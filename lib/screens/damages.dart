import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/damageitem.dart';
import '../models/itemmodel.dart';
import '../providers/SalesProvider.dart';
import 'damagesslist.dart';

class Damages extends StatefulWidget {
  final damageitemmodel? damageitem;

  const Damages({super.key, this.damageitem});

  @override
  State<Damages> createState() => _DamagesState();
}

class _DamagesState extends State<Damages> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _totalPiecesController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _cppriceController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedDamageMode;
  List<String> _damageMode = [];

  List<Mode>? _itemModes;

  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  ItemModel? _selectedItem;
  String _searchQuery = '';
  String grandtotal = '0.0';
  List<Map<String, dynamic>> _damageItems = [];

  int? _editingIndex;
  String _branchid = "";
  String _branchname = "";
  double _selectedCartonLeft = 0.0;
  double _singleLeft = 0.0;
  Map<String, dynamic>? branchbalance;
  String? _selecteddamagereason;


  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final datafeed = context.read<Datafeed>();

      setState(() {
        _branchid = datafeed.branchid;
        _branchname = datafeed.branch;
      });
      context.read<Datafeed>().fetchItems();
      context.read<Datafeed>().fetchSuppliers();
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchReturnreasons();

      _barcodeController.addListener(_onBarcodeChanged);
      _quantityController.addListener(_updateTotals);
      _cppriceController.addListener(_updateTotals);
      _discountController.addListener(_updateTotals);
    });
    if (widget.damageitem != null) {
      final Map<String, dynamic> itemMap = Map<String, dynamic>.from(
        widget.damageitem!.item,
      );

      var indexkeys = itemMap.keys.toList()..sort();

      _damageItems = indexkeys.map((key) => Map<String, dynamic>.from(itemMap[key])).toList();
      _syncTotals();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateGrandTotal();
      });
    } else {
      _damageItems = [];
      grandtotal = '0.0';
     }

  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeController.dispose();
    _itemController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _discountController.removeListener(_updateTotals);
    _cppriceController.removeListener(_updateTotals);
    _totalPiecesController.dispose();
    _totalAmountController.dispose();
    _cppriceController.dispose();
    super.dispose();
  }
  void _syncTotals() {
    double total = 0;

    for (final item in _damageItems) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      final modeQty = double.tryParse(item['modeqty']?.toString() ?? '1') ?? 1;

      total += cp * qty * modeQty;
    }

    setState(() {
      grandtotal = total.toStringAsFixed(2);
      _totalAmountController.text = grandtotal;
    });
  }
  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
      );

      if (result != null && result is String) {
        setState(() {
          _barcodeController.text = result;
        });
        _formKey.currentState?.validate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening scanner: $e'),
            backgroundColor: Colors.red,
          ),
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

  void _addToSalesPreview() {
    final datafeed = Provider.of<Datafeed>(context, listen: false);
    if (_formKey.currentState!.validate()) {
      final qty = double.tryParse(_quantityController.text) ?? 0;
      final cp = double.tryParse(_cppriceController.text) ?? 0;
      if (_selectedCartonLeft <= 0) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No stock available for this item",style: TextStyle(color: Theme.of(context).colorScheme.surface),)),
        );
        return;
      }

      if (_selectedDamageMode?.toLowerCase() == 'single') {
        if (qty > _singleLeft) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Quantity exceeds available single stock"),
            ),
          );
          return;
        }
      } else {
        if (qty > _selectedCartonLeft) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Quantity exceeds available carton stock"),
            ),
          );
          return;
        }
      }
      String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());


      final mode = _getSelectedMode();

      final modeQty =
          double.tryParse(mode?.qty ?? '1') ?? 1;

      final totalPieces = qty * modeQty;
      final itemGrandTotal = cp * totalPieces;
      final now = DateTime.now();

      final day = DateFormat('EEEE').format(now);
      final year = now.year.toString();
      final month = '${now.year}.${now.month}';
      final weekNumber =
          ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

      final week = '${now.year}.$weekNumber';
      final salesItem = {
        'itemid': _selectedItem?.id ?? '',
        'barcode': _barcodeController.text,
        'cp': _cppriceController.text,
        'reason': _selecteddamagereason??'',
        'branchid': _branchid,
        'branchname': _branchname,
        'modeqty': mode?.qty ?? '1',
        'item': _itemController.text,
        'mode': _selectedDamageMode ?? 'single',
        'quantity': _quantityController.text,
        'totalpieces': totalPieces,
        'supplier': datafeed.selectedSupplier?.supplier ?? '',
        'grandtotal': itemGrandTotal.toStringAsFixed(2),
        'dateymd': formattedDate,
        'day': day,
        'week': week,
        'month': month,
        'year': year,
        'boxpiece':_itemModes
            ?.firstWhere(
              (m) => m.name.toLowerCase() == 'carton',
          orElse: () => Mode(id: '', name: '', qty: '1', cp: '', rp: '', wp: '', sp: ''),
        )
            .qty ?? '1',

        'modes': _itemModes != null
            ? { for (final m in _itemModes!) m.name: {
          'id':   m.id,
          'name': m.name,
          'qty':  m.qty,
          'cp':   m.cp,
          'rp':   m.rp,
          'wp':   m.wp,
          'sp':   m.sp,
        }}  : <String, dynamic>{},
      };

      setState(() {
        if (_editingIndex != null) {
          _damageItems[_editingIndex!] = salesItem;
          _editingIndex = null;
        } else {
          _damageItems.add(salesItem);
        }
        _recalculateGrandTotal();
      });
      _syncTotals();
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item added to damages preview'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Mode? _getSelectedMode() {
    if (_itemModes == null || _selectedDamageMode == null) return null;

    return _itemModes!.firstWhere(
      (m) => m.name.toLowerCase() == _selectedDamageMode!.toLowerCase(),
      orElse: () => Mode(id: '', name: '', qty: '', cp: '', rp: '', wp: '', sp: ''

      )
    );
  }

  void _updateTotals() {
    double totalCost = 0;
    double totalPieces = 0;

    for (var item in _damageItems) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      final modeQty = double.tryParse(item['modeqty']?.toString() ?? '1') ?? 1;

      final pieces = qty * modeQty;

      totalPieces += pieces;
      totalCost += cp * pieces;
    }

    _totalPiecesController.text = totalPieces.toStringAsFixed(2);
    _totalAmountController.text = totalCost.toStringAsFixed(2);

    setState(() {
      grandtotal = totalCost.toStringAsFixed(2);
    });
  }

  void _resetForm() {
    _itemController.clear();
    _barcodeController.clear();
    _quantityController.clear();
    _priceController.clear();
    _discountController.clear();
    _totalPiecesController.clear();
    _cppriceController.clear();

    setState(() {
      _selectedItem = null;


      _selectedDamageMode = null;

      _itemModes = null;
      _damageMode = [];
      _selecteddamagereason = null;
    });
  }

  void _removeFromSalesPreview(int index) {
    setState(() {
      _damageItems.removeAt(index);
      _recalculateGrandTotal();
    });
    _syncTotals();
  }
  void _recalculateGrandTotal() {
    double total = 0;
    for (final item in _damageItems) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      final modeQty = double.tryParse(item['modeqty']?.toString() ?? '1') ?? 1;
      total += cp * qty * modeQty;
    }
    setState(() {
      grandtotal = total.toStringAsFixed(2);
      _totalAmountController.text = grandtotal;
    });
  }

  bool _isLoading = false;

  void _editCartItem(int index) {
    final item = _damageItems[index];
    final datafeed = Provider.of<Datafeed>(context, listen: false);

    _barcodeController.removeListener(_onBarcodeChanged);

    final itemId = item['itemid']?.toString() ?? '';

    if (itemId.isNotEmpty) {
      final foundItem = datafeed.items.firstWhere(
            (i) => i.id == itemId,
        orElse: () => ItemModel.fromMap({'id': itemId}),
      );
      _selectItem(foundItem, datafeed);
    }

    setState(() {
      _editingIndex = index;
      _itemController.text = item['item']?.toString() ?? '';
      _barcodeController.text = item['barcode']?.toString() ?? '';
      _quantityController.text = item['quantity']?.toString() ?? '';
      _totalPiecesController.text = item['totalpieces']?.toString() ?? '';
      _selectedDamageMode = item['mode']?.toString() ?? '';
      _cppriceController.text = item['cp']?.toString() ?? '';
      _selecteddamagereason = item['reason']?.toString();
      _showSuggestions = false;


      double total = 0;
      for (final d in _damageItems) {
        final cp = double.tryParse(d['cp']?.toString() ?? '0') ?? 0;
        final qty = double.tryParse(d['quantity']?.toString() ?? '0') ?? 0;
        final modeQty = double.tryParse(d['modeqty']?.toString() ?? '1') ?? 1;
        total += cp * qty * modeQty;
      }
      grandtotal = total.toStringAsFixed(2);
      _totalAmountController.text = grandtotal;
    });

    _barcodeController.addListener(_onBarcodeChanged);
  }

  void _selectItem(ItemModel? item, Datafeed datafeed) {
    if (item == null) return;

    final branchId = _branchid;

    final branchbalance =
        item.branchbalance?[branchId] as Map<String, dynamic>? ?? {};

    final double netPieces =
        (branchbalance['netpieces'] as num?)?.toDouble() ?? 0.0;

    final mode = item.modes;

    final cartonMode = mode?.firstWhere(
          (m) => m.name.toLowerCase() == 'carton',
      orElse: () =>
          Mode(id: '', name: '', qty: '', cp: '', rp: '', wp: '', sp: ''),
    );

    final singleMode = mode?.firstWhere(
          (m) => m.name.toLowerCase() == 'single',
      orElse: () =>
          Mode(id: '', name: '', qty: '', cp: '', rp: '', wp: '', sp: ''),
    );

    final boxQty = double.tryParse(cartonMode?.qty ?? '1') ?? 1;
    final singleQty = double.tryParse(singleMode?.qty ?? '1') ?? 1;

    final double cartonsLeft = boxQty > 0 ? (netPieces / boxQty) : 0;
    final double singleLeft = singleQty > 0 ? (netPieces / singleQty) : 0;

    List<Mode>? effectivePricing;

    if (item.branchprices != null &&
        item.branchprices!.containsKey(branchId)) {
      final rawPricing = item.branchprices![branchId]['pricing'];

      if (rawPricing is List) {
        effectivePricing = (rawPricing)
            .map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final id = map['id']?.toString() ?? '';
          return Mode.fromMap(id, map);
        })
            .cast<Mode>()
            .toList();
      } else if (rawPricing is Map) {
        effectivePricing = rawPricing.entries
            .map((entry) {
          final id = entry.key.toString();
          final map = Map<String, dynamic>.from(entry.value as Map);
          return Mode.fromMap(id, map);
        })
            .cast<Mode>()
            .toList();
      } else {
        effectivePricing = item.modes;
      }
    } else {
      effectivePricing = item.modes;
    }

    setState(() {
      _selectedItem = item;
      _selectedCartonLeft = cartonsLeft;
      _singleLeft = singleLeft;
      _itemModes = effectivePricing;

      if (_itemModes != null && _itemModes!.isNotEmpty) {
        _damageMode = _itemModes!.map((e) {
          return e.name.isNotEmpty ? e.name : e.id;
        }).toList();

        _damageMode.sort((a, b) {
          if (a.toLowerCase() == 'single') return -1;
          if (b.toLowerCase() == 'single') return 1;
          return 0;
        });

        _selectedDamageMode = _damageMode.first;
      } else {
        _damageMode = ['Single'];
        _selectedDamageMode = 'Single';
      }

      _itemController.text = item.name;
      _barcodeController.text = item.barcode;
      _cppriceController.text = item.cp;

      _showSuggestions = false;
      _suggestions.clear();
    });
  }

