
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/branch.dart';
import '../models/itemregmodel.dart';
import 'Datafeed.dart';

class SalesProvider extends  Datafeed {

  final FirebaseFirestore db = FirebaseFirestore.instance;

  bool loading = false;

  Map<String, dynamic>? itemModes;
  Map<String, dynamic>? currentModeData;
  String? selectedPriceMode;
  double? vatRate;
  bool vatEnabled = false;
  String? companyVatKey;
  String? _saleDate;

  String get saleDate =>
      _saleDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

  void setSaleDate(DateTime? date) {
    _saleDate = DateFormat('yyyy-MM-dd').format(
      date ?? DateTime.now(),
    );
    notifyListeners();
  }

  void clearSaleDate() {
    _saleDate = null;
    notifyListeners();
  }
  Map<String, List<Map<String, dynamic>>> _customerCarts = {};
  String _currentCartId = 'cart_1';
  int _cartCounter = 1;
  SalesProvider() {
    _customerCarts[_currentCartId] = [];
  }

  bool isServiceOnlySale(List items) {
    if (items.isEmpty) return false;
    return items.every(
          (item) => (item['producttype']?.toString().toLowerCase().trim() ?? '') == 'service',
    );
  }
  List<Map<String, dynamic>> get salesItems {
    return _customerCarts[_currentCartId] ?? [];
  }

  Map<String, List<Map<String, dynamic>>> get customerCarts =>  _customerCarts;

  String get currentCartId => _currentCartId;

  int get cartCounter => _cartCounter;

  void addToCart(Map<String, dynamic> item) {
    _customerCarts.putIfAbsent(_currentCartId, () => []);
    _customerCarts[_currentCartId]!.add(item);
    notifyListeners();
  }

  void removeFromSalesPreview(int index) {
    if (!_customerCarts.containsKey(_currentCartId)) return;

    final currentList = List<Map<String, dynamic>>.from(
      _customerCarts[_currentCartId]!,
    );

    if (index < 0 || index >= currentList.length) return;

    final targetItem = currentList[index];

    final isBundle =
        targetItem['pcategory']?.toString() == 'bundle' &&
            targetItem['producttype']?.toString() == 'bundle';

    if (isBundle) {
      final bundleName =
          targetItem['bundleName']?.toString() ?? '';

      final branchId =
          targetItem['branchid']?.toString() ?? '';

      currentList.removeWhere((item) {
        final sameBundle =
            item['pcategory']?.toString() == 'bundle' &&
                item['producttype']?.toString() == 'bundle' &&
                item['bundleName']?.toString() == bundleName &&
                item['branchid']?.toString() == branchId;

        return sameBundle;
      });
    }

    else {
      currentList.removeAt(index);
    }

    _customerCarts[_currentCartId] = currentList;

    notifyListeners();
  }
  void createNewCart() {
    _cartCounter++;
    _currentCartId = 'cart_$_cartCounter';
    _customerCarts[_currentCartId] = [];
    notifyListeners();
  }

  void clearCurrentCart() {
    _customerCarts[_currentCartId]?.clear();
    notifyListeners();
  }



  void switchCart(String cartId) {
    if (_customerCarts.containsKey(cartId)) {
      _currentCartId = cartId;
      notifyListeners();
    }
  }

  bool deleteCart(String cartId) {
    // Prevent deleting the last cart
    if (_customerCarts.length == 1) return false;

    if (!_customerCarts.containsKey(cartId)) return false; // extra safety

    _customerCarts.remove(cartId);

    // Switch current cart if the deleted one was active
    if (_currentCartId == cartId) {
      _currentCartId = _customerCarts.keys.first;
    }

    notifyListeners();
    return true;
  }

  void addItemToCurrentCart(Map<String, dynamic> item) {
    _customerCarts[_currentCartId] ??= [];
    _customerCarts[_currentCartId]!.add(item);
    notifyListeners();
  }

  void removeItemFromCurrentCart(int index) {
    final cart = _customerCarts[_currentCartId];
    if (cart == null || index >= cart.length) return;
    cart.removeAt(index);
    notifyListeners();
  }
  void addToSalesPreview(Map<String, dynamic> salesItem) {
    final items = List<Map<String, dynamic>>.from(salesItems);
    items.add(salesItem);

    _customerCarts[_currentCartId] = items;

    notifyListeners();
  }


