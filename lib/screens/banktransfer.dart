import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/banktransfermodel.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class Banktransfer extends StatefulWidget {
  final String? docId;
  final BankTransferModel? data;


  const Banktransfer({Key? key, this.docId, this.data, }) : super(key: key);

  @override
  State<Banktransfer> createState() => _BanktransferState();
}

class _BanktransferState extends State<Banktransfer> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _narationController = TextEditingController();
  final _dateCtrl   = TextEditingController();
  String? _transferaccount;
  String? _transferaccountid;
  String? _receivingaccount;
  String? _receivingaccountid;
  DateTime? _selecteddate;
 String? _selectedBranch;
 String? _branchname;
  bool _loading = false;


  final FirebaseFirestore _db = FirebaseFirestore.instance;
  void showMessage(BuildContext context, Color color, String message) {
    if (!context.mounted) return;
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
    Future.microtask((){
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().getAllAccounts();
    });

    if (widget.data != null) {
      final d = widget.data!;
      _narationController.text = d.narration!;
      _amountController.text = d.amount;
      _transferaccount =d.transferAccount;
      _transferaccountid =d.transferAccountid;
      _receivingaccount =d.receivingAccount;
      _receivingaccountid =d.receivingAccountid;
      _selecteddate = d.date;
        _selectedBranch =d.branchId;
        _branchname =d.branchName;

      if (d.date != null) {
        _selecteddate = d.date;
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(d.date!);
      }
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color(0xFF415A77),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateCtrl.text =
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _selecteddate = picked;
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: Text(widget.docId == null ? 'Transfer to Bank' : 'Update Transfer to Bank'),
            actions: [
              IconButton(
                icon: const Icon(Icons.home, size: 25),
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
              ),

            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedBranch,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF22304A),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Select Branch',
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
                        items: datafeed.branches.where((branch) => branch.branchtype != 'Warehouse').map((branch) {
                          return DropdownMenuItem<String>(
                            value: branch.id,
                            child: Text(branch.branchname),
                          );
                        }).toList(),
                        onChanged: (val) {setState(() {
                          _selectedBranch = val!;
                          _branchname=datafeed.branches.firstWhere((b)=>b.id == val).branchname;
                        });


                        },
                      ),
                       SizedBox(height: 10),
                      SizedBox(
                        child: _buildField(
                          _amountController,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'),
                            ),
                          ],
                          'Enter amount',
                          Icons.attach_money,
                          isNumber: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }

                            final value = double.tryParse(v);

                            if (value == null) {
                              return 'Enter a valid number';
                            }

                            if (value < 0) {
                              return 'Amount must be greater than 0';
                            }

                            return null;
                          },
                          onChanged: (value) {

                           // _formKey.currentState?.validate();
                          },
                        ),
                      ),

                      const SizedBox(height: 10),
                      SizedBox(
                       child: _buildField(_narationController, 'Naration', Icons.notes)),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _transferaccountid,
                        dropdownColor: const Color(0xFF22304A),
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildDropdownDecoration('Transfer account'),
                        items: datafeed.accountList
                            .map((m) => DropdownMenuItem<String>(
                          value: m.id,
                          child: Text(m.name),
                        )).toList(),
                        onChanged: (v){
                          final selected =datafeed.accountList.firstWhere((e)=>e.id ==v);
                          setState(() {
                            _transferaccount =selected.name;
                            _transferaccountid =selected.id;
                          });
                        },

                        validator: (v) => v == null ? 'Select Transfer account' : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _receivingaccountid,
                        dropdownColor: const Color(0xFF22304A),
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildDropdownDecoration('Receiving account'),
                        items: datafeed.accountList
                            .map((m) => DropdownMenuItem<String>(
                          value: m.id,
                          child: Text(m.name),
                        ))
                            .toList(),
                        onChanged: (v) {
                          final selected = datafeed.accountList.firstWhere((e) => e.id == v);
                          setState(() {
                          _receivingaccount =selected.name;
                          _receivingaccountid =selected.id;
                          });
                        },
                        validator: (v) => v == null ? 'Select receiving account' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _dateCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildDropdownDecoration('dd / mm / yyyy'),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Date is required' : null,
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        children: [
                          SizedBox(
                            width: 180,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _loading
                                  ? null
                                  : () async {
                                if (!_formKey.currentState!.validate()) return;

                                // Prevent same account transfer
                                if (_transferaccount == _receivingaccount) {
                                  showMessage(context, Colors.red, 'Transfer and Receiving accounts cannot be the same');

                                  return;
                                }

                                setState(() => _loading = true);

                                final docid = datafeed.normalizeAndSanitize("${datafeed.companyid}-${datafeed.staffPosition}-${DateTime.now().millisecondsSinceEpoch}");

                                try {
                                  final id = widget.docId ?? docid;
                                  String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

                                  // Check if exists
                                  if (widget.docId == null) {
                                    final existing = await _db.collection(
                                        'banktransfers').doc(id).get();

                                    if (existing.exists) {
                                      showMessage(context, Colors.red,
                                          'Transfer already exists');
                                      return;
                                    }
                                  }

                                  final now = DateTime.now();

                                  final day = DateFormat('EEEE').format(now);

                                  final year = now.year.toString();

                                  final month = '${now.year}.${now.month}';

                                  final weekNumber =
                                      ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

                                  final week = '${now.year}.$weekNumber';
                                  // Build model
                                  final model = BankTransferModel(
                                    id: id,
                                    date: _selecteddate,
                                    createdAt: DateTime.now(),
                                    branchName: _branchname?? datafeed.branch,
                                    branchId: _selectedBranch?? datafeed.branchid,
                                    transferAccount: _transferaccount,
                                    transferAccountid: _transferaccountid,
                                    receivingAccount: _receivingaccount,
                                    receivingAccountid: _receivingaccountid,
                                    narration: _narationController.text.trim(),
                                    amount: _amountController.text.trim(),
                                    companyId: datafeed.companyid,
                                    staff: datafeed.staff,
                                    dateymd: formattedDate,
                                    updatedAt: widget.docId != null ?DateTime.now(): null,
                                    updatedBy: widget.docId != null ? datafeed.staff: null,

                                    day: day,
                                    week: week,
                                    month: month,
                                    year: year,
                                  );

                                  //Save
                                  await _db.collection('banktransfers').doc(id).set(model.toMap());
                                  final index = datafeed.bankTransferList.indexWhere((e) => e.id == id);
                                  if (index != -1) {
                                    datafeed.bankTransferList[index] = model;
                                  } else {
                                    datafeed.bankTransferList.add(model);
                                  }
                                  datafeed.notifyListeners();
                                  showMessage(context, Colors.green,
                                    widget.docId == null
                                        ? 'Transfer Saved Successfully'
                                        : 'Transfer Updated Successfully',);
                                  if (!mounted) return;
                                  if (widget.docId != null && widget.docId!.isNotEmpty){
                                    Navigator.pop(context);
                                    _amountController.clear();
                                    _narationController.clear();
                                    _dateCtrl.clear();
                                    setState(() {
                                      _receivingaccount = null;
                                      _receivingaccountid = null;
                                      _transferaccount = null;
                                      _transferaccountid = null;
                                    });
                                }
                                 else{
                                    _amountController.clear();
                                    _narationController.clear();
                                    _dateCtrl.clear();
                                    setState(() {
                                      _receivingaccount = null;
                                      _receivingaccountid = null;
                                      _transferaccount = null;
                                      _transferaccountid = null;
                                    });

                                  }
                                } catch (e) {

                                  showMessage(context, Colors.red, e.toString());

                                } finally {
                                  if (mounted) {
                                    setState(() => _loading = false);
                                  }
                                }
                              },
                              child: _loading
                                  ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Saving...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.docId == null
                                        ? 'Save'
                                        : 'Update',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
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
                                Navigator.pushNamed(context, Routes.banktransferview);
                              },
                              child:  Text("View",style: TextStyle(color: Colors.white),),
                            ),
                          ),
                        ],
                      )

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



  TextFormField _buildField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isNumber = false,
        TextInputType? keyboardType,
        Function(String)? onChanged,
        String? Function(String?)? validator,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return TextFormField(
      controller: controller,

      keyboardType:
      keyboardType ??
          (isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : null),

      style: const TextStyle(color: Colors.white70),
      validator: validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
      decoration: _inputDecoration(label, icon),
      onChanged: onChanged,
      inputFormatters: inputFormatters,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF22304A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue),
      ),
    );
  }

  InputDecoration _buildDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF22304A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}