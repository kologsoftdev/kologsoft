import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/branch.dart';
import '../models/sales_import_models.dart';
import '../providers/Datafeed.dart';

/// Result of one [SalesImportService.syncFromExternalApi] run.
class ApiSyncResult {
  final int fetched;
  final int uploaded;
  final int skipped;
  final int failed;
  final List<String> uploadedIds;
  final List<String> errors;

  const ApiSyncResult({
    required this.fetched,
    required this.uploaded,
    required this.skipped,
    required this.failed,
    required this.uploadedIds,
    this.errors = const [],
  });

  static const empty = ApiSyncResult(fetched: 0, uploaded: 0, skipped: 0, failed: 0, uploadedIds: []);

  @override
  String toString() {
    return 'ApiSyncResult(fetched: $fetched, uploaded: $uploaded, skipped: $skipped, '
        'failed: $failed, uploadedIds: $uploadedIds, errors: $errors)';
  }
}

class SalesImportService {
  final FirebaseFirestore db;
  SalesImportService({FirebaseFirestore? db}) : db = db ?? FirebaseFirestore.instance;

  static const int maxFieldLength = 200;
  // Firestore hard-caps a batch at 500 writes; 450 leaves headroom.
  static const int writeBatchSize = 450;

  static const Set<String> validPaymentMethods = {
    'cash',
    'momo',
    'card',
    'bank_transfer',
    'cheque',
  };

  static const Map<String, String> _paymentMethodAliases = {
    'banktransfer': 'bank_transfer',
    'bank transfer': 'bank_transfer',
    'bank-transfer': 'bank_transfer',
    'transfer': 'bank_transfer',
    'mobilemoney': 'momo',
    'mobile money': 'momo',
    'mobile_money': 'momo',
    'momo': 'momo',
    'card': 'card',
    'cheque': 'cheque',
    'cash': 'cash',
  };

  String sanitizeCell(String value) {
    var v = value.trim();
    const dangerous = ['=', '+', '-', '@', '\t', '\r', '\n'];
    if (v.isNotEmpty && dangerous.contains(v[0])) {
      v = "'$v";
    }
    if (v.length > maxFieldLength) {
      v = v.substring(0, maxFieldLength);
    }
    return v;
  }

  // ---------------------------------------------------------------------
  // Branch extraction / creation — unchanged: match by name, create
  // whatever doesn't already exist, then rewrite branchId to the real id.
  // ---------------------------------------------------------------------