//   Future<void> _saveSale() async {
//     if (_damageItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//          SnackBar(
//           content: Text('No items to save',style: TextStyle(color: Theme.of(context).colorScheme.surface),),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }
//     if (_isLoading) return;
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       final datafeed = Provider.of<Datafeed>(context, listen: false);
//
//       final companyId = datafeed.companyid;
//       final staffPosition = datafeed.staffPosition;
//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//
//       final docId = '${_branchid}_${staffPosition}_$timestamp'
//           .toLowerCase()
//           .replaceAll(RegExp(r'[^a-z0-9_]'), '');
// final trnx =  '${staffPosition}_$timestamp'
//           .toLowerCase()
//           .replaceAll(RegExp(r'[^a-z0-9_]'), '');
//
//       final Map<String, dynamic> itemsMap = {};
//       for (int i = 0; i < _damageItems.length; i++) {
//         itemsMap['item_$i'] = {..._damageItems[i]};
//       }
//      // String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
//       final formattedDate = context.read<SalesProvider>().saleDate;
//       final damageitem = damageitemmodel(
//         id: docId,
//         trxid: trnx,
//         itemcount: _damageItems.length.toString(),
//         item: itemsMap,
//         branchid: _branchid,
//         branchname: _branchname,
//         description: '',
//         createdby: datafeed.staff,
//         createdat: DateTime.now(),
//         staffposition: staffPosition.toString(),
//         companyid: companyId,
//         company: datafeed.company,
//         dateymd: formattedDate,
//         grandtotal: grandtotal,
//       );
//
//       await datafeed.db
//           .collection('damageitems')
//           .doc(docId)
//           .set(damageitem.tomap(), SetOptions(merge: true));
//
//       if (!mounted) return;
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Damages recorded successfully',style: TextStyle(color: Theme.of(context).colorScheme.surface),),
//           backgroundColor: Colors.green,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//
//       setState(() {
//         _damageItems.clear();
//         _isLoading = false;
//         _totalAmountController.text = '0.00';
//         grandtotal = '0.00';
//       });
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error saving damages: $e',style: TextStyle(color: Theme.of(context).colorScheme.surface),),
//           backgroundColor: Colors.red,
//         ),
//       );
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
  Future<void> _saveSale() async {
    if (_damageItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No items to save', style: TextStyle(color: Theme.of(context).colorScheme.surface)),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final datafeed = Provider.of<Datafeed>(context, listen: false);

      final companyId = datafeed.companyid;
      final staffPosition = datafeed.staffPosition;

      // FIX: reuse the existing document's id/trxid when editing, instead of
      // always minting a new one from the current timestamp. Previously this
      // block ran unconditionally, so every save — including edits — wrote to
      // a brand-new Firestore document and left the original record untouched.
      final bool isEditing = widget.damageitem != null;

      final String docId;
      final String trnx;

      if (isEditing) {
        docId = widget.damageitem!.id;
        trnx = widget.damageitem!.trxid!;
      } else {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        docId = '${_branchid}_${staffPosition}_$timestamp'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]'), '');
        trnx = '${staffPosition}_$timestamp'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      }

      final Map<String, dynamic> itemsMap = {};
      for (int i = 0; i < _damageItems.length; i++) {
        itemsMap['item_$i'] = {..._damageItems[i]};
      }

      final formattedDate = context.read<SalesProvider>().saleDate;

      final damageitem = damageitemmodel(
        id: docId,
        trxid: trnx,
        itemcount: _damageItems.length.toString(),
        item: itemsMap,
        branchid: _branchid,
        branchname: _branchname,
        description: '',
        // Preserve who originally created the record when editing; only stamp
        // the current staff as creator for brand-new records.
        createdby: isEditing ? widget.damageitem!.createdby : datafeed.staff,
        createdat: isEditing ? widget.damageitem!.createdat : DateTime.now(),
        staffposition: staffPosition.toString(),
        companyid: companyId,
        company: datafeed.company,
        dateymd: formattedDate,
        grandtotal: grandtotal,
      );

      await datafeed.db
          .collection('damageitems')
          .doc(docId)
          .set(damageitem.tomap(), SetOptions(merge: true));

      // FIX: refresh the local cached list so the list page reflects the
      // update immediately instead of showing stale data until a manual
      // re-fetch. fetchdamages() already exists and is what DamagesListPage
      // calls on init, so this is the safest way to sync local state without
      // needing to know Datafeed's internal list-mutation methods.
      await datafeed.fetchdamages();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Damage record updated successfully' : 'Damages recorded successfully',
            style: TextStyle(color: Theme.of(context).colorScheme.surface),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _damageItems.clear();
        _isLoading = false;
        _totalAmountController.text = '0.00';
        grandtotal = '0.00';
      });

      // If this was an edit opened from the list page, pop back to it now
      // that the update has been saved and the local list refreshed.
      if (isEditing && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving damages: $e', style: TextStyle(color: Theme.of(context).colorScheme.surface)),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final accesslevel = value.accesslevel;
        final isSuperAdmin = accesslevel.toLowerCase().trim() == 'super admin';
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            tooltip: 'View Damages',
            child: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DamagesListPage()),
              );
            },
          ),
          appBar: AppBar(
            title: Text( "Damages",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 8.0,
                  top: 20,
                  right: 8,
                  bottom: 20,
                ),
                child: Column(
                  children: [
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmallScreen = constraints.maxWidth < 900;
                          final double itemWidth = isSmallScreen
                              ? constraints.maxWidth
                              : (constraints.maxWidth / 2) - 24;
                          final bool isMobile = constraints.maxWidth < 600;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                child: Container(
                                  color: Color(0xFF182232),
                                  //height: 600,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Damages Entries",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Divider(color: Colors.white24),
                                        SizedBox(height: 15),
                                        Form(
                                          key: _formKey,
                                          child: Column(
                                            children: [
                                              if(isSuperAdmin)...[
                                                TextFormField(
                                                  controller: _dateController,
                                                  readOnly: true,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: _inputDecoration(
                                                    label: 'Date',
                                                    prefix: Icons.calendar_today,
                                                    hint: 'yyyy-mm-dd',
                                                  ),
                                                  onTap: () async {
                                                    DateTime? picked = await showDatePicker(
                                                      context: context,
                                                      initialDate: _selectedDate ?? DateTime.now(),
                                                      firstDate: DateTime(2020),
                                                      lastDate: DateTime(2100),
                                                      builder: (context, child) {
                                                        return Theme(
                                                          data: Theme.of(context).copyWith(
                                                            colorScheme: const ColorScheme.dark(
                                                              primary: Colors.blue,
                                                              onPrimary: Colors.white,
                                                              surface: Color(0xFF22304A),
                                                              onSurface: Colors.white,
                                                            ),
                                                          ),
                                                          child: child!,
                                                        );
                                                      },
                                                    );

                                                    if (picked != null) {
                                                      context.read<SalesProvider>().setSaleDate(picked);

                                                      setState(() {
                                                        _selectedDate = picked;
                                                        _dateController.text =
                                                        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                                      });
                                                    }
                                                  },
                                                  validator: (value) =>
                                                  value == null || value.isEmpty
                                                      ? 'Select date'
                                                      : null,
                                                )
                                              ],
                                              SizedBox(height: 10),
                                              DropdownButtonFormField<String>(
                                                isExpanded: true,
                                                value: value.branches.any((b) => b.id == value.branchid)
                                                    ? value.branchid
                                                    : null,
                                                dropdownColor: const Color(0xFF22304A,),
                                                style: const TextStyle(color: Colors.white, ),
                                                decoration: InputDecoration(
                                                  labelText: 'Branch',
                                                  labelStyle: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                  OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular( 12, ),
                                                    borderSide:  const BorderSide(
                                                      color: Colors.white24,
                                                    ),
                                                  ),
                                                  focusedBorder:
                                                  OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12, ),
                                                    borderSide:  const BorderSide(
                                                      color:  Colors.blue,
                                                    ),
                                                  ),
                                                  fillColor: const Color(0xFF22304A, ),
                                                  filled: true,
                                                ),
                                                items: value.branches.map((branch) {
                                                  return DropdownMenuItem<String>(
                                                    value: branch.id,
                                                    child: Text(
                                                      branch.branchname,
                                                      style: const TextStyle(color: Colors.white),
                                                    ),
                                                  );
                                                }).toList(),

                                                onChanged: (val) {
                                                  if (val != null) {
                                                    value.selectBranch(val);

                                                    setState(() {
                                                      _branchid = val;
                                                      _branchname = value.branches
                                                          .firstWhere((b) => b.id == val)
                                                          .branchname;
                                                    });

                                                    if (_selectedItem != null) {
                                                      _selectItem(_selectedItem, value);
                                                    }


                                                    _formKey.currentState?.validate();
                                                  }
                                                },

                                                validator: (val) =>
                                                val == null ? 'Please select Branch' : null,
                                              ),
                                              SizedBox(height: 10,),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller:
                                                          _barcodeController,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText: 'Barcode',
                                                        labelStyle:
                                                            const TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                            ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide:
                                                                  const BorderSide(
                                                                    color: Colors
                                                                        .white24,
                                                                  ),
                                                            ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide:
                                                                  const BorderSide(
                                                                    color: Colors
                                                                        .blue,
                                                                  ),
                                                            ),
                                                        fillColor: const Color(
                                                          0xFF22304A,
                                                        ),
                                                        filled: true,
                                                      ),
                                                      validator: (value) =>
                                                          value == null ||
                                                              value.isEmpty
                                                          ? 'Barcode required'
                                                          : null,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    height: 56,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF22304A,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.white24,
                                                      ),
                                                    ),
                                                    child: IconButton(
                                                      icon: const Icon(
                                                        Icons.qr_code_scanner,
                                                        color: Colors.white70,
                                                      ),
                                                      onPressed: _scanBarcode,
                                                      tooltip:
                                                          'Scan Barcode/QR Code',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_showSuggestions &&  _editingIndex == null)
                                                value.loading ? const Center(
                                                 child: CircularProgressIndicator(
                                                        color: Colors.blue,
                                                        strokeWidth: 2,
                                                         ),
                                                      )
                                                    : (() {
                                                     final query =_searchQuery.toLowerCase();

                                                    final filteredItems = query.isEmpty ? value.items
                                                            : value.items.where((item,) {
                                                                    final name = (item.name).toLowerCase();
                                                                    final barcode = (item.barcode).toLowerCase();
                                                                    final company =
                                                                        (item.company)
                                                                            .toLowerCase();
                                                                    final category =
                                                                        (item.pcategory)
                                                                            .toLowerCase();

                                                                    return name.contains(
                                                                          query,
                                                                        ) ||
                                                                        barcode.contains(
                                                                          query,
                                                                        ) ||
                                                                        company.contains(
                                                                          query,
                                                                        ) ||
                                                                        category.contains(
                                                                          query,
                                                                        );
                                                                  })
                                                                  .take(10)
                                                                  .toList();

                                                        if (filteredItems
                                                            .isEmpty) {
                                                          return const SizedBox.shrink();
                                                        }

                                                        return Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                top: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFF22304A,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            border: Border.all(
                                                              color: Colors.blue
                                                                  .withOpacity(
                                                                    0.3,
                                                                  ),
                                                            ),
                                                            boxShadow: const [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black26,
                                                                blurRadius: 8,
                                                                offset: Offset(
                                                                  0,
                                                                  4,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          constraints:
                                                              const BoxConstraints(
                                                                maxHeight: 250,
                                                              ),
                                                          child: ListView.builder(
                                                            shrinkWrap: true,
                                                            itemCount:
                                                                filteredItems
                                                                    .length,
                                                            itemBuilder: (context, index) {
                                                              final item = filteredItems[index];
                                                              final branchId = _branchid;
                                                              final branchbalance =item.branchbalance?[branchId] as Map<String, dynamic>? ?? {};

                                                              final double   netPieces = (branchbalance['netpieces'] as num?) ?.toDouble() ??   0.0;

                                                              final mode =   item.modes;

                                                              final cartonMode = mode?.firstWhere((m) => m.name.toLowerCase() == 'carton',
                                                                    orElse: () => Mode(
                                                                      id: '',
                                                                      name: '',
                                                                      qty: '1',
                                                                      cp: '',
                                                                      rp: '',
                                                                      wp: '',
                                                                      sp: '',
                                                                    ),
                                                                  );

                                                              final singleMode = mode?.firstWhere((m) => m.name.toLowerCase() =='single',
                                                                    orElse: () => Mode(
                                                                      id: '',
                                                                      name: '',
                                                                      qty: '1',
                                                                      cp: '',
                                                                      rp: '',
                                                                      wp: '',
                                                                      sp: '',
                                                                    ),
                                                                  );

                                                              final boxQty =  double.tryParse( cartonMode ?.qty ?? singleMode ?.qty ?? '1',);

                                                              final double  cartonsLeft =  boxQty! > 0  ? (netPieces /  boxQty) : 0.0;

                                                              return ListTile(
                                                                dense: true,
                                                                leading: const Icon(
                                                                  Icons
                                                                      .inventory_2,
                                                                  color: Colors
                                                                      .blue,
                                                                  size: 20,
                                                                ),
                                                                title: Text(
                                                                  item?.name ??
                                                                      '',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                                subtitle: Text(
                                                                  'Barcode: ${item.barcode} | Retail Price: GHS ${item.cp} | Boxes Balance: ${cartonsLeft.toStringAsFixed(2)} | Pieces: ${netPieces.toStringAsFixed(0)}',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                                ),
                                                                trailing: const Icon(
                                                                  Icons
                                                                      .arrow_forward_ios,
                                                                  color: Colors
                                                                      .white54,
                                                                  size: 14,
                                                                ),
                                                                onTap: () {
                                                                  _selectItem(
                                                                    item,
                                                                    value,
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          ),
                                                        );
                                                      })(),


                                              SizedBox(height: 10),
                                              TextFormField(
                                                controller: _itemController,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Item',
                                                  labelStyle: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Colors
                                                                  .white24,
                                                            ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                      ),
                                                  fillColor: const Color(
                                                    0xFF22304A,
                                                  ),
                                                  filled: true,
                                                ),
                                                validator: (value) =>
                                                    value == null ||
                                                        value.isEmpty
                                                    ? 'Item required'
                                                    : null,
                                              ),
                                              SizedBox(height: 10),
                                              DropdownButtonFormField<String>(
                                                value: _selectedDamageMode,
                                                dropdownColor: const Color(
                                                  0xFF22304A,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Sales Mode',
                                                  labelStyle: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Colors
                                                                  .white24,
                                                            ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                      ),
                                                  fillColor: const Color(
                                                    0xFF22304A,
                                                  ),
                                                  filled: true,
                                                ),
                                                items: _damageMode.isEmpty  ? null
                                                    : _damageMode.map((type) {
                                                        return DropdownMenuItem<String>(
                                                          value: type,
                                                          child: Text(type),
                                                        );
                                                      }).toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedDamageMode = value;
                                                  });

                                                  _updateTotals();
                                                  _formKey.currentState?.validate();
                                                },
                                                validator: (value) => value == null
                                                    ? 'Please select sales mode'
                                                    : null,
                                              ),
                                              SizedBox(height: 10),
                                              TextFormField(
                                                controller: _cppriceController,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Cost price',
                                                  labelStyle: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Colors
                                                                  .white24,
                                                            ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(         12,
                                                            ),
                                                        borderSide:  const BorderSide(
                                                              color: Colors.blue,
                                                            ),
                                                      ),
                                                  fillColor: const Color(
                                                    0xFF22304A,
                                                  ),
                                                  filled: true,
                                                ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    _selectedDamageMode?.toLowerCase() == 'single'
                                                        ? RegExp(r'^\d*$')
                                                        : RegExp(r'^\d*\.?\d*$'),
                                                  ),
                                                ],
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Enter amount';
                                                  }
                                                  final amount =
                                                      double.tryParse(value);
                                                  if (amount == null ||
                                                      amount < 1) {
                                                    return 'Amount must be greater than zero';
                                                  }

                                                  return null;
                                                },
                                                enabled: false,
                                              ),
                                              SizedBox(height: 10),
                                              TextFormField(
                                                controller: _quantityController,
                                               style: const TextStyle( color: Colors.white,),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true, ),
                                                inputFormatters: [
                                                    FilteringTextInputFormatter.allow(
                                                      _selectedDamageMode =='Single' ? RegExp(r'^\d*$')
                                                          : RegExp(r'^\d*\.?\d*$',),
                                                    ),
                                                  ],
                                                decoration: InputDecoration(
                                                  labelText: 'Quantity',
                                                  labelStyle: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                    borderSide:
                                                    const BorderSide(
                                                      color: Colors
                                                          .white24,
                                                    ),
                                                  ),
                                                  focusedBorder:  OutlineInputBorder(
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                    borderSide:
                                                    const BorderSide(
                                                      color:
                                                      Colors.blue,
                                                    ),
                                                  ),
                                                  fillColor: const Color(
                                                    0xFF22304A,
                                                  ),
                                                  filled: true,
                                                ),
                                                onChanged: (value) {
                                                  // validate instantly when user types
                                                  _formKey.currentState?.validate();
                                                },
                                                validator: (value) {
                                                  if (value == null || value.isEmpty) {
                                                    return "Enter quantity";
                                                  }

                                                  final qty = double.tryParse(value) ?? 0;

                                                  if (_selectedCartonLeft <= 0) {
                                                    return "Item not available in $_branchname branch";
                                                  }

                                                  if (_selectedDamageMode?.toLowerCase() == 'single' &&
                                                      qty > _singleLeft) {
                                                    return "Only ${_singleLeft.toStringAsFixed(0)} available in $_branchname branch";
                                                  }

                                                  if (_selectedDamageMode?.toLowerCase() == 'carton' &&
                                                      qty > _selectedCartonLeft) {
                                                    return "Only ${_selectedCartonLeft.toStringAsFixed(2)} available in $_branchname branch";
                                                  }

                                                  return null;
                                                },
                                              ),
                                              SizedBox(height: 10),
                                              DropdownButtonFormField<String>(
                                                value:
                                                    value.selectedSupplier?.id,
                                                dropdownColor: const Color(
                                                  0xFF22304A,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Supplier',
                                                  labelStyle: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Colors
                                                                  .white24,
                                                            ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                      ),
                                                  fillColor: const Color(
                                                    0xFF22304A,
                                                  ),
                                                  filled: true,
                                                ),
                                                items: value.suppliers.map((
                                                  suplier,
                                                ) {
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: suplier.id,
                                                    child: Text(
                                                      suplier.supplier,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null)
                                                    value.selectSupplier(val);
                                                },
                                                validator: (val) => val == null
                                                    ? 'Please select Supplier'
                                                    : null,
                                              ),
                                              SizedBox(height: 10),
                                              DropdownButtonFormField<String>(
                                                value: value.returnitemreasons.any(
                                                      (r) => r.name == _selecteddamagereason,
                                                )
                                                    ? _selecteddamagereason
                                                    : null,
                                                dropdownColor: const Color(0xFF22304A),
                                                style: const TextStyle(color: Colors.white),
                                                iconEnabledColor: Colors.white70,
                                                decoration: InputDecoration(
                                                  labelText: 'Damage Reason',
                                                  labelStyle: const TextStyle(color: Colors.white70),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
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
                                                ),
                                                items: value.returnitemreasons.map((reason) {
                                                  return DropdownMenuItem<String>(
                                                    value: reason.name,
                                                    child: Text(
                                                      reason.name,
                                                      style: const TextStyle(color: Colors.white),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _selecteddamagereason = val;
                                                  });
                                                },
                                                validator: (val) =>
                                                val == null || val.isEmpty ? 'Please select damage reason' : null,
                                              ),
                                              SizedBox(height: 10),
                                              const Divider(
                                                color: Colors.white24,
                                              ),
                                              Wrap(
                                                spacing: 10,
                                                runSpacing: 10,
                                                children: [
                                                  SizedBox(
                                                    width: 150,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.lightBlue,
                                                        padding:  const EdgeInsets.symmetric( vertical: 16, ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8,),
                                                        ),
                                                      ),
                                                      onPressed: _addToSalesPreview,
                                                      child: Text( "Save Record",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 150,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.orangeAccent,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 16,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: _resetForm,
                                                      child: Text(
                                                        "Reset",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
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
                                ),
                              ),
                              Visibility(
                                visible: !isMobile,
                                child: SizedBox(
                                  width: itemWidth,
                                  child: Container(
                                    color: Color(0xFF182232),
                                    //height: 300,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Damages Preview",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(color: Colors.white24),
                                          SizedBox(height: 15),

                                          Table(
                                            border: TableBorder.all(
                                              color: Colors.grey,
                                            ),
                                            columnWidths: const {
                                              0: FixedColumnWidth(40),
                                              1: FlexColumnWidth(3),
                                              2: FlexColumnWidth(2),
                                              3: FlexColumnWidth(1),
                                              4: FlexColumnWidth(1),
                                              5: FlexColumnWidth(1),
                                              6: FixedColumnWidth(60),
                                            },
                                            children: [
                                              _tableRow([
                                                "#",
                                                "Item",
                                                "Mode",
                                                "Qty",
                                                "CP",
                                                "Total",
                                                "Action",
                                              ], isHeader: true),
                                              // Display sales items
                                              ..._damageItems.asMap().entries.map((
                                                entry,
                                              ) {
                                                final index = entry.key;
                                                final item = entry.value;
                                                final modeqty = double.tryParse(item['modeqty']?.toString() ?? '1', ) ?? 1;
                                                final quantity =  double.tryParse(item['quantity'] ?.toString() ?? '0', ) ??  0;
                                                final totalpieces =  modeqty * quantity;
                                                final itemCost = double.tryParse( item['cp']?.toString() ?? '0',) ?? 0;
                                                final costprice =  itemCost * totalpieces;

                                                return _tableRowWithAction(
                                                  (index + 1).toString(),
                                                  item['item'] ?? '',
                                                  "${item['mode'] ?? ''} (${item['modeqty'] ?? '1'})",
                                                  item['quantity'] ?? '0',
                                                  item['cp'] ?? '0',
                                                  costprice.toStringAsFixed(2),
                                                  () => _removeFromSalesPreview(index,),
                                                  onEdit: () => _editCartItem(index),
                                                );
                                              }),

                                              _tableRow([
                                                "",
                                                "Amount",
                                                "",
                                                "",
                                                "",
                                                grandtotal,
                                                "",
                                              ]),
                                            ],
                                          ),

                                          SizedBox(height: 20),
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              final isWideScreen =
                                                  constraints.maxWidth > 600;
                                              final buttonWidth = isWideScreen
                                                  ? 120.0
                                                  : 90.0;
                                              final buttonPadding = isWideScreen
                                                  ? 16.0
                                                  : 12.0;
                                              final fontSize = isWideScreen
                                                  ? 14.0
                                                  : 12.0;

                                              return Wrap(
                                                spacing: isWideScreen ? 10 : 6,
                                                runSpacing: isWideScreen
                                                    ? 10
                                                    : 8,
                                                alignment: WrapAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: buttonWidth,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.teal,
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              vertical:
                                                                  buttonPadding,
                                                              horizontal: 4,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: _isLoading
                                                          ? null
                                                          : _saveSale,
                                                      child: _isLoading
                                                          ? const SizedBox(
                                                              height: 20,
                                                              width: 20,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            )
                                                          : FittedBox(
                                                              fit: BoxFit
                                                                  .scaleDown,
                                                              child: Text(
                                                                "Save",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      fontSize,
                                                                ),
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Visibility(
                                visible: isMobile,
                                child: MobileSalesPreview(
                                  cartItems: _damageItems,
                                  saveSale: _saveSale,
                                  isLoading: _isLoading,
                                  onDelete: _removeFromSalesPreview,
                                  onEdit: _editCartItem,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefix,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: prefix != null ? Icon(prefix, color: Colors.white70) : null,
      suffixIcon: suffix,
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
  }

  TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells
          .map(
            (e) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                e,
                textAlign: isHeader ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  color: Colors.white,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _tableRowWithAction(
    String index,
    String item,
    String quantity,
    String price,
    String cprice,
    String total,
    VoidCallback onDelete, {
    bool isInsufficient = false,
    VoidCallback? onEdit,
  }) {
    final textColor = isInsufficient ? Colors.redAccent : Colors.white;
    return TableRow(
      decoration: isInsufficient
          ? BoxDecoration(color: Colors.red.withOpacity(0.12))
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(index, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(item, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(quantity, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(price, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(cprice, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(total, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.amber, size: 18),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Edit',
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Barcode Scanner Screen
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode/QR Code'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, value, child) {
                final isFlashOn = value.torchState == TorchState.on;
                return Icon(
                  isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isProcessing) return;

              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final barcode = barcodes.first;
              final String? code = barcode.rawValue;

              if (code != null && code.isNotEmpty) {
                setState(() => _isProcessing = true);
                Navigator.pop(context, code);
              }
            },
          ),
          // Overlay with scanning guide
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Position the barcode or QR code within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

class MobileSalesPreview extends StatelessWidget {
  const MobileSalesPreview({
    super.key,
    required this.cartItems,
    required this.saveSale,
    required this.isLoading,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Map<String, dynamic>> cartItems;
  final VoidCallback saveSale;
  final bool isLoading;
  final Function(int) onDelete;
  final Function(int) onEdit;

  double _calculateTotal() {
    double total = 0;

    for (var item in cartItems) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final modeqty = double.tryParse(item['modeqty']?.toString() ?? '1') ?? 1;
      final quantity = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;

      final totalpieces = modeqty * quantity;

      total += cp * totalpieces;
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFF182232)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              SizedBox(width: 8),
              Text(
                "Damages Preview",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const Divider(color: Colors.white24, height: 20),

          const SizedBox(height: 12),

          /// ITEMS LIST
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, thickness: 1, height: 16),
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return _cartItem(item, index);
            },
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white24),

          /// TOTAL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Amount",
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                "GHC ${_calculateTotal().toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          /// SAVE BUTTON
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: isLoading ? null : saveSale,
                  child: isLoading   ?
                  const SizedBox(
                   height: 20,
                   width: 20,
                   child: CircularProgressIndicator(
                   strokeWidth: 2,
                   color: Colors.white,
                      ),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "Save",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ITEM CARD
  Widget _cartItem(
    Map<String, dynamic> item,
    int index, {
    bool isInsufficient = false,
  }) {
    final name = (item['item'] ?? '').toString();
    final modes = (item['mode'] ?? '').toString();
    final modeqty = (item['modeqty'] ?? '').toString();
    final mode = modes.isNotEmpty ? "$modes ($modeqty)" : "";
    final price = _parseDouble(item['cp']);
    final qty = _parseDouble(item['quantity']);
    final totalpieces = _parseDouble(item['totalpieces']);

    final total = price * totalpieces;
    final total1 = price * (qty * _parseDouble(modeqty));
    final primaryColor = isInsufficient ? Colors.redAccent : Colors.white;
    final secondaryColor = isInsufficient ? Colors.redAccent : Colors.white60;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isInsufficient
          ? BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isInsufficient
                ? Colors.red.withOpacity(0.25)
                : Colors.white24,
            child: const Icon(Icons.inventory_2, size: 18, color: Colors.white),
          ),

          const SizedBox(width: 10),

          /// ITEM INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// NAME + PRICE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(color: primaryColor, fontSize: 14),
                    ),
                    Text(
                      "GHC ${price.toStringAsFixed(2)}",
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                /// MODE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Mode",
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                    Text(mode, style: TextStyle(color: primaryColor)),
                  ],
                ),

                /// QUANTITY
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Quantity",
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                    Text(
                      qty.toStringAsFixed(0),
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                /// TOTAL
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total",
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                    Text(
                      "GHC ${total1.toStringAsFixed(2)}",
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                /// WARNING
                if (isInsufficient)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Insufficient balance',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 6),

                /// ACTION BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.amber,
                        size: 18,
                      ),
                      onPressed: () => onEdit(index),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () => onDelete(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
