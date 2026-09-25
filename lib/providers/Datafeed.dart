import 'dart:async';

import 'dart:convert';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/banktransfermodel.dart';
import 'package:kologsoft/models/salesreturnmodel.dart';
import 'package:universal_io/io.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kologsoft/models/paymentdurationmodel.dart';
import 'package:kologsoft/models/productcategorymodel.dart';
import 'package:kologsoft/models/staffmodel.dart';
import 'package:kologsoft/models/account_type_model.dart';
import 'package:kologsoft/models/activity_model.dart';
import 'package:kologsoft/models/sub_account_model.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:kologsoft/services/item_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/ReasonsModel.dart';
import '../models/addtaxvatmodel.dart';
import '../models/branch.dart';
import '../models/closesalemodel.dart';
import '../models/companymodel.dart';
import '../models/configurevatmodel.dart';
import '../models/creditorbalanceModel.dart';
import '../models/customerreg_model.dart';
import '../models/damageitem.dart';
import '../models/dashboardStats.dart';
import '../models/discountmanager.dart';
import '../models/itemhistory.dart';
import '../models/itemregmodel.dart';
import '../models/permissionsmodel.dart';
import '../models/printbarcodemodel.dart';
import '../models/sales_summary.dart';
import '../models/salesmodel.dart';
import '../models/stocking_modeModel.dart';
import '../models/suppliermodel.dart';
import '../models/warehousemodel.dart';
import '../screens/role_access_config.dart';
import '../services/sales_import_service.dart';

class WeeklySalesComparison {
  final List<double> currentWeek;
  final List<double> previousWeek;
  final DateTime currentWeekStart;

  WeeklySalesComparison({
    required this.currentWeek,
    required this.previousWeek,
    required this.currentWeekStart,
  });
}
double toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}


class Datafeed extends ChangeNotifier {
  SalesImportService? _salesImport;
  double smsBalance=0.0;
  double disCount=0.0;
  SalesImportService get salesImport => _salesImport ??= SalesImportService();

