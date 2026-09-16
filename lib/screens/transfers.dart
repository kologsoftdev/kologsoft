import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/branch.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/transferinvoice.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/StockProvider.dart';
import 'itemreg.dart';

class NewTransfer extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;
  const NewTransfer({super.key,this.docId, this.data});

  @override
  State<NewTransfer> createState() => _NewTransferState();
}

class _NewTransferState extends State<NewTransfer> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();

  bool _loading = false;
  DateTime? _selectedDate;
  bool _showStockItems = false;
  Map<String, dynamic>? _pendingHeader;
  BranchModel? _fromselectedBranch;
  String? _fromselectedBranchid;
  String? _toselectedBranchid;
  String? _fromselectedBrancname;
  String? _toselectedBrancname;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<Datafeed>(context, listen: false);
      provider.fetchBranches();
      provider.fetchWarehouses();
      if (widget.data!=null && widget.data != null) {
        final customadata = widget.data!;
        final branchId = customadata['branchId'];
        if (branchId != null && branchId.isNotEmpty) {
          provider.selectBranch(branchId);
        }
      }
    });


    if (widget.docId != null && widget.docId!.isNotEmpty) {
      _showStockItems = true;
      _pendingHeader = widget.data;
    }
  }

  void _resetToNewStock() {
    setState(() {
      _showStockItems = false;
      _pendingHeader ={};
      widget.docId == null;
      _dateController.clear();
      _selectedDate = null;

    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefix,
    String? hint,
    Widget? suffix,
  }) {return InputDecoration(
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
  );}

  Widget _twoCol(BuildContext context, Widget a, Widget b) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (isSmallScreen) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: a),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: b),
        ],
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(width: 320, child: a),
          SizedBox(width: 320, child: b),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(builder: (BuildContext context, Datafeed value, Widget? child) {

      return Scaffold(
        backgroundColor: const Color(0xFF101A23),
        appBar: AppBar(
          title: Text(widget.docId != null ? "EDIT STOCK TRANSFER" : "STOCK TRANSFER"),
          backgroundColor: const Color(0xFF0D1A26),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0.15, 0),
                    end: Offset.zero,
                  ).animate(animation);

                  return SlideTransition(
                    position: offset,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _showStockItems
                    ? Padding(
                  key: const ValueKey('stock_form'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child:WareHouseTransferForm(
                    transactionId: _pendingHeader!['docid'] as String,
                    headerData: _pendingHeader!,
                    onNewTransaction: _resetToNewStock,
                  ),


                )
                    : Padding(
                  key: const ValueKey('header_card'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: ConstrainedBox( constraints: const BoxConstraints(maxWidth: 700),
                      child: Card(
                        color: const Color(0xFF182232),
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Note: You cannot transfer stock from and to the same branch.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                value: _fromselectedBranch?.id,
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(label: 'Warehouse/Branch (Source)', prefix: Icons.business),
                                items: value.branches.where((branch) => branch.branchtype!= 'Sales Point')
                                    .map((fromselectedbranch) {
                                  final isSameAsTo = fromselectedbranch.id == _toselectedBranchid;
                                  return DropdownMenuItem<String>(
                                    enabled: !isSameAsTo,
                                    value: fromselectedbranch.id,
                                    child: Text(
                                        fromselectedbranch.branchname,
                                        style: TextStyle(
                                          color: isSameAsTo ? Colors.grey : Colors.white,
                                    ),
                                  ),);
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null);
                                  setState(() {
                                    _fromselectedBranchid=val!;
                                    _fromselectedBrancname = value.branches.firstWhere((w) => w.id == val).branchname;
                                  });
                                },
                                validator: (val) => val == null ? 'Please select warehouse' : null,

                              ),
                              const SizedBox(height: 14),

                              _twoCol(
                                context,
                                DropdownButtonFormField<String>(
                                  value: value.branches
                                      .where((b) => b.branchtype != 'Sales Point')
                                      .any((b) => b.id == value.selectedBranch?.id)
                                      ? value.selectedBranch?.id
                                      : null,
                                  dropdownColor: const Color(0xFF22304A),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(label: 'Recieving Branch', prefix: Icons.location_city),
                                  items: value.branches.where((branch) => branch.branchtype!= 'Sales Point')
                                      .map((branch) {
                                    final isSameAsFrom = branch.id == _fromselectedBranchid;
                                    return DropdownMenuItem<String>(
                                      value: branch.id,
                                      enabled: !isSameAsFrom,
                                      child: Text(
                                        branch.branchname,
                                        style: TextStyle(
                                          color: isSameAsFrom ? Colors.grey : Colors.white, // gray out
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() {
                                        _toselectedBranchid=val;
                                        _toselectedBrancname = value.branches.firstWhere((w) => w.id == val).branchname;
                                      });
                                  },
                                  validator: (val) {
                                    if (val == null) return 'Please select branch';
                                    if (val == _fromselectedBranchid) {
                                      return 'Destination branch cannot be the same as warehouse';
                                    }
                                    return null;
                                  },
                                ),
                                TextFormField(
                                  controller: _dateController,
                                  readOnly: true,
                                  style: const TextStyle(color: Colors.white),
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
                                      setState(() {
                                        _selectedDate = picked;
                                        _dateController.text =
                                        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                      });
                                    }
                                  },
                                  validator: (value) => value == null || value.isEmpty ? 'Select date' : null,
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Actions
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF415A77),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: _loading
                                            ? null
                                            : () async {
                                          if (!_formKey.currentState!.validate()) return;

                                          setState(() => _loading = true);

                                          DateTime? transferdate = _selectedDate;
                                          final branchId = _toselectedBranchid;
                                          final branchName = _toselectedBrancname;
                                          final warehouseid = _fromselectedBranchid;
                                          final warehousename = _fromselectedBrancname;
                                          final docid = value.normalizeAndSanitize("${value.companyid}${DateTime.now().millisecondsSinceEpoch}${branchId}${value.staffPosition}");

                                          if (warehouseid!.isNotEmpty && branchId == warehouseid)
                                          {
                                            ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Branch and Warehouse cannot be the same')), );
                                            setState(() => _loading = false);
                                            return;

                                          }
                                          if (branchId == null || branchId.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Please select a receiving branch'),
                                              ),
                                            );
                                            setState(() => _loading = false);
                                            return;
                                          }
                                          final headerData = {
                                            'transferdate': transferdate != null ? Timestamp.fromDate(transferdate) : null,
                                            'recievebranchid': branchId,
                                            'recievebranchname': branchName,
                                            'supplywarehouseid': warehouseid,
                                            'supplywarehousename': warehousename,
                                            'docid': docid,
                                            'createdat': Timestamp.fromDate(DateTime.now()),
                                            'createdby': value.staff,
                                            'companyid': value.companyid,
                                            'company': value.company,
                                            'staffbranch': value.branch,
                                            'staffbranchid': value.branchid,
                                          };

                                          try {
                                            if (widget.docId == null) {
                                              setState(() {
                                                _pendingHeader = headerData;
                                                _showStockItems = true;
                                              });
                                              FocusScope.of(context).unfocus();
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                          }

                                          if (!mounted) return;
                                          setState(() {
                                            _loading = false;
                                          });
                                        },
                                        icon: _loading ? const SizedBox.shrink() : const Icon(Icons.arrow_forward),
                                        label: _loading
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                                            : Text(
                                          "Proceed",
                                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.white24),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => Navigator.of(context).maybePop(),
                                      child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class WareHouseTransferForm extends StatefulWidget {
  final String transactionId;
  final Map<String, dynamic> headerData;
  final VoidCallback onNewTransaction;

  const WareHouseTransferForm({super.key, required this.transactionId, required this.headerData, required this.onNewTransaction});

  @override
  State<WareHouseTransferForm> createState() => _WareHouseTransferFormState();
}

class _WareHouseTransferFormState extends State<WareHouseTransferForm> {
  final _formkey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  String? _selectedStockMode;
  List<String> _stockMode = [];
  String? _selectedPriceMode;
  Map<String, dynamic>? _itemModes;
  double boxpieces=1;
  bool _loading=false;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  Map<String, dynamic>? _selectedItem;
  String _searchQuery = '';
  bool hasbranchprices=false;
  Map<String, dynamic> branchData={};
  Map<String, dynamic> branchbalance={};
  Map<String, dynamic>? _branchbalancelist;
  Map<String, dynamic> currentBranchBalance={};
  Map<String, dynamic> currentBranchPrice={};
  double _selectedItemCP = 0.0;
  final List<Map<String, dynamic>> _items = [];
  double itembalance=0;
  @override
  void initState() {
    super.initState();
    _barcodeController.addListener(_onBarcodeChanged);
    if (widget.headerData.containsKey('items')) {
      final rawItems = widget.headerData['items'];
      if (rawItems is List) { _items.addAll(rawItems.map((e) => Map<String, dynamic>.from(e))); }
    }
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeController.dispose();
    _itemController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onBarcodeChanged() {
    setState(() {
      _searchQuery = _barcodeController.text.trim();
      _showSuggestions = _searchQuery.isNotEmpty;
    });
  }

   _selectItem(Map<String, dynamic> item, Map<String, dynamic> headerData) {
    setState(() {
      try{
      final provider=Provider.of<Datafeed>(context, listen: false);
      final warehouseid=headerData['supplywarehouseid'];

      _selectedItem = item;
      _barcodeController.text = item['barcode'] ?? '';
      _itemController.text = item['name'] ?? '';
      _selectedItemCP =
          double.tryParse(
            item['cp']?.toString() ?? '0',
          ) ??
              0.0;
      //get branch balance
      branchbalance = item['branchbalance'];
      _branchbalancelist = branchbalance[warehouseid];
      if(_branchbalancelist!=null){
        itembalance=(_branchbalancelist?['netpieces'] as num?)?.toDouble() ??0.0;
      }
       boxpieces = double.tryParse(item['modes']?['carton']?['qty']?.toString() ?? '1',) ?? 1;
      _itemModes = item['modes'] as Map<String, dynamic>?;
      _stockMode = provider.normalizeModes(_itemModes);
      _selectedStockMode = _stockMode.isNotEmpty ? _stockMode.first : null;
      }catch(e){
      debugPrint("Error : $e");
      _stockMode = ['Single', 'Box'];
      _selectedStockMode = _stockMode.first;
      }

      _updatePrice();



      _showSuggestions = false;
      _suggestions = [];
    });
  }

  void _updatePrice() {
    if (_itemModes == null || _selectedStockMode == null) {
      _priceController.text = '0';
      return;
    }

    // Find the mode data by matching the name
    Map<String, dynamic>? selectedModeData;
    for (var entry in _itemModes!.entries) {
      final modeData = entry.value as Map<String, dynamic>?;
      if (modeData?['name'] == _selectedStockMode) {
        selectedModeData = modeData;
        break;
      }
    }

    if (selectedModeData != null) {
      // Set price based on retail/wholesale selection
      //String price = '0';
      // if (_selectedPriceMode == 'Retail') {
      //   price = selectedModeData['cp']?.toString() ?? selectedModeData['retailprice']?.toString() ?? '0';
      // } else if (_selectedPriceMode == 'Wholesale') {
      //   price = selectedModeData['cp']?.toString() ?? selectedModeData['wholesaleprice']?.toString() ?? '0';
      // } else {
      //   // Default to retail price
      //   price = selectedModeData['cp']?.toString() ?? selectedModeData['retailprice']?.toString() ?? '0';
      // }
      _priceController.text =
          _selectedItemCP.toString();
      //_priceController.text = price;
    }
  }

  bool hasBalance=false;

  bool _checkItemBalance(double balance, double qty) {
    final isEnough = balance >= qty;

    setState(() {
      hasBalance = isEnough;
    });

    if (!isEnough) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance,$balance pieces left'),backgroundColor: Colors.redAccent,),
      );

    }

    return isEnough;
  }


  void _addItem() {
    if (_formkey.currentState!.validate()) {
      final String itemId = _selectedItem?['id'] ?? '';

      if (!widget.headerData.containsKey('items')) {
        final bool exists = _items.any(
              (item) => item['itemid'].toString() == itemId,
        );

        if (exists) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Duplicate Item"),
              content: const Text(
                "This item has already been added.\n\n"
                    "Please delete the existing item before adding it again.",
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          return;
        }
      }
      setState(() {
        final double quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
        final double price = double.tryParse(_priceController.text.trim())?.toDouble() ?? 0.0;
        // Determine mode quantity (pieces per selected mode) - default to 1 when missing
        double modeQty = 1;
        if (_itemModes != null && _selectedStockMode != null) {
          Map<String, dynamic>? selectedModeData;
          for (var entry in _itemModes!.entries) {
            final modeData = entry.value as Map<String, dynamic>?;
            if (modeData?['name'] == _selectedStockMode) {
              selectedModeData = modeData;
              break;
            }
          }
          if (selectedModeData != null) {
            // try several common keys for quantity-per-mode
            final dynamic qVal = selectedModeData['qty'] ?? 1;
            modeQty = (double.tryParse(qVal.toString()) ?? (qVal is double ? qVal.toDouble() : 1.0));

          }
        }

        final double pieces = modeQty * quantity;
        // If editing, compare with old pieces
        double oldPieces = 0;

        if (widget.headerData.containsKey('items')) {
          final oldItems = List<Map<String, dynamic>>.from(
            widget.headerData['items'] ?? [],
          );

          final oldItem = oldItems.cast<Map<String, dynamic>?>().firstWhere(
                (e) => e?['itemid'] == (_selectedItem?['id'] ?? ''),
            orElse: () => null,
          );

          if (oldItem != null) {
            oldPieces = (oldItem['pieces'] as num?)?.toDouble() ?? 0;
          }
        }

        print('New: $pieces, Old: $oldPieces');
        if (widget.headerData.containsKey('items')) {
          if (pieces > oldPieces) {
            final extraPieces = pieces - oldPieces;

            if (!_checkItemBalance(itembalance, extraPieces)) {
              return;
            }
          }
        } else {
          if (!_checkItemBalance(itembalance, pieces)) {
            return;
          }
        }

        // compute line amounts
        final double total = price * pieces;


        _items.add({
          'item': _itemController.text.trim(),
          'quantity': quantity,
          'price': price,
          'total': total,
          'transfermode': _selectedStockMode ?? '',
          'modeqty': modeQty,
          'pieces': pieces,
          'barcode': _barcodeController.text.trim(),
          'itemid': _selectedItem != null ? _selectedItem!['id'] ?? '' : '',
          'receivedquantity':0,
          'receivedpieces':0,
          'boxpieces':boxpieces
        });

        _itemController.clear();
        _quantityController.clear();
        _barcodeController.clear();
        _priceController.clear();
      });
    }
  }

  ({double gross}) _calculateTotals() {
    double baseTotal = 0.0;


    for (final it in _items) {
      final double price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final double qty = (it['pieces'] as double?) ?? 0;
      baseTotal += price * qty;
    }

    return (
    gross: baseTotal,

    );
  }
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final now = DateTime.now();
  int weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) / 7).ceil();
  }
Future updatebranch()async{

  final Map<String, dynamic> branchData = {

    'stocktransfer': true,
    'transferdate': Timestamp.fromDate(DateTime.now()),
  };
  final editbranchid=widget.headerData['recievebranchid'];

  await FirebaseFirestore.instance
      .collection('branches')
      .doc(editbranchid)
      .set(branchData,SetOptions(merge: true));
}

  bool _saved = false;
  Future<void> _saveRecords() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to save')),
      );
      return;
    }
    setState(() => _loading = true);
    final totals = _calculateTotals();
    final stockProvider = context.read<StockProvider>();
    String today = stockProvider.formatInvoiceDate(widget.headerData['transferdate']);


    final Map<String, dynamic> docData = {
      ...widget.headerData,
      'transactionid': widget.transactionId,
      'transferid': DateTime.now().millisecondsSinceEpoch.toString(),
      'items': _items,
      'gross': totals.gross,
      'status': 'pending',
      'date': today,
      'year': now.year.toString(), // 2026
      'month': '${now.year}.${now.month}', // 2026.5
      'week': '${now.year}.${weekNumber(now)}', // 2026.32
      'day': DateFormat('EEEE').format(now),
    };

    if (widget.headerData.containsKey('items'))
    {
      docData['editedat'] = FieldValue.serverTimestamp();
      docData['transferid'] = widget.headerData['transferid'] ?? 'unknown';
      docData['editedby'] =stockProvider.staff;


      final oldItems = List<Map<String, dynamic>>.from(
        widget.headerData['items'] ?? [],
      );

      final insufficientItems = <String>[];

      for (final oldItem in oldItems) {
        final itemId = oldItem['itemid'].toString();

        // Find edited item. If removed completely, assume 0 pieces.
        final newItem = _items.firstWhere(
              (e) => e['itemid'] == itemId,
          orElse: () => <String, dynamic>{
            'itemid': itemId,
            'item': oldItem['item'],
            'pieces': 0,
          },
        );

        final oldPieces =
        (oldItem['pieces'] ?? oldItem['receivedpieces'] ?? 0) as num;

        final newPieces =
        (newItem['pieces'] ?? newItem['receivedpieces'] ?? 0) as num;

        // Pieces that would be removed from the receiving branch
        final piecesToReverse = oldPieces.toDouble() - newPieces.toDouble();

        if (piecesToReverse > 0) {
          final availableBalance =
          await stockProvider.fetchItemCurrentBalance(
            itemId: itemId,
            selectedBranch: widget.headerData['recievebranchid'],
          );

          if (availableBalance < piecesToReverse) {
            insufficientItems.add(
              '${newItem['item']}\n'
                  'Available: ${availableBalance.toInt()} pcs\n'
                  'Trying to remove: ${piecesToReverse.toInt()} pcs',
            );
          }
        }
      }

      if (insufficientItems.isNotEmpty) {
        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cannot Edit Transfer'),
            content: SingleChildScrollView(
              child: Text(
                'The following items no longer have enough stock in '
                    '${widget.headerData['recievebranchname']} to reverse this edit:\n\n'
                    '${insufficientItems.join('\n\n')}',
              ),
            ),
            actions: [

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Ok"),
              ),
            ],
          ),
        );

        if (mounted) {
          setState(() => _loading = false);
        }

        return;
      }
    }
    try {

      await FirebaseFirestore.instance
          .collection('stock_transfer')
          .doc(widget.transactionId)
          .set(docData,SetOptions(merge: true));
         await updatebranch();

      if (!mounted) return;
      setState(() {
        _saved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Records saved ')),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }finally { if (mounted) setState(() => _loading = false);

    }

  }

  Future<void> _printRecords() async {
    final pdf = pw.Document();
    final totals = _calculateTotals();
    final transferDate = widget.headerData['createdat'];
    String transferDateStr = 'N/A';
    if (transferDate != null) {
      final dateTime = (transferDate as Timestamp).toDate();
      transferDateStr = DateFormat('dd/MM/yyyy').format(dateTime);
    }
    String fmtNum(dynamic v) {
      if (v == null || v.toString().isEmpty) return '-';
      if (v is int) return v.toString();
      if (v is double || v is num) return (v as num).toStringAsFixed(2);
      return v.toString();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {

          return <pw.Widget>[
            // Company name
            pw.Center(
              child: pw.Text(
                widget.headerData['company'] ?? 'COMPANY NAME',
                style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),

            // Title
            pw.Center(
              child: pw.Text(
                'TRANSFER INVOICE',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),

            // new thin divider between title and headerdata
            pw.SizedBox(height: 8),
            pw.Container(height: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),

            // Header section (no border)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [

                      pw.Text('Warehouse: ${widget.headerData['supplywarehousename'] ?? ''}', style: pw.TextStyle(fontSize: 14)),
                      pw.Text('Staff: ${widget.headerData['createdby'] ?? ''}', style: pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Recieving Branch: ${widget.headerData['recievebranchname'] ?? ''}', style: pw.TextStyle(fontSize: 14)),
                      pw.Text('Date: ${transferDateStr}', style: pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

            // thin divider between header and table
            pw.SizedBox(height: 12),
            pw.Container(height: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),

            // Manual table - borders enabled only here
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),   // #
                1: const pw.FlexColumnWidth(3.0),   // Item
                2: const pw.FlexColumnWidth(1.2),   // Mode
                3: const pw.FlexColumnWidth(0.9),   // Mode Qty (num)
                4: const pw.FlexColumnWidth(0.9),   // Pieces (num)
                5: const pw.FlexColumnWidth(0.9),   // Qty (num)
                6: const pw.FlexColumnWidth(1.2),   // Unit Price (num)
                8: const pw.FlexColumnWidth(1.4),   // Total (num)
              },
              children: [
                // header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Mode', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Mode Qty', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pieces', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Unit Price', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ],
                ),

                // data rows
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final it = entry.value;
                  final bool even = entry.key % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: even ? PdfColors.white : PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(idx.toString(), style: pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it['item']?.toString() ?? '-', style: pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it['transfermode']?.toString() ?? it['salesMode']?.toString() ?? '-', style: pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['modeqty'] ?? it['modeQty'] ?? ''), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['pieces'] ?? ''), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['quantity'] ?? ''), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['price'] ?? ''), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['total'] ?? ''), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 20),

            // Totals - right aligned, no border
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 260,
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                        pw.Text('Gross:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(fmtNum(totals.gross), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                      ]),

                      pw.Divider(),

                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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
        _formkey.currentState?.validate();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
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
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: Container(
                              color: const Color(0xFF182232),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "STOCK TRANSFER ENTRIES (${widget.headerData['supplywarehousename']}-${widget.headerData['recievebranchname']})",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Divider(color: Colors.white24),
                                    const SizedBox(height: 15),
                                    Form(
                                      key: _formkey,
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  controller: _barcodeController,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'Barcode',
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
                                                      ? 'Barcode required'
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF22304A),
                                                  borderRadius:
                                                  BorderRadius.circular(12),
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
                                                  tooltip: 'Scan Barcode/QR Code',
                                                ),
                                              ),
                                            ],
                                          ),

                                          if (_showSuggestions)
                                            StreamBuilder<List<Map<String, dynamic>>>(
                                              stream:Provider.of<Datafeed>(context, listen: false).itemsStream(collectionName: 'itemsreg'),
                                              builder: (context, snapshot) {
                                                if (!snapshot.hasData) {
                                                  return Container(
                                                    margin: const EdgeInsets.only(top: 4),
                                                    padding: const EdgeInsets.all(16),
                                                    child: const Center(
                                                      child: CircularProgressIndicator(
                                                        color: Colors.blue,
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  );
                                                }

                                                final allDocs = snapshot.data!;
                                                final filteredDocs = allDocs.where((doc) {
                                                  final data = doc as Map<String, dynamic>;
                                                  final name = (data['name'] ?? '').toString().toLowerCase();
                                                  final barcode = (data['barcode'] ?? '').toString().toLowerCase();
                                                  final query = _searchQuery.toLowerCase();
                                                  return name.contains(query) || barcode.contains(query);
                                                }).take(10).toList();

                                                if (filteredDocs.isEmpty) return const SizedBox.shrink();

                                                return Container(
                                                  margin: const EdgeInsets.only(top: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF22304A),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                                    boxShadow: const [
                                                      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                                                    ],
                                                  ),
                                                  constraints: const BoxConstraints(maxHeight: 250),
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: filteredDocs.length,
                                                    itemBuilder: (context, index) {
                                                      final doc = filteredDocs[index];
                                                      final item = doc as Map<String, dynamic>;
                                                      item['id'] = doc['id'];
                                                      final branchBalance =
                                                      (item['branchbalance'] as Map<String, dynamic>? ?? {});

                                                      final currentBranch =
                                                      (branchBalance[widget.headerData['supplywarehouseid']] as Map<String, dynamic>? ?? {});

                                                      final netPieces = currentBranch['netpieces'] ?? 0;

                                                      return ListTile(
                                                        dense: true,
                                                        leading: const Icon(Icons.inventory_2, color: Colors.blue, size: 20),
                                                        title: Text(
                                                          item['name'] ?? '',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        subtitle: Text(
                                                          'Barcode: ${item['barcode']} || Stock: $netPieces',
                                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                        ),
                                                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                                                        onTap: () => _selectItem(item,widget.headerData),
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: _itemController,
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              labelText: 'Item',
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
                                            ),
                                            validator: (value) => value == null || value.isEmpty ? 'Item required' : null,
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  value: _selectedStockMode,
                                                  dropdownColor: const Color(
                                                    0xFF22304A,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'Transfer Mode',
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
                                                  items: _stockMode.isEmpty ? null : _stockMode.map((type) {
                                                    return DropdownMenuItem<String>(value: type, child: Text(type));
                                                  }).toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedStockMode = value;
                                                      _updatePrice();
                                                    });
                                                  },
                                                  validator: (value) =>
                                                  value == null
                                                      ? 'Please select transfer mode'
                                                      : null,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: TextFormField(
                                                  readOnly: true,
                                                  controller: _priceController,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters:
                                                  [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                                  ],
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: 'Price',
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
                                                      ? 'Enter amount'
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: _quantityController,
                                            style: const TextStyle(color: Colors.white),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters:
                                            [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                            ],
                                            decoration: InputDecoration(
                                              labelText: 'Quantity',
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
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Enter quantity';
                                              }
                                              final qty = double.tryParse(value);
                                              if (qty == null) {
                                                return 'Quantity must be a number';
                                              }
                                              if (qty < 0.5) {
                                                return 'Quantity must be greater than 0.5';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(color: Colors.white24),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              if (!_saved)
                                                SizedBox(
                                                  width: 150,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.orangeAccent,
                                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    onPressed: _loading ? null : _addItem,
                                                    child: const Text(
                                                      "Add Record",
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              SizedBox(
                                                width: 150,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.lightBlue,
                                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _itemController.clear();
                                                      _priceController.clear();
                                                      _quantityController.clear();
                                                      _barcodeController.clear();

                                                    });
                                                  },

                                                  child: const Text("Reset", style: TextStyle(color: Colors.white)),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 150,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.teal,
                                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  onPressed: () {
                                                    widget.onNewTransaction();

                                                  },
                                                  child: const Text("New Transaction", style: TextStyle(color: Colors.white)),
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
                          isSmallScreen
                              ? MobileSalesPreview(
                            items: _items,
                            onPrint: _saveRecords,
                            onNewTransaction: _printRecords,
                            onDeleteItem: (index) {
                              setState(() {
                                _items.removeAt(index);
                              });
                            },
                            loading: _loading,
                          )

                              : _buildStockTable( itemWidth),


                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

      ],

    );

  }

  Widget _buildStockTable(double itemWidth) {
    return SizedBox(
      width: itemWidth,
      child: Container(
        color: const Color(0xFF182232),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TRANSFER PREVIEW",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 15),
              Table(
                border: TableBorder.all(color: Colors.grey),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1),
                  7: FlexColumnWidth(1), // extra column for delete
                },
                children: [
                  _tableRow([
                    "#",
                    "Item",
                    "Mode",
                    "Qty",
                    "Pieces",
                    "Unit Price",
                    "Total",
                    "Action"
                  ], isHeader: true),
                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final priceText = (item['price'] != null)
                        ? (item['price'] as double).toStringAsFixed(2)
                        : '0.00';
                    final totalText = (item['total'] != null)
                        ? (item['total'] as double).toStringAsFixed(2)
                        : '0.00';


                    return TableRow(
                      children: [
                        _cell((idx + 1).toString()),
                        _cell(item['item']?.toString() ?? ''),
                        _cell(item['transfermode']?.toString() ?? ''),
                        _cell(item['quantity']?.toString() ?? '0', alignRight: true),
                        _cell(item['pieces']?.toString() ?? '0', alignRight: true),
                        _cell(priceText, alignRight: true),
                        _cell(totalText, alignRight: true),
                        _saved
                            ? const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                        )
                            : Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Confirm Delete"),
                                  content: const Text("Are you sure you want to delete this item?"),
                                  actions: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white54),
                                      ),
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                setState(() {
                                  _items.removeAt(idx);
                                });
                              }
                            },
                          ),
                        )

                      ],
                    );
                  }).toList(),
                  (() {
                    return _tableRow(["", "", "", "", "", "", "",""]);
                  })(),
                  (() {
                    final totals = _calculateTotals();
                    return _tableRow([
                      "",
                      "Grand Total",
                      "",
                      "",
                      "",
                      "",
                      totals.gross!.toStringAsFixed(2),
                      ""
                    ]);
                  })(),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_saved)
                      SizedBox(
                        width: 150,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _loading
                                ? null
                                : () async {
                              setState(() => _loading = true);
                              await _saveRecords();
                              if (mounted) setState(() => _loading = false);
                            },
                            child: _loading
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                :
                            Text(
                              widget.headerData.containsKey('items') ? "UPDATE RECORDS" : "SAVE RECORDS",
                              style: const TextStyle(color: Colors.white),
                            )
                        ),
                      ),

                    const SizedBox(height: 12),

                    if (_saved)
                      SizedBox(
                        width: 150,
                        child: OutlinedButton.icon(
                          onPressed: ()async {
                            try {
                              final gross = _calculateTotals().gross;
                              final Hdata = {
                                ...widget.headerData,
                                'gross': gross.toDouble(),
                              };
                              await generateInvoicePdf(Hdata, _items);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error generating PDF: $e"), backgroundColor: Colors.red),
                              );
                            }
                          },
                          icon: const Icon(Icons.print),
                          label: const Text('PRINT'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.lightBlue),
                            foregroundColor: Colors.lightBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.asMap().entries.map((entry) {
        final index = entry.key;
        final text = entry.value;

        TextAlign align;
        if (isHeader) {
          align = TextAlign.center;
        } else if ([4, 5, 6, 7, 8].contains(index)) {
          align = TextAlign.right;
        } else {
          align = TextAlign.left;
        }

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            text,
            textAlign: align,
            style: const TextStyle(
              color: Colors.white,
            ).copyWith(fontWeight: isHeader ? FontWeight.bold : FontWeight.normal),
          ),
        );
      }).toList(),
    );
  }

  Widget _cell(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

}

