import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/StockProvider.dart';
import 'itemreg.dart';

class NewStock extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;
  const NewStock({super.key, this.docId, this.data});

  @override
  State<NewStock> createState() => _NewStockState();
}

class _NewStockState extends State<NewStock> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _invoicenumberController =TextEditingController();
  final TextEditingController _waybillController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  String? _selectedPurchaseType;
  String? _selectedpaymentaccount;
  String method="";
  Map<String,List<String>> linkedAccounts={};
  List<String> _linkedAccounts = [];
  String? _selectedAccount;

  bool _loading = false;
  DateTime? _selectedDate;
  bool _showStockItems = false;
  Map<String, dynamic>? _pendingHeader;
  late List<String> _purchasTypes = ['Cash', 'Credit', 'Opening Stock'];
  List<String> paymentaccount = [];
  String _selectedPaymentMethod = '';
  bool get isCashPurchase => _selectedPurchaseType == 'Cash';
  bool get isCreditOrOpeningStock =>
      _selectedPurchaseType == 'Credit' || _selectedPurchaseType == 'Opening Stock';
  String paymentMethod='';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<Datafeed>(context, listen: false);
      provider.fetchBranches();
      provider.fetchSuppliers();
      paymentaccount=provider.allowedPaymentMethods;

      if (widget.data != null) {
        final customadata = widget.data!;
        final branchId = customadata['branchId'];
        if (branchId != null && branchId.isNotEmpty) {
          provider.selectBranch(branchId);
        }
      }

    });

    if (widget.data != null) {
      final customadata = widget.data!;
      _invoicenumberController.text = customadata['name'] ?? '';
      _contactController.text = customadata['contact'] ?? '';
      final customerType = customadata['customertype'];
      if (_purchasTypes.contains(customerType)) {
        _selectedPurchaseType = customerType;
      }
      final paymentDuration = customadata['paymentduration'];
      if (paymentaccount.contains(paymentDuration)) {
        _selectedpaymentaccount = paymentDuration;
      }
    }
    if (widget.docId != null && widget.docId!.isNotEmpty) {
      _showStockItems = true;
      _pendingHeader = widget.data;
    }
    _fetchPaymentMethods();


  }

  void _fetchPaymentMethods() async {
    try {
      final datafeed = context.read<Datafeed>();
      final snapshot = await datafeed.db.collection('paymentaccounts').where('companyId',isEqualTo: datafeed.companyid).get();


      for (var doc in snapshot.docs) {
        final map = doc.data();

        method = map['paymentMethod']?.toString() ?? '';
        final accounts = List<String>.from(map['linkedAccounts'] ?? []);

        if (method.isNotEmpty) {
          linkedAccounts[method] = accounts;
        }
      }

    } catch (e) {
      print("error:$e");

    } finally {
      print("error:loading payment accounts");

    }
  }


  void _resetToNewStock() {
    setState(() {

      _showStockItems = false;
      _pendingHeader = {};
      widget.docId == null;
      _invoicenumberController.clear();
      _waybillController.clear();
      _contactController.clear();
      _dateController.clear();
      _selectedPurchaseType = null;
      _selectedpaymentaccount = null;
      _selectedDate = null;
    });
  }

  @override
  void dispose() {
    _invoicenumberController.dispose();
    _contactController.dispose();
    _waybillController.dispose();
    _dateController.dispose();
    super.dispose();
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

  Widget _twoCol(BuildContext context, Widget a, Widget b) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: a),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: b),
        ],
      );
    } else if (width < 1024) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.start,
        children: [
          SizedBox(width: 320, child: a),
          SizedBox(width: 320, child: b),
        ],
      );
    }
  }

  Widget _buildLinkedAccountDropdown({required bool enabled}) {
    final hasMethod = _selectedPaymentMethod.isNotEmpty;
    final hasAccounts = _linkedAccounts.isNotEmpty;

    final bool canChange = enabled && hasMethod && hasAccounts;
    final String hintMessage = !enabled
        ? 'Disabled'
        : !hasMethod
            ? 'Select payment method first'
            : !hasAccounts
                ? 'No accounts available'
                : 'Select payment account';

    return DropdownButtonFormField<String>(
      value: _selectedAccount,
      hint: Text(
        hintMessage,
        style: const TextStyle(color: Colors.white),
      ),
      decoration: InputDecoration(
        labelText: 'Payment Account',
        prefixIcon: const Icon(
          Icons.account_balance_outlined,
          color: Colors.white70,
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hintMessage,
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
      ),
      dropdownColor: const Color(0xFF182232),
      style: const TextStyle(color: Colors.white),

      onChanged: canChange
          ? (value) {
              setState(() {
                _selectedAccount = value;
              });
            }
          : null,

      items: _linkedAccounts.map((accountName) {
        return DropdownMenuItem<String>(
          value: accountName,
          child: Text(accountName),
        );
      }).toList(),

    );
  }


  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?)? onChanged,
    // required String? Function(String) validator,
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

    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        // Guard against duplicate IDs returned by backend/provider lists.
        final uniqueSuppliers = <dynamic>[];
        final supplierIds = <String>{};
        for (final supplier in value.suppliers) {
          final id = supplier.id.toString();
          if (id.isEmpty) continue;
          if (supplierIds.add(id)) uniqueSuppliers.add(supplier);
        }

        final uniqueBranches = <dynamic>[];
        final branchIds = <String>{};
        for (final branch in value.branches) {
          if (branch.branchtype == 'Sales Point') continue;
          final id = branch.id.toString();
          if (id.isEmpty) continue;
          if (branchIds.add(id)) uniqueBranches.add(branch);
        }

        final selectedSupplierId = value.selectedSupplier?.id;
        final selectedBranchId = value.selectedBranch?.id;
        final supplierValue =selectedSupplierId != null &&
                supplierIds.contains(selectedSupplierId)
            ? selectedSupplierId
            : null;
        final branchValue =
            selectedBranchId != null && branchIds.contains(selectedBranchId)
            ? selectedBranchId
            : null;

        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text(
              widget.docId != null ? "EDIT STOCK ENTRY" : "NEW STOCK ENTRY",
            ),
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
                          child: StockItemsForm(
                            transactionId: _pendingHeader!['docid'] as String,
                            headerData: _pendingHeader!,
                            onNewTransaction: _resetToNewStock,
                          ),
                        )
                      : Padding(
                          key: const ValueKey('header_card'),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 700),
                              child: Card(
                                color: const Color(0xFF182232),
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Section title
                                      Text(
                                        "Header Details",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Provide the invoice, supplier and branch information for this stock entry.",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      _twoCol(
                                        context,
                                        TextFormField(
                                          controller: _invoicenumberController,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: _inputDecoration(
                                            label: 'Invoice Number',
                                            prefix: Icons.receipt,
                                          ),
                                        ),
                                        TextFormField(
                                          controller: _waybillController,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: _inputDecoration(
                                            label: 'Waybill Number',
                                            prefix: Icons.local_shipping,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      // Supplier full width
                                      DropdownSearch<String>(
                                        selectedItem: supplierValue,

                                        items: (filter, infiniteScrollProps) => uniqueSuppliers
                                            .map<String>((supplier) => supplier.id.toString())
                                            .toList(),

                                        decoratorProps: DropDownDecoratorProps(
                                          decoration: _inputDecoration(
                                            label: '',
                                            prefix: Icons.business,
                                          ),
                                        ),

                                        popupProps: PopupProps.menu(
                                          showSearchBox: true,

                                          searchFieldProps: const TextFieldProps(
                                            style: TextStyle(color: Colors.black),
                                            decoration: InputDecoration(
                                              hintText: 'Search supplier...',
                                              hintStyle: TextStyle(color: Colors.black),
                                            ),
                                          ),

                                          menuProps: const MenuProps(
                                            backgroundColor: Color(0xFF22304A),
                                          ),

                                          itemBuilder: (context, item, isDisabled, isSelected) {
                                            final supplierData = uniqueSuppliers.firstWhere(
                                                  (e) => e.id.toString() == item,
                                            );

                                            return ListTile(
                                              title: Text(
                                                supplierData.supplier.toString(),
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            );
                                          },
                                        ),

                                        dropdownBuilder: (context, selectedItem) {
                                          if (selectedItem == null) {
                                            return const Text(
                                              'Select Supplier',
                                              style: TextStyle(color: Colors.white70),
                                            );
                                          }

                                          final supplierData = uniqueSuppliers.firstWhere(
                                                (e) => e.id.toString() == selectedItem,
                                          );

                                          return Text(
                                            supplierData.supplier.toString(),
                                            style: const TextStyle(color: Colors.white),
                                          );
                                        },

                                        onSelected: (val) {
                                          if (val != null) {
                                            value.selectSupplier(val);
                                          }
                                        },

                                        validator: (val) =>
                                        val == null ? 'Please select Supplier' : null,
                                      ),
                                      const SizedBox(height: 14),
                                      _twoCol(
                                        context,
                                        DropdownButtonFormField<String>(
                                          value: _selectedPurchaseType,
                                          dropdownColor: const Color(0xFF22304A),
                                          style: const TextStyle(color: Colors.white),
                                          decoration: _inputDecoration(
                                            label: 'Purchase Mode',
                                            prefix: Icons.payment,
                                          ),
                                          items: _purchasTypes.map((type) {
                                            return DropdownMenuItem<String>(
                                              value: type,
                                              child: Text(type),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            setState(() {
                                              _selectedPurchaseType = v;

                                              if (v != 'Cash') {
                                                _selectedPaymentMethod = '';
                                                _selectedpaymentaccount = null;
                                                _linkedAccounts = [];
                                              }
                                            });
                                          },
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please select purchase mode';
                                            }
                                            return null;
                                          },
                                        ),

                                        _buildDropdown(
                                          label: 'Payment Method',
                                          value: _selectedPaymentMethod.isEmpty
                                              ? null
                                              : _selectedPaymentMethod,
                                          items: linkedAccounts.keys.toList(),
                                          icon: Icons.payment,

                                          onChanged: isCreditOrOpeningStock
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    _selectedPaymentMethod = value ?? '';
                                                    _selectedAccount = null;

                                                    if (value != null && value.isNotEmpty) {
                                                      _linkedAccounts = linkedAccounts[value]!.toList();
                                                    } else {
                                                      _linkedAccounts = [];
                                                    }
                                                  });
                                                },
                                        ),

                                      ),
                                      const SizedBox(height: 14),
                                      _buildLinkedAccountDropdown(
                                        enabled: !isCreditOrOpeningStock,
                                      ),

                                      const SizedBox(height: 14),

                                      _twoCol(
                                        context,
                                        DropdownButtonFormField<String>(
                                          value: branchValue,
                                          dropdownColor: const Color(
                                            0xFF22304A,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: _inputDecoration(
                                            label: 'Branch',
                                            prefix: Icons.location_city,
                                          ),
                                          items: (
                                              value.accesslevel == 'super admin'
                                                  ? uniqueBranches // show all branches
                                                  : uniqueBranches.where((branch) => branch.id == value.branchid) // only user branch
                                          ).map((branch){
                                            return DropdownMenuItem<String>(
                                              value: branch.id,
                                              child: Text(branch.branchname),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null)
                                              value.selectBranch(val);
                                          },
                                          validator: (val) => val == null
                                              ? 'Please select branch'
                                              : null,
                                        ),
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
                                                  backgroundColor: const Color(
                                                    0xFF415A77,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                onPressed: _loading
                                                    ? null
                                                    : () async {
                                                        if (!_formKey
                                                            .currentState!
                                                            .validate())
                                                          return;

                                                        setState(
                                                          () => _loading = true,
                                                        );

                                                        String invoicenumber =
                                                            _invoicenumberController
                                                                .text
                                                                .trim();

                                                        String waybillnumber = _waybillController.text.trim().isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : _waybillController.text.trim();                                                        String purchasetype =
                                                            _selectedPurchaseType!;
                                                        DateTime? invoicedate =
                                                            _selectedDate;
                                                        final branchId = value.selectedBranch
                                                                ?.id ??
                                                            '';
                                                        final branchName = value.selectedBranch
                                                                ?.branchname ??
                                                            '';
                                                        final docid = value.normalizeAndSanitize(
                                                              "${value.companyid}${DateTime.now().millisecondsSinceEpoch}${value.staffPosition}",
                                                            );

                                                        final headerData = {
                                                          'paymentaccount':_selectedAccount,
                                                          'invoice': invoicenumber,
                                                          'invoicedate': invoicedate,
                                                          'waybill': waybillnumber,
                                                          'supplierid': value.selectedSupplier ?.id ?? '',
                                                          'suppliername': value.selectedSupplier ?.supplier ?? '',
                                                          'branchid': branchId,
                                                          'branchname': branchName,
                                                          'purchasetype': purchasetype,
                                                          'docid': docid,
                                                          'createdat': DateTime.now(),
                                                          'createdby': value.staff,
                                                          'companyid': value.companyid,
                                                          'company': value.company,
                                                          'staffbranchid': value.branchid,
                                                          'staffbranch': value.branch,
                                                        };

                                                        try {
                                                          if (widget.docId == null) {
                                                            setState(() {
                                                              _pendingHeader = headerData;
                                                              _showStockItems = true;
                                                            });
                                                            FocusScope.of(
                                                              context,
                                                            ).unfocus();
                                                          }
                                                        } catch (e) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                e.toString(),
                                                              ),
                                                            ),
                                                          );
                                                        }

                                                        if (!mounted) return;
                                                        setState(() {
                                                          _loading = false;
                                                          _selectedPurchaseType =
                                                              null;
                                                        });
                                                      },
                                                icon: _loading
                                                    ? const SizedBox.shrink()
                                                    : const Icon(
                                                        Icons.arrow_forward,
                                                      ),
                                                label: _loading
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                    : Text(
                                                        "Proceed",
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            height: 48,
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                  color: Colors.white24,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).maybePop(),
                                              child: const Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
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

class StockItemsForm extends StatefulWidget {
  final String transactionId;
  final Map<String, dynamic> headerData;
  final VoidCallback onNewTransaction;

  const StockItemsForm({
    super.key,
    required this.transactionId,
    required this.headerData,
    required this.onNewTransaction,
  });

  @override
  State<StockItemsForm> createState() => _StockItemsFormState();
}

class _StockItemsFormState extends State<StockItemsForm> {
  final _formkey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _taxValueController = TextEditingController();

  String? _selectedStockMode;
  List<String> _stockMode = [];
  String? _selectedTaxType;
  final List<String> _taxType = ['No vat', 'Flat', 'standard'];
  Map<String, dynamic>? _itemModes;
  bool _loading = false;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  Map<String, dynamic>? _selectedItem;
  String _searchQuery = '';
  bool hasbranchprices = false;
  Map<String, dynamic> branchData = {};
  Map<String, dynamic> currentBranchPrice = {};
  Map<String, dynamic> branchBalance = {};
  final List<Map<String, dynamic>> _items = [];
  double oldPieces=0;
  double boxPieces=0;
  double total=0;
  bool _loadingBalance=false;
  @override
  void initState() {
    super.initState();
    _barcodeController.addListener(_onBarcodeChanged);
    _selectedTaxType = _taxType.first;
    _taxValueController.text = '0';
    _discountController.text = '0';
    if (widget.headerData.containsKey('items')) {
      final rawItems = widget.headerData['items'];
      if (rawItems is List) {
        _items.addAll(rawItems.map((e) => Map<String, dynamic>.from(e)));
      }
    }
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeController.dispose();
    _itemController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    _taxValueController.dispose();
    super.dispose();
  }

  void _onBarcodeChanged() {
    setState(() {
      _searchQuery = _barcodeController.text.trim();
      _showSuggestions = _searchQuery.isNotEmpty;
    });
  }

  Future<void> _selectItem(Map<String, dynamic> item) async {
    try {
      final provider = Provider.of<Datafeed>(
        context,
        listen: false,
      );

      final Map<String, dynamic>? modes =
      item['modes'] is Map
          ? Map<String, dynamic>.from(item['modes'])
          : null;

      final double newBoxPieces =
          double.tryParse(
            modes?['carton']?['qty']?.toString() ?? '1',
          ) ??
              1;

      final stockModes = provider.normalizeModes(modes);

      final String? selectedStockMode =
      stockModes.isNotEmpty
          ? stockModes.first
          : null;

      final dynamic rawBranchBalance =
      (item['branchbalance'] as Map?)?[
      widget.headerData['branchid']
      ];
      setState(() {
        _loadingBalance = true;
      });

      final double newOldPieces =(await  provider.fetchItemCurrentBalance(itemId: item['id'])??.0).toDouble();

      debugPrint(
        'Old pieces for ${item['name']}: $newOldPieces',
      );

      if (!mounted) return;

      setState(() {
        _loadingBalance = false;
        _selectedItem = item;

        _barcodeController.text =item['barcode']?.toString() ?? '';

        _itemController.text =item['name']?.toString() ?? '';

        _priceController.text =item['cp']?.toString() ?? '0';

        _itemModes = modes;

        boxPieces = newBoxPieces;

        _stockMode = stockModes;

        _selectedStockMode = selectedStockMode;

        branchBalance = rawBranchBalance;

        oldPieces = newOldPieces;

        _showSuggestions = false;

        _suggestions = [];
      });
    } catch (e, stack) {
      debugPrint(
        '_selectItem error: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );
    }
  }

  void _addItem() {
    if (_formkey.currentState!.validate()) {

      final String itemId = _selectedItem?['id'] ?? '';

      final bool exists = _items.any(
            (item) => item['itemid'].toString() == itemId,
      );

      if (exists) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Item Already Added"),
            content: const Text(
              "This item already exists in the list.\n\n"
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

      setState(() {
        final double quantity =
            double.tryParse(_quantityController.text.trim()) ?? 0;
        final double price =
            double.tryParse(_priceController.text.trim())?.toDouble() ?? 0.0;
        final double discount =
            double.tryParse(_discountController.text.trim())?.toDouble() ?? 0.0;
        final double taxValue =
            double.tryParse(_taxValueController.text.trim())?.toDouble() ?? 0.0;

        // Determine mode quantity
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
            final dynamic qVal = selectedModeData['qty'] ?? 1;
            if (qVal is num) {
              modeQty = qVal.toDouble();
            } else {
              modeQty = double.tryParse(qVal.toString()) ?? 1.0;
            }
          }
        }

        // pieces = modeQty * entered quantity
        final double pieces = modeQty * quantity;

        // compute line amounts
        final double baseAmount = price * pieces;
        double taxAmount = 0.0;
        if (_selectedTaxType == 'No vat') {
          taxAmount = 0.0;
        } else if (_selectedTaxType == 'Flat') {
          taxAmount = taxValue;
        } else {
          final taxableBase = (baseAmount - discount).clamp(
            0.0,
            double.infinity,
          );
          taxAmount = taxableBase * (taxValue / 100.0);
        }
        final double total = (baseAmount - discount) + taxAmount;

        _items.add({
          'item': _itemController.text.trim(),
          'quantity': quantity,
          'price': price,
          'discount': discount,
          'taxtype': _selectedTaxType ?? '',
          'taxvalue': taxValue,
          'taxamount': taxAmount,
          'total': total,
          'stockingmode': _selectedStockMode ?? '',
          'modeqty': modeQty,
          'pieces': pieces,
          'barcode': _barcodeController.text.trim(),
          'itemid': _selectedItem != null ? _selectedItem!['id'] ?? '' : '',
          'boxpieces':boxPieces,
          'originalcp': _selectedItem?['cp'],
          'oldPieces': oldPieces,
        });
        _itemController.clear();
        _quantityController.clear();
        _discountController.text = '0';
        _taxValueController.text = '0';
        _barcodeController.clear();
        _priceController.clear();
      });
    }
  }

  ({double gross, double discount, double tax, double net}) _calculateTotals() {
    double baseTotal = 0.0;
    double discountTotal = 0.0;
    double taxTotal = 0.0;

    for (final it in _items) {
      final double price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final double qty = (it['quantity'] as double?) ?? 0;
      final double totalpieces = (it['pieces'] as double?) ?? 0;
      final double discount = (it['discount'] as num?)?.toDouble() ?? 0.0;
      final double taxAmt = (it['taxamount'] as num?)?.toDouble() ?? 0.0;

      baseTotal += price * totalpieces;
      discountTotal += discount;
      taxTotal += taxAmt;
    }

    final double payable = baseTotal - discountTotal + taxTotal;

    return (
      gross: baseTotal,
      discount: discountTotal,
      tax: taxTotal,
      net: payable,
    );
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
    final stockProvider = context.read<StockProvider>();

    String today = stockProvider.formatInvoiceDate(widget.headerData['invoicedate']);
    final totals = _calculateTotals();
    //String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    int weekNumber(DateTime date) {
      final firstDayOfYear = DateTime(date.year, 1, 1);
      final days = date.difference(firstDayOfYear).inDays;
      return ((days + firstDayOfYear.weekday) / 7).ceil();
    }
    final Map<String, dynamic> docData = {
      ...widget.headerData,
      'transactionid': widget.transactionId,
      'items': _items,
      'gross': totals.gross,
      'discount': totals.discount,
      'tax': totals.tax,
      'netval': totals.net,
      'date': today,
      'year': now.year.toString(), // 2026
      'month': '${now.year}.${now.month}', // 2026.5
      'week': '${now.year}.${weekNumber(now)}', // 2026.32
      'day': DateFormat('EEEE').format(now),
    };

    if (widget.headerData.containsKey('items')) {
      docData['editedat'] = FieldValue.serverTimestamp();
      docData['editedby'] = widget.headerData['createdby'] ?? 'unknown';
      docData['date'] = widget.headerData['date'] ?? today;

      final oldItems = List<Map<String, dynamic>>.from(
        widget.headerData['items'] ?? [],
      );

      final insufficientItems = <String>[];

      for (final oldItem in oldItems) {
        final itemId = oldItem['itemid'].toString();

        // Find the edited item. If it doesn't exist, it means it was deleted.
        final newItem = _items.firstWhere(
              (e) => e['itemid'] == itemId,
          orElse: () => <String, dynamic>{
            'itemid': itemId,
            'item': oldItem['item'],
            'stockin_pieces': 0,
            'pieces': 0,
          },
        );

        final oldPieces =
        (oldItem['stockin_pieces'] ?? oldItem['pieces'] ?? 0) as num;

        final newPieces =
        (newItem['stockin_pieces'] ?? newItem['pieces'] ?? 0) as num;

        final piecesToRemove = oldPieces.toDouble() - newPieces.toDouble();

        if (piecesToRemove > 0) {
          final availableBalance =
          await stockProvider.fetchItemCurrentBalance(
            itemId: itemId,
            selectedBranch: widget.headerData['branchid'],
          );

          if (availableBalance < piecesToRemove) {
            insufficientItems.add(
              '${newItem['item']}\n'
                  'Available: ${availableBalance.toInt()} pcs\n'
                  'Trying to remove: ${piecesToRemove.toInt()} pcs',
            );
          }
        }
      }
      if (insufficientItems.isNotEmpty) {
        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cannot Edit Stock Invoice'),
            content: SingleChildScrollView(
              child: Text(
                'The following items no longer have enough stock to apply this edit:\n\n'
                    '${insufficientItems.join('\n\n')}',
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: () => Navigator.pop(context, false),
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
      final batch = FirebaseFirestore.instance.batch();

      for (final item in _items) {
        final oldCp = double.tryParse(item['originalcp'].toString())?? 0;
        final oldPieces=double.tryParse(item['oldPieces'].toString())?? 0;
        final oldValue = oldPieces * oldCp;

        final newCp = double.tryParse(item['price'].toString()) ?? 0;
        final newPieces = double.tryParse(item['pieces'].toString()) ?? 0;
        final newval=double.tryParse(item['total'].toString())?? 0;

        final totalpieces=oldPieces+newPieces;
        final totalValue=oldValue+newval;
        final calculatedCp = totalpieces == 0 ? 0.0 : double.parse((totalValue / totalpieces).toStringAsFixed(2));
        print(
          "${item['itemid']} -> old cp: $oldCp -> old pcs: $oldPieces -> oldValue:$oldValue ->new cp: $newCp -> newval: $newval ->calc cp:$calculatedCp ->totalval:$totalValue",
        );

        if (oldCp != newCp) {
          batch.update(
            FirebaseFirestore.instance
                .collection('itemsreg')
                .doc(item['itemid']),
            {
              'oldcp': oldCp,
              'cp': calculatedCp,
              'newcp': newCp,
              'lastModified': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      await batch.commit();
      await FirebaseFirestore.instance
          .collection('stock_transactions')
          .doc(widget.transactionId)
          .set(docData, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _saved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Records saved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stack) {
      debugPrint('ERROR: $e');
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _printRecords() async {
    final pdf = pw.Document();
    final totals = _calculateTotals();
    final currencyFormat = NumberFormat.currency(
      symbol: 'GHC ',
      decimalDigits: 2,
    );

    // Helper function to format numbers
    String fmtNum(dynamic v) {
      if (v == null || v.toString().isEmpty) return '-';
      if (v is int) return v.toString();
      if (v is double || v is num) {
        final numVal = v as num;
        return currencyFormat.format(numVal.toDouble());
      }
      return v.toString();
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    // Helper function for table cells
    pw.Widget _tableCell(
      String text, {
      bool isHeader = false,
      pw.TextAlign align = pw.TextAlign.left,
      bool bold = false,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isHeader || bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: isHeader ? PdfColors.blue900 : PdfColors.grey800,
          ),
          textAlign: align,
        ),
      );
    }

    pw.Widget _infoRowRight(String label, String value) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.openSansRegular(),
          bold: await PdfGoogleFonts.openSansBold(),
        ),
        build: (context) {
          return <pw.Widget>[
            // Header Section
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 24),
              child: pw.Column(
                children: [
                  // Company Logo/Name
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            widget.headerData['company']?.toUpperCase() ??
                                'COMPANY NAME',
                            style: pw.TextStyle(
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'STOCK ENTRY INVOICE',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.normal,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Separator
                  pw.Container(
                    height: 1,
                    decoration: pw.BoxDecoration(
                      gradient: const pw.LinearGradient(
                        colors: [PdfColors.blue100, PdfColors.grey300],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Document Information
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.blue100, width: 1),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left Column
                        pw.Flexible(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _infoRow(
                                'Invoice Number:',
                                widget.headerData['invoice'] ?? 'N/A',
                              ),
                              pw.SizedBox(height: 6),
                              _infoRow(
                                'Waybill Number:',
                                widget.headerData['waybill'] ?? 'N/A',
                              ),
                              pw.SizedBox(height: 6),
                              _infoRow(
                                'Staff:',
                                widget.headerData['createdby'] ?? 'N/A',
                              ),
                            ],
                          ),
                        ),

                        // Right Column
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              _infoRowRight(
                                'Supplier:',
                                widget.headerData['suppliername'] ?? 'N/A',
                              ),
                              pw.SizedBox(height: 6),
                              _infoRowRight(
                                'Branch:',
                                widget.headerData['branchname'] ?? 'N/A',
                              ),
                              pw.SizedBox(height: 6),

          _infoRowRight(
          'Date:',
          widget.headerData['invoicedate'] is Timestamp
          ? dateFormat.format(
          (widget.headerData['invoicedate'] as Timestamp).toDate(),
          )
              : widget.headerData['invoicedate'] is DateTime
          ? dateFormat.format(widget.headerData['invoicedate'])
              : widget.headerData['invoicedate']?.toString() ?? 'N/A',
          ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Items Table Section
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 24),
              child: pw.Column(
                children: [
                  // Table Title
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Text(
                      'TRANSACTION ITEMS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ),

                  // Items Table
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300, width: 1),
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(4),
                        topRight: pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Table(
                      border: null,
                      columnWidths: {
                        0: const pw.FixedColumnWidth(30), // #
                        1: const pw.FlexColumnWidth(3.0), // Item
                        2: const pw.FlexColumnWidth(1.2), // Mode
                        3: const pw.FlexColumnWidth(0.9), // Mode Qty
                        //4: const pw.FlexColumnWidth(0.9),   // Pieces
                        5: const pw.FlexColumnWidth(0.9), // Qty
                        6: const pw.FlexColumnWidth(1.2), // Unit Price
                        // 7: const pw.FlexColumnWidth(1.2),   // Discount
                        8: const pw.FlexColumnWidth(1.4), // Total
                      },
                      children: [
                        // Table Header
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius: pw.BorderRadius.only(
                              topLeft: pw.Radius.circular(4),
                              topRight: pw.Radius.circular(4),
                            ),
                          ),
                          children: [
                            _tableCell(
                              '#',
                              isHeader: true,
                              align: pw.TextAlign.center,
                            ),
                            _tableCell('ITEM DESCRIPTION', isHeader: true),
                            _tableCell('MODE', isHeader: true),
                            _tableCell(
                              'MODE QTY',
                              isHeader: true,
                              align: pw.TextAlign.right,
                            ),
                            //_tableCell('PIECES', isHeader: true, align: pw.TextAlign.right),
                            _tableCell(
                              'QTY',
                              isHeader: true,
                              align: pw.TextAlign.right,
                            ),
                            _tableCell(
                              'UNIT PRICE',
                              isHeader: true,
                              align: pw.TextAlign.right,
                            ),
                            //_tableCell('DISCOUNT', isHeader: true, align: pw.TextAlign.right),
                            _tableCell(
                              'TOTAL',
                              isHeader: true,
                              align: pw.TextAlign.right,
                            ),
                          ],
                        ),

                        // Data Rows with alternating colors
                        ..._items.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final it = entry.value;
                          final bool isEven = entry.key % 2 == 0;

                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: isEven
                                  ? PdfColors.white
                                  : PdfColors.grey50,
                            ),
                            children: [
                              _tableCell(
                                idx.toString(),
                                align: pw.TextAlign.center,
                              ),
                              _tableCell(it['item']?.toString() ?? '-'),
                              _tableCell(
                                it['stockingmode']?.toString() ??
                                    it['salesMode']?.toString() ??
                                    '-',
                              ),
                              _tableCell(
                                fmtNum(it['modeqty'] ?? it['modeQty'] ?? ''),
                                align: pw.TextAlign.right,
                              ),
                              //_tableCell(fmtNum(it['pieces'] ?? ''), align: pw.TextAlign.right),
                              _tableCell(
                                fmtNum(it['quantity'] ?? ''),
                                align: pw.TextAlign.right,
                              ),
                              _tableCell(
                                fmtNum(it['price'].toStringAsFixed(2) ?? ''),
                                align: pw.TextAlign.right,
                              ),
                              // _tableCell(fmtNum(it['discount'] ?? ''), align: pw.TextAlign.right),
                              _tableCell(
                                fmtNum(it['total'].toStringAsFixed(2) ?? ''),
                                align: pw.TextAlign.right,
                                bold: true,
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Summary Section
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 320,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Summary Title
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 16),
                      child: pw.Text(
                        'TRANSACTION SUMMARY',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),

                    // Summary Rows
                    _summaryRow(
                      'Gross Total:',
                      fmtNum(totals.gross.toStringAsFixed(2)),
                      isHighlighted: false,
                    ),
                    pw.SizedBox(height: 8),
                    //_summaryRow('Total Discount:', fmtNum(totals.discount), isHighlighted: false),
                    pw.SizedBox(height: 8),
                    _summaryRow(
                      'Tax Amount:',
                      fmtNum(totals.tax.toStringAsFixed(2)),
                      isHighlighted: false,
                    ),

                    // Divider
                    pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 12),
                      child: pw.Divider(
                        height: 1,
                        thickness: 1,
                        color: PdfColors.grey400,
                      ),
                    ),

                    // Net Total
                    _summaryRow(
                      'NET TOTAL:',
                      fmtNum(totals.net.toStringAsFixed(2)),
                      isHighlighted: true,
                    ),

                    // Item Count
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 16),
                      child: pw.Text(
                        'Total Items: ${_items.length}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Section
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 40),
              child: pw.Column(
                children: [
                  pw.Divider(height: 1, thickness: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Left Footer
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Generated by: ${widget.headerData['createdby'] ?? 'System'}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),

                      // Right Footer
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Page 1 of 1',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          // pw.Text(
                          //   'Document ID: ${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}',
                          //   style: pw.TextStyle(
                          //     fontSize: 8,
                          //     color: PdfColors.grey500,
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // Helper widget for info rows
  pw.Widget _infoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  // Helper widget for summary rows
  pw.Widget _summaryRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isHighlighted ? 14 : 12,
            fontWeight: isHighlighted
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: isHighlighted ? PdfColors.blue900 : PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isHighlighted ? 16 : 12,
            fontWeight: pw.FontWeight.bold,
            color: isHighlighted ? PdfColors.blue900 : PdfColors.grey800,
          ),
        ),
      ],
    );
  }

  Future _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
      );

      if (result != null) {
        setState(() {
          print("qrcode:$result");
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
                                    const Text(
                                      "STOCK ENTRIES",
                                      style: TextStyle(
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
                                                  controller:
                                                      _barcodeController,
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
                                                  color: const Color(
                                                    0xFF22304A,
                                                  ),
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
                                                  tooltip:
                                                      'Scan Barcode/QR Code',
                                                ),
                                              ),
                                            ],
                                          ),

                                          if (_showSuggestions)
                                            StreamBuilder<
                                              List<Map<String, dynamic>>
                                            >(
                                              stream:
                                                  Provider.of<Datafeed>(
                                                    context,
                                                    listen: false,
                                                  ).itemsStream(
                                                    collectionName: 'itemsreg',
                                                  ),
                                              builder: (context, snapshot) {
                                                if (!snapshot.hasData) {
                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            color: Colors.blue,
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  );
                                                }

                                                final allDocs = snapshot.data!;
                                                final filteredDocs = allDocs
                                                    .where((doc) {

                                                  final data =   doc as Map<String,dynamic>;
                                                      final name =(data['name'] ?? '').toString().toLowerCase();
                                                      final barcode = (data['barcode'] ?? '').toString().toLowerCase();
                                                      final query = _searchQuery.toLowerCase();
                                                      return name.contains(query,) ||barcode.contains(query,); }).take(10).toList();

                                                if (filteredDocs.isEmpty)
                                                  return const SizedBox.shrink();

                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF22304A,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.blue
                                                          .withOpacity(0.3),
                                                    ),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Colors.black26,
                                                        blurRadius: 8,
                                                        offset: Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxHeight: 250,
                                                      ),
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        filteredDocs.length,
                                                    itemBuilder: (context, index) {
                                                      final doc =
                                                          filteredDocs[index];
                                                      final item =
                                                          doc
                                                              as Map<
                                                                String,
                                                                dynamic
                                                              >;
                                                      item['id'] = doc['id'];

                                                      return ListTile(
                                                        dense: true,
                                                        leading: const Icon(
                                                          Icons.inventory_2,
                                                          color: Colors.blue,
                                                          size: 20,
                                                        ),
                                                        title: Text(
                                                          item['name'] ?? '',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        subtitle: Text(
                                                          'Barcode: ${item['barcode']}',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                        trailing: const Icon(
                                                          Icons
                                                              .arrow_forward_ios,
                                                          color: Colors.white54,
                                                          size: 14,
                                                        ),
                                                        onTap: () =>
                                                            _selectItem(item),
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          const SizedBox(height: 10),
                                          _loadingBalance
                                              ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ): TextFormField(
                                            controller: _itemController,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Item',
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
                                              fillColor: const Color(
                                                0xFF22304A,
                                              ),
                                              filled: true,
                                            ),
                                            validator: (value) =>
                                                value == null || value.isEmpty
                                                ? 'Item required'
                                                : null,
                                          ),
                                          const SizedBox(height: 10),
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              const spacing = 10.0;
                                              const minFieldWidth = 200.0;

                                              final width = constraints.maxWidth;

                                              final columns = width >= (minFieldWidth * 2 + spacing) ? 2 : 1;

                                              final fieldWidth = columns == 2
                                                  ? (width - spacing) / 2
                                                  : width;

                                              return Wrap(
                                                spacing: spacing,
                                                runSpacing: spacing,
                                                children: [
                                                  SizedBox(
                                                    width: fieldWidth,
                                                    child: DropdownButtonFormField<String>(
                                                      value: _selectedStockMode,
                                                      dropdownColor: const Color(0xFF22304A),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText: 'Stocking Mode',
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
                                                      items: _stockMode.isEmpty
                                                          ? null
                                                          : _stockMode.map((type) {
                                                        return DropdownMenuItem<String>(
                                                          value: type,
                                                          child: Text(
                                                            type,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        );
                                                      }).toList(),
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _selectedStockMode = value;
                                                        });
                                                      },
                                                      validator: (value) => value == null
                                                          ? 'Please select stocking mode'
                                                          : null,
                                                    ),
                                                  ),

                                                  SizedBox(
                                                    width: fieldWidth,
                                                    child: TextFormField(
                                                      controller: _priceController,
                                                      keyboardType: const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.allow(
                                                          RegExp(r'^\d*\.?\d*$'),
                                                        ),
                                                      ],
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText: 'Price',
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
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: _quantityController,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d*$'),
                                              ),
                                            ],
                                            decoration: InputDecoration(
                                              labelText: 'Quantity',
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
                                              fillColor: const Color(
                                                0xFF22304A,
                                              ),
                                              filled: true,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Enter quantity';
                                              }
                                              final qty = double.tryParse(
                                                value,
                                              );
                                              if (qty == null) {
                                                return 'Quantity must be a number';
                                              }
                                              if (qty <= 0) {
                                                return 'Quantity must be greater than 0';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          DropdownButtonFormField<String>(
                                            value: _selectedTaxType,
                                            dropdownColor: const Color(
                                              0xFF22304A,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Tax Type',
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
                                              fillColor: const Color(
                                                0xFF22304A,
                                              ),
                                              filled: true,
                                            ),
                                            items: _taxType
                                                .map(
                                                  (t) => DropdownMenuItem(
                                                    value: t,
                                                    child: Text(t),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (val) => setState(
                                              () => _selectedTaxType = val,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: _discountController,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d*$'),
                                              ),
                                            ],
                                            decoration: InputDecoration(
                                              labelText: 'Purchase Discount',
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
                                              fillColor: const Color(
                                                0xFF22304A,
                                              ),
                                              filled: true,
                                            ),
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
                                                      backgroundColor:
                                                          Colors.orangeAccent,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 16,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    onPressed: _loading
                                                        ? null
                                                        : _addItem,
                                                    child: const Text(
                                                      "Add Record",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              SizedBox(
                                                width: 150,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.lightBlue,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _itemController.clear();
                                                      _priceController.clear();
                                                      _quantityController
                                                          .clear();
                                                      _discountController.text =
                                                          '0';
                                                      _taxValueController.text =
                                                          '0';
                                                      _barcodeController
                                                          .clear();
                                                      _loadingBalance=false;
                                                    });
                                                  },

                                                  child: const Text(
                                                    "Reset",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 150,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.teal,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    widget.onNewTransaction();
                                                  },
                                                  child: const Text(
                                                    "New Transaction",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
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
                                  headerdata: widget.headerData,
                                  items: _items,
                                  onPrint: _saveRecords,
                                  onNewTransaction: _printRecords,
                                  onDeleteItem: (index) {
                                    setState(() {
                                      _items.removeAt(index);
                                    });
                                  },
                                  loading: _loading, saved: false,
                                )
                              : _buildStockTable(itemWidth),
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
                "STOCK PREVIEW",
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
                  // 4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1),
                  // 6: FlexColumnWidth(1),
                  7: FlexColumnWidth(1),
                  8: FlexColumnWidth(1), // extra column for delete
                },
                children: [
                  _tableRow([
                    "#",
                    "Item",
                    "Mode",
                    "Qty",
                    //"Pieces",
                    "Unit Price",
                    "Discount",
                    //"Tax",
                    "Total",
                    "Action",
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
                    final discountText = (item['discount'] != null)
                        ? (item['discount'] as double).toStringAsFixed(2)
                        : '0.00';
                    // final taxText = (item['taxamount'] != null)
                    //     ? (item['taxamount'] as double).toStringAsFixed(2)
                    //     : '0.00';

                    return TableRow(
                      children: [
                        _cell((idx + 1).toString()),
                        _cell(item['item']?.toString() ?? ''),
                        _cell(item['stockingmode']?.toString() ?? ''),
                        _cell(
                          item['quantity']?.toString() ?? '0',
                          alignRight: true,
                        ),
                        // _cell(item['pieces']?.toString() ?? '0', alignRight: true),
                        _cell(priceText, alignRight: true),
                        _cell(discountText, alignRight: true),
                        // _cell(taxText, alignRight: true),
                        _cell(totalText, alignRight: true),
                        _saved
                            ? const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Confirm Delete"),
                                        content: const Text(
                                          "Are you sure you want to delete this item?",
                                        ),
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
                              ),
                      ],
                    );
                  }).toList(),
                  (() {
                    return _tableRow(["", "", "", "", "", "", "", ""]);
                  })(),
                  (() {
                    final totals = _calculateTotals();
                    return _tableRow([
                      "",
                      "Grand Total",
                      "",
                      "",
                      //"",
                      "",
                      totals.discount!.toStringAsFixed(2),
                      //totals.tax!.toStringAsFixed(2),
                      totals.net!.toStringAsFixed(2),
                      "",
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
                              : Text(
                                  widget.headerData.containsKey('items')
                                      ? "UPDATE RECORDS"
                                      : "SAVE RECORDS",
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    if (_saved)
                      SizedBox(
                        width: 150,
                        child: OutlinedButton.icon(
                          onPressed: _printRecords,
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
              ),
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
            style: const TextStyle(color: Colors.white).copyWith(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
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
  final Map<String, dynamic> headerdata;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onPrint;
  final VoidCallback? onNewTransaction;
  final void Function(int index)? onDeleteItem;
  final bool loading;
  final bool saved;
  const MobileSalesPreview({
    super.key,
    required this.headerdata,
    required this.items,
    this.onPrint,
    this.onNewTransaction,
    this.onDeleteItem,
    this.loading = false,
    required this.saved,
  });

  double get totalAmount {
    return items.fold(0.0, (sum, item) {
      return sum + (item['total'] ?? 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> datas;
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
              "Stock Preview",
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
              return _cartItem(
                name: item['item'] ?? '',
                price: (item['price'] ?? 0.0).toDouble(),
                qty: double.tryParse(item['quantity'].toString()) ?? 0,
                mode: item['stockingmode'] ?? "",
                total: (item['total'] ?? 0.0).toDouble(),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Confirm Delete"),
                      content: const Text(
                        "Are you sure you want to delete this item?",
                      ),
                      actions: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    onDeleteItem?.call(index);
                  }
                }, // use callback
              );
            },
          ),

          const Divider(color: Colors.white24),
          _row(
            "Grand Total",
            "GHC ${totalAmount.toStringAsFixed(2)}",
            bold: true,
          ),
          const SizedBox(height: 18),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!saved)
                _actionBtn(
                  headerdata.containsKey('items')
                      ? "UPDATE RECORDS"
                      : "SAVE RECORDS",
                  Colors.teal,
                  onPrint,
                ),

              if (saved)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: onNewTransaction,
                  child: const Text(
                    "PRINT",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          )        ],
      ),
    );
  }

  Widget _cartItem({
    required String name,
    required double price,
    required double qty,
    required String mode,
    required double total,
    required VoidCallback onDelete,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(
            Icons.delete,
            color: Colors.redAccent,
          ),
          onPressed: onDelete,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item name can wrap
              Text(
                name,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              // Details wrap within available width
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _responsiveDetail(
                    "Price",
                    "GHC ${price.toStringAsFixed(2)}",
                  ),
                  _responsiveDetail(
                    "Mode",
                    mode,
                  ),
                  _responsiveDetail(
                    "Qty",
                    "$qty",
                  ),
                  _responsiveDetail(
                    "Total",
                    "GHC ${total.toStringAsFixed(2)}",
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _responsiveDetail(String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 80,
        maxWidth: 220,
      ),
      child: RichText(
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        text: TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(String text, Color color, VoidCallback? onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
    );
  }
}
