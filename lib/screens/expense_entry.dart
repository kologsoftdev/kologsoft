import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/expense_entry_model.dart';
import 'package:kologsoft/models/sub_account_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:provider/provider.dart';

class ExpenseEntry extends StatefulWidget {
  final ExpenseEntryModel? expense;

  const ExpenseEntry({super.key, this.expense});

  @override
  State<ExpenseEntry> createState() => _ExpenseEntryState();
}

class _ExpenseEntryState extends State<ExpenseEntry> {
  final _formKey = GlobalKey<FormState>();
  final _expenseNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiptNumberController = TextEditingController();
  final _vendorNameController = TextEditingController();

  String _selectedCategory = '';
  String _selectedPaymentMethod = '';
  //SubAccountModel? _selectedAccount;
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;
  //List<SubAccountModel> _paymentAccounts = [];
  //Map<String, dynamic>? _selectedAccount;
  String? _selectedAccount;
  List<String> _linkedAccounts = [];
  String method="";
  List<String> _categories = [];
  bool _isLoadingCategories = false;

  List<String> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  Map<String,List<String>> linkedAccounts={};

  bool _isLoadingLinkedAccounts = false;

  @override
  void initState() {
    super.initState();
    //_loadPaymentAccounts();
    if (widget.expense != null) {
      _populateForm();
    }
    _fetchExpenseCategories();
    _fetchPaymentMethods();
  }

  void _fetchPaymentMethods() async {
    try {
      final datafeed = context.read<Datafeed>();
      final snapshot = await datafeed.db.collection('paymentaccounts').where('companyId', isEqualTo: datafeed.companyid).get();


      for (var doc in snapshot.docs) {
        final map = doc.data();

         method = map['paymentMethod']?.toString() ?? '';
        final accounts = List<String>.from(map['linkedAccounts'] ?? []);

        if (method.isNotEmpty) {
          linkedAccounts[method] = accounts;
        }
      }
      print(linkedAccounts.keys);

    } catch (e) {
      // Optionally handle error
    } finally {
      setState(() {
        //_isLoadingPaymentMethods = false;
      });
    }
  }

