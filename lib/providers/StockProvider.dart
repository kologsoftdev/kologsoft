import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/farmerModel.dart';
import 'package:kologsoft/models/levelofeducation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/cropModel.dart';
import '../models/languageModel.dart';
import '../models/purchasereturns.dart';
import '../models/stockReport.dart';
import '../models/stockmodel.dart';
import '../screens/warehousehomescreen.dart';
//import 'dart:html' as html;
import 'Datafeed.dart';

class StockProvider extends Datafeed {
  List<PurchaseReturnView> filteredTransactions = [];
  List<Map<String, dynamic>> pendingRequests = [];
  List<FarmerRegModel> farmerlist = [];
List<Map<String,dynamic>> communities=[];
  Map<String, dynamic>? selectedRequest;
  String? selectedRequestId;
  String? selectedRequestStatus;
  bool isLoading = false;
  String searchQuery = '';
  List<StockItem> sampleJson=[];
  List<StockItem> dailyStokcReport=[];
  List<StockModel> purchaseTransactions=[];
  List<CropModel> crops=[];
  List<LanguageModel> languages=[];
  List<EducationModel> levelofeducationlist=[];
  List<PurchaseReturnView> purchasereturnitems=[];
  final Map<String, Map<String, dynamic>> supplyItems = {};
  String notes = '';
  bool showCompleted = false;
  int pendingRequestscount=0;
  StreamSubscription? _subscription;

  final now = DateTime.now();
  late final defaultStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
  late final defaultEnd   = DateTime(now.year, now.month, now.day, 23, 59, 59);

