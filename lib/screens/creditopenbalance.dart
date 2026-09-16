

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/creditorbalanceModel.dart';
import 'creditopenbalancelist.dart';


class _C {
  static const bg       = Color(0xFF0F1117);
  static const surface  = Color(0xFF1A1D27);
  static const card     = Color(0xFF1F2333);
  static const header   = Color(0xFF0D1A26);
  static const divider  = Color(0xFF2C2F3E);
  static const primary  = Color(0xFF3B82F6);
  static const positive = Color(0xFF22C55E);
  static const negative = Color(0xFFEF4444);
  static const warning  = Color(0xFFF59E0B);
  static const textPri  = Color(0xFFE2E8F0);
  static const textSub  = Color(0xFF94A3B8);
  static const textMuted= Color(0xFF4B5563);
}


class creditOpenBalScreen extends StatefulWidget {

  final String? docId;
  final CreditorBalance? item;
  const creditOpenBalScreen({Key? key, this.docId, this.item,}) : super(key: key);

  @override
  State<creditOpenBalScreen> createState() => _creditOpenBalScreenState();
}

class _creditOpenBalScreenState extends State<creditOpenBalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // Supplier searchable dropdown
  final _supplierSearchCtrl = TextEditingController();
  final _supplierFocusNode  = FocusNode();
  bool _showSupplierList    = false;

  DateTime? _selectedDate;
  String? _selectedcreditor;
  String? _selectedcreditorname;
  bool _isloading =false;
  double? _oldAmount;
  String? _docId;
  final db =FirebaseFirestore.instance;
  DateTime now = DateTime.now();
  late String year = now.year.toString();
  late String month = now.month.toString();
  late String day = now.day.toString();

  void showMessage(BuildContext context, Color color, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,style: TextStyle(color: Colors.white),),
        backgroundColor: color,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      if (!mounted) return;
      final datafeed = context.read<Datafeed>();
      await datafeed.fetchSuppliers();

      //  PREFILL AFTER DATA LOAD
      if (widget.item != null) {
        final item = widget.item!;
        _docId = widget.docId;
        _oldAmount = item.amount;
        _selectedcreditor     = item.creditorId;
        _selectedcreditorname = item.creditorName;
        _supplierSearchCtrl.text = item.creditorName;

        _amountCtrl.text = item.amount.toString();

        _selectedDate = item.date;
        _dateController.text =
        "${item.date?.year}-${item.date?.month.toString().padLeft(2, '0')}-${item.date?.day.toString().padLeft(2, '0')}";

        if (mounted) setState(() {});
      }
    });
  }
  @override
  void dispose() {
    _amountCtrl.dispose();
    _supplierSearchCtrl.dispose();
    _supplierFocusNode.dispose();
    super.dispose();
  }

  void _save() async {
    bool isEmpty = _selectedcreditor == null || _selectedcreditor!.isEmpty;
    final datafeed = context.read<Datafeed>();
    if (_isloading) return;

    if (!_formKey.currentState!.validate()) return;

    if (isEmpty) {
      if (!mounted) return;
      showMessage(context,Colors.red, 'Please select creditor');
      return;
    }

    if (_selectedDate == null) {
      if (!mounted) return;
      showMessage(context,Colors.red, 'Please select date');
      return;
    }

    setState(() => _isloading = true );

    try {
      String sanitize(String input) => input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^a-z0-9_]'), '');

      final newAmount = double.tryParse(_amountCtrl.text) ?? 0;
      final isEdit   = widget.docId != null;

      final docId = widget.docId ??
              '${sanitize(_selectedcreditor!)}_'
              '${DateTime.now().millisecondsSinceEpoch}';

      final balanceDoc  = db.collection('creditor_balances').doc(docId);
      final supplierDoc = db.collection('suppliers').doc(_selectedcreditor);
      String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now = DateTime.now();
      final day = DateFormat('EEEE').format(now);
      final year = now.year.toString();
      final month = '${now.year}.${now.month}';
      final weekNumber =
          ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

      final week = '${now.year}.$weekNumber';

      final item = CreditorBalance(
        creditorId:_selectedcreditor!,
        amount:newAmount,
        date: _selectedDate ?? DateTime.now(),
        companyid:datafeed.companyid,
        company:datafeed.company,
        companyemail:datafeed.companyemail,
        staff: datafeed.staff,
        branchid: datafeed.branchid,
        branchname:datafeed.branch,
        id: docId,
        datecreated:Timestamp.fromDate(DateTime.now()),
        updatedby: isEdit ? datafeed.staff : '',
        updatedat: isEdit ? DateTime.now() : null,
        creditorName: _selectedcreditorname!,
        paymentMode: '',
        transactionRef: '${sanitize(_selectedcreditorname!)}_${DateTime.now().millisecondsSinceEpoch}',
        type: 'creditor opening balance ',
        dateymd: formattedDate,
        day: day,
        week: week,
        month: month,
        yearr: year,
      );


      await db.runTransaction((txn) async {

        double creditDelta;
        if (isEdit) {

          final snap        = await txn.get(balanceDoc);
          final liveOldAmount =
          snap.exists ? ((snap.data()?['amount'] ?? 0) as num).toDouble() : 0.0;
          creditDelta = newAmount - liveOldAmount;
        } else {
          creditDelta = newAmount;
        }

        txn.set(balanceDoc, item.toMap());
        if (creditDelta != 0) {
          txn.update(supplierDoc, {
            'creditaccount': FieldValue.increment(creditDelta),
          });
        }
      });

      if (!mounted) return;

      _amountCtrl.clear();
      _dateController.clear();
      setState(() {
        _selectedcreditor = null;
        _selectedDate     = null;
        _isloading        = false;
      });



      showMessage(context, Colors.green, isEdit ? 'Updated successfully' : 'Saved successfully');
    }
    catch (e) {
      if (!mounted) return;
      setState(() => _isloading = false);
      showMessage(context, Colors.red, 'Error: $e',);
    }
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
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, _) {

        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            backgroundColor: _C.header,
            elevation: 0,
            titleSpacing: 0,
            leading: const BackButton(color: _C.textPri),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text('Creditor Balance',
                    style: TextStyle(
                        color: _C.textPri,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),

              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.home, size: 25),
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _C.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _C.primary.withOpacity(0.25), width: 1),
                    ),
                    child: Text(
                      datafeed.company,
                      style: const TextStyle(
                          color: _C.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],

          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [

                      SizedBox(height: 14,),

                      // ── Searchable supplier dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search input — acts as the "dropdown trigger"
                          TextFormField(
                            controller: _supplierSearchCtrl,
                            focusNode:  _supplierFocusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              label: 'Creditor',
                              prefix: Icons.person_search,
                              hint: 'Search supplier…',
                              suffix: _selectedcreditor != null
                                  ? IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white54, size: 18),
                                onPressed: () => setState(() {
                                  _selectedcreditor     = null;
                                  _selectedcreditorname = null;
                                  _supplierSearchCtrl.clear();
                                  _showSupplierList = false;
                                }),
                              )
                                  : const Icon(Icons.arrow_drop_down,
                                  color: Colors.white54),
                            ),
                            onTap: () => setState(() => _showSupplierList = true),
                            onChanged: (_) => setState(() {
                              _selectedcreditor     = null;
                              _selectedcreditorname = null;
                              _showSupplierList     = true;
                            }),
                            validator: (_) => _selectedcreditor == null
                                ? 'Select creditor'
                                : null,
                          ),

                          // Filtered list — visible only when searching
                          if (_showSupplierList) Builder(builder: (context) {
                            final query = _supplierSearchCtrl.text.toLowerCase();
                            final filtered = datafeed.suppliers.where((s) =>
                                s.supplier.toLowerCase().contains(query)).toList();

                            if (filtered.isEmpty) {
                              return Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22304A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Text('No supplier found',
                                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                              );
                            }

                            return Container(
                              margin: const EdgeInsets.only(top: 4),
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22304A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final s = filtered[i];
                                  final isSelected = s.id == _selectedcreditor;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedcreditor     = s.id;
                                        _selectedcreditorname = s.supplier;
                                        _supplierSearchCtrl.text = s.supplier;
                                        _showSupplierList = false;
                                      });
                                      _supplierFocusNode.unfocus();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      color: isSelected
                                          ? _C.primary.withOpacity(0.15)
                                          : Colors.transparent,
                                      child: Row(children: [
                                        if (isSelected)
                                          const Icon(Icons.check,
                                              color: _C.primary, size: 16),
                                        if (isSelected)
                                          const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            s.supplier,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? _C.primary
                                                  : Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ]),
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ),


                      SizedBox(height: 14,),
                      TextFormField(
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        controller: _amountCtrl,
                        cursorColor: Colors.white,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),

                        decoration: InputDecoration(
                          hintText: 'Enter amount',

                          hintStyle: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          prefixIcon: const Icon(Icons.attach_money,
                              color: _C.textSub, size: 20),
                          suffixIcon: _amountCtrl.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.close,
                                color: _C.textSub, size: 18),
                            onPressed: () {
                              _amountCtrl.clear();
                              datafeed.searchQuery = '';
                              datafeed.notifyListeners();
                            },
                          )
                              : null,
                          filled: true,
                          fillColor: Color(0xFF22304A),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: _C.primary, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Enter valid number';
                          }
                          if(double.parse(value) <= 0) {
                            return 'Amount must be greater than zero';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 14,),
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
                          DateTime?
                          picked = await showDatePicker(
                            context: context,
                            initialDate:
                            _selectedDate ??
                                DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme:
                                  const ColorScheme.dark(
                                    primary: Colors.blue,
                                    onPrimary:
                                    Colors.white,
                                    surface: Color(
                                      0xFF22304A,
                                    ),
                                    onSurface:
                                    Colors.white,
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
                        validator: (value) =>
                        value == null || value.isEmpty
                            ? 'Select date'
                            : null,
                      ),
                      Container(height: 1, color: _C.divider),
                      SizedBox(height: 20,),
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isloading ? null : _save,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isloading
                                    ? const SizedBox(
                                  key: ValueKey('loader'),
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    :  Text(widget.item != null ? "Update Record" :
                                "Save Record",
                                  key: ValueKey('text'),
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: Colors.white70)
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const creditOpenBalViewPage(),
                                  ),
                                );
                              },
                              child: Text(
                                "View Creditors",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}