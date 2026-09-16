import 'package:flutter/material.dart';
import 'package:kologsoft/models/sub_account_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

const String _subAccountViewRoute = '/sub-account-view';

class SubAccountReg extends StatefulWidget {
  final SubAccountModel? subAccount;
  const SubAccountReg({super.key, this.subAccount});

  @override
  State<SubAccountReg> createState() => _SubAccountRegState();
}

class _SubAccountRegState extends State<SubAccountReg> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  String? _selectedClass;
  String? _selectedClassType;

  final List<String> _accountClasses = [
    'Assets',
    'Liability',
    'Capital',
    'Expense',
    'Revenue',
  ];

  final Map<String, List<String>> _classTypes = {
    'Assets': ['Current Asset', 'Fixed Asset'],
    'Liability': ['Current Liability', 'Long-term Liability'],
    'Capital': ['Owner Equity', 'Retained Earnings'],
    'Expense': ['Operating Expense', 'Cost of Sales', 'Admin Expense'],
    'Revenue': ['Sales Revenue', 'Service Revenue', 'Other Income'],
  };

  @override
  void initState() {
    super.initState();
    if (widget.subAccount != null) {
      _nameController.text = widget.subAccount!.name;
      _selectedClass = widget.subAccount!.accountClass;
      _selectedClassType = widget.subAccount!.accountClassType;
    }
  }

  String normalizeAndSanitize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text(
              widget.subAccount != null
                  ? 'EDIT SUB ACCOUNT'
                  : 'SUB ACCOUNT REGISTRATION',
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
                      Card(
                        color: const Color(0xFF182232),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedClass,
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Account Class',
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
                                    _selectedClassType = null;
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Please select account class'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _selectedClassType,
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Class Type',
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
                                    : (_classTypes[_selectedClass] ?? []).map((
                                        type,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(type),
                                        );
                                      }).toList(),
                                onChanged: (_selectedClass == null)
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedClassType = value;
                                        });
                                      },
                                validator: (value) => value == null
                                    ? 'Please select class type'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Sub Account Name',
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
                                    ? 'Enter sub account name'
                                    : null,
                              ),
                              const SizedBox(height: 30),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
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
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        if (!_formKey.currentState!
                                            .validate()) {
                                          return;
                                        }

                                        try {
                                          final subAccount = SubAccountModel(
                                            id: widget.subAccount?.id ?? '',
                                            name: _nameController.text.trim(),
                                            accountClass: _selectedClass!,
                                            accountClassType:
                                                _selectedClassType!,
                                            staff: '',
                                            companyid: value.companyid,
                                            companyemail: value.companyemail,
                                            date: DateTime.now(),
                                            updatedat: DateTime.now(),
                                            deletedat: DateTime.now(),
                                            updatedby: '',
                                            deletedby: '',
                                          );

                                          await value.addOrUpdateSubAccount(
                                            subAccount,
                                          );

                                          if (widget.subAccount != null) {
                                            Navigator.pop(context);
                                          }

                                          _nameController.clear();
                                          setState(() {
                                            _selectedClass = null;
                                            _selectedClassType = null;
                                          });

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                widget.subAccount != null
                                                    ? 'Sub account updated successfully'
                                                    : 'Sub account saved successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Operation failed: $e',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        widget.subAccount != null
                                            ? 'Update'
                                            : 'Add',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 200,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.white70,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.view_list,
                                        color: Colors.white70,
                                      ),
                                      label: const Text(
                                        'View',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          _subAccountViewRoute,
                                        );
                                      },
                                    ),
                                  ),
                                ],
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
        );
      },
    );
  }
}