  String normalizeBranchKey(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  static const List<String> branchTypes = ['Sales Point', 'Sales Branch', 'Warehouse'];

  String inferBranchType(String name) {
    final n = name.toLowerCase();
    if (n.contains('warehouse') || n.contains('store')) return 'Warehouse';
    return 'Sales Branch';
  }

  List<ExtractedBranch> extractBranches(List<SaleGroup> groups) {
    final byKey = <String, ExtractedBranch>{};
    for (final group in groups) {
      for (final row in group.rows) {
        final raw = row.get('branchId');
        if (raw.isEmpty) continue;
        final key = normalizeBranchKey(raw);
        final existing = byKey[key];
        if (existing == null) {
          byKey[key] = ExtractedBranch(
            key: key,
            rawNames: [raw],
            name: raw.trim(),
            type: inferBranchType(raw),
          );
        } else if (!existing.rawNames.contains(raw)) {
          byKey[key] = ExtractedBranch(
            key: existing.key,
            rawNames: [...existing.rawNames, raw],
            name: existing.name,
            type: existing.type,
          );
        }
      }
    }
    return byKey.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  ({Map<String, String> existingIdByKey, List<ExtractedBranch> missing}) splitExistingBranches({
    required List<ExtractedBranch> branches,
    required Datafeed datafeed,
  }) {
    BranchModel? findByName(String key) {
      for (final b in datafeed.branches) {
        if (normalizeBranchKey(b.branchname) == key) return b;
      }
      return null;
    }

    final existingIdByKey = <String, String>{};
    final missing = <ExtractedBranch>[];
    for (final b in branches) {
      final existing = findByName(b.key);
      if (existing != null) {
        existingIdByKey[b.key] = existing.id;
      } else {
        missing.add(b);
      }
    }
    return (existingIdByKey: existingIdByKey, missing: missing);
  }

  Future<Map<String, String>> ensureBranchesExist({
    required List<ExtractedBranch> branches,
    required Datafeed datafeed,
    required String companyId,
    required String companyEmail,
    String? staffName,
  }) async {
    await datafeed.fetchBranches();

    final split = splitExistingBranches(branches: branches, datafeed: datafeed);
    final idByKey = Map<String, String>.from(split.existingIdByKey);
    final toCreate = split.missing;

    if (toCreate.isEmpty) return idByKey;

    for (final b in toCreate) {
      final branch = BranchModel(
        id: '',
        branchname: b.name,
        branchtype: b.type,
        address: '',
        branchcontact: '',
        companyid: companyId,
        companyemail: companyEmail,
        staff: staffName ?? '',
        date: DateTime.now(),
        updatedat: DateTime.now(),
      );
      await datafeed.addOrUpdateBranch(branch);
    }

    await datafeed.fetchBranches();
    for (final b in toCreate) {
      for (final br in datafeed.branches) {
        if (normalizeBranchKey(br.branchname) == b.key) {
          idByKey[b.key] = br.id;
          break;
        }
      }
    }

    return idByKey;
  }

  List<SaleGroup> applyBranchIds(List<SaleGroup> groups, Map<String, String> idByKey) {
    return groups.map((group) {
      final newRows = group.rows.map((row) {
        final raw = row.get('branchId');
        if (raw.isEmpty) return row;
        final id = idByKey[normalizeBranchKey(raw)];
        if (id == null) return row;
        final cells = Map<String, String>.from(row.cells);
        cells['branchId'] = id;
        return RawSaleRow(cells);
      }).toList();
      return SaleGroup(group.receipt, newRows);
    }).toList();
  }

  // ---------------------------------------------------------------------
  // Payments
  // ---------------------------------------------------------------------

  String normalizePaymentMethod(String raw) {
    final cleaned = raw.trim().toLowerCase();
    return _paymentMethodAliases[cleaned] ?? (cleaned.isEmpty ? 'cash' : cleaned);
  }

  List<Map<String, dynamic>> parsePayments(
      String raw, {
        required double fallbackTotal,
        required String transMode,
      }) {
    if (transMode.toLowerCase().trim() == 'credit') return [];

    if (raw.trim().isEmpty) {
      return [
        {
          'amount': fallbackTotal,
          'accountName': 'cash',
          'accountNumber': 'cash',
          'status': true,
          'reference': 'cash',
          'method': 'cash',
        }
      ];
    }

    final payments = <Map<String, dynamic>>[];
    for (final entry in raw.split('|')) {
      if (entry.trim().isEmpty) continue;
      final parts = entry.split(':');
      final method = parts.isNotEmpty ? normalizePaymentMethod(parts[0]) : 'cash';
      final amount = parts.length > 1 ? (double.tryParse(parts[1].trim()) ?? 0) : 0.0;
      final accountName = parts.length > 2 ? parts[2].trim() : (method == 'cash' ? 'cash' : method);
      final accountNumber = parts.length > 3 ? parts[3].trim() : method;
      final reference = parts.length > 4 ? parts[4].trim() : method;

      payments.add({
        'amount': amount,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'status': true,
        'reference': reference,
        'method': method,
      });
    }

    if (payments.isEmpty) {
      payments.add({
        'amount': fallbackTotal,
        'accountName': 'cash',
        'accountNumber': 'cash',
        'status': true,
        'reference': 'cash',
        'method': 'cash',
      });
    }
    return payments;
  }

  // ---------------------------------------------------------------------
  // Item / customer lookups — preloaded once per company so buildSaleDoc's
  // lookups are in-memory map reads, not per-row Firestore queries.
  // ---------------------------------------------------------------------

  final Map<String, Map<String, dynamic>> _itemByBarcode = {};
  final Map<String, Map<String, dynamic>> _itemByName = {};
  final Set<String> _itemsPreloadedForCompany = {};
  final Map<String, Future<void>> _itemPreloadInFlight = {};

  Future<void> preloadItemsForCompany(String companyId) {
    if (_itemsPreloadedForCompany.contains(companyId)) return Future.value();
    return _itemPreloadInFlight.putIfAbsent(companyId, () async {
      try {
        final snap = await db.collection('itemsreg').where('companyid', isEqualTo: companyId).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final barcode = (data['barcode'] ?? '').toString().trim().toLowerCase();
          final name = (data['name'] ?? '').toString().trim().toLowerCase();
          if (barcode.isNotEmpty) _itemByBarcode['$companyId::$barcode'] = data;
          if (name.isNotEmpty) _itemByName['$companyId::$name'] = data;
        }
        _itemsPreloadedForCompany.add(companyId);
      } catch (_) {
        // Best-effort — items just won't resolve without the catalog.
      } finally {
        _itemPreloadInFlight.remove(companyId);
      }
    });
  }

  Map<String, dynamic>? lookupItem(String companyId, String barcode, String itemName) {
    final normalizedBarcode = barcode.trim().toLowerCase();
    final normalizedName = itemName.trim().toLowerCase();
    if (normalizedBarcode.isEmpty && normalizedName.isEmpty) return null;

    if (normalizedBarcode.isNotEmpty) {
      final byBarcode = _itemByBarcode['$companyId::$normalizedBarcode'];
      if (byBarcode != null) return byBarcode;
    }
    if (normalizedName.isNotEmpty) {
      return _itemByName['$companyId::$normalizedName'];
    }
    return null;
  }

  final Map<String, Map<String, dynamic>> _customerByPhone = {};
  final Set<String> _customersPreloadedForCompany = {};
  final Map<String, Future<void>> _customerPreloadInFlight = {};

  Future<void> preloadCustomersForCompany(String companyId) {
    if (_customersPreloadedForCompany.contains(companyId)) return Future.value();
    return _customerPreloadInFlight.putIfAbsent(companyId, () async {
      try {
        final snap = await db.collection('customers').where('companyid', isEqualTo: companyId).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final phone = (data['contact'] ?? '').toString().trim();
          if (phone.isNotEmpty) _customerByPhone['$companyId::$phone'] = data;
        }
        _customersPreloadedForCompany.add(companyId);
      } catch (_) {
        // Best-effort.
      } finally {
        _customerPreloadInFlight.remove(companyId);
      }
    });
  }