class MobileSalesPreview extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback? onPrint;
  final VoidCallback? onNewTransaction;
  final void Function(int index)? onDeleteItem;
  final bool loading;
  const MobileSalesPreview({
    super.key,
    required this.items,
    this.onPrint,
    this.onNewTransaction,
    this.onDeleteItem,
    this.loading=false,
  });

  double get totalAmount {
    return items.fold(0.0, (sum, item) {
      return sum + (item['total'] ?? 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF182232),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Transfer Preview",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 20),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final item = items[index];

            try{
              return _cartItem(
                name: item['item'] ?? '',
                price: (item['price'] ?? 0.0).toDouble(),
                qty: double.tryParse(item['quantity'].toString()) ?? 0,
                pieces: double.tryParse(item['pieces'].toString()) ?? 0,
                mode: item['transfermode'] ?? "",
                total: (item['total'] ?? 0.0).toDouble(),
                onDelete: () => onDeleteItem?.call(index), // use callback
              );
            }catch(e){
              print(e);
              return Container();
            }

            },
          ),

          const Divider(color: Colors.white24),
          _row("Total", "GHC ${totalAmount.toStringAsFixed(2)}", bold: true),
          const SizedBox(height: 18),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _actionBtn("SAVE RECORDS", Colors.teal, onPrint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cartItem({
    required String name,
    required double price,
    required double qty,
    required double pieces,
    required String mode,
    required double total,
    required VoidCallback onDelete,
  }) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: onDelete,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(name, "GHC ${price.toStringAsFixed(2)}"),
              _line("Mode", mode),
              _line("Qty", "$qty"),
              _line("Total", "GHC ${total.toStringAsFixed(2)}"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String left, String right) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(right, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            )),
        Text(value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            )),
      ],
    );
  }

  Widget _actionBtn(String text, Color color, VoidCallback? onTap) {
    return ElevatedButton( style: ElevatedButton.styleFrom( backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), ),
      onPressed: loading ? null : onTap,
      child: loading ? const SizedBox( height: 16, width: 16, child: CircularProgressIndicator( strokeWidth: 2, color: Colors.white, ), ) : Text(text, style: const TextStyle(fontSize: 12, color: Colors.white)), ); }

}