  void _fetchLinkedAccounts(String paymentMethod) async {
    setState(() {
      _isLoadingLinkedAccounts = true;
      _linkedAccounts = [];
      _selectedAccount = null;
    });

    try {
      final datafeed = context.read<Datafeed>();

      final snapshot = await datafeed.db
          .collection('paymentaccounts')
          .where('paymentMethod', isEqualTo: paymentMethod)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final linked = data['linkedAccounts'];

        if (linked is List) {
          _linkedAccounts = linked.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading linked accounts: $e");
    }

    setState(() {
      _isLoadingLinkedAccounts = false;
    });
  }

  void _fetchExpenseCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final datafeed = context.read<Datafeed>();
      final snapshot = await datafeed.db
          .collection('accounts').where('companyId', isEqualTo: datafeed.companyid)
          .where('accountClass', isEqualTo: 'Expense')
          .get();
      final names = snapshot.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      setState(() {
        _categories = names;
      });
    } catch (e) {
      // Optionally handle error
    } finally {
      setState(() {
       // _isLoadingCategories = false;
      });
    }
  }


  void _populateForm() {
    final expense = widget.expense!;
    _expenseNameController.text = expense.expenseName;
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toString();
    _receiptNumberController.text = expense.receiptNumber;
    _vendorNameController.text = expense.vendorName;
    _selectedCategory = expense.category;
    _selectedPaymentMethod = expense.paymentMethod;
    _expenseDate = expense.expenseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _receiptNumberController.dispose();
    _vendorNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _expenseDate) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPaymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final datafeed = context.read<Datafeed>();
      final expenseName = _expenseNameController.text.trim();
      final companyid = datafeed.companyid;
      final companyName = datafeed.company;
      final branchid = datafeed.branchid;
      final staffPosition = datafeed.staffPosition;
      final branchName = datafeed.branch;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final docId = '${companyid}_${expenseName}_${staffPosition}_$timestamp'.toLowerCase().replaceAll(RegExp(r'\s+'), '_');

      final expense = ExpenseEntryModel(
        id: widget.expense?.id ?? docId,
        expenseName: expenseName,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _selectedCategory,
        subAccountId: _selectedAccount!,
        subAccountName: _selectedAccount!,
        paymentMethod: _selectedPaymentMethod,
        receiptNumber: _receiptNumberController.text.trim(),
        vendorName: _vendorNameController.text.trim(),
        staff: datafeed.staff,
        companyid: companyid,
        companyName: companyName,
        branchId: branchid,
        branchName: branchName,
        companyemail: datafeed.companyemail,
        expenseDate: _expenseDate,
        date: widget.expense?.date ?? DateTime.now(),
        updatedat: DateTime.now(),
        createdAtTimestamp: widget.expense == null
            ? timestamp
            : widget.expense!.createdAtTimestamp,
      );

      // Save to Firestore
      if (widget.expense == null) {

        // Check for duplicate first
        final existingDoc = await datafeed.db
            .collection('expenses')
            .doc(docId)
            .get();

        if (existingDoc.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense already exists'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          print(datafeed.staffPosition);

          setState(() {
            _isSaving = false;
          });

          return;
        }

        // Save only if it doesn't exist
        await datafeed.db
            .collection('expenses')
            .doc(docId)
            .set(expense.toMap());

      } else {

        // Existing expense: update by id
        await datafeed.db
            .collection('expenses')
            .doc(expense.id)
            .update(expense.toMap());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null
                  ? 'Expense saved successfully'
                  : 'Expense updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _expenseNameController.clear();
        _descriptionController.clear();
        _amountController.clear();
        _receiptNumberController.clear();
        _vendorNameController.clear();
        setState(() {
          _selectedAccount = null;
          _selectedCategory = '';
          _selectedPaymentMethod = '';
          _expenseDate = DateTime.now();
        });
        //Navigator.pop(context, expense);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: Text(widget.expense == null ? 'New Expenses' : 'Edit Expense'),
        elevation: 2,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveExpense,
              tooltip: 'Save Expense',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Expense Name
                    _buildTextField(
                      controller: _expenseNameController,
                      label: 'Expense Name',
                      hint: 'e.g., Office Supplies Purchase',
                      icon: Icons.receipt_long,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter expense name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    _buildTextField(
                      controller: _amountController,
                      label: 'Amount',
                      hint: '0.00',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category
                   _buildDropdown(
                            label: 'Category',
                            value: _selectedCategory.isEmpty
                                ? null
                                : _selectedCategory,
                            items: _categories,
                            icon: Icons.category,
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value ?? '';
                              });
                            },
                          ),
                    const SizedBox(height: 16),

                    // Payment Method

                    _buildDropdown(
                            label: 'Payment Method',
                            value: _selectedPaymentMethod.isEmpty
                                ? null
                                : _selectedPaymentMethod,
                            items: linkedAccounts.keys.toList(),
                            icon: Icons.payment,
                            onChanged: (value) {
                              setState(() {
                                _selectedPaymentMethod = value ?? '';
                                _selectedAccount = null;
                              });
                              if (value != null && value.isNotEmpty) {
                                setState(() {
                                  _linkedAccounts = linkedAccounts[value]!.toList();
                                });
                               // _fetchLinkedAccounts(value);
                              } else {
                                setState(() {
                                  _linkedAccounts = linkedAccounts[value]!.toList();
                                });
                              }
                            },
                          ),
                    const SizedBox(height: 16),

                    // Payment Account
                    _buildLinkedAccountDropdown(),

                    const SizedBox(height: 16),

                    // Vendor Name
                    _buildTextField(
                      controller: _vendorNameController,
                      label: 'Vendor/Supplier Name',
                      hint: 'Optional',
                      icon: Icons.business,
                      required: false,
                    ),
                    const SizedBox(height: 16),

                    // Receipt Number
                    _buildTextField(
                      controller: _receiptNumberController,
                      label: 'Receipt/Invoice Number',
                      hint: 'Optional',
                      icon: Icons.receipt,
                      required: false,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Add any additional notes',
                      icon: Icons.notes,
                      maxLines: 4,
                      required: false,
                    ),
                    const SizedBox(height: 16),

                    // Expense Date
                    _buildDateField(
                      label: 'Expense Date',
                      date: _expenseDate,
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    Center(
                      child: Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        children: [
                          SizedBox(
                            width: 270,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveExpense,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF0472ed),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : Text(
                                widget.expense == null
                                    ? 'Save Expense'
                                    : 'Update Expense',
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 270,
                            child: ElevatedButton(
                              onPressed: (){
                                Navigator.pushNamed(context, Routes.expenseview);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: Colors.white70)
                                ),
                              ),
                              child: Text("View",
                                style: const TextStyle(fontSize: 16, color: Colors.white),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: required
          ? validator
          : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
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

  Widget _buildLinkedAccountDropdown() {
    final hasMethod = _selectedPaymentMethod.isNotEmpty;
    final hasAccounts = _linkedAccounts.isNotEmpty;

    return DropdownButtonFormField<String>(
      value: _selectedAccount,
      disabledHint: Text(
        !hasMethod
            ? 'Select payment method first'
            : 'No accounts available',
        style: const TextStyle(color: Colors.white38),
      ),
      decoration: InputDecoration(
        labelText: 'Payment Account',
        prefixIcon: const Icon(
          Icons.account_balance_outlined,
          color: Colors.white70,
        ),
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

      onChanged: (!hasMethod || !hasAccounts)
          ? null
          : (value) {
        setState(() {
          _selectedAccount = value;
        });
      },

      items: _linkedAccounts.map((accountName) {
        return DropdownMenuItem<String>(
          value: accountName,
          child: Text(accountName),
        );
      }).toList(),

      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a payment account';
        }
        return null;
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
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
        child: Text(
          DateFormat('MMM dd, yyyy').format(date),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