  Map<String, dynamic>? lookupCustomerByPhone(String companyId, String phone) {
    if (phone.isEmpty) return null;
    return _customerByPhone['$companyId::$phone'];
  }

  ModePricing resolveModePricing({
    required Map<String, dynamic> item,
    required String modeText,
    required String pricemode,
  }) {
    final modes = item['modes'];
    final wantedRaw = modeText.trim().isEmpty ? 'single' : modeText.trim().toLowerCase();

    if (modes is! Map || modes.isEmpty) {
      return ModePricing(modeQty: 1, unitPrice: 0, resolvedMode: modeText.isEmpty ? 'Single' : modeText);
    }

    Map<String, dynamic>? match;
    String resolvedKey = wantedRaw;

    if (modes[wantedRaw] is Map) {
      match = Map<String, dynamic>.from(modes[wantedRaw] as Map);
      resolvedKey = wantedRaw;
    } else {
      for (final entry in modes.entries) {
        final data = entry.value;
        if (data is! Map) continue;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final id = (data['id'] ?? entry.key).toString().toLowerCase();
        if (id == wantedRaw ||
            name == wantedRaw ||
            name.contains(wantedRaw) ||
            (wantedRaw.isNotEmpty && wantedRaw.contains(id))) {
          match = Map<String, dynamic>.from(data);
          resolvedKey = entry.key.toString();
          break;
        }
      }
    }

    if (match == null) {
      return ModePricing(modeQty: 1, unitPrice: 0, resolvedMode: modeText.isEmpty ? 'Single' : modeText);
    }

    final qty = double.tryParse(match['qty']?.toString() ?? '1') ?? 1;
    final bool wholesale = pricemode.toLowerCase().trim() == 'wholesale';

    double price = double.tryParse((wholesale ? match['wp'] : match['rp'])?.toString() ?? '') ?? 0;
    if (price <= 0) price = double.tryParse(match['sp']?.toString() ?? '') ?? 0;
    if (price <= 0) price = double.tryParse((wholesale ? match['rp'] : match['wp'])?.toString() ?? '') ?? 0;
    if (price <= 0) price = double.tryParse(match['cp']?.toString() ?? '') ?? 0;

    final resolvedName = (match['name'] ?? resolvedKey).toString();
    return ModePricing(modeQty: qty <= 0 ? 1 : qty, unitPrice: price, resolvedMode: resolvedName);
  }

  dynamic resolveBranch(Datafeed datafeed, String branchIdRaw, String defaultBranchId) {
    return datafeed.branches.firstWhere(
          (b) => b.id == branchIdRaw,
      orElse: () => datafeed.branches.firstWhere(
            (b) => b.id == defaultBranchId,
        orElse: () => throw 'Branch "$branchIdRaw" not found',
      ),
    );
  }

  Map<String, String> dateParts(String dateymd) {
    DateTime dt;
    try {
      if (dateymd.isEmpty) {
        dt = DateTime.now();
      } else if (dateymd.contains('/')) {
        final parts = dateymd.split('/');
        if (parts.length != 3) throw 'bad date';
        dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } else {
        dt = DateTime.parse(dateymd);
      }
    } catch (_) {
      dt = DateTime.now();
    }
    final day = DateFormat('EEEE').format(dt);
    final year = dt.year.toString();
    final month = '${dt.year}.${dt.month}';
    final weekNumber = ((dt.difference(DateTime(dt.year, 1, 1)).inDays) / 7).floor() + 1;
    final week = '${dt.year}.$weekNumber';
    final ymd = DateFormat('yyyy-MM-dd').format(dt);
    return {'dateymd': ymd, 'day': day, 'year': year, 'month': month, 'week': week};
  }

