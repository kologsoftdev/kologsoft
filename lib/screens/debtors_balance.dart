import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/debtorsbalmodel.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/routes.dart';

class DebtorsBalance extends StatefulWidget {
  final DebtorsBalModel? debtors;
  const DebtorsBalance({super.key, this.debtors});

  @override
  State<DebtorsBalance> createState() => _DebtorsBalanceState();
}


class _DebtorsBalanceState extends State<DebtorsBalance> {
    bool _isSaving = false;

    Future<void> _saveDebtorBalance() async {
      if (!_formKey.currentState!.validate()) return;
      setState(() {
        _isSaving = true;
      });
      try {
        final datafeed = context.read<Datafeed>();
        final debtorName = _selectedDebtor;
        final amount = double.tryParse(_amountController.text) ?? 0.0;
        final debtDate = _dateController.text;
        final companyId = datafeed.companyid;
        final branchId = datafeed.branchid;
        final branchName = datafeed.branch;

        // Find customer by name
        final customerQuery = await datafeed.db
            .collection('customers')
            .where('name', isEqualTo: debtorName)
            .limit(1)
            .get();
        if (customerQuery.docs.isEmpty) {
          throw Exception('Customer not found');
        }
        final customerDoc = customerQuery.docs.first;
        final customerData = customerDoc.data();
        final customerContact = customerData['contact']?.toString() ?? '';
        final docId = '${companyId}_$customerContact';

        final debt = DebtorsBalModel(
          id: widget.debtors?.id ?? docId,
          name: debtorName,
          amount: amount.toString(),
          staff: datafeed.staff,
          companyid: companyId,
          branchId: branchId,
          branchName: branchName,
          activityType: 'debtor opening balance',
          companyemail: datafeed.companyemail,
          date: widget.debtors?.date ?? DateTime.tryParse(_dateController.text) ?? DateTime.now(),
          updatedat: DateTime.now(),

        );


        double currentCredit = double.tryParse(customerData['creditBalance']?.toString() ?? '0') ?? 0.0;
        double oldAmount = 0.0;
        if (widget.debtors != null) {
          // Editing: get the previous amount
          oldAmount = double.tryParse(widget.debtors!.amount) ?? 0.0;
        }

        // Save debtor balance
        if (widget.debtors == null) {
          await datafeed.db.collection('debtorsbalance').doc(docId).set(debt.toMap());
        } else {
          await datafeed.db
              .collection('debtorsbalance')
              .doc(debt.id)
              .update(debt.toMap());
        }

        // Update creditBalance in customers collection
        // If editing, subtract old amount and add new amount
        final newCredit = currentCredit - oldAmount + amount;
        await datafeed.db
            .collection('customers')
            .doc(customerDoc.id)
            .update({'creditBalance': newCredit});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.debtors == null
                    ? 'saved successfully'
                    : 'updated successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _amountController.clear();
          _dateController.clear();
          setState(() {
            _selectedDebtor = '';
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add debtor balance: \n${e.toString()}')),
        );
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  String _selectedDebtor = '';

  List<String> _debtors = [];
  bool _isLoadingDebtors = false;

  @override
  void initState() {
    super.initState();
    //_loadPaymentAccounts();
    if (widget.debtors != null) {
      _amountController.text = widget.debtors!.amount;
      _dateController.text = widget.debtors!.date.toString();
      _selectedDebtor = widget.debtors!.name;
      //_populateForm();
    }
    _fetchDebtors();
  }

  void _fetchDebtors() async {
    setState(() {
      _isLoadingDebtors = true;
    });
    try {
      final datafeed = context.read<Datafeed>();
      final accessLevel = datafeed.accesslevel.toLowerCase();
      final companyId = datafeed.companyid;
      final branchId = datafeed.branchid;
      var query = datafeed.db.collection('customers').where('companyid', isEqualTo: companyId);
      if (accessLevel != 'super admin' && branchId.isNotEmpty) {
        query = query.where('branchid', isEqualTo: branchId);
      }
      final snapshot = await query.get();
      final names = snapshot.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      setState(() {
        _debtors = names;
      });
    } catch (e) {
      // Optionally handle error
    } finally {
      setState(() {
        // _isLoadingCategories = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text(
              widget.debtors != null
                  ? 'EDIT DEBTORS BALANCE'
                  : 'DEBTORS BALANCE',
            ),
            backgroundColor: const Color(0xFF0D1A26),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [

                      const SizedBox(height: 8),
                      Card(
                        color: const Color(0xFF182232),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildDropdown(
                                label: "Debtors",
                                value: _selectedDebtor.isEmpty
                                    ? null
                                    : _selectedDebtor,
                                items: _debtors,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDebtor = value ?? '';
                                  });
                                },
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _amountController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Amount',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                    ),
                                  ),
                                  fillColor: const Color(0xFF22304A),
                                  filled: true,
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Enter amount'
                                        : null,
                              ),

                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Date',
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
                                  suffixIcon: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white70,
                                  ),
                                ),
                                onTap: () async {
                                  FocusScope.of(context).unfocus();

                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
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
                                          textButtonTheme: TextButtonThemeData(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );

                                  if (pickedDate != null) {
                                    _dateController.text =
                                    "${pickedDate.year}-"
                                        "${pickedDate.month.toString().padLeft(2, '0')}-"
                                        "${pickedDate.day.toString().padLeft(2, '0')}";
                                  }
                                },
                                validator: (value) =>
                                value == null || value.isEmpty ? 'Select date' : null,
                              ),
                              // TextFormField(
                              //   controller: _dateController,
                              //   readOnly: true,
                              //   style: const TextStyle(color: Colors.white),
                              //   decoration: InputDecoration(
                              //     labelText: 'Date',
                              //     labelStyle: const TextStyle(color: Colors.white70),
                              //     border: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //     ),
                              //     enabledBorder: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //       borderSide: const BorderSide(color: Colors.white24),
                              //     ),
                              //     focusedBorder: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //       borderSide: const BorderSide(color: Colors.blue),
                              //     ),
                              //     fillColor: const Color(0xFF22304A),
                              //     filled: true,
                              //     suffixIcon: Icon(Icons.calendar_today, color: Colors.white70),
                              //   ),
                              //   onTap: () async {
                              //     FocusScope.of(context).requestFocus(FocusNode());
                              //     DateTime? pickedDate = await showDatePicker(
                              //       context: context,
                              //       initialDate: DateTime.now(),
                              //       firstDate: DateTime(2000),
                              //       lastDate: DateTime(2100),
                              //     );
                              //     if (pickedDate != null) {
                              //       _dateController.text =
                              //           "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                              //     }
                              //   },
                              //   validator: (value) =>
                              //       value == null || value.isEmpty
                              //           ? 'Select date'
                              //           : null,
                              // ),
                              const SizedBox(height: 30),
                              Wrap(
                                spacing: 15,
                                runSpacing: 15,
                                children: [
                                  SizedBox(
                                    width: 200,
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
                                      onPressed: _isSaving ? null : _saveDebtorBalance,
                                      child: Text(
                                        widget.debtors != null ? 'Update' : 'Add',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 200,
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
                                        Navigator.pushNamed(context, Routes.debtorBalView);
                                      },
                                      child: Text(
                                        "View Debtors",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
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
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF182232),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
      dropdownColor: const Color(0xFF182232),
      style: const TextStyle(color: Colors.white),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select $label';
        }
        return null;
      },
    );
  }
}
