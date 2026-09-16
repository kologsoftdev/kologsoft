

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../paymentwidgets/BarcodeScannerScreen.dart';
import '../providers/SalesProvider.dart';

class BundlePage extends StatefulWidget {
  final String? docId;
  final List<Map<String, dynamic>>? item;

  const BundlePage({super.key, this.docId, this.item});

  @override
  State<BundlePage> createState() => _BundlePageState();
}

class _BundlePageState extends State<BundlePage> {

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _bundlenameController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _totalPiecesController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();

  bool _isSaving = false;
  String? _selectedSalesMode;
  List<String> _salesMode = [];
  String? _selectedPriceMode;
  List<dynamic> _priceMode = [];
  Map<String, dynamic>? _itemModes;
  Map<String, dynamic>? _currentModeData;

  bool _isPriceManuallyEntered = false;
  bool _isTotalManuallyEntered = false;

  bool _showSuggestions = false;
  ItemModel? _selectedItem;
  String _searchQuery = '';
  String? _productType;
  String? _productCategory;
  String branchid = '';
  String branchtype = '';
  bool isActive = true;


  List<Map<String, dynamic>> _salesItems = [];

  bool get _isEditMode => widget.docId != null;
  final Map<int, TextEditingController> _rowQtyControllers = {};
  final Map<int, TextEditingController> _rowPriceControllers = {};


  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';