  int weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) / 7).ceil();
  }

  subscribePendingRequests({DateTime? startDate, DateTime? endDate}) async {
    await getdata();
    _subscription?.cancel();

    isLoading = true;
    notifyListeners();

    final effectiveStart = startDate ?? defaultStart;
    final effectiveEnd   = endDate ?? defaultEnd;

    Query query = db
        .collection('stock_request')
        .where('companyid', isEqualTo: companyid)
        .where('warehouseid', isEqualTo: branchid)
        .where('createdat', isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart))
        .where('createdat', isLessThanOrEqualTo: Timestamp.fromDate(effectiveEnd))
        .orderBy('createdat', descending: true);

    if (!showCompleted) {
      query = query.where('status', whereIn: ['pending', 'partial', 'complete']);
    }

    _subscription = query.snapshots().listen((snapshot) {
      pendingRequests = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      isLoading = false;
      notifyListeners();
    }, onError: (error) {
      isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void selectRequest(String id, Map<String, dynamic> request, String requestStatus) {
    selectedRequestId = id;
    selectedRequest = request;
    selectedRequestStatus = requestStatus;

    supplyItems.clear();
    notifyListeners();
  }

   updateSupplyQuantity(String itemId, double requestedQty, double suppliedQty) {
    if (suppliedQty >= 0) {
      supplyItems[itemId] = {
        'requested': requestedQty,
        'supplied': suppliedQty,
        'status': getSupplyStatus(requestedQty, suppliedQty),
      };
    } else {
      supplyItems.remove(itemId);
    }
    notifyListeners();
  }

  String getSupplyStatus(double requestedQty, double suppliedQty) {
    if (suppliedQty == requestedQty) return 'completed';
    if (suppliedQty < requestedQty && suppliedQty > 0) return 'partial';
    if (suppliedQty == 0) return 'no stock';
    return 'pending';
  }

  double calculateSupplyPercentage() {
    if (selectedRequest == null) return 0;
    final items = selectedRequest!['items'] as List? ?? [];
    if (items.isEmpty) return 0;

    double totalRequested = 0;
    double totalSupplied = 0;

    for (var item in items) {
      final requestedQty = (item['requestedquantity'] as num?)?.toDouble() ?? 0.0;
      final oldsupply = (item['suppliedquantity'] as num?)?.toDouble();
      final dbstatus = item['supplystatus'];
      totalRequested += requestedQty;
      final itemId = item['itemid'];
      final supply = supplyItems[itemId];
      final rawsupply = (supply?['supplied'] as num?)?.toDouble();
      double suppliedQty;
      if (dbstatus == 'pending') {
        suppliedQty = rawsupply ?? requestedQty;
      } else {
        suppliedQty = oldsupply ?? 0.0;
      }
      totalSupplied += suppliedQty!;
    }

    if (totalRequested == 0) return 0;
    return (totalSupplied / totalRequested * 100).clamp(0, 100) as double;
  }

  Future<void> submitSupply() async {
    if (selectedRequest == null || selectedRequestId == null) {
      throw Exception('No request selected');
    }

    try {
      await getdata();
      isLoading = true;
      notifyListeners();
      final items = selectedRequest!['items'] as List;
      String supplyPercentage = calculateSupplyPercentage().toStringAsFixed(0);
      final overallStatus = (supplyPercentage == '100' ? 'complete' : 'partial');

      final updatedItems = items.asMap().entries.map((entry) {
        final item = entry.value as Map<String, dynamic>;
        final itemId = item['itemid'];
        double requested = (item['requestedquantity'] as num?)?.toDouble() ?? 0.0;
        final supply = supplyItems[itemId];
        final suppliedQty = supply?['supplied'];
        final suppliedQtys = suppliedQty ?? requested;
        final modeQty = (item['modeqty'] as num?)?.toDouble() ?? 1.0;
        final suppliedPieces = suppliedQtys! * modeQty;
        final supplyStatus = getSupplyStatus(requested, suppliedQtys);

        return {
          ...item,
          'suppliedquantity': suppliedQtys,
          'suppliedpieces': suppliedPieces,
          'supplystatus': supplyStatus,
          'supplydate': Timestamp.fromDate(DateTime.now()),
        };
      }).toList();


      await db.collection('stock_request').doc(selectedRequestId).update({
        'items': updatedItems,
        'status': overallStatus,
        'supplypercentage': supplyPercentage,
        'suppliedby': staff,
        'generalnotes': notes,
        'supplieddate': staff,
        'supplieddate': Timestamp.fromDate(DateTime.now()),
      });

      selectedRequest = {
        ...selectedRequest!,
        'items': updatedItems,
        'status': overallStatus,
        'supplypercentage': supplyPercentage,
        'suppliedby': staff,
        'generalnotes': notes,
        'supplieddate': Timestamp.fromDate(DateTime.now()),
      };

      selectRequest(selectedRequestId!, selectedRequest!, overallStatus);
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void resetSupply() {
    selectedRequest = null;
    selectedRequestId = null;
    supplyItems.clear();
    notes = '';
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> stockStream({required String? collectionName,required String branchfield,required String datefield,DateTime? startDate, DateTime? endDate}) {
    final now = DateTime.now();

    final effectiveStart = startDate ?? DateTime(now.year, now.month, 1);

    final effectiveEnd = endDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59);


    Query<Map<String, dynamic>> query = db.collection(collectionName!)
        .where("companyid", isEqualTo: companyid)
        //.where("$branchfield", isEqualTo: branchid)
        .where(datefield, isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart))
        .where(datefield, isLessThanOrEqualTo: Timestamp.fromDate(effectiveEnd))
        .orderBy(datefield, descending: true);
    if (accesslevel != 'super admin') {
      query = query.where(branchfield, isEqualTo: branchid);
    }
        return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

 stockreportdata({
    required String? collectionName,
    required String branchfield,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final effectiveStart = startDate ?? defaultStart;
    final effectiveEnd = endDate ?? defaultEnd;

    final querySnapshot = await db.collection(collectionName!)
        .where("companyid", isEqualTo: companyid)
        .orderBy('createdat', descending: true).get();
    return sampleJson= querySnapshot.docs.map((json) => StockItem.fromJson(json.data())).toList();

  }

  Future<List<StockItem>> getDailyStockReport({
    required DateTime date,
  }) async {
    final List<StockItem> stockReport = [];

    // yyyy-mm-dd
    final today =
        "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";

    // get all items from itemsreg
    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('itemsreg')
        .where("companyid", isEqualTo: companyid)
        .get();

    for (final itemDoc in itemsSnapshot.docs) {
      final itemId = itemDoc.id;

      // fetch daily transaction document
      final dailyDoc = await FirebaseFirestore.instance
          .collection('itemsreg')
          .doc(itemId)
          .collection('dailytransactions')
          .doc(today)
          .get();

      Map<String, dynamic> finalData = {};

      if (dailyDoc.exists) {
        // use dailytransactions data
        final dailyData = dailyDoc.data() ?? {};

        finalData = {
          ...itemDoc.data(),

          // overwrite with daily transaction values
          'branchbalance': dailyData['branchbalance'] ?? {},
          'createdat': dailyData['createdat'],
        };
      } else {
        // fallback to itemsreg branchbalance
        finalData = itemDoc.data();
      }

      stockReport.add(StockItem.fromJson(finalData));
    }

    return dailyStokcReport=stockReport;
  }
   loadPurchaseTransactions(String invoicenumber) async {
    try {
         await getdata();
           Query query = db
          .collection('stock_transactions')
          .where('companyid', isEqualTo: companyid)
          .where('waybill', isEqualTo: invoicenumber);
          final snapshot = await query.limit(10).get();
          purchaseTransactions = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return StockModel.fromMap(data, doc.id);
        }).toList();
    } catch (e) {
      print('Failed to load purchases: $e');
    }finally{
      notifyListeners();
    }
  }

   submitReturn({
    required StockModel transaction,
    required Map<String, dynamic> returnItems,
    required String returnId,
    required String returndate,

  }) async {
    await getdata();
    final validItems = <Map<String, dynamic>>[];
    double totalReturnValue = 0;
    final docid = normalizeAndSanitize(
      "${companyid}${DateTime.now().millisecondsSinceEpoch}${staffPosition}",
    );
    for (var item in transaction.items) {
      final data = returnItems[item.itemId];
      final returnedQty = (data?['returned'] as num?)?.toDouble() ?? 0;
      final reason = (data?['reason'] ?? '').toString().trim();
      if (returnedQty > 0) {
        if (reason.isEmpty) {
          throw Exception('Select reason for ${item.item}');
        }

        if (returnedQty > item.quantity) {
          throw Exception('${item.item} exceeds purchased quantity');
        }

        final returnPieces = item.modeQty * returnedQty;

        // Check current stock balance
        final availableBalance = await fetchItemCurrentBalance(
          itemId: item.itemId,
          selectedBranch: transaction.branchId,
        );

        if (availableBalance < returnPieces) {
          throw Exception(
            '${item.item}\n'
                'Available: ${availableBalance.toInt()} pcs\n'
                'Trying to return: ${returnPieces.toInt()} pcs',
          );
        }

        double net_returnvalue=0;
        net_returnvalue=item.price * returnPieces;
        validItems.add({
          ...item.toMap(),
          'returnquantity': returnedQty,
          'returnpieces': returnPieces,
          'returnreason': reason,
          'net_returnvalue': net_returnvalue,
          'returndate': Timestamp.now(),
        });

        totalReturnValue += net_returnvalue;
      }
    }

    if (validItems.isEmpty) {
      throw Exception('No items selected for return');
    }
    //String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    //String today = formatInvoiceDate(returndate);
    final DateTime parsedDate = DateFormat('dd MMM yyyy').parse(returndate);

    final String today = DateFormat('yyyy-MM-dd').format(parsedDate);;
    final batch = db.batch();

    final returnRef = db
        .collection('purchase_returns')
        .doc(docid);

    final updateSource = db
        .collection('stock_transactions')
        .doc(transaction.docId);

    batch.set(returnRef, {
      'returnid': docid,
      'items': validItems,
      'returnvalue': totalReturnValue,
      'companyid': companyid,
      'companyname': company,
      'submittedat': Timestamp.now(),
      'supplierid':transaction.supplierId,
      'suppliername':transaction.supplierName,
      'invoice':transaction.invoice,
      'waybill':transaction.waybill,
      'purchasetype':transaction.purchaseType,
      'createdby':staff,
      'date':today,
      'branchname':transaction.branchName,
      'branchid':transaction.branchId,
      'year': now.year.toString(), // 2026
      'month': '${now.year}.${now.month}', // 2026.5
      'week': '${now.year}.${weekNumber(now)}', // 2026.32
      'day': DateFormat('EEEE').format(now),
      'returndate':returndate ,
    });

    batch.update(updateSource, {
      'purchasereturn': true,
    });

    await batch.commit();
    markTransactionReturned(transaction.docId);
  }

   markTransactionReturned(String id) {
    final index = purchaseTransactions.indexWhere((t) => t.docId == id);
    if (index != -1) {
      purchaseTransactions[index] =
          purchaseTransactions[index].copyWith(purchasereturn: true);
      notifyListeners();
    }
  }

  loadPurchaseReturns() async {
    try {
      await getdata();
      Query query = db
          .collection('purchase_returns')
          .where('companyid', isEqualTo: companyid);
      final snapshot = await query.get();
      purchasereturnitems = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return PurchaseReturnView.fromJson(data, customId: doc.id);
      }).toList();
      filterTransactions();
    } catch (e) {
      print('Failed to load purchases: $e');
    }finally{
      notifyListeners();
    }
  }

   filterTransactions() {
    filteredTransactions = purchasereturnitems.where((txn) {
      final query = searchQuery.toLowerCase();

      bool matchesSearch = searchQuery.isEmpty ||
          txn.invoice.toLowerCase().contains(query) ||
          txn.suppliername.toLowerCase().contains(query) ||
          txn.companyname.toLowerCase().contains(query);

      return matchesSearch;
    }).toList();

    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    filterTransactions();
  }

  deletePurchaseReturn(String id) async {
    try {
      await db.collection('purchase_returns').doc(id).delete();
      purchasereturnitems.removeWhere((txn) => txn.id == id);
      purchasereturnitems.removeWhere((e) => e.id == id);
      filteredTransactions.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      print('Delete failed: $e');
    }
  }
  fetchCrops() async {
    await getdata();
    try {
      final snap = await db
          .collection('crops')
          .where("companyid", isEqualTo: companyid)
          .get(const GetOptions(source: Source.serverAndCache));
      crops = snap.docs.map((doc) {
        return CropModel.fromJson(doc.data());
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching stocking modes: $e");
    }
  }
  fetchLanguages() async {
    await getdata();
    try {
      final snap = await db
          .collection('languages')
          .where("companyid", isEqualTo: companyid)
          .get(const GetOptions(source: Source.serverAndCache));
      languages = snap.docs.map((doc) {
        return LanguageModel.fromJson(doc.data());
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching stocking modes: $e");
    }
  }
  fetcheducationlevels() async {
    await getdata();
    try {
      final snap = await db
          .collection('educationlevel')
          .where("companyid", isEqualTo: companyid)
          .get(const GetOptions(source: Source.serverAndCache));
      levelofeducationlist = snap.docs.map((doc) {
        return EducationModel.fromJson(doc.data());
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching education levels: $e");
    }
  }
  fetchFarmers() async {
    try {
      await getdata();

      Query query = db.collection('customers')
          .where("companyid", isEqualTo: companyid);

      if (accesslevel != 'super admin') {
        query = query.where("branchid", isEqualTo: branchid);
      }

      final snap = await query
          .orderBy('createdat', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      farmerlist = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return FarmerRegModel.fromMap(data, doc.id);
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching customer list: $e");
    }
  }

  // fetchFarmers() async {
  //   try {
  //     await getdata();
  //     final snap = await db .collection('customers').where("companyid", isEqualTo: companyid)
  //         .orderBy('createdat', descending: true)
  //         .get(const GetOptions(source: Source.serverAndCache));
  //
  //     farmerlist = snap.docs.map((doc) {
  //       return FarmerRegModel.fromMap(doc.data(), doc.id);
  //     }).toList();
  //
  //     notifyListeners();
  //   } catch (e) {
  //     debugPrint("Error fetching customer list: $e");
  //   }
  // }

  deleteFarmer(String id) async {
    await db.collection('customers').doc(id).delete();
    farmerlist.removeWhere((c) => c.id == id);
    notifyListeners();
  }
  fetchCommunities() async {
    await getdata();
    try {
      final snap = await db
          .collection('communities')
          .where("companyid", isEqualTo: companyid)
          .get(const GetOptions(source: Source.serverAndCache));
      communities = snap.docs.map((doc) {
        return doc.data();
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching communities $e");
    }
  }

  Future<void> syncTransactionToReport(String transactionId) async {
    final db = FirebaseFirestore.instance;

    final txDoc =
    await db.collection('stock_transactions').doc(transactionId).get();

    if (!txDoc.exists) {
      throw Exception("Transaction not found");
    }

    // Convert the document into a normal Dart Map
    final txData = Map<String, dynamic>.from(txDoc.data()!);

    final String branchId = txData['branchid'];
    final String branchName = txData['branchname'];
    final String companyId = txData['companyid'];
    final String today = txData['date'];

    final List<Map<String, dynamic>> items =
    (txData['items'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final summaryId = "${companyId}_$today";

    final dailyRef = db.collection('stockreport').doc(summaryId);
    final statsRef = db.collection('dashbaord_stats').doc(companyId);

    final batch = db.batch();

    double totalPieces = 0;
    double totalValue = 0;

    /// Create report structure
    final Map<String, dynamic> reportData = {
      "summarydate": today,
      "summaryid": summaryId,
      "companyid": companyId,

      "branchbalance": {
        branchId: {
          "branchId": branchId,
          "branchName": branchName,
          "branch_newstock": FieldValue.increment(0),
          "branch_newstockvalue": FieldValue.increment(0),
          "branchstockin_balance": FieldValue.increment(0),
          "branchstockin_value": FieldValue.increment(0),
          "branchtransaction_count": FieldValue.increment(1),
          "lastupdate": FieldValue.serverTimestamp(),
        }
      },

      "items": {
        branchId: <String, dynamic>{},
      }
    };

    // Get references to the ORIGINAL nested maps
    final Map<String, dynamic> itemsMap =
    reportData["items"] as Map<String, dynamic>;

    final Map<String, dynamic> branchItems =
    itemsMap[branchId] as Map<String, dynamic>;

    final Map<String, dynamic> branchBalance =
    (reportData["branchbalance"] as Map<String, dynamic>)[branchId]
    as Map<String, dynamic>;

    // Build item report
    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw);

      final int pieces = (item["pieces"] ?? 0).toInt();
      final double price = (item["price"] ?? 0).toDouble();
      final double value = pieces * price;

      totalPieces += pieces;
      totalValue += value;

      final String itemId = item["itemid"];

      branchItems[itemId] = {
        "item": item["item"],
        "itemId": itemId,
        "itemid": itemId,
        "itemName": item["item"],
        "barcode": item["barcode"],
        "boxpieces": item["boxpieces"],

        "newstock": FieldValue.increment(pieces),
        "newstock_value": FieldValue.increment(value),

        "stockin_balance": FieldValue.increment(pieces),
        "stockin_value": FieldValue.increment(value),

        "transaction_count": FieldValue.increment(1),

        "lastupdate": FieldValue.serverTimestamp(),
      };
    }

    // Update branch totals
    branchBalance["branch_newstock"] =
        FieldValue.increment(totalPieces);

    branchBalance["branch_newstockvalue"] =
        FieldValue.increment(totalValue);

    branchBalance["branchstockin_balance"] =
        FieldValue.increment(totalPieces);

    branchBalance["branchstockin_value"] =
        FieldValue.increment(totalValue);

    // Save stock report
    batch.set(
      dailyRef,
      reportData,
      SetOptions(merge: true),
    );

    // Update dashboard stats
    batch.set(
      statsRef,
      {
        "companyId": companyId,
        "updatedAt": FieldValue.serverTimestamp(),
        "stock_in_total": FieldValue.increment(totalValue),
        "branchstock": {
          branchId: {
            "branchname": branchName,
            "stock_value": FieldValue.increment(totalValue),
            "lastupdate": FieldValue.serverTimestamp(),
          }
        }
      },
      SetOptions(merge: true),
    );

    // Mark synced
    batch.update(
      db.collection("stock_transactions").doc(transactionId),
      {
        "syncstatus": true,
        "lastSyncedAt": FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

   deleteLedgersForCompany(String companyId) async {
    try {
      // Query all ledgers for the given company
      final snapshot = await db
          .collection('ledgers')
          .where('companyId', isEqualTo: companyId)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint("No ledgers found for company $companyId");
        return;
      }

      // Firestore batch limit is 500 operations, so chunk if needed
      for (var i = 0; i < snapshot.docs.length; i += 500) {
        final batch = db.batch();
        final chunk = snapshot.docs.skip(i).take(500);

        for (var doc in chunk) {
          batch.delete(doc.reference);
        }

        await batch.commit();
      }

      debugPrint("Deleted ${snapshot.docs.length} ledgers for company $companyId");
    } catch (e) {
      debugPrint("Error deleting ledgers for company $companyId: $e");
    }
  }

  bool _loading = false;
  bool get loading => _loading;

  List<Sale> _sales = [];
  List<Sale> get salesTosupply => _sales;


   loadSales({DateTime? startDate, DateTime? endDate,}) async {
    _loading = true;
    notifyListeners();
    await getdata();

    try {
      Query query = db.collection('sales')
          .where('companyId', isEqualTo: companyid)
          .where('branchType', isEqualTo: 'Sales Point');

      if (startDate == null && endDate == null) {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      } else {
        if (startDate != null) {
          final startOfDay = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
        }
        if (endDate != null) {
          final startOfNextDay = DateTime(
            endDate.year,
            endDate.month,
            endDate.day + 1,
          );
          query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(startOfNextDay));
        }

      }

      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      _sales = snapshot.docs.map((doc) {
        final sale = Sale.fromFirestore(doc);
        final includeByMode = sale.transMode == 'credit' || (sale.transMode == 'cash' && sale.paymentStatus != 'pending');

        if (!includeByMode) return null;

        if (accesslevel != 'super admin') {
          final filteredItems = sale.items.where((item) => item.branchid == branchid).toList();

          if (filteredItems.isEmpty) {
            return null;
          }

          return sale.copyWith(
            items: filteredItems,
            itemCount: filteredItems.length,
          );
        }

        return sale;
      })
          .whereType<Sale>()
          .toList();

    } catch (e) {
      debugPrint(e.toString());
    }

    _loading = false;
    notifyListeners();
  }



 syncStockTransfers(String docId) async {
    final db = FirebaseFirestore.instance;

    final transferDoc = await db.collection('stock_transfer').doc(docId).get();
    if (!transferDoc.exists) {
      debugPrint('Transfer document not found.');
      return;
    }

    final transfer = transferDoc.data()!;
    final companyId = transfer['companyid'];
    final transferId = docId;

    final sourceBranchId = transfer['supplywarehouseid'];
    final sourceBranchName = transfer['supplywarehousename'];

    final receiveBranchId = transfer['recievebranchid'];
    final receiveBranchName = transfer['recievebranchname'];

    final updatedBy = transfer['createdby'] ?? '';
    final today = transfer['date'];
    final reportId = "${companyId}_$today";

    final stockReportRef = db.collection('stockreport').doc(reportId);
    final dashboardRef = db.collection('dashbaord_stats').doc(companyId);

    final items = List<Map<String, dynamic>>.from(transfer['items'] ?? []);

    double sourceStockValue = 0;
    double receiveStockValue = 0;

    // Aggregate item updates here
    final Map<String, dynamic> sourceItemsUpdate = {};
    final Map<String, dynamic> receiveItemsUpdate = {};

    for (final item in items) {
      final itemId = item['itemid'];
      final itemRef = db.collection('itemsreg').doc(itemId);
      final itemSnap = await itemRef.get();
      if (!itemSnap.exists) continue;

      final itemData = itemSnap.data()!;
      final cp = double.tryParse(itemData['cp'].toString()) ?? 0;
      final pieces = (item['pieces'] ?? 0).toDouble();
      final qty = (item['quantity'] ?? 0).toDouble();
      final boxPieces = (item['boxpieces'] ?? 1).toDouble();
      final cartons = boxPieces == 0 ? 0 : pieces / boxPieces;

      final stockValue = cp * pieces;
      sourceStockValue += stockValue;
      receiveStockValue += stockValue;

      //Update itemsreg directly per item
      await itemRef.set({
        "branchbalance": {
          sourceBranchId: {
            "quantity": FieldValue.increment(-qty),
            "netpieces": FieldValue.increment(-pieces),
            "stock_value": FieldValue.increment(-stockValue),
            "name": sourceBranchName,
            "updatedby": updatedBy,
            "lastupdate": FieldValue.serverTimestamp(),
          },
          receiveBranchId: {
            "quantity": FieldValue.increment(qty),
            "receivedquantity": FieldValue.increment(qty),
            "receivedpieces": FieldValue.increment(pieces),
            "netpieces": FieldValue.increment(pieces),
            "stock_value": FieldValue.increment(stockValue),
            "name": receiveBranchName,
            "updatedby": updatedBy,
            "lastupdate": FieldValue.serverTimestamp(),
          }
        },
        "lastModified": FieldValue.serverTimestamp(),
        "lastStockTransferId": transferId,
      }, SetOptions(merge: true));

      //Aggregate into one big update map
      sourceItemsUpdate[itemId] = {
        "itemId": itemId,
        "item": item['item'],
        "barcode": item['barcode'],
        "boxpieces": boxPieces,
        "transfer_cartons": FieldValue.increment(cartons),
        "transfer_qty": FieldValue.increment(pieces),
        "stockout_balance": FieldValue.increment(pieces),
        "transaction_count": FieldValue.increment(1),
        "lastupdate": FieldValue.serverTimestamp(),

      };

      receiveItemsUpdate[itemId] = {
        "itemId": itemId,
        "item": item['item'],
        "barcode": item['barcode'],
        "boxpieces": boxPieces,
        "transfer_recieved_cartons": FieldValue.increment(cartons),
        "transfer_recieved_qty": FieldValue.increment(pieces),
        "stockin_balance": FieldValue.increment(pieces),
        "transaction_count": FieldValue.increment(1),
        "lastupdate": FieldValue.serverTimestamp(),

      };
    }

    final batch = db.batch();

    // Write aggregated items once
    batch.set(stockReportRef, {
      "companyid": companyId,
      "summaryid": reportId,
      "summarydate": today,
      "branchbalance": {
        sourceBranchId: {
          "branchId": sourceBranchId,
          "branchName": sourceBranchName,
          "branchtransfer_qty": FieldValue.increment(items.fold<double>(0, (sum, i) => sum + (i['pieces'] ?? 0).toDouble())),
          "branchstockout_balance": FieldValue.increment(items.fold<double>(0, (sum, i) => sum + (i['pieces'] ?? 0).toDouble())),

          "branchtransaction_count": FieldValue.increment(1),
        },
        receiveBranchId: {
          "branchId": receiveBranchId,
          "branchName": receiveBranchName,
        "branchtransferRecieved_qty": FieldValue.increment(items.fold<double>(0, (sum, i) => sum + (i['pieces'] ?? 0).toDouble())),
         "branchstockin_balance": FieldValue.increment(items.fold<double>(0, (sum, i) => sum + (i['pieces'] ?? 0).toDouble())),
          "branchtransaction_count": FieldValue.increment(1),
        }
      },
      "items": {
        sourceBranchId: sourceItemsUpdate,
        receiveBranchId: receiveItemsUpdate,
      }
    }, SetOptions(merge: true));

    batch.set(dashboardRef, {
      "companyId": companyId,
      "branchstock": {
        sourceBranchId: {
          "branchname": sourceBranchName,
          "stock_value": FieldValue.increment(sourceStockValue),
        },
        receiveBranchId: {
          "branchname": receiveBranchName,
          "stock_value": FieldValue.increment(receiveStockValue),
        }
      },
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    debugPrint("Processed stock transfer $transferId. for $reportId Updated ${items.length} items.");
  }

  String formatInvoiceDate(dynamic value) {
    if (value is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(value.toDate());
    } else if (value is DateTime) {
      return DateFormat('yyyy-MM-dd').format(value);
    } else if (value is String) {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(value));
    }
    return '';
  }
  //String today = formatInvoiceDate(widget.headerData['invoicedate']);

  Future<void> syncsingleTransactionToReport(
      String transactionId,
      Map<String, dynamic> selectedItem,
      ) async {
    final db = FirebaseFirestore.instance;

    final txDoc = await db
        .collection('stock_transactions')
        .doc(transactionId)
        .get();

    if (!txDoc.exists) {
      throw Exception("Transaction not found");
    }

    // Convert the document into a normal Dart Map
    final txData = Map<String, dynamic>.from(
      txDoc.data()!,
    );

    final String branchId =
        txData['branchid']?.toString() ?? '';

    final String branchName =
        txData['branchname']?.toString() ?? '';

    final String companyId =
        txData['companyid']?.toString() ?? '';

    final String today =
        txData['date']?.toString() ?? '';

    if (branchId.isEmpty) {
      throw Exception("Branch ID is missing");
    }

    if (companyId.isEmpty) {
      throw Exception("Company ID is missing");
    }

    if (today.isEmpty) {
      throw Exception("Transaction date is missing");
    }


    final item = Map<String, dynamic>.from(
      selectedItem,
    );

    final int pieces =
        (item["pieces"] as num?)?.toInt() ?? 0;

    final double price =
        (item["price"] as num?)?.toDouble() ?? 0;

    final double value =
        pieces * price;

    final String itemId =
        item["itemid"]?.toString() ?? '';

    if (itemId.isEmpty) {
      throw Exception("Selected item has no itemid");
    }

    final summaryId =
        "${companyId}_$today";

    final dailyRef =
    db.collection('stockreport').doc(summaryId);

    final statsRef =
    db.collection('dashbaord_stats').doc(companyId);

    final batch = db.batch();

    // Ttotals for singe item

    final double totalPieces =
    pieces.toDouble();

    final double totalValue =
        value;

    final Map<String, dynamic> reportData = {
      "summarydate": today,
      "summaryid": summaryId,
      "companyid": companyId,

      "branchbalance": {
        "summarydate": today,
        "companyid": companyId,
        branchId: {
          "branchId": branchId,
          "branchName": branchName,

          "branch_newstock":
          FieldValue.increment(0),

          "branch_newstockvalue":
          FieldValue.increment(0),

          "branchstockin_balance":
          FieldValue.increment(0),

          "branchtransaction_count":
          FieldValue.increment(1),

          "lastupdate":
          FieldValue.serverTimestamp(),
        }
      },

      "items": {
        branchId: <String, dynamic>{},
      }
    };

    // Get references to the ORIGINAL nested maps
    final Map<String, dynamic> itemsMap =
    reportData["items"] as Map<String, dynamic>;

    final Map<String, dynamic> branchItems =
    itemsMap[branchId] as Map<String, dynamic>;

    final Map<String, dynamic> branchBalance =
    (reportData["branchbalance"]
    as Map<String, dynamic>)[branchId]
    as Map<String, dynamic>;

    // ONLY ADD THE SELECTED ITEM

    branchItems[itemId] = {
      "item": item["item"],
      "itemid": itemId,
      "barcode": item["barcode"],
      "boxpieces": item["boxpieces"],

      "newstock":
      FieldValue.increment(pieces),

      "newstock_value":
      FieldValue.increment(value),

      "transaction_count":
      FieldValue.increment(1),

      "lastupdate":
      FieldValue.serverTimestamp(),
    };

    // UPDATE BRANCH TOTALS
    branchBalance["branch_newstock"] =
        FieldValue.increment(totalPieces);

    branchBalance["branch_newstockvalue"] =
        FieldValue.increment(totalValue);

    branchBalance["branchstockin_balance"] =
        FieldValue.increment(totalPieces);

    branchBalance["branchstockin_value"] =
        FieldValue.increment(totalValue);

    batch.set(
      dailyRef,
      reportData,
      SetOptions(merge: true),
    );

    // ----------------------------------------------------------
    // UPDATE DASHBOARD STATS
    batch.set(
      statsRef,
      {
        "companyId": companyId,
        "updatedAt":
        FieldValue.serverTimestamp(),

        "stock_in_total":
        FieldValue.increment(totalValue),

        "branchstock": {
          branchId: {
            "branchname": branchName,

            "stock_value":
            FieldValue.increment(totalValue),

            "lastupdate":
            FieldValue.serverTimestamp(),
          }
        }
      },
      SetOptions(merge: true),
    );


    await markItemAsSynced(transactionId, itemId);
    await batch.commit();
  }

  Future<void> markItemAsSynced(
      String transactionId,
      String itemId,
      ) async {
    final transactionRef = db
        .collection('stock_transactions')
        .doc(transactionId);

    final snapshot = await transactionRef.get();

    if (!snapshot.exists) {
      throw Exception('Stock transaction not found');
    }

    final data = snapshot.data();

    if (data == null) {
      throw Exception('Transaction data is empty');
    }

    final rawItems = data['items'];

    if (rawItems is! List) {
      throw Exception('Transaction items are not stored as a list');
    }

    // Copy all items
    final List<Map<String, dynamic>> items = rawItems
        .map(
          (item) => Map<String, dynamic>.from(item as Map),
    )
        .toList();

    bool found = false;

    for (int i = 0; i < items.length; i++) {
      final currentItem = items[i];

      if (currentItem['itemid']?.toString() == itemId) {
        items[i] = {
          ...currentItem,
          'syncstatus': true,
          'lastSyncedAt': Timestamp.now(),
        };

        found = true;
        break;
      }
    }

    if (!found) {
      throw Exception(
        'Item $itemId was not found in transaction',
      );
    }

    // Write the complete array back.
    await transactionRef.update({
      'items': items,
    });
  }
  /*
  Future<void> downloadstocktemplate(BuildContext context) async {
    const assetPath = 'assets/stockupload.xlsx';
    const fileName = 'stockupload.xlsx';

    if (kIsWeb) {
      // For web: trigger browser download
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download started')),
      );
    } else {
      // For Android/iOS: save to Downloads folder
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }
      if (downloadsDir != null) {
        final byteData = await rootBundle.load(assetPath);
        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File saved to ${downloadsDir.path}')),
        );
      }
    }
  }
*/

  Future<void> downloadstocktemplate(BuildContext context) async {
    const assetPath = 'assets/stockupload.xlsx';
    const fileName = 'stockupload.xlsx';

    final byteData = await rootBundle.load(assetPath);

    Directory? downloadsDir;

    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];

      if (home != null) {
        downloadsDir = Directory('$home\\Downloads');
      }
    } else if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    if (downloadsDir == null) {
      throw Exception('Unable to determine download directory');
    }

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final file = File('${downloadsDir.path}${Platform.pathSeparator}$fileName');

    await file.writeAsBytes(
      byteData.buffer.asUint8List(),
      flush: true,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File saved to ${file.path}'),
        ),
      );
    }
  }

}

