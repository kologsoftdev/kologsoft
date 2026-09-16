import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/activity_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:provider/provider.dart';

class ActivityChartReg extends StatefulWidget {
  final ActivityModel? chart;
  const ActivityChartReg({super.key, this.chart});

  @override
  State<ActivityChartReg> createState() => _ActivityChartRegState();
}

class _ActivityChartRegState extends State<ActivityChartReg> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedActivity;
  String? _selectedDebitId;
  String? _selectedDebitName;
  String? _selectedCreditId;
  String? _selectedCreditName;
  Future<QuerySnapshot<Map<String, dynamic>>>? _accountsFuture;
  String? _lastCompanyId;
  bool _isSaving = false;

  final List<String> _activities = [
    'Cash Sales',
    'Credit Sales',
    'Expense',
    'Cash Purchase',
    'Credit Purchase',
    'Sales Return',
    'Purchase Return',
    'Creditors Payment',
    'Debtors Payment',
    'Journal Entry',
    'Bank Transfer'

  ];

  @override
  void initState() {
    super.initState();
    if (widget.chart != null) {
      _selectedActivity = widget.chart!.activityName;
      _selectedDebitId = widget.chart!.debitAccountId;
      _selectedDebitName = widget.chart!.debitAccountName;
      _selectedCreditId = widget.chart!.creditAccountId;
      _selectedCreditName = widget.chart!.creditAccountName;
      if (_selectedDebitId != null && _selectedDebitId == _selectedCreditId) {
        _selectedCreditId = null;
        _selectedCreditName = null;
      }
    }
  }

  String _buildDisplayText(String name) {
    return name;
  }

  void _ensureAccountsFuture(Datafeed value) {
    if (value.companyid.isEmpty) return;
    if (_lastCompanyId == value.companyid && _accountsFuture != null) return;
    _lastCompanyId = value.companyid;
    _accountsFuture = value.db
        .collection('accounts')
        .where('companyId', isEqualTo: value.companyid)
        .orderBy('name')
        .get();
  }

  Future<Map<String, String>> _loadAccountMeta(
    Datafeed value,
    String? id,
  ) async {
    if (id == null || id.isEmpty) {
      return {'subclass': '', 'subtype': ''};
    }

    final doc = await value.db.collection('accounts').doc(id).get();
    final data = doc.data();
    if (data == null) {
      return {'subclass': '', 'subtype': ''};
    }

    return {
      'subclass': (data['accountClassType'] ?? '').toString(),
      'subtype': (data['subAccount'] ?? '').toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        _ensureAccountsFuture(value);
        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text(
              widget.chart != null ? 'EDIT ACTIVITY CHART' : 'ACTIVITY CHART',
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
                                value: _selectedActivity,
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'ACTIVITY NAME',
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
                                items: _activities.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedActivity = value;
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Please select an activity'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              if (value.companyid.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Company not set. Please sign in again.',
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                )
                              else
                                FutureBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  future: _accountsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      debugPrint(
                                        'Accounts fetch error: ${snapshot.error}',
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Failed to load accounts: ${snapshot.error}',
                                          style: const TextStyle(
                                            color: Colors.orangeAccent,
                                          ),
                                        ),
                                      );
                                    }

                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }

                                    final accounts =
                                        snapshot.data?.docs ?? const [];
                                    final hasAccounts = accounts.isNotEmpty;
                                    if (!hasAccounts) {
                                      debugPrint(
                                        'No accounts found for companyId=${value.companyid}',
                                      );
                                    }

                                    List<DropdownMenuItem<String>> buildItems(
                                      String? excludeId,
                                    ) {
                                      return accounts
                                          .where((doc) => doc.id != excludeId)
                                          .map((doc) {
                                            final data = doc.data();
                                            final name =
                                                data['name']?.toString() ?? '';
                                            final displayText =
                                                _buildDisplayText(name);
                                            return DropdownMenuItem<String>(
                                              value: doc.id,
                                              child: Text(displayText),
                                            );
                                          })
                                          .toList();
                                    }

                                    return Column(
                                      children: [
                                        DropdownButtonFormField<String>(
                                          value: _selectedDebitId,
                                          dropdownColor: const Color(
                                            0xFF22304A,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: 'DEBIT ACCOUNT',
                                            labelStyle: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Colors.white24,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Colors.blue,
                                              ),
                                            ),
                                            fillColor: const Color(0xFF22304A),
                                            filled: true,
                                          ),
                                          items: buildItems(_selectedCreditId),
                                          onChanged: hasAccounts
                                              ? (value) {
                                                  final selected = accounts
                                                      .firstWhere(
                                                        (doc) =>
                                                            doc.id == value,
                                                      )
                                                      .data();
                                                  setState(() {
                                                    _selectedDebitId = value;
                                                    _selectedDebitName =
                                                        selected['name']
                                                            ?.toString();
                                                    if (value ==
                                                        _selectedCreditId) {
                                                      _selectedCreditId = null;
                                                      _selectedCreditName =
                                                          null;
                                                    }
                                                  });
                                                }
                                              : null,
                                          validator: (value) => value == null
                                              ? 'Select a debit account'
                                              : null,
                                        ),
                                        const SizedBox(height: 14),
                                        DropdownButtonFormField<String>(
                                          value: _selectedCreditId,
                                          dropdownColor: const Color(
                                            0xFF22304A,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: 'CREDIT ACCOUNT',
                                            labelStyle: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Colors.white24,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Colors.blue,
                                              ),
                                            ),
                                            fillColor: const Color(0xFF22304A),
                                            filled: true,
                                          ),
                                          items: buildItems(_selectedDebitId),
                                          onChanged: hasAccounts
                                              ? (value) {
                                                  final selected = accounts
                                                      .firstWhere(
                                                        (doc) =>
                                                            doc.id == value,
                                                      )
                                                      .data();
                                                  setState(() {
                                                    _selectedCreditId = value;
                                                    _selectedCreditName =
                                                        selected['name']
                                                            ?.toString();
                                                    if (value ==
                                                        _selectedDebitId) {
                                                      _selectedDebitId = null;
                                                      _selectedDebitName = null;
                                                    }
                                                  });
                                                }
                                              : null,
                                          validator: (value) => value == null
                                              ? 'Select a credit account'
                                              : null,
                                        ),
                                        if (!hasAccounts)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              'No chart of accounts found.',
                                              style: TextStyle(
                                                color: Colors.orangeAccent,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              const SizedBox(height: 30),
                              Wrap(
                                runSpacing: 15,
                                spacing: 15,
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
                                      onPressed: _isSaving
                                          ? null
                                          : () async {
                                        if (!_formKey.currentState!
                                            .validate()) {
                                          return;
                                        }
                                        if (_selectedDebitId ==
                                            _selectedCreditId) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Debit and credit accounts must be different',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        setState(() {
                                          _isSaving = true;
                                        });

                                        try {
                                          final debitMeta =
                                          await _loadAccountMeta(
                                            value,
                                            _selectedDebitId,
                                          );
                                          final creditMeta =
                                          await _loadAccountMeta(
                                            value,
                                            _selectedCreditId,
                                          );
                                          final chart = ActivityModel(
                                            id: widget.chart?.id ?? '',
                                            activityName: _selectedActivity!,
                                            subclass:
                                            debitMeta['subclass'] ?? '',
                                            subtype:
                                            debitMeta['subtype'] ?? '',
                                            debitSubclass:
                                            debitMeta['subclass'] ?? '',
                                            debitSubtype:
                                            debitMeta['subtype'] ?? '',
                                            creditSubclass:
                                            creditMeta['subclass'] ?? '',
                                            creditSubtype:
                                            creditMeta['subtype'] ?? '',
                                            debitAccountId: _selectedDebitId!,
                                            debitAccountName:
                                            _selectedDebitName ?? '',
                                            creditAccountId:
                                            _selectedCreditId!,
                                            creditAccountName:
                                            _selectedCreditName ?? '',
                                            staff: '',
                                            companyid: value.companyid,
                                            companyemail: value.companyemail,
                                            date: DateTime.now(),
                                            updatedat: DateTime.now(),
                                            deletedat: DateTime.now(),
                                            updatedby: '',
                                            deletedby: '',
                                          );

                                          await value
                                              .addOrUpdateActivityChart(
                                            chart,
                                          );

                                          if (widget.chart != null) {
                                            Navigator.pop(context);
                                          }

                                          setState(() {
                                            _selectedActivity = null;
                                            _selectedDebitId = null;
                                            _selectedDebitName = null;
                                            _selectedCreditId = null;
                                            _selectedCreditName = null;
                                          });

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                widget.chart != null
                                                    ? 'Activity chart updated successfully'
                                                    : 'Activity chart saved successfully',
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
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _isSaving = false;
                                            });
                                          }
                                        }
                                      },
                                      child: _isSaving
                                          ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                          : Text(
                                        widget.chart != null
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
                                        Navigator.pushNamed(context, Routes.activityChartView);
                                      },
                                      child: Text(
                                          "View",
                                        style: TextStyle(color: Colors.white),
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