    Future.microtask(() async {
      if (!mounted) return;
      context.read<Datafeed>().fetchItems();
      final value = Provider.of<Datafeed>(context, listen: false);
      context.read<Datafeed>().fetchproductcategory();
      await value.getdata();

      if (!mounted) return;

      branchid = value.branchid;
      _barcodeController.addListener(_onBarcodeChanged);
      _quantityController.addListener(_onQuantityChanged);
      _discountController.addListener(_calculateTotals);

      branchtype = value.branchtype;
      _priceMode = value.pricingmode.map((e) => e.toString()).toList();
      if (_selectedPriceMode == null && _priceMode.isNotEmpty) {
        _selectedPriceMode = _priceMode.first;
      }

      if (widget.item != null && widget.item!.isNotEmpty) {
        final d = widget.item!;
        _bundlenameController.text = d.first['bundleName'] ?? '';
        _productType = d.first['producttype'] ?? '';
        _productCategory = d.first['pcategory'] ?? '';
        isActive = d.first['isActive'] ?? true;

        // Deep-copy each item so inline edits don't mutate the original list
        final loadedItems = d.map((e) => Map<String, dynamic>.from(e)).toList();

        setState(() {
          _salesItems = loadedItems;
          _rebuildRowControllers();
        });
      }
    });
  }

  void _rebuildRowControllers() {

    for (final c in _rowQtyControllers.values) {
      c.dispose();
    }
    for (final c in _rowPriceControllers.values) {
      c.dispose();
    }
    _rowQtyControllers.clear();
    _rowPriceControllers.clear();

    for (int i = 0; i < _salesItems.length; i++) {
      final item = _salesItems[i];
      _rowQtyControllers[i] =
          TextEditingController(text: item['quantity']?.toString() ?? '1');
      _rowPriceControllers[i] =
          TextEditingController(text: item['price']?.toString() ?? '0');

      // Listen so totals recalc live
      final idx = i;
      _rowQtyControllers[i]!.addListener(() {
        if (mounted) _recalcRow(idx);
      });
      _rowPriceControllers[i]!.addListener((){
          if (mounted) {
            _recalcRow(idx);
          }
      });
    }
  }

 void _recalcRow(int idx) {
   if (!mounted || idx >= _salesItems.length) return;
    if (idx >= _salesItems.length) return;
    final item = _salesItems[idx];
    final qty =
        double.tryParse(_rowQtyControllers[idx]?.text.trim() ?? '1') ?? 1.0;
    final price =
        double.tryParse(_rowPriceControllers[idx]?.text.trim() ?? '0') ?? 0.0;
    final modeQty =
        double.tryParse((item['modeqty'] ?? '1').toString()) ?? 1.0;
    final pieces = (qty * modeQty).round();
    final total = qty * price;

    setState(() {
      _salesItems[idx] = {
        ..._salesItems[idx],
        'quantity': qty.toString(),
        'price': price.toStringAsFixed(2),
        'totalpieces': pieces.toString(),
        'totalamount': total.toStringAsFixed(2),
      };
    });
  }

  double _currentQuantityValue() {
    final parsed = double.tryParse(_quantityController.text.trim());
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  void _setQuantityValue(double value) {
    final normalized = value <= 0 ? 1 : value;
    final text = normalized % 1 == 0
        ? normalized.toStringAsFixed(0)
        : normalized.toString();
    _quantityController.text = text;
    _quantityController.selection =
        TextSelection.collapsed(offset: text.length);
  }

  void _incrementQuantity() => _setQuantityValue(_currentQuantityValue() + 1);

  void _decrementQuantity() {
    final next = _currentQuantityValue() - 1;
    _setQuantityValue(next <= 0 ? 1 : next);
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _quantityController.removeListener(_onQuantityChanged);
    _discountController.removeListener(_calculateTotals);
    for (final c in _rowQtyControllers.values) {
      c.dispose();
    }
    for (final c in _rowPriceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
      );
      if (result != null && result is String) {
        setState(() => _barcodeController.text = result);
        _formKey.currentState?.validate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error opening scanner: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onBarcodeChanged() {
    setState(() {
      _searchQuery = _barcodeController.text.trim();
      _showSuggestions = _searchQuery.isNotEmpty;
    });
  }

  void _onQuantityChanged() => _calculateTotals();

 void _calculateTotals() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final modeQty =
        double.tryParse((_currentModeData?['qty'] ?? '1').toString()) ?? 1.0;
    final pieces = (qty * modeQty).round();
    _totalPiecesController.text = pieces.toString();

    if (_isTotalManuallyEntered) {
      final manualTotal =
          double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
      final discount =
          double.tryParse(_discountController.text.trim().isEmpty
              ? '0'
              : _discountController.text.trim()) ??
              0.0;
      final computedPrice = qty > 0 ? ((manualTotal + discount) / qty) : 0.0;
      _priceController.text = computedPrice.toStringAsFixed(2);
      _totalAmountController.text = manualTotal.toStringAsFixed(2);
      setState(() {});
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final result = salesProvider.calculateTotals(
      quantityText: _quantityController.text,
      priceText: price.toString(),
      discountText: _discountController.text,
      modeData: _currentModeData,
    );
    _totalAmountController.text = result['amount'] ?? '0';
    setState(() {});
  }

 void _updatePrice() {
    if (_selectedItem == null ||
        _selectedSalesMode == null ||
        _itemModes == null ||
        _itemModes!.isEmpty) {
      if (!_isTotalManuallyEntered && !_isPriceManuallyEntered) {
        _priceController.text = '0';
      }
      _currentModeData = null;
      _calculateTotals();
      return;
    }

    Map<String, dynamic>? selectedModeData;
    for (final entry in _itemModes!.entries) {
      if (entry.key.toLowerCase().trim() ==
          _selectedSalesMode!.toLowerCase().trim()) {
        selectedModeData = Map<String, dynamic>.from(entry.value);
        break;
      }
    }

    if (selectedModeData == null) {
      if (!_isTotalManuallyEntered && !_isPriceManuallyEntered) {
        _priceController.text = '0';
      }
      _currentModeData = null;
      _calculateTotals();
      return;
    }

    _currentModeData = selectedModeData;

    if (!_isPriceManuallyEntered && !_isTotalManuallyEntered) {
      String pickRetail(Map<String, dynamic> data) =>
          data['rp']?.toString() ??
              data['sp']?.toString() ??
              data['cp']?.toString() ??
              '0';

      _priceController.text = _selectedPriceMode == 'Wholesale'
          ? selectedModeData['wp']?.toString() ?? '0'
          : pickRetail(selectedModeData);
    }
    _calculateTotals();
  }

  void _addToSalesPreview() {
    final isMobile = MediaQuery.of(context).size.width < 600;
  //  if (!isMobile && !_formKey.currentState!.validate()) return;
    if (!_formKey.currentState!.validate()) return;
    if (_bundlenameController.text.trim().isEmpty) {
      _snack('Please enter bundle name before adding items.', Colors.red);
      return;
    }
    if (_selectedItem == null) {
      _snack('Select an item before adding to preview', Colors.red);
      return;
    }

    _updatePrice();

    final salesItem = {
      'bundleName': _bundlenameController.text.trim(),
      'itemid': _selectedItem?.id ?? '',
      'item': _selectedItem?.name ?? _itemController.text,
      'barcode': _selectedItem?.barcode ?? _barcodeController.text,
      'mode': _selectedSalesMode ?? '',
      'modeqty':
      double.tryParse((_currentModeData?['qty'] ?? '1').toString()) ?? 1.0,
      'quantity': _quantityController.text,
      'price': _priceController.text,
      'discount': _discountController.text.trim().isEmpty
          ? '0'
          : _discountController.text.trim(),
      'cp': _selectedItem?.cp ?? '',
      'totalpieces': _totalPiecesController.text,
      'totalamount': _totalAmountController.text,
      'pricemode': _selectedPriceMode ?? 'retail',
      'pcategory': _productCategory,
      'producttype': _productType,
    };

    setState(() {
      _salesItems.add(salesItem);
      _rebuildRowControllers();
    });

    _resetItemEntry();
    _snack('Item added to preview', Colors.green);
  }


  void _resetItemEntry() {
    _itemController.clear();
    _barcodeController.clear();
    _quantityController.text = '1';
    _priceController.clear();
    _discountController.clear();
    _totalPiecesController.clear();
    _totalAmountController.clear();
    _showSuggestions = false;
    _isPriceManuallyEntered = false;
    _isTotalManuallyEntered = false;
    setState(() {
      _selectedItem = null;
      _selectedSalesMode = null;
      _selectedPriceMode =
      _priceMode.isNotEmpty ? _priceMode.first.toString() : null;
      _currentModeData = null;
      _itemModes = null;
      _salesMode = [];
    });
  }

  void _resetForm() {
    _bundlenameController.clear();
    _resetItemEntry();
    setState(() {
      _salesItems = [];
      _rebuildRowControllers();
    });
  }


  Future<void> _updateNameOnly() async {
    final newName = _bundlenameController.text.trim();
    if (newName.isEmpty) {
      _snack('Bundle name cannot be empty', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final datafeed = Provider.of<Datafeed>(context, listen: false);

      final duplicateQuery = await datafeed.db
          .collection('bundle')
          .where('name', isEqualTo: newName)
          .where('companyid', isEqualTo: datafeed.companyid)
          .limit(2)
          .get();

      final hasDuplicate =
      duplicateQuery.docs.any((doc) => doc.id != widget.docId);

      if (hasDuplicate) {
        _snack('A bundle with this name already exists', Colors.red);
        return;
      }

      // keep every item's embedded bundleName in sync
      final updatedItems = _salesItems
          .map((e) => {...e, 'bundleName': newName})
          .toList();

      await datafeed.db.collection('bundle').doc(widget.docId!).update({
        'name': newName,
        'barcode': newName,
        'items': updatedItems,
      });

      if (!mounted) return;

      setState(() {
        _salesItems = updatedItems;
        _rebuildRowControllers();
      });

      final idx =
      datafeed.bundleview.indexWhere((b) => b['id'] == widget.docId);
      if (idx != -1) {
        datafeed.bundleview[idx]['name'] = newName;
        datafeed.bundleview[idx]['barcode'] = newName;
        datafeed.bundleview[idx]['items'] = updatedItems;
        datafeed.notifyListeners();
      }

      _snack('Bundle name updated successfully', Colors.green);
    } catch (e) {
      _snack('Failed to update name: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBundle() async {
    if (_isSaving) return;
    _formKey.currentState?.reset();
    setState(() => _isSaving = true);

    try {
      final bundleName = _bundlenameController.text.trim();
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      final items = _salesItems
          .map((e) => {...e, 'bundleName': bundleName})
          .toList();

      if (bundleName.isEmpty) {
        _snack('Enter bundle name before saving', Colors.red);
        return;
      }
      final duplicateQuery = await datafeed.db
          .collection('bundle')
          .where('name', isEqualTo: bundleName)
          .where('companyid', isEqualTo: datafeed.companyid)
          .limit(2)
          .get();

      final hasDuplicate = duplicateQuery.docs.any(
            (doc) => doc.id != widget.docId, );

      if (hasDuplicate) {
        _snack('A bundle with this name already exists', Colors.red);
        return;
      }
      if (items.isEmpty) {
        _snack('Add at least one item to preview before saving', Colors.red);
        return;
      }

      String sanitize(String input) => input.trim().toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');

      final docId = _isEditMode
          ? widget.docId!
          : '${sanitize(datafeed.companyid)}_${datafeed.staffPosition}_${sanitize(bundleName)}';

      final barcode = bundleName;
      final now = DateTime.now();

      final day = DateFormat('EEEE').format(now);

      final year = now.year.toString();

      final month = '${now.year}.${now.month}';

      final weekNumber =
          ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

      final week = '${now.year}.$weekNumber';
      final bundleDoc = {
        'name': bundleName,
        'id': docId,
        'isActive': isActive,
        'companyid': datafeed.companyid,
        'branchid': datafeed.branchid,
        'barcode': barcode,
        'producttype':'bundle',
        'pcategory': 'bundle',
        'isHamper': true,
        'day': day,
        'week': week,
        'month': month,
        'year': year,
        'company': datafeed.company,
        'createdat': FieldValue.serverTimestamp(),
        'staff': datafeed.staff,
        'items': items,

      };

      await datafeed.db.collection('bundle').doc(docId).set(bundleDoc);

      if (!mounted) return;

      _snack(
        _isEditMode ? 'Bundle updated successfully' : 'Bundle saved successfully',
        Colors.green,
      );

      if (_isEditMode) {
        final datafeed = context.read<Datafeed>();
        final originalTimestamp = widget.item?.isNotEmpty == true
            ? widget.item!.first['createdat']
            : null;

        final localDoc = Map<String, dynamic>.from(bundleDoc);
        localDoc['createdat'] = originalTimestamp;

        final idx = datafeed.bundleview.indexWhere((b) => b['id'] == widget.docId);
        if (idx != -1) datafeed.bundleview[idx] = localDoc;

        datafeed.notifyListeners();
        Navigator.pop(context);
      } else {
        final datafeed = context.read<Datafeed>();
        final localDoc = Map<String, dynamic>.from(bundleDoc);
        localDoc['createdat'] = null;

        datafeed.bundleview.add(localDoc);
        datafeed.notifyListeners();
        _resetForm();
        setState(() => _salesItems = []);
      }

    } catch (e) {
      _snack('Failed to save bundle: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg,style: TextStyle(color: Colors.white),),
          backgroundColor: color,
          duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildSalesPreview(double itemWidth) {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, _) {
        final items = _salesItems;

        // Grand totals
        final grandTotal = items.fold(0.0, (s, e) {
          return s +  (double.tryParse(e['totalamount']?.toString() ?? '0') ?? 0.0);
        });

        return SizedBox(
          width: itemWidth,
          child: Container(
            color: const Color(0xFF182232),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode ? 'Edit Bundle Items' : 'Preview Items',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_isEditMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'EDIT MODE',
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Divider(color: Colors.white24),

                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No items yet. Add items using the form.',
                          style: TextStyle(color: Colors.white38)),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowColor: MaterialStateProperty.all(
                          const Color(0xFF1B263B)),
                      headingRowColor: MaterialStateProperty.all(
                          const Color(0xFF0D1B2A)),
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(
                            label: Text('Item',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Mode',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Qty',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Price',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Pieces',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Total',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Action',
                                style: TextStyle(color: Colors.white))),
                      ],
                      rows: items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;

                        // Ensure controllers exist (safety)
                        _rowQtyControllers.putIfAbsent(
                          idx,
                              () => TextEditingController(
                              text: item['quantity']?.toString() ?? '1'),
                        );
                        _rowPriceControllers.putIfAbsent(
                          idx,
                              () => TextEditingController(
                              text: item['price']?.toString() ?? '0'),
                        );

                        return DataRow(cells: [
                          // ── Item name
                          DataCell(SizedBox(
                            width: 130,
                            child: Text(
                              item['item']?.toString() ?? '',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),

                          // ── Mode (read-only label)
                          DataCell(Text(
                            item['mode']?.toString() ?? '',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          )),

                          // ── Qty (inline editable)
                          DataCell(SizedBox(
                            width: 70,
                            child: TextFormField(
                              controller: _rowQtyControllers[idx],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*$')),
                              ],
                              decoration: _inlineCellDecoration(),
                            ),
                          )),

                          // ── Price (inline editable)
                          DataCell(SizedBox(
                            width: 80,
                            child: TextFormField(
                              controller: _rowPriceControllers[idx],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*$')),
                              ],
                              decoration: _inlineCellDecoration(),
                            ),
                          )),

                          // ── Total pieces (computed, read-only)
                          DataCell(Text(
                            item['totalpieces']?.toString() ?? '0',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          )),

                          // ── Total amount (computed, read-only)
                          DataCell(Text(
                            item['totalamount']?.toString() ?? '0',
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          )),

                          // ── Delete
                          DataCell(IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent, size: 18),
                            onPressed: () {
                              setState(() {
                                _salesItems.removeAt(idx);
                                _rebuildRowControllers();
                              });
                            },
                            tooltip: 'Remove item',
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),

                // ── Grand total row
                if (items.isNotEmpty) ...[
                  const Divider(color: Colors.white24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'Grand Total: GHS ${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Save / Update button
                Center(
                  child: SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        _isEditMode ? Colors.orange : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSaving ? null : _saveBundle,
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        _isEditMode ? 'Update Bundle' : 'Save Bundle',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inlineCellDecoration() => InputDecoration(
    isDense: true,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    filled: true,
    fillColor: const Color(0xFF22304A),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Colors.blue),
    ),
  );

  void _selectItem(ItemModel? item, Datafeed datafeed) {
    if (item == null) return;
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    setState(() {
      _selectedItem = item;

      if (datafeed.isSalesPoint) {
        final available =
        salesProvider.availableSalesWarehousesForItem(datafeed, item);
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
      }

      _itemController.text = item.name;
      _barcodeController.text = item.barcode;

      Map<String, dynamic> effectivePricing = {};
      final branchPrices = item.branchprices;
      final modes = item.modes;
      final String branchId = datafeed.activeBranchId;

      if (branchPrices != null &&
          branchPrices.containsKey(branchId) &&
          branchPrices[branchId]['pricing'] != null) {
        effectivePricing =
        Map<String, dynamic>.from(branchPrices[branchId]['pricing']);
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

      _itemModes = effectivePricing;
      _isPriceManuallyEntered = false;
      _isTotalManuallyEntered = false;

      if (_itemModes != null && _itemModes!.isNotEmpty) {
        _salesMode = _itemModes!.entries.map((e) {
          final data = e.value as Map<String, dynamic>;
          return data['name']?.toString() ?? e.key;
        }).toList();

        if (datafeed.isSalesPoint) {
          _salesMode.sort((a, b) {
            if (a.toLowerCase() == 'cartoon') return -1;
            if (b.toLowerCase() == 'cartoon') return 1;
            return 0;
          });
        } else {
          _salesMode.sort((a, b) {
            if (a.toLowerCase() == 'single') return -1;
            if (b.toLowerCase() == 'single') return 1;
            return 0;
          });
        }

        _selectedSalesMode = _salesMode.first;
        _updatePrice();
      } else {
        _salesMode = const ['single'];
        _selectedSalesMode = null;
        _currentModeData = null;
      }

      _showSuggestions = false;
    });
  }

   @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: Text(
              _isEditMode
                  ? 'Edit Bundle — ${value.branch.toString().toUpperCase()}'
                  : 'Bundle Transaction — ${value.branch.toString().toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFF1B263B),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
                child: LayoutBuilder(builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 900;
                  final isMobile = constraints.maxWidth < 600;
                  final double colW = isSmall
                      ? constraints.maxWidth
                      : (constraints.maxWidth / 2) - 10;

                  final form = _buildForm(colW, value);
                  final preview = _buildSalesPreview(colW);

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      if (isMobile) ...[
                        form,
                        const SizedBox(height: 16),
                        preview,
                      ] else
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [form, preview],
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm(double width, Datafeed value) {
    return SizedBox(
      width: width,
      child: Container(
        color: const Color(0xFF182232),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                const Text(
                  'Register Bundle',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),

                // Active toggle
                Row(
                  children: [
                    const Text('Active',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Switch(
                      value: isActive,
                      onChanged: (v) => setState(() => isActive = v),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _bundlenameController,
                    cursorColor: Colors.white,
                    enabled: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Bundle Name',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue)),
                      fillColor: Color(0xFF22304A),
                      filled: true,
                    ),
                    validator: (v) =>
                    v == null || v.isEmpty ? 'Bundle name required' : null,
                    onChanged: (_) => setState(() {}),
                  ),


                  if (_isEditMode) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.drive_file_rename_outline,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Update Name Only',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        onPressed: _isSaving ? null : _updateNameOnly,
                      ),
                    ),
                  ],


                  const SizedBox(height: 8),

                  // ── Barcode + scanner
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration('Barcode / Search Item'),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Barcode required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22304A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: Colors.white70),
                          onPressed: _scanBarcode,
                          tooltip: 'Scan Barcode/QR Code',
                        ),
                      ),
                    ],
                  ),

                  // Suggestions dropdown
                  if (_showSuggestions)
                    value.loading
                        ? const Center(
                        child: CircularProgressIndicator(
                            color: Colors.blue, strokeWidth: 2))
                        : _buildSuggestions(value),

                  const SizedBox(height: 8),

                  //Item (read-only display)
                  TextFormField(
                    controller: _itemController,
                    enabled: false,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Item'),
                    validator: (v) =>
                    v == null || v.isEmpty ? 'Item required' : null,
                  ),
                  const SizedBox(height: 8),

                  // ── Sales mode
                  DropdownButtonFormField<String>(
                    value: _selectedSalesMode,
                    dropdownColor: const Color(0xFF22304A),
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Sales Mode'),
                    items: _salesMode.isEmpty
                        ? null
                        : _salesMode
                        .map((t) => DropdownMenuItem(
                        value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedSalesMode = v;
                      _isPriceManuallyEntered = false;
                      _isTotalManuallyEntered = false;
                      _updatePrice();
                    }),
                    validator: (v) =>
                    v == null ? 'Please select sales mode' : null,
                  ),
                  const SizedBox(height: 8),

                  // ── Price
                  TextFormField(
                    controller: _priceController,
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Price'),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*$')),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      final a = double.tryParse(v);
                      if (a == null || a < 1) {
                        return 'Amount must be greater than zero';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {
                      _isPriceManuallyEntered = true;
                      _isTotalManuallyEntered = false;
                      _calculateTotals();
                    }),
                  ),
                  const SizedBox(height: 8),

                  // ── Quantity with +/- buttons
                  Row(
                    children: [
                      _qtyButton(Icons.remove, _decrementQuantity),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          textAlign: TextAlign.center,
                          cursorColor: Colors.white,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                          keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^(0(\.\d*)?|[1-9]\d*(\.\d*)?)?$')),
                          ],
                          decoration: _fieldDecoration('Quantity'),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Enter quantity';
                            }
                            final qty = double.tryParse(v);
                            if (qty == null || qty <= 0) {
                              return 'Quantity must be greater than zero';
                            }
                            if (!RegExp(r'^(0|[1-9]\d*)(\.\d+)?$')
                                .hasMatch(v)) {
                              return 'Use decimals without leading zeros';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      _qtyButton(Icons.add, _incrementQuantity),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Total pieces + total amount
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _totalPiecesController,
                          readOnly: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration('Total Pieces'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _totalAmountController,
                          cursorColor: Colors.white,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration('Total Amount'),
                          onChanged: (_) => setState(() {
                            _isTotalManuallyEntered = true;
                            _isPriceManuallyEntered = false;
                            _calculateTotals();
                          }),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),
                  const Divider(color: Colors.white24),

                  // ── Action buttons
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 160,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _addToSalesPreview,
                          child: Text(
                            _isEditMode
                                ? 'Add to Bundle'
                                : 'Add to Preview',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isEditMode
                              ? _resetItemEntry  // in edit mode only reset the item entry, not the whole form
                              : _resetForm,
                          child: const Text('Reset',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(Datafeed value) {
    final query = _searchQuery.toLowerCase();
    final filtered = query.isEmpty
        ? value.items
        : value.items.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.barcode.toLowerCase().contains(query) ||
          item.company.toLowerCase().contains(query) ||
          item.pcategory.toLowerCase().contains(query);
    }).take(10).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: const Color(0xFF22304A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          final branchBalance =
              item.branchbalance?[value.activeBranchId] as Map<String, dynamic>? ??
                  {};
          final double netPieces =
              (branchBalance['netpieces'] as num?)?.toDouble() ?? 0.0;
          return ListTile(
            dense: true,
            leading: const Icon(Icons.inventory_2, color: Colors.blue, size: 20),
            title: Text(item.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            subtitle: Text(
              'Barcode: ${item.barcode} | CP: GHS ${item.cp} | Pieces: ${netPieces.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            trailing: const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 14),
            onTap: () => _selectItem(item, value),
          );
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.blue),
    ),
    fillColor: const Color(0xFF22304A),
    filled: true,
  );

  Widget _qtyButton(IconData icon, VoidCallback onTap) => SizedBox(
    width: 52,
    height: 52,
    child: Material(
      color: const Color(0xFF22304A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Icon(icon, color: Colors.white70),
      ),
    ),
  );
}