  // Load VAT from shared preferences
  Future<void> loadVatFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final vatRateValue = prefs.getDouble('vatRate');
    final vatEnabledValue = prefs.getBool('vatEnabled');
    vatRate = vatRateValue;
    vatEnabled = vatEnabledValue ?? false;
    notifyListeners();
  }
  void showMessage(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void showMessageDialog(BuildContext context, String msg, Color color) {
    final messenger = ScaffoldMessenger.maybeOf(
      Navigator.of(context, rootNavigator: true).context,
    );

    messenger?.showSnackBar(
      SnackBar(
        content: Text(msg,style: TextStyle(color: Colors.white),),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }




  Future<bool> ensureSaleApproved(BuildContext context, String saleId,{
    bool skipStockCheck = false,
  }) async {
    if (skipStockCheck) {
      try {
        await db.collection('sales').doc(saleId).update({
          'stockCheckStatus': 'approved',
          'stockCheckedAt': Timestamp.now(),
        });
      } catch (e) {
        debugPrint('Failed to set approved status for service-only sale $saleId: $e');
      }
      return true;
    }
    const maxAttempts = 5;

    try {
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final doc = await db.collection('sales').doc(saleId).get(
          const GetOptions(source: Source.server),
        );

        if (!doc.exists) return false;

        final data = doc.data() ?? <String, dynamic>{};
        final status = data['stockCheckStatus']?.toString().trim().toLowerCase();

        // Approved — proceed
        if (status == 'approved') return true;

        // Explicitly rejected by Cloud Function
        if (status == 'rejected') {
          try {
            await db.collection('sales').doc(saleId).delete();
          } catch (e) {
            debugPrint('Failed to delete rejected sale $saleId: $e');
          }
          showMessage(
            context,
            'Sale rejected: insufficient stock. Please adjust cart.',
            Colors.red,
          );
          return false;
        }

        // null = Function not run yet → wait and retry
        if (status == null) {
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }

        // Anything else is unexpected — delete and stop
        debugPrint('Unexpected stockCheckStatus: "$status" for sale $saleId');
        try {
          await db.collection('sales').doc(saleId).delete();
        } catch (e) {
          debugPrint('Failed to delete unexpected-status sale $saleId: $e');
        }
        showMessage(
          context,
          'Unexpected stock check result. Please try again.',
          Colors.red,
        );
        return false;
      }

      // Timed out — delete the orphaned doc so it does not linger
      try {
        await db.collection('sales').doc(saleId).delete();
      } catch (e) {
        debugPrint('Failed to delete timed-out sale $saleId: $e');
      }
      showMessage(
        context,
        'Stock check timed out. Please try again.',
        Colors.orange,
      );
      debugPrint('Stock check still pending after $maxAttempts attempts for $saleId');
      return false;

    } catch (e) {
      debugPrint('ensureSaleApproved error: $e');
      showMessage(
        context,
        'Unable to verify stock approval. Please check connection.',
        Colors.red,
      );
      return false;
    }
  }

  Future<bool> validateCartStockOnSave( BuildContext context, List salesItems, Datafeed datafeed,) async {

    try {
      final requestedByItem = <String, double>{};
      final itemNameById = <String, String>{};
      final branchByItem = <String, String>{};

      /// BUILD REQUEST MAP


      for (final item in salesItems) {
        try {
          final isBundle =    item['producttype']?.toString().toLowerCase() == 'bundle';
          final isService =
              item['producttype']?.toString().toLowerCase().trim() == 'service';
          if (isService) continue;
          /// BUNDLE
          if (isBundle) {
            final bundleQty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

            final bundleItems = (item['items'] as List?) ?? [];

            for (final sub in bundleItems) {
              if (sub is! Map<String, dynamic>) continue;

              final itemId = sub['itemid']?.toString() ?? '';
              if (itemId.isEmpty) continue;

              /// QTY ×  totalpieces
              final unitPieces =   double.tryParse(sub['totalpieces']?.toString() ?? '0') ?? 0;

              final requestedPieces = unitPieces * bundleQty;

              if (requestedPieces <= 0) continue;

              ///  ACCUMULATE
              requestedByItem[itemId] =   (requestedByItem[itemId] ?? 0) + requestedPieces;

              itemNameById[itemId] =    sub['item']?.toString() ?? 'item';

              branchByItem[itemId] =    item['branchid']?.toString() ?? datafeed.branchid;

            }
          }
          else {
            final isService =
                item['producttype']?.toString().toLowerCase().trim() == 'service';
            if (isService) continue;
            final itemId = item['itemid']?.toString() ?? '';
            if (itemId.isEmpty) continue;

            final requestedPieces =
                double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;

            if (requestedPieces <= 0) continue;

            requestedByItem[itemId] =
                (requestedByItem[itemId] ?? 0) + requestedPieces;

            itemNameById[itemId] =
                item['item']?.toString() ?? 'item';

            branchByItem[itemId] =
                item['branchid']?.toString() ?? datafeed.branchid;
          }
        } catch (e) {
          debugPrint('Cart parsing error: $e');
        }
      }
      if (requestedByItem.isEmpty) return true;

      /// FETCH ITEMS FROM FIRESTORE
      final futures = requestedByItem.keys.map((id) {
        return db.collection('itemsreg').doc(id).get(const GetOptions(source: Source.server));
      });

      final docs = await Future.wait(futures);
      if (!context.mounted) return false;
      /// VALIDATE STOCK
      for (final doc in docs) {

        try {

          if (!doc.exists) {
            debugPrint('Item document missing: ${doc.id}');
            continue;
          }

          final data = doc.data() ?? <String, dynamic>{};

          final branchId =   branchByItem[doc.id] ?? datafeed.branchid;

          final branchBalance =    data['branchbalance'] as Map<String, dynamic>? ?? {};

          final branchData =     resolveBranchBalance(branchBalance, branchId, datafeed);

          final availableNetPieces =    parseNetPieces(branchData);

          final requestedPieces =      requestedByItem[doc.id] ?? 0;

          final boxQty =
              double.tryParse(
                data['boxqty']?.toString() ??
                    data['boxQty']?.toString() ??
                    data['modes']?['carton']?['qty']?.toString() ??
                    data['modes']?['single']?['qty']?.toString() ??
                    '1',
              ) ??
                  1.0;

          final availableBoxes =   boxQty > 0 ? (availableNetPieces / boxQty) : null;

          final requestedBoxes =    boxQty > 0 ? (requestedPieces / boxQty) : null;

          /// INSUFFICIENT STOCK
          if (requestedBoxes != null &&  availableBoxes != null &&  requestedBoxes > availableBoxes) {
            if (!context.mounted) return false;
            showMessage( context,
              'Insufficient stock for ${itemNameById[doc.id] ?? 'item'}: '
                  '${availableBoxes.toStringAsFixed(2)} boxes '
                  '(${availableNetPieces.toStringAsFixed(0)} pieces) available',
              Colors.red,
            );

            return false;
          }

        } catch (e) {

          debugPrint('Stock validation error for ${doc.id}: $e');
          if (!context.mounted) return false;
          showMessage( context,
            'Error checking stock for ${itemNameById[doc.id] ?? 'item'}',
            Colors.red,
          );

          return false;
        }
      }

      return true;

    } catch (e) {

      debugPrint('validateCartStockOnSave error: $e');

      showMessage(  context,'Unable to verify stock. Please check connection.', Colors.red, );

      return false;
    }
  }

  double parseNetPieces(Map<String, dynamic>? branchData) {
    try {

      if (branchData == null) return 0;

      final raw =
          branchData['netpieces'] ??
              branchData['netPieces'] ??
              branchData['net_piece'];

      if (raw == null) return 0;

      if (raw is num) {
        return raw.toDouble();
      }

      if (raw is String) {
        return double.tryParse(raw.trim()) ?? 0;
      }

      debugPrint('Unknown netpieces type: ${raw.runtimeType}');
      return 0;

    } catch (e, stack) {

      debugPrint('parseNetPieces error: $e');
      debugPrintStack(stackTrace: stack);

      return 0;
    }
  }

  Map<String, dynamic> resolveBranchBalance( Map<String, dynamic>? balances, String branchId,  Datafeed datafeed, ) {
    try {

      if (balances == null || balances.isEmpty) {
        return {};
      }

      /// DIRECT BRANCH LOOKUP
      final rawDirect = balances[branchId];

      if (rawDirect is Map) {
        final direct = Map<String, dynamic>.from(rawDirect);
        if (direct.isNotEmpty) return direct;
      }

      /// SALES POINT FALLBACK
      if (datafeed.isSalesPoint && datafeed.branchid.isNotEmpty) {

        final rawFallback = balances[datafeed.branchid];

        if (rawFallback is Map) {
          final fallback = Map<String, dynamic>.from(rawFallback);
          if (fallback.isNotEmpty) return fallback;
        }
      }

      return {};

    } catch (e, stack) {

      debugPrint('resolveBranchBalance error: $e');
      debugPrintStack(stackTrace: stack);

      return {};
    }
  }
  bool isPreviewItemInsufficient( Map<String, dynamic> item, Datafeed datafeed,  ) {
    try {
      final isService =
          item['producttype']?.toString().toLowerCase().trim() == 'service';
      if (isService) return false;
      final itemId = item['itemid']?.toString() ?? '';

      if (itemId.isEmpty) return false;

      final requestedPieces =
          double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;

      if (requestedPieces <= 0) return false;

      final branchId =
          item['branchid']?.toString() ?? datafeed.activeBranchId;

      /// FIND ITEM MODEL
      final itemModel = datafeed.items.firstWhere(
            (i) => i.id == itemId,
        orElse: () => ItemModel.fromMap({'id': itemId}),
      );

      /// RESOLVE BRANCH BALANCE
      final branchBalance = resolveBranchBalance(
        itemModel.branchbalance,
        branchId,
        datafeed,
      );

      /// AVAILABLE STOCK
      final availableNetPieces = parseNetPieces(branchBalance);

      return requestedPieces > availableNetPieces;

    } catch (e, stack) {

      debugPrint('isPreviewItemInsufficient error: $e');
      debugPrintStack(stackTrace: stack);

      /// If error occurs, allow preview instead of blocking POS
      return false;
    }
  }
  bool ensureSalesWarehouseSelected( BuildContext context, Datafeed datafeed,  ItemModel? selectedItem, { bool requireItemSelection = false,  }) {
    try {

      if (!datafeed.isSalesPoint) return true;
      if ((selectedItem?.producttype ?? '').toLowerCase().trim() == 'service') {
        return true;
      }
      /// ITEM NOT SELECTED
      if (selectedItem == null) {

        if (requireItemSelection) {
          showMessage(context, 'Select an item first', Colors.orange);
          return false;
        }

        return true;
      }

      /// GET AVAILABLE WAREHOUSES
      final available =
      availableSalesWarehousesForItem(datafeed, selectedItem);

      if (available.isEmpty) {

        showMessage(
          context,
          'No warehouse balance for this item.',
          Colors.orange,
        );

        return false;
      }

      /// NO WAREHOUSE SELECTED
      if (datafeed.salesWarehouseId == null ||
          datafeed.salesWarehouseId!.isEmpty) {

        showMessage(
          context,
          'Select a warehouse to sell from.',
          Colors.orange,
        );

        return false;
      }

      /// INVALID WAREHOUSE
      if (!available.contains(datafeed.salesWarehouseId)) {

        showMessage(
          context,
          'Selected warehouse has no balance for this item.',
          Colors.orange,
        );

        return false;
      }

      return true;

    } catch (e, stack) {

      debugPrint('ensureSalesWarehouseSelected error: $e');
      debugPrintStack(stackTrace: stack);

      showMessage(
        context,
        'Unable to verify warehouse selection.',
        Colors.red,
      );

      return false;
    }
  }

  double calculateTaxableTotal() {
    double total = 0;

    try {

      for (var item in salesItems) {

        try {

          final value = double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0;

          total += value;

        } catch (e) {
          debugPrint('Item tax calculation error: $e');
        }
      }
      if (vatEnabled && vatRate != null) {
        total += total * vatRate!;
      }
      return total;
    } catch (e, stack) {

      debugPrint('calculateTaxableTotal error: $e');
      debugPrintStack(stackTrace: stack);

      return 0;
    }

  }
  double calculateVatFromInclusive(double total) {
    try {
      if (!vatEnabled || vatRate == null) return 0;
      if (total <= 0) return 0;

      final rate = vatRate!;

      if (rate <= 0) return 0;

      return rate  * total;

    } catch (e) {
     print(e);
      return 0;
    }
  }
  double calculateDiscountTotal() {
    double total = 0;

    try {

      for (final item in salesItems) {

        try {

          final discount =
              double.tryParse(item['discount']?.toString().trim() ?? '0') ?? 0;

          total += discount;

        } catch (e) {
          debugPrint('Discount parse error: $e');
        }
      }

    } catch (e, stack) {

      debugPrint('calculateDiscountTotal error: $e');
      debugPrintStack(stackTrace: stack);

      return 0;
    }

    return total;
  }
  double calculateGrossTotal() {
    double total = 0;

    try {

      for (final item in salesItems) {

        try {

          final grosstotalamount =
              double.tryParse(item['grosstotalamount']?.toString().trim() ?? '0') ?? 0;

          total += grosstotalamount;

        } catch (e) {
          debugPrint('grosstotal parse error: $e');
        }
      }

    } catch (e, stack) {

      debugPrint('calculateDiscountTotal error: $e');
      debugPrintStack(stackTrace: stack);

      return 0;
    }

    return total;
  }
   double amountPayable(){
  double total = 0;
  for (var item in salesItems) {
  total += double.tryParse(item['totalamount'] ?? '0') ?? 0;
  }
  if (vatEnabled && vatRate != null) {
  total += total * vatRate!;
  }
  return total;
}

   List<String> availableSalesWarehousesForItem( Datafeed datafeed, ItemModel item, ) {
    try {

      final allowedIds = (datafeed.salesWarehouseIds).toSet();
       print(allowedIds);
      final balanceKeys =
      (item.branchbalance ?? {})
          .keys
          .map((e) => e.toString())
          .toSet();

      if (allowedIds.isEmpty) {

        debugPrint(
          'Empty salesWarehouseIds - no warehouses assigned to this staff member',
        );

        return [];
      }

      final companyPrefix = datafeed.companyid.toLowerCase();

      final normalizedAllowedIds = <String>{};

      for (final id in allowedIds) {

        try {

          final safeId = id.toString();

          normalizedAllowedIds.add(safeId);

          if (!safeId.startsWith(companyPrefix)) {
            normalizedAllowedIds.add('$companyPrefix$safeId');
          }

          if (safeId.startsWith(companyPrefix)) {
            normalizedAllowedIds.add(
              safeId.substring(companyPrefix.length),
            );
          }

        } catch (e) {
          debugPrint('Warehouse ID normalization error: $e');
        }
      }

      final available =   normalizedAllowedIds.intersection(balanceKeys).toList();

      available.sort();

      return available;

    } catch (e, stack) {

      debugPrint('availableSalesWarehousesForItem error: $e');
      debugPrintStack(stackTrace: stack);

      return [];
    }
  }


   Map<String, String> calculateTotals({required String quantityText,required String priceText, required String discountText,  required Map<String, dynamic>? modeData, }) {
    if (modeData == null || quantityText.isEmpty) {
      return {
        'pieces': '0',
        'amount': '0',
      };
    }

    try {
      final userQuantity = double.tryParse(quantityText) ?? 0;

      final modeQty =   double.tryParse((modeData['qty'] ?? '1').toString()) ?? 1;

      final discountAmount =  double.tryParse(discountText.trim().isEmpty ? '0' : discountText.trim()) ?? 0;

      final price = double.tryParse(priceText) ?? 0;

      final totalPieces = userQuantity * modeQty;

      final subTotal = price * userQuantity;

      final totalAmount =  (subTotal - discountAmount).clamp(0, double.infinity);

      return {
        'pieces': totalPieces.toStringAsFixed(2),
        'amount': totalAmount.toStringAsFixed(2),
      };
    } catch (e, stackTrace) {
      debugPrint('Error calculating totals: $e');
      debugPrint(stackTrace.toString());

      return {
        'pieces': '0',
        'amount': '0',
      };
    }
  }


  List<ItemModel> searchItems(String query, List<ItemModel> items) {
    try {
      final q = query.toLowerCase();

      return items.where((item) {
        final name = (item.name ?? '').toLowerCase();
        final barcode = item.barcode ?? '';

        return name.contains(q) || barcode.contains(query);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Error searching items: $e');
      debugPrint(stackTrace.toString());
      return [];
    }
  }

  List<String> buildSalesModes(Map<String, dynamic> itemModes) {
    try {
      final modes = itemModes.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        return data['name']?.toString() ?? e.key;
      }).toList();

      /// put Single first
      modes.sort((a, b) {
        if (a.toLowerCase() == 'single') return -1;
        if (b.toLowerCase() == 'single') return 1;
        return 0;
      });

      return modes;
    } catch (e, stackTrace) {
      debugPrint('Error building sales modes: $e');
      debugPrint(stackTrace.toString());
      return [];
    }
  }
  Map<String, dynamic> resolvePricing(ItemModel item, Datafeed datafeed) {
    try {
      Map<String, dynamic> effectivePricing = {};

      final branchPrices = item.branchprices;
      final modes = item.modes;
      final branchId = datafeed.activeBranchId;

      if (branchPrices != null &&
          branchPrices.containsKey(branchId) &&
          branchPrices[branchId]['pricing'] != null) {

        effectivePricing = Map<String, dynamic>.from(
          branchPrices[branchId]['pricing'],
        );

      } else if (modes != null) {

        for (var mode in modes) {
          effectivePricing[mode.name] = {
            'id': mode.id,
            'name': mode.name,
            'qty': mode.qty,
            'cp': mode.cp,
            'rp': mode.rp,
            'wp': mode.wp,
            'sp': mode.sp,
          };
        }
      }

      return effectivePricing;

    } catch (e, stackTrace) {
      debugPrint('Error resolving pricing: $e');
      debugPrint(stackTrace.toString());
      return {};
    }
  }

  void ensureSalesWarehouse(Datafeed datafeed, ItemModel item) {
    try {
      if (!datafeed.isSalesPoint) return;

      final available = availableSalesWarehousesForItem(datafeed,item);

      if (available.isNotEmpty &&
          !available.contains(datafeed.salesWarehouseId)) {

        final selectedId = available.first;

        String selectedName = '';

        final index = datafeed.salesWarehouseIds.indexOf(selectedId);

        if (index >= 0 && index < datafeed.salesWarehouseNames.length) {
          selectedName = datafeed.salesWarehouseNames[index];
        }

        if (selectedName.isEmpty) {
          final branch = datafeed.branches.firstWhere(
                (b) => b.id == selectedId,
            orElse: () => BranchModel(),
          );
          selectedName = branch.branchname;
        }

        datafeed.setSalesWarehouse(selectedId, selectedName);
      }
    } catch (e, stackTrace) {
      debugPrint('Error ensuring sales warehouse: $e');
      debugPrint(stackTrace.toString());
    }
  }
  Future<String?> getReceiptNumber(String saleId) async {
    try {
      final doc = await db.collection('sales').doc(saleId).get(const GetOptions(source: Source.server));

      if (!doc.exists) {
        debugPrint('Sale document not found: $saleId');
        return null;
      }

      final data = doc.data();
      return data?['receiptNumber']?.toString();

    } catch (e) {
      debugPrint('getReceiptNumber error: $e');
      return null;
    }
  }

/*
  Future<bool> validateCartStockOnSaves(String branchId,) async {

    final requestedByItem = <String, double>{};
    final itemNameById = <String, String>{};
    final branchByItem = <String, String>{};

    for (final item in salesItems) {
      final isService =
          item['producttype']?.toString().toLowerCase().trim() == 'service';
      if (isService) continue;
      final itemId = item['itemid']?.toString() ?? '';
      if (itemId.isEmpty) continue;
      final requestedPieces =
          double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
      if (requestedPieces <= 0) continue;
      requestedByItem[itemId] =
          (requestedByItem[itemId] ?? 0) + requestedPieces;
      itemNameById[itemId] = item['item']?.toString() ?? 'item';
      branchByItem[itemId] = item['branchid']?.toString() ?? branchId;
    }
    if (requestedByItem.isEmpty) return true;
    try {
      final futures = requestedByItem.keys.map(
            (id) => FirebaseFirestore.instance
            .collection('itemsreg')
            .doc(id)
            .get(const GetOptions(source: Source.server)),
      );
      final docs = await Future.wait(futures);
      for (final doc in docs) {
        if (!doc.exists) continue;
        final data = doc.data() ?? <String, dynamic>{};
        //final branchId = branchByItem[doc.id] ?? branchId;
        final branchBalance =
            data['branchbalance'] as Map<String, dynamic>? ?? {};
        final branchData =
            branchBalance[branchId] as Map<String, dynamic>? ?? {};
        final availableNetPieces = _parseNetPieces(branchData);
        final requestedPieces = requestedByItem[doc.id] ?? 0;
        final boxQty =
            double.tryParse(
              data['boxqty']?.toString() ??
                  data['boxQty']?.toString() ??
                  data['modes']?['carton']?['qty']?.toString() ??
                  data['modes']?['single']?['qty']?.toString() ??
                  '1',
            ) ??
                1.0;
        final availableBoxes = boxQty > 0
            ? (availableNetPieces / boxQty)
            : null;
        final requestedBoxes = boxQty > 0 ? (requestedPieces / boxQty) : null;
        if (requestedBoxes != null &&
            availableBoxes != null &&
            requestedBoxes > availableBoxes) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
*/
  Future<bool> validateCartStockOnSaves(String branchId,) async {

    final requestedByItem = <String, double>{};
    final itemNameById = <String, String>{};
    final branchByItem = <String, String>{};

    for (final item in salesItems) {
      final isService =
          item['producttype']?.toString().toLowerCase().trim() == 'service';
      if (isService) continue;
      final itemId = item['itemid']?.toString() ?? '';
      if (itemId.isEmpty) continue;
      final requestedPieces =
          double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
      if (requestedPieces <= 0) continue;
      requestedByItem[itemId] =
          (requestedByItem[itemId] ?? 0) + requestedPieces;
      itemNameById[itemId] = item['item']?.toString() ?? 'item';
      branchByItem[itemId] = item['branchid']?.toString() ?? branchId;
    }
    if (requestedByItem.isEmpty) return true;
    try {
      final futures = requestedByItem.keys.map(
            (id) => FirebaseFirestore.instance
            .collection('itemsreg')
            .doc(id)
            .get(const GetOptions(source: Source.server)),
      );
      final docs = await Future.wait(futures);
      for (final doc in docs) {
        if (!doc.exists) continue;
        final data = doc.data() ?? <String, dynamic>{};
        final itemBranchId = branchByItem[doc.id] ?? branchId;
        final branchBalance =
            data['branchbalance'] as Map<String, dynamic>? ?? {};
        final branchData =
            branchBalance[itemBranchId] as Map<String, dynamic>? ?? {};
        final availableNetPieces = _parseNetPieces(branchData);
        final requestedPieces = requestedByItem[doc.id] ?? 0;
        final boxQty =
            double.tryParse(
              data['boxqty']?.toString() ??
                  data['boxQty']?.toString() ??
                  data['modes']?['carton']?['qty']?.toString() ??
                  data['modes']?['single']?['qty']?.toString() ??
                  '1',
            ) ??
                1.0;
        final availableBoxes = boxQty > 0
            ? (availableNetPieces / boxQty)
            : null;
        final requestedBoxes = boxQty > 0 ? (requestedPieces / boxQty) : null;
        if (requestedBoxes != null &&
            availableBoxes != null &&
            requestedBoxes > availableBoxes) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
  double _parseNetPieces(Map<String, dynamic> branchData) {
    final raw =
        branchData['netpieces'] ??
            branchData['netPieces'] ??
            branchData['net_piece'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }

}