  // Stream for top 10 items by sales amount, updates incrementally as sales change
        Stream<List<Map<String, dynamic>>> top10BestSellingItems(fieldname) {
          return FirebaseFirestore.instance
              .collection('itemsreg')
              .where('companyid', isEqualTo: companyid)
              .where(fieldname, isGreaterThan: 0)
              .orderBy(fieldname, descending: true)
              .limit(10)
              .snapshots()
              .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'itemid': doc.id,
                'item': data['name'] ?? '',
                'barcode': data['barcode'] ?? '',
                'sales_value': toDouble(data['sales_value']),
                'sales_qty': toInt(data['sales_qty']),
                'retailprice': toDouble(data['retailprice']),
              };
            }).toList();
          });
        }

  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final ItemCacheService itemCache = ItemCacheService();
  bool authenticated = false;
  bool isOffline = false;
  String company = "";
  List pricingmode = [];

  String companytype = "both";
  String companyid = "";
  String companyemail = "";
  String branchtype = "";
  String branchaddress ="";
  String branchphone ="";
  String branch = "";
  String companyphone = "";
  String staff = "";
  String staffemail = "";
  bool canPrint = false;
  bool canEditPrice = false;
  bool canSelectDate = false;
  bool canSellAnyBranch =false;
  bool allowDiscount =false;
  bool allowDiscountCode =false;
  String branchid = "";
  String accesslevel = "";
  String subscriptionTier = 'starter';
  int staffPosition = 0;
  String sessionId="";
  List<String> allowedPaymentMethods = [];
  List<String> salesWarehouseIds = [];
  List<String> salesWarehouseNames = [];
  String? salesWarehouseId;
  String? salesWarehouseName;
  List<WarehouseModel> warehouses = [];
  bool loadingproductcategory = false;
  List<Productcategorymodel> productcategory = [];
  List<BranchModel> branches = [];
  List<Supplier> suppliers = [];
  List<CustomerRegModel> customerlist = [];
  List<damageitemmodel> damages = [];
  bool isloadingdamages = false;

  List<salereturn> salesreturn = [];
  List<SalesModel> salesview = [];
  String searchQuery = '';
  bool isloadingsalesreturn = false;


  List<cropModel> stockingModes = [];
  List<ReasonsModel> returnitemreasons = [];
  bool loadingWarehouses = false;
  BranchModel? selectedBranch;
  WarehouseModel? selectedwarehouse;
  Supplier? selectedSupplier;
  StaffModel? currentStaff;
  CompanyModel? currentCompany;
  cropModel? selectedStockingMode;
  String totalSales = "";
  String totalCash = "";
  String totalCredit = "";
  bool loadingsale = false;
  List<Map<String, dynamic>> salesItem = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?_dashboardStatsSub;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _staffDocSub;

  bool isloadingsalesbundle= false;
  List<Map<String,dynamic>> bundleview = [];
  List<ItemModel> bundleviewitemodel = [];
  bool isLoadingReceipt = false;
  List<Map<String, dynamic>> receiptList = [];
  final List<Map<String, dynamic>> closeSaleRecords = [];
  double? editingCloseSaleIndex;
  List<Map<String,dynamic>> closesales = [];
  bool isloadingclosesale = false;
  List<CreditorBalance> creditoropenbal = [];
  bool isloadingcreditbal = false;

  List<Map<String, dynamic>> itemBalanceList = [  ];
  bool isLoadingItemDetail = false;
  List<Map<String, dynamic>> itemDetailList = [ ];
  bool isLoadingcreditlist = false;
  List<Map<String, dynamic>> creditorList = [];
  bool isLoadingcreditpaylist = false;
  List<CreditorBalance> creditorpayList = [];
  bool isLoadingPaymentMethods = false;
  Map<String, List<String>> linkedAccounts = {};
  List<String> get paymentMethods => linkedAccounts.keys.toList();

  bool isloadingsalesview =false;
  List<Map<String, dynamic>> report = [];
  List<Map<String, dynamic>> stockreport = [];
  List<Map<String, dynamic>> profitAndLossRows = [];
  Map<String, dynamic> profitAndLossSummary = {};
  bool isLoadingProfitAndLoss = false;
  List<Map<String, dynamic>> stockreportraw = [];
  List<Map<String, dynamic>> salesregisterreport = [];
  bool isloadingsalesregister = false;
  List<dynamic> resultList = [];
  bool isloadingsalesreport = false;
  List<ItemModel> items = [];
  bool loading = true;
  StreamSubscription? sub;
  String? error;
  List<ConfigureVatModel> vatList = [];
  List<addTaxVatModel> addvatList = [];
  bool isloadingvatlist =false;
  bool isloadingaddvatlist =false;
  List<ProductModel> products = [];
  bool loadingproducts = false;
  Map<String, ModulePermission> _permissions = {};

  String stockReportSearchQuery = '';
  String stockDialogSearchQuery = '';
  String itemHistorySearchQuery = '';


  Datafeed() {
    _initSync();
    _initItemCache();
    initHamperListener();
    expireOutdatedCodes();
  }

  void updateSearch(String query) {
    searchQuery = query;
    _notify();
  }
  void updateStockReportSearch(String q) { stockReportSearchQuery = q; _notify(); }
  void updateStockDialogSearch(String q) { stockDialogSearchQuery = q; _notify(); }
  void updateItemHistorySearch(String q) { itemHistorySearchQuery = q; _notify(); }


  Stream<SalesSummary> StodayTotalsStream() {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final docId = "${companyid}_$today";

          return db
              .collection('salesSummary')
              .doc(docId)
              .snapshots()
              .map((snapshot) {
            if (!snapshot.exists) {
              return SalesSummary(
                total: 0,
                totalToday: 0,
                cash: 0,
                credit: 0,
                momo: 0,

                branchTotals: {},
              );
            }

            final data = snapshot.data()!;

            double totalToday = 0;
            double cash = 0;
            double credit = 0;
            double momo = 0;

            final Map<String, double> branchTotals = {};

            if (accesslevel.toLowerCase() == 'super admin') {
              totalToday = (data['companysales_value'] as num?)?.toDouble() ?? 0;

              credit = (data['credit'] as num?)?.toDouble() ?? 0;

              // Everything except credit is considered cash
              cash = totalToday - credit;
              momo = 0;

              final branches = Map<String, dynamic>.from(data['branchSummary'] ?? {});

              branches.forEach((key, value) {
                final branch = Map<String, dynamic>.from(value);

                branchTotals[branch['branchName'] ?? key] = (branch['branchsales_value'] as num?)?.toDouble() ?? 0;
              });
            } else {
              final branches =
              Map<String, dynamic>.from(data['branchSummary'] ?? {});

              if (branches.containsKey(branchid)) {
                final branch =
                Map<String, dynamic>.from(branches[branchid]);

                totalToday = (branch['branchsales_value'] as num?)?.toDouble() ?? 0;

                credit = (branch['credit'] as num?)?.toDouble() ?? 0;

                // Everything except credit is considered cash
                cash = totalToday - credit;
                momo = 0;

                branchTotals[branch['branchName'] ?? branchid] =
                    totalToday;
              }
            }

            return SalesSummary(
              total: totalToday,
              totalToday: totalToday,
              cash: cash,
              credit: credit,
              momo: momo,
              branchTotals: branchTotals,
            );
          });
        }

  Stream<DashboardStats> dashboardStatsStream() {
    if (companyid.isEmpty) {
      return Stream.value(
        DashboardStats(
          companySalesValue: 0,
          companyExpenseValue: 0,

          branchSalesValue: 0,
          branchExpenseValue: 0,

          companyStockValue: 0,
          branchStockValue: 0,

          companyCash: 0,
          companyCard: 0,
          companyCredit: 0,
          companyMomo: 0,
          companyBankTransfer: 0,
          companyopening_credit_bal: 0,
          companyDiscount: 0,
          companydebtpay_momo: 0,

          branchCash: 0,
          branchCard: 0,
          branchCredit: 0,
          branchMomo: 0,
          branchBankTransfer: 0,
          branchopening_credit_bal:0,
          smsBalance:0,
          branchDiscount:0,
           branchdebtpay_momo: 0

        ),
      );
    }

    return db.collection('dashbaord_stats').doc(companyid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return DashboardStats(
          companySalesValue: 0,
          companyExpenseValue: 0,

          branchSalesValue: 0,
          branchExpenseValue: 0,

          companyStockValue: 0,
          branchStockValue: 0,

          companyCash: 0,
          companyCard: 0,
          companyCredit: 0,
          companyMomo: 0,
          companyBankTransfer: 0,
          companyDiscount: 0,
          companydebtpay_momo:0,

          branchCash: 0,
          branchCard: 0,
          branchCredit: 0,
          branchMomo: 0,
          branchBankTransfer: 0,
          branchDiscount: 0,
          branchdebtpay_momo:0,

          companyopening_credit_bal: 0,
          branchopening_credit_bal: 0,
          smsBalance: 0,
        );
      }

      final data = snapshot.data()!;

      final branchSales = Map<String, dynamic>.from( data['branchsales'] ?? {}, );

      double companySalesValue = 0.0;
      double branchSalesValue = 0.0;

      // Company payment totals
      double companyCash = 0.0;
      double companyCard = 0.0;
      double companyCredit = 0.0;
      double companyMomo = 0.0;
      double companyBankTransfer = 0.0;
      double companyopening_credit_bal = 0.0;
      double companyDiscount = 0.0;
      double companydebtpay_momo = 0.0;
      double companydebtpay_cash = 0.0;
      double companydebtpay_card = 0.0;
      double companydebtpay_banktransfer = 0.0;
      double totaldebtpayment = 0.0;

      // Current branch payment totals
      double branchCash = 0.0;
      double branchCard = 0.0;
      double branchCredit = 0.0;
      double branchMomo = 0.0;
      double branchBankTransfer = 0.0;
      double branchopening_credit_bal = 0.0;
       smsBalance = (data['smsBalance'] as num?)?.toDouble() ?? 0.0;
       disCount = (data['company_Discount'] as num?)?.toDouble() ?? 0.0;
     double branchDiscount = 0.0;
     double branchdebtpay_momo = 0.0;
     double branchdebtpay_cash = 0.0;
     double branchdebtpay_card = 0.0;
     double branchdebtpay_banktransfer = 0.0;
     double branchdebtpay = 0.0;

      for (final entry in branchSales.entries) {
        if (entry.value is! Map) continue;

        final branchData =
        Map<String, dynamic>.from(
          entry.value as Map,
        );


        final salesValue =  (branchData['sales_value'] as num?) ?.toDouble() ?? 0.0;
        companySalesValue += salesValue;

        final cash = (branchData['cash'] as num?)?.toDouble() ?? 0.0;
        final card =  (branchData['card'] as num?)?.toDouble() ??  0.0;
        final credit = (branchData['credit'] as num?) ?.toDouble() ??0.0;
        final momo =   (branchData['momo'] as num?) ?.toDouble() ?? 0.0;
        final bankTransfer = (branchData['bank transfer'] as num?) ?.toDouble() ??  (branchData['bank_transfer'] as num?) ?.toDouble()?? 0.0;
        final opening_credit_bal = (branchData['opening_credit_bal'] as num?) ?.toDouble() ??  0.0;
        final discount = (branchData['discount'] as num?) ?.toDouble() ??  0.0;
        final debtpay_momo = (branchData['debtpay_momo'] as num?) ?.toDouble() ??  0.0;
        final debtpay_cash = (branchData['debtpay_cash'] as num?) ?.toDouble() ??  0.0;
        final debtpay_card = (branchData['debtpay_card'] as num?) ?.toDouble() ??  0.0;
        final debtpay_banktransfer = (branchData['debtpay_bank transfer'] as num?) ?.toDouble() ?? (branchData['debtpay_bank_transfer'] as num?) ?.toDouble()??  0.0;

        // Company totals
        companyCash += cash;
        companyCard += card;
        companyCredit += credit;
        companyMomo += momo;
        companyBankTransfer += bankTransfer;
        companyopening_credit_bal += opening_credit_bal;
        companyDiscount += discount;
        companydebtpay_momo+=debtpay_momo;
        totaldebtpayment+=(debtpay_momo+debtpay_cash+debtpay_card+debtpay_banktransfer);
        if (
        entry.key.toLowerCase() ==
            branchid.toLowerCase()
        ) {
          branchSalesValue = salesValue;

          branchCash = cash;
          branchCard = card;
          branchCredit = credit;
          branchMomo = momo;
          branchBankTransfer = bankTransfer;
          branchopening_credit_bal = opening_credit_bal;
          branchDiscount = discount;
          branchdebtpay_momo=debtpay_momo;
          branchdebtpay=(debtpay_momo+debtpay_cash+debtpay_card+debtpay_banktransfer);
        }
      }

      final branchExpenses = Map<String, dynamic>.from(
        data['branchexpense'] ?? {},
      );

      double companyExpenseValue = 0.0;
      double branchExpenseValue = 0.0;

      for (final entry in branchExpenses.entries) {
        if (entry.value is! Map) continue;

        final branchData =
        Map<String, dynamic>.from(
          entry.value as Map,
        );

        final expenseValue =
            (branchData['expense_value'] as num?)
                ?.toDouble() ??
                0.0;

        companyExpenseValue +=
            expenseValue;

        if (
        entry.key.toLowerCase() ==
            branchid.toLowerCase()
        ) {
          branchExpenseValue =
              expenseValue;
        }
      }


      final branchStock = Map<String, dynamic>.from(
        data['branchstock'] ?? {},
      );

      double companyStockValue = 0.0;
      double branchStockValue = 0.0;

      for (final entry in branchStock.entries) {
        if (entry.value is! Map) continue;

        final stockData =
        Map<String, dynamic>.from(
          entry.value as Map,
        );

        final stockValue =(stockData['stock_value'] as num?) ?.toDouble() ?? 0.0;
        companyStockValue += stockValue;

        if ( entry.key.toLowerCase() ==branchid.toLowerCase() ) {
          branchStockValue =stockValue;
        }
      }

      return DashboardStats(
        companySalesValue:companySalesValue,
        companyExpenseValue:companyExpenseValue,
        branchSalesValue:branchSalesValue,
        branchExpenseValue:branchExpenseValue,
        companyStockValue:companyStockValue,
        branchStockValue:branchStockValue,
        companyCash:companyCash,
        companyCard:companyCard,
        companyCredit:(companyCredit-totaldebtpayment),
        companyMomo:companyMomo,
        companyBankTransfer:companyBankTransfer,
        branchCash: branchCash,
        branchCard: branchCard,
        branchCredit: (branchCredit-branchdebtpay),
        branchMomo:branchMomo,
        branchBankTransfer:branchBankTransfer,
        companyopening_credit_bal:companyopening_credit_bal,
        branchopening_credit_bal: branchopening_credit_bal,
        smsBalance: smsBalance,
        companyDiscount: companyDiscount,
        branchDiscount: branchDiscount,
        companydebtpay_momo:companydebtpay_momo,
        branchdebtpay_momo:branchdebtpay_momo,
      );

    });
  }


  List<String> normalizeModes(Map<String, dynamic>? modes) {
    if (modes == null || modes.isEmpty) {
      return ['Single', 'Box'];
    }

    final modeList = modes.keys.map((key) {
      final modeData = modes[key] as Map<String, dynamic>?;
      return modeData?['name'] as String? ?? key;
    }).toList();

    // Move Single to the front if present
    final singleIndex = modeList.indexWhere(
          (mode) => mode.toLowerCase() == 'single',
    );
    if (singleIndex != -1) {
      final single = modeList.removeAt(singleIndex);
      modeList.insert(0, single);
    }
    return modeList;
  }

  Timestamp dayBoundaryTimestamp(dynamic date, {bool end = false}) {
    DateTime dt;
    if (date is Timestamp) {
      dt = date.toDate().toUtc();
    } else if (date is DateTime) {
      dt = date.toUtc();
    } else {
      throw ArgumentError('date must be DateTime or Timestamp');
    }

    if (!end) {
      return Timestamp.fromDate(DateTime.utc(dt.year, dt.month, dt.day));
    } else {
      final nextDay = DateTime.utc(dt.year, dt.month, dt.day + 1);
      return Timestamp.fromDate(
        nextDay.subtract(const Duration(milliseconds: 1)),
      );
    }
  }

  Future<void> _initItemCache() async {
    try {
      await itemCache.init();
      debugPrint('Item cache initialized');
    } catch (e) {
      debugPrint('Error initializing item cache: $e');
    }
  }

  void _initSync() {
    // Listen to Firestore snapshots metadata to detect offline/online status
    db.collection('_connection_check')
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      isOffline = snapshot.metadata.isFromCache;
      notifyListeners();
      debugPrint(isOffline ? '📴 App is OFFLINE' : '📶 App is ONLINE');
    });
  }
        bool _fetchingBranches = false;
        fetchBranches() async {
          if (_fetchingBranches || branches.isNotEmpty) return;
          _fetchingBranches = true;
          try {
            final snap = await db
                .collection('branches')
                .where("companyid", isEqualTo: companyid)
                .orderBy('date', descending: true)
            .get();
                //.get(const GetOptions(source: Source.serverAndCache));

            final seen = <String>{};
            branches = snap.docs
                .where((doc) => seen.add(doc.id))
                .map((doc) => BranchModel.fromJson(doc.data()))
                .toList();
print("Fetched ${branches.length} branches for company $companyid");
            notifyListeners();
          } catch (e) {
            debugPrint("Error fetching branches: $e");
          } finally {
            _fetchingBranches = false;
          }
        }

        refreshBranches() {
          branches.clear();
          fetchBranches();
        }

  Stream<List<Map<String, dynamic>>> itemsStream({
    required String? collectionName,
  }) {
    Query<Map<String, dynamic>> query = db .collection(collectionName!)
        .where("companyid", isEqualTo: companyid);
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
       Future<void> toggleItemActive({ required String docId, required bool newStatus, }) async {

          final idx = bundleview.indexWhere((e) => e['id'] == docId);
          if (idx != -1) {
            bundleview[idx]['isActive'] = newStatus;
            notifyListeners();
          }

          try {
            await db.collection('bundle').doc(docId).update({
              'isActive': newStatus,
            });
          } catch (e) {
            if (idx != -1) {
              bundleview[idx]['isActive'] = !newStatus;
              notifyListeners();
            }
            print("Error updating isActive: $e");
          }
        }
        Future<void> toggleNormalItemActive({ required String docId,  required bool newStatus,  }) async {
          final idx = items.indexWhere((e) => e.id == docId);
          //update
          if (idx != -1) {
            items[idx] = items[idx].copyWith(isActive: newStatus);
            notifyListeners();
          }

          try {
            await db.collection('itemsreg').doc(docId).update({
              'isActive': newStatus,
            });
          } catch (e) {
            if (idx != -1) {
              items[idx] = items[idx].copyWith(isActive: !newStatus);
              notifyListeners();
            }
            print("Error updating isActive: $e");
          }
        }

       Future<void> fetchSuppliers() async {
       try {

      final snap = await db .collection('suppliers').where("companyid", isEqualTo: companyid)
          .orderBy('datecreated', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      suppliers = snap.docs.map((doc) {
        return Supplier.fromMap(doc.data(), doc.id);
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching suppliers: $e");
    }
  }
     Future<void> addOrUpdateSupplier(Supplier supplier) async {
    String docId = supplier.id;
    Supplier toSave = supplier;

    if (docId.isEmpty) {
      docId = db.collection('suppliers').doc().id;
      toSave = Supplier.fromMap(supplier.toMap(), docId);
    }

    await db
        .collection('suppliers')
        .doc(docId)
        .set(toSave.toMap(), SetOptions(merge: true));

    final idx = suppliers.indexWhere((s) => s.id == docId);
    if (idx != -1) {
      suppliers[idx] = toSave;
    } else {
      suppliers.insert(0, toSave);
    }

    notifyListeners();
  }

  Future<void> deleteSupplier(String id) async {
    try {
      await db.collection('suppliers').doc(id).delete();
      suppliers.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting supplier: $e");
      rethrow;
    }
  }
       Future<void> fetchCustomers() async {
    try {
      final snap = await db .collection('customers').where("companyid", isEqualTo: companyid)
          .orderBy('createdat', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      customerlist = snap.docs.map((doc) {
        return CustomerRegModel.fromMap(doc.data(), doc.id);
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching customer list: $e");
    }
  }
       Future<void> fetchdamages({DateTimeRange? selectedDate, String? selectedBranch}) async {

        isloadingdamages = true;
        notifyListeners();

    try {
      final now = DateTime.now();
      final startDate = selectedDate?.start ?? now.subtract(const Duration(days: 60));
      final endDate = selectedDate?.end ?? now;

      String ymd(DateTime dt) =>
          '${dt.year.toString().padLeft(4, '0')}-'
              '${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')}';

      final start = ymd(startDate);
      final end = ymd(endDate);
      var query = db
          .collection('damageitems')
          .where("companyid", isEqualTo: companyid)
          .where('dateymd', isGreaterThanOrEqualTo: start)
          .where('dateymd', isLessThanOrEqualTo: end);

      if (selectedBranch != null && selectedBranch.isNotEmpty) {
        query = query.where('branchid', isEqualTo: selectedBranch);
      }

      final snap = await query
          .orderBy('dateymd', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      damages = snap.docs.map((doc) {
        return damageitemmodel.fromfirestore(doc.data() as Map<String,dynamic>, doc.id);
      }).toList();

      isloadingdamages = false;
      notifyListeners();
    } catch (e) {
      print(e);
      debugPrint("Error fetching damages: $e");
      isloadingdamages = false;
      notifyListeners();
    }
  }
        bool _disposed = false;

        @override
        void dispose() {
          _disposed = true;
          _salesSubscription?.cancel();
          super.dispose();
        }

        void _notify() {
          if (!_disposed) notifyListeners();
        }
        Future<void> fetchsalesreturn({DateTimeRange? selectedDate, String? selectedBranch}) async {

          try {
            isloadingsalesreturn = true;

           // notifyListeners();
            _notify();
            final now = DateTime.now();
            final startDate = selectedDate?.start ?? now.subtract(const Duration(days: 60));
            final endDate = selectedDate?.end ?? now;

            String ymd(DateTime dt) =>
                '${dt.year.toString().padLeft(4, '0')}-'
                    '${dt.month.toString().padLeft(2, '0')}-'
                    '${dt.day.toString().padLeft(2, '0')}';

            final start = ymd(startDate);
            final end = ymd(endDate);
            var query = db
                .collection('salesreturn')
                .where("returned_companyid", isEqualTo: companyid)
                .where('dateymd', isGreaterThanOrEqualTo: start)
                .where('dateymd', isLessThanOrEqualTo: end)
                .orderBy('dateymd', descending: true);

            if (selectedBranch != null && selectedBranch.isNotEmpty) {
              query = query.where('returned_branchid', isEqualTo: selectedBranch);
            }

            final snap = await query.get(const GetOptions(source: Source.serverAndCache));

            salesreturn = snap.docs
                .map((doc) => salereturn.fromfirestore(doc.data(), doc.id))
                .toList();
          } catch (e) {
            debugPrint("Error fetching Sales return: $e");
          }

          isloadingsalesreturn = false;
          //notifyListeners();
          _notify();
        }
      List<salereturn> filtersalesreturn() {
    if (searchQuery.isEmpty) return salesreturn;

    final q = searchQuery.toLowerCase();

    return salesreturn.where((s) {
      final Map<String, dynamic> itemMap = Map<String, dynamic>.from(s.items);

      final itemMatch = itemMap.values.any((item) {
        if (item is Map<String, dynamic>) {

          final ireceiptid = item['returned_receiptid']?.toString().toLowerCase() ?? '';
          final itemName = item['returned_item']?.toString().toLowerCase() ?? '';

          final itemId = item['returned_itemid']?.toString().toLowerCase() ?? '';

          final mode = item['returned_mode']?.toString().toLowerCase() ?? '';

          final reason = item['returned_reason']?.toString().toLowerCase() ?? '';

          final modeqty = item['returned_modeqty']?.toString().toLowerCase() ?? '';

          final price = item['returned_price']?.toString().toLowerCase() ?? '';

          final quantity = item['returned_quantity']?.toString().toLowerCase() ?? '';

          final totalamount = item['returned_totalamount']?.toString().toLowerCase() ??
              '';
          final totalpieces = item['returned_totalpieces']?.toString().toLowerCase() ??
              '';
          final barcode = item['returned_barcode']?.toString().toLowerCase() ?? '';

          return itemName.contains(q)||ireceiptid.contains(q) ||modeqty.contains(q) || price.contains(q) || totalamount.contains(q)
              || totalpieces.contains(q) || barcode.contains(q) || itemId.contains(q) || quantity.contains(q)
              || mode.contains(q) ||  reason.contains(q);
        }
        return false;
      });

      return itemMatch;
    }).toList();
  }

        Future<void> fetchsalesview({DateTimeRange? selectedDate, String? selectedBranch}) async {
          try {
            isloadingsalesview = true;
           // notifyListeners();
            _notify();
            final now = DateTime.now();
            final startDate = selectedDate?.start ?? now.subtract(const Duration(days: 60));
            final endDate = selectedDate?.end ?? now;

            String ymd(DateTime dt) =>
                '${dt.year.toString().padLeft(4, '0')}-'
                    '${dt.month.toString().padLeft(2, '0')}-'
                    '${dt.day.toString().padLeft(2, '0')}';

            final start = ymd(startDate);
            final end = ymd(endDate);
            Query query = db.collection('sales')
                .where("companyId", isEqualTo: companyid)
                .where('dateymd', isGreaterThanOrEqualTo: start)
                .where('dateymd', isLessThanOrEqualTo: end);

            if (selectedBranch != null && selectedBranch.isNotEmpty) {
              query = query.where('branchId', isEqualTo: selectedBranch);
            }

            final snap = await query
                .orderBy('dateymd', descending: true)
                .get(const GetOptions(source: Source.serverAndCache));
               salesview = snap.docs.map((doc) {
              try {
                return SalesModel.fromSnapshot(doc);
              } catch (e) {
                print("Failed to parse doc ${doc.id}: $e");
                return null;
              }
            }).whereType<SalesModel>().toList();

           // print("Total parsed: ${salesview.length}");

          } catch (e) {
            print("Error fetching Sales view: $e");
          } finally {

            isloadingsalesview = false;
           // notifyListeners();
            _notify();
          }
        }

        List<SalesModel> filtersalesview() {
          if (searchQuery.isEmpty) return salesview;

          final q = searchQuery.toLowerCase();

          return salesview.where((s) {

            final topLevelMatch =
                s.id.toLowerCase().contains(q) ||
                    s.companyId.toLowerCase().contains(q) ||
                    s.companyname.toLowerCase().contains(q) ||
                    s.branchId.toLowerCase().contains(q) ||
                    s.branchName.toLowerCase().contains(q) ||
                    (s.branchType ?? '').toLowerCase().contains(q) ||
                    (s.createdBy ?? '').toLowerCase().contains(q) ||
                    (s.approvedby ?? '').toLowerCase().contains(q) ||
                    (s.receiptby ?? '').toLowerCase().contains(q) ||
                    (s.printedby ?? '').toLowerCase().contains(q) ||
                    s.receiptNumber.toLowerCase().contains(q) ||
                    (s.transMode ?? '').toLowerCase().contains(q) ||
                    (s.customerId ?? '').toLowerCase().contains(q) ||
                    (s.customerName ?? '').toLowerCase().contains(q) ||
                    (s.customerPhone ?? '').toLowerCase().contains(q) ||
                    (s.pricingtype ?? '').toLowerCase().contains(q) ||
                    (s.paymentStatus ?? '').toLowerCase().contains(q) ||
                    s.totalamount.toString().contains(q) ||
                    s.amountPaid.toString().contains(q) ||
                    s.change.toString().contains(q) ||
                    s.staffPosition.toString().contains(q);

            final Map<String, dynamic> itemMap = Map<String, dynamic>.from(s.items ?? {}); // ✅ null-safe

            final itemMatch = itemMap.values.any((item) {
              if (item is Map<String, dynamic>) {
                final itemName = item['item']?.toString().toLowerCase() ?? '';
                final itemId = item['itemid']?.toString().toLowerCase() ?? '';
                final mode = item['mode']?.toString().toLowerCase() ?? '';
                final modeqty = item['modeqty']?.toString().toLowerCase() ?? '';
                final price = item['price']?.toString().toLowerCase() ?? '';
                final quantity = item['quantity']?.toString().toLowerCase() ?? '';
                final totalamount = item['totalamount']?.toString().toLowerCase() ?? '';
                final totalpieces = item['totalpieces']?.toString().toLowerCase() ?? '';
                final barcode = item['barcode']?.toString().toLowerCase() ?? '';

                return itemName.contains(q) ||
                    itemId.contains(q) ||
                    mode.contains(q) ||
                    modeqty.contains(q) ||
                    price.contains(q) ||
                    quantity.contains(q) ||
                    totalamount.contains(q) ||
                    totalpieces.contains(q) ||
                    barcode.contains(q);
              }
              return false;
            });

            return topLevelMatch || itemMatch;
          }).toList();
        }
        List<String> generateIds( String companyId, DateTime startDate, DateTime endDate, ) {
          List<String> ids = [];
          for ( DateTime d = startDate;
                 !d.isAfter(endDate);
                 d = d.add(const Duration(days: 1))
          )
          {
            final date = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

            ids.add("${companyId}_$date");
          }

          return ids;
        }
        List<String> generatestockIds( String companyId, DateTime start, DateTime end, ) {

          final ids = <String>[];

          for (
          DateTime date = start;
          !date.isAfter(end);
          date = date.add(
            const Duration(days: 1),
          )
          ) {

            final formatted =
            DateFormat('yyyy-MM-dd')
                .format(date);

            ids.add(
              '${companyId.toUpperCase()}_$formatted',
            );
          }

          return ids;
        }

        double reportTotalCashSales = 0.0;
        double reportTotalCreditSales = 0.0;
        double reportTotalCashReturns = 0.0;
        double reportTotalCreditReturns  = 0.0;
        double reportTotalReturns  = 0.0;
        double reportTotalDiscount = 0.0;
        double reportTotalDiscountReturn = 0.0;
        double reportTotalDamage= 0.0;
        double reportTotalPurchaseReturn = 0.0;
        double reportTotalProfit= 0.0;
        double reportTotalProfitReturn= 0.0;
        double reportTotalRowTotal = 0.0;
        double reportDebttotal= 0.0;
        double reportGrandTotal= 0.0;
        double reportCashAtHand = 0.0;

        List<Map<String, dynamic>> branchReport = [];
        List<Map<String, dynamic>> branchReportitem = [];
        // branch-level totals
        double branchTotalCashSales      = 0;
        double branchTotalCreditSales    = 0;
        double branchTotalCashReturns    = 0;
        double branchTotalCreditReturns  = 0;
        double branchTotalReturns        = 0;
        double branchTotalDiscount       = 0;
        double branchTotalDiscountReturn = 0;
        double branchTotalDamage         = 0;
        double branchTotalPurchaseReturn = 0;
        double branchTotalProfit         = 0;
        double branchTotalProfitReturn   = 0;
        double branchTotalRowTotal       = 0;
        double branchGrandTotal          = 0;
        double branchCashAtHand          = 0;
        double branchreportDebttotal     = 0;


     Future<void> fetchsalesreport({DateTimeRange? selectedDate, String? selectedBranch,  }) async {
    try {
      isloadingsalesreport = true;
      notifyListeners();

      report.clear();
      branchReport.clear();

      final now      = DateTime.now();
      final startStr = _toDateOnly(selectedDate?.start ?? now);
      final endStr   = _toDateOnly(selectedDate?.end   ?? now);

      final snap = await db
          .collection('salesSummary')
          .where('companyid',   isEqualTo: companyid)
          .where('summarydate', isGreaterThanOrEqualTo: startStr)
          .where('summarydate', isLessThanOrEqualTo:    endStr)
          .get(const GetOptions(source: Source.serverAndCache));

      if (snap.docs.isNotEmpty) {
        final raw = snap.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        report = extractItems(raw, selectedBranch);
        branchReport = extractbranch(raw, selectedBranch);
      } else {
        report       = [];
        branchReport = [];
      }

      _computeReportTotals();
      _computeBranchReportTotals();

    } catch (e) {
      print("fetchsalesreport error: $e");
      report   = [];
      branchReport = [];
      _computeReportTotals();
      _computeBranchReportTotals();
    } finally {
      isloadingsalesreport = false;
      notifyListeners();
    }
  }

      Map<String, dynamic> extractDebtPayments(
            List<Map<String, dynamic>> rawReport, {
              String? selectedBranch,
            }) {
          double grandTotal = 0;
          final Map<String, Map<String, dynamic>> byBranch = {};

          for (final doc in rawReport) {
            final staffSummary = doc['staffSummary'] as Map<String, dynamic>? ?? {};

            // iterate branch keys, filter if needed
            final Iterable<MapEntry<String, dynamic>> branchEntries =
            selectedBranch != null
                ? staffSummary.entries
                .where((e) => e.key == selectedBranch)
                : staffSummary.entries;

            for (final branchEntry in branchEntries) {
              final branchId   = branchEntry.key;
              final staffMap   = branchEntry.value as Map<String, dynamic>? ?? {};

              byBranch.putIfAbsent(branchId, () => {
                'branchId'  : branchId,
                'branchName': '',
                'total'     : 0.0,
                'byStaff'   : <String, Map<String, dynamic>>{},
              });

              final branchNode = byBranch[branchId]!;
              final byStaff    = branchNode['byStaff'] as Map<String, Map<String, dynamic>>;

              for (final staffEntry in staffMap.entries) {
                final email     = staffEntry.key;
                final staffData = staffEntry.value as Map<String, dynamic>? ?? {};

                final staffName  = staffData['staffName']?.toString()
                    ?? staffData['staff']?.toString()
                    ?? email;
                final branchName = staffData['branchName']?.toString() ?? branchId;
                final payment    = (staffData['debtpayments_value'] ?? 0).toDouble();

                // update branch name from first staff entry that has it
                if ((branchNode['branchName'] as String).isEmpty) {
                  branchNode['branchName'] = branchName;
                }

                byStaff.putIfAbsent(email, () => {
                  'staffName': staffName,
                  'email'    : email,
                  'total'    : 0.0,
                });

                byStaff[email]!['total'] =
                    (byStaff[email]!['total'] as double) + payment;

                branchNode['total'] =
                    (branchNode['total'] as double) + payment;

                grandTotal += payment;
              }
            }
          }

          return {
            'total'   : grandTotal,
            'byBranch': byBranch,
          };
        }

    void _computeReportTotals() {
    reportTotalCashSales      = 0;
    reportTotalCreditSales    = 0;
    reportTotalCashReturns    = 0;
    reportTotalCreditReturns  = 0;
    reportTotalReturns        = 0;
    reportTotalDiscount       = 0;
    reportTotalDiscountReturn = 0;
    reportTotalDamage         = 0;
    reportTotalPurchaseReturn = 0;
    reportTotalProfit         = 0;
    reportTotalProfitReturn   = 0;
    reportTotalRowTotal       = 0;

    for (final item in report) {
      reportTotalCashSales += (item['cashSales']?? 0.0) as double;
      reportTotalCreditSales    += (item['creditSales'] ?? 0.0) as double;
      reportTotalCashReturns    += (item['cashReturns'] ?? 0.0) as double;
      reportTotalCreditReturns  += (item['creditReturns'] ?? 0.0) as double;
      reportTotalReturns        += (item['returns'] ?? 0.0) as double;
      reportTotalDiscount       += (item['discount'] ?? 0.0) as double;
      reportTotalDiscountReturn += (item['return_discount'] ?? 0.0) as double;
      reportTotalDamage         += (item['damage_value']  ?? 0.0) as double;
      reportTotalPurchaseReturn += (item['purchaseReturn_value'] ?? 0.0) as double;
      reportTotalProfit         += (item['profit'] ?? 0.0) as double;
      reportTotalProfitReturn   += (item['return_profit'] ?? 0.0) as double;
      reportTotalRowTotal       += (item['rowtotal']  ?? 0.0) as double;
    }

    reportGrandTotal = reportTotalRowTotal ;
    reportCashAtHand = reportTotalCashSales - reportTotalCashReturns;
  }
    void _computeBranchReportTotals() {
    branchTotalCashSales      = 0;
    branchTotalCreditSales    = 0;
    branchTotalCashReturns    = 0;
    branchTotalCreditReturns  = 0;
    branchTotalReturns        = 0;
    branchTotalDiscount       = 0;
    branchTotalDiscountReturn = 0;
    branchTotalDamage         = 0;
    branchTotalPurchaseReturn = 0;
    branchTotalProfit         = 0;
    branchTotalProfitReturn   = 0;
    branchTotalRowTotal       = 0;
    branchreportDebttotal       = 0;

    for (final item in branchReport) {
      branchTotalCashSales += (item['cashSales']  ?? 0.0) as double;
      branchTotalCreditSales  += (item['creditSales'] ?? 0.0) as double;
      branchTotalCashReturns    += (item['cashReturns']  ?? 0.0) as double;
      branchTotalCreditReturns  += (item['creditReturns'] ?? 0.0) as double;
      branchTotalReturns        += (item['totalReturns']?? 0.0) as double;
      branchTotalDiscount       += (item['discount'] ?? 0.0) as double;
      reportTotalDiscountReturn += (item['return_discount'] ?? 0.0) as double;
      branchTotalDamage         += (item['damage_value'] ?? 0.0) as double;
      branchTotalPurchaseReturn += (item['purchaseReturn_value'] ?? 0.0) as double;
      branchTotalProfit         += (item['profit']?? 0.0) as double;
      reportTotalProfitReturn   += (item['return_profit'] ?? 0.0) as double;

      branchreportDebttotal     += (item['branchdebt'] ?? 0.0) as double;
    }
    branchTotalRowTotal = branchTotalCashSales  + branchTotalCreditSales;
    branchGrandTotal = branchTotalRowTotal;
    branchCashAtHand = branchTotalCashSales - branchTotalCashReturns;

  }
        List<Map<String, dynamic>> extractItems(List<Map<String, dynamic>> rawReport, String? selectedBranch, ) {
          final Map<String, Map<String, dynamic>> groupedItems = {};

          for (var company in rawReport) {
            final companyId   = company['companyid'] ?? '';
            final companyName = company['company']   ?? '';
            final branchSummary = company['branchSummary'] as Map<String, dynamic>? ?? {};

            final Iterable branches = selectedBranch == null
                ? branchSummary.values
                : [branchSummary[selectedBranch]].where((b) => b != null);

            for (var branch in branches) {
              final branchItems = branch['items'] as Map<String, dynamic>? ?? {};
              final branchName  = branch['branchName'] ?? '';
              final branchId    = branch['branchId']   ?? '';

              for (var item in branchItems.values) {
                final itemId = (item['itemid'] ?? '').toString();
                if (itemId.isEmpty) continue;

                final itemName = item['itemName'] ?? item['barcode'] ?? '';

                final cash= (item['cash'] ?? 0).toDouble();
                final credit = (item['credit'] ?? 0).toDouble();
                final damageQty = (item['damage_qty'] ?? 0).toDouble();
                final damageValue = (item['damage_value'] ?? 0).toDouble();
                final discount  = (item['discount']?? 0).toDouble();

                final purchaseReturnQty = (item['purchaseReturn_qty']  ?? 0).toDouble();
                final purchaseReturnValue = (item['purchaseReturn_value']?? 0).toDouble();
                final salesQty  = (item['sales_qty'] ?? 0).toDouble();

                final salesReturnQty = (item['salesReturn_qty'] ?? 0).toDouble();
                final returns  = (item['salesReturn_value']   ?? 0).toDouble();
                final cashreturn = (item['cash_returns']?? 0).toDouble();
                final creditreturn = (item['credit_returns'] ?? 0).toDouble();
                final itemCost  = (item['costof_goods'] ?? 0).toDouble();
                final salesValue  = (item['sales_value'] ?? 0).toDouble();
                final profit  = (item['profit'] ?? 0).toDouble();
                final returnProfit  = (item['return_profit'] ?? 0).toDouble();
                final returnDiscount = (item['return_discount'] ?? 0).toDouble();

               // final totalReturns = returns > 0 ? returns : (cashreturn + creditreturn);
                final totalReturns = cashreturn + creditreturn;
                final rowtotal     = (cash + credit) - totalReturns;
                final netDiscount  = discount - returnDiscount;
                final netProfit    = profit - returnProfit;
                groupedItems.putIfAbsent(itemId, () => {
                  'item': itemName,
                  'branchName': branchName,
                  'branchId': branchId,
                  'company': companyName,
                  'companyid': companyId,
                  'itemid':itemId,
                  'quantity': 0.0,
                  'returns': 0.0,
                  'cashSales':0.0,
                  'creditSales':0.0,
                  'damage_qty':0.0,
                  'damage_value': 0.0,
                  'damage':0.0,
                  'discount':0.0,
                  'purchaseReturn_qty':0.0,
                  'purchaseReturn_value':0.0,
                  'sales_qty':0.0,
                  'cashReturns':0.0,
                  'creditReturns':0.0,
                  'totalSales':0.0,
                  'totalcost':0.0,
                  'profit':0.0,
                  'rowtotal':0.0,
                  'sales_value':0.0,
                  'cost_of_goods':0.0,
                  'return_profit':0.0,
                  'return_discount':0.0,
                });

                final e = groupedItems[itemId]!;
                e['quantity'] += salesQty;
                e['cashSales'] += cash;
                e['creditSales']+= credit;
                e['damage_qty'] += damageQty;
                e['damage_value'] += damageValue;
                e['damage'] += damageValue;
                e['discount'] += netDiscount;
                e['purchaseReturn_qty'] += purchaseReturnQty;
                e['purchaseReturn_value'] += purchaseReturnValue;
                e['sales_qty'] += salesQty;
                e['cashReturns'] += cashreturn;
                e['creditReturns']+= creditreturn;
                e['returns'] += returns;
                e['totalSales'] += rowtotal;
                e['totalcost']+= itemCost;
                e['rowtotal'] += rowtotal;
                e['sales_value'] += salesValue;
                e['cost_of_goods'] += itemCost;
                e['profit']  +=netProfit ;

                e['return_profit']   = (e['return_profit']   ?? 0.0) + returnProfit;
                e['return_discount'] = (e['return_discount'] ?? 0.0) + returnDiscount;
              }
            }
          }

          return groupedItems.values.toList();
        }

        List<Map<String,dynamic>> filtersalesreport(){
    if(searchQuery.isEmpty) return report;
      final q =searchQuery.toLowerCase();
      return report.where((searched){
        final item =searched['item']?.toString().toLowerCase()?? '';
        final branchName =searched['branchName']?.toString().toLowerCase()?? '';
        final branchId =searched['branchId']?.toString().toLowerCase()?? '';
        final company =searched['company']?.toString().toLowerCase()?? '';
        final itemid =searched['itemid']?.toString().toLowerCase()?? '';
        final companyid =searched['companyid']?.toString().toLowerCase()?? '';
        final quantity =searched['quantity']?.toString().toLowerCase()?? '';
        final returns =searched['returns']?.toString().toLowerCase()?? '';
        final cashSales =searched['cashSales']?.toString().toLowerCase()?? '';
        final creditSales =searched['creditSales']?.toString().toLowerCase()?? '';
        final damage_qty =searched['damage_qty']?.toString().toLowerCase()?? '';
        final damage_value =searched['damage_value']?.toString().toLowerCase()?? '';
        final discount =searched['discount']?.toString().toLowerCase()?? '';
        final purchaseReturn_qty =searched['purchaseReturn_qty']?.toString().toLowerCase()?? '';
        final purchaseReturn_value =searched['purchaseReturn_value']?.toString().toLowerCase()?? '';
        final sales_qty =searched['sales_qty']?.toString().toLowerCase()?? '';
        final cashReturns_qty =searched['cashReturns_qty']?.toString().toLowerCase()?? '';
        final creditReturns_qty =searched['creditReturns_qty']?.toString().toLowerCase()?? '';
        final cashReturns =searched['cashReturns']?.toString().toLowerCase()?? '';
        final creditReturns =searched['creditReturns']?.toString().toLowerCase()?? '';
        final totalSales =searched['totalSales']?.toString().toLowerCase()?? '';
        final totalcost =searched['totalcost']?.toString().toLowerCase()?? '';
        final profit =searched['profit']?.toString().toLowerCase()?? '';
        final damage =searched['damage']?.toString().toLowerCase()?? '';
        final rowtotal =searched['rowtotal']?.toString().toLowerCase()?? '';
        return item.contains(q) ||
              branchName.contains(q) ||
            branchId.contains(q) ||
            company.contains(q) ||
            purchaseReturn_qty.contains(q) ||
            sales_qty.contains(q) ||
            creditReturns_qty.contains(q) ||
            purchaseReturn_value.contains(q) ||
            discount.contains(q) ||
            cashReturns_qty.contains(q) ||
            itemid.contains(q) ||
            damage_value.contains(q) ||
            quantity.contains(q) ||
            damage_qty.contains(q) ||
            cashSales.contains(q) ||
            creditSales.contains(q) ||
            companyid.contains(q) ||
            returns.contains(q) ||
            damage.contains(q) ||
            profit.contains(q) ||
            totalcost.contains(q) ||
            totalSales.contains(q) ||
            creditReturns.contains(q) ||
            cashReturns.contains(q) ||
             rowtotal.contains(q);
      }).toList();

    }
        List<Map<String, dynamic>> extractbranch(List<Map<String, dynamic>> rawReport, String? selectedBranch,) {
          final Map<String, Map<String, dynamic>> grouped = {};

          for (var company in rawReport) {
            final companyId   = (company['companyid'] ?? '').toString();
            final companyName = (company['company']   ?? '').toString();
            final branchSummary = company['branchSummary'] as Map<String, dynamic>? ?? {};

            final Iterable<dynamic> branches = selectedBranch == null
                ? branchSummary.values
                : [branchSummary[selectedBranch]].where((b) => b != null);

            for (var branch in branches) {
              final branchId   = (branch['branchId']   ?? '').toString();
              final branchName = (branch['branchName'] ?? '').toString();
              if (branchId.isEmpty) continue;

              final cash = (branch['cash'] ?? 0).toDouble();
              final credit = (branch['credit'] ?? 0).toDouble();
              final momo = (branch['momo'] ?? 0).toDouble();
              final merchantmomo = (branch['merchantmomo'] ?? branch['momo'] ?? 0).toDouble();
              final hubtel = (branch['hubtel'] ?? 0).toDouble();
              final card = (branch['card'] ?? 0).toDouble();
              final bank = (branch['bank'] ?? 0).toDouble();
              final cheque = (branch['cheque'] ?? 0).toDouble();

              final discount = (branch['branch_Discount'] ?? branch['branchDiscount'] ?? 0).toDouble();
              final returnDiscount  = (branch['branch_returnDiscount'] ?? 0).toDouble();
              final profit    = (branch['branch_profit'] ?? 0).toDouble();
              final returnProfit    = (branch['branch_returnprofit'] ?? 0).toDouble();

              final salesQty    = (branch['branchsales_qty'] ?? 0).toDouble();
              final salesValue  = (branch['branchsales_value']  ?? 0).toDouble();
              final costOfGoods = (branch['branchCostof_goods']  ?? 0).toDouble();

              final txnCount    = (branch['branchtransaction_count'] ?? 0).toDouble();
              double branchdebt = (branch['branchdebt']  ?? 0).toDouble();
              double cashReturns   = (branch['branch_cash_returns'] ?? 0).toDouble();
              double creditReturns  = (branch['branch_credit_returns'] ?? 0).toDouble();
              double salesReturns   = (branch['branchsalesReturn_value'] ?? 0).toDouble();
              double damageQty      = (branch['damage_qty'] ?? 0).toDouble();
              double damageValue     = (branch['damage_value'] ?? 0).toDouble();
              double purchaseReturnQty   = (branch['purchaseReturn_qty'] ?? 0).toDouble();
              double purchaseReturnValue = (branch['purchaseReturn_value'] ?? 0).toDouble();

              final items = branch['items'] as Map<String, dynamic>? ?? {};

              if (cashReturns == 0 && creditReturns == 0 && salesReturns == 0) {
                for (var item in items.values) {
                  cashReturns    += (item['cash_returns']  ?? 0).toDouble();
                  creditReturns  += (item['credit_returns']  ?? 0).toDouble();
                  salesReturns   += (item['salesReturn_value']  ?? 0).toDouble();
                  damageQty      += (item['damage_qty']  ?? 0).toDouble();
                  damageValue    += (item['damage_value']  ?? 0).toDouble();
                  purchaseReturnQty += (item['purchaseReturn_qty'] ?? 0).toDouble();
                  purchaseReturnValue += (item['purchaseReturn_value'] ?? 0).toDouble();
                }
              }

              final totalReturns = salesReturns > 0 ? salesReturns : (cashReturns + creditReturns);


              final totalSales = (merchantmomo + hubtel + card + bank + cheque) > 0
                  ? merchantmomo + hubtel + card + bank + cheque
                  : cash + credit + momo;
              final rowTotal   = totalSales - totalReturns - discount;
              final netDiscount = discount - returnDiscount;
              final netProfit   = profit - returnProfit ;


              grouped.putIfAbsent(branchId, () => {
                'branchId':             branchId,
                'branchName':           branchName,
                'company':              companyName,
                'companyid':            companyId,
                'sales_qty':            0.0,
                'cashSales':            0.0,
                'creditSales':          0.0,
                'momo':                 0.0,
                'merchantmomo':         0.0,
                'hubtel':              0.0,
                'card':                0.0,
                'bank':                0.0,
                'cheque':              0.0,
                'cashReturns':          0.0,
                'creditReturns':        0.0,
                'salesReturns':         0.0,
                'totalReturns':         0.0,
                'discount':             0.0,
                'damage_qty':           0.0,
                'damage_value':         0.0,
                'purchaseReturn_qty':   0.0,
                'purchaseReturn_value': 0.0,
                'sales_value':          0.0,
                'cost_of_goods':        0.0,
                'profit':               0.0,
                'totalSales':           0.0,
                'rowTotal':             0.0,
                'transaction_count':    0.0,
                'branchdebt':    0.0,
              });

              final e = grouped[branchId]!;
              e['sales_qty'] = (e['sales_qty']  as double) + salesQty;
              e['cashSales']   = (e['cashSales'] as double) + cash;
              e['creditSales'] = (e['creditSales']  as double) + credit;
              e['momo'] = (e['momo']  as double) + momo;
              e['merchantmomo'] = (e['merchantmomo'] as double) + merchantmomo;
              e['hubtel'] = (e['hubtel'] as double) + hubtel;
              e['card'] = (e['card'] as double) + card;
              e['bank'] = (e['bank'] as double) + bank;
              e['cheque'] = (e['cheque'] as double) + cheque;
              e['cashReturns'] = (e['cashReturns'] as double) + cashReturns;
              e['creditReturns'] = (e['creditReturns']  as double) + creditReturns;
              e['salesReturns']  = (e['salesReturns']  as double) + salesReturns;
              e['totalReturns']  = (e['totalReturns']  as double) + totalReturns;
              e['discount']      = (e['discount']   as double) + netDiscount;
              e['damage_qty']     = (e['damage_qty']  as double) + damageQty;
              e['damage_value']    = (e['damage_value']    as double) + damageValue;
              e['purchaseReturn_qty']   = (e['purchaseReturn_qty'] as double) + purchaseReturnQty;
              e['purchaseReturn_value'] = (e['purchaseReturn_value'] as double) + purchaseReturnValue;
              e['sales_value']   = (e['sales_value']    as double) + salesValue;
              e['cost_of_goods']    = (e['cost_of_goods']  as double) + costOfGoods;
              e['profit']      = (e['profit']   as double) + netProfit;
              e['totalSales']    = (e['totalSales']   as double) + totalSales;
              e['rowTotal']  = (e['rowTotal']    as double) + rowTotal;
              e['transaction_count']  = (e['transaction_count'] as double) + txnCount;
              e['branchdebt']  = (e['branchdebt'] as double) + branchdebt;
            }
          }

          return grouped.values.toList();
        }

        List<Map<String, dynamic>> filterbranchsalesreport() {
    if (searchQuery.isEmpty) return branchReport;
    final q = searchQuery.toLowerCase();
    return branchReport.where((row) {
      final fields = [
        row['branchName'], row['branchId'], row['company'], row['companyid'],
        row['sales_qty'], row['merchantmomo'], row['hubtel'], row['card'], row['bank'], row['cheque'],
        row['cashSales'], row['creditSales'], row['momo'],
        row['cashReturns'], row['creditReturns'], row['totalReturns'],
        row['discount'], row['damage_qty'], row['damage_value'],
        row['purchaseReturn_qty'], row['purchaseReturn_value'],
        row['sales_value'], row['cost_of_goods'], row['profit'],
        row['totalSales'], row['rowTotal'], row['transaction_count'],
      ];
      return fields.any((f) => f?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

        Map<String, dynamic> calcGrandTotal(List<Map<String, dynamic>> rows) {
          const keys = [
            'sales_qty', 'cashSales', 'creditSales', 'momo',
            'cashReturns', 'creditReturns', 'salesReturns', 'totalReturns',
            'discount', 'damage_qty', 'damage_value',
            'purchaseReturn_qty', 'purchaseReturn_value',
            'sales_value', 'cost_of_goods', 'profit', 'totalSales',
            'rowTotal', 'transaction_count',
          ];

          final Map<String, dynamic> totals = {
            for (var k in keys) k: 0.0,
            'branchName': 'Grand Total',
            'branchId':   '',
            'company':    '',
            'companyid':  '',
          };

          for (var row in rows) {
            for (var k in keys) {
              totals[k] = (totals[k] as double) + ((row[k] ?? 0.0) as double);
            }
          }
          return totals;
        }

       bool isloadingbranchitem =false;
        Future<void> loadBranchItemsReport({required DateTime startDate,required DateTime endDate,String? branchId,}) async {
          isloadingbranchitem = true;
         notifyListeners();

          try {

          final List<String> dateStrings = [];
          DateTime cursor = DateTime(startDate.year, startDate.month, startDate.day);
          final endDay    = DateTime(endDate.year,   endDate.month,   endDate.day);
          while (!cursor.isAfter(endDay)) {
          dateStrings.add(DateFormat('yyyy-MM-dd').format(cursor));
          cursor = cursor.add(const Duration(days: 1));
          }

          final List<Map<String, dynamic>> fetched = [];

          for (final dateStr in dateStrings) {

          final docId = '${companyid}_$dateStr';
          final doc = await db
          .collection('salesSummary')
                  .doc(docId)
              .get();

          if (doc.exists && doc.data() != null) {
            fetched.add(doc.data()! as Map<String, dynamic>);
          }
          }


          branchReportitem    = extractBranchItems(fetched, branchId);
          } catch (e) {
            debugPrint('loadBranchItemsReport error: $e');
            report = [];
          }

          isloadingbranchitem = false;
          notifyListeners();
          }
        double _d(dynamic v) {
          if (v == null) return 0.0;
          if (v is double) return v;
          if (v is int)    return v.toDouble();
          return (v as num).toDouble();
        }


        String _str(dynamic v) => v?.toString() ?? '';
        List<Map<String, dynamic>> extractBranchItems(List<Map<String, dynamic>> rawReport, String? selectedBranch, ) {
          // grouped by "branchId__itemId"
          final Map<String, Map<String, dynamic>> grouped = {};

          for (final doc in rawReport) {
            final companyId   = _str(doc['companyid']);
            final companyName = _str(doc['company']);

            // branchSummary keys ARE the branchIds
            final branchSummary = doc['branchSummary'] as Map<String, dynamic>? ?? {};

            for (final branchEntry in branchSummary.entries) {
              final branchKey  = branchEntry.key;   // e.g. "ks005yagaba"
              final branchData = branchEntry.value as Map<String, dynamic>? ?? {};

              // If a branch filter
              if (selectedBranch != null && branchKey != selectedBranch) continue;

              final branchId   = _str(branchData['branchId']   ?? branchKey);
              final branchName = _str(branchData['branchName'] ?? '');

              // items map is inside the branch map
              final items = branchData['items'] as Map<String, dynamic>? ?? {};

              for (final itemEntry in items.entries) {
                final itemId   = itemEntry.key;
                final itemData = itemEntry.value as Map<String, dynamic>? ?? {};

                final itemName       = _str(itemData['itemName']);
                final itemBranchId   = _str(itemData['branchId']   ?? branchId);
                final itemBranchName = _str(itemData['branchName'] ?? branchName);

                // Exact Firestore field names from your structure
                final cashSales   = _d(itemData['cash']);
                final creditSales = _d(itemData['credit']);
                final momo        = _d(itemData['momo']);
                final salesQty    = _d(itemData['sales_qty']);
                final salesValue  = _d(itemData['sales_value']);
                final costOfGoods = _d(itemData['costof_goods']);
                final discount    = _d(itemData['discount']);
                final txnCount    = _d(itemData['transaction_count']);
                final profit      = _d(itemData['profit']);
                final return_profit      = _d(itemData['return_profit']);
                final return_discount      = _d(itemData['return_discount']);

                // Returns — default 0 if not yet in your data
                final cashReturns         = _d(itemData['cash_returns']);
                final creditReturns       = _d(itemData['credit_returns']);
                final salesReturns        = _d(itemData['salesReturn_value']);
                final damageQty           = _d(itemData['damage_qty']);
                final damageValue         = _d(itemData['damage_value']);
                final purchaseReturnQty   = _d(itemData['purchaseReturn_qty']);
                final purchaseReturnValue = _d(itemData['purchaseReturn_value']);
                final totalReturns        = salesReturns > 0
                    ? salesReturns : (cashReturns + creditReturns);

                // Calculations
                final totalSales = cashSales + creditSales + momo;
                final rowTotal   = cashSales - cashReturns ;

                final groupKey = '${branchId}__$itemId';

                grouped.putIfAbsent(groupKey, () => {
                  'itemid':               itemId,
                  'item':                 itemName,
                  'branchId':             itemBranchId,
                  'branchName':           itemBranchName,
                  'company':              companyName,
                  'companyid':            companyId,
                  'sales_qty':            0.0,
                  'quantity':             0.0,
                  'cashSales':            0.0,
                  'creditSales':          0.0,
                  'momo':                 0.0,
                  'cashReturns':          0.0,
                  'creditReturns':        0.0,
                  'salesReturns':         0.0,
                  'returns':              0.0,
                  'totalReturns':         0.0,
                  'discount':             0.0,
                  'damage_qty':           0.0,
                  'damage_value':         0.0,
                  'purchaseReturn_qty':   0.0,
                  'purchaseReturn_value': 0.0,
                  'sales_value':          0.0,
                  'cost_of_goods':        0.0,
                  'profit':               0.0,
                  'return_profit':        0.0,
                  'return_discount':      0.0,
                  'totalSales':           0.0,
                  'rowtotal':             0.0,
                  'transaction_count':    0.0,
                });

                final e = grouped[groupKey]!;
                // Accumulate — multi-day ranges add up correctly
                e['sales_qty']  = (e['sales_qty'] as double) + salesQty;
                e['quantity']   = (e['quantity']  as double) + salesQty;
                e['cashSales']  = (e['cashSales'] as double) + cashSales;
                e['creditSales'] = (e['creditSales'] as double) + creditSales;
                e['momo']  = (e['momo'] as double) + momo;
                e['cashReturns']  = (e['cashReturns'] as double) + cashReturns;
                e['creditReturns'] = (e['creditReturns']as double) + creditReturns;
                e['salesReturns'] = (e['salesReturns'] as double) + salesReturns;
                e['returns']  = (e['returns'] as double) + totalReturns;
                e['totalReturns']  = (e['totalReturns'] as double) + totalReturns;
                e['discount'] = (e['discount'] as double) + (discount - return_discount);
                e['return_discount']   = (e['return_discount'] as double) + return_discount;
                e['damage_qty']  = (e['damage_qty']  as double) + damageQty;
                e['damage_value'] = (e['damage_value'] as double) + damageValue;
                e['purchaseReturn_qty'] = (e['purchaseReturn_qty'] as double) + purchaseReturnQty;
                e['purchaseReturn_value'] = (e['purchaseReturn_value'] as double) + purchaseReturnValue;
                e['sales_value']     = (e['sales_value']  as double) + salesValue;
                e['cost_of_goods']   = (e['cost_of_goods']  as double) + costOfGoods;
                e['profit']   = (e['profit']   as double) + (profit   - return_profit);
                e['return_profit']    = (e['return_profit'] as double) + return_profit;
                e['totalSales']    = (e['totalSales'] as double) + totalSales;
                e['rowtotal']  = (e['rowtotal'] as double) + rowTotal;
                e['transaction_count'] = (e['transaction_count'] as double) + txnCount;
              }
            }
          }

          return grouped.values.toList();
        }
        List<Map<String, dynamic>> filterBranchItems() {
          if (searchQuery.isEmpty) return branchReportitem;
          final q = searchQuery.toLowerCase();
          return report.where((item) {
            final itemName   = (item['item']       ?? '').toString().toLowerCase();
            final branchName = (item['branchName'] ?? '').toString().toLowerCase();
            final itemId     = (item['itemid']     ?? '').toString().toLowerCase();
            return itemName.contains(q)
                || branchName.contains(q)
                || itemId.contains(q);
          }).toList();
        }


  Map<String, double> computeBranchItemTotals(
      List<Map<String, dynamic>> filteredList) {
    double totalCashSales     = 0;
    double totalCreditSales   = 0;
    double totalMomo          = 0;
    double totalMomoReturn    = 0;
    double totalCashReturns   = 0;
    double totalCreditReturns = 0;
    double totalReturns       = 0;
    double totalDiscount      = 0;
    double totalProfit        = 0;
    double totalRowTotal      = 0;
    double totalSalesQty      = 0;
    double totalSalesValue    = 0;
    double totalCostOfGoods   = 0;
    double totalTxnCount      = 0;

    for (final item in filteredList) {
      final cashSales     = _d(item['cashSales']);
      final creditSales   = _d(item['creditSales']);
      final momo          = _d(item['momo']);
      final momoreturn    = _d(item['momoreturns']);
      final cashReturns   = _d(item['cashReturns']);
      final creditReturns = _d(item['creditReturns']);
      final returns       = _d(item['totalReturns']);
      final discount      = _d(item['discount']);
      final profit        = _d(item['profit']);
      final rowtotal      = _d(item['rowtotal']);
      final salesQty      = _d(item['sales_qty']);
      final salesValue    = _d(item['sales_value']);
      final costOfGoods   = _d(item['cost_of_goods']);
      final txnCount      = _d(item['transaction_count']);


      totalCashSales     += cashSales;
      totalCreditSales   += creditSales;
      totalMomo          += momo;
      totalMomoReturn    += momoreturn;
      totalCashReturns   += cashReturns;
      totalCreditReturns += creditReturns;
      totalReturns       += returns;
      totalDiscount      += discount ;
      totalProfit        += profit;
      totalRowTotal      += rowtotal;
      totalSalesQty      += salesQty;
      totalSalesValue    += salesValue;
      totalCostOfGoods   += costOfGoods;
      totalTxnCount      += txnCount;
    }


    final globalCashAtHand =
        (totalCashSales + totalMomo) - totalCashReturns - totalMomo;


    final grandTotal = totalRowTotal;

    return {
      'totalCashSales'    : totalCashSales,
      'totalCreditSales'  : totalCreditSales,
      'totalMomo'         : totalMomo,
      'totalMomoReturn'   : totalMomoReturn,
      'totalCashReturns'  : totalCashReturns,
      'totalCreditReturns': totalCreditReturns,
      'totalReturns'      : totalReturns,
      'totalDiscount'     : totalDiscount,
      'totalProfit'       : totalProfit,
      'totalRowTotal'     : totalRowTotal,
      'totalSalesQty'     : totalSalesQty,
      'totalSalesValue'   : totalSalesValue,
      'totalCostOfGoods'  : totalCostOfGoods,
      'totalTxnCount'     : totalTxnCount,
      'grandTotal'        : grandTotal,
      'globalCashAtHand'  : globalCashAtHand,
    };
  }
        // Future<void> fetchsalesregister({ DateTimeRange? selectedDate, String? selectedBranch,  }) async {
        //   try {
        //     isloadingsalesregister = true;
        //     notifyListeners();
        //
        //     salesregisterreport.clear();
        //
        //     final now = DateTime.now();
        //     final startStr = _toDateOnly(selectedDate?.start ?? now);
        //     final endStr = _toDateOnly(selectedDate?.end ?? now);
        //
        //     final snap = await db
        //         .collection('salesSummary')
        //         .where('companyid', isEqualTo: companyid)
        //         .where('summarydate', isGreaterThanOrEqualTo: startStr)
        //         .where('summarydate', isLessThanOrEqualTo: endStr)
        //         .get();
        //
        //     final docs = snap.docs;
        //     if (docs.isEmpty) return;
        //
        //     final Map<String, Map<String, dynamic>> grouped = {};
        //
        //     final isCompany = selectedBranch == null;
        //
        //     for (final doc in docs) {
        //       final d = doc.data();
        //
        //
        //       if (isCompany) {
        //         final key = companyid;
        //
        //         final group = grouped.putIfAbsent(key, () => {
        //           'branch': companyid,
        //           'branchName': d['company'] ?? 'Company Total',
        //           'quantity': 0.0,
        //           'cashSales': 0.0,
        //           'creditSales': 0.0,
        //           'cashReturns': 0.0,
        //           'creditReturns': 0.0,
        //           'cashDiscount': 0.0,
        //           'costOfGoods': 0.0,
        //           'salesValue': 0.0,
        //           'damages': 0.0,
        //           'profit': 0.0,
        //           'profitreturn': 0.0,
        //           'cashAtHand': 0.0,
        //           'cashDiscountreturn': 0.0,
        //         });
        //
        //        group['quantity'] += ((d['companysales_qty'] ?? 0) - (d['companysales_returns'] ?? 0)).toDouble();
        //         group['profit'] += (d['profit'] ?? 0).toDouble();
        //         final branchSummaryForProfit = d['branchSummary'] as Map<String, dynamic>?;
        //
        //
        //         if (group['profit'] == 0.0) {
        //           final branchSummaryForProfit = d['branchSummary'] as Map<String, dynamic>?;
        //           if (branchSummaryForProfit != null) {
        //             for (final b in branchSummaryForProfit.values) {
        //               final items = b['items'] as Map<String, dynamic>?;
        //               if (items != null) {
        //                 for (final item in items.values) {
        //                   group['profit'] += ((item['profit'] ?? 0).toDouble()-(item['return_profit'] ?? 0).toDouble());
        //
        //                 }
        //               }
        //             }
        //           }
        //         }
        //         group['cashSales'] += (d['cash'] ?? 0).toDouble();
        //         group['creditSales'] += (d['credit'] ?? 0).toDouble();
        //
        //         group['cashReturns'] += (d['companycash_returns'] ?? 0).toDouble();
        //         group['creditReturns'] += (d['companycredit_returns'] ?? 0).toDouble();
        //
        //         group['cashDiscount'] += (d['company_Discount'] ?? 0).toDouble();
        //         group['cashDiscountreturn'] += (d['company_Discountreturn'] ?? 0).toDouble();
        //
        //         group['profit'] += (d['company_profit'] ?? 0).toDouble();
        //         group['profitreturn'] += (d['company_profitreturn'] ?? 0).toDouble();
        //         group['costOfGoods'] += (d['companyCostof_goods'] ?? 0).toDouble();
        //         group['salesValue'] += (d['companysales_value'] ?? 0).toDouble();
        //         group['damages'] += (d['companydamage_value'] ?? 0).toDouble();
        //       }
        //
        //
        //       else {
        //         final branchSummary = d['branchSummary'] as Map<String, dynamic>?;
        //
        //         if (branchSummary == null) continue;
        //
        //         for (final entry in branchSummary.entries) {
        //           final branchId = entry.key;
        //           final b = entry.value;
        //
        //           if (b == null) continue;
        //
        //           final realBranchId = (b['branchId'] ?? branchId).toString();
        //
        //
        //           if (selectedBranch != null && realBranchId != selectedBranch) {
        //             continue;
        //           }
        //
        //           final group = grouped.putIfAbsent(realBranchId, () => {
        //             'branch': realBranchId,
        //             'branchName': b['branchName'] ?? '',
        //             'quantity': 0.0,
        //             'cashSales': 0.0,
        //             'creditSales': 0.0,
        //             'cashReturns': 0.0,
        //             'creditReturns': 0.0,
        //             'cashDiscount': 0.0,
        //             'costOfGoods': 0.0,
        //             'salesValue': 0.0,
        //             'damages': 0.0,
        //             'profit': 0.0,
        //             'cashAtHand': 0.0,
        //             'branchsalesReturn_value': 0.0,
        //           });
        //
        //          group['quantity'] += ((b['branchsales_qty'] ?? 0) - (b['branchsalesReturn_qty'] ?? 0)).toDouble();
        //           group['cashSales'] += (b['cash'] ?? 0).toDouble();
        //           group['creditSales'] += (b['credit'] ?? 0).toDouble();
        //           group['profit'] += ((b['branch_profit'] ?? 0).toDouble()- (b['branch_returnprofit'] ?? 0).toDouble());
        //           final branchItems = b['items'] as Map<String, dynamic>?;
        //          // if(group['profit'] ==0.0){}
        //           if (branchItems != null) {
        //             for (final item in branchItems.values) {
        //               group['profit'] += ((item['profit'] ?? 0).toDouble()-(item['return_profit'] ?? 0).toDouble());
        //             }
        //           }
        //           group['cashReturns'] += (b['branch_cash_returns'] ?? 0).toDouble();
        //           group['branchsalesReturn_value'] += (b['branchsalesReturn_value'] ?? 0).toDouble();
        //           group['creditReturns'] +=  (( b['branch_credit_returns'] ??  0) as num).toDouble();
        //
        //           group['cashDiscount'] += ((b['branch_Discount']?? 0).toDouble()-( b['branch_returnDiscount'] ?? 0).toDouble());
        //           group['costOfGoods'] += (b['branchCostof_goods'] ?? 0).toDouble();
        //           group['salesValue'] += (b['branchsales_value'] ?? 0).toDouble();
        //           group['damages'] += (b['branchdamage_value'] ?? 0).toDouble();
        //         }
        //       }
        //     }
        //
        //     // profit calculations
        //     for (final g in grouped.values) {
        //
        //       g['cashAtHand'] = g['cashSales'] - g['cashReturns'];
        //     }
        //
        //     salesregisterreport = grouped.values.toList()
        //       ..sort((a, b) =>
        //           (a['branchName'] ?? '').compareTo(b['branchName'] ?? ''));
        //
        //   } catch (e) {
        //     print("Error: $e");
        //     salesregisterreport = [];
        //   }
        //   finally {
        //     isloadingsalesregister = false;
        //     notifyListeners();
        //   }
        // }

  Future<void> fetchsalesregister({ DateTimeRange? selectedDate, String? selectedBranch,  }) async {
    try {
      isloadingsalesregister = true;
      notifyListeners();

      salesregisterreport.clear();

      final now = DateTime.now();
      final startStr = _toDateOnly(selectedDate?.start ?? now);
      final endStr = _toDateOnly(selectedDate?.end ?? now);

      final snap = await db
          .collection('salesSummary')
          .where('companyid', isEqualTo: companyid)
          .where('summarydate', isGreaterThanOrEqualTo: startStr)
          .where('summarydate', isLessThanOrEqualTo: endStr)
          .get();

      final docs = snap.docs;
      if (docs.isEmpty) return;

      final Map<String, Map<String, dynamic>> grouped = {};

      final bool hasBranchFilter = selectedBranch != null &&
          selectedBranch.trim().isNotEmpty &&
          selectedBranch.trim().toLowerCase() != 'all';

      for (final doc in docs) {
        final d = doc.data();

        final branchSummary = d['branchSummary'] as Map<String, dynamic>?;

        if (branchSummary == null) continue;

        for (final entry in branchSummary.entries) {
          final branchId = entry.key;
          final b = entry.value;

          if (b == null) continue;

          final realBranchId = (b['branchId'] ?? branchId).toString();

          if (hasBranchFilter && realBranchId != selectedBranch) {
            continue;
          }

          final group = grouped.putIfAbsent(realBranchId, () => {
            'branch': realBranchId,
            'branchId': realBranchId,
            'branchName': b['branchName'] ?? '',
            'quantity': 0.0,
            'cashSales': 0.0,
            'creditSales': 0.0,
            'cashReturns': 0.0,
            'creditReturns': 0.0,
            'cashDiscount': 0.0,
            'costOfGoods': 0.0,
            'salesValue': 0.0,
            'damages': 0.0,
            'profit': 0.0,
            'cashAtHand': 0.0,
            'branchsalesReturn_value': 0.0,
          });

          group['quantity'] += ((b['branchsales_qty'] ?? 0) - (b['branchsalesReturn_qty'] ?? 0)).toDouble();
          group['cashSales'] += (b['cash'] ?? 0).toDouble();
          group['creditSales'] += (b['credit'] ?? 0).toDouble();
          group['profit'] += ((b['branch_profit'] ?? 0).toDouble()- (b['branch_returnprofit'] ?? 0).toDouble());
          final branchItems = b['items'] as Map<String, dynamic>?;
          if (branchItems != null) {
            for (final item in branchItems.values) {
              group['profit'] += ((item['profit'] ?? 0).toDouble()-(item['return_profit'] ?? 0).toDouble());
            }
          }
          group['cashReturns'] += (b['branch_cash_returns'] ?? 0).toDouble();
          group['branchsalesReturn_value'] += (b['branchsalesReturn_value'] ?? 0).toDouble();
          group['creditReturns'] +=  (( b['branch_credit_returns'] ??  0) as num).toDouble();

          group['cashDiscount'] += ((b['branch_Discount']?? 0).toDouble()-( b['branch_returnDiscount'] ?? 0).toDouble());
          group['costOfGoods'] += (b['branchCostof_goods'] ?? 0).toDouble();
          group['salesValue'] += (b['branchsales_value'] ?? 0).toDouble();
          group['damages'] += (b['branchdamage_value'] ?? 0).toDouble();
        }
      }

      for (final g in grouped.values) {
        g['cashAtHand'] = g['cashSales'] - g['cashReturns'];
      }

      salesregisterreport = grouped.values.toList()
        ..sort((a, b) =>
            (a['branchName'] ?? '').compareTo(b['branchName'] ?? ''));

    } catch (e) {
      print("Error: $e");
      salesregisterreport = [];
    }
    finally {
      isloadingsalesregister = false;
      notifyListeners();
    }
  }

        List<Map<String, dynamic>>filterfetchsalesregister() {
          if (searchQuery.isEmpty) return salesregisterreport;

          final q = searchQuery.toLowerCase();

          return salesregisterreport.where((entry) {
            final branchName = entry['branchName']?.toString().toLowerCase() ?? '';
            final date = entry['date']?.toString().toLowerCase() ?? '';
            final cashSales =entry['cashSales']?.toString().toLowerCase() ?? '';
            final creditSales =entry['creditSales']?.toString().toLowerCase() ?? '';
            final quantity =entry['quantity']?.toString().toLowerCase() ?? '';
            final creditReturns =entry['creditReturns']?.toString().toLowerCase() ?? '';
            final cashDiscount =entry['cashDiscount']?.toString().toLowerCase() ?? '';
            final creditDiscount =entry['creditDiscount']?.toString().toLowerCase() ?? '';
            final purchaseReturns =entry['purchaseReturns']?.toString().toLowerCase() ?? '';
            final cashReturns =entry['cashReturns']?.toString().toLowerCase() ?? '';
            final damages =entry['damages']?.toString().toLowerCase() ?? '';
            final cashAtHand =entry['cashAtHand']?.toString().toLowerCase() ?? '';
            final Costof_goods =entry['Costof_goods']?.toString().toLowerCase() ?? '';
            final sales_value =entry['sales_value']?.toString().toLowerCase() ?? '';


            return
              branchName.contains(q) ||
                  cashSales.contains(q) ||
                  quantity.contains(q) ||
                  creditReturns.contains(q) ||
                  cashDiscount.contains(q) ||
                  creditDiscount.contains(q) ||
                  creditSales.contains(q) ||
                  purchaseReturns.contains(q) ||
                  cashReturns.contains(q) ||
                  damages.contains(q) ||
                  cashAtHand.contains(q) ||
                  Costof_goods.contains(q) ||
                  sales_value.contains(q) ||
                  date.contains(q);
          }).toList();
        }

        String clean(dynamic v) {
          final s = v?.toString().trim();
          if (s == null || s.isEmpty) return '';
          return s;
        }

        List<Map<String, dynamic>> salesStaffRows = [];

        List<Map<String, dynamic>> salesTransactions = [];
        List<Map<String, dynamic>> itemTransactions = [];
        List<Map<String, dynamic>> stockTransactions = [];
        List<Map<String, dynamic>> filteredStockTransactions = [];
        String _toDateOnly(DateTime d) =>
            "${d.year.toString().padLeft(4, '0')}-"
                "${d.month.toString().padLeft(2, '0')}-"
                "${d.day.toString().padLeft(2, '0')}";
        double _n(dynamic v) => v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
        DateTime _startOfWeek(DateTime date) => date.subtract(Duration(days: date.weekday - 1));

        Future<WeeklySalesComparison> fetchWeeklySalesComparison({String? selectedBranch}) async {
          final now = DateTime.now();
          final currentWeekStart = _startOfWeek(now);
          final previousWeekStart = currentWeekStart.subtract(const Duration(days: 7));
          final startStr = _toDateOnly(previousWeekStart);
          final endStr = _toDateOnly(currentWeekStart.add(const Duration(days: 6)));

          final branchKey = selectedBranch?.trim().isEmpty ?? true
              ? (accesslevel.toLowerCase() != 'super admin' && branchid.isNotEmpty
                  ? branchid
                  : null)
              : selectedBranch;

          final snapshot = await db
              .collection('salesSummary')
              .where('companyid', isEqualTo: companyid)
              .where('summarydate', isGreaterThanOrEqualTo: startStr)
              .where('summarydate', isLessThanOrEqualTo: endStr)
              .get(const GetOptions(source: Source.serverAndCache));

          final totalsByDate = <String, double>{};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final dayKey = _str(data['summarydate']);
            if (dayKey.isEmpty) continue;

            final branchSummary = data['branchSummary'] as Map<String, dynamic>? ?? {};
            double dayTotal = 0;

            for (final branchEntry in branchSummary.entries) {
              final branchData = branchEntry.value as Map<String, dynamic>? ?? {};
              final branchIdValue = _str(branchData['branchId'] ?? branchEntry.key);

              if (branchKey != null && branchIdValue != branchKey && branchEntry.key != branchKey) {
                continue;
              }

              dayTotal += _n(branchData['branchsales_value'] ?? branchData['sales_value'] ?? 0);
            }

            totalsByDate[dayKey] = dayTotal;
          }

          final currentWeek = List.generate(7, (index) {
            final day = currentWeekStart.add(Duration(days: index));
            return totalsByDate[_toDateOnly(day)] ?? 0.0;
          });

          final previousWeek = List.generate(7, (index) {
            final day = previousWeekStart.add(Duration(days: index));
            return totalsByDate[_toDateOnly(day)] ?? 0.0;
          });

          return WeeklySalesComparison(
            currentWeek: currentWeek,
            previousWeek: previousWeek,
            currentWeekStart: currentWeekStart,
          );
        }
        List<Map<String, dynamic>> _rawStockDocs = [];
        DateTime _stockStartDate = DateTime.now();
        void applyStockBranch(String? selectedBranch) {
          if (_rawStockDocs.isEmpty) return;
          stockreport = extractstockReport(_rawStockDocs, selectedBranch, _stockStartDate);
          notifyListeners();
        }
        Future<void> fetchstockreport({DateTimeRange? selectedDate, String? selectedBranch, }) async {
          try {
            isloadingsalesreport = true;
            notifyListeners();

            stockreport.clear();

            final now = DateTime.now();

            final startDate = DateTime(
              (selectedDate?.start ?? now).year,
              (selectedDate?.start ?? now).month,
              (selectedDate?.start ?? now).day,
            );

            final endDate = DateTime(
              (selectedDate?.end ?? now).year,
              (selectedDate?.end ?? now).month,
              (selectedDate?.end ?? now).day,
            );


            final startStr = _toDateOnly(startDate);
            final endStr = _toDateOnly(endDate);

            // OPENING BALANCE
            final openingQuery = await db
                .collection('stockreport')
                .where('summarydate', isLessThan: startStr)
                .where('companyid', isEqualTo: companyid)
                .get(const GetOptions(source: Source.serverAndCache));

            // CURRENT PERIOD
            final currentQuery = await db
                .collection('stockreport')
                .where('summarydate', isGreaterThanOrEqualTo: startStr)
                .where('summarydate', isLessThanOrEqualTo: endStr)
                .where('companyid', isEqualTo: companyid)
                .get(const GetOptions(source: Source.serverAndCache));

            final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
              ...openingQuery.docs,
              ...currentQuery.docs,
            ];

            if (allDocs.isEmpty) {
              stockreport = [];
              return;
            }

            final raw = allDocs.map((e) {
              final data = Map<String, dynamic>.from(e.data());
              data['_docId'] = e.id;
              return data;
            }).toList();
            _rawStockDocs    = raw;
            _stockStartDate  = startDate;
            stockreport = extractstockReport(
              raw,
              selectedBranch,
              startDate,
            );
          } catch (e) {
            print("Error fetching stock report: $e");
            stockreport = [];
          } finally {
            isloadingsalesreport = false;
            notifyListeners();
          }
        }


        List<Map<String, dynamic>> extractstockReport( List<Map<String, dynamic>> rawReport, String? selectedBranch, DateTime startDate, ) {
          final grouped = <String, Map<String, dynamic>>{};

          double getNum(dynamic v) =>
              v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

          final isCompanyView = selectedBranch == null || selectedBranch.isEmpty;
          final startStr = _toDateOnly(startDate);

          for (final doc in rawReport) {
            final summaryDateStr = doc['summarydate']?.toString();
            if (summaryDateStr == null || summaryDateStr.isEmpty) continue;

            final isBeforeStart = summaryDateStr.compareTo(startStr) < 0;

            final itemsRaw = doc['items'];
            if (itemsRaw is! Map<String, dynamic>) continue;

            final itemsRoot = Map<String, dynamic>.from(itemsRaw);

            Iterable<String> branchIds;
            if (isCompanyView) {
              branchIds = itemsRoot.keys;
            } else {
              if (!itemsRoot.containsKey(selectedBranch)) continue;
              branchIds = [selectedBranch];
            }

            for (final branchId in branchIds) {
              final branchItemsRaw = itemsRoot[branchId];
              if (branchItemsRaw is! Map<String, dynamic>) continue;

              final branchItems = Map<String, dynamic>.from(branchItemsRaw);
              final branchName = isCompanyView
                  ? company
                  : (branchItems['branchName'] ?? branchId);

              for (final entry in branchItems.entries) {

                if (entry.value is! Map<String, dynamic>) continue;

                final item = Map<String, dynamic>.from(entry.value);
                final producttype = (item['producttype'] ?? '').toString().trim().toLowerCase();
                if (producttype == 'service') continue;
                // map key (entry.key)

                final itemId = item['itemId']?.toString()?.trim().isNotEmpty == true
                    ? item['itemId'].toString().trim()
                    : item['itemid']?.toString()?.trim().isNotEmpty == true
                    ? item['itemid'].toString().trim()
                    : entry.key.trim();

                if (itemId.isEmpty) continue;

                final groupKey = isCompanyView ? itemId : '${branchId}_$itemId';

                // resolve item name
                final name = item['itemName']?.toString().trim() ?? '';

                final name2 = item['item']?.toString().trim() ?? '';
                final finalName = name.isNotEmpty
                    ? name
                    : name2.isNotEmpty
                    ? name2
                    : itemId;

                //  initialize with zeros —
                grouped.putIfAbsent(groupKey, () => {
                  'branchId': isCompanyView ? '' : branchId,
                  'branch': branchName,
                  'itemid': itemId,
                  'item': finalName,
                  'itemcp': item['costprice'] ?? '',
                  'itemsp': item['sellingprice'] ?? '',
                  'barcode': item['barcode'] ?? '',
                  'opening_stock': 0.0,
                  'newstock': 0.0,
                  'sale_returns': 0.0,
                  'cash_sales': 0.0,
                  'sales_qty': 0.0,
                  'credit_sales': 0.0,
                  'purchase_returns': 0.0,
                  'damages': 0.0,
                  'transfer_qty': 0.0,
                  'Box': 0.0,
                  'cartonqty_bal': 0.0,
                  '_latest_date': '',
                  'transfer_recieved_qty': 0.0,
                });

                final existing = grouped[groupKey]!;

                //name/barcode
                if (existing['item'] == itemId && finalName != itemId) {
                  existing['item'] = finalName;
                }
                if ((existing['barcode'] as String).isEmpty &&
                    (item['barcode'] ?? '').toString().isNotEmpty) {
                  existing['barcode'] = item['barcode'].toString();
                }
                if ((item['costprice'] ?? '').toString().isNotEmpty) {
                  existing['itemcp'] = item['costprice'];
                }
                if ((item['sellingprice'] ?? '').toString().isNotEmpty) {
                  existing['itemsp'] = item['sellingprice'];
                }
                if (isBeforeStart) {
                  // Opening balance accumulation
                      existing['opening_stock'] +=
                      (getNum(item['newstock']) +
                          (isCompanyView ? 0.0 : getNum(item['transfer_recieved_qty']))) -
                          (getNum(item['sales_qty']) +                              (isCompanyView ? 0.0 : getNum(item['transfer_qty'])) +
                              getNum(item['damage_qty']) +
                              getNum(item['purchaseReturn_qty']));
                      final bpBefore = getNum(item['boxpieces']);
                      if (bpBefore > 0) existing['cartonqty_bal'] = bpBefore;
                }
                else {
                  // Current period — accumulate all fields
                  existing['newstock'] += getNum(item['newstock']);
                  existing['sale_returns'] += getNum(item['salesReturn_qty']);
                  existing['transfer_recieved_qty'] += getNum(item['transfer_recieved_qty']);
                  existing['sales_qty'] += getNum(item['sales_qty']);

                  final bp = getNum(item['boxpieces']);
                  if (bp > 0) existing['cartonqty_bal'] = bp;

                  existing['cash_sales'] += getNum(item['cash_sales']);
                  existing['credit_sales'] += getNum(item['credit_sales']);
                  existing['purchase_returns'] += getNum(item['purchaseReturn_qty']);
                  existing['damages'] += getNum(item['damage_qty']);
                  existing['transfer_qty'] += getNum(item['transfer_qty']);
                }

                existing['_latest_date'] = summaryDateStr;
                final bpLatest = getNum(item['boxpieces']);
                if (bpLatest > 0) existing['cartonqty_bal'] = bpLatest;
              }
            }
          }

          // Compute final totals
          for (final item in grouped.values) {
            item['total_stock'] = item['opening_stock'] +
                item['newstock'] +
                (isCompanyView ? 0.0 : item['transfer_recieved_qty']);

            item['stock_out'] = item['sales_qty'] +
                                item['purchase_returns'] +
                                item['damages'] +
                                (isCompanyView ? 0.0 : item['transfer_qty']);

            item['balance_cd'] = item['total_stock'] - item['stock_out'];
          }

          return grouped.values.toList();
        }

        List<Map<String, dynamic>> filterstockreport() {

          if (stockReportSearchQuery.isEmpty) return stockreport;
          final q = stockReportSearchQuery.toLowerCase();

          return stockreport.where((s) {
            final branch = (s['branch'] ?? '').toString().toLowerCase();
            final itemId = (s['itemid'] ?? '').toString().toLowerCase();
            final itemName = (s['item'] ?? '').toString().toLowerCase();
            final barcode = (s['barcode'] ?? '').toString().toLowerCase();

            final balance = (s['balance_cd'] ?? '').toString().toLowerCase();
            final totalStock = (s['total_stock'] ?? '').toString().toLowerCase();

            return branch.contains(q) ||
                itemId.contains(q) ||
                itemName.contains(q) ||
                barcode.contains(q) ||
                balance.contains(q) ||
                totalStock.contains(q);
          }).toList();
        }
        List<Map<String, dynamic>> filterFinishedstockreport() {
          final q = searchQuery.toLowerCase();

          return stockreport.where((s) {
            final balance = double.tryParse(s['balance_cd'].toString()) ?? 0;
           print(stockreport);
            // Only include records with 0 balance
            if (balance != 0) return false;

            // If no search text, return all zero-balance records
            if (searchQuery.isEmpty) return true;

            final branch = (s['branch'] ?? '').toString().toLowerCase();
            final itemId = (s['itemid'] ?? '').toString().toLowerCase();
            final itemName = (s['item'] ?? '').toString().toLowerCase();
            final barcode = (s['barcode'] ?? '').toString().toLowerCase();
            final totalStock = (s['total_stock'] ?? '').toString().toLowerCase();

            return branch.contains(q) ||
                itemId.contains(q) ||
                itemName.contains(q) ||
                barcode.contains(q) ||
                totalStock.contains(q);
          }).toList();
        }
        List<Map<String, dynamic>> filterReOrderstockreport() {
          final q = searchQuery.toLowerCase();

          return stockreport.where((s) {
            final balance = double.tryParse(s['balance_cd'].toString()) ?? 0;

            // Only include records with balance less than 10
            if (balance >= 10) return false;

            // If no search text, return all matching records
            if (searchQuery.isEmpty) return true;

            final branch = (s['branch'] ?? '').toString().toLowerCase();
            final itemId = (s['itemid'] ?? '').toString().toLowerCase();
            final itemName = (s['item'] ?? '').toString().toLowerCase();
            final barcode = (s['barcode'] ?? '').toString().toLowerCase();
            final totalStock = (s['total_stock'] ?? '').toString().toLowerCase();

            return branch.contains(q) ||
                itemId.contains(q) ||
                itemName.contains(q) ||
                barcode.contains(q) ||
                totalStock.contains(q);
          }).toList();
        }

        double _dailyNet(Map<String, dynamic> item) {
          final stockIn  = _n(item['newstock'])
              + _n(item['transfer_recieved_qty']) ;
            //  + _n(item['salesReturn_qty']) ;
          final stockOut =
               _n(item['sales_qty']) +
             // _n(item['credit_sales']) +
              _n(item['transfer_qty']) +
              _n(item['damage_qty']) +
              _n(item['purchaseReturn_qty']);
          return stockIn - stockOut;
        }
        /*
        Future<double> _computeOpeningBalance({ required String  targetItemId, required String  beforeDateStr, required bool    isAllBranches,  required String? selectedBranch, }) async {
          final snap = await db
              .collection('stockreport')
              .where('companyid', isEqualTo: companyid)
              .where('summarydate', isLessThan: beforeDateStr)
              .get(const GetOptions(source: Source.serverAndCache));

          double opening = 0.0;

          for (final doc in snap.docs) {
            final itemsRoot = doc.data()['items'] as Map<String, dynamic>?;
            if (itemsRoot == null) continue;

            // Decide which branches to include
            Iterable<String> branchIds;
            if (isAllBranches) {
              branchIds = itemsRoot.entries.where((e) => e.value is Map<String, dynamic>)
                  .map((e) => e.key);
            }

            else {
              if (!itemsRoot.containsKey(selectedBranch)) continue;
              branchIds = [selectedBranch!];
            }

            for (final bId in branchIds) {
              final branchData = itemsRoot[bId];
              if (branchData is! Map<String, dynamic>) continue;

              for (final entry in branchData.entries) {
                //  process item entries


                if (entry.key == 'branchId' || entry.key == 'branchName') continue;
                if (entry.value is! Map<String, dynamic>) continue;

                final item = Map<String, dynamic>.from(entry.value);


                final docItemId = (item['itemId'] ?? item['itemid'] ?? '').toString().trim();
                if (docItemId != targetItemId.trim()) continue;


                opening += _dailyNet(item);
              }
            }
          }

          return opening;
        }
*/
  /*
        Future<void> loadStockTransactions({ required DateTime startDate, required DateTime endDate,  required String   itemId,  required String   itemName, required String?  selectedBranch,}) async {
          final List<Map<String, dynamic>> transactions = [];

          final isAllBranches = selectedBranch == null ||
              selectedBranch.trim().isEmpty ||
              selectedBranch.trim().toLowerCase() == 'all';

          final startStr = _toDateOnly(startDate);
          final endStr   = _toDateOnly(endDate);

          final currentSnap = await db
              .collection('stockreport')
              .where('companyid', isEqualTo: companyid)
              .where('summarydate', isGreaterThanOrEqualTo: startStr)
              .where('summarydate', isLessThanOrEqualTo: endStr)
              .orderBy('summarydate', descending: true)
              .get(const GetOptions(source: Source.serverAndCache));

          // Helper to build a zero-activity row — used when the item has no
          // transactions on a given day but still has a carried-forward balance
          Map<String, dynamic> _buildBalanceOnlyRow({
            required String date,
            required String branch,
            required double opening,
            double boxpieces = 1.0,
          }) {
            return {
              'date' : date,
              'item'  : itemName,
              'itemId':itemId,
              'branch'  : branch,
              'opening_stock'  : opening,
              'newstock' : 0.0,
              'sales_qty'  : 0.0,
              'credit_sales' : 0.0,
              'cash_sales' : 0.0,
              'sale_returns' : 0.0,
              'purchase_returns': 0.0,
              'damages' : 0.0,
              'transfer' : 0.0,
              'transfer_recieved_qty': 0.0,
              'total_stock' : opening,
              'stock_out' : 0.0,
              'boxpieces' : boxpieces,
              'balance_cd': opening,
            };
          }

          for (final doc in currentSnap.docs) {
            final data    = doc.data();
            final dateStr = data['summarydate']?.toString() ?? '';
            if (dateStr.isEmpty) continue;

            final itemsRoot = data['items'] as Map<String, dynamic>?;
            if (itemsRoot == null) continue;

            Iterable<String> branchIds;

            if (isAllBranches) {
              branchIds = itemsRoot.entries
                  .where((e) => e.value is Map<String, dynamic>)
                  .map((e) => e.key);
            }

             else {
              if (!itemsRoot.containsKey(selectedBranch)) continue;
              branchIds = [selectedBranch!];
            }

            // Accumulated net stock from all days
            final openingForThisDate = await _computeOpeningBalance(
              targetItemId  : itemId,
              beforeDateStr : dateStr,
              isAllBranches : isAllBranches,
              selectedBranch: selectedBranch,
            );

            if (isAllBranches) {
              double newStock = 0, boxpieces = 1.0, salesReturn = 0, transferReceiveQty = 0,
                  cashSales = 0,salesQty = 0, creditSales = 0, purchaseRet = 0,
                  damages = 0, transfer = 0;
              bool found = false;

              for (final bId in branchIds) {
                final branchData = itemsRoot[bId];
                if (branchData is! Map<String, dynamic>) continue;

                for (final entry in branchData.entries) {
                  if (entry.key == 'branchId' || entry.key == 'branchName') continue;
                  if (entry.value is! Map<String, dynamic>) continue;


                  final item = Map<String, dynamic>.from(entry.value);
                  final docItemId = (item['itemId'] ?? item['itemid'] ?? '').toString().trim();
                  if (docItemId != itemId.trim()) continue;

                  newStock  += _n(item['newstock']);
                  salesReturn  += _n(item['salesReturn_qty']);
                  transferReceiveQty += _n(item['transfer_recieved_qty']);
                  salesQty   += _n(item['sales_qty']);
                  cashSales   += _n(item['cash_sales']);
                  creditSales  += _n(item['credit_sales']);
                  purchaseRet += _n(item['purchaseReturn_qty']);
                  damages   += _n(item['damage_qty']);
                  transfer  += _n(item['transfer_qty']);
                  final bp = _n(item['boxpieces']);

                  if (bp > 0) {
                    boxpieces = bp;
                  }
                  found = true;
                }
              }


              // balance still show
              if (!found) {
                if (openingForThisDate != 0.0) {
                  transactions.add(_buildBalanceOnlyRow(
                    date    : dateStr,
                    branch  : company,
                    opening : openingForThisDate,
                    boxpieces: boxpieces > 0 ? boxpieces : 1.0,
                  ));
                }
                continue;
              }

             // final totalStock = openingForThisDate + newStock + salesReturn ;
              final totalStock = openingForThisDate + newStock  ;
            //  final stockOut   = cashSales + creditSales + purchaseRet + damages ;
              final stockOut   = salesQty + purchaseRet + damages ;

              transactions.add({
                'date'  : dateStr,
                'item'  : itemName,
                'itemId'  : itemId,
                'branch' : company,
                'opening_stock' : openingForThisDate,
                'newstock' : newStock,
                'sales_qty'  : salesQty,
                'cash_sales'  : cashSales,
                'credit_sales' : creditSales,
                'sale_returns' : salesReturn,
                'purchase_returns': purchaseRet,
                'damages'  : damages,
                'transfer' : transfer,
                'boxpieces' : boxpieces > 0 ? boxpieces : 1.0,
                'transfer_recieved_qty': transferReceiveQty,
                'total_stock': totalStock,
                'stock_out' : stockOut,
                'balance_cd' : totalStock - stockOut,
              });

            } else {
              // Single branch
              final branchData = itemsRoot[selectedBranch!];
              if (branchData is! Map<String, dynamic>) continue;
              final branchItems = Map<String, dynamic>.from(branchData);
              final branchName  = branchItems['branchName']?.toString() ?? selectedBranch;

              bool found = false;

              for (final entry in branchItems.entries) {
                if (entry.key == 'branchId' || entry.key == 'branchName') continue;
                if (entry.value is! Map<String, dynamic>) continue;

                final item      = Map<String, dynamic>.from(entry.value);
                final docItemId = (item['itemId'] ?? item['itemid'] ?? '').toString().trim();
                if (docItemId != itemId.trim()) continue;

                final newStock   = _n(item['newstock']);
                final transferReceive = _n(item['transfer_recieved_qty']);
                final salesReturn  = _n(item['salesReturn_qty']);
                final salesQty   = _n(item['sales_qty']);
                final cashSales   = _n(item['cash_sales']);
                final creditSales  = _n(item['credit_sales']);
                final purchaseRet  = _n(item['purchaseReturn_qty']);
                final damages  = _n(item['damage_qty']);
                final transfer  = _n(item['transfer_qty']);
                final bp = _n(item['boxpieces']);

               // final totalStock = openingForThisDate + newStock + salesReturn + transferReceive;
                final totalStock = openingForThisDate + newStock  + transferReceive;
               // final stockOut   = cashSales + creditSales + purchaseRet + damages + transfer;
                final stockOut   = salesQty  + purchaseRet + damages + transfer;

                transactions.add({
                  'date' : dateStr,
                  'item' : item['item'] ?? itemName,
                  'itemId' : docItemId,
                  'branch' : branchName,
                  'opening_stock': openingForThisDate,
                  'newstock': newStock,
                  'sales_qty' : salesQty,
                  'cash_sales' : cashSales,
                  'credit_sales' : creditSales,
                  'sale_returns' : salesReturn,
                  'purchase_returns': purchaseRet,
                  'damages' : damages,
                  'transfer' : transfer,
                  'transfer_recieved_qty': transferReceive,
                  'total_stock' : totalStock,
                  'boxpieces': bp > 0 ? bp : 1.0,
                  'stock_out'  : stockOut,
                  'balance_cd' : totalStock - stockOut,
                });

                found = true;
              }

              // Item had no activity  show carried balance
              if (!found && openingForThisDate != 0.0) {
                transactions.add(_buildBalanceOnlyRow(
                  date  : dateStr,
                  branch  : branchName,
                  opening : openingForThisDate,
                  boxpieces: 1.0,
                ));
              }
            }
          }


          // balance from before the start date and show it as a single row
          if (transactions.isEmpty) {
            final openingBalance = await _computeOpeningBalance(
              targetItemId  : itemId,
              beforeDateStr : startStr,
              isAllBranches : isAllBranches,
              selectedBranch: selectedBranch,
            );

            if (openingBalance != 0.0) {
              transactions.add(_buildBalanceOnlyRow(
                date    : startStr,
                branch  : isAllBranches ? (company) : (selectedBranch),
                opening : openingBalance,
                boxpieces: 1.0,
              ));
            }
          }

          stockTransactions = transactions;
          notifyListeners();
        }
           */

  // Pure in-memory computation now — no Firestore call, no async needed.
// Runs against docs you already fetched once.
  double _computeOpeningBalanceFromDocs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> openingDocs,
    required String targetItemId,
    required bool isAllBranches,
    required String? selectedBranch,
  }) {
    double opening = 0.0;

    for (final doc in openingDocs) {
      final itemsRoot = doc.data()['items'] as Map<String, dynamic>?;
      if (itemsRoot == null) continue;

      Iterable<String> branchIds;
      if (isAllBranches) {
        branchIds = itemsRoot.entries
            .where((e) => e.value is Map<String, dynamic>)
            .map((e) => e.key);
      } else {
        if (!itemsRoot.containsKey(selectedBranch)) continue;
        branchIds = [selectedBranch!];
      }

      for (final bId in branchIds) {
        final branchData = itemsRoot[bId];
        if (branchData is! Map<String, dynamic>) continue;

        for (final entry in branchData.entries) {
          if (entry.key == 'branchId' || entry.key == 'branchName') continue;
          if (entry.value is! Map<String, dynamic>) continue;

          final item = Map<String, dynamic>.from(entry.value);
          final docItemId = (item['itemId'] ?? item['itemid'] ?? '').toString().trim();
          if (docItemId != targetItemId.trim()) continue;

          opening += _dailyNet(item);
        }
      }
    }

    return opening;
  }

  Future<void> loadStockTransactions({
    required DateTime startDate,
    required DateTime endDate,
    required String   itemId,
    required String   itemName,
    required String?  selectedBranch,
  }) async {
    final List<Map<String, dynamic>> transactions = [];

    final isAllBranches = selectedBranch == null ||
        selectedBranch.trim().isEmpty ||
        selectedBranch.trim().toLowerCase() == 'all';

    final startStr = _toDateOnly(startDate);
    final endStr   = _toDateOnly(endDate);

    // ONE query to establish the opening balance (everything before the range)
    final openingSnap = await db
        .collection('stockreport')
        .where('companyid', isEqualTo: companyid)
        .where('summarydate', isLessThan: startStr)
        .get(const GetOptions(source: Source.serverAndCache));

    // ONE query for the whole range, ASCENDING so we can walk forward and
    // accumulate a running balance instead of recomputing it every day.
    final currentSnap = await db
        .collection('stockreport')
        .where('companyid', isEqualTo: companyid)
        .where('summarydate', isGreaterThanOrEqualTo: startStr)
        .where('summarydate', isLessThanOrEqualTo: endStr)
        .orderBy('summarydate', descending: false)
        .get(const GetOptions(source: Source.serverAndCache));

    Map<String, dynamic> _buildBalanceOnlyRow({
      required String date,
      required String branch,
      required double opening,
      double boxpieces = 1.0,
    }) {
      return {
        'date' : date,
        'item'  : itemName,
        'itemId':itemId,
        'branch'  : branch,
        'opening_stock'  : opening,
        'newstock' : 0.0,
        'sales_qty'  : 0.0,
        'credit_sales' : 0.0,
        'cash_sales' : 0.0,
        'sale_returns' : 0.0,
        'purchase_returns': 0.0,
        'damages' : 0.0,
        'transfer' : 0.0,
        'transfer_recieved_qty': 0.0,
        'total_stock' : opening,
        'stock_out' : 0.0,
        'boxpieces' : boxpieces,
        'balance_cd': opening,
      };
    }

    // Running balance — starts as the balance carried into the range.
    double runningBalance = _computeOpeningBalanceFromDocs(
      openingDocs: openingSnap.docs,
      targetItemId: itemId,
      isAllBranches: isAllBranches,
      selectedBranch: selectedBranch,
    );

    for (final doc in currentSnap.docs) {
      final data    = doc.data();
      final dateStr = data['summarydate']?.toString() ?? '';
      if (dateStr.isEmpty) continue;

      final itemsRoot = data['items'] as Map<String, dynamic>?;
      if (itemsRoot == null) continue;

      Iterable<String> branchIds;
      if (isAllBranches) {
        branchIds = itemsRoot.entries
            .where((e) => e.value is Map<String, dynamic>)
            .map((e) => e.key);
      } else {
        if (!itemsRoot.containsKey(selectedBranch)) continue;
        branchIds = [selectedBranch!];
      }

      final openingForThisDate = runningBalance;

      if (isAllBranches) {
        double newStock = 0, boxpieces = 1.0, salesReturn = 0, transferReceiveQty = 0,
            cashSales = 0, salesQty = 0, creditSales = 0, purchaseRet = 0,
            damages = 0, transfer = 0;
        bool found = false;

        for (final bId in branchIds) {
          final branchData = itemsRoot[bId];
          if (branchData is! Map<String, dynamic>) continue;

          for (final entry in branchData.entries) {
            if (entry.key == 'branchId' || entry.key == 'branchName') continue;
            if (entry.value is! Map<String, dynamic>) continue;

            final item = Map<String, dynamic>.from(entry.value);
            final docItemId = (item['itemId'] ?? item['itemid'] ?? '').toString().trim();
            if (docItemId != itemId.trim()) continue;

            newStock  += _n(item['newstock']);
            salesReturn  += _n(item['salesReturn_qty']);
            transferReceiveQty += _n(item['transfer_recieved_qty']);
            salesQty   += _n(item['sales_qty']);
            cashSales   += _n(item['cash_sales']);
            creditSales  += _n(item['credit_sales']);
            purchaseRet += _n(item['purchaseReturn_qty']);
            damages   += _n(item['damage_qty']);
            transfer  += _n(item['transfer_qty']);
            final bp = _n(item['boxpieces']);
            if (bp > 0) boxpieces = bp;
            found = true;
          }
        }

        if (!found) {
          if (openingForThisDate != 0.0) {
            transactions.add(_buildBalanceOnlyRow(
              date: dateStr,
              branch: company,
              opening: openingForThisDate,
              boxpieces: boxpieces > 0 ? boxpieces : 1.0,
            ));
          }
          // no activity → balance carries forward unchanged
          continue;
        }

        final totalStock = openingForThisDate + newStock;
        final stockOut    = salesQty + purchaseRet + damages;
        final closing     = totalStock - stockOut;

        transactions.add({
          'date'  : dateStr,
          'item'  : itemName,
          'itemId'  : itemId,
          'branch' : company,
          'opening_stock' : openingForThisDate,
          'newstock' : newStock,
          'sales_qty'  : salesQty,
          'cash_sales'  : cashSales,
          'credit_sales' : creditSales,
          'sale_returns' : salesReturn,
          'purchase_returns': purchaseRet,
          'damages'  : damages,
          'transfer' : transfer,
          'boxpieces' : boxpieces > 0 ? boxpieces : 1.0,
          'transfer_recieved_qty': transferReceiveQty,
          'total_stock': totalStock,
          'stock_out' : stockOut,
          'balance_cd' : closing,
        });

        runningBalance = closing;
      } else {
        final branchData = itemsRoot[selectedBranch!];
        if (branchData is! Map<String, dynamic>) continue;
        final branchItems = Map<String, dynamic>.from(branchData);
        final branchName  = branchItems['branchName']?.toString() ?? selectedBranch;

        bool found = false;
        double closingForBranch = openingForThisDate;

        for (final entry in branchItems.entries) {
          if (entry.key == 'branchId' || entry.key == 'branchName') continue;
          if (entry.value is! Map<String, dynamic>) continue;

          final item      = Map<String, dynamic>.from(entry.value);
          final docItemId = (item['itemId'] ?? item['itemid'] ?? '').toString().trim();
          if (docItemId != itemId.trim()) continue;

          final newStock   = _n(item['newstock']);
          final transferReceive = _n(item['transfer_recieved_qty']);
          final salesReturn  = _n(item['salesReturn_qty']);
          final salesQty   = _n(item['sales_qty']);
          final cashSales   = _n(item['cash_sales']);
          final creditSales  = _n(item['credit_sales']);
          final purchaseRet  = _n(item['purchaseReturn_qty']);
          final damages  = _n(item['damage_qty']);
          final transfer  = _n(item['transfer_qty']);
          final bp = _n(item['boxpieces']);

          final totalStock = openingForThisDate + newStock + transferReceive;
          final stockOut   = salesQty + purchaseRet + damages + transfer;
          final closing    = totalStock - stockOut;

          transactions.add({
            'date' : dateStr,
            'item' : item['item'] ?? itemName,
            'itemId' : docItemId,
            'branch' : branchName,
            'opening_stock': openingForThisDate,
            'newstock': newStock,
            'sales_qty' : salesQty,
            'cash_sales' : cashSales,
            'credit_sales' : creditSales,
            'sale_returns' : salesReturn,
            'purchase_returns': purchaseRet,
            'damages' : damages,
            'transfer' : transfer,
            'transfer_recieved_qty': transferReceive,
            'total_stock' : totalStock,
            'boxpieces': bp > 0 ? bp : 1.0,
            'stock_out'  : stockOut,
            'balance_cd' : closing,
          });

          found = true;
          closingForBranch = closing;
        }

        if (!found && openingForThisDate != 0.0) {
          transactions.add(_buildBalanceOnlyRow(
            date: dateStr,
            branch: branchName,
            opening: openingForThisDate,
            boxpieces: 1.0,
          ));
        }

        runningBalance = closingForBranch;
      }
    }

    // UI previously expected newest-first (docs were queried descending).
    final ordered = transactions.reversed.toList();

    if (ordered.isEmpty) {
      final openingBalance = runningBalance == 0.0
          ? _computeOpeningBalanceFromDocs(
        openingDocs: openingSnap.docs,
        targetItemId: itemId,
        isAllBranches: isAllBranches,
        selectedBranch: selectedBranch,
      )
          : runningBalance;

      if (openingBalance != 0.0) {
        ordered.add(_buildBalanceOnlyRow(
          date: startStr,
          branch: isAllBranches ? company : selectedBranch!,
          opening: openingBalance,
          boxpieces: 1.0,
        ));
      }
    }

    stockTransactions = ordered;
    notifyListeners();
  }
  Future<void> loadSalesStaffSummary({ required DateTime startDate,required DateTime endDate,required bool shouldFilterByBranch, required String selectedBranchId, }) async {
          final Map<String, Map<String, dynamic>> grouped = {};

          final startStr = _toDateOnly(startDate);
          final endStr = _toDateOnly(endDate);

          final snap = await db
              .collection('salesSummary')
              .where('companyid', isEqualTo: companyid)
              .where('summarydate', isGreaterThanOrEqualTo: startStr)
              .where('summarydate', isLessThanOrEqualTo: endStr)
              .get(const GetOptions(source: Source.serverAndCache));

          for (final doc in snap.docs) {
            final data = doc.data();

            // staffSummary
            final staffSummary = data['staffSummary'] as Map<String, dynamic>? ?? {};
            if (staffSummary.isEmpty) continue;


            for (final branchEntry in staffSummary.entries) {
              final branchId = branchEntry.key.trim().toLowerCase();

              // Filter by branch
              if (shouldFilterByBranch &&
                  branchId != selectedBranchId.trim().toLowerCase()) {
                continue;
              }

              if (branchEntry.value is! Map) continue;

              final branchMap = Map<String, dynamic>.from(branchEntry.value);

              //staffEmail
              for (final staffEntry in branchMap.entries) {
                final staffEmail = staffEntry.key;

                if (staffEntry.value is! Map) continue;

                final staffData = Map<String, dynamic>.from(staffEntry.value);

                final branchName = (staffData['branchName'] ?? '').toString();
                final staffDisplayName =
                (staffData['staff'] ?? staffEmail).toString();


                final groupKey = '$branchId|$staffEmail';

                grouped.putIfAbsent(
                  groupKey,
                      () => {
                    'staff': staffDisplayName,
                    'staffEmail': staffEmail,
                    'branchId': branchId,
                    'branchName': branchName,
                    'quantity': 0.0,
                    'cashSales': 0.0,
                    'creditSales': 0.0,
                    'creditReturns': 0.0,
                    'merchantmomo': 0.0,
                    'hubtel': 0.0,
                    'card': 0.0,
                    'bank': 0.0,
                    'cheque': 0.0,
                    'cashDiscount': 0.0,
                    'creditDiscount': 0.0,
                    'cashReturns': 0.0,
                    'profit': 0.0,
                    'debtPayment': 0.0,
                    'debtpayment_cash': 0.0,
                    'debtcard': 0.0,
                    'debtcheque': 0.0,
                    'debtbank': 0.0,
                    'debtmerchantmomo': 0.0,
                    'debthubtel': 0.0,
                    'cashAtHand': 0.0,
                  },
                );

                final row = grouped[groupKey]!;

               final merchantmomo =    (staffData['momo'] ?? 0).toDouble();
               final debtmerchantmomo =    (staffData['debtpayment_momo'] ?? 0).toDouble();
                final hubtel =    (staffData['hubtel'] ?? 0).toDouble();
                final debthubtel =    (staffData['debtpayment_hubtel'] ?? 0).toDouble();
                final card =    (staffData['card'] ?? 0).toDouble();
                final debtcard =    (staffData['debtpayment_card'] ?? 0).toDouble();
                final bank =    (staffData['bank'] ?? 0).toDouble();
                final debtbank =    (staffData['debtpayment_bank'] ?? 0).toDouble();
                final cheque =    (staffData['cheque'] ?? 0).toDouble();
                final debtcheque =    (staffData['debtpayment_cheque'] ?? 0).toDouble();
                final cashReturns =  (staffData['cash_returns'] ?? 0).toDouble();
                final debtPayment =  (staffData['debtpayments_value'] ?? 0).toDouble();
                final debtpayment_cash =  (staffData['debtpayment_cash'] ?? 0).toDouble();

                final creditReturns = (staffData['credit_returns'] ?? 0).toDouble();
                final discount =  (staffData['staffdiscount']  ?? 0).toDouble();

               final qty =  (staffData['staffsales_qty'] ?? 0).toDouble();

                final salesReturnQty = (staffData['staffsalesReturn_qty'] ?? 0).toDouble();
                final cash = (staffData['cash'] ?? 0).toDouble();
                final credit = (staffData['credit'] ?? 0).toDouble();



                final profit = (staffData['profit'] ?? 0).toDouble();
                final cashNet = (cash + debtpayment_cash) -cashReturns;

                row['quantity'] += (qty - salesReturnQty);
                row['cashSales'] += cash;
                row['creditSales'] += credit;
                row['cashReturns'] += cashReturns;
                row['debtPayment'] += debtPayment;
                row['debtpayment_cash'] += debtpayment_cash;
                row['creditReturns'] += creditReturns;
                row['cashDiscount'] += discount;

                row['merchantmomo'] += merchantmomo;
                row['debtmerchantmomo'] += debtmerchantmomo;
                row['hubtel'] += hubtel;
                row['debthubtel'] += debthubtel;
                row['card'] += card;
                row['debtcard'] += debtcard;
                row['bank'] += bank;
                row['debtbank'] += debtbank;
                row['cheque'] += cheque;
                row['debtcheque'] += debtcheque;
                row['profit'] += profit;

                row['cashAtHand'] += cashNet;
              }
            }
          }

          salesStaffRows = grouped.values.toList();
          notifyListeners();
        }
        Future<void> loadSalesAndDebStaffSummary({
          required DateTime startDate,
          required DateTime endDate,
          required bool shouldFilterByBranch,
          required String selectedBranchId,
        }) async {
          final Map<String, Map<String, dynamic>> grouped = {};

          final startStr = _toDateOnly(startDate);
          final endStr   = _toDateOnly(endDate);

          double dv(dynamic v) {
            if (v == null) return 0.0;
            if (v is num) return v.toDouble();
            return double.tryParse(v.toString()) ?? 0.0;
          }

          Query salesQuery = db
              .collection('sales')
              .where('companyId', isEqualTo: companyid)
              .where('dateymd', isGreaterThanOrEqualTo: startStr)
              .where('dateymd', isLessThanOrEqualTo: endStr);
          if (shouldFilterByBranch) {
            salesQuery = salesQuery.where('branchId', isEqualTo: selectedBranchId);
          }
          final salesSnap = await salesQuery.get();

          Query debtQuery = db
              .collection('debtpayment')
              .where('companyid', isEqualTo: companyid)
              .where('date', isGreaterThanOrEqualTo: startStr)
              .where('date', isLessThanOrEqualTo: endStr);
          if (shouldFilterByBranch) {
            debtQuery = debtQuery.where('branchId', isEqualTo: selectedBranchId);
          }
          final debtSnap = await debtQuery.get();

          Map<String, dynamic> seedRow(String staff, String staffEmail, String branchId, String branchName) => {
            'staff': staff,
            'staffEmail': staffEmail,
            'branchId': branchId,
            'branchName': branchName,
            'quantity': 0.0,
            'cashSales': 0.0,
            'creditSales': 0.0,
            'creditReturns': 0.0,
            'merchantmomo': 0.0,
            'hubtel': 0.0,
            'card': 0.0,
            'bank': 0.0,
            'cheque': 0.0,
            'cashDiscount': 0.0,
            'creditDiscount': 0.0,
            'cashReturns': 0.0,
            'profit': 0.0,
            'debtPayment': 0.0,
            'cashAtHand': 0.0,
          };

          for (final doc in salesSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;

            final branchId   = (data['branchId'] ?? '').toString().toLowerCase();
            final staffEmail = (data['receiptbyemail'] ?? '').toString().toLowerCase();
            final staffName  = (data['createdBy'] ?? data['approvedby'] ?? staffEmail).toString();
            final branchName = (data['branchName'] ?? '').toString();
            final groupKey   = '$branchId|$staffEmail';

            grouped.putIfAbsent(groupKey, () => seedRow(staffName, staffEmail, branchId, branchName));
            final row = grouped[groupKey]!;

            final totalAmount  = dv(data['totalamount']);
            final discount     = dv(data['discount']);
            final transMode    = (data['transMode'] ?? '').toString().toLowerCase();
            final isCreditSale = transMode == 'credit' ||
                (data['paymentStatus'] ?? '').toString().toLowerCase() == 'pending';

            double profit = 0, qty = 0, cashReturn = 0, creditReturn = 0;
            final items = data['items'];
            if (items is Map) {
              for (final iv in items.values) {
                if (iv is! Map) continue;
                profit += dv(iv['profit']);
                qty    += dv(iv['quantity']) - dv(iv['returned_quantity']);

                if (iv['status'] == 'returned') {
                  final retAmt  = dv(iv['returned_totalamount']);
                  final retMode = (iv['returned_transMode'] ?? transMode).toString().toLowerCase();
                  retMode == 'credit' ? creditReturn += retAmt : cashReturn += retAmt;
                }
              }
            }

            double cashAmt = 0, momoAmt = 0, cardAmt = 0;
            double bankAmt = 0, hubtelAmt = 0, chequeAmt = 0;
            final payments = data['payments'];
            if (payments is List) {
              for (final p in payments) {
                if (p is! Map) continue;
                final method = (p['method'] ?? '').toString().toLowerCase();
                final amt    = dv(p['amount']);
                switch (method) {
                  case 'cash':         cashAmt   += amt; break;
                  case 'momo':
                  case 'mobile_money': momoAmt   += amt; break;
                  case 'card':         cardAmt   += amt; break;
                  case 'bank_transfer':
                  case 'bank':         bankAmt   += amt; break;
                  case 'hubtel':       hubtelAmt += amt; break;
                  case 'cheque':
                  case 'cheques':      chequeAmt += amt; break;
                }
              }
            }

            // Infer physical cash: anything not covered by other payment methods
            if (!isCreditSale) {
              final totalPaid = cashAmt + momoAmt + cardAmt + bankAmt + hubtelAmt + chequeAmt;
              final remainder = totalAmount - totalPaid;
              if (remainder > 0) cashAmt += remainder;
            }

            row['quantity']     += qty;
            row['cashSales']    += cashAmt;
            row['merchantmomo'] += momoAmt;
            row['card']         += cardAmt;
            row['bank']         += bankAmt;
            row['hubtel']       += hubtelAmt;
            row['cheque']       += chequeAmt;
            if (isCreditSale) {
              row['creditSales']    += totalAmount;
              row['creditDiscount'] += discount;
            } else {
              row['cashDiscount']   += discount;
            }
            row['cashReturns']   += cashReturn;
            row['creditReturns'] += creditReturn;
            row['profit']        += profit;
            row['cashAtHand']    += (cashAmt - cashReturn);
          }

          for (final doc in debtSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;

            final branchId   = (data['branchId'] ?? '').toString().toLowerCase();
            final staffEmail = (data['receiptbyemail'] ?? '').toString().toLowerCase();
            final staffName  = (data['createdby'] ?? staffEmail).toString();

            final branchName = (data['branchName'] ?? '').toString();
            final groupKey   = '$branchId|$staffEmail';

            grouped.putIfAbsent(groupKey, () => seedRow(staffName, staffEmail, branchId, branchName));
            grouped[groupKey]!['debtPayment'] += dv(data['amount']);
          }

          salesStaffRows = grouped.values.toList();
          notifyListeners();
        }
        List<Map<String, dynamic>> filteredSalesStaffRows(){
          if (searchQuery.isEmpty) return salesStaffRows;

          final q = searchQuery.toLowerCase();

          return salesStaffRows.where((row) {
            final staff =  (row['staff'] ?? '').toString().toLowerCase();

            final branch = (row['branchName'] ?? '').toString().toLowerCase();

            return staff.contains(q) ||
                branch.contains(q);
          }).toList();

        }

  Future<void> loadSalesStaffTransactions({ required DateTime startDate, required DateTime endDate, required String staffName, required String staffEmail, required String companyId, required String? selectedBranch,}) async {
    final List<Map<String, dynamic>> sales = [];

    final startStr = _toDateOnly(startDate);
    final endStr   = _toDateOnly(endDate);

    final salesSnap = await db
        .collection('sales')
        .where('companyId', isEqualTo: companyId)
        .where('dateymd', isGreaterThanOrEqualTo: startStr)
        .where('dateymd', isLessThanOrEqualTo: endStr)
        .get();

    final debtSnap = await db
        .collection('debtpayment')
        .where('companyid', isEqualTo: companyId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .get();

    String methodLabel(dynamic paymentsField) {
      if (paymentsField is! List || paymentsField.isEmpty) return '';
      final parts = <String>[];
      for (final p in paymentsField) {
        if (p is Map) {
          final method = (p['method'] ?? '').toString();
          final amt    = (p['amount'] ?? 0).toString();
          if (method.isNotEmpty) parts.add('$method $amt');
        }
      }
      return parts.join(', ');
    }

    // Normalized branch filter
    final filterBranch = (selectedBranch == null ||
        selectedBranch.isEmpty ||
        selectedBranch.toLowerCase() == 'all')
        ? null
        : selectedBranch.trim();

    for (final doc in salesSnap.docs) {
      final data = doc.data();

      // Filter by staff email first. 
      // This is the primary key for staff-based transactions.
      final staffemail = (data['receiptbyemail'] ?? data['staffemail'] ?? '').toString().trim();
      if (staffemail.toLowerCase() != staffEmail.toLowerCase()) continue;

      // We no longer strictly filter by doc-level branchId here because 
      // Sales Point staff transactions might belong to a warehouse in Firestore (stock deduction)
      // while being reported under their sales point in the summary report.

      sales.add({
        'type': 'sale',
        'date': data['dateymd'] ?? '',
        'datetime': data['createdAt'] ?? '',
        'receipt': data['receiptNumber'] ?? '',
        'customer': data['customerName'] ?? '',
        'amount': data['totalamount'] ?? 0,
        'amountPaid': data['amountPaid'] ?? 0,
        'discount': data['discount'] ?? 0,
        'payment': data['transMode'] ?? '',
        'paymentMethods': methodLabel(data['payments']),
        'payments': data['payments'] is List ? data['payments'] : <dynamic>[],
        'paymentStatus': data['paymentStatus'] ?? '',
        'branch': data['branchName'] ?? '',
        'itemCount': data['itemCount'] ?? 0,
        'items': data['items'] is Map
            ? Map<String, dynamic>.from(data['items'])
            : <String, dynamic>{},
        'mode': data['pricingtype'] ?? '',
      });
    }

    for (final doc in debtSnap.docs) {
      final data = doc.data();

      final staffemail = (data['receiptemail'] ?? '').toString().trim();
      if (staffemail.toLowerCase() != staffEmail.toLowerCase()) continue;

      if (selectedBranch != null &&
          selectedBranch.isNotEmpty &&
          data['branchId']?.toString() != selectedBranch) {
        continue;
      }

      sales.add({
        'type': 'debt',
        'date': data['date'] ?? '',
        'datetime': data['createdat'] ?? '',
        'receipt': data['id'] ?? '',
        'customer': data['customername'] ?? '',
        'amount': data['amount'] ?? 0,
        'amountPaid': data['amount'] ?? 0,
        'discount': 0,
        'payment': data['paymentmethod'] ?? '',
        'paymentMethods': methodLabel(data['payments']),
        'payments': data['payments'] is List ? data['payments'] : <dynamic>[],
        'paymentStatus': '',
        'branch': data['branchName'] ?? '',
        'itemCount': 0,
        'items': <String, dynamic>{},
        'mode': 'Debt Payment',
      });
    }

    sales.sort((a, b) {
      final da = a['datetime'];
      final dbb = b['datetime'];
      if (da is Timestamp && dbb is Timestamp) return dbb.compareTo(da);
      return 0;
    });

    salesTransactions = sales;
    notifyListeners();
  }

  List<Map<String, dynamic>>filteredSalesStaffTransactions(){
    if (searchQuery.isEmpty) return salesTransactions;

    final q = searchQuery.toLowerCase();

    return salesTransactions.where((s) {
      final receipt = (s['receipt'] ?? '').toString().toLowerCase();
      final customer = (s['customer'] ?? '').toString().toLowerCase();
      final branch = (s['branch'] ?? '').toString().toLowerCase();
      final amount = (s['amount'] ?? '').toString().toLowerCase();
      final amountPaid = (s['amountPaid'] ?? '').toString().toLowerCase();
      final date = (s['date'] ?? '').toString().toLowerCase();
      final payment = (s['payment'] ?? '').toString().toLowerCase();
      final itemCount = (s['itemCount'] ?? '').toString().toLowerCase();
      final mode = (s['mode'] ?? '').toString().toLowerCase();
      final discount = (s['discount'] ?? '').toString().toLowerCase();

      return receipt.contains(q) ||
          customer.contains(q) ||
          branch.contains(q) ||
          amount.contains(q) ||
          amountPaid.contains(q) ||
          date.contains(q) ||
          payment.contains(q) ||
          itemCount.contains(q) ||
          mode.contains(q) ||
          discount.contains(q);

    }).toList();

  }


        Future<void> loadItemSalesTransactions({ required DateTime startDate, required DateTime endDate,  required String itemId, required String itemName, required String? branchId, }) async {
          final List<Map<String, dynamic>> transactions = [];

          List<String> generateIds(DateTime start, DateTime end) {
            List<String> ids = [];
            for (
            DateTime d = start;
            !d.isAfter(end);
            d = d.add(const Duration(days: 1))
            ) {
              final date =
                  "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
              ids.add(date);
            }
            return ids;
          }

          final ids = generateIds(startDate, endDate);
          final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (int i = 0; i < ids.length; i += 30) {
            final chunk = ids.skip(i).take(30).toList();

            Query<Map<String, dynamic>> query = db
                .collection('sales')
                .where('companyId', isEqualTo: companyid)
                .where('dateymd', whereIn: chunk);

            // Removing query-level branchId filter to capture all relevant transactions,
            // especially for Sales Point staff where doc-level branchId might be a warehouse.
            // We'll filter in-memory instead.
            /*
            if (branchId != null &&
                branchId.isNotEmpty &&
                branchId.toLowerCase() != 'all') {
              query = query.where('branchId', isEqualTo: branchId.trim());
            }
            */

            final snap = await query.get();
            allDocs.addAll(snap.docs);
          }

          for (final doc in allDocs) {
            final data = doc.data();
            final items = data['items'] as Map<String, dynamic>? ?? {};

            final docTransMode = (data['transMode'] ?? '').toString().toLowerCase().trim();
            final resolvedTransMode = docTransMode.isNotEmpty ? docTransMode : 'cash';

            // Document-level branch check
            final bool docMatchesBranch = branchId == null ||
                branchId.isEmpty ||
                branchId.toLowerCase() == 'all' ||
                data['branchId']?.toString().trim() == branchId.trim();

            items.forEach((key, value) {
              if (value is! Map) return;
              final itemMap = Map<String, dynamic>.from(value);

              // Match by itemid (Firestore ID) OR barcode
              final currentItemId = (itemMap['itemid'] ?? itemMap['itemId'] ?? itemMap['id'] ?? '').toString().trim();
              final currentBarcode = (itemMap['barcode'] ?? '').toString().trim();
              
              if (currentItemId != itemId.trim() && currentBarcode != itemId.trim()) return;

              // Item-level branch check
              final itemBranchId = (itemMap['branchid'] ?? data['branchId'] ?? '').toString().trim();
              final bool itemMatchesBranch = branchId == null ||
                  branchId.isEmpty ||
                  branchId.toLowerCase() == 'all' ||
                  itemBranchId == branchId.trim();

              // If filtering by branch, only include if document or item specifically matches
              if (!docMatchesBranch && !itemMatchesBranch) return;

              final qty = double.tryParse(itemMap['quantity'].toString()) ?? 0;
              final price = double.tryParse(itemMap['price'].toString()) ?? 0;
              final profit = double.tryParse(itemMap['profit'].toString()) ?? 0;
              final total = double.tryParse(
                itemMap['totalamount']?.toString() ?? itemMap['price']?.toString() ?? '0',
              ) ?? 0;
              final cp = double.tryParse(itemMap['cp']?.toString() ?? '0') ?? 0;
              final discount = double.tryParse(itemMap['discount']?.toString() ?? '0') ?? 0;

              // Return info
              final returnedQty = double.tryParse(itemMap['returned_quantity']?.toString() ?? '0') ?? 0;
              final returnedProfit = double.tryParse(itemMap['returned_profit']?.toString() ?? '0') ?? 0;
              final returnedDiscount = double.tryParse(itemMap['returned_discount']?.toString() ?? '0') ?? 0;
              final returnedAmount = double.tryParse(itemMap['returned_totalamount']?.toString() ?? '0') ?? 0;
              final returnedGrosstotalamount = double.tryParse(itemMap['returned_grosstotalamount']?.toString() ?? '0') ?? 0;
              final isReturned = itemMap['status']?.toString() == 'returned' && returnedQty > 0;
              final returnedTransMode = (itemMap['returned_transMode'] ?? resolvedTransMode)
                  .toString().toLowerCase().trim();


              transactions.add({
                'date': data['createdAt'],
                'item': itemMap['item'] ?? '',
                'qty': qty,
                'price': price,
                'profit': profit,
                'total': total,
                'cp': cp,
                'discount': discount,
                'transMode': resolvedTransMode,
                'salesMode': itemMap['mode'] ?? '',
                'customer': data['customerName'] ?? '',
                'branch': data['branchName'] ?? '',
                'pricingMode': itemMap['pricemode'] ?? '',
                'staff': data['createdBy'] ?? '',
                'staffEmail': data['staffemail'] ?? '',
                'receipt': data['receiptNumber'] ?? '',
                'paymentStatus': data['paymentStatus'] ?? '',
                'transactionId': data['id'] ?? '',
                'isReturned': false,
                'returnedQty': 0.0,
                'returnedAmount': 0.0,
                'returnedTransMode': '',
                'isCash': resolvedTransMode == 'cash',
                'isCredit': resolvedTransMode == 'credit',
                'isCashReturn': false,
                'isCreditReturn': false,
              });


              if (isReturned) {
                transactions.add({
                  'date': data['returned_updatedat'] ?? data['createdAt'],
                  'item': itemMap['returned_item'] ?? itemMap['item'] ?? '',
                  'qty': returnedQty,
                  'price': double.tryParse(itemMap['returned_price']?.toString() ?? '') ?? price,
                  'total': returnedAmount,
                  'profit': returnedProfit,
                  'returnedGrosstotalamount': returnedGrosstotalamount,
                  'discount': returnedDiscount,
                  'cp': cp,
                  'transMode': returnedTransMode,
                  'salesMode': itemMap['returned_mode'] ?? itemMap['mode'] ?? '',
                  'customer': data['customerName'] ?? '',
                  'branch': data['branchName'] ?? '',
                  'pricingMode': itemMap['returned_pricemode'] ?? itemMap['pricemode'] ?? '',
                  'staff': data['createdBy'] ?? '',
                  'staffEmail': data['staffemail'] ?? '',
                  'receipt': data['receiptNumber'] ?? '',
                  'paymentStatus': 'returned',
                  'transactionId': data['id'] ?? '',
                  'isReturned': true,
                  'returnedQty': returnedQty,
                  'returnedAmount': returnedAmount,
                  'returnedTransMode': returnedTransMode,
                  'isCash': false,
                  'isCredit': false,
                  'isCashReturn': returnedTransMode == 'cash',
                  'isCreditReturn': returnedTransMode == 'credit',
                });
              }
            });
          }

          itemTransactions = transactions;
          notifyListeners();
        }
        List<Map<String, dynamic>> filteredItemTransactions() {
          final query = searchQuery.trim().toLowerCase();

          if (query.isEmpty) {
            return itemTransactions;
          }

          return itemTransactions.where((transaction) {
            final item = (transaction['item'] ?? '')
                .toString()
                .toLowerCase();

            final receipt = (transaction['receipt'] ?? '')
                .toString()
                .toLowerCase();

            final customer = (transaction['customer'] ?? '').toString().toLowerCase();
            final staff = (transaction['staff'] ?? '').toString().toLowerCase();

            return item.contains(query) ||
                receipt.contains(query) ||
                customer.contains(query) ||
                staff.contains(query);
          }).toList();
        }

       List<Map<String, dynamic>> filterstockTransactions() {
         final q = stockDialogSearchQuery.trim().toLowerCase();
         if (q.isEmpty) return stockTransactions;

          return stockTransactions.where((t) {
            final item = (t['item'] ?? '').toString().toLowerCase();
            final branch = (t['branch'] ?? '').toString().toLowerCase();
            final date = (t['summarydate'] ?? '').toString().toLowerCase();
            final itemId = (t['itemId'] ?? '').toString().toLowerCase();
            final opening_stock = (t['opening_stock'] ?? '').toString().toLowerCase();
            final newstock = (t['newstock'] ?? '').toString().toLowerCase();
            final sales = (t['sales'] ?? '').toString().toLowerCase();
            final credit_sales = (t['credit_sales'] ?? '').toString().toLowerCase();
            final sale_returns = (t['sale_returns'] ?? '').toString().toLowerCase();
            final purchase_returns = (t['purchase_returns'] ?? '').toString().toLowerCase();
            final damages = (t['damages'] ?? '').toString().toLowerCase();
            final transfer = (t['transfer'] ?? '').toString().toLowerCase();
            final stockin_balance = (t['stockin_balance'] ?? '').toString().toLowerCase();
            final stockout_balance = (t['stockout_balance'] ?? '').toString().toLowerCase();

            return item.contains(q) ||
                opening_stock.contains(q) ||
                newstock.contains(q) ||
                sales.contains(q) ||
                credit_sales.contains(q) ||
                sale_returns.contains(q) ||
                purchase_returns.contains(q) ||
                damages.contains(q) ||
                transfer.contains(q) ||
                stockin_balance.contains(q) ||
                stockout_balance.contains(q) ||
                branch.contains(q) ||
                date.contains(q) ||
                itemId.contains(q);
          }).toList();
        }

  List<ItemHistoryEntry> filterItemHistoryEntries() {
    final q = itemHistorySearchQuery.trim().toLowerCase();
    if (q.isEmpty) return itemHistoryEntries;

    return itemHistoryEntries.where((t) {
      return t.item.toLowerCase().contains(q) ||
          t.type.toLowerCase().contains(q) ||
          t.branch.toLowerCase().contains(q) ||
          t.staff.toLowerCase().contains(q) ||
          t.mode.toLowerCase().contains(q) ||
          t.transactionid.toLowerCase().contains(q) ||
          (t.invoiceDate ?? '').toLowerCase().contains(q) ||
          t.qty.toString().toLowerCase().contains(q) ||
          t.total.toString().toLowerCase().contains(q);
    }).toList();
  }
      void searchStockTransactions(String query) {
          final q = searchQuery.trim().toLowerCase();


          if (q.isEmpty) {
            filteredStockTransactions = List.from(stockTransactions);
          }
          else {
            filteredStockTransactions = stockTransactions.where((t) {
              final branch = (t['branch'] ?? '').toString().toLowerCase();
              final date = (t['summarydate'] ?? '').toString().toLowerCase();
              final itemId = (t['itemId'] ?? '').toString().toLowerCase();
              final item = (t['item'] ?? '').toString().toLowerCase();
              final opening_stock = (t['opening_stock'] ?? '').toString().toLowerCase();
              final newstock = (t['newstock'] ?? '').toString().toLowerCase();
              final sales = (t['sales'] ?? '').toString().toLowerCase();
              final credit_sales = (t['credit_sales'] ?? '').toString().toLowerCase();
              final sale_returns = (t['sale_returns'] ?? '').toString().toLowerCase();
              final purchase_returns = (t['purchase_returns'] ?? '').toString().toLowerCase();
              final damages = (t['damages'] ?? '').toString().toLowerCase();
              final transfer = (t['transfer'] ?? '').toString().toLowerCase();
              final stockin_balance = (t['stockin_balance'] ?? '').toString();
              final stockout_balance = (t['stockout_balance'] ?? '').toString();

              return item.contains(q) ||
              opening_stock.contains(q) ||
                  newstock.contains(q) ||
              sales.contains(q) ||
              credit_sales.contains(q) ||
              sale_returns.contains(q) ||
              purchase_returns.contains(q) ||
              damages.contains(q) ||
              transfer.contains(q) ||
              stockin_balance.contains(q) ||
              stockout_balance.contains(q) ||
              branch.contains(q) ||
              date.contains(q) ||
              itemId.contains(q);
            }).toList();
          }

          notifyListeners();
        }

      Future<void> fetchsalesregisterreport({DateTimeRange? selectedDate,String? selectedBranch,}) async {

          try {
            isloadingsalesreport = true;
            notifyListeners();
            report.clear();
            final now = DateTime.now();

            final startDate = selectedDate?.start ?? now;
            final endDate = selectedDate?.end ?? now;

            final ids =generateIds(companyid, startDate, endDate);

            final snap = await db.collection('salesSummary').where(FieldPath.documentId,whereIn: ids).get(
                const GetOptions(source: Source.serverAndCache) );

            if(snap.docs.isNotEmpty){
              report = snap.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
              report = extractItems(report, selectedBranch);
            }else{
              report = [];
            }

          } catch (e) {
            debugPrint("Error fetching Sales salesSummary: $e");
            report = [];
          } finally {
            isloadingsalesreport = false;
            notifyListeners();
          }
        }

     fetchReturnreasons() async {
    try {
      await getdata();
      final snap = await db
          .collection('return_reasons')
          .where("companyid", isEqualTo: companyid)
          .get(const GetOptions(source: Source.serverAndCache));
      returnitemreasons = snap.docs.map((doc) {
        return ReasonsModel.fromJson(doc.data());
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching stocking modes: $e");
    }
  }

  fetchStockingModes() async {
    try {
      final snap = await db
          .collection('stockingmode')
          .where("companyid", isEqualTo: companyid)
          .get(const GetOptions(source: Source.serverAndCache));
      stockingModes = snap.docs.map((doc) {
        return cropModel.fromJson(doc.data());
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching stocking modes: $e");
    }
  }

  fetchStockingModeslist({DateTimeRange? selectedDate}) async {
    try {
      final now =DateTime.now();
      final startDate =selectedDate?.start?? now;
      final endDate = selectedDate?.end ?? now;
      final start =DateTime(startDate.year,startDate.month,startDate.day);
      final end = DateTime(endDate.year,endDate.month,endDate.day,23,59,59);

      final snap = await db .collection('stockingmode')
      //  .where("companyid", isEqualTo: companyid)
          .where("created_at",isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where("created_at",isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy("created_at",descending: true)
          .get(const GetOptions(source: Source.serverAndCache));
      stockingModes = snap.docs.map((doc) {
        return cropModel.fromJson(doc.data());
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching stocking modes: $e");
    }
  }

  Future<void> fetchproductcategory() async {
    loadingproductcategory = true;
    notifyListeners();

    try {
      final snap = await db .collection('productcategoryreg')
          .where('companyId', isEqualTo: companyid).get(const GetOptions(source: Source.serverAndCache));
      productcategory = snap.docs .map((e) => Productcategorymodel.fromJson(e.data())).toList();
    } catch (e) {
      debugPrint("fetch product category error: $e");
    }

    loadingproductcategory = false;
    notifyListeners();
  }

  selectSupplier(String suplylierId) {
    selectedSupplier = suppliers.firstWhere(
          (sup) => sup.id == suplylierId,
      orElse: () => Supplier(
        id: '',
        supplier: '',
        staff: '',
        contact: '',
        company: '',
        companyid: '',
        datecreated: Timestamp.now(),
      ),
    );
    notifyListeners();
  }

  selectBranch(String branchId) {
    selectedBranch = branches.firstWhere(
          (branch) => branch.id == branchId,
      orElse: () => BranchModel(),
    );
    notifyListeners();
    return selectedBranch;
  }

  selectstockingMode(String modeid) {
    selectedStockingMode = stockingModes.firstWhere(
          (stockmode) => stockmode.id == modeid,
      orElse: () => cropModel(
        name: '',
        staff: '',
        id: '',
        date: DateTime.now(),
        companyid: '',
        company: '',
      ),
    );
    notifyListeners();
  }

  fetchWarehouses({DateTimeRange? selectedDate}) async {
    try {
      loadingWarehouses = true;
      notifyListeners();
      final snap = await db.collection('warehouse') .where('companyid', isEqualTo: companyid)
          .orderBy('created_at', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      warehouses = snap.docs .map((e) => WarehouseModel.fromMap(e.data())).toList();
    } catch (e) {
      debugPrint("Fetch warehouses error: $e");
    }

    loadingWarehouses = false;
    notifyListeners();
  }

  selectWarehouses(String warehouseid) {
    selectedwarehouse = warehouses.firstWhere(
          (warehouse) => warehouse.id == warehouseid,
      orElse: () => WarehouseModel(
        name: '',
        staff: '',
        id: '',
        date: DateTime.now(),
        companyid: '',
        company: '',
      ),
    );
    notifyListeners();
  }

  Future<void> logout(BuildContext context) async {
    _staffDocSub?.cancel();
    //await auth.signOut();
    final spref = await SharedPreferences.getInstance();

    final email = auth.currentUser?.email;
    final sessionId = spref.getString('sessionId');
    try {
      if (email != null) {
        await db.collection('staff').doc(email).update({
          'isLoggedIn': false,
          'sessionId': FieldValue.delete(),
          'lastLogout': FieldValue.serverTimestamp(),
        });
        if (sessionId != null) {
          await db.collection('staff_login_logs').doc(sessionId).update({
            'logoutTime': FieldValue.serverTimestamp(),
            'status': 'logged_out',
          });
        }
      }
    } catch (e, s) {
      debugPrint('Logout update failed: $e');
      debugPrintStack(stackTrace: s);
    }
    await spref.clear();
    await auth.signOut();

    authenticated = false;
    company = "";
    companyid = "";
    companyemail = "";
    companyphone = "";
    staff = "";
    staffemail = "";
    branch = "";
    branches = [];
    branchid = "";
    staffPosition = 0;
    salesWarehouseIds = [];
    salesWarehouseNames = [];
    salesWarehouseId = null;
    salesWarehouseName = null;
    currentStaff = null;
    accesslevel = '';
    currentCompany = null;
    subscriptionTier = 'starter';
    suppliers=[];
    await clearpermissions();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (route) => false);
    notifyListeners();
  }

  Future<void> changePassword( String currentPassword, String newPassword, ) async {
    try {
      final user = auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Current password is incorrect');
      } else if (e.code == 'weak-password') {
        throw Exception('New password is too weak');
      } else {
        throw Exception(e.message ?? 'Failed to change password');
      }
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  String normalizeAndSanitize(dynamic value) {
    if (value == null) return "na";
    String result = value.toString().trim();

    if (result.isEmpty) return "n_a";

    result = result
        .replaceAll('/', '')
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');

    result = result.toLowerCase();

    return result.isNotEmpty ? result : "n_a";
  }

  // Future<void> addOrUpdateBranch(BranchModel branch) async {
  //   String docId;
  //
  //   if (branch.id.isNotEmpty) {
  //     docId = branch.id;
  //   } else {
  //     docId = "${branch.companyid}${branch.branchname}".toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  //
  //     branch.id = docId;
  //   }
  //
  //   await db
  //       .collection('branches')
  //       .doc(docId)
  //       .set(branch.toMap(), SetOptions(merge: true));
  // }

  Future<void> addOrUpdateBranch(BranchModel branch) async {
    String docId;

    if (branch.id.isNotEmpty) {
      docId = branch.id;
    } else {
      docId = "${branch.companyid}${branch.branchname}"
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_');
      branch.id = docId;
    }

    await db.collection('branches')
        .doc(docId).set(branch.toMap(), SetOptions(merge: true));

    final idx = branches.indexWhere((b) => b.id == docId);
    if (idx != -1) {
      branches[idx] = branch;
    } else {
      branches.add(branch);
    }

    notifyListeners();
  }
  Future<void> addOrUpdateCategory(Productcategorymodel category) async {
    String docId;

    if (category.id.isNotEmpty) {
      docId = category.id;
    } else {
      docId = "${category.companyid}${category.productname}"
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_');

      category.id = docId;
    }

    await db
        .collection('productcategoryreg')
        .doc(docId)
        .set(category.toMap(), SetOptions(merge: true));
  }

  Future<void> addOrUpdatePaymentDuration(PaymentDurationModel payment) async {
    String docId;

    if (payment.id.isNotEmpty) {
      docId = payment.id;
    } else {
      docId = "${payment.companyid}${payment.paymentname}"
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_');

      payment.id = docId;
    }

    await db
        .collection('paymentdurationreg')
        .doc(docId)
        .set(payment.toMap(), SetOptions(merge: true));
  }

  Future<void> addOrUpdateAccountType(AccountTypeModel account) async {
    String docId;

    if (account.id.isNotEmpty) {
      docId = account.id;
    } else {
      final safeName = normalizeAndSanitize(account.name);
      docId = "${account.companyid}_$safeName";
      account.id = docId;
    }

    await db
        .collection('accounts')
        .doc(docId)
        .set(account.toMap(), SetOptions(merge: true));
  }

  Future<void> addOrUpdateActivityChart(ActivityModel chart) async {
    String docId;

    if (chart.id.isNotEmpty) {
      docId = chart.id;
    } else {
      final safeName = normalizeAndSanitize(chart.activityName);
      docId = "${chart.companyid}_$safeName";
      chart.id = docId;
    }

    await db
        .collection('activity_chart')
        .doc(docId)
        .set(chart.toMap(), SetOptions(merge: true));
  }

  Future<void> addOrUpdateSubAccount(SubAccountModel subAccount) async {
    String docId;

    if (subAccount.id.isNotEmpty) {
      docId = subAccount.id;
    } else {
      final safeClass = normalizeAndSanitize(subAccount.accountClass);
      final safeType = normalizeAndSanitize(subAccount.accountClassType);
      final safeName = normalizeAndSanitize(subAccount.name);
      docId = "${subAccount.companyid}_${safeClass}_${safeType}_$safeName";
      subAccount.id = docId;
    }

    await db
        .collection('sub_accounts')
        .doc(docId)
        .set(subAccount.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteBranch(String id) async {
    await db.collection('branches').doc(id).delete();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await db.collection('productcategoryreg').doc(id).delete();
    notifyListeners();
  }

  Future<void> deletePaymentDuration(String id) async {
    await db.collection('paymentdurationreg').doc(id).delete();
  }

  Future<void> forgotPassword(String email, BuildContext context) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: \\${e.toString()}')));
    }

  }

  login(String email, String password, BuildContext context) async {
    final spref = await SharedPreferences.getInstance();
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      authenticated = true;
      final userDoc = await db.collection('staff').doc(auth.currentUser!.email.toString()).get();
      // print(userDoc.data());
      if (userDoc.exists) {
        // Use StaffModel to parse the data
        currentStaff = StaffModel.fromMap(userDoc.data()!);
        branch = currentStaff!.branchname;
        branchid = currentStaff!.branchid;
         canPrint = currentStaff?.canPrint ?? false;
         canEditPrice = currentStaff?.canEditPrice ?? false;
         canSelectDate = currentStaff?.canSelectDate ?? false;
         canSellAnyBranch = currentStaff?.canSellAnyBranch ?? false;
         allowDiscount = currentStaff?.allowDiscount ?? false;
         allowDiscountCode = currentStaff?.allowDiscountCode ?? false;
        salesWarehouseIds = currentStaff!.salesWarehouseIds;
        salesWarehouseNames = currentStaff!.salesWarehouseNames;
        if (salesWarehouseIds.isNotEmpty) {
          salesWarehouseId = salesWarehouseIds.first;
          salesWarehouseName = salesWarehouseNames.isNotEmpty
              ? salesWarehouseNames.first
              : '';
        }

        List _pricingmode = currentStaff!.pricingmode;
        final companydoc = await db.collection('companies').doc(currentStaff!.companyid.toString().toUpperCase()).get();
        final branchdata = await db.collection("branches").doc(currentStaff!.branchid.toString().toLowerCase()).get();
        if (branchdata.exists) {
          selectedBranch = BranchModel.fromJson(branchdata.data()!);
        } else {
          throw Exception("Branch data not found");
        }

        if (companydoc.exists) {
          currentCompany = CompanyModel.fromMap(companydoc.data()!);
          company = currentCompany!.company;
          companyemail = currentCompany!.email;
          companyphone = currentCompany!.phone;
          subscriptionTier = currentCompany!.subscriptionTier ?? 'starter';
        } else {
          throw Exception("Company data not found");
        }
        // print("Data: ${currentStaff!.toMap()}");
        // Save to SharedPreferences
        spref.setString('email', currentStaff!.email);
        spref.setString('accesslevel', currentStaff!.accesslevel);
        spref.setString('accessLevel', currentStaff!.accesslevel);
        spref.setString('staff', currentStaff!.name);
        spref.setString('staffemail', currentStaff!.email);
        spref.setString('phone', currentStaff!.phone);
        spref.setString('companyid', currentStaff!.companyid);
        spref.setString('companyphone', currentCompany!.phone);
        spref.setString('company', currentCompany!.company);
        spref.setString('companyemail', currentCompany!.email);
        spref.setInt('staffPosition', currentStaff!.position);
        spref.setString('branch', currentStaff!.branchname);
        spref.setString('branchid', currentStaff!.branchid);
        spref.setString('branchtype', selectedBranch!.branchtype);
        spref.setString('branchaddress', selectedBranch!.address);
        spref.setString('branchphone', selectedBranch!.branchcontact);
        spref.setBool('canPrint', currentStaff!.canPrint );
        spref.setBool('canEditPrice', currentStaff!.canEditPrice );
        spref.setBool('canSelectDate', currentStaff!.canSelectDate );
        spref.setBool('canSellAnyBranch', currentStaff!.canSellAnyBranch );
        spref.setBool('allowDiscount', currentStaff!.allowDiscount );
        spref.setBool('allowDiscountCode', currentStaff!.allowDiscountCode );
        spref.setStringList('salesWarehouseIds', salesWarehouseIds);
        spref.setStringList('salesWarehouseNames', salesWarehouseNames);
        spref.setStringList('allowedPaymentMethods', currentStaff!.allowedPaymentMethods,);
        if (salesWarehouseId != null) {
          spref.setString('salesWarehouseId', salesWarehouseId!);
        }
        if (salesWarehouseName != null) {
          spref.setString('salesWarehouseName', salesWarehouseName!);
        }
        final pricingList = _pricingmode.map((e) => e.toString()).toList();
        spref.setStringList('pricingmode', pricingList);
        spref.setString('subscriptionTier', subscriptionTier);
        pricingmode = pricingList;
        // Update display name
        auth.currentUser!.updateDisplayName(currentStaff!.name);
        // Update local state
        staff = currentStaff!.name;
        staffemail = currentStaff!.email;
        companyid = currentStaff!.companyid;
        staffPosition = currentStaff!.position;
        allowedPaymentMethods = currentStaff!.allowedPaymentMethods;
        load(currentStaff!);
      }
      final sessionId = const Uuid().v4();
      spref.setString('sessionId', sessionId);
      await db.collection('staff').doc(currentStaff!.email).update({
        'isLoggedIn': true,
        'sessionId': sessionId,
        'lastLogin': FieldValue.serverTimestamp(),
      });
      await db.collection('staff_login_logs').doc(sessionId).set({
        'sessionId': sessionId,
        'companyId': currentStaff!.companyid,
        'staffEmail': currentStaff!.email,
        'staffName': currentStaff!.name,
        'branchId': currentStaff!.branchid,
        'branchName': currentStaff!.branchname,
        'loginTime': FieldValue.serverTimestamp(),
        'logoutTime': null,
        'status': 'logged_in',
      });
      await getdata();

      // Sync items cache after successful login
      //_syncItemsCache();
      listenToStaffChanges();
      notifyListeners();
     
      final landingRoute = this.landingRoute;

      Navigator.pushNamedAndRemoveUntil(context, landingRoute, (route) => false);
      //Navigator.pushNamed(context, Routes.home);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
        SnackBar snackBar = SnackBar(
          content: Text('No user found for that email.'),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
        SnackBar snackBar = SnackBar(
          content: Text('Wrong password provided for that user.'),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
      SnackBar snackBar = SnackBar(content: Text('Error: ${e.message}'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    // Implement login logic here
  }

 Future<void> loginAsCompanyAdmin({ required String companyId, required String companyName,  required String companyEmailVal, required String companyPhoneVal, required String staffName,}) async {
    final spref = await SharedPreferences.getInstance();

    company = companyName;
    companyid = companyId;
    companyemail = companyEmailVal;
    companyphone = companyPhoneVal;
    staff = staffName;
    staffemail = auth.currentUser?.email ?? '';
    accesslevel = 'super admin';
    branchtype = 'Sales Branch';
    canPrint = false;
    canEditPrice = false;
    canSelectDate = false;
    canSellAnyBranch = false;
    allowDiscount = false;
    allowDiscountCode = false;
    final companydoc = await db.collection('companies').doc(companyId).get();
    if (companydoc.exists) {
      currentCompany = CompanyModel.fromMap(companydoc.data()!);
      company = currentCompany!.company;
      companyemail = currentCompany!.email;
      companyphone = currentCompany!.phone;
      subscriptionTier = currentCompany!.subscriptionTier;
    }
    final userDoc = await db.collection('staff').doc(companyemail.toString()).get();

    if (userDoc.exists) {
      currentStaff = StaffModel.fromMap(userDoc.data()!);
      branch = currentStaff!.branchname;
      branchid = currentStaff!.branchid;
      canPrint = currentStaff?.canPrint ?? false;
      canEditPrice = currentStaff?.canEditPrice ?? false;
      canSelectDate = currentStaff?.canSelectDate ?? false;
      canSellAnyBranch = currentStaff?.canSellAnyBranch ?? false;
      allowDiscount = currentStaff?.allowDiscount ?? false;
      allowDiscountCode = currentStaff?.allowDiscountCode ?? false;
      salesWarehouseIds = currentStaff!.salesWarehouseIds;
      salesWarehouseNames = currentStaff!.salesWarehouseNames;
      if (salesWarehouseIds.isNotEmpty) {
        salesWarehouseId = salesWarehouseIds.first;
        salesWarehouseName = salesWarehouseNames.isNotEmpty
            ? salesWarehouseNames.first
            : '';
      }

      List _pricingmode = currentStaff!.pricingmode;
     final branchdata = await db.collection("branches").doc(currentStaff!.branchid.toString().toLowerCase()).get();
      if (branchdata.exists) {
        selectedBranch = BranchModel.fromJson(branchdata.data()!);
      } else {
        throw Exception("Branch data not found");
      }


      // print("Data: ${currentStaff!.toMap()}");
      // Save to SharedPreferences
      spref.setString('email', currentStaff!.email);
      spref.setString('accesslevel', currentStaff!.accesslevel);
      spref.setString('accessLevel', currentStaff!.accesslevel);
      spref.setString('staff', currentStaff!.name);
      spref.setString('staffemail', currentStaff!.email);
      spref.setString('phone', currentStaff!.phone);
      spref.setString('companyid', currentStaff!.companyid);
      spref.setString('companyphone', currentCompany!.phone);
      spref.setString('company', currentCompany!.company);
      spref.setString('companyemail', currentCompany!.email);
      spref.setInt('staffPosition', currentStaff!.position);
      spref.setString('branch', currentStaff!.branchname);
      spref.setString('branchid', currentStaff!.branchid);
      spref.setString('branchtype', selectedBranch!.branchtype);
      spref.setString('branchaddress', selectedBranch!.address);
      spref.setString('branchphone', selectedBranch!.branchcontact);
      spref.setBool('canPrint', currentStaff!.canPrint );
      spref.setBool('canEditPrice', currentStaff!.canEditPrice );
      spref.setBool('canSelectDate', currentStaff!.canSelectDate );
      spref.setBool('canSellAnyBranch', currentStaff!.canSellAnyBranch );
      spref.setBool('allowDiscount', currentStaff!.allowDiscount );
      spref.setBool('allowDiscountCode', currentStaff!.allowDiscountCode );
      spref.setStringList('salesWarehouseIds', salesWarehouseIds);
      spref.setStringList('salesWarehouseNames', salesWarehouseNames);
      spref.setStringList('allowedPaymentMethods', currentStaff!.allowedPaymentMethods,);
      if (salesWarehouseId != null) {
        spref.setString('salesWarehouseId', salesWarehouseId!);
      }
      if (salesWarehouseName != null) {
        spref.setString('salesWarehouseName', salesWarehouseName!);
      }
      final pricingList = _pricingmode.map((e) => e.toString()).toList();
      spref.setStringList('pricingmode', pricingList);

      pricingmode = pricingList;
      // Update display name
      auth.currentUser!.updateDisplayName(currentStaff!.name);
      // Update local state
      staff = currentStaff!.name;
      staffemail = currentStaff!.email;
      companyid = currentStaff!.companyid;
      staffPosition = currentStaff!.position;
      allowedPaymentMethods = currentStaff!.allowedPaymentMethods;
      load(currentStaff!);
    }
    spref.setString('company', company);
    spref.setString('companyid', companyid);
    spref.setString('companyemail', companyemail);
    spref.setString('companyphone', companyphone);
    spref.setString('staff', staff);
    spref.setString('staffemail', staffemail);
    spref.setString('accesslevel', accesslevel);
    spref.setString('accessLevel', accesslevel);
    spref.setInt('staffPosition', staffPosition);
    spref.setString('branch', branch);
    spref.setString('branchid', branchid);
    spref.setString('branchtype', branchtype);
    spref.setString('subscriptionTier', subscriptionTier);
    await getdata();
    listenToStaffChanges();
    notifyListeners();
  }

  Map<String, dynamic> formatApiItem(
      Map<String, dynamic> apiItem,
      String companyid,
      ) {
    final now = DateTime.now();
    // Default Firestore modes structure
    final defaultModes = {
      "carton": {
        "name": "carton",
        "qty": "24",
        "rp": "140",
        "sp": "140",
        "wp": "140",
      },
      "single": {"name": "Single", "qty": "1", "rp": "8", "sp": "8", "wp": "8"},
    };
    final modes =  (apiItem['modes'] is Map && (apiItem['modes'] as Map).isNotEmpty)
        ? apiItem['modes']
        : defaultModes;
    return {
      'id': apiItem['id']?.toString() ?? '',
      'no': '',
      'name': apiItem['name'] ?? '',
      'barcode': apiItem['barcode'] ?? '',
      'costprice': apiItem['cost_price']?.toString() ?? '0',
      'retailmarkup': apiItem['rmarkup']?.toString() ?? '0',
      'wholesalemarkup': apiItem['wmarkup']?.toString() ?? '0',
      'retailprice': apiItem['selling_price']?.toString() ?? '0',
      'wholesaleprice': apiItem['wselling_price']?.toString() ?? '0',
      'producttype': apiItem['product_type'] ?? 'product',
      'modes': modes,
      'productcategory': apiItem['category'] ?? '',
      'warehouse': apiItem['warehouse'] ?? '',
      'openingstock': apiItem['balance']?.toString() ?? '0',
      'company': '',
      'companyid': companyid,
      'sminqty': 5,
      'createdAt': now,
      'updatedAt': now,
      'updatedBy': apiItem['updatedby'] ?? '',
      'image': apiItem['image'] ?? '',
    };
  }

  Future<void> syncItemsFromApi() async {
    //setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('https://queenlatifahenterprise.com/pos/api/pix/items'),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> items = decoded['data'] ?? [];
        // Get companyid from provider
        String sanitize(String input) {
          return input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
        }

        for (final item in items) {
          final formatted = formatApiItem(
            item as Map<String, dynamic>,
            companyid,
          );
          final barcodeRaw = formatted['barcode']?.toString() ?? '';
          if (barcodeRaw.isEmpty) continue; // skip if no barcode
          final barcode = sanitize(barcodeRaw);
          final docId = '${sanitize(companyid)}_$barcode';
          await db
              .collection('itemsreg')
              .doc(docId)
              .set(formatted, SetOptions(merge: true));
        }
      } else {
        print('Sync error: Failed to fetch items: ���{response.statusCode}');
        throw Exception('Failed to fetch items: ���{response.statusCode}');
      }
    } on SocketException catch (_) {
      print('Sync error: No internet connection.');
    } catch (e, stack) {
      print('Sync error: $e');
      print(stack);
    }
  }

  getdata() async {
    try {
      final spref = await SharedPreferences.getInstance();
      company = spref.getString('company') ?? '';
      companyid = spref.getString('companyid') ?? '';
      branchid = spref.getString('branchid') ?? '';
      branch = spref.getString('branch') ?? '';
      canPrint =spref.getBool('canPrint',)?? false;
      canEditPrice = spref.getBool('canEditPrice',)?? false;
      canEditPrice = spref.getBool('canEditPrice',)?? false;
      canSelectDate = spref.getBool('canSelectDate',)?? false;
      canSellAnyBranch = spref.getBool('canSellAnyBranch',)?? false;
      canSellAnyBranch = spref.getBool('canSellAnyBranch',)?? false;
      allowDiscount = spref.getBool('allowDiscount',)?? false;
      allowDiscountCode = spref.getBool('allowDiscountCode',)?? false;
      accesslevel = spref.getString('accesslevel') ?? spref.getString('accessLevel') ?? '';
      companyemail = spref.getString('companyemail') ?? '';
      companyphone = spref.getString('companyphone') ?? '';
      staff = spref.getString('staff') ?? '';
      staffemail = spref.getString('staffemail') ?? '';
      branchtype = spref.getString('branchtype') ?? '';
      branchaddress =spref.getString('branchaddress')?? '';
      branchphone =spref.getString('branchphone')?? '';
      staffPosition = spref.getInt('staffPosition') ?? 0;
      pricingmode = spref.getStringList('pricingmode') ?? [];
      salesWarehouseIds = spref.getStringList('salesWarehouseIds') ?? [];
      salesWarehouseNames = spref.getStringList('salesWarehouseNames') ?? [];
      allowedPaymentMethods = spref.getStringList('allowedPaymentMethods') ?? [];
      salesWarehouseId = spref.getString('salesWarehouseId');
      salesWarehouseName = spref.getString('salesWarehouseName');
      salesWarehouseIds= spref.getStringList('salesWarehouseIds') ?? [];
      subscriptionTier = spref.getString('subscriptionTier') ?? 'starter';
      await loadFromPrefs();
      await loadTierFeatures();
      //print(salesWarehouseIds);
      if ((salesWarehouseId == null || salesWarehouseId!.isEmpty) &&
          salesWarehouseIds.isNotEmpty) {
        salesWarehouseId = salesWarehouseIds.first;
        salesWarehouseName = salesWarehouseNames.isNotEmpty
            ? salesWarehouseNames.first
            : '';
      }
    } catch (e) {
      print(e);
    }
    listenToStaffChanges();
    // Re-attach dashboard stats listener now that companyid is known.
    //salesTotals();
    notifyListeners();
  }

  // Sync items cache in background
  void _syncItemsCache() async {
    if (companyid.isEmpty) return;

    try {
      debugPrint('Starting background item sync...');
      await itemCache.syncItems(companyid);
      final stats = itemCache.getCacheStats();
      debugPrint(' Item cache synced: ${stats['totalItems']} items');
      notifyListeners();
    } catch (e) {
      debugPrint(' Error syncing item cache: $e');
    }
  }

  // Force sync items cache
  Future<void> forceSyncItems() async {
    if (companyid.isEmpty) return;

    try {
      debugPrint('🔄 Force syncing items...');
      await itemCache.syncItems(companyid, forceSync: true);
      final stats = itemCache.getCacheStats();
      debugPrint(' Items force synced: ${stats['totalItems']} items');
      notifyListeners();
    } catch (e) {
      debugPrint(' Error force syncing items: $e');
      rethrow;
    }
  }


  //fetching of items
     fetchItems() {
      loading = true;
      error = null;
      sub?.cancel();
          try {

            sub = db.collection('itemsreg').where(
                'companyid', isEqualTo: companyid.toUpperCase())
                .snapshots().listen((snapshot) {
              items =
                  snapshot.docs.map((doc) => ItemModel.fromDoc(doc)).toList();
              items.sort((a, b) => a.name.compareTo(b.name));
              loading = false;
              notifyListeners();
            },
              onError: (e) {
                loading = false;
                items = [];
                error = _friendlyError(e);
                notifyListeners();
              },
            );

            notifyListeners();
          }
    catch(e){

    }
  }



  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('index')) {
      return 'Database index not ready. Please try again later.';
    }
    if (msg.contains('permission')) {
      return 'You do not have permission to view these items.';
    }
    if (msg.contains('network')) {
      return 'No internet connection. Check your network.';
    }

    return 'Failed to load items. Please try again.';
  }

  void setSelectedBranch(String id, String name) {
    branchid = id;
    branch = name;
    notifyListeners();
  }

  void setSalesWarehouse(String? id, String? name) {
    salesWarehouseId = id;
    salesWarehouseName = name;
    notifyListeners();
  }

  bool get isSalesPoint {
    final t = branchtype.toLowerCase().trim();
    return t == 'sales point' || t == 'salespoint';
  }

  String get activeBranchId {
    if (isSalesPoint &&
        salesWarehouseId != null &&
        salesWarehouseId!.isNotEmpty) {
      return salesWarehouseId!;
    }
    return branchid;
  }

  String get activeBranchName {
    if (isSalesPoint &&
        salesWarehouseName != null &&
        salesWarehouseName!.isNotEmpty) {
      return salesWarehouseName!;
    }
    return branch;
  }

  bool get canSelectBranch {
    final n = accesslevel.toLowerCase().replaceAll(' ', '');
    return {'admin', 'manager', 'superadmin'}.contains(n);
  }


  String get normalizedAccessLevel => accesslevel.toLowerCase().trim();
  String get normalizedAccessLevelNoSpaces => accesslevel.toLowerCase().replaceAll(' ', '');
  bool get isSalesStaff =>
       normalizedAccessLevel == 'sales attendance' ||
       normalizedAccessLevel == 'sales manager';
    String get landingRoute {
    final role = normalizedAccessLevelNoSpaces;
    if (role.contains('cashier')) {
      return Routes.cashierPage;
    }
    else if (role == 'salesattendance' ||
        role == 'salesmanager' ||
        role.contains('operations') ||
        role.contains('stockofficer') ||
        role.contains('accountant') ||
        role.contains('sales')) {
      return Routes.roleAccessDashboard;
    } else if (role.contains('superadmin')) {
      return Routes.home;
    } else if (role.contains('systemadmin')) {
      return Routes.systemadmin;
    } else if (role.contains('admin')) {
      return Routes.home;
    } else {
      return Routes.login;
    }

  }

  bool get isSuperAdmin => normalizedAccessLevelNoSpaces == 'superadmin';
  bool get isAdmin => normalizedAccessLevelNoSpaces == 'admin' || normalizedAccessLevelNoSpaces == 'manager' || isSuperAdmin;
  bool get canDeleteRecords => isSuperAdmin || isAdmin;
        Future<void> initUserAndBranches() async {
          try {
            await getdata();

            final isAdmin = ['admin', 'super admin'].contains(accesslevel);

            if (isAdmin) {
              final snap = await db.collection('branches')
                  .where('companyid', isEqualTo: companyid)
                  .where('branchtype', isNotEqualTo: 'Warehouse')
                  .orderBy('branchtype')
                  .orderBy('branchname')
                  .get();

              branches = snap.docs
                  .map((doc) => BranchModel.fromJson({...doc.data(), 'id': doc.id}))
                  .toList();

              if (branches.length == 1) {
                branchid = branches.first.id;
                branch = branches.first.branchname;
              }
              else {
                branchid = '';
                branch = '';
              }

            }
             else {
              branch = '';
            }

          //  print('Branch length: ${branch.length}');

          } catch (e) {
            debugPrint('Error loading branches: $e');
            branch = '';
          }
          notifyListeners();
        }
  Future<void> fetchsalesitem(String query) async {
    if (query.isEmpty) {
      salesItem = [];
      notifyListeners();
      return;
    }

    loadingsale = true;
    notifyListeners();

    try {
      final snapshot = await db.collection('sales').doc(query).get();

      if (snapshot.exists) {
        final data = snapshot.data()!;

        final Map<String, dynamic> itemsMap =
        data['items'] is Map ? Map<String, dynamic>.from(data['items']) : {};


        final Map<String, dynamic> topdata =
        Map<String, dynamic>.from(data)..remove('items');

        salesItem = itemsMap.entries.map((entry) {
          final String itemkey = entry.key;
          final Map<String, dynamic> itemData =
          Map<String, dynamic>.from(entry.value);

          return {
            'itemkey': itemkey,
            ...{
              for (var e in topdata.entries)
                'returned_${e.key}': e.value
            },

            ...{
              for (var e in itemData.entries)
                'returned_${e.key}': e.value
            },
          };
        }).toList();
      } else {
        salesItem = [];
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      salesItem = [];
    }

    loadingsale = false;
    notifyListeners();
  }

        Future<void> deletedamage(String id) async {
          try {
            final damageRef = db.collection('damageitems').doc(id);
            final damageDoc = await damageRef.get();
            final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
            final formattedDateTime =
            DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
            if (damageDoc.exists) {
              await db.collection('deletedcollection').doc(id).set({
                ...damageDoc.data() as Map<String, dynamic>,
                'deleted_at':    FieldValue.serverTimestamp(),
                'deleted_by':    staff,
                'deleted_email': staffemail,
                'type': 'damages',
                'originalCollection': 'damages',
                'originalId': id,
                'datedmy': formattedDate,
              });
            }

            await damageRef.delete();
            damages.removeWhere((d) => d.id == id);
            notifyListeners();
          } catch (e) {
            print("Error deleting damage item: $e");
            rethrow;
          }
        }


   Future<void> deletesalesreturn(String id) async {
          try {
            final salesReturnRef = db.collection('salesreturn').doc(id);
            final salesRef = db.collection('sales').doc(id);
            final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
            final returnDoc = await salesReturnRef.get();

            if (returnDoc.exists) {
              final returnData = returnDoc.data() as Map<String, dynamic>;

              final returnedItems =
                  returnData['returned_items'] as Map<String, dynamic>? ?? {};

              await db.collection('deletedcollection').doc(id).set({
                ...returnData,
                'deleted_at':    FieldValue.serverTimestamp(),
                'deleted_by':    staff,
                'deleted_email': staffemail,
                'branchid': branchid,
                'type': 'salesreturn',
                'originalId': id,
                'companyid': companyid,
                'datedmy': formattedDate,
              });


              final Map<String, dynamic> updates = {
                'isreturned': false,
                'isreturned_dateymd': FieldValue.delete(),
                'returned_updatedat': FieldValue.delete(),
                'returned_updatedby': FieldValue.delete(),
                'staffemailupdated': FieldValue.delete(),
              };

              returnedItems.forEach((key, value) {
                final item = Map<String, dynamic>.from(value as Map);

                item.forEach((field, _) {
                  if (field.startsWith('returned_')) {
                    updates['items.$key.$field'] = FieldValue.delete();
                  }
                });

                updates['items.$key.status'] = FieldValue.delete();
                updates['items.$key.itemkey'] = FieldValue.delete();
              });

              if ((await salesRef.get()).exists) {
                await salesRef.update(updates);
              }
            }

            await salesReturnRef.delete();

            salesreturn.removeWhere((d) => d.id == id);

            notifyListeners();
          } catch (e) {
            print("Error deleting sales return item: $e");
          }
        }

     Future<void> deletesalesview(String id, String receipt) async {
          try {
            final salesRef  = db.collection('sales').doc(id);
            final salesDoc  = await salesRef.get();
            final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
            final formattedDateTime =
            DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
            if (salesDoc.exists) {

              await db.collection('deletedcollection').doc(id).set({
                ...salesDoc.data() as Map<String, dynamic>,
                'deleted_at':    FieldValue.serverTimestamp(),
                'deleted_by':    staff,
                'type': 'sales',
                'originalId': id,
                'status': 'deleted',
                'deleted_email': staffemail,
                'branchid': branchid,
                'companyid': companyid,
                'datedmy': formattedDate,

              });
            }

            await salesRef.delete();

            final returnSnap = await db
                .collection('salesreturn')
                .where('returned_receiptid', isEqualTo: receipt)
                .limit(1)
                .get();

            final batch = db.batch();
            for (var doc in returnSnap.docs) {
              await db.collection('deletedreturns').doc(doc.id).set({
                ...doc.data(),
                'deleted_at':        FieldValue.serverTimestamp(),
                'deleted_by':        staff,
                'deleted_email':     staffemail,
                'deleted_via_sales': true,
              });
              batch.delete(doc.reference);
            }

            await batch.commit();

            salesview.removeWhere((d) => d.id == id);
            notifyListeners();
          } catch (e) {
            print("Error deleting sales + returns: $e");
          }
        }


  Future<void> deletebundleview(String id) async {
    try {
      final bundleRef = db.collection('bundle').doc(id);
      final bundleDoc = await bundleRef.get();
      final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final formattedDateTime =
      DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
      if (bundleDoc.exists) {
        await db.collection('deletedbundles').doc(id).set({
          ...bundleDoc.data() as Map<String, dynamic>,
          'deleted_at':    FieldValue.serverTimestamp(),
          'deleted_by':    staff,
          'deleted_email': staffemail,
          'type': 'bundle',
          'originalCollection': 'bundle',
          'originalId': id,
          'datedmy': formattedDate,
        });
      }

      await bundleRef.delete();
      bundleview.removeWhere((d) => d['id'] == id);
      notifyListeners();
    } catch (e) {
      print("Error deleting sales return item: $e");
    }
  }
  Future<void> deleteImagesFromStorage(List urls) async {
          for (final url in urls) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(url);
              await ref.delete();
            } catch (e) {
              debugPrint("Delete error: $e");
            }
          }
        }
  Future<void> deleteUploadReceipt(String id,List urls) async {

    try {
      await deleteImagesFromStorage(urls);
      await db.collection('uploadreceipt').doc(id).delete();
      receiptList.removeWhere((d) => d['id'] == id);
      notifyListeners();
    } catch (e) {
      print("Error deleting sales return item: $e");
    }
  }

  DateTimeRange? selectedDate;
  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    selectedDate = range;
    // fetchCustomers();
  }
  Future<void> deleteCustomer(String id) async {
    await db.collection('customers').doc(id).delete();
    customerlist.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> fetchVat() async {
    try {
      isloadingvatlist =true;
      final snapshot = await db.collection('vat')
          .where('companyid', isEqualTo: companyid)
          .get();

      vatList = snapshot.docs.map((doc) {
        return ConfigureVatModel.fromJson(doc.data());
      }).toList();
      isloadingvatlist =false;
      notifyListeners();
    } catch (e) {
      isloadingvatlist =false;
      print("Error fetching VAT: $e");
    }
  }

  Future<void> fetchaddVat() async {
    try {
      isloadingaddvatlist =true;
      final snapshot = await db
          .collection('addvat')
          .where('companyid', isEqualTo: companyid)
          .get();

      addvatList  = snapshot.docs.map((doc) {
        return addTaxVatModel.fromJson(doc.data());
      }).toList();
       isloadingaddvatlist =false;
      notifyListeners();
    } catch (e) {
      isloadingaddvatlist =false;
      print("Error fetching VAT: $e");
    }
  }

 Future<List<ProductModel>> fetchProducts() async {
    try {
      loadingproducts = true;
      notifyListeners();

      final snapshot = await db.collection('itemsreg')
          .where('companyid', isEqualTo: companyid).get();
      products = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();

      loadingproducts = false;
      notifyListeners();

      return products;
    } catch (e) {
      print("Error fetching products: $e");
      loadingproducts = false;
      notifyListeners();
      return [];
    }
  }
 /*
  Future<void> fetchbundlesales({  String? selectedBranch, }) async {

    try {
      isloadingsalesbundle = true;
      notifyListeners();


      final snap = await db
          .collection('bundle')
          .where("companyid", isEqualTo: companyid)
          .get(const GetOptions(source: Source.serverAndCache));

      bundleview = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        return {
          'name': data['name'] ?? '',
          'id':  doc.id,
          'companyid': data['companyid'] ?? '',
          'isActive': data['isActive'] ?? true,
          'branchid': data['branchid'] ?? '',
          'barcode': data['barcode'] ?? '',
          'producttype': data['producttype'] ?? '',
          'pcategory': data['pcategory'] ?? '',
          'company': data['company'] ?? '',
          'createdat': data['createdat'],
          'staff': data['staff'] ?? '',
          'items': data['items'] ?? [],
          'modes': data['modes'] ?? {},
        };
      }).toList();
      bundleviewitemodel =snap.docs.map((doc)=>ItemModel.fromMap(doc.data())).toList();

    } catch (e) {
      debugPrint("Error fetching bundle view: $e");
    }

    isloadingsalesbundle = false;
    notifyListeners();
  }
*/

   Future<void> fetchbundlesales({String? selectedBranch}) async {
          try {
            isloadingsalesbundle = true;
            notifyListeners();

            Query query = db.collection('bundle').where('companyid', isEqualTo: companyid);

            if (selectedBranch != null && selectedBranch.isNotEmpty) {
              query = query.where('branchid', isEqualTo: selectedBranch);
            }

            final snap = await query.get(
              const GetOptions(source: Source.serverAndCache),
            );

            bundleview = snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'name': data['name'] ?? '',
                'id' : doc.id,
                'companyid': data['companyid']?? '',
                'isActive': data['isActive'] ?? true,
                'branchid': data['branchid'] ?? '',
                'barcode': data['barcode'] ?? '',
                'producttype':data['producttype'] ?? '',
                'pcategory':data['pcategory'] ?? '',
                'company': data['company'] ?? '',
                'createdat' : data['createdat'],
                'staff': data['staff']?? '',
                'items' : data['items'] ?? [],
                'modes' : data['modes']?? {},
              };
            }).toList();

            bundleviewitemodel = snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ItemModel.fromMap({
                ...data,
                'id': doc.id,
              });
            }).toList();

          } catch (e) {
            debugPrint('Error fetching bundle view: $e');
          }

          isloadingsalesbundle = false;
          notifyListeners();
        }
   List<Map<String, dynamic>> filterbundlesales() {
    if (searchQuery.isEmpty) return bundleview;

    final q = searchQuery.toLowerCase();

    return bundleview.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final id = (s['id'] ?? '').toString().toLowerCase();
      final company = (s['company'] ?? '').toString().toLowerCase();
      final branch = (s['branchid'] ?? '').toString().toLowerCase();
      final producttype = (s['producttype'] ?? '').toString().toLowerCase();

      final topLevelMatch =
          name.contains(q) ||
              id.contains(q) ||
              company.contains(q) ||
              branch.contains(q) ||
              producttype.contains(q);

      //  items is LIST, not Map
      final List items = s['items'] ?? [];

      final itemMatch = items.any((item) {
        if (item is Map<String, dynamic>) {
          final itemName = item['item']?.toString().toLowerCase() ?? '';
          final itemId = item['itemid']?.toString().toLowerCase() ?? '';
          final mode = item['mode']?.toString().toLowerCase() ?? '';
          final price = item['price']?.toString().toLowerCase() ?? '';
          final quantity = item['quantity']?.toString().toLowerCase() ?? '';
          final totalamount =
              item['totalamount']?.toString().toLowerCase() ?? '';
          final totalpieces =
              item['totalpieces']?.toString().toLowerCase() ?? '';
          final barcode = item['barcode']?.toString().toLowerCase() ?? '';

          return itemName.contains(q) ||
              itemId.contains(q) ||
              mode.contains(q) ||
              price.contains(q) ||
              quantity.contains(q) ||
              totalamount.contains(q) ||
              totalpieces.contains(q) ||
              barcode.contains(q);
        }
        return false;
      });

      return topLevelMatch || itemMatch;
    }).toList();
  }

  Future<void> fetchUploadReceipts({String? selectedBranch}) async {
    try {
      isLoadingReceipt = true;
      notifyListeners();

      Query query = db.collection('uploadreceipt');

      if (selectedBranch != null && selectedBranch.isNotEmpty) {
        query = query.where('branchid', isEqualTo: selectedBranch);
      }

      final snapshot = await query.orderBy('createdat', descending: true).get();

      receiptList = snapshot.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching receipts: $e");
    }

    isLoadingReceipt = false;
    notifyListeners();
  }
  List<Map<String, dynamic>> filterUploadReceipts() {
    if (searchQuery.isEmpty) return receiptList;

    final q = searchQuery.toLowerCase();

    return receiptList.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final id = (s['id'] ?? '').toString().toLowerCase();
      final company = (s['company'] ?? '').toString().toLowerCase();
      final branch = (s['branchid'] ?? '').toString().toLowerCase();
      final receiptUrl = (s['receiptUrl'] ?? '').toString().toLowerCase();
      final staff = (s['staff'] ?? '').toString().toLowerCase();

      final topLevelMatch =
                        name.contains(q) || id.contains(q) ||
                        company.contains(q) ||  branch.contains(q) ||
                         staff.contains(q) || receiptUrl.contains(q);

      return topLevelMatch ;
    }).toList();
  }
  String sampleUrl = '';
  Future<void> getSampleUrl() async {
    try {
      final doc = await db.collection('sampleCsvUrl') .doc('sampleCsvUrl').get();
      if (doc.exists && doc.data() != null) {
        sampleUrl = (doc.data()!['url'] ?? '').toString().trim();

      }
    } catch (e) {
      debugPrint('Error fetching sample URL: $e');
    }
  }
  final List<CashDenomination> denominations = [
    CashDenomination(value: 0.1),
    CashDenomination(value: 0.20),
    CashDenomination(value: 0.50),
    CashDenomination(value: 1),
    CashDenomination(value: 2),
    CashDenomination(value: 5),
    CashDenomination(value: 10),
    CashDenomination(value: 20),
    CashDenomination(value: 50),
    CashDenomination(value: 100),
    CashDenomination(value: 200),
  ];

  void updateCount(int index, String value) {
    denominations[index].count = int.tryParse(value) ?? 0;
    notifyListeners();
  }

  void clearCloseSaleForm() {
    for (final item in denominations) {
      item.count = 0;
    }
    editingCloseSaleIndex = null;
    notifyListeners();
  }

  void deleteCloseSaleRecord(int index) {
    if (index < 0 || index >= closeSaleRecords.length) return;
    closeSaleRecords.removeAt(index);
    if (editingCloseSaleIndex != null && editingCloseSaleIndex == index) {
      clearCloseSaleForm();
    }
    notifyListeners();
  }

  double get total {
    return denominations.fold(0, (sum, item) => sum + item.total);
  }

  double getDenominationTotal(int index) {
    return denominations[index].total;
  }


  // Future<void> fetchcloseSales([DateTime? dtPeriod]) async {
  //   try {
  //     isloadingclosesale = true;
  //     notifyListeners();
  //
  //     final date = dtPeriod ?? DateTime.now();
  //
  //     final ymd = DateFormat('yyyy-MM-dd').format(date);
  //    print(date);
  //    print(ymd);
  //     // Clear previous results
  //     closesales = [];
  //
  //     final cleanStaff = staff.replaceAll(' ', '').toLowerCase();
  //     final isAdmin =
  //         accesslevel.toLowerCase() == 'systemadmin' ||
  //         accesslevel.toLowerCase() == 'super admin';
  //
  //     if (isAdmin) {
  //       final snap = await db
  //           .collection('closeSales')
  //           .where('companyid', isEqualTo: companyid)
  //           .get(const GetOptions(source: Source.serverAndCache));
  //
  //       closesales = snap.docs
  //           .where((doc) {
  //         // Document ID format:
  //         // companyid-staffname-yyyy-MM-dd
  //         final parts = doc.id.split('-');
  //
  //         if (parts.length < 4) {
  //           return false;
  //         }
  //
  //         final docDate = parts.sublist(parts.length - 3).join('-');
  //
  //         return docDate == ymd;
  //       })
  //           .map((doc) {
  //         final data = doc.data();
  //
  //         return {
  //           'id': doc.id,
  //           'companyid': data['companyid'] ?? '',
  //           'branchid': data['branchid'] ?? '',
  //           'createdAt': data['createdAt'],
  //           'staff': data['staff'] ?? '',
  //           'money': data['money'] ?? [],
  //           'total': data['total'] ?? 0,
  //         };
  //       })
  //      .toList();
  //     } else {
  //
  //       final id = '$companyid-$cleanStaff-$ymd';
  //
  //       final snap = await db
  //           .collection('closeSales')
  //           .doc(id)
  //           .get(const GetOptions(source: Source.serverAndCache));
  //
  //       final data = snap.data();
  //
  //       if (data != null && data.isNotEmpty) {
  //         closesales = [
  //           {
  //             'id': snap.id,
  //             'companyid': data['companyid'] ?? '',
  //             'branchid': data['branchid'] ?? '',
  //             'createdAt': data['createdAt'],
  //             'staff': data['staff'] ?? '',
  //             'money': data['money'] ?? [],
  //             'total': data['total'] ?? 0,
  //           }
  //         ];
  //       }
  //     }
  //     print(closesales);
  //   } catch (e) {
  //     debugPrint("Error fetching close sales: $e");
  //   } finally {
  //     isloadingclosesale = false;
  //     notifyListeners();
  //   }
  // }
  //
  // Future<void> deleteCloseSale(String id) async {
  //   try {
  //     await db.collection('closeSales').doc(id).delete();
  //     closesales.removeWhere((d) => d['id'] == id);
  //     notifyListeners();
  //   } catch (e) {
  //     print("Error deleting close sale item: $e");
  //   }
  // }


  Future<void> saveCloseSale({
    required List<Map<String, dynamic>> money,
    required num total,
    String? docId,
  }) async {
    try {
      // Date used for the close sale
      final now = DateTime.now();

      // YYYY-MM-DD
      final ymd = DateFormat('yyyy-MM-dd').format(now);

      // Clean staff name
      final cleanStaff = staff
          .replaceAll(' ', '')
          .toLowerCase();

      // ----------------------------------------------------------
      // If editing, use the existing document ID.
      // If creating, generate a new ID.
      // ----------------------------------------------------------
      final id = docId ?? '$companyid-$cleanStaff-$ymd';

      final record = {
        'companyid': companyid,
        'branchid': branchid,
        'staff': staff,
        'money': money,
        'total': total,

        // Important: used for date-based queries
        'ymd': ymd,

        // Keep the actual timestamp
        'createdAt': FieldValue.serverTimestamp(),

        // Useful for identifying the user/role
        'staffPosition': staffPosition,
      };

      await db
          .collection('closeSales')
          .doc(id)
          .set(
        record,
        SetOptions(merge: docId != null),
      );

      debugPrint(
        docId == null
            ? 'Close sale created: $id'
            : 'Close sale updated: $id',
      );
    } catch (e) {
      debugPrint('Error saving close sale: $e');
      rethrow;
    }
  }


// ============================================================
// CLOSE SALES - FETCH
// ============================================================

  Future<void> fetchcloseSales([DateTime? dtPeriod]) async {
    try {
      isloadingclosesale = true;
      notifyListeners();

      // ----------------------------------------------------------
      // Default to TODAY if no date was supplied
      // ----------------------------------------------------------
      final date = dtPeriod ?? DateTime.now();

      // YYYY-MM-DD
      final ymd = DateFormat('yyyy-MM-dd').format(date);

      // Clear old results
      closesales = [];

      // ----------------------------------------------------------
      // Normalize role
      // ----------------------------------------------------------
      final role = accesslevel
          .trim()
          .toLowerCase()
          .replaceAll('_', '')
          .replaceAll('-', '')
          .replaceAll(' ', '');

      final isAdmin =
          role == 'systemadmin' ||
              role == 'superadmin';

      // ----------------------------------------------------------
      // ADMIN / SUPER ADMIN
      // Fetch ALL close sales for company + selected date
      // ----------------------------------------------------------
      if (isAdmin) {
        final snap = await db
            .collection('closeSales')
            .where(
          'companyid',
          isEqualTo: companyid,
        )
            .where(
          'ymd',
          isEqualTo: ymd,
        )
            .get(
          const GetOptions(
            source: Source.serverAndCache,
          ),
        );

        closesales = snap.docs.map((doc) {
          final data = doc.data();

          return {
            'id': doc.id,
            'companyid': data['companyid'] ?? '',
            'branchid': data['branchid'] ?? '',
            'createdAt': data['createdAt'],
            'ymd': data['ymd'] ?? '',
            'staff': data['staff'] ?? '',
            'staffPosition': data['staffPosition'] ?? '',
            'money': data['money'] ?? [],
            'total': data['total'] ?? 0,
          };
        }).toList();

        // Optional: alphabetical staff order
        closesales.sort((a, b) {
          final staffA =
          (a['staff'] ?? '').toString().toLowerCase();

          final staffB =
          (b['staff'] ?? '').toString().toLowerCase();

          return staffA.compareTo(staffB);
        });
      }

      // ----------------------------------------------------------
      // NORMAL USER
      // Fetch ONLY this user's close sale
      // ----------------------------------------------------------
      else {
        final cleanStaff = staff
            .replaceAll(' ', '')
            .toLowerCase();

        final id = '$companyid-$cleanStaff-$ymd';

        final snap = await db
            .collection('closeSales')
            .doc(id)
            .get(
          const GetOptions(
            source: Source.serverAndCache,
          ),
        );

        final data = snap.data();

        if (snap.exists && data != null && data.isNotEmpty) {
          closesales = [
            {
              'id': snap.id,
              'companyid': data['companyid'] ?? '',
              'branchid': data['branchid'] ?? '',
              'createdAt': data['createdAt'],
              'ymd': data['ymd'] ?? '',
              'staff': data['staff'] ?? '',
              'staffPosition': data['staffPosition'] ?? '',
              'money': data['money'] ?? [],
              'total': data['total'] ?? 0,
            }
          ];
        } else {
          closesales = [];
        }
      }
    } catch (e) {
      debugPrint('Error fetching close sales: $e');
      closesales = [];
    } finally {
      isloadingclosesale = false;
      notifyListeners();
    }
  }


// ============================================================
// CLOSE SALES - EDIT / UPDATE
// ============================================================

  Future<void> editCloseSale({
    required String docId,
    required List<Map<String, dynamic>> money,
    required num total,
  }) async {
    try {
      final updateData = {
        'money': money,
        'total': total,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await db
          .collection('closeSales')
          .doc(docId)
          .update(updateData);

      debugPrint('Close sale updated: $docId');
    } catch (e) {
      debugPrint('Error updating close sale: $e');
      rethrow;
    }
  }


// ============================================================
// CLOSE SALES - DELETE
// ============================================================

  Future<void> deleteCloseSale(String docId) async {
    try {
      await db
          .collection('closeSales')
          .doc(docId)
          .delete();

      debugPrint('Close sale deleted: $docId');
    } catch (e) {
      debugPrint('Error deleting close sale: $e');
      rethrow;
    }
  }



  Future<void> fetchcreditoropenbal(DateTimeRange? range, String branch) async {
          try {
            isloadingcreditbal = true;
            notifyListeners();

            final now = DateTime.now();
            final startDate = range?.start ?? now;
            final endDate = range?.end ?? now;
            final start = DateTime(startDate.year, startDate.month, startDate.day);
            final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

            Query query = db
                .collection('creditor_balances')
                .where("companyid", isEqualTo: companyid)
                .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));

            if (branch.isNotEmpty) {
              query = query.where("branchid", isEqualTo: branch);  // ← only filter if branch selected
            }

            query = query.orderBy('date', descending: true);

            final snap = await query.get(const GetOptions(source: Source.serverAndCache));
            creditoropenbal = snap.docs.map((doc) => CreditorBalance.fromFirestore(doc)).toList();

          } catch (e) {
            debugPrint("Error fetching creditor info: $e");
          }

          isloadingcreditbal = false;
          notifyListeners();
        }
   List<CreditorBalance> filtercreditorBalance(String searchQuery ) {
          if (searchQuery.isEmpty) return creditoropenbal;
          final q = searchQuery.toLowerCase();
          return creditoropenbal.where((s) {
            final company = (s.company ?? '').toLowerCase();
            final staff = (s.staff ?? '').toLowerCase();
            final name = (s.creditorName ?? '').toLowerCase();
            final id = (s.creditorId ?? '').toLowerCase();
            final naration = (s.naration ?? '').toLowerCase();
            final payaccount = (s.paymentaccount ?? '').toLowerCase();
            final paymethod = (s.paymentMode ?? '').toLowerCase();
            final phone = (s.phone ?? '').toLowerCase();

            final amount = (s.amount ?? '').toString().toLowerCase();

            return company.contains(q) ||
                id.contains(q) ||
                staff.contains(q) ||
                name.contains(q) ||
                payaccount.contains(q) ||
                paymethod.contains(q) ||
                phone.contains(q) ||
                amount.contains(q) ||
                naration.contains(q);
          }).toList();
        }

        Future<void> deletecreditoropenbal(
            CreditorBalance? creditdata, String id) async {
          final amount = double.tryParse(creditdata?.amount.toString() ?? '0') ?? 0;
          final supplierId = creditdata?.creditorId;

          if (supplierId == null) return;

          try {
            final creditRef = db.collection('creditor_balances').doc(id);
            final creditDoc = await creditRef.get();

            if (!creditDoc.exists) return;

            final formattedDate =
            DateFormat('dd-MM-yyyy').format(DateTime.now());

            final batch = db.batch();

            // Store deleted document
            batch.set(
              db.collection('deletedcollection').doc(id),
              {
                ...creditDoc.data()!,
                'deleted_at': FieldValue.serverTimestamp(),
                'deleted_by': staff,
                'deleted_email': staffemail,
                'type': 'creditor_balances',
                'originalCollection': 'creditor_balances',
                'originalId': id,
                'datedmy': formattedDate,
              },
            );

            // Delete original document
            batch.delete(creditRef);

            // Update supplier balance
            batch.update(
              db.collection('suppliers').doc(supplierId),
              {
                'creditaccount': FieldValue.increment(-amount),
              },
            );

            // Commit all operations together
            await batch.commit();

            creditoropenbal.removeWhere((c) => c.id == id);
            notifyListeners();
          } catch (e) {
            print("Error deleting creditor open balance: $e");
          }
        }
        Future<void> fetchCreditorlist({String? branchID}) async {
          isLoadingcreditlist = true;
          notifyListeners();

          try {
            // Build query — filter by branch only when one is selected
            Query query = db.collection('suppliers')
                .where("companyid", isEqualTo: companyid);

            if (branchID != null && branchID.isNotEmpty) {
              query = query.where("branchid", isEqualTo: branchID);
            }

            final snap = await query.get(
              const GetOptions(source: Source.serverAndCache),
            );

            creditorList = snap.docs.map((doc) {
              final map = doc.data() as Map<String, dynamic>;

              // Fix: safely parse both int, double, or string to double
              final credit = _toDouble(map['creditaccount']);
              final debit  = _toDouble(map['debitaccount']);
              final balance = credit - debit;

              return {
                'creditorId': map['id'] ?? doc.id,
                'name': map['supplier'] ?? '',
                'credit': credit,
                'debit': debit,
                'balance': balance,
              };
            }).where((item) => (item['balance'] as double) > 0).toList();

          } catch (e) {
            debugPrint("Error fetching suppliers: $e");
          } finally {
            isLoadingcreditlist = false;
            notifyListeners();
          }
        }


        double _toDouble(dynamic value) {
          if (value == null) return 0.0;
          if (value is double) return value;
          if (value is int) return value.toDouble();
          if (value is String) return double.tryParse(value) ?? 0.0;
          return 0.0;
        }
  List<Map<String, dynamic>> filterCreditorlist() {
    if (searchQuery.isEmpty) return creditorList;

    final q = searchQuery.toLowerCase();

    return creditorList.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final id = (s['creditorId'] ?? '').toString().toLowerCase();
      final credit = (s['credit'] ?? 0).toString();
      final debit = (s['debit'] ?? 0).toString();
      final balance = (s['balance'] ?? 0).toString();

      return name.contains(q) ||
          id.contains(q) ||
          credit.contains(q) ||
          debit.contains(q) ||
          balance.contains(q);
    }).toList();
  }

        Future<void> fetchCreditorPaylist(DateTimeRange? daterange, String? selectedBranch) async {
          isLoadingcreditpaylist = true;
          notifyListeners();

          try {
            Query query = db.collection('creditor_payments')
                .where("companyid", isEqualTo: companyid);

            if (selectedBranch != null && selectedBranch.isNotEmpty) {
              query = query.where("branchid", isEqualTo: selectedBranch);
            }

            final snap = await query.get(
              const GetOptions(source: Source.serverAndCache),
            );

            creditorpayList = snap.docs.map((doc) => CreditorBalance.fromFirestore(doc)).toList();
          } catch (e) {
            debugPrint("Error fetching creditor payments: $e");
          } finally {
            isLoadingcreditpaylist = false;
            notifyListeners();
          }
        }
  List<CreditorBalance> filterCreditorPaylist(String searchQuery) {
          if (searchQuery.isEmpty) return creditorpayList;

          final q = searchQuery.toLowerCase();

          return creditorpayList.where((s) {
            final name = s.creditorName.toLowerCase();
            final id = s.creditorId.toLowerCase();
            final amount = s.amount.toString();
            final ref = (s.transactionRef).toLowerCase();
            final account = (s.paymentaccount ?? '').toLowerCase();
            final phone = (s.paymentMode).toLowerCase();
            final date = (s.date.toString()).toLowerCase();

            return name.contains(q) ||
                id.contains(q) ||
                amount.contains(q) ||
                ref.contains(q) ||
                account.contains(q) ||
                date.contains(q) ||
                phone.contains(q);
          }).toList();
        }

  // Future<void> deleteCreditorpay(CreditorBalance? credita, String id) async {
  //   final supplierid = credita?.creditorId;
  //   final amount = credita?.amount ?? 0.0;
  //
  //   if (supplierid == null || supplierid.isEmpty) {
  //     print("delete: missing supplierid, aborting.");
  //     return;
  //   }
  //
  //   // Atomic batch
  //   final batch = db.batch();
  //
  //   batch.delete(
  //     db.collection('creditor_payments').doc(id),
  //   );
  //
  //   batch.update(
  //     db.collection('suppliers').doc(supplierid),
  //     {
  //       'debitaccount': FieldValue.increment(-amount)
  //     },
  //   );
  //
  //   try {
  //     await batch.commit();
  //
  //     // Update local state
  //     creditorpayList.removeWhere((d) => d.id == id);
  //     notifyListeners();
  //   } catch (e) {
  //     print("Error deleting Creditor Payment info: $e");
  //   }
  // }
        Future<void> deleteCreditorpay(CreditorBalance? credita, String id) async {
          final supplierId = credita?.creditorId;
          final amount = credita?.amount ?? 0.0;

          if (supplierId == null || supplierId.isEmpty) {
            print("delete: missing supplierId, aborting.");
            return;
          }

          try {
            final paymentRef = db.collection('creditor_payments').doc(id);
            final paymentDoc = await paymentRef.get();

            if (!paymentDoc.exists) return;

            final formattedDate =
            DateFormat('dd-MM-yyyy').format(DateTime.now());

            final batch = db.batch();

            // Store deleted document
            batch.set(
              db.collection('deletedcollection').doc(id),
              {
                ...paymentDoc.data()!,
                'deleted_at': FieldValue.serverTimestamp(),
                'deleted_by': staff,
                'deleted_email': staffemail,
                'type': 'creditor_payments',
                'originalCollection': 'creditor_payments',
                'originalId': id,
                'datedmy': formattedDate,
              },
            );

            // Delete original document
            batch.delete(paymentRef);

            // Update supplier account
            batch.update(
              db.collection('suppliers').doc(supplierId),
              {
                'debitaccount': FieldValue.increment(-amount),
              },
            );

            // Commit all operations together
            await batch.commit();

            // Update local state
            creditorpayList.removeWhere((d) => d.id == id);
            notifyListeners();
          } catch (e) {
            print("Error deleting Creditor Payment info: $e");
          }
        }
  List<String> getAccounts(String method) {
    return linkedAccounts[method] ?? [];
  }

  Future<void> fetchPaymentMethods() async {
    isLoadingPaymentMethods = true;
    notifyListeners();

    try {
      final snapshot = await db.collection('paymentaccounts').get();

      Map<String, List<String>> temp = {};

      for (var doc in snapshot.docs) {
        final map = doc.data();

        final method = map['paymentMethod']?.toString().trim() ?? '';
        final accounts = (map['linkedAccounts'] as List?) ?.map((e) => e.toString()).toList() ?? [];

        if (method.isNotEmpty) {
          temp[method] = accounts;
        }
      }

      linkedAccounts = temp;

      // IMPORTANT: sync allowed methods
      allowedPaymentMethods = linkedAccounts.keys.toList();

     // debugPrint("linkedAccounts: $linkedAccounts");
     // debugPrint("allowedPaymentMethods: $allowedPaymentMethods");

    } catch (e) {
      debugPrint("Error fetching payment methods: $e");
    } finally {
      isLoadingPaymentMethods = false;
      notifyListeners();
    }
  }
  List<AccountTypeModel> accountList = [];

  bool isLoadingaccountList = false;
  Future<void> getAllAccounts() async {
          isLoadingaccountList = true;
          notifyListeners();

          try {
            Query query = db.collection('accounts');

            final snap = await query.get(
              const GetOptions(source: Source.serverAndCache),
            );

            accountList = snap.docs.map((doc) => AccountTypeModel.fromJson(
              doc.data() as Map<String, dynamic>,
            ))
                .toList();

          } catch (e) {
            debugPrint("Error fetching accounts: $e");
          } finally {
            isLoadingaccountList = false;
            notifyListeners();
          }
       }
        List<BankTransferModel> bankTransferList = [];
        bool isLoadingbtranlist = false;

        Future<void> fetchBankTransfers( DateTimeRange? dateRange, String? sbranch, ) async {
          isLoadingbtranlist = true;
          notifyListeners();

          try {
            Query query;


            if (sbranch != null && sbranch.isNotEmpty) {
              query = db
                  .collection('banktransfers')
                  .where("companyId", isEqualTo: companyid)
                  .where("branchId", isEqualTo: sbranch);
            } else {
                 query = db.collection('banktransfers')
                  .where("companyId", isEqualTo: companyid);
            }


            if (dateRange != null) {
              final start = DateTime(
                dateRange.start.year,
                dateRange.start.month,
                dateRange.start.day,
              );

              final end = DateTime(
                dateRange.end.year,
                dateRange.end.month,
                dateRange.end.day,
                23,
                59,
                59,
              );

              query = query.where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(start), )
               .where("date", isLessThanOrEqualTo: Timestamp.fromDate(end), );
            }


            query = query.orderBy("date", descending: true);

            final snap = await query.get();


            bankTransferList = snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return BankTransferModel.fromMap({
                ...data,
                "id": doc.id,
              });
            }).toList();
          } catch (e) {
            print("Error fetching bank transfers: $e");
            bankTransferList = [];
          } finally {
            isLoadingbtranlist = false;
            notifyListeners();
          }
        }
        List<BankTransferModel> filterBankTransfer() {
          if (searchQuery.isEmpty) {
            return List.from(bankTransferList);
          }

          final q = searchQuery.toLowerCase();

          return bankTransferList.where((s) {
            final receiveAccount =
            (s.receivingAccount ?? '').toLowerCase();

            final transferAccount =
            (s.transferAccount ?? '').toLowerCase();

            final id = s.id.toLowerCase();

            final amount =  s.amount.toString().toLowerCase();

            final narration = (s.narration ?? '').toLowerCase();

            final staff =   (s.staff ?? '').toLowerCase();

            final company = (s.companyId).toLowerCase();

            return receiveAccount.contains(q) ||
                transferAccount.contains(q) ||
                id.contains(q) ||
                amount.contains(q) ||
                narration.contains(q) ||
                staff.contains(q) ||
                company.contains(q);
          }).toList();
        }

  Future<void> deleteBankTransfer(String id,BankTransferModel? d ) async {
    final bankRef = db.collection('banktransfers').doc(id);
    final bankDoc = await bankRef.get();
    final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final formattedDateTime =
    DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
    if (bankDoc.exists) {
      await db.collection('deletedcollection').doc(id).set({
        ...bankDoc.data() as Map<String, dynamic>,
        'deleted_at':    FieldValue.serverTimestamp(),
        'deleted_by':    staff,
        'deleted_email': staffemail,
        'type': 'banktransfers',
        'originalCollection': 'banktransfers',
        'originalId': id,
        'datedmy': formattedDate,
      });
    }

    await bankRef.delete();
    bankTransferList.removeWhere((c) => c.id == id);
    notifyListeners();

  }


  List<DiscountCodeModel> discountCodes = [];

   Future<void> fetchDiscountCodes() async {
    try {
      final snap = await db.collection('discountcodes')
          .where('companyId', isEqualTo: companyid )
          .orderBy('createdAt', descending: true)
          .get();

      discountCodes = snap.docs.map((d) => DiscountCodeModel.fromSnapshot(d)).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('fetchDiscountCodes error: $e');
    }
  }

