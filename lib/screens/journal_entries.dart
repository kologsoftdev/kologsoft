import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/journalentrymodel.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/routes.dart';

class JournalEntries extends StatefulWidget {
  final JournalEntryModel? journal;
  const JournalEntries({super.key, this.journal});

  @override
  State<JournalEntries> createState() => _JournalEntriesState();
}

class _JournalEntriesState extends State<JournalEntries> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  String? _selectedTransType;
  final List<String> _TransTypes = [
    'Main Journal',
    'Debtors Journal Entry',
    'Debtors Payment Journal Entry',
    'Creditors or Credit Purchase Journal',
    'Creditors or Credit Payment Journal'
  ];

  List<String> _accounts = [];
  String? _selectedCreditAccount;
  String? _selectedDebitAccount;
  bool _isSaving = false;
  // bool _loadingAccounts = false;
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final now = DateTime.now();
  int weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) / 7).ceil();
  }
  Future<void> _saveJournal()async{
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final datafeed = context.read<Datafeed>();
      final transType= _selectedTransType;
      final creditAcc= _selectedCreditAccount;
      final debitAcc= _selectedDebitAccount;
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final debtDate = _dateController.text;
      final companyId = datafeed.companyid;
      final branchId = datafeed.branchid;
      final branchName = datafeed.branch;
      
      // Parse the date string (YYYY-MM-DD format)
      final DateTime parsedDate = DateTime.parse(debtDate);
      
      //final docId = '${companyId}_$transType'.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final docId = '${companyId}_${DateTime.now().millisecondsSinceEpoch}${datafeed.staffPosition}';
      final journals = JournalEntryModel(
        id: widget.journal?.id ?? docId,
        journalType: "journal entry",
        amount: double.parse(_amountController.text.trim()),
        staff: datafeed.staff,
        branchName: branchName,
        branchId: branchId,
        companyid: companyId,
        creditAccount: creditAcc!,
        debitAccount: debitAcc!,
        narration: _refController.text.trim(),
        date: parsedDate,
        dateymd: DateFormat('yyyy-MM-dd').format(parsedDate),
        year: parsedDate.year.toString(),
        month: '${parsedDate.year}.${parsedDate.month}',
        week: '${parsedDate.year}.${weekNumber(parsedDate)}',
        day: DateFormat('EEEE').format(parsedDate),
    );

      // Save to Firestore
      if (widget.journal == null) {
        // New expense: set doc id to companyid+expensename
        await datafeed.db.collection('journal').doc(docId).set(journals.toMap());
      } else {
        // Existing expense: update by id
        await datafeed.db
            .collection('journal')
            .doc(journals.id)
            .update(journals.toMap());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.journal == null
                  ? 'saved successfully'
                  : 'updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to journal view after successful save
        Navigator.pop(context);

        _amountController.clear();

      }
    }catch(e){
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.journal != null) {
      _amountController.text = widget.journal!.amount.toString();
      _selectedCreditAccount = widget.journal!.creditAccount;
      _selectedDebitAccount = widget.journal!.debitAccount;
      _refController.text = widget.journal!.narration;
      _dateController.text = widget.journal!.dateymd;
    } else {
      _dateController.text = today;
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      final datafeed = context.read<Datafeed>();
      final snap = await datafeed.db
          .collection('accounts')
          .where('companyId', isEqualTo: datafeed.companyid)
          .get();
      setState(() {
        _accounts = snap.docs.map((doc) => doc['name'].toString()).toList();
      });
    } catch (e) {
      setState(() {
        _accounts = [];
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
        builder: (BuildContext context, Datafeed value, Widget? child){
          return Scaffold(
            backgroundColor: const Color(0xFF101A23),
            appBar: AppBar(
              title: Text(
                widget.journal != null
                    ? 'EDIT JOURNAL ENTRIES'
                    : 'JOURNAL ENTRIES',
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

                                // const SizedBox(height: 14),
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
                                _buildDropdown(
                                  label: "Credit Account",
                                  value: _selectedCreditAccount,
                                  items: _accounts,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCreditAccount = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),
                                _buildDropdown(
                                  label: "Debit Account",
                                  value: _selectedDebitAccount,
                                  items: _accounts,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDebitAccount = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _refController,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Narration',
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    prefixIcon: Icon(Icons.notes, color: Colors.white70),
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
                                    suffixIcon: Icon(Icons.calendar_today, color: Colors.white70),
                                  ),
                                  onTap: () async {
                                    FocusScope.of(context).requestFocus(FocusNode());
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (pickedDate != null) {
                                      _dateController.text =
                                      "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                                    }
                                  },
                                  validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Select date'
                                      : null,
                                ),
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
                                        onPressed: _isSaving? null: _saveJournal,
                                        child: _isSaving
                                            ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                            : Text(
                                          widget.journal == null
                                              ? 'Save'
                                              : 'Update',
                                          style: const TextStyle(fontSize: 16, color: Colors.white),
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
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          "Back",
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
        }
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
        fillColor: const Color(0xFF22304A),
        filled: true,
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
