import 'package:flutter/material.dart';
import 'package:kologsoft/models/sub_account_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:provider/provider.dart';

class SubAccountForm extends StatefulWidget {
  final SubAccountModel? existingAccount;

  const SubAccountForm({super.key, this.existingAccount});

  @override
  State<SubAccountForm> createState() => _SubAccountFormState();
}

class _SubAccountFormState extends State<SubAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedAccountClass;
  String? _selectedClassType;
  bool _isSubmitting = false;

  // Account classes
  final List<Map<String, dynamic>> _accountClasses = [
    {
      'name': 'Assets',
      'icon': Icons.account_balance_wallet,
      'types': ['Current Asset', 'Fixed Asset', 'Intangible Asset'],
    },
    {
      'name': 'Liability',
      'icon': Icons.receipt_long,
      'types': ['Current Liability', 'Long-term Liability'],
    },
    {
      'name': 'Capital',
      'icon': Icons.savings,
      'types': ['Owner Equity', 'Retained Earnings', 'Share Capital'],
    },
    {
      'name': 'Expense',
      'icon': Icons.shopping_cart,
      'types': [
        'Operating Expense',
        'Cost of Sales',
        'Admin Expense',
        'Financial Expense',
      ],
    },
    {
      'name': 'Revenue',
      'icon': Icons.trending_up,
      'types': [
        'Sales Revenue',
        'Service Revenue',
        'Other Income',
        'Interest Income',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingAccount != null) {
      _nameController.text = widget.existingAccount!.name;
      _selectedAccountClass = widget.existingAccount!.accountClass;
      _selectedClassType = widget.existingAccount!.accountClassType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<String> _getTypesForClass(String className) {
    final classData = _accountClasses.firstWhere(
      (c) => c['name'] == className,
      orElse: () => {'types': <String>[]},
    );
    return List<String>.from(classData['types'] ?? []);
  }

  IconData _getIconForClass(String className) {
    final classData = _accountClasses.firstWhere(
      (c) => c['name'] == className,
      orElse: () => {'icon': Icons.category},
    );
    return classData['icon'] ?? Icons.category;
  }

  Future<void> _submitForm(Datafeed datafeed) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final subAccount = SubAccountModel(
        id: widget.existingAccount?.id ?? '',
        name: _nameController.text.trim(),
        accountClass: _selectedAccountClass!,
        accountClassType: _selectedClassType!,
        staff: datafeed.staff,
        companyid: datafeed.companyid,
        companyemail: datafeed.companyemail,
        date: widget.existingAccount?.date ?? DateTime.now(),
        updatedat: DateTime.now(),
        deletedat: DateTime.now(),
        updatedby: datafeed.staff,
        deletedby: '',
      );
      await datafeed.addOrUpdateSubAccount(subAccount);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  widget.existingAccount != null
                      ? 'Sub account updated successfully!'
                      : 'Sub account created successfully!',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        if (widget.existingAccount != null) {
          Navigator.pop(context, true);
        } else {
          // Clear form for new entry
          _nameController.clear();
          setState(() {
            _selectedAccountClass = null;
            _selectedClassType = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text(
              widget.existingAccount != null
                  ? 'Edit Sub Account'
                  : 'Create Sub Account',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF0D1A26),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header card
                        // Form fields card
                        Card(
                          color: const Color(0xFF182232),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Account Class
                                // const Text(
                                //   'Account Class',
                                //   style: TextStyle(
                                //     color: Colors.white70,
                                //     fontSize: 16,
                                //     fontWeight: FontWeight.w600,
                                //   ),
                                // ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedAccountClass,
                                  dropdownColor: const Color(0xFF22304A),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  hint: Text("Select account class", style: TextStyle(color: Colors.white70),),
                                  decoration: InputDecoration(
                                    // prefixIcon: Icon(
                                    //   _selectedAccountClass != null
                                    //       ? _getIconForClass(
                                    //           _selectedAccountClass!,
                                    //         )
                                    //       : Icons.category,
                                    //   color: Colors.blue,
                                    // ),
                                    hintText: 'Select account class',
                                    hintStyle: TextStyle(
                                      color: Colors.white70,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
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
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.red,
                                      ),
                                    ),
                                    fillColor: const Color(0xFF22304A),
                                    filled: true,
                                  ),
                                  items: _accountClasses.map((classData) {
                                    return DropdownMenuItem<String>(
                                      value: classData['name'],
                                      child: Row(
                                        children: [
                                          Icon(
                                            classData['icon'],
                                            size: 20,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(classData['name']),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAccountClass = value;
                                      _selectedClassType = null;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an account class';
                                    }
                                    return null;
                                  },
                                ),
                                // Class Type
                                // const Text(
                                //   'Class Type',
                                //   style: TextStyle(
                                //     color: Colors.white70,
                                //     fontSize: 16,
                                //     fontWeight: FontWeight.w600,
                                //   ),
                                // ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedClassType,
                                  dropdownColor: const Color(0xFF22304A),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  hint: Text("Select class type", style: TextStyle(color: Colors.white70),),
                                  decoration: InputDecoration(
                                    // prefixIcon: const Icon(
                                    //   Icons.list_alt,
                                    //   color: Colors.blue,
                                    // ),
                                    hintText: 'Select class type',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[500],
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
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
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.red,
                                      ),
                                    ),
                                    fillColor: const Color(0xFF22304A),
                                    filled: true,
                                  ),
                                  items: _selectedAccountClass == null
                                      ? []
                                      : _getTypesForClass(
                                          _selectedAccountClass!,
                                        ).map((type) {
                                          return DropdownMenuItem<String>(
                                            value: type,
                                            child: Text(type),
                                          );
                                        }).toList(),
                                  onChanged: _selectedAccountClass == null
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _selectedClassType = value;
                                          });
                                        },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a class type';
                                    }
                                    return null;
                                  },
                                ),
                                // Account Name
                                // const Text(
                                //   'Sub Account Name',
                                //   style: TextStyle(
                                //     color: Colors.white70,
                                //     fontSize: 16,
                                //     fontWeight: FontWeight.w600,
                                //   ),
                                // ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _nameController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    // prefixIcon: const Icon(
                                    //   Icons.account_balance,
                                    //   color: Colors.blue,
                                    // ),
                                    hintText: 'Enter sub account name',
                                    hintStyle: TextStyle(
                                      color: Colors.white70,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
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
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.red,
                                      ),
                                    ),
                                    fillColor: const Color(0xFF22304A),
                                    filled: true,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a sub account name';
                                    }
                                    if (value.trim().length < 2) {
                                      return 'Name must be at least 2 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 32),

                                // Submit button
                                Wrap(
                                  runSpacing: 15,
                                  spacing: 15,
                                  children: [
                                    SizedBox(
                                      //height: 56,
                                      width: 200,
                                      child: ElevatedButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : () => _submitForm(datafeed),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          disabledBackgroundColor: Colors.blue
                                              .withOpacity(0.5),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          //elevation: 4,
                                        ),
                                        child: _isSubmitting
                                            ? const Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                AlwaysStoppedAnimation<
                                                    Color
                                                >(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Saving...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                            : Text(
                                          widget.existingAccount != null
                                              ? 'Update Sub Account'
                                              : 'Add Sub Account',
                                          style: const TextStyle(

                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 200,
                                      child: ElevatedButton(
                                        onPressed: (){
                                          Navigator.pushNamed(context, Routes.subAccountView);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              side: BorderSide(color: Colors.white70)
                                          ),
                                          elevation: 4,
                                        ),
                                        child: Text("View Sub Accounts", style: TextStyle(color: Colors.white),),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info card
                        Card(
                          color: const Color(0xFF1E293B).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[300],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Sub accounts help you organize and track specific categories within your main account classes.',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
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
          ),
        );
      },
    );
  }
}