//Save new code
  Future<bool> saveDiscountCode(DiscountCodeModel dc) async {
    try {
      final ref = db.collection('discountcodes').doc(dc.id);
      await ref.set(dc.toMap());

      discountCodes.insert(0, dc);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('saveDiscountCode error: $e');
      return false;
    }
  }


  Future<bool> editDiscountCode(DiscountCodeModel dc) async {
    if (dc.isUsed) return false;
    try {
      await db .collection('discountcodes')
          .doc(dc.id)
          .update({
        'amount':    dc.amount,
        'isActive':  dc.isActive,
        'expiresAt': dc.expiresAt,
      });
      final idx = discountCodes.indexWhere((c) => c.id == dc.id);
      if (idx != -1) discountCodes[idx] = dc;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('editDiscountCode error: $e');
      return false;
    }
  }

  Future<bool> deleteDiscountCode(String id) async {
    final index = discountCodes.indexWhere((c) => c.id == id);
    // Not found
    if (index == -1) return false;

    final dc = discountCodes[index];

    // Already used
    if (dc.isUsed) return false;

    try {
      await db.collection('discountcodes').doc(id).delete();

      discountCodes.removeAt(index);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('deleteDiscountCode error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> validateDiscountCode(String code) async {
    final upper = code.trim().toUpperCase();

    try {
      final doc = await db.collection('discountcodes').doc(upper).get();

      if(doc.exists){
        final data = doc.data();
     final isActive =   data?['isActive'] == true ;
     final isUsed =   data?['isUsed'] == false ;

     if(isActive && isUsed){
       return {
         'code': doc.id,
         'amount': data?['amount'] ?? 0,
       };
     }
      }
    } catch (e) {
      print('Error validating discount code: $e');
      return null;
    }
  }


  Future<void> markDiscountCodeUsed( String code, { String usedBy = '',  String usedBranch = '',}) async {
    final upper = code.trim().toUpperCase();

    final index = discountCodes.indexWhere( (c) => c.code.toUpperCase() == upper,);

    // Not found
    if (index == -1) return;

    final dc = discountCodes[index];

    //prevent re-use
    if (dc.isUsed) {
      print('Attempted to use already used code: $code');
       return;
    }

    final now = Timestamp.now();

    try {
      await db.collection('discountcodes').doc(upper).update({
        'isUsed': true,
        'isActive': false,
        'usedBy': usedBy,
        'usedBranch': usedBranch,
        'usedAt': now,
      });

      // Update loc
      dc.isUsed = true;
      dc.isActive = false;
      dc.usedBy = usedBy;
      dc.usedBranch = usedBranch;
      dc.usedAt = now;

      notifyListeners();
    } catch (e) {
      debugPrint('markDiscountCodeUsed error: $e');
    }
  }



//Duplicate check
  bool discountCodeExists(String code) => discountCodes.any(
        (c) => c.code.toUpperCase() == code.trim().toUpperCase(),);

  bool  hamperEnabled = false;

  void initHamperListener() {
    try {
      db
          .collection('settings')
          .doc('hamper_config')
          .snapshots()
          .listen((doc) {
        try {
          hamperEnabled = (doc.data()?['isEnabled'] ?? false) as bool;
          notifyListeners();
        } catch (e) {
          print("Error parsing hamper config: $e");
        }
      }, onError: (error) {
        print("Firestore listener error: $error");
      });
    } catch (e) {
      print("Error initializing hamper listener: $e");
    }
  }

  void toggleHamper(bool val) {
    try {
         db .collection('settings')
          .doc('hamper_config')
          .set({'isEnabled': val}, SetOptions(merge: true));
    }
    catch (e) {
      print("Error updating hamper config: $e");
    }
  }
  void setBranch(String id, String name, String address, String phone) {
    branchid = id;
    branch = name;
    branchaddress = address;
    branchphone = phone;
    notifyListeners();
  }


  List<Map<String, dynamic>> stockDailyData({ required List<ItemModel> items,  String? selectedBranch,  DateTime? from,   DateTime? to,  }) {
    final Map<String, Map<String, dynamic>> grouped = {};


    bool isWithinRange(DateTime date) {
      if (from == null || to == null) {
        return true;
      }

      final DateTime today = DateTime.now();

      final DateTime fromDate = DateTime(
        (from ?? today).year,
        (from ?? today).month,
        (from ?? today).day,
      );

      final DateTime toDate = DateTime(
        (to ?? from ?? today).year,
        (to ?? from ?? today).month,
        (to ?? from ?? today).day,
      );

      final DateTime checkDate = DateTime(
        date.year,
        date.month,
        date.day,
      );

      return !checkDate.isBefore(fromDate) &&
          !checkDate.isAfter(toDate);
    }

    for (final item in items) {
      final itemId = item.id ?? '';
      final itemName = item.name ?? '';
      final barcode = item.barcode ?? '';

      double openingStock = 0;
      double newStock = 0;
      double totalStock = 0;

      double cashSales = 0;
      double salesQty = 0;
      double creditSales = 0;

      double purchaseReturns = 0;
      double damages = 0;
      double transfer = 0;
      double saleReturns = 0;

      double stockOut = 0;
      double balance = 0;

      bool hasDailyData = false;


      final itemDaily =
          item.dailytransactions
          as Map<String, dynamic>? ??
              {};

    // daily
      itemDaily.forEach((dateKey, dayData) {
        final date = DateTime.tryParse(dateKey);

        if (date == null) return;

        /// RANGE FILTER
        if (!isWithinRange(date)) return;

        final branchBalances =
            dayData['branchbalance']
            as Map<String, dynamic>? ??
                {};

        if (branchBalances.isNotEmpty) {
          hasDailyData = true;
        }

        branchBalances.forEach((branchId, branchData) {
          /// BRANCH FILTER
          if (selectedBranch != null &&
              selectedBranch != 'All' &&
              branchId != selectedBranch) {
            return;
          }

          /// SALES
          final salesQty =
          (branchData['sales_qty'] ?? 0)
              .toDouble();

          /// BALANCE
          final availableBalance =
          (branchData['available_balance'] ?? 0)
              .toDouble();

          /// OPENING STOCK
          openingStock +=
              availableBalance + salesQty;

          /// NEW STOCK
          newStock +=
              (branchData['newstock'] ?? 0)
                  .toDouble();
          /// CASH SALES
          cashSales += salesQty;
          /// CASH SALES

          creditSales +=
              (branchData['credit_sales_qty'] ?? 0)
                  .toDouble();

          /// CREDIT SALES
          creditSales +=
              (branchData['credit_sales_qty'] ?? 0)
                  .toDouble();

          /// PURCHASE RETURNS
          purchaseReturns +=
              (branchData['purchaseReturn_qty'] ?? 0)
                  .toDouble();

          /// DAMAGES
          damages +=
              (branchData['damage_qty'] ?? 0)
                  .toDouble();

          /// TRANSFER
          transfer +=
              (branchData['transfer_qty'] ?? 0)
                  .toDouble();

          /// SALES RETURNS
          saleReturns +=
              (branchData['salesReturn_qty'] ?? 0)
                  .toDouble();
        });
      });


      if (!hasDailyData) {
        final fallback =
            item.branchbalance
            as Map<String, dynamic>? ??
                {};

        fallback.forEach((branchId, branchData) {
          if (selectedBranch != null &&
              selectedBranch != 'All' &&
              branchId != selectedBranch) {
            return;
          }

          openingStock +=
              (branchData['quantity'] ?? 0)
                  .toDouble();

          newStock +=
              (branchData['stockin_pieces'] ?? 0)
                  .toDouble();

          cashSales +=
              (branchData['stockout_qty'] ?? 0)
                  .toDouble();

          creditSales += 0;

          damages +=
              (branchData['damage_qty'] ?? 0)
                  .toDouble();

          purchaseReturns +=
              (branchData['purchaseReturn_qty'] ?? 0)
                  .toDouble();

          transfer +=
              (branchData['transfer_qty'] ?? 0)
                  .toDouble();

          saleReturns +=
              (branchData['salesReturn_qty'] ?? 0)
                  .toDouble();
        });
      }

      /// TOTAL STOCK
      totalStock =
          openingStock +
              newStock +
              saleReturns;

      /// STOCK OUT
      stockOut =
          cashSales +
              creditSales +
              damages +
              transfer +
              purchaseReturns;

      /// BALANCE
      balance =
          totalStock - stockOut;


      grouped[itemId] = {
        'itemid': itemId,
        'item': itemName,
        'barcode': barcode,

        'opening_stock': openingStock,
        'newstock': newStock,
        'total_stock': totalStock,

        'cash_sales': cashSales,
        'credit_sales': creditSales,

        'purchase_returns': purchaseReturns,
        'damages': damages,
        'transfer': transfer,
        'sale_returns': saleReturns,

        'stock_out': stockOut,
        'balance_cd': balance,
      };
    }

    return grouped.values.toList();
  }




  List<Map<String, dynamic>> FetchBranchBalances({ String? branchId, String? search }) {

    if (stockreport.isEmpty) return [];

    var result = stockreport.where((r) {
      if (branchId == null || branchId.isEmpty) return true; // all items pass
      final rBranch = (r['branchId'] ?? r['branchkey'] ?? '').toString().toLowerCase();
      return rBranch == branchId.toLowerCase();
    }).map((r) {
      final balance       = _toDouble(r['balance_cd']);
      final boxpieces     = _toDouble(r['cartonqty_bal']);
      final cartonBalance = boxpieces > 0 ? balance / boxpieces : 0.0;

      return {
        'item'          : r['item']     ?? '',
        'itemcp'          : r['itemcp']     ?? '',
        'itemsp'          : r['itemsp']     ?? '',
        'itemid'        : r['itemid']   ?? '',
        'branch'        : r['branch']   ?? '',
        'branchkey'     : r['branchId'] ?? '',
        'balance'       : balance,
        'carton_qty'    : boxpieces,
        'carton_balance': cartonBalance,
      };

    }).toList();

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result.where((r) =>
      r['item'].toString().toLowerCase().contains(q)   ||
          r['branch'].toString().toLowerCase().contains(q) ||
          r['itemid'].toString().toLowerCase().contains(q),
      ).toList();
    }

    return result;
  }

  Future<void> expireOutdatedCodes() async {
    final now = Timestamp.now();
    final batch = db.batch();
    bool hasChanges = false;

    for (final code in discountCodes) {
      if (code.isActive && !code.isUsed && code.expiresAt != null) {
        if (code.expiresAt!.compareTo(now) < 0) {
          final ref = db
              .collection('discountCodes')
              .doc(code.id);
          batch.update(ref, {'isActive': false});
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      await batch.commit();
      await fetchDiscountCodes();
    }
  }
  List<ItemHistoryEntry> itemHistoryEntries = [];
  bool itemHistoryLoading = false;

  List<dynamic> _asItemsList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.values.toList();
    return [];
  }

  double _toD(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  Future<void> loadItemHistory({  required String itemId,  required String itemName, required String? branchId, required DateTime startDate,required DateTime endDate,}) async {
    itemHistoryLoading = true;
    itemHistoryEntries = [];
    notifyListeners();

    final start = _toDateOnly(startDate);
    final end   = _toDateOnly(endDate);

    final isBranch = branchId != null && branchId.trim().isNotEmpty &&
        branchId.trim().toLowerCase() != 'all';

    final branch = isBranch ? branchId!.trim() : null;
    final id = itemId.trim();

    // Base query builder
    Query<Map<String, dynamic>> _q(String col, String dateField, String companyField, String? branchField,) {
      var q = db.collection(col)
          .where(companyField, isEqualTo: companyid)
          .where(dateField, isGreaterThanOrEqualTo: start)
          .where(dateField, isLessThanOrEqualTo: end);
      if (branch != null && branchField != null) {
        q = q.where(branchField, isEqualTo: branch);
      }
      return q;
    }

    try {
      final results = await Future.wait([
        _q('sales','dateymd','companyId','branchId').get(),
        _q('stock_transactions','date','companyid','branchid').get(),
        _q('stock_transfer','date','companyid','staffbranchid').get(),
        _q('damageitems', 'dateymd','companyid','branchid').get(),
        _q('purchase_returns', 'date','companyid','branchid').get(),
        _q('salesreturn', 'dateymd','companyid','branchid').get(),
      ]);

      final entries = <ItemHistoryEntry>[];


      // SALES
      for (final doc in results[0].docs) {
        final d = doc.data();
        final items = d['items'] as Map<String, dynamic>? ?? {};

        for (final v in items.values) {
          if (v is! Map) continue;
          final m = Map<String, dynamic>.from(v);

          final currentItemId = (m['itemid'] ?? m['itemId'] ?? m['id'] ?? '').toString().trim();
          final currentBarcode = (m['barcode'] ?? '').toString().trim();

          if (currentItemId != id.trim() && currentBarcode != id.trim()) {
            continue;
          }

          // Branch check for sales (handled in-memory if query filter was broad, 
          // or just verifying if the doc filter matched).
          if (branch != null) {
            final docBranchId = d['branchId']?.toString().trim();
            final itemBranchId = m['branchid']?.toString().trim();
            if (docBranchId != branch && itemBranchId != branch) {
               // continue; 
               // Note: We might want to be inclusive for Sales Point staff here too.
            }
          }

          // returned  sales
          final isReturned =  (m['status'] ?? '').toString().toLowerCase() =='returned';

          //SALES RETURN

          if (isReturned) {
            entries.add(
              ItemHistoryEntry(
                date: (d['createdAt'] as Timestamp?)?.toDate(),
                invoiceDate: d['dateymd'] ?? '',
                type: 'Sales Return',

                sign: '+',
                item:  m['returned_item']?.toString() ??  m['item']?.toString() ??  itemName,
               /*
                qty: double.tryParse(m['returned_totalpieces']?.toString() ??
                      m['returned_quantity']?.toString() ??'0', ) ??  0,

                price: double.tryParse(
                  m['returned_price']?.toString() ??  m['price']?.toString() ?? '0', ) ??   0,

                total: double.tryParse(m['returned_totalamount']?.toString() ?? '0',) ?? 0,
                  */
                qty: _toD(m['returned_totalpieces'] ?? m['returned_quantity']),
                price: _toD(m['returned_price'] ?? m['price']),
                total: _toD(m['returned_totalamount']),
                mode:  m['returned_mode']?.toString() ??  m['mode']?.toString() ??  '',

                branch: m['returned_branchname']?.toString() ?? d['branchName']?.toString() ?? '',

                staff: d['createdBy']?.toString() ?? '',

                transactionid:  m['returned_receiptid']?.toString() ??
                    d['receiptNumber']?.toString() ??
                    d['id']?.toString() ??'',
              ),
            );


            continue;
          }


          // SALE

          entries.add(
            ItemHistoryEntry(
              date: (d['createdAt'] as Timestamp?)?.toDate(),
              type: 'Sale',
              invoiceDate: (d['dateymd'] )?? '',
              sign: '-',

              item: m['item']?.toString() ?? itemName,

              qty: _toD(m['totalpieces'] ?? m['quantity']),

              price: _toD(m['price']),

              total: _toD(m['totalamount']),

              mode: m['mode']?.toString() ?? '',

              branch:
                    m['branchname']?.toString() ??
                    d['branchName']?.toString() ?? '',

              staff: d['createdBy']?.toString() ?? '',

              transactionid:  d['receiptNumber']?.toString() ??
                    d['id']?.toString() ??  '',
            ),
          );
        }
      }



      // STOCK TRANSACTIONS / PURCHASES
      for (final doc in results[1].docs) {

        final d = doc.data();
        final invoiceDate = d['date'] ?? '';

       // final waybill =d['waybill'].toString().trim();
        //final effectiveDate =   (d['createdat'] as Timestamp?)?.toDate() ?? invoiceDate;
      //  final items = d['items'] as List<dynamic>? ?? [];
        final items = _asItemsList(d['items']);

        for (final v in items) {
          if (v is! Map) continue;

          final m = Map<String, dynamic>.from(v);

          final currentItemId = (m['itemid'] ?? m['itemId'] ?? m['id'] ?? '').toString().trim();
          final currentBarcode = (m['barcode'] ?? '').toString().trim();

          if (currentItemId != id.trim() && currentBarcode != id.trim()) {
            continue;
          }


          entries.add(
            ItemHistoryEntry(
              date: (d['createdat'] as Timestamp?)?.toDate(),
              invoiceDate: invoiceDate,

              type: (d['purchasetype'] ?? 'New stock') .toString(),


              sign: '+',

              item: m['item']?.toString() ?? itemName,

              qty: _toD(m['pieces'] ?? m['quantity']),

              price: _toD(m['price']),

              total: _toD(m['total']),

              mode: m['stockingmode']?.toString() ?? '',

              branch: d['branchname']?.toString() ?? '',

              staff:  d['createdby']?.toString() ?? '',

              transactionid:    d['waybill']?.toString() ??
                      d['docid']?.toString() ??  '',
              waybill: d['waybill']?.toString() ?? '',
            ),
          );

          // PURCHASE RETURN

          final returnPieces = (m['returnpieces'] as num?)?.toDouble() ??
                  double.tryParse( m['returnpieces']?.toString() ?? '0',) ?? 0;

          if (returnPieces > 0) {
            entries.add(
              ItemHistoryEntry(
                date:    (m['returndate'] as Timestamp?)?.toDate() ??
                        (d['createdat'] as Timestamp?)?.toDate(),
                invoiceDate: d['date']?? '',
                type: 'Purchase Return',


                sign: '-',

                item:  m['item']?.toString() ?? itemName,

               // qty: _toD(returnPieces),

               // price:  (m['price'] as num?)?.toDouble() ??  double.tryParse( m['price']?.toString() ?? '0',) ?? 0,

              //  total:  (m['returnvalue'] as num?)?.toDouble() ??   double.tryParse( m['returnvalue']?.toString() ?? '0', ) ?? 0,
                  qty: returnPieces,
                  price: _toD(m['price']),
                  total: _toD(m['returnvalue']),
                mode:   m['stockingmode']?.toString() ?? '',

                branch: d['branchname']?.toString() ?? '',

                staff:  d['createdby']?.toString() ?? '',

                transactionid:    m['waybill']?.toString() ??
                        d['docid']?.toString() ?? '',
              ),
            );
          }
        }
      }

      // STOCK TRANSFERS
      for (final doc in results[2].docs) {
        final d = doc.data();
        final transferdate = d['date'] ?? '';

       // final items = d['items'] as List<dynamic>? ?? [];
        final items = _asItemsList(d['items']);
        for (final v in items) {
          if (v is! Map) continue;

          final m = Map<String, dynamic>.from(v);

          final currentItemId = (m['itemid'] ?? m['itemId'] ?? m['id'] ?? '').toString().trim();
          final currentBarcode = (m['barcode'] ?? '').toString().trim();

          if (currentItemId != id.trim() && currentBarcode != id.trim()) {
            continue;
          }


          entries.add(
            ItemHistoryEntry(
              date: (d['createdat'] as Timestamp?)?.toDate(),
              invoiceDate: transferdate,
              type: 'Transfer to ${d['recievebranchname'] ?? ''}',

              sign: '-',

              item:  m['item']?.toString() ??  itemName,

             // qty:  double.tryParse( m['pieces']?.toString() ?? m['quantity']?.toString() ??'0', ) ?? 0,

             // price: double.tryParse( m['price']?.toString() ?? '0', ) ?? 0,

             // total: double.tryParse(  m['total']?.toString() ??'0', ) ?? 0,
              qty: _toD(m['pieces'] ?? m['quantity']),
              price: _toD(m['price']),
              total: _toD(m['total']),
              mode: m['transfermode'] ?.toString() ?? '',

              branch:  d['supplywarehousename'] ?.toString() ??  d['staffbranch'] ?.toString() ??'',

              staff:  d['createdby'] ?.toString() ?? '',

              transactionid:  d['transferid'] ?.toString() ??  d['docid'] ?.toString() ??  '',
            ),
          );
        }
      }

      // DAMAGES
      for (final doc in results[3].docs) {
        final d = doc.data();

        final itemMap =  d['item'] as Map<String, dynamic>? ?? {};

        for (final entry in itemMap.entries) {
          final v = entry.value;

          if (v is! Map) continue;

          final m = Map<String, dynamic>.from(v);

          final currentItemId = (m['itemid'] ?? m['itemId'] ?? m['id'] ?? '').toString().trim();
          final currentBarcode = (m['barcode'] ?? '').toString().trim();

          if (currentItemId != id.trim() && currentBarcode != id.trim()) {
            continue;
          }

          entries.add(
            ItemHistoryEntry(
              date: (d['createdat'] as Timestamp?)?.toDate(),
              invoiceDate: d['dateymd']  ?? '',
              type: 'Damage',

              sign: '-',

              item: m['item']?.toString() ??  itemName,

             // qty:  double.tryParse( m['totalpieces'] ?.toString() ??  m['quantity'] ?.toString() ?? '0', ) ?? 0,

             // price: double.tryParse(m['cp']?.toString() ?? '0', ) ?? 0,

             // total: double.tryParse(m['grandtotal'] ?.toString() ?? '0',) ??  0,
              qty: _toD(m['totalpieces'] ?? m['quantity']),
              price: _toD(m['cp']),
              total: _toD(m['grandtotal']),
              mode:  m['mode']?.toString() ?? '',
              branch:m['branchname'] ?.toString() ??  d['branchname']  ?.toString() ?? '',

              staff: d['createdby'] ?.toString() ??   '',

              transactionid:   d['trxid'] ?? d['id'] ?.toString(),
            ),
          );
        }
      }
      //purchase return
      for (final doc in results[4].docs) {
        final d = doc.data();

        final items =_asItemsList(d['items']);
        for (final v in items) {
          if (v is! Map) continue;

          final m = Map<String, dynamic>.from(v);

          final currentItemId = (m['itemid'] ?? m['itemId'] ?? m['id'] ?? '').toString().trim();
          final currentBarcode = (m['barcode'] ?? '').toString().trim();

          if (currentItemId != id.trim() && currentBarcode != id.trim()) {
            continue;
          }

          entries.add(
            ItemHistoryEntry(
              date: (m['returndate'] as Timestamp?)?.toDate() ??
                  (d['submittedat'] as Timestamp?)?.toDate(),

              type: 'Purchase Return',
              invoiceDate: d['date']  ?? '',
              sign: '-',

              item: m['item']?.toString() ?? itemName,

              qty: double.tryParse(
                m['returnpieces']?.toString() ??
                    m['returnquantity']?.toString() ?? '0',
              ) ?? 0,

              price: double.tryParse(m['price']?.toString() ?? '0') ?? 0,

              total: double.tryParse(
                m['returnvalue']?.toString() ??
                    m['net_returnvalue']?.toString() ?? '0',
              ) ?? 0,

              mode: m['stockingmode']?.toString() ?? '',

              branch: d['branchname']?.toString() ?? '',

              staff: d['createdby']?.toString() ?? '',

              transactionid: m['waybill']?.toString() ??
                  d['returnid']?.toString() ?? '',
            ),
          );
        }
      }
      //sales return

      for (final doc in results[5].docs) {
        final d = doc.data();
        final returnedItems = d['returned_items'] as Map<String, dynamic>? ?? {};

        for (final v in returnedItems.values) {
          if (v is! Map) continue;
          final m = Map<String, dynamic>.from(v);
          final currentItemId = (m['returned_itemid'] ?? '').toString().trim();
          final currentBarcode = (m['returned_barcode'] ?? m['barcode'] ?? '').toString().trim();
          if (currentItemId != id.trim() && currentBarcode != id.trim()) continue;

          entries.add(
            ItemHistoryEntry(
              date: (d['returned_createdat'] as Timestamp?)?.toDate(),
              invoiceDate: d['dateymd'] ?? '',
              type: 'Sales Return',
              sign: '+',
              item: m['returned_item']?.toString() ?? itemName,
              qty: double.tryParse(m['returned_totalpieces']?.toString() ?? m['returned_quantity']?.toString() ?? '0') ?? 0,
              price: double.tryParse(m['returned_price']?.toString() ?? '0') ?? 0,
              total: double.tryParse(m['returned_totalamount']?.toString() ?? '0') ?? 0,
              mode: m['returned_mode']?.toString() ?? '',
              branch: m['returned_branchname']?.toString() ?? d['branchName']?.toString() ?? '',
              staff: d['returned_createdby']?.toString() ?? '',
              transactionid: m['returned_receiptid']?.toString() ??
                  d['receiptNumber']?.toString() ??
                  d['id']?.toString() ??
                  '',
            ),
          );
        }
      }
      // Newest first
      entries.sort((a, b) {
        final ta = a.date?.millisecondsSinceEpoch ?? 0;
        final tb = b.date?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      itemHistoryEntries = entries;
    }
    catch (e) {
      print('loadItemHistory error: $e');
      itemHistoryEntries = [];
    }

    itemHistoryLoading = false;
    notifyListeners();
  }

  List<Map<String, dynamic>> ledgerreport = [];
  bool isloadingledgerreport = false;



  Future<void> fetchgeneralledgerreport({DateTimeRange? selectedDate, String? selectedBranch,}) async {
    try {
      print(selectedDate);
      isloadingledgerreport = true;
      notifyListeners();

      ledgerreport.clear();

      final now = DateTime.now();

      //today
      final start = selectedDate?.start ?? DateTime(now.year, now.month, now.day);
      final end   = selectedDate?.end   ?? DateTime(now.year, now.month, now.day);

      String fmtDate(DateTime d) =>
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      final startStr = fmtDate(start);
      final endStr   = fmtDate(end);

      // Opening balance
      final dayBeforeStart = start.subtract(const Duration(days: 1));
      final dayBeforeStartStr = fmtDate(dayBeforeStart);

      final bool allBranches =
          selectedBranch == null || selectedBranch.trim().isEmpty;

      Query<Map<String, dynamic>> openingQuery = db
          .collection('ledgers')
          .where('companyId', isEqualTo: companyid)
          .where('date', isLessThanOrEqualTo: dayBeforeStartStr);

      if (!allBranches) {
        openingQuery =
            openingQuery.where('branchId', isEqualTo: selectedBranch!.trim());
      }

      Query<Map<String, dynamic>> periodQuery = db
          .collection('ledgers')
          .where('companyId', isEqualTo: companyid)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr);

      if (!allBranches) {
        periodQuery =
            periodQuery.where('branchId', isEqualTo: selectedBranch!.trim());
      }

      final openingSnapshot = await openingQuery.get();
      final periodSnapshot  = await periodQuery.get();

      final Map<String, Map<String, dynamic>> grouped = {};

      void ensureGroup(String key, String account, String branchId, String branchName) {
        grouped.putIfAbsent(key, () => {
          'account':       account,
          'branchId':      allBranches ? '' : branchId,
          'branchName':    allBranches ? 'ALL BRANCHES' : branchName,
          'openingDebit':  0.0,
          'openingCredit': 0.0,
          'debit':         0.0,
          'credit':        0.0,
        });
      }

      String makeKey(String account, String branchId) =>
          allBranches ? account : '${account}_$branchId';

      //Accumulate opening balances
      for (final doc in openingSnapshot.docs) {
        final data       = doc.data();
        final account = (data['account'] ?? '').toString().trim().toLowerCase();
        final branchId   = (data['branchId']   ?? '').toString().trim();
        final branchName = (data['branchName'] ?? '').toString();
        final amount     = (data['amount']     ?? 0).toDouble();
        final type       = (data['type']       ?? '').toString().toLowerCase().trim();

        final key = makeKey(account, branchId);
        ensureGroup(key, account, branchId, branchName);

        if (type == 'debit') {
          grouped[key]!['openingDebit'] = (grouped[key]!['openingDebit'] as double) + amount;
        }
        else if (type == 'credit') {
          grouped[key]!['openingCredit'] =
              (grouped[key]!['openingCredit'] as double) + amount;
        }
      }

     for (final doc in periodSnapshot.docs) {
        final data       = doc.data();
        final account = (data['account'] ?? '').toString().trim().toLowerCase();
        final branchId   = (data['branchId']   ?? '').toString().trim();
        final branchName = (data['branchName'] ?? '').toString();
        final amount     = (data['amount']     ?? 0).toDouble();
        final type       = (data['type']       ?? '').toString().toLowerCase().trim();

        final key = makeKey(account, branchId);
        ensureGroup(key, account, branchId, branchName);

        if (type == 'debit') {
          grouped[key]!['debit'] =     (grouped[key]!['debit'] as double) + amount;
        }
        else if (type == 'credit') {
          grouped[key]!['credit'] =   (grouped[key]!['credit'] as double) + amount;
        }
      }

     int count = 1;

      ledgerreport = grouped.values.map((g) {
        final openingDebit  = g['openingDebit']  as double;
        final openingCredit = g['openingCredit'] as double;
        final debit         = g['debit']         as double;
        final credit        = g['credit']        as double;

        // Opening balance = total debit - total credit
        final openingBalance = openingDebit - openingCredit;

        // Closing = period debit - period credit
        final balance =  debit - credit;

        return {
          'number':  count++,
          'account':  g['account'],
          'branchName': g['branchName'],
          'branchId': g['branchId'],
          'openingBalance': openingBalance,
          'debit':  debit,
          'credit': credit,
          'balance': balance,
        };
      }).toList();

      //Sort by account
      ledgerreport.sort((a, b) {
        final cmp = a['account'].toString().compareTo(b['account'].toString());
        if (cmp != 0) return cmp;
        return a['branchName'].toString().toLowerCase()
            .compareTo(b['branchName'].toString().toLowerCase());
      });

    } catch (e, st) {
      debugPrint("Error fetching General Ledger Report: $e\n$st");
      ledgerreport = [];
    } finally {
      isloadingledgerreport = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfitAndLossReport({DateTimeRange? selectedDate, String? selectedBranch}) async {
    try {
      isLoadingProfitAndLoss = true;
      notifyListeners();

      profitAndLossRows = [];
      profitAndLossSummary = {};

      final now = DateTime.now();
      final start = selectedDate?.start ?? DateTime(now.year, now.month, now.day);
      final end = selectedDate?.end ?? DateTime(now.year, now.month, now.day);

      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final startStr = fmt(start);
      final endStr = fmt(end);

      final branchKey = (selectedBranch?.trim().isNotEmpty ?? false)
          ? selectedBranch!.trim()
          : (accesslevel.toLowerCase() != 'super admin' && branchid.isNotEmpty ? branchid : null);

      Query<Map<String, dynamic>> query = db
          .collection('ledgers')
          .where('companyId', isEqualTo: companyid)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr);

      if (branchKey != null && branchKey.isNotEmpty) {
        query = query.where('branchId', isEqualTo: branchKey);
      }

      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));

      final Map<String, double> income = {};
      final Map<String, double> costOfGoodsSold = {};
      final Map<String, double> operatingExpenses = {};
      final Map<String, double> otherActivity = {};

      double _n(dynamic value) => double.tryParse(value.toString()) ?? 0.0;

      String _accountName(Map<String, dynamic> data) =>
          (data['account'] ?? data['name'] ?? '').toString().trim();

      String _type(Map<String, dynamic> data) =>
          (data['accountType'] ?? data['type'] ?? '').toString().toLowerCase().trim();

      bool _looksIncome(String account, String accountType) {
        final key = '$account $accountType'.toLowerCase();
        return key.contains('sales') ||
            key.contains('income') ||
            key.contains('revenue') ||
            key.contains('receivable');
      }

      bool _looksCogs(String account, String accountType) {
        final key = '$account $accountType'.toLowerCase();
        return key.contains('cost of goods') ||
            key.contains('cogs') ||
            key.contains('inventory') ||
            key.contains('stock') ||
            key.contains('purchase return');
      }

      bool _looksExpense(String account, String accountType) {
        final key = '$account $accountType'.toLowerCase();
        return key.contains('expense') ||
            key.contains('salary') ||
            key.contains('rent') ||
            key.contains('transport') ||
            key.contains('damage') ||
            key.contains('discount');
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = _accountName(data);
        final accountType = _type(data);
        final amount = _n(data['amount']);
        final entryType = (data['type'] ?? '').toString().toLowerCase().trim();

        if (amount <= 0) continue;

        final Map<String, double> bucket = _looksIncome(name, accountType)
            ? income
            : _looksCogs(name, accountType)
                ? costOfGoodsSold
                : _looksExpense(name, accountType)
                    ? operatingExpenses
                    : otherActivity;

        if (entryType == 'credit') {
          bucket[name] = (bucket[name] ?? 0.0) + amount;
        } else if (entryType == 'debit') {
          bucket[name] = (bucket[name] ?? 0.0) + amount;
        }

        profitAndLossRows.add({
          'account': name,
          'accountType': accountType,
          'amount': amount,
          'type': entryType,
          'branchId': data['branchId'] ?? '',
          'branchName': data['branchName'] ?? '',
          'date': data['date'] ?? '',
          'description': data['description'] ?? '',
        });
      }

      final salesRevenue = income.values.fold<double>(0.0, (sum, value) => sum + value);
      final costOfGoods = costOfGoodsSold.values.fold<double>(0.0, (sum, value) => sum + value);
      final operating = operatingExpenses.values.fold<double>(0.0, (sum, value) => sum + value);
      final other = otherActivity.values.fold<double>(0.0, (sum, value) => sum + value);

      profitAndLossSummary = {
        'salesRevenue': salesRevenue,
        'costOfGoodsSold': costOfGoods,
        'grossProfit': salesRevenue - costOfGoods,
        'operatingExpenses': operating,
        'otherActivity': other,
        'netProfit': (salesRevenue - costOfGoods) - operating + other,
      };
    } catch (e, st) {
      debugPrint('Error fetching Profit & Loss report: $e\n$st');
      profitAndLossRows = [];
      profitAndLossSummary = {};
    } finally {
      isLoadingProfitAndLoss = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> filtergeneralledgerreport() {
    if (searchQuery.isEmpty) return ledgerreport;
    final q = searchQuery.toLowerCase();
    return ledgerreport.where((row) {
      return row['account'].toString().toLowerCase().contains(q) ||
          row['number'].toString().contains(q);
    }).toList();
  }



  Future<void> showLedgerDetailsDialog({ required DateTime startDate, required DateTime endDate, required String Id, required String Name, required String? branchId,}) async {

    final List<Map<String, dynamic>> transactions = <Map<String, dynamic>>[];

    String formatDate(DateTime d) {
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }

    final startStr = formatDate(startDate);
    final endStr = formatDate(endDate);

    final accountId = Id.trim().toLowerCase();


    /// OPENING BALANCE QUERY
    final dayBeforeStart = startDate.subtract(const Duration(days: 1));
    final dayBeforeStartStr = formatDate(dayBeforeStart);

    Query<Map<String, dynamic>> openingQuery = db
        .collection('ledgers')
        .where('companyId', isEqualTo: companyid)
        .where('account', isEqualTo: accountId)
        .where('date', isLessThanOrEqualTo: dayBeforeStartStr);

    if (branchId != null && branchId.trim().isNotEmpty) {
      openingQuery =
          openingQuery.where('branchId', isEqualTo: branchId.trim());
    }

    final openingSnap = await openingQuery.get();

    double openingDebit = 0.0;
    double openingCredit = 0.0;

    for (final doc in openingSnap.docs) {
      final data = doc.data();

      final amount = (data['amount'] ?? 0).toDouble();
      final type =
      (data['type'] ?? '').toString().toLowerCase().trim();

      if (type == 'debit') {
        openingDebit += amount;
      } else if (type == 'credit') {
        openingCredit += amount;
      }
    }


    double openingBalance = (openingDebit - openingCredit).abs();

    /// PERIOD QUERY

    Query<Map<String, dynamic>> query = db
        .collection('ledgers')
        .where('companyId', isEqualTo: companyid)
        .where('account', isEqualTo: accountId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr);

    if (branchId != null && branchId.trim().isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId.trim());
    }

    final snap = await query.get();

    /// START RUNNING BALANCE
    double runningBalance = openingBalance;


    /// SHOW OPENING
    transactions.add({
      'number': '',
      'account': Name,
      'accountId': accountId,
      'customerName': '',
      'openingBalance': openingBalance,
      'debit': 0.0,
      'credit': 0.0,
      'balance': openingBalance,
      'date': startStr,
      'branch': '',
      'staff': '',
      'transactionId': '',
      'description': 'Opening Balance',
      'type': '',
    });

    /// SORT DOCS FIRST
    final docs = snap.docs.toList();

    docs.sort((a, b) {
      final ad = a.data()['date'] ?? '';
      final bd = b.data()['date'] ?? '';
      return ad.compareTo(bd);
    });

    for (final doc in docs) {
      final data = doc.data();

      final amount = (data['amount'] ?? 0).toDouble();
      final type =
      (data['type'] ?? '').toString().toLowerCase().trim();

      double debit = 0.0;
      double credit = 0.0;

      if (type == 'debit') {
        debit = amount;
        runningBalance += amount;
      } else if (type == 'credit') {
        credit = amount;
        runningBalance -= amount;
      }

      transactions.add({
        'number': '',
        'account': data['account'] ?? '',
        'accountId': data['account'] ?? '',
        'customerName': data['customerName'] ?? '',
        'openingBalance': openingBalance,
        'debit': debit,
        'credit': credit,
        'balance': runningBalance,
        'date': data['date'] ?? '',
        'branch': data['branchName'] ?? '',
        'staff': data['createdBy'] ?? '',
        'transactionId': doc.id,
        'description': data['description'] ?? '',
        'type': type,
      });
    }

    itemTransactions = List<Map<String, dynamic>>.from(transactions);

    notifyListeners();
  }
  List<Map<String, dynamic>> filteredshowLedgerDetailsDialog() {
    final q = searchQuery.trim().toLowerCase();

    if (q.isEmpty) return itemTransactions;

    return itemTransactions.where((t) {
      return (t['customerName'] ?? '').toString().toLowerCase().contains(q) ||
          (t['account'] ?? '').toString().toLowerCase().contains(q) ||
          (t['date'] ?? '').toString().toLowerCase().contains(q) ||
          (t['transactionId'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }


  Future<void> showLedgerAccountDetailsDialog({ required DateTime startDate,required DateTime endDate, required String itemId,required String itemName, required String? branchId,}) async {

    final List<Map<String, dynamic>> transactions = [];

    /// FORMAT DATE
    String format(DateTime d) {
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }

    final start = format(startDate);
    final end = format(endDate);

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];

    /// Firestore allows
    List<String> dates = [];

    for (DateTime d = startDate;
    !d.isAfter(endDate);
    d = d.add(const Duration(days: 1))) {
      dates.add(format(d));
    }

    for (int i = 0; i < dates.length; i += 30) {
      final chunk = dates.skip(i).take(30).toList();

      Query<Map<String, dynamic>> query = db
          .collection('ledgers')
          .where('companyId', isEqualTo: companyid)
          .where('date', whereIn: chunk)
          .where('account', isEqualTo: itemId);

      ///BRANCH FILTER
      if (branchId != null &&
          branchId.isNotEmpty &&
          branchId.toLowerCase() != 'all') {
        query = query.where('branchId', isEqualTo: branchId.trim());
      }

      final snap = await query.get();
      allDocs.addAll(snap.docs);
    }

    /// BUILD TRANSACTIONS
    double balance = 0;

    for (final doc in allDocs) {
      final data = doc.data();

      final amount = (data['amount'] ?? 0).toDouble();
      final type = (data['type'] ?? '').toString().toLowerCase();

      if (type == 'debit') {
        balance += amount;
      } else if (type == 'credit') {
        balance -= amount;
      }

      transactions.add({
        'number': '',
        'transactionDate': data['date'] ?? '',
        'description': data['description'] ?? '',
        'debit': type == 'debit' ? amount : 0.0,
        'credit': type == 'credit' ? amount : 0.0,
        'balance': balance,
        'accountName': data['account'] ?? itemName,
        'accountId': data['account'] ?? itemId,
        'branchName': data['branchName'] ?? '',
        'branchId': data['branchId'] ?? '',
        'customerName': data['customerName'] ?? '',
        'transactionId': doc.id,
        'createdBy': data['createdBy'] ?? '',
      });
    }

    /// SORT BY DATE
    transactions.sort((a, b) =>
        a['transactionDate'].compareTo(b['transactionDate']));

    itemTransactions = transactions;
    notifyListeners();
  }
  List<Map<String, dynamic>> filteredshowLedgerAccountDetailsDialog() {
    final q = searchQuery.trim().toLowerCase();

    if (q.isEmpty) return itemTransactions;

    return itemTransactions.where((t) {
      return (t['description'] ?? '').toString().toLowerCase().contains(q) ||
          (t['transactionDate'] ?? '').toString().toLowerCase().contains(q) ||
          (t['accountName']??'').toString().toLowerCase().contains(q);
    }).toList();
  }

  Future<double> fetchAlreadyReturnedQty({required String receiptId,required String itemId, }) async {
    double totalReturned = 0.0;

    final snap = await db
        .collection('salesreturn')
        .where('returned_companyid', isEqualTo: companyid)
        .where('returned_receiptid', isEqualTo: receiptId).limit(1)
        .get(const GetOptions(source: Source.serverAndCache));

    for (final doc in snap.docs) {
      final items = doc.data()['returned_items'] as Map<String, dynamic>?;
      if (items == null) continue;

      for (final item in items.values) {
        if (item is! Map<String, dynamic>) continue;
        final docItemId = (item['returned_itemid'] ?? item['itemid'] ?? '').toString().trim();
        final docBarcode = (item['returned_barcode'] ?? item['barcode'] ?? '').toString().trim();
        
        if (docItemId == itemId.trim() || docBarcode == itemId.trim()) {
          totalReturned += double.tryParse(
              item['returned_quantity']?.toString() ?? '0'
          ) ?? 0;
        }
      }
    }

    return totalReturned;
  }
  Future<num> fetchItemCurrentBalance({ required String itemId, DateTimeRange? selectedDate, String? selectedBranch, }) async {
    try {
      final now = DateTime.now();

      final endDate = DateTime(
        (selectedDate?.end ?? now).year,
        (selectedDate?.end ?? now).month,
        (selectedDate?.end ?? now).day,
      );

      final endStr = _toDateOnly(endDate);

      final snap = await db
          .collection('stockreport')
          .where('companyid', isEqualTo: companyid)
          .where('summarydate', isLessThanOrEqualTo: endStr)
          .get(const GetOptions(source: Source.serverAndCache));

      final isAllBranches = selectedBranch == null || selectedBranch.isEmpty;
      double balance = 0.0;

      for (final doc in snap.docs) {
        final itemsRoot = doc.data()['items'] as Map<String, dynamic>?;
        if (itemsRoot == null) continue;

        final branchIds = isAllBranches
            ? itemsRoot.keys
            : (itemsRoot.containsKey(selectedBranch) ? [selectedBranch!] : <String>[]);

        for (final bId in branchIds) {
          final branchData = itemsRoot[bId];
          if (branchData is! Map<String, dynamic>) continue;

            for (final entry in branchData.entries) {
              if (entry.value is! Map<String, dynamic>) continue;

              final item = Map<String, dynamic>.from(entry.value);

              final docItemId = (item['itemId'] ?? item['itemid'] ?? item['id'] ?? '').toString().trim();
              final docBarcode = (item['barcode'] ?? '').toString().trim();
              
              if (docItemId != itemId.trim() && docBarcode != itemId.trim()) continue;

              balance += _dailyNet(item);
            }
        }
      }

      return balance.round();
    } catch (e) {
      print("Error fetching item balance: $e");
      return 0;
    }
  }


  double totalDebtPayments = 0;
  Map<String, Map<String, dynamic>> debtPaymentsByBranch = {};
  bool isloadingdebtpayments = false;

  bool isLoadingDebtPaymentTransactions = false;
  List<Map<String, dynamic>> debtPaymentTransactions = [];

  bool isLoadingDebtorReport = false;
  List<Map<String, dynamic>> debtorReportRows = [];
  double totalDebtorCreditBalance = 0;
  double totalDebtorAmountPaid = 0;

  Future<void> fetchDebtPaymentTransactions({ DateTimeRange? selectedDate, String? selectedBranch, String? customerId,}) async {
    try {
      isLoadingDebtPaymentTransactions = true;
      notifyListeners();

      final now = DateTime.now();
      final start = selectedDate?.start ?? now.subtract(const Duration(days: 30));
      final end   = selectedDate?.end   ?? now;
      final startStr = _toDateOnly(start);
      final endStr   = _toDateOnly(end);

      final baseQuery = db
          .collection('debtpayment')
          .where('companyid', isEqualTo: companyid)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr);

      Query<Map<String, dynamic>> query = baseQuery;
      if (selectedBranch != null && selectedBranch.isNotEmpty) {
        query = query.where('branchId', isEqualTo: selectedBranch);
      }
      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customerid', isEqualTo: customerId);
      }

      var snap = await query.get(const GetOptions(source: Source.serverAndCache));

      if (snap.docs.isEmpty && selectedBranch != null && selectedBranch.isNotEmpty) {
        final fallbackBranchQuery = baseQuery.where('branchid', isEqualTo: selectedBranch);
        Query<Map<String, dynamic>> fallbackQuery = fallbackBranchQuery;
        if (customerId != null && customerId.isNotEmpty) {
          fallbackQuery = fallbackBranchQuery.where('customerid', isEqualTo: customerId);
        }
        var fallbackSnap = await fallbackQuery.get(const GetOptions(source: Source.serverAndCache));
        if (fallbackSnap.docs.isNotEmpty) {
          snap = fallbackSnap;
        }
      }

      if (snap.docs.isEmpty && customerId != null && customerId.isNotEmpty) {
        Query<Map<String, dynamic>> fallbackCustomerQuery = baseQuery.where('customerId', isEqualTo: customerId);
        if (selectedBranch != null && selectedBranch.isNotEmpty) {
          fallbackCustomerQuery = fallbackCustomerQuery.where('branchId', isEqualTo: selectedBranch);
        }
        var fallbackSnap = await fallbackCustomerQuery.get(const GetOptions(source: Source.serverAndCache));
        if (fallbackSnap.docs.isNotEmpty) {
          snap = fallbackSnap;
        } else if (selectedBranch != null && selectedBranch.isNotEmpty) {
          final fallbackBranchCustomerQuery = baseQuery
              .where('branchid', isEqualTo: selectedBranch)
              .where('customerId', isEqualTo: customerId);
          fallbackSnap = await fallbackBranchCustomerQuery.get(const GetOptions(source: Source.serverAndCache));
          if (fallbackSnap.docs.isNotEmpty) {
            snap = fallbackSnap;
          }
        }
      }

      debtPaymentTransactions = snap.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('fetchDebtPaymentTransactions error: $e');
      debtPaymentTransactions = [];
    } finally {
      isLoadingDebtPaymentTransactions = false;
      notifyListeners();
    }
  }

  Future<void> fetchDebtorReport({ String? selectedBranch, DateTimeRange? selectedDate,}) async {
    try {
      isLoadingDebtorReport = true;
      notifyListeners();

      totalDebtorCreditBalance = 0;
      totalDebtorAmountPaid = 0;
      debtorReportRows = [];

      DateTime? _parseSaleDate(Map<String, dynamic> saleData) {
        final candidates = [
          saleData['createdAt'],
          saleData['createdat'],
          saleData['date'],
          saleData['datetime'],
        ];

        for (final candidate in candidates) {
          if (candidate is Timestamp) {
            return candidate.toDate();
          }
          if (candidate is DateTime) {
            return candidate;
          }
          if (candidate is String && candidate.isNotEmpty) {
            final parsed = DateTime.tryParse(candidate);
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      // Get all customers
      Query<Map<String, dynamic>> customerQuery = db
          .collection('customers')
          .where('companyid', isEqualTo: companyid);

      if (selectedBranch != null && selectedBranch.isNotEmpty) {
        customerQuery = customerQuery.where('branchid', isEqualTo: selectedBranch);
      }

      var customerSnap = await customerQuery
          .orderBy('createdat', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      if (customerSnap.docs.isEmpty && selectedBranch != null && selectedBranch.isNotEmpty) {
        customerQuery = db
            .collection('customers')
            .where('companyid', isEqualTo: companyid)
            .where('branchId', isEqualTo: selectedBranch);
        customerSnap = await customerQuery
            .orderBy('createdat', descending: true)
            .get(const GetOptions(source: Source.serverAndCache));
      }

      final rows = <Map<String, dynamic>>[];
      for (final customerDoc in customerSnap.docs) {
        final customerData = customerDoc.data();
        final customerId = customerData['id']?.toString() ?? customerDoc.id;
        final customerName = customerData['name']?.toString() ?? '';
        final branchId = customerData['branchid']?.toString() ?? '';
        final branchName = customerData['branchname']?.toString() ?? '';
        final creditLimit = customerData['creditlimit']?.toString() ?? '';
        final contact = customerData['contact']?.toString() ?? '';

        // Calculate total amount owed (from credit sales)
        var creditSalesQuery = db
            .collection('sales')
            .where('companyId', isEqualTo: companyid)
            .where('customerId', isEqualTo: customerId)
            .where('transMode', isEqualTo: 'credit');

        final creditSalesSnap = await creditSalesQuery
            .get(const GetOptions(source: Source.serverAndCache));

        double totalOwed = 0;
        for (final sale in creditSalesSnap.docs) {
          final saleData = sale.data();
          final saleDate = _parseSaleDate(saleData);

          if (selectedDate != null && saleDate != null) {
            final start = DateTime(
              selectedDate!.start.year,
              selectedDate!.start.month,
              selectedDate!.start.day,
            );
            final end = DateTime(
              selectedDate!.end.year,
              selectedDate!.end.month,
              selectedDate!.end.day,
              23,
              59,
              59,
              999,
            );
            if (saleDate.isBefore(start) || saleDate.isAfter(end)) {
              continue;
            }
          }

          final amount = (saleData['totalamount'] is num)
              ? (saleData['totalamount'] as num).toDouble()
              : double.tryParse(saleData['totalamount']?.toString() ?? '0') ?? 0.0;
          totalOwed += amount;
        }

        // Calculate total payments made - use amountpaid from customers collection
        final amountPaidFromCustomer = (customerData['amountpaid'] is num)
            ? (customerData['amountpaid'] as num).toDouble()
            : double.tryParse(customerData['amountpaid']?.toString() ?? '0') ?? 0.0;
        
        double totalPaid = amountPaidFromCustomer;

        // Calculate balance
        final balance = totalOwed - totalPaid;

        // Skip if no debt, no payment, and no credit limit
        if (totalOwed == 0 && totalPaid == 0 && creditLimit.isEmpty) {
          continue;
        }

        final row = {
          'customerId': customerId,
          'customerName': customerName,
          'branchId': branchId,
          'branchName': branchName,
          'creditBalance': totalOwed,  // Total amount owed
          'amountPaid': totalPaid,     // Total amount paid
          'creditLimit': creditLimit,
          'balance': balance,          // What's still owed
          'contact': contact,
        };
        rows.add(row);
        totalDebtorCreditBalance += totalOwed;
        totalDebtorAmountPaid += totalPaid;
      }

      debtorReportRows = rows;
    } catch (e) {
      debugPrint('fetchDebtorReport error: $e');
      totalDebtorCreditBalance = 0;
      totalDebtorAmountPaid = 0;
      debtorReportRows = [];
    } finally {
      isLoadingDebtorReport = false;
      notifyListeners();
    }
  }

  Future<void> fetchDebtPayments({ DateTimeRange? selectedDate, String? selectedBranch,}) async {
    try {
      isloadingdebtpayments = true;
      notifyListeners();

      totalDebtPayments    = 0;
      debtPaymentsByBranch = {};

      final now = DateTime.now();
      final start = selectedDate?.start ?? now.subtract(const Duration(days: 30));
      final end   = selectedDate?.end   ?? now;
      final startStr = _toDateOnly(start);
      final endStr   = _toDateOnly(end);

      final snap = await db
          .collection('salesSummary')
          .where('companyid',   isEqualTo:              companyid)
          .where('summarydate', isGreaterThanOrEqualTo:  startStr)
          .where('summarydate', isLessThanOrEqualTo:     endStr)
          .get(const GetOptions(source: Source.serverAndCache));

      if (snap.docs.isEmpty) return;

      final raw = snap.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      double grandTotal = 0;
      final Map<String, Map<String, dynamic>> byBranch = {};

      for (final doc in raw) {
        final staffSummary =
            doc['staffSummary'] as Map<String, dynamic>? ?? {};

        final Iterable<MapEntry<String, dynamic>> branchEntries =
        selectedBranch != null
            ? staffSummary.entries.where((e) => e.key == selectedBranch)
            : staffSummary.entries;

        for (final branchEntry in branchEntries) {
          final branchId  = branchEntry.key;
          final staffMap  = branchEntry.value as Map<String, dynamic>? ?? {};

          byBranch.putIfAbsent(branchId, () => {
            'branchId'  : branchId,
            'branchName': '',
            'total'     : 0.0,
            'byStaff'   : <String, Map<String, dynamic>>{},
          });

          final branchNode = byBranch[branchId]!;
          final byStaff =
          branchNode['byStaff'] as Map<String, Map<String, dynamic>>;

          for (final staffEntry in staffMap.entries) {
            final email     = staffEntry.key;
            final staffData = staffEntry.value as Map<String, dynamic>? ?? {};

            final staffName  = staffData['staffName']?.toString()
                ?? staffData['staff']?.toString()
                ?? email;
            final branchName = staffData['branchName']?.toString() ?? branchId;
            final payment    = (staffData['debtpayments_value'] ?? 0).toDouble();

            if ((branchNode['branchName'] as String).isEmpty) {
              branchNode['branchName'] = branchName;
            }

            byStaff.putIfAbsent(email, () => {
              'staffName': staffName,
              'email'    : email,
              'total'    : 0.0,
            });

            byStaff[email]!['total'] =
                (byStaff[email]!['total'] as double) + payment;
            branchNode['total'] =
                (branchNode['total'] as double) + payment;
            grandTotal += payment;
          }
        }
      }

      totalDebtPayments    = grandTotal;
      debtPaymentsByBranch = byBranch;

    } catch (e) {
      debugPrint('fetchDebtPayments error: $e');
      totalDebtPayments    = 0;
      debtPaymentsByBranch = {};
    } finally {
      isloadingdebtpayments = false;
      notifyListeners();
    }
  }
  bool isLoadingSupplierReport = false;
  bool isLoadingSupplierTransactions = false;  // ADD THIS

  List<Map<String, dynamic>> _supplierReportRaw = [];
  List<Map<String, dynamic>> _supplierReportRows = [];
  List<Map<String, dynamic>> get supplierReportRows => _supplierReportRows;
  Map<String, double> _supplierReportTotals = {};
  Map<String, double> get supplierReportTotals => _supplierReportTotals;
  List<Map<String, dynamic>> _supplierTransactions = [];
  List<Map<String, dynamic>> get supplierTransactions => _supplierTransactions;

  Future<void> fetchSupplierReport({
    DateTimeRange? selectedDate,
    String? selectedBranch,
  }) async {
    isLoadingSupplierReport = true;
    _notify();

    try {
      final String? startStr = selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(selectedDate.start)
          : null;
      final String? endStr = selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(selectedDate.end)
          : null;

      Query query = db
          .collection('stock_transactions')
          .where('companyid', isEqualTo: companyid);

      if (selectedBranch != null && selectedBranch.isNotEmpty) {
        query = query.where('branchid', isEqualTo: selectedBranch);
      }

      if (startStr != null) {
        query = query
            .where('date', isGreaterThanOrEqualTo: startStr)
            .where('date', isLessThanOrEqualTo: endStr!);
      }

      final snap = await query.get();
      _supplierReportRaw = snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      _aggregateSupplierReport();
    } catch (e) {
      debugPrint('fetchSupplierReport error: $e');
    }

    isLoadingSupplierReport = false;
    _notify();
  }

  Future<void> fetchSupplierTransactions({
    required String supplierId,
    DateTimeRange? selectedDate,
    String? selectedBranch,
  }) async {
    isLoadingSupplierTransactions = true;
    _notify();

    try {
      final String? startStr = selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(selectedDate.start)
          : null;
      final String? endStr = selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(selectedDate.end)
          : null;

      Query query = db
          .collection('stock_transactions')
          .where('companyid', isEqualTo: companyid)
          .where('supplierid', isEqualTo: supplierId);

      if (selectedBranch != null && selectedBranch.isNotEmpty) {
        query = query.where('branchid', isEqualTo: selectedBranch);
      }

      if (startStr != null) {
        query = query
            .where('date', isGreaterThanOrEqualTo: startStr)
            .where('date', isLessThanOrEqualTo: endStr!);
      }

      query = query.orderBy('date', descending: true);

      final snap = await query.get();
      _supplierTransactions = snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('fetchSupplierTransactions error: $e');
    }

    isLoadingSupplierTransactions = false;
    _notify();
  }

  void _aggregateSupplierReport() {
    final Map<String, Map<String, dynamic>> bySupplier = {};
    for (final doc in _supplierReportRaw) {
      final id   = (doc['supplierid']   ?? '').toString();
      final name = (doc['suppliername'] ?? '').toString();
      final isReturn = doc['purchasereturntrue'] == true;
      final purchaseType = (doc['purchasetype'] ?? '').toString();
      final ptKey = purchaseType.toLowerCase().trim();
      double _d(dynamic v) {
        if (v == null) return 0.0;
        if (v is double) return v;
        if (v is int) return v.toDouble();
        return (v as num).toDouble();
      }
      final gross    = _d(doc['gross']);
      final net      = _d(doc['netval']);
      final discount = _d(doc['discount']);
      final tax      = _d(doc['tax']);
      if (!bySupplier.containsKey(id)) {
        bySupplier[id] = {
          'supplierId':         id,
          'supplierName':       name,
          'gross':              0.0,
          'net':                0.0,
          'discount':           0.0,
          'tax':                0.0,
          'purchaseCount':      0.0,
          'returnCount':        0.0,
          'purchaseType':       '',
          'cashAmount':         0.0,
          'creditAmount':       0.0,
          'openingStockAmount': 0.0,
        };
      }
      bySupplier[id]!['gross']    = (bySupplier[id]!['gross']    as double) + gross;
      bySupplier[id]!['net']      = (bySupplier[id]!['net']      as double) + net;
      bySupplier[id]!['discount'] = (bySupplier[id]!['discount'] as double) + discount;
      bySupplier[id]!['tax']      = (bySupplier[id]!['tax']      as double) + tax;
      if (!isReturn) {
        if (ptKey == 'cash') {
          bySupplier[id]!['cashAmount'] = (bySupplier[id]!['cashAmount'] as double) + net;
        } else if (ptKey == 'credit') {
          bySupplier[id]!['creditAmount'] = (bySupplier[id]!['creditAmount'] as double) + net;
        } else if (ptKey.contains('opening')) {
          bySupplier[id]!['openingStockAmount'] = (bySupplier[id]!['openingStockAmount'] as double) + net;
        }
        if (purchaseType.isNotEmpty) {
          final existing = (bySupplier[id]!['purchaseType'] as String);
          if (existing.isEmpty) {
            bySupplier[id]!['purchaseType'] = purchaseType;
          } else if (!existing.split(', ').contains(purchaseType)) {
            bySupplier[id]!['purchaseType'] = '$existing, $purchaseType';
          }
        }
      }
      if (isReturn) {
        bySupplier[id]!['returnCount'] =
            (bySupplier[id]!['returnCount'] as double) + 1;
      } else {
        bySupplier[id]!['purchaseCount'] =
            (bySupplier[id]!['purchaseCount'] as double) + 1;
      }
    }
    _supplierReportRows = bySupplier.values.toList()
      ..sort((a, b) =>
          (a['supplierName'] as String).compareTo(b['supplierName'] as String));
    _computeSupplierReportTotals();
  }

  void _computeSupplierReportTotals() {
    double totalGross = 0, totalNet = 0, totalDiscount = 0, totalTax = 0;
    double totalCount = 0, totalReturns = 0;
    double totalCash = 0, totalCredit = 0, totalOpeningStock = 0;

    for (final row in _supplierReportRows) {
      totalGross        += row['gross']              as double;
      totalNet          += row['net']                as double;
      totalDiscount     += row['discount']           as double;
      totalTax          += row['tax']                as double;
      totalCount        += row['purchaseCount']      as double;
      totalReturns      += row['returnCount']        as double;
      totalCash         += row['cashAmount']         as double;
      totalCredit       += row['creditAmount']       as double;
      totalOpeningStock += row['openingStockAmount'] as double;
    }

    _supplierReportTotals = {
      'totalGross':        totalGross,
      'totalNet':          totalNet,
      'totalDiscount':     totalDiscount,
      'totalTax':          totalTax,
      'totalCount':        totalCount,
      'totalReturns':      totalReturns,
      'totalCash':         totalCash,
      'totalCredit':       totalCredit,
      'totalOpeningStock': totalOpeningStock,
    };
  }

  List<Map<String, dynamic>> filteredSupplierReport() {
    final q = searchQuery.toLowerCase().trim();
    if (q.isEmpty) return _supplierReportRows;
    return _supplierReportRows
        .where((r) =>
        (r['supplierName'] as String).toLowerCase().contains(q))
        .toList();
  }

  Map<String, double> filteredSupplierTotals() {
    final rows = filteredSupplierReport();

    double totalGross = 0,
        totalNet = 0,
        totalDiscount = 0,
        totalTax = 0,
        totalCount = 0,
        totalReturns = 0,
        totalCash = 0,
        totalCredit = 0,
        totalOpeningStock = 0;

    for (final row in rows) {
      totalGross += row['gross'] as double;
      totalNet += row['net'] as double;
      totalDiscount += row['discount'] as double;
      totalTax += row['tax'] as double;
      totalCount += row['purchaseCount'] as double;
      totalReturns += row['returnCount'] as double;
      totalCash += row['cashAmount'] as double;
      totalCredit += row['creditAmount'] as double;
      totalOpeningStock += row['openingStockAmount'] as double;
    }

    return {
      'totalGross': totalGross,
      'totalNet': totalNet,
      'totalDiscount': totalDiscount,
      'totalTax': totalTax,
      'totalCount': totalCount,
      'totalReturns': totalReturns,
      'totalCash': totalCash,
      'totalCredit': totalCredit,
      'totalOpeningStock': totalOpeningStock,
    };
  }

  bool isLoadingDamageReport = false;
  bool isLoadingDamageDetails = false;
  List<Map<String, dynamic>> damageReportRows = [];
  List<Map<String, dynamic>> _damageReportDocs = [];
  List<Map<String, dynamic>> get damageReportDocs => _damageReportDocs;
  List<Map<String, dynamic>> damageReportDetails = [];
  double totalDamageCost = 0;
  double totalDamageSelling = 0;

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _damageItemKey(Map<String, dynamic> item) {
    final itemId = item['itemid']?.toString() ??
        item['id']?.toString() ??
        item['barcode']?.toString() ??
        '';
    if (itemId.isNotEmpty) return itemId;
    final itemName = item['item']?.toString() ?? item['name']?.toString() ?? '';
    return itemName.toLowerCase();
  }

  List<Map<String, dynamic>> _extractDamageItems(
      Map<String, dynamic> doc,
      String docId,
      ) {
    final items = <Map<String, dynamic>>[];
    
    // First, try to find item_0, item_1, etc. at root level
    final itemKeys = doc.keys.where((key) => key.toString().startsWith('item_')).toList();
    if (itemKeys.isNotEmpty) {
      for (final key in itemKeys) {
        final value = doc[key];
        if (value is Map<String, dynamic>) {
          final item = Map<String, dynamic>.from(value);
          item['__docId'] = docId;
          item['__rootBranchId'] = doc['branchid'] ?? '';
          item['__rootBranchName'] = doc['branchname'] ?? '';
          item['__rootCreatedAt'] = doc['createdat'];
          item['__rootCreatedBy'] = doc['createdby'] ?? '';
          items.add(item);
        }
      }
    }
    // If no items found at root, check if doc['item'] is a map containing item_0, item_1, etc.
    else if (doc['item'] is Map<String, dynamic>) {
      final itemContainer = doc['item'] as Map<String, dynamic>;
      final nestedItemKeys = itemContainer.keys.where((key) => key.toString().startsWith('item_')).toList();
      
      if (nestedItemKeys.isNotEmpty) {
        // Extract items from nested structure
        for (final key in nestedItemKeys) {
          final value = itemContainer[key];
          if (value is Map<String, dynamic>) {
            final item = Map<String, dynamic>.from(value);
            item['__docId'] = docId;
            item['__rootBranchId'] = doc['branchid'] ?? '';
            item['__rootBranchName'] = doc['branchname'] ?? '';
            item['__rootCreatedAt'] = doc['createdat'];
            item['__rootCreatedBy'] = doc['createdby'] ?? '';
            items.add(item);
          }
        }
      } else {
        // Treat doc['item'] as a single item (for backward compatibility)
        final value = Map<String, dynamic>.from(itemContainer);
        value['__docId'] = docId;
        value['__rootBranchId'] = doc['branchid'] ?? '';
        value['__rootBranchName'] = doc['branchname'] ?? '';
        value['__rootCreatedAt'] = doc['createdat'];
        value['__rootCreatedBy'] = doc['createdby'] ?? '';
        items.add(value);
      }
    }
    return items;
  }

  Future<void> fetchDamageReport({
    DateTimeRange? selectedDate,
    String? selectedBranch,
  }) async {
    try {
      isLoadingDamageReport = true;
      notifyListeners();

      totalDamageCost = 0;
      totalDamageSelling = 0;
      damageReportRows = [];
      _damageReportDocs = [];
      damageReportDetails = [];

      final now = DateTime.now();
      final startDate = selectedDate?.start ?? now.subtract(const Duration(days: 60));
      final endDate = selectedDate?.end ?? now;
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      var query = db.collection('damageitems')
          .where('companyid', isEqualTo: companyid)
          .where('createdat', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdat', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (selectedBranch != null && selectedBranch.isNotEmpty) {
        query = query.where('branchid', isEqualTo: selectedBranch);
      }

      final snap = await query
          .orderBy('createdat', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      _damageReportDocs = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['__docId'] = doc.id;
        return data;
      }).toList();

      final Map<String, Map<String, dynamic>> grouped = {};
      for (final doc in _damageReportDocs) {
        final docId = doc['__docId']?.toString() ?? '';
        final items = _extractDamageItems(doc, docId);
        for (final item in items) {
          final itemId = item['itemid']?.toString() ??
              item['id']?.toString() ??
              item['barcode']?.toString() ??
              '';
          final itemName = item['item']?.toString() ?? item['name']?.toString() ?? 'Unknown';
          final itemKey = _damageItemKey(item);
          final mode = item['mode']?.toString() ?? '';

          final modeData = (item['modes'] is Map)
              ? (item['modes'] as Map)[mode]
              : null;
          final cp = _parseDouble(modeData?['cp'] ?? item['cp']);
          final sp = _parseDouble(modeData?['sp'] ?? item['sp']);
          final rp = _parseDouble(modeData?['rp'] ?? item['rp']);

          final totalPieces = _parseDouble(item['totalpieces']) > 0
              ? _parseDouble(item['totalpieces'])
              : _parseDouble(item['quantity']);
          final cost = cp * totalPieces;
          final selling = (rp > 0 ? rp : sp) * totalPieces;
          if (!grouped.containsKey(itemKey)) {
            grouped[itemKey] = {
              'itemKey': itemKey,
              'itemId': itemId,
              'itemName': itemName,
              'totalCost': 0.0,
              'totalSelling': 0.0,
              'totalPieces': 0.0,
              'detailCount': 0,
            };
          }
          grouped[itemKey]!['totalCost'] = (grouped[itemKey]!['totalCost'] as double) + cost;
          grouped[itemKey]!['totalSelling'] = (grouped[itemKey]!['totalSelling'] as double) + selling;
          grouped[itemKey]!['totalPieces'] = (grouped[itemKey]!['totalPieces'] as double) + totalPieces;
          grouped[itemKey]!['detailCount'] = (grouped[itemKey]!['detailCount'] as int) + 1;
          totalDamageCost += cost;
          totalDamageSelling += selling;
        }
      }

      damageReportRows = grouped.values.toList()
        ..sort((a, b) => (a['itemName'] as String).compareTo(b['itemName'] as String));
    } catch (e) {
      debugPrint('fetchDamageReport error: $e');
      damageReportRows = [];
      _damageReportDocs = [];
      damageReportDetails = [];
      totalDamageCost = 0;
      totalDamageSelling = 0;
    } finally {
      isLoadingDamageReport = false;
      notifyListeners();
    }
  }

  Future<void> fetchDamageItemDetails({
    required String itemKey,
    DateTimeRange? selectedDate,
    String? selectedBranch,
  }) async {
    try {
      isLoadingDamageDetails = true;
      notifyListeners();

      final rows = <Map<String, dynamic>>[];
      if (_damageReportDocs.isEmpty) {
        await fetchDamageReport(selectedDate: selectedDate, selectedBranch: selectedBranch);
      }

      for (final doc in _damageReportDocs) {
        final docId = doc['__docId']?.toString() ?? '';
        final items = _extractDamageItems(doc, docId);
        for (final item in items) {
          final currentItemKey = _damageItemKey(item);
          if (currentItemKey == itemKey) {
            final totalPieces = _parseDouble(item['totalpieces']) > 0
                ? _parseDouble(item['totalpieces'])
                : _parseDouble(item['quantity']);
            final cp = _parseDouble(item['cp']);
            final sp = _parseDouble(item['sp']);
            final rp = _parseDouble(item['rp']);
            final currentItemId = item['itemid']?.toString() ??
                item['id']?.toString() ??
                item['barcode']?.toString() ??
                item['item']?.toString().toLowerCase() ??
                '';
            rows.add({
              'docId': docId,
              'branchId': item['__rootBranchId'] ?? '',
              'branchName': item['__rootBranchName'] ?? '',
              'createdBy': item['__rootCreatedBy'] ?? '',
              'createdAt': item['__rootCreatedAt'],
              'dateymd': item['dateymd'] ?? '',
              'itemId': currentItemId,
              'itemName': item['item']?.toString() ?? item['name']?.toString() ?? 'Unknown',
              'mode': item['mode'] ?? '',
              'reason': item['reason'] ?? '',
              'cp': cp,
              'sp': rp > 0 ? rp : sp,
              'quantity': _parseDouble(item['quantity']),
              'totalPieces': totalPieces,
              'cost': cp * totalPieces,
              'selling': (rp > 0 ? rp : sp) * totalPieces,
              'reference': item['barcode'] ?? item['itemid'] ?? '',
            });
          }
        }
      }

      damageReportDetails = rows
        ..sort((a, b) => (a['dateymd']?.toString() ?? '').compareTo(b['dateymd']?.toString() ?? ''));
    } catch (e) {
      debugPrint('fetchDamageItemDetails error: $e');
      damageReportDetails = [];
    } finally {
      isLoadingDamageDetails = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> filteredDamageReport() {
    final q = searchQuery.toLowerCase().trim();
    if (q.isEmpty) return damageReportRows;
    return damageReportRows.where((row) {
      final name = (row['itemName'] ?? '').toString().toLowerCase();
      final id = (row['itemId'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  Map<String, double> filteredDamageTotals() {
    final rows = filteredDamageReport();
    double totalCost = 0, totalSelling = 0, totalPieces = 0, totalCount = 0;
    for (final row in rows) {
      totalCost += row['totalCost'] as double;
      totalSelling += row['totalSelling'] as double;
      totalPieces += row['totalPieces'] as double;
      totalCount += (row['detailCount'] as int).toDouble();
    }
    return {
      'totalCost': totalCost,
      'totalSelling': totalSelling,
      'totalPieces': totalPieces,
      'totalCount': totalCount,
    };
  }


   load(StaffModel staff) async {
    _permissions = staff.permissions ?? {};

    final prefs = await SharedPreferences.getInstance();

    final permissionMap = _permissions.map(
          (key, value) => MapEntry(key, value.toMap()),
    );

    await prefs.setString(
      'permissions',
      jsonEncode(permissionMap),
    );

    notifyListeners();
  }

   loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final json = prefs.getString('permissions');
    if (json == null) return;

    final decoded = Map<String, dynamic>.from(jsonDecode(json));

    _permissions = decoded.map(
          (key, value) => MapEntry(
        key,
        ModulePermission.fromMap(
          Map<String, dynamic>.from(value),
        ),
      ),
    );

    notifyListeners();
  }

   clearpermissions() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('permissions');
    _permissions.clear();

    notifyListeners();
  }

  bool canView(String module) =>
      _permissions[module]?.view ?? false;

  bool canCreate(String module) =>
      _permissions[module]?.create ?? false;

  bool canEdit(String module) =>
      _permissions[module]?.edit ?? false;

  bool canDelete(String module) =>
      _permissions[module]?.delete ?? false;

  bool can_Print(String module) =>
      _permissions[module]?.print ?? false;

  Map<String, List<String>>? roleAccessSelections;
  bool roleAccessLoading = false;
  bool roleAccessError = false;

  Future<void> loadRoleAccessSelections({bool force = false}) async {
    if (roleAccessLoading) return;
    if (roleAccessSelections != null && !force) return;

    roleAccessLoading = true;
    roleAccessError = false;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(roleAccessSelectionsCollection)
          .where('companyId', isEqualTo: companyid)
          .get();

      final selections = <String, List<String>>{};
      for (final doc in snapshot.docs) {
        final prefix = '${companyid}_';
        final roleKey = doc.id.startsWith(prefix)
            ? doc.id.substring(prefix.length)
            : doc.id;
        final pages = (doc.data()['pages'] as List<dynamic>? ?? [])
            .map((item) =>
            RolePageSelection.fromMap(item as Map<String, dynamic>))
            .where((page) => page.route.isNotEmpty)
            .map((page) => page.route)
            .toList();
        selections[roleKey] = pages;
      }

      for (final entry in getDefaultRoleAccessSelections().entries) {
        selections.putIfAbsent(entry.key, () => entry.value);
      }

      roleAccessSelections = selections;
      roleAccessLoading = false;
      roleAccessError = false;
      notifyListeners();
    } catch (e) {
      roleAccessLoading = false;
      roleAccessError = true;
      notifyListeners();
    }
  }


  Future<void> saveRoleAccessSelections( Map<String, List<String>> selections,) async {
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    for (final entry in selections.entries) {
      final docRef = FirebaseFirestore.instance
          .collection(roleAccessSelectionsCollection)
          .doc('${companyid}_${entry.key}');
      final pages = entry.value
          .map(
            (route) => RolePageSelection(
          route: route,
          label: pageLabelForRoute(route),
        ).toMap(),
      )
          .toList();
      batch.set(
        docRef,
        {
          'company': company,
          'companyId': companyid,
          'pages': pages,
          'staff': staff,
          'updatedAt': now.toIso8601String(),
          'date':
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'day': _roleAccessWeekdayName(now.weekday),
          'month': '${now.year}.${now.month}',
          'id': docRef.id,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();


    roleAccessSelections =
        selections.map((key, value) => MapEntry(key, List<String>.from(value)));
    roleAccessError = false;
    notifyListeners();
  }

  String _roleAccessWeekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  double _salesValue = 0.00;

  double get salesValue => _salesValue;

  StreamSubscription? _salesSubscription;

  void listenToDashboardSales() {
    _salesSubscription?.cancel();
    if (companyid.trim().isEmpty) {
      _salesValue = 0;
      notifyListeners();
      return;
    }
    _salesSubscription = db
        .collection('dashbaord_stats')
        .doc(companyid)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        _salesValue = 0;
        notifyListeners();
        return;
      }

      final data = snapshot.data()!;

      if (accesslevel.toLowerCase() == 'super admin') {
        _salesValue =(data['companysales_value'] as num?)?.toDouble() ?? 0;
      } else {
        final branchSales = Map<String, dynamic>.from(data['branchsales'] ?? {});

        if (branchSales.containsKey(branchid)) {
          final branch = Map<String, dynamic>.from(branchSales[branchid]);

          _salesValue = (branch['sales_value'] as num?)?.toDouble() ?? 0;
        } else {
          _salesValue = 0;
        }
      }

      notifyListeners();
    });
  }

  static const Map<String, List<String>> _defaultTierFeatures = {
    'starter': [
      'sales',
      'sales_register',
      'stock_report',
    ],

    'professional': [
      'sales',
      'sales_register',
      'stock_report',
      'staff_sales_report',
      'category_sales_report',
      'supplier_report',
      'payment_report',
      'creditor_payable',
      'discount_codes',
      'bundle_management',
      'sales_return',
      'stock_transfer',
      'thermal_printing',
      'hubtel_payment',
      'momo_payment',
    ],

    'enterprise': [
      'sales',
      'sales_register',
      'stock_report',
      'staff_sales_report',
      'category_sales_report',
      'supplier_report',
      'payment_report',
      'creditor_payable',
      'discount_codes',
      'bundle_management',
      'sales_return',
      'stock_transfer',
      'thermal_printing',
      'hubtel_payment',
      'momo_payment',
      'general_ledger',
      'profit_and_loss',
      'multi_company',
      'bulk_stock_sync',
    ],
  };


  Map<String, List<String>> tierFeatureSelections = {};
  bool tierFeaturesLoading = false;
  bool tierFeaturesError = false;

  Future<void> loadTierFeatures({bool force = false}) async {
    final spref = await SharedPreferences.getInstance();
    if (tierFeaturesLoading) return;
    if (tierFeatureSelections.isNotEmpty && !force) return;

    tierFeaturesLoading = true;
    tierFeaturesError = false;
    notifyListeners();

    try {
      final snap = await db.collection('tier_features').get(
        const GetOptions(source: Source.serverAndCache),
      );

      final loaded = <String, List<String>>{};

      for (final doc in snap.docs) {
        final features = (doc.data()['features'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        loaded[doc.id] = features;
      }

      for (final entry in _defaultTierFeatures.entries) {
        loaded.putIfAbsent(entry.key, () => entry.value);
      }

      tierFeatureSelections = loaded;

      await spref.setStringList('tierFeatureSelections', tierFeatureSelections.entries.map((e) => '${e.key}:${e.value.join(',')}').toList());
      tierFeaturesLoading = false;
      tierFeaturesError = false;
      notifyListeners();
    } catch (e) {
      tierFeatureSelections = Map<String, List<String>>.from(_defaultTierFeatures);
      tierFeaturesLoading = false;
      tierFeaturesError = true;
      notifyListeners();
    }
  }

  Future<void> saveTierFeatures(String tier, List<String> features) async {
    final spref = await SharedPreferences.getInstance();
    await db.collection('tier_features').doc(tier).set({
      'features': features,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': staff,
    }, SetOptions(merge: true));

    tierFeatureSelections[tier] = features;

    spref.setStringList('tierFeatureSelections', tierFeatureSelections.entries.map((e) => '${e.key}:${e.value.join(',')}').toList());
    notifyListeners();
  }

  bool hasFeature(String featureKey) {
    final features = tierFeatureSelections[subscriptionTier] ?? _defaultTierFeatures[subscriptionTier] ?? [];
    return features.contains(featureKey);
  }

  void listenToStaffChanges() {
    _staffDocSub?.cancel();
    if (staffemail.isEmpty) return;

    _staffDocSub = db.collection('staff').doc(staffemail).snapshots().listen((doc) async {
      if (!doc.exists || doc.data() == null) return;

      final updated = StaffModel.fromMap(doc.data()!);
      final spref = await SharedPreferences.getInstance();

      currentStaff = updated;
      branch = updated.branchname;
      branchid = updated.branchid;
      canPrint = updated.canPrint;
      canEditPrice = updated.canEditPrice;
      canSelectDate = updated.canSelectDate;
      canSellAnyBranch = updated.canSellAnyBranch;
      allowDiscount = updated.allowDiscount;
      allowDiscountCode = updated.allowDiscountCode;
      accesslevel = updated.accesslevel;
      staffPosition = updated.position;
      staff = updated.name;
      allowedPaymentMethods = updated.allowedPaymentMethods;
      salesWarehouseIds = updated.salesWarehouseIds;
      salesWarehouseNames = updated.salesWarehouseNames;
      if (salesWarehouseIds.isNotEmpty) {
        salesWarehouseId = salesWarehouseIds.first;
        salesWarehouseName = salesWarehouseNames.isNotEmpty ? salesWarehouseNames.first : '';
      } else {
        salesWarehouseId = null;
        salesWarehouseName = null;
      }

      final pricingList = updated.pricingmode.map((e) => e.toString()).toList();
      pricingmode = pricingList;

      spref.setString('accesslevel', accesslevel);
      spref.setString('accessLevel', accesslevel);
      spref.setString('staff', staff);
      spref.setString('branch', branch);
      spref.setString('branchid', branchid);
      spref.setInt('staffPosition', staffPosition);
      spref.setBool('canPrint', canPrint);
      spref.setBool('canEditPrice', canEditPrice);
      spref.setBool('canSelectDate', canSelectDate);
      spref.setBool('canSellAnyBranch', canSellAnyBranch);
      spref.setBool('allowDiscount', allowDiscount);
      spref.setBool('allowDiscountCode', allowDiscountCode);
      spref.setStringList('salesWarehouseIds', salesWarehouseIds);
      spref.setStringList('salesWarehouseNames', salesWarehouseNames);
      spref.setStringList('allowedPaymentMethods', allowedPaymentMethods);
      spref.setStringList('pricingmode', pricingList);
      if (salesWarehouseId != null) {
        spref.setString('salesWarehouseId', salesWarehouseId!);
      } else {
        spref.remove('salesWarehouseId');
      }
      if (salesWarehouseName != null) {
        spref.setString('salesWarehouseName', salesWarehouseName!);
      } else {
        spref.remove('salesWarehouseName');
      }

      await load(updated);

      notifyListeners();
    }, onError: (e) {
      debugPrint("Error listening to staff changes: $e");
    });
  }

updateStockreorderBalance({required int companyCount, required String branchid,branchCount}) async {
   await db .collection("dashbaord_stats").doc(companyid).update({
    "companyreorderCount":  companyCount,
     "branchreorderCount.$branchid": branchCount,

  });

}

}