import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/account_type_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:provider/provider.dart';

class AccountTypeReg extends StatefulWidget {
  final AccountTypeModel? account;
  const AccountTypeReg({super.key, this.account});

  @override
  State<AccountTypeReg> createState() => _AccountTypeRegState();
}

class _AccountTypeRegState extends State<AccountTypeReg> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  String? _selectedClass;
  String? _selectedSubclass;
  String? _selectedSubtype;
  List<Map<String, dynamic>> _availableSubtypes = [];
  bool _loadingSubtypes = false;

  final List<String> _accountClasses = [
    'Assets',
    'Liability',
    'Equity',
    'Expense',
    'Revenue',
  ];

  final Map<String, List<String>> _subclassesByClass = {
    'Assets': ['Current Asset', 'Non-current'],
    'Liability': ['Current Liability', 'Non-current Liability'],
    'Equity': ['Equity'],
    'Expense': [
      'Operating Expense',
      'Cost of Sales',
      'Admin Expense',
      'Financial Expense',
    ],
    'Revenue': ['Revenue'],
  };

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _nameController.text = widget.account!.name;
      _selectedClass = widget.account!.accountClass;
      _selectedSubclass = widget.account!.accountClassType;
      _selectedSubtype = widget.account!.subAccount;

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
              widget.account != null
                  ? 'EDIT CHART OF ACCOUNTS'
                  : 'CHART OF ACCOUNTS',
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
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Account Name',
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
                                    ? 'Enter account name'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _selectedClass,
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Class',
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
                                items: _accountClasses.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedClass = value;
                                    _selectedSubclass = null;
                                    _selectedSubtype = null;
                                    _availableSubtypes = [];
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Please select class'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _selectedSubclass,
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Subclass',
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
                                items: (_selectedClass == null)
                                    ? const []
                                    : (_subclassesByClass[_selectedClass] ?? [])
                                          .map((type) {
                                            return DropdownMenuItem<String>(
                                              value: type,
                                              child: Text(type),
                                            );
                                          })
                                          .toList(),
                                onChanged: (_selectedClass == null)
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedSubclass = value;
                                          _selectedSubtype = null;
                                        });
                                        if (value != null) {
                                          //_loadSubtypes(value);
                                        }
                                      },
                                validator: (value) => value == null
                                    ? 'Please select subclass'
                                    : null,
                              ),
                              // const SizedBox(height: 14),
                              // DropdownButtonFormField<String>(
                              //   value: _selectedSubtype,
                              //   dropdownColor: const Color(0xFF22304A),
                              //   style: const TextStyle(color: Colors.white),
                              //   decoration: InputDecoration(
                              //     labelText: 'Subtype',
                              //     labelStyle: const TextStyle(
                              //       color: Colors.white70,
                              //     ),
                              //     suffixIcon: _loadingSubtypes
                              //         ? const Padding(
                              //             padding: EdgeInsets.all(12.0),
                              //             child: SizedBox(
                              //               width: 20,
                              //               height: 20,
                              //               child: CircularProgressIndicator(
                              //                 strokeWidth: 2,
                              //                 valueColor:
                              //                     AlwaysStoppedAnimation<Color>(
                              //                       Colors.blue,
                              //                     ),
                              //               ),
                              //             ),
                              //           )
                              //         : null,
                              //     border: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //     ),
                              //     enabledBorder: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //       borderSide: const BorderSide(
                              //         color: Colors.white24,
                              //       ),
                              //     ),
                              //     focusedBorder: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //       borderSide: const BorderSide(
                              //         color: Colors.blue,
                              //       ),
                              //     ),
                              //     fillColor: const Color(0xFF22304A),
                              //     filled: true,
                              //   ),
                              //   items: _availableSubtypes.isEmpty
                              //       ? const []
                              //       : _availableSubtypes.map((subtype) {
                              //           return DropdownMenuItem<String>(
                              //             value: subtype['name'],
                              //             child: Text(subtype['name']),
                              //           );
                              //         }).toList(),
                              //   onChanged:
                              //       (_selectedSubclass == null ||
                              //           _availableSubtypes.isEmpty)
                              //       ? null
                              //       : (value) {
                              //           setState(() {
                              //             _selectedSubtype = value;
                              //           });
                              //         },
                              //   validator: (value) {
                              //     if (_availableSubtypes.isNotEmpty &&
                              //         (value == null || value.isEmpty)) {
                              //       return 'Please select subtype';
                              //     }
                              //     return null;
                              //   },
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
                                      onPressed: () async {
                                        if (!_formKey.currentState!.validate()) {
                                          return;
                                        }

                                        try {
                                          final account = AccountTypeModel(
                                            id: widget.account?.id ?? '',
                                            name: _nameController.text.trim(),
                                            accountClass: _selectedClass!,
                                            accountClassType: _selectedSubclass!,
                                            subAccount: _selectedSubtype ?? '',
                                            staff: value.staff,
                                            companyid: value.companyid,
                                            companyemail: value.companyemail,
                                            date:
                                            widget.account?.date ??
                                                DateTime.now(),
                                            updatedat: DateTime.now(),
                                            deletedat: DateTime.now(),
                                            updatedby: value.staff,
                                            deletedby: '',
                                          );

                                          await value.addOrUpdateAccountType(
                                            account,
                                          );

                                          if (widget.account != null) {
                                            Navigator.pop(context);
                                          }

                                          _nameController.clear();
                                          setState(() {
                                            _selectedClass = null;
                                            _selectedSubclass = null;
                                            _selectedSubtype = null;
                                            _availableSubtypes = [];
                                          });

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                widget.account != null
                                                    ? 'Chart of account updated successfully'
                                                    : 'Chart of account saved successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Operation failed: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        widget.account != null ? 'Update' : 'Add',
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
                                        Navigator.pushNamed(context, Routes.accountTypeView);
                                      },
                                      child: Text(
                                        "View Accounts",
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
}
