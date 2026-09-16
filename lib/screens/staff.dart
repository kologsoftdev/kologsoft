import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' hide Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kologsoft/models/branch.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:kologsoft/widgets/salespagewidgets/snackmsg.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

import '../providers/Datafeed.dart';
import '../models/staffmodel.dart';

class Staff extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;
  final StaffModel? staff;

  const Staff({Key? key, this.docId, this.data, this.staff}) : super(key: key);

  @override
  State<Staff> createState() => _StaffState();
}

class _StaffState extends State<Staff> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String? _accesslevel;
  String? _selectedBranch;
  List<String> _assignedWarehouseIds = [];
  bool _pricingRetail = false;
  bool _pricingWholesale = false;
  bool _pricingNone = false;

  bool _payCash = false;
  bool _payCredit = false;
  bool _payMomo = false;
  bool _payBankTransfer = false;
  bool _payCheque = false;
  bool _payCard = false;

  bool _loading = false;
  Uint8List? _logoBytes;
  File? _logoFile;
  String? _existingLogoUrl;
  bool? _canPrint = true;
  bool? _canEditPrice = false;
  bool? _canSelectDate = false;
  bool? _canSellAnyBranch = false;
  bool? _allowDiscountCode = false;
  bool? _allowDiscount = false;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  String? _resolveBranchId(List<BranchModel> branches, String? current) {
    if (current == null || current.isEmpty) return null;
    final hasId = branches.any((b) => b.id == current);
    if (hasId) return current;
    final match = branches.firstWhere(
          (b) => b.branchname == current,
      orElse: () => BranchModel(),
    );
    return match.id.isNotEmpty ? match.id : null;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(!mounted)return;
      context.read<Datafeed>().fetchBranches();
    });


    if (widget.data != null) {
      final d = widget.data!;
      _existingLogoUrl = d['imageurl'];
      _nameController.text = d['name'] ?? '';
      _canPrint = d['canPrint'] ?? true;
      _canEditPrice = d['canEditPrice'] ?? false;
      _canSelectDate = d['canSelectDate'] ?? false;
      _canSellAnyBranch = d['canSellAnyBranch'] ?? false;
      _allowDiscount = d['allowDiscount'] ?? false;
      _allowDiscountCode = d['allowDiscountCode'] ?? false;
      _emailController.text = d['email'] ?? '';
      _phoneController.text = d['phone'] ?? '';
      _accesslevel = d['accesslevel'] ?? d['accessLevel'];

      _selectedBranch =  d['branchId'] ?? d['branch'] ?? d['branche'] ?? d['branchname'];
      // initialize pricing mode if provided (supports String or List)
      final pricingRaw = d['pricingMode'] ?? d['pricing'];
      List<String> pricingList = [];
      if (pricingRaw is List) {
        pricingList = pricingRaw.map((e) => e.toString()).toList();
      }
      else if (pricingRaw is String) {
        pricingList = pricingRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      _pricingRetail = pricingList.contains('retail');
      _pricingWholesale = pricingList.contains('wholesale');
      _pricingNone = pricingList.contains('none');


      final allowedRaw =
          d['allowedPaymentMethods'] ??
              d['allowed_payment_methods'] ??
              d['paymentMethods'] ??
              d['payment_methods'];
      List<String> allowed = [];
      if (allowedRaw is List) {
        allowed = allowedRaw.map((e) => e.toString()).toList();
      } else if (allowedRaw is String) {
        allowed = allowedRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      String norm(String v) {
        final m = v.trim().toLowerCase();
        if (m == 'bank' || m == 'bank transfer' || m == 'banktransfer') {
          return 'bank_transfer';
        }
        if (m == 'mobilemoney' || m == 'mobile money') return 'momo';
        return m.replaceAll(' ', '_');
      }

      final allowedSet = allowed.map(norm).toSet();
      // If field not present, keep defaults (all true). If present, use it.
      _payCash = allowedSet.contains('cash');
      _payCredit = allowedSet.contains('credit');
      _payMomo = allowedSet.contains('momo');
      _payBankTransfer = allowedSet.contains('bank_transfer');
      _payCheque = allowedSet.contains('cheque');
      _payCard = allowedSet.contains('card');
      // if (allowedSet.isNotEmpty) {
      //   _payCash = allowedSet.contains('cash');
      //   _payCredit = allowedSet.contains('credit');
      //   _payMomo = allowedSet.contains('momo');
      //   _payBankTransfer = allowedSet.contains('bank_transfer');
      //   _payCheque = allowedSet.contains('cheque');
      //   _payCard = allowedSet.contains('card');
      // }
      final warehousesRaw =
          d['warehouseIds'] ?? d['warehouseids'] ?? d['warehouses'];
      if (warehousesRaw is List) {
        _assignedWarehouseIds = warehousesRaw.map((e) => e.toString()).toList();
      } else if (warehousesRaw is String && warehousesRaw.isNotEmpty) {
        _assignedWarehouseIds = warehousesRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      final startRaw = d['startdate'];
      if (startRaw is Timestamp) {
        _selectedStartDate = startRaw.toDate();
      } else if (startRaw is DateTime) {
        _selectedStartDate = startRaw;
      }

      final endRaw = d['enddate'];
      if (endRaw is Timestamp) {
        _selectedEndDate = endRaw.toDate();
      } else if (endRaw is DateTime){
        _selectedEndDate = endRaw;
      }

      // _barcodeController.text = d['barcode'] ?? '';
      // _costController.text = d['costprice'] ?? '';
      // _productType = d['producttype'];
      // _productCategory = d['productcategory'];
    }

    if (widget.staff != null) {
      final s = widget.staff!;

      _nameController.text = s.name;
      _emailController.text = s.email;
      _phoneController.text = s.phone;
      _accesslevel = s.accesslevel;
      _selectedBranch = s.branchid;
      _selectedStartDate = s.startdate;
      _selectedEndDate = s.enddate;

      _existingLogoUrl = s.imageurl;
      _canPrint = s.canPrint;
      _canEditPrice = s.canEditPrice;
      _canSelectDate = s.canSelectDate;
      _canSellAnyBranch = s.canSellAnyBranch;
      _allowDiscount = s.allowDiscount;
      _allowDiscountCode = s.allowDiscountCode;
      _pricingRetail = s.pricingmode.contains('retail');
      _pricingWholesale = s.pricingmode.contains('wholesale');
      _pricingNone = s.pricingmode.contains('none');

      final allowedSet = s.allowedPaymentMethods.toSet();
      _payCash = allowedSet.contains('cash');
      _payCredit = allowedSet.contains('credit');
      _payMomo = allowedSet.contains('momo');
      _payBankTransfer = allowedSet.contains('bank_transfer');
      _payCheque = allowedSet.contains('cheque');
      _payCard = allowedSet.contains('card');

      _assignedWarehouseIds = s.salesWarehouseIds;
    }
    if (widget.docId != null && widget.data == null && widget.staff == null) {
      _loadExistingStaff(widget.docId!);
    }
  }

  Future<void> pickLogo() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    if (kIsWeb) {
      _logoBytes = await picked.readAsBytes();
      _logoFile = null;
    } else {
      _logoFile = File(picked.path);
      _logoBytes = null;
    }

    setState(() {});
  }
  Future<void> _loadExistingStaff(String id) async {
    final doc = await _db.collection('staff').doc(id).get();
    if (!mounted || !doc.exists) return;

    final d = doc.data()!;
    setState(() {
      _existingLogoUrl = d['imageurl'];
      _nameController.text = d['name'] ?? '';
      _emailController.text = d['email'] ?? '';
      _phoneController.text = d['phone'] ?? '';
      _accesslevel = d['accesslevel'] ?? d['accessLevel'];
      _selectedBranch = d['branchId'] ?? d['branch'] ?? d['branche'] ?? d['branchname'];

      _canPrint = d['canPrint'] ?? true;
      _canEditPrice = d['canEditPrice'] ?? false;
      _canSelectDate = d['canSelectDate'] ?? false;
      _canSellAnyBranch = d['canSellAnyBranch'] ?? false;
      _allowDiscount = d['allowDiscount'] ?? false;
      _allowDiscountCode = d['allowDiscountCode'] ?? false;

      final pricingRaw = d['pricingMode'] ?? d['pricing'] ?? d['pricingmode'];
      List<String> pricingList = [];
      if (pricingRaw is List) {
        pricingList = pricingRaw.map((e) => e.toString()).toList();
      } else if (pricingRaw is String) {
        pricingList = pricingRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      _pricingRetail = pricingList.contains('retail');
      _pricingWholesale = pricingList.contains('wholesale');
      _pricingNone = pricingList.contains('none');

      final allowedRaw = d['allowedPaymentMethods'] ?? d['allowed_payment_methods'] ??
          d['paymentMethods'] ?? d['payment_methods'];
      List<String> allowed = [];
      if (allowedRaw is List) {
        allowed = allowedRaw.map((e) => e.toString()).toList();
      } else if (allowedRaw is String) {
        allowed = allowedRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      String norm(String v) {
        final m = v.trim().toLowerCase();
        if (m == 'bank' || m == 'bank transfer' || m == 'banktransfer') return 'bank_transfer';
        if (m == 'mobilemoney' || m == 'mobile money') return 'momo';
        return m.replaceAll(' ', '_');
      }
      final allowedSet = allowed.map(norm).toSet();
      _payCash = allowedSet.contains('cash');
      _payCredit = allowedSet.contains('credit');
      _payMomo = allowedSet.contains('momo');
      _payBankTransfer = allowedSet.contains('bank_transfer');
      _payCheque = allowedSet.contains('cheque');
      _payCard = allowedSet.contains('card');

      final warehousesRaw = d['warehouseIds'] ?? d['warehouseids'] ?? d['warehouses'];
      if (warehousesRaw is List) {
        _assignedWarehouseIds = warehousesRaw.map((e) => e.toString()).toList();
      } else if (warehousesRaw is String && warehousesRaw.isNotEmpty) {
        _assignedWarehouseIds = warehousesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      final startRaw = d['startdate'];
      if (startRaw is Timestamp) _selectedStartDate = startRaw.toDate();
      final endRaw = d['enddate'];
      if (endRaw is Timestamp) _selectedEndDate = endRaw.toDate();
    });
  }
  Future<String?> uploadLogo(String itemId) async {
    if (_logoFile == null && _logoBytes == null) {
      return _existingLogoUrl; // unchanged
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('items')
        .child('$itemId.png');

    UploadTask task;

    if (kIsWeb) {
      task = ref.putData(
        _logoBytes!,
        SettableMetadata(contentType: 'image/png'),
      );
    } else {
      task = ref.putFile(
        _logoFile!,
        SettableMetadata(contentType: 'image/png'),
      );
    }

    final snap = await task;
    return snap.ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: Text(widget.docId == null ? 'Register Staff' : 'Edit Staff'),
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
                      _imagePickerSection(),
                      const SizedBox(height: 10),
                      _buildField(_nameController, 'Staff Name', Icons.person),
                      const SizedBox(height: 10),
                      _buildField(
                        _emailController,
                        'Email',
                        Icons.email,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter an email';
                          }
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(v)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildField(
                        _phoneController,
                        'Phone',
                        Icons.phone,
                        isNumber: true,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^[0-9+]*$'),
                          ),
                          LengthLimitingTextInputFormatter(13),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a phone number';
                          }
                          final phoneRegex = RegExp(r'^(0[0-9]{9}|\+233[0-9]{9})$');
                          if (!phoneRegex.hasMatch(v)) {
                            return 'Enter a valid phone number (e.g. 0241234567 or +233241234567)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _accesslevel,
                        dropdownColor: const Color(0xFF22304A),
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildDropdownDecoration('Access Level'),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('admin'),
                          ),
                          DropdownMenuItem(
                            value: 'super admin',
                            child: Text('super admin'),
                          ),
                          DropdownMenuItem(
                            value: 'warehouse',
                            child: Text('warehouse'),
                          ),
                          DropdownMenuItem(
                            value: 'sales',
                            child: Text('sales'),
                          ),
                          DropdownMenuItem(
                            value: 'cashier',
                            child: Text('cashier'),
                          ),
                          DropdownMenuItem(
                            value: 'sales attendance',
                            child: Text('sales attendance'),
                          ),
                          DropdownMenuItem(
                            value: 'sales manager',
                            child: Text('sales manager'),
                          ),
                          DropdownMenuItem(
                            value: 'operations officers',
                            child: Text('operations officers'),
                          ),
                          DropdownMenuItem(
                            value: 'stock officer',
                            child: Text('stock officer'),
                          ),
                          DropdownMenuItem(
                            value: 'accountant',
                            child: Text('accountant'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _accesslevel = v),
                        validator: (v) =>
                        v == null ? 'Select product type' : null,
                      ),
                      const SizedBox(height: 10),
                      Consumer<Datafeed>(
                        builder: (context, datafeed, _) {
                          if (datafeed.branches.isEmpty) {
                            return const Text(
                              "No branches found",
                              style: TextStyle(color: Colors.white54),
                            );
                          }

                          final resolvedBranchId = _resolveBranchId(
                            datafeed.branches,
                            _selectedBranch,
                          );
                          final branchValue =
                              resolvedBranchId ?? _selectedBranch;
                          BranchModel? selectedBranch;
                          if (branchValue != null) {
                            selectedBranch = datafeed.branches.firstWhere(
                                  (b) => b.id == branchValue,
                              orElse: () => BranchModel(),
                            );
                          }

                          final branchTypeRaw =
                              selectedBranch?.branchtype ?? '';
                          final branchType = branchTypeRaw.toLowerCase().trim();
                          final isSalesPoint =
                              branchType == 'sales point' ||
                                  branchType == 'salespoint';
                          final warehouseBranches = datafeed.branches
                              .where(
                                (b) =>
                            b.branchtype.toLowerCase().trim() ==
                                'warehouse',
                          )
                              .toList();
                          String hintText = 'Select a branch to see its type.';
                          if (isSalesPoint) {
                            hintText =
                            'Sales Point: sells from warehouses with stock balance.';
                          } else if (branchType == 'sales branch' ||
                              branchType == 'salesbranch') {
                            hintText = 'Sales Branch: holds its own stock.';
                          } else if (branchType == 'warehouse') {
                            hintText =
                            'Warehouse: keeps stock to transfer or fulfill branch requests.';
                          } else if (branchTypeRaw.isNotEmpty) {
                            hintText = 'Branch Type: $branchTypeRaw';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: branchValue,
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white),
                                decoration: _buildDropdownDecoration(
                                  'Select Branch',
                                ),
                                items: datafeed.branches
                                    .map(
                                      (w) => DropdownMenuItem<String>(
                                    value: w.id,
                                    child: Text(w.branchname),
                                  ),
                                )
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _selectedBranch = v;
                                  final selected = datafeed.branches.firstWhere(
                                        (b) => b.id == v,
                                    orElse: () => BranchModel(),
                                  );
                                  final selectedType = selected.branchtype
                                      .toLowerCase()
                                      .trim();
                                  final isSelectedSalesPoint =
                                      selectedType == 'sales point' ||
                                          selectedType == 'salespoint';
                                  if (!isSelectedSalesPoint) {
                                    _assignedWarehouseIds.clear();
                                  }
                                }),
                                validator: (v) =>
                                v == null ? 'Select Staff Branch' : null,
                              ),
                              const SizedBox(height: 6),

                              // Payment methods checkboxes
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Allowed Payment Methods',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 6),
                                  CheckboxListTile(
                                    value: _payCash,
                                    onChanged: (v) =>
                                        setState(() => _payCash = v ?? false),
                                    title: const Text(
                                      'Cash',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    controlAffinity:
                                    ListTileControlAffinity.leading,
                                    activeColor: Colors.blue,
                                    tileColor: const Color(0xFF22304A),
                                    contentPadding: EdgeInsets.zero,
                                    side: BorderSide(color: Colors.white70),
                                  ),
                                  CheckboxListTile(
                                    value: _payCredit,
                                    onChanged: (v) =>
                                        setState(() => _payCredit = v ?? false),
                                    title: const Text(
                                      'Credit',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    controlAffinity:
                                    ListTileControlAffinity.leading,
                                    activeColor: Colors.blue,
                                    tileColor: const Color(0xFF22304A),
                                    contentPadding: EdgeInsets.zero,
                                    side: BorderSide(color: Colors.white70),
                                  ),
                                  CheckboxListTile(
                                    value: _payMomo,
                                    onChanged: (v) =>
                                        setState(() => _payMomo = v ?? false),
                                    title: const Text(
                                      'MOMO',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    controlAffinity:
                                    ListTileControlAffinity.leading,
                                    activeColor: Colors.blue,
                                    tileColor: const Color(0xFF22304A),
                                    contentPadding: EdgeInsets.zero,
                                    side: BorderSide(color: Colors.white70),
                                  ),
                                  CheckboxListTile(
                                    value: _payBankTransfer,
                                    onChanged: (v) => setState(
                                          () => _payBankTransfer = v ?? false,
                                    ),
                                    title: const Text(
                                      'Bank Transfer',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    controlAffinity:
                                    ListTileControlAffinity.leading,
                                    activeColor: Colors.blue,
                                    tileColor: const Color(0xFF22304A),
                                    contentPadding: EdgeInsets.zero,
                                    side: BorderSide(color: Colors.white70),
                                  ),
                                  CheckboxListTile(
                                    value: _payCard,
                                    onChanged: (v) =>
                                        setState(() => _payCard = v ?? false),
                                    title: const Text(
                                      'Card',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    controlAffinity:
                                    ListTileControlAffinity.leading,
                                    activeColor: Colors.blue,
                                    tileColor: const Color(0xFF22304A),
                                    contentPadding: EdgeInsets.zero,
                                    side: BorderSide(color: Colors.white70),
                                  ),
                                  CheckboxListTile(
                                    value: _payCheque,
                                    onChanged: (v) =>
                                        setState(() => _payCheque = v ?? false),
                                    title: const Text(
                                      'Cheque',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    controlAffinity:
                                    ListTileControlAffinity.leading,
                                    activeColor: Colors.blue,
                                    tileColor: const Color(0xFF22304A),
                                    contentPadding: EdgeInsets.zero,
                                    side: BorderSide(color: Colors.white70),
                                  ),
                                ],
                              ),

                              Text(
                                hintText,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              if (isSalesPoint) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Assign Warehouses',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                if (warehouseBranches.isEmpty)
                                  const Text(
                                    'No warehouse branches found.',
                                    style: TextStyle(color: Colors.white54),
                                  )
                                else
                                  ...warehouseBranches.map(
                                        (w) => CheckboxListTile(
                                      value: _assignedWarehouseIds.contains(
                                        w.id,
                                      ),
                                      onChanged: (v) => setState(() {
                                        if (v == true) {
                                          _assignedWarehouseIds.add(w.id);
                                        } else {
                                          _assignedWarehouseIds.remove(w.id);
                                        }
                                      }),
                                      title: Text(
                                        w.branchname,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      controlAffinity:
                                      ListTileControlAffinity.leading,
                                      activeColor: Colors.blue,
                                      tileColor: const Color(0xFF22304A),
                                      contentPadding: EdgeInsets.zero,
                                      side: BorderSide(color: Colors.white70),
                                    ),
                                  ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      // Pricing mode checkboxes (mutually exclusive)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pricing Mode',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          CheckboxListTile(
                            value: _pricingRetail,
                            onChanged: (v) => setState(() {
                              _pricingRetail = v ?? false;
                              // selecting retail should clear 'none' if set
                              if (_pricingRetail) _pricingNone = false;
                            }),
                            title: const Text(
                              'Retail',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                            side: BorderSide(color: Colors.white70),
                          ),
                          CheckboxListTile(
                            value: _pricingWholesale,
                            onChanged: (v) => setState(() {
                              _pricingWholesale = v ?? false;
                              // selecting wholesale should clear 'none' if set
                              if (_pricingWholesale) _pricingNone = false;
                            }),
                            title: const Text(
                              'Wholesale',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                            side: BorderSide(color: Colors.white70),
                          ),
                          CheckboxListTile(
                            value: _pricingNone,
                            onChanged: (v) => setState(() {
                              _pricingNone = v ?? false;
                              if (_pricingNone) {
                                _pricingRetail = false;
                                _pricingWholesale = false;
                              }
                            }),
                            title: const Text(
                              'None',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                            side: BorderSide(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Auto Print Receipt',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),

                          RadioListTile<bool>(
                            value: true,
                            groupValue: _canPrint,
                            onChanged: (v) => setState(() => _canPrint = v),
                            title: const Text(
                              'Yes',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),

                          RadioListTile<bool>(
                            value: false,
                            groupValue: _canPrint,
                            onChanged: (v) => setState(() => _canPrint = v),
                            title: const Text(
                              'No',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allow Price Editing',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          RadioListTile<bool>(
                            value: true,
                            groupValue: _canEditPrice,
                            onChanged: (v) => setState(() => _canEditPrice = v),
                            title: const Text(
                              'Yes',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<bool>(
                            value: false,
                            groupValue: _canEditPrice,
                            onChanged: (v) => setState(() => _canEditPrice = v),
                            title: const Text(
                              'No',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allow Past Sale Dates',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          RadioListTile<bool>(
                            value: true,
                            groupValue: _canSelectDate,
                            onChanged: (v) => setState(() => _canSelectDate = v),
                            title: const Text(
                              'Yes',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<bool>(
                            value: false,
                            groupValue: _canSelectDate,
                            onChanged: (v) => setState(() => _canSelectDate = v),
                            title: const Text(
                              'No',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allow Sales From Any Branch',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          RadioListTile<bool>(
                            value: true,
                            groupValue: _canSellAnyBranch,
                            onChanged: (v) => setState(() => _canSellAnyBranch = v),
                            title: const Text(
                              'Yes',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<bool>(
                            value: false,
                            groupValue: _canSellAnyBranch,
                            onChanged: (v) => setState(() => _canSellAnyBranch = v),
                            title: const Text(
                              'No',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allow Discounts',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          RadioListTile<bool>(
                            value: true,
                            groupValue: _allowDiscount,
                            onChanged: (v) => setState(() => _allowDiscount = v),
                            title: const Text(
                              'Yes',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<bool>(
                            value: false,
                            groupValue: _allowDiscount,
                            onChanged: (v) => setState(() => _allowDiscount = v),
                            title: const Text(
                              'No',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allow Discount Codes',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          RadioListTile<bool>(
                            value: true,
                            groupValue: _allowDiscountCode,
                            onChanged: (v) => setState(() => _allowDiscountCode = v),
                            title: const Text(
                              'Yes',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<bool>(
                            value: false,
                            groupValue: _allowDiscountCode,
                            onChanged: (v) => setState(() => _allowDiscountCode = v),
                            title: const Text(
                              'No',
                              style: TextStyle(color: Colors.white70),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.blue,
                            tileColor: const Color(0xFF22304A),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedStartDate ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            textButtonTheme: TextButtonThemeData(
                                              style: ButtonStyle(
                                                foregroundColor: WidgetStatePropertyAll(Colors.white),
                                              ),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) setState(() => _selectedStartDate = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22304A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedStartDate != null
                                              ? "${_selectedStartDate!.day}/${_selectedStartDate!.month}/${_selectedStartDate!.year}"
                                              : 'Start Date',
                                          style: TextStyle(
                                            color: _selectedStartDate != null ? Colors.white : Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedEndDate ?? _selectedStartDate ?? DateTime.now(),
                                      firstDate: _selectedStartDate ?? DateTime(2000),
                                      lastDate: DateTime(2100),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            textButtonTheme: TextButtonThemeData(
                                              style: ButtonStyle(
                                                foregroundColor: WidgetStatePropertyAll(Colors.white),
                                              ),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) setState(() => _selectedEndDate = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22304A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedEndDate != null
                                              ? "${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}"
                                              : 'End Date',
                                          style: TextStyle(
                                            color: _selectedEndDate != null ? Colors.white : Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 10,),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF415A77),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _loading
                              ? null
                              : () async {
                            if (!_formKey.currentState!.validate()) {
                              return;
                            }
                            setState(() => _loading = true);
                            final bool canPrint = _canPrint ?? false;
                            final bool canEditPrice = _canEditPrice ?? false;
                            final bool canSelectDate = _canSelectDate ?? false;
                            final bool canSellAnyBranch = _canSellAnyBranch ?? false;
                            final bool allowDiscount = _allowDiscount ?? false;
                            final bool allowDiscountCode = _allowDiscountCode ?? false;
                            final name = _nameController.text.trim();
                            final email = _emailController.text.trim();
                            final phone = _phoneController.text.trim();
                            final access = _accesslevel ?? '';
                            final branchId = _resolveBranchId(datafeed.branches,_selectedBranch,) ??'';

                            // find branch name from provider's list
                            String branchName = '';
                            String branchType = '';
                            for (var b in datafeed.branches) {
                              if (b.id == branchId) {
                                branchName = b.branchname;
                                branchType = b.branchtype;
                                break;
                              }
                            }

                            final normalizedBranchType = branchType.toLowerCase().trim();
                            final isSalesPoint = normalizedBranchType == 'sales point' ||
                                    normalizedBranchType == 'salespoint';
                            final assignedWarehouseIds = isSalesPoint ? _assignedWarehouseIds
                                : <String>[];
                            final assignedWarehouseNames =
                            assignedWarehouseIds.map(
                                  (id) => datafeed.branches.firstWhere(
                                    (b) => b.id == id,
                                orElse: () => BranchModel(),
                              ).branchname,
                            ).where((name) => name.isNotEmpty).toList();


                            final docid = email.toLowerCase();
                            try {
                              final id = (widget.docId ?? docid).toLowerCase();


                              final staffRef = _db.collection('staff');

                              final query = await staffRef
                                  .where('email', isEqualTo: email.trim())
                                  .limit(1)
                                  .get();

                              final isCreating = widget.docId == null;

                              if (query.docs.isNotEmpty) {
                                final matchedDocId = query.docs.first.id.toLowerCase();
                                final isSameUser = matchedDocId == id;

                                if (!isSameUser) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.red,
                                      content: Text(
                                        isCreating
                                            ? 'Staff already exists'
                                            : 'Email already used by another staff',
                                        style: TextStyle(color: ColorScheme.of(context).onPrimary),
                                      ),
                                    ),
                                  );
                                  setState(() => _loading = false);
                                  return;
                                }
                              }
                              final imageUrl = await uploadLogo(id);
                              // collect one-or-more pricing modes
                              final List<String> pricingModes = [];
                              if (_pricingRetail)
                                pricingModes.add('retail');
                              if (_pricingWholesale) {
                                pricingModes.add('wholesale');
                              }
                              if (_pricingNone) pricingModes.add('none');

                              // collect allowed payment methods
                              final List<String> allowedPaymentMethods = [];
                              if (_payCash) {
                                allowedPaymentMethods.add('cash');
                              }
                              if (_payCredit) {
                                allowedPaymentMethods.add('credit');
                              }
                              if (_payMomo) {
                                allowedPaymentMethods.add('momo');
                              }
                              if (_payBankTransfer) {
                                allowedPaymentMethods.add(
                                  'bank_transfer',
                                );
                              }
                              if (_payCheque) {
                                allowedPaymentMethods.add('cheque');
                              }
                              if (_payCard) {
                                allowedPaymentMethods.add('card');
                              }
                              // build StaffModel
                              final staffModel = StaffModel(
                                company: datafeed.company,
                                id: id,
                                name: name,
                                email: email,
                                phone: phone,
                                accesslevel: access,
                                branchid: branchId,
                                branchname: branchName,
                                pricingmode: pricingModes,
                                createdat: widget.staff?.createdat ?? Timestamp.now(),
                                createdby: widget.staff?.createdby ?? datafeed.staff,
                                deletedat: widget.staff?.deletedat,
                                deletedby: widget.staff?.deletedby,
                                companyid: datafeed.companyid,
                                startdate: _selectedStartDate,
                                enddate: _selectedEndDate,
                                salesWarehouseIds: assignedWarehouseIds,
                                salesWarehouseNames: assignedWarehouseNames,
                                allowedPaymentMethods: allowedPaymentMethods,
                                canPrint: canPrint,
                                canEditPrice: canEditPrice,
                                canSelectDate: canSelectDate,
                                canSellAnyBranch: canSellAnyBranch,
                                allowDiscount: allowDiscount,
                                allowDiscountCode: allowDiscountCode,
                                imageurl: imageUrl ?? '',
                                WarehouseIds: assignedWarehouseIds,
                                WarehouseNames: assignedWarehouseNames,
                                permissions: widget.staff?.permissions,
                              );
                              final record = staffModel.toMap()
                                ..removeWhere((key, value) => value == null);

                              /*
                              final record = staffModel.toMap();
                              record.addAll({
                                'warehouseids': assignedWarehouseIds,
                                'salesWarehouseIds': assignedWarehouseIds,
                                'warehousenames': assignedWarehouseNames,
                                'salesWarehouseNames': assignedWarehouseNames,
                                'allowedPaymentMethods': allowedPaymentMethods,
                                'imageurl': imageUrl ?? '',
                                'canPrint': canPrint,
                                'canEditPrice': canEditPrice,
                                'canSelectDate': canSelectDate,
                                'canSellAnyBranch': canSellAnyBranch,
                                'allowDiscount': allowDiscount,
                                'allowDiscountCode': allowDiscountCode,
                              });
                                   */

                             // if (widget.docId == null) {
                                await _db.collection('staff').doc(id).set(record, SetOptions(merge: true));

                              snackMsg(context, widget.docId == null
                                  ? 'Staff Registered Successfully'
                                  : 'Staff Updated Successfully', Colors.green);


                              // reset form
                            if (widget.docId == null){

                            _nameController.clear();
                            _emailController.clear();
                            _phoneController.clear();
                            setState(() {
                            _accesslevel = null;
                            _selectedBranch = null;
                            _assignedWarehouseIds = [];
                            });
                          }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }

                            if (!mounted) return;
                            setState(() => _loading = false);
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
                              const Icon(
                                Icons.save,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.docId == null
                                    ? 'Save Staff'
                                    : 'Update Staff',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 4),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF415A77),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, Routes.staffView);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.view_list_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text("View Staff"),
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

  // ================= IMAGE UI =================
  Widget _imagePickerSection() {
    Widget preview;

    if (_logoBytes != null) {
      preview = Image.memory(_logoBytes!, fit: BoxFit.contain);
    } else if (_logoFile != null) {
      preview = Image.file(_logoFile!, fit: BoxFit.contain);
    } else if (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty) {
      preview = Image.network(_existingLogoUrl!, fit: BoxFit.contain);
    } else {
      preview = const Icon(Icons.image, size: 40, color: Colors.white38);
    }

    final bool hasImage =_logoBytes != null ||  _logoFile != null ||
        (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Image (optional)',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),

        // show preview only when an image exists (hide by default)
        if (hasImage) ...[
          GestureDetector(
            onTap: pickLogo,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF22304A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Center(child: preview),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],

        TextButton.icon(
          onPressed: pickLogo,
          icon: const Icon(Icons.upload),
          label: const Text('Select Image'),
        ),
      ],
    );
  }

  // ================= FIELDS =================
  Widget _priceField(
      TextEditingController controller,
      String label,
      IconData icon,
      ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white70),
      decoration: _inputDecoration(label, icon),
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