  // ---------------------------------------------------------------------
  // Document build — every problem (unresolvable item/price, bad branch,
  // missing credit customer, ...) surfaces as a thrown String here and is
  // caught per-group by the caller during the sync loop.
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> buildSaleDoc({
    required SaleGroup group,
    required Datafeed datafeed,
    required String companyId,
    required String companyName,
    required String staffPosition,
    required String staffName,
    required String staffEmail,
    required String defaultBranchId,
    required int timestamp,
    String? docIdOverride,
  }) async {
    final first = group.first;

    final transModes = group.rows.map((r) => r.get('transMode', 'cash').toLowerCase().trim()).toSet();
    if (transModes.length > 1) {
      throw 'Receipt "${group.receipt}" has conflicting transMode values: ${transModes.join(', ')}';
    }
    final transMode = transModes.first;
    if (transMode != 'cash' && transMode != 'credit') {
      throw 'transMode must be "cash" or "credit" (got "${first.get('transMode')}")';
    }

    final bool isSuperAdmin = datafeed.accesslevel.toLowerCase() == 'superadmin';
    final branchIdRaw = isSuperAdmin ? first.get('branchId', defaultBranchId) : defaultBranchId;
    final branch = resolveBranch(datafeed, branchIdRaw, defaultBranchId);
    final branchId = branch.id.isNotEmpty ? branch.id : defaultBranchId;
    final branchName = branch.branchname.isNotEmpty ? branch.branchname : defaultBranchId;
    final branchType = branch.branchtype ?? datafeed.branchtype;

    final itemsMap = <String, dynamic>{};
    double grandTotal = 0;
    double totalDiscount = 0;

    for (int i = 0; i < group.rows.length; i++) {
      final row = group.rows[i];

      final itemNameRaw = row.get('item');
      final barcode = row.get('barcode');
      final quantity = double.tryParse(row.get('quantity')) ?? 0;

      if (itemNameRaw.isEmpty && barcode.isEmpty) {
        throw 'Row ${i + 1} of transaction "${group.receipt}" needs an item name or a barcode';
      }
      if (quantity <= 0) {
        throw '"${itemNameRaw.isEmpty ? barcode : itemNameRaw}" has invalid quantity in transaction "${group.receipt}"';
      }

      final looked = lookupItem(companyId, barcode, itemNameRaw);
      final bool isUnregistered = looked == null;

      final itemName =
      itemNameRaw.isNotEmpty ? itemNameRaw : (isUnregistered ? barcode : (looked!['name'] ?? '').toString());
      final resolvedBarcode =
      barcode.isNotEmpty ? barcode : (isUnregistered ? '' : (looked!['barcode'] ?? '').toString());

      final pricemode = row.get('pricemode', 'retail');
      final modePricing = isUnregistered
          ? ModePricing(modeQty: 1, unitPrice: 0, resolvedMode: row.get('mode', 'Single'))
          : resolveModePricing(item: looked!, modeText: row.get('mode', 'Single'), pricemode: pricemode);
      final priceOverrideText = row.get('price');
      final price = priceOverrideText.isNotEmpty ? (double.tryParse(priceOverrideText) ?? 0) : modePricing.unitPrice;
      if (price <= 0) {
        throw '"$itemName" has no resolvable price in transaction "${group.receipt}"';
      }

      final itemid = row.get('itemid', isUnregistered ? '' : (looked!['id'] ?? looked['itemid'] ?? '').toString());
      final cp = row.get('cp', isUnregistered ? '0' : (looked!['cp'] ?? '0').toString());
      final pcategory = row.get('pcategory', isUnregistered ? '' : (looked!['pcategory'] ?? '').toString());
      final producttype =
      row.get('producttype', isUnregistered ? 'product' : (looked!['producttype'] ?? 'product').toString());
      final mode = modePricing.resolvedMode;
      final modeqty = modePricing.modeQty.toString();
      final boxpiece = row.get('boxpiece', modeqty);
      final itemDiscount = double.tryParse(row.get('itemDiscount', '0')) ?? 0;

      final grossTotal = price * quantity;
      final totalAmount = grossTotal - itemDiscount;
      final totalPieces = quantity * modePricing.modeQty;
      final cpVal = double.tryParse(cp) ?? 0;
      final profit = totalAmount - (totalPieces * cpVal);

      itemsMap['item_$i'] = {
        'itemid': itemid,
        'branchid': branchId,
        'branchname': branchName,
        'branchtype': branchType,
        'modeqty': modeqty,
        'item': itemName,
        'barcode': resolvedBarcode,
        'mode': mode,
        'quantity': quantity.toString(),
        'price': price.toString(),
        'profit': profit.toString(),
        'discount': itemDiscount.toString(),
        'cp': cp,
        'pcategory': pcategory,
        'producttype': producttype,
        'totalpieces': totalPieces.toString(),
        'totalamount': totalAmount.toString(),
        'grosstotalamount': grossTotal.toStringAsFixed(2),
        'pricemode': pricemode,
        'boxpiece': boxpiece,
        'stockCheckStatus': 'approved',
      };

      grandTotal += totalAmount;
      totalDiscount += itemDiscount;
    }

    if (itemsMap.isEmpty) throw 'Transaction "${group.receipt}" has no valid items';

    final amountPaidOverride = first.get('amountPaid');
    final payments = parsePayments(first.get('payments'), fallbackTotal: grandTotal, transMode: transMode);

    final double amountPaid = amountPaidOverride.isNotEmpty
        ? (double.tryParse(amountPaidOverride) ?? 0)
        : payments.fold<double>(0, (s, p) => s + (p['amount'] as double));

    final bool isCredit = transMode == 'credit';
    final String paymentStatus = isCredit ? 'pending' : (amountPaid >= grandTotal ? 'paid' : 'pending');
    final double change = (!isCredit && amountPaid > grandTotal) ? (amountPaid - grandTotal) : 0;

    String customerId;
    String customerName;
    String customerPhone;

    if (isCredit) {
      final customerIdOverride = first.get('customerId');
      final phone = first.get('customerPhone');
      Map<String, dynamic>? customerDoc;
      String resolvedCustomerId;

      if (customerIdOverride.isNotEmpty) {
        final snap = await db.collection('customers').doc(customerIdOverride).get();
        customerDoc = snap.data();
        resolvedCustomerId = customerIdOverride;
      } else {
        if (phone.isEmpty) {
          throw 'Credit transaction "${group.receipt}": requires customerId or customerPhone';
        }
        final found = lookupCustomerByPhone(companyId, phone);
        customerDoc = found;
        resolvedCustomerId = found != null ? (found['id'] ?? '').toString() : '${companyId.toLowerCase()}_$phone';
      }

      if (customerDoc == null) {
        final newCustomerName = first.get('customerName');
        if (newCustomerName.isEmpty) {
          throw 'Credit transaction "${group.receipt}": customer not found — customerName is required to create one';
        }
        final newCustomerPhone = phone.isNotEmpty ? phone : resolvedCustomerId;

        await db.collection('customers').doc(resolvedCustomerId).set({
          'id': resolvedCustomerId,
          'branchname': branchName,
          'branchid': branchId,
          'name': newCustomerName,
          'contact': newCustomerPhone,
          'customertype': 'credit',
          'creditlimit': null,
          'companyid': companyId,
          'staff': staffName,
          'date': Timestamp.now(),
          'updatedby': null,
          'updatedat': null,
          'deletedat': null,
          'companyname': companyName,
          'creditBalance': '0.0',
        });

        customerId = resolvedCustomerId;
        customerName = newCustomerName;
        customerPhone = newCustomerPhone;
      } else {
        customerId = resolvedCustomerId;
        customerName = (customerDoc['name'] ?? first.get('customerName')).toString();
        customerPhone = (customerDoc['contact'] ?? customerDoc['phone'] ?? phone).toString();
      }
    } else {
      final phone = first.get('customerPhone');
      if (phone.isEmpty) {
        customerId = 'cash';
        customerName = first.get('customerName').isNotEmpty ? first.get('customerName') : 'cash customer';
        customerPhone = 'cash';
      } else {
        customerName = first.get('customerName');
        customerPhone = phone;
        customerId = first.get('customerId', '${companyId.toLowerCase()}_$customerPhone');

        final existing = await db.collection('customers').doc(customerId).get();
        if (!existing.exists) {
          await db.collection('customers').doc(customerId).set({
            'id': customerId,
            'branchname': branchName,
            'branchid': branchId,
            'name': customerName,
            'contact': customerPhone,
            'customertype': 'cash',
            'creditlimit': null,
            'companyid': companyId,
            'staff': staffName,
            'date': Timestamp.now(),
            'updatedby': null,
            'updatedat': null,
            'deletedat': null,
            'companyname': companyName,
            'creditBalance': '0.0',
          });
        }
      }
    }

    final parts = dateParts(first.get('dateymd'));
    final docId = docIdOverride ?? '${companyId}_${staffPosition}_$timestamp';
    final receiptNumber = '$staffPosition$timestamp';
    final now = Timestamp.now();

    final paymentsMapped = payments
        .map((p) => {
      'amount': p['amount'],
      'accountName': p['accountName'],
      'accountNumber': p['accountNumber'],
      'status': p['status'],
      'reference': p['reference'],
      'method': p['method'],
    })
        .toList();

    return <String, dynamic>{
      'id': docId,
      'companyId': companyId,
      'companyname': companyName,
      'branchId': branchId,
      'branchName': branchName,
      'branchType': branchType,
      'pricingtype': branchType,
      'staffPosition': staffPosition,
      'amountPaid': amountPaid,
      'approvedby': staffName,
      'change': change,
      'createdAt': now,
      'createdBy': staffName,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'dateymd': parts['dateymd'],
      'day': parts['day'],
      'discount': totalDiscount,
      'isreturned': false,
      'itemCount': itemsMap.length,
      'items': itemsMap,
      'month': parts['month'],
      'paymentStatus': paymentStatus,
      'payments': paymentsMapped,
      'printed': !isCredit,
      'printedat': now,
      'printedby': staffName,
      'receiptNumber': receiptNumber,
      'receiptat': now,
      'receiptby': staffName,
      'receiptbyemail': staffEmail,
      'reciepted': true,
      'staffemail': staffEmail,
      'stockCheckStatus': 'approved',
      'stockCheckedAt': now,
      'timestamp': timestamp,
      'totalamount': grandTotal,
      'transMode': transMode,
      'week': parts['week'],
      'year': parts['year'],
    };
  }

  // =======================================================================
  // External POS API sync
  //
  // Pulls sales rows from apiSalesUrl without requiring a sync_status field.
  // Existing local synced-id records prevent duplicate processing.
  // Transactions use deterministic Firestore ids, so retrying a failed
  // callback is safe and does not create duplicate sale documents.
  //
  // The callback receives exactly {"ids":[...]}.
  // Local synced-id records are written only after the callback succeeds,
  // allowing a failed callback to be retried on the next sync.
  //
  // Dedicated collections, kept separate from anything else in the app:
  //   apiSales           — the sale documents created from POS API rows
  //   apiSalesSyncState  — one doc per company: {lastId, updatedAt}
  //   apiSalesSyncedIds  — one doc per API row id, used purely for dedupe
  // =======================================================================

  static const String apiSalesUrl = 'https://queenlatifahenterprise.com/pos/firebase/sales/';
  static const String apiCallbackUrl = 'https://queenlatifahenterprise.com/pos/firebase/trans_callback/';

  static const String salesCollection = 'sales';
  static const String syncStateCollection = 'apiSalesSyncState';
  static const String syncedIdsCollection = 'apiSalesSyncedIds';


  String _apiRecordDocId(String companyId, String id) => '${companyId}_$id';

  Future<Set<String>> _existingApiRecordDocIds(String companyId, List<String> ids) async {
    final existing = <String>{};
    const chunkSize = 30; // Firestore whereIn cap
    for (int i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, (i + chunkSize).clamp(0, ids.length));
      final docIds = chunk.map((id) => _apiRecordDocId(companyId, id)).toList();
      final snap = await db.collection(syncedIdsCollection).where(FieldPath.documentId, whereIn: docIds).get();
      for (final doc in snap.docs) {
        existing.add(doc.id);
      }
    }
    return existing;
  }

  String _cell(Map<String, dynamic> row, String key) => (row[key] ?? '').toString().trim();

  /// A kept (`transtype == "sales"`) row's `transmode` reads like
  /// "cash sales" / "credit sales" / "Sales Momo" — only "credit" makes
  /// it a credit sale.
  bool _isCreditTransmode(String mode) => mode.toLowerCase().contains('credit');

  /// Groups the raw JSON rows for one `tid` into the same [SaleGroup]
  /// shape [buildSaleDoc] already knows how to consume. Field names here
  /// are taken directly from the API's own response — no CSV-header
  /// guessing.
  SaleGroup _apiRowsToSaleGroup(
      String tid,
      List<Map<String, dynamic>> rows,
      ) {
    if (rows.isEmpty) {
      throw 'Transaction "$tid" has no rows';
    }

    final first = rows.first;

    final transmodeRaw = _cell(first, 'transmode');
    final isCredit = _isCreditTransmode(transmodeRaw);

    final transMode = isCredit ? 'credit' : 'cash';

    // IMPORTANT:
    // `paid` from the API is a PAYMENT METHOD, not an amount.
    final paymentMethod =
    normalizePaymentMethod(_cell(first, 'paid'));

    double groupTotal = 0;

    for (final row in rows) {
      final quantity = double.tryParse(_cell(row, 'quantity')) ?? 0;

      final sellingPrice = double.tryParse(_cell(row, 'selling_price')) ?? 0;

      final discount =
          double.tryParse(_cell(row, 'discount')) ?? 0;

      groupTotal += (sellingPrice * quantity) - discount;
    }

    bool firstRow = true;

    final saleRows = rows.map((row) {
      final branchName = _cell(row, 'branchname').isNotEmpty
          ? _cell(row, 'branchname')
          : _cell(row, 'salebranch');

      final pricing = _cell(row, 'pricing');

      final productType = _cell(row, 'product_type');

      final payment = (!isCredit && firstRow)
          ? '$paymentMethod:${groupTotal.toStringAsFixed(2)}'
          : '';

      firstRow = false;

      return RawSaleRow({
        // Original API values
        'apiId': _cell(row, 'id'),
        'tid': _cell(row, 'tid'),
        'sid': _cell(row, 'sid'),

        // Sale information
        'receipt': tid,
        'transMode': transMode,

        // Item
        'item': sanitizeCell(_cell(row, 'item')),
        'barcode': sanitizeCell(_cell(row, 'barcode')),
        'itemid': '',

        // Quantity / pricing
        'quantity': _cell(row, 'quantity'),
        'price': _cell(row, 'selling_price'),
        'cp': _cell(row, 'cost_price'),
        'itemDiscount': _cell(row, 'discount').isEmpty
            ? '0'
            : _cell(row, 'discount'),

        // Product information
        'pcategory':
        sanitizeCell(_cell(row, 'product_category')),

        'producttype': productType.isEmpty
            ? 'product'
            : productType,

        // Pricing mode
        'mode': 'Single',
        'modeqty': '1',
        'pricemode': pricing.isEmpty
            ? 'retail'
            : pricing,

        'boxpiece': '1',

        // Branch.
        // This is initially the NAME.
        // It will be replaced with the actual branch ID
        // before buildSaleDoc/upload.
        'branchId': sanitizeCell(branchName),
        'branchName': sanitizeCell(branchName),

        // Customer.
        // These will be resolved to the real customer ID
        // before upload.
        'customerName':
        sanitizeCell(_cell(row, 'tname')),

        'customerPhone':
        sanitizeCell(_cell(row, 'cphone')),

        'customerId': '',

        // Payment
        'payments': payment,
        'amountPaid': '',

        // Date/time
        'dateymd': _cell(row, 'date'),
        'time': _cell(row, 'time'),
      });
    }).toList();

    return SaleGroup(tid, saleRows);
  }

  /// One full fetch -> dedupe -> upload -> callback cycle against the
  /// external POS API for [companyId].
  Future<ApiSyncResult> syncFromExternalApi({
    required Datafeed datafeed,
    required String companyId,
    required String companyName,
    required String staffPosition,
    required String staffName,
    required String staffEmail,
    required String defaultBranchId,
  }) async {
    try {
      print('[POS Sync] Starting sync for company: $companyId');

      final response = await http.get(Uri.parse(apiSalesUrl));
      print('[POS Sync] GET $apiSalesUrl -> ${response.statusCode}');

      if (response.statusCode != 200) {
        throw 'Sales API request failed (${response.statusCode}): ${response.body}';
      }

      late final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (e) {
        throw 'Sales API returned invalid JSON: $e';
      }

      if (decoded is Map && decoded['success'] == false) {
        throw (decoded['message'] ?? 'Sales API returned an error').toString();
      }

      final List<dynamic> rawRows =
          (decoded is Map ? decoded['data'] : decoded) ?? [];

      print('[POS Sync] Fetched ${rawRows.length} raw row(s)');

      // IMPORTANT:
      // There is intentionally NO sync_status check here.
      // The local Firestore synced-id records are the source of truth for
      // whether this app has already processed an API row.
      final candidates = <Map<String, dynamic>>[];

      for (final raw in rawRows) {
        if (raw is! Map) continue;

        final row = Map<String, dynamic>.from(raw);

        // ONLY sales are imported.
        // Deliberately do NOT validate companyid.
        // Deliberately do NOT inspect sync_status.
        final transtype = _cell(row, 'transtype').toLowerCase();
        if (transtype != 'sales') continue;

        // The POS API supplies id/tid for normal sales rows.
        // Use id as a safe fallback transaction key if tid is absent so
        // the row is not rejected by an unnecessary validation rule.
        final id = _cell(row, 'id');
        if (id.isEmpty) continue;

        final tid = _cell(row, 'tid').isEmpty ? id : _cell(row, 'tid');

        final normalizedRow = Map<String, dynamic>.from(row);
        normalizedRow['tid'] = tid;
        candidates.add(normalizedRow);
      }

      if (candidates.isEmpty) {
        return ApiSyncResult(
          fetched: rawRows.length,
          uploaded: 0,
          skipped: 0,
          failed: 0,
          uploadedIds: const [],
        );
      }

      final candidateIds =
      candidates.map((r) => _cell(r, 'id')).where((id) => id.isNotEmpty).toList();

      final alreadyRecorded =
      await _existingApiRecordDocIds(companyId, candidateIds);

      final groupedRows = <String, List<Map<String, dynamic>>>{};
      final idsByTid = <String, List<String>>{};
      int skipped = 0;

      for (final row in candidates) {
        final id = _cell(row, 'id');
        final tid = _cell(row, 'tid');

        if (alreadyRecorded.contains(_apiRecordDocId(companyId, id))) {
          skipped++;
          continue;
        }

        groupedRows.putIfAbsent(tid, () => <Map<String, dynamic>>[]).add(row);
        idsByTid.putIfAbsent(tid, () => <String>[]).add(id);
      }

      if (groupedRows.isEmpty) {
        return ApiSyncResult(
          fetched: rawRows.length,
          uploaded: 0,
          skipped: skipped,
          failed: 0,
          uploadedIds: const [],
        );
      }

      await Future.wait([
        preloadItemsForCompany(companyId),
        preloadCustomersForCompany(companyId),
      ]);

      final tids = groupedRows.keys.toList();

      final saleGroups = tids
          .map((tid) => _apiRowsToSaleGroup(tid, groupedRows[tid]!))
          .toList();

      final extractedBranches = extractBranches(saleGroups);

      final branchIdByKey = await ensureBranchesExist(
        branches: extractedBranches,
        datafeed: datafeed,
        companyId: companyId,
        companyEmail: datafeed.companyemail,
        staffName: staffName,
      );

      final resolvedGroups = applyBranchIds(saleGroups, branchIdByKey);

      final successfulIds = <String>[];
      final errors = <String>[];
      int failed = 0;

      final int baseTimestamp = DateTime.now().millisecondsSinceEpoch;

      WriteBatch batch = db.batch();
      int inBatch = 0;
      final pendingGroups = <Map<String, dynamic>>[];

      Future<void> commitBatch() async {
        if (inBatch == 0) return;

        try {
          await batch.commit();

          for (final pending in pendingGroups) {
            final ids = pending['ids'] as List<String>;
            successfulIds.addAll(ids);
          }

          print(
            '[POS Sync] Firestore batch committed: '
                '${pendingGroups.length} transaction(s)',
          );
        } catch (e, st) {
          print('[POS Sync] Firestore batch FAILED: $e');
          print(st);

          for (final pending in pendingGroups) {
            final tid = pending['tid'].toString();
            final ids = pending['ids'] as List<String>;

            failed += ids.length;
            errors.add('Transaction "$tid" Firestore batch failed: $e');
          }
        }

        batch = db.batch();
        inBatch = 0;
        pendingGroups.clear();
      }

      for (int i = 0; i < resolvedGroups.length; i++) {
        final tid = tids[i];
        final rowIds = idsByTid[tid] ?? const <String>[];

        try {
          // Deterministic document ID makes this operation idempotent.
          final saleDocId = '${companyId}_api_$tid';

          final saleDoc = await buildSaleDoc(
            group: resolvedGroups[i],
            datafeed: datafeed,
            companyId: companyId,
            companyName: companyName,
            staffPosition: staffPosition,
            staffName: staffName,
            staffEmail: staffEmail,
            defaultBranchId: defaultBranchId,
            timestamp: baseTimestamp + i,
            docIdOverride: saleDocId,
          );

          batch.set(
            db.collection(salesCollection).doc(saleDoc['id'] as String),
            saleDoc,
          );

          // DO NOT write apiSalesSyncedIds here.
          // The API callback must succeed first. This allows a later sync
          // to retry the callback if the POS callback endpoint is down.
          pendingGroups.add({
            'tid': tid,
            'ids': List<String>.from(rowIds),
          });

          inBatch++;

          if (inBatch >= writeBatchSize) {
            await commitBatch();
          }
        } catch (e, st) {
          print('[POS Sync] Transaction "$tid" failed: $e');
          print(st);

          failed += rowIds.length;
          errors.add('Transaction "$tid": $e');
        }
      }

      await commitBatch();

      // Send exactly:
      // {"ids":["123","124",...]}
      //
      // No companyid is added because the callback endpoint expects an ids
      // array. Local synced-id records are only created after the callback
      // confirms success.
      if (successfulIds.isNotEmpty) {
        final callbackBody = jsonEncode({
          'ids': successfulIds,
        });

        print('[POS Sync] Callback JSON: $callbackBody');

        try {
          final callbackResponse = await http.post(
            Uri.parse(apiCallbackUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: callbackBody,
          );

          print(
            '[POS Sync] Callback POST -> '
                '${callbackResponse.statusCode}: ${callbackResponse.body}',
          );

          bool callbackAccepted = callbackResponse.statusCode >= 200 &&
              callbackResponse.statusCode < 300;

          if (callbackAccepted && callbackResponse.body.trim().isNotEmpty) {
            try {
              final callbackDecoded = jsonDecode(callbackResponse.body);

              if (callbackDecoded is Map &&
                  callbackDecoded['success'] == false) {
                callbackAccepted = false;
                errors.add(
                  'Callback rejected: '
                      '${callbackDecoded['message'] ?? callbackResponse.body}',
                );
              }
            } catch (_) {
              // A non-JSON 2xx response is still treated as accepted.
            }
          }

          if (callbackAccepted) {
            // Only now mark the API ids as locally synced.
            WriteBatch syncedBatch = db.batch();
            int syncedWrites = 0;

            for (final id in successfulIds) {
              syncedBatch.set(
                db.collection(syncedIdsCollection).doc(
                  _apiRecordDocId(companyId, id),
                ),
                {
                  'id': id,
                  'companyId': companyId,
                  'syncedAt': Timestamp.now(),
                },
              );

              syncedWrites++;

              if (syncedWrites >= writeBatchSize) {
                await syncedBatch.commit();
                syncedBatch = db.batch();
                syncedWrites = 0;
              }
            }

            if (syncedWrites > 0) {
              await syncedBatch.commit();
            }

            print(
              '[POS Sync] Callback accepted. '
                  '${successfulIds.length} id(s) marked synced locally.',
            );
          } else {
            errors.add(
              'Callback failed (${callbackResponse.statusCode}): '
                  '${callbackResponse.body}',
            );

            print(
              '[POS Sync] Callback failed. '
                  'IDs remain unsynced locally so the next run can retry.',
            );
          }
        } catch (e, st) {
          print('[POS Sync] Callback request FAILED: $e');
          print(st);

          errors.add('Callback request failed: $e');

          // Deliberately do not write apiSalesSyncedIds.
          // The next run will retry the callback.
        }
      }

      final result = ApiSyncResult(
        fetched: rawRows.length,
        uploaded: successfulIds.length,
        skipped: skipped,
        failed: failed,
        uploadedIds: successfulIds,
        errors: errors,
      );

      print('[POS Sync] Result: $result');
      return result;
    } catch (e, st) {
      print('[POS Sync] UNCAUGHT ERROR: $e');
      print(st);
      rethrow;
    }
  }

}

