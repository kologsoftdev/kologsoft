
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

import '../models/branch.dart';
import '../models/companymodel.dart';
import '../models/staffmodel.dart';
import '../providers/Datafeed.dart';
import 'login_screen.dart';


const _kBg = Color(0xFF101624);
const _kCard = Color(0xFF1B263B);
const _kHeaderStrip = Color(0xFF0D1420);
const _kFieldFill = Color(0xFF22304A);
const _kAccent = Colors.blue;
const _kButton = Color(0xFF415A77);

class CompanyRegPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;
  final bool isSuperAdmin;
  final bool isSystemAdmin;
  const CompanyRegPage({Key? key, this.docId,this.isSuperAdmin = false, this.isSystemAdmin = false, this.data}) : super(key: key);

  @override
  State<CompanyRegPage> createState() => _CompanyRegPageState();
}

class _CompanyRegPageState extends State<CompanyRegPage> {
  final TextEditingController _vatRateController = TextEditingController();
  bool _vatEnabled = false;
  final _formKey = GlobalKey<FormState>();

  final _companyController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _domainsController = TextEditingController();
  String _address = '';
  String _branchType = "retail";
  String? _mode;
  bool _loading = false;
  String idd = '';
  Uint8List? _logoBytes;
  File? _logoFile;
  String? _existingLogoUrl;

  // ── Wizard state
  int _currentStep = 0;
  final List<String> _stepLabels = const ["Company", "Owner", "Setup", "Plan"];
  String _selectedPlan = "free_trial";

  // Payment
  String _paymentMethod = "momo";
  final _paymentNumberController = TextEditingController();

  List<String> get _effectiveStepLabels =>
      (_selectedPlan == "free_trial" || widget.docId != null)
          ? _stepLabels
          : [..._stepLabels, "Payment"];

  static const List<Map<String, dynamic>> _plans = [
    {
      'id': 'free_trial',
      'icon': Icons.flag,
      'name': 'Free Trial',
      'price': 'GHC 0',
      'priceNote': '10 days · No card needed',
      'features': ['All core features', 'Up to 5 users · 1 property'],
      'popular': false,
      'amount': 0.0,
    },
    {
      'id': 'starter',
      'icon': Icons.star,
      'name': 'Starter',
      'price': 'GHC 1,000/mo',
      'priceNote': '≈ USD 63 · +GHC 3k setup',
      'features': ['Up to 10 users · 1-3 properties', 'SMS + Email + POS'],
      'popular': false,
      'amount': 1000.0,
    },
    {
      'id': 'professional',
      'icon': Icons.business_center,
      'name': 'Professional',
      'price': 'GHC 2,000/mo',
      'priceNote': '≈ USD 125 · +GHC 3k setup',
      'features': ['Up to 20 users · 10 properties', 'AI Reports + Analytics'],
      'popular': true,
      'amount': 2000.0,
    },
    {
      'id': 'enterprise',
      'icon': Icons.apartment,
      'name': 'Enterprise',
      'price': 'GHC 4,000/mo',
      'priceNote': '≈ USD 250 · +GHC 3k setup',
      'features': ['Unlimited users · 20+ properties', 'Dedicated support'],
      'popular': false,
      'amount': 4000.0,
    },
  ];
  static const List<String> testimonials = [
    '"The service was excellent and made everything so easy for me!"',
    '"I am very happy with the quality and support I received."',
    '"Professional, fast, and reliable. Highly recommended!"',
  ];

  final String randomTestimonial =
  testimonials[Random().nextInt(testimonials.length)];

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      final d = widget.data!;
      _companyController.text = d['company'] ?? '';
      _nameController.text = d['name'] ?? '';
      _phoneController.text = d['phone'] ?? '';
      _emailController.text = d['email'] ?? '';
      _addressController.text = d['address'] ?? '';
      final rawDomains = d['customDomains'];
      if (rawDomains is List) {
        _domainsController.text = rawDomains.map((e) => e.toString()).join(', ');
      } else {
        _domainsController.text = (rawDomains ?? '').toString();
      }

      _branchType = d['type'] ?? 'retail';
      _mode = d['branch'] ?? 'Main';
      _existingLogoUrl = d['logo'];

      // VAT fields
      final vat = d['vat'];
      _vatRateController.text = (vat != null) ? vat.toString() : '';
      _vatEnabled = d['vatEnabled'] ?? false;
      _selectedPlan = d['plan'] ?? d['subscriptionTier'] ?? 'free_trial';

    }
  }

  String _normalizeDomain(String input) {
    final raw = input.trim().toLowerCase();
    if (raw.isEmpty) return '';

    final withScheme = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    final host = (uri?.host ?? '').trim().toLowerCase();
    if (host.isEmpty) return '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  List<String> _parseDomains(String raw) {
    final parts = raw.split(RegExp(r'[\s,\n]+'));
    final normalized = parts
        .map(_normalizeDomain)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    normalized.sort();
    return normalized;
  }

  String normalizeKey(String input) {
    return input.trim().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  Future<void> pickLogo() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
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


  Future<String?> uploadLogo(String companyId) async {
    if (_logoFile == null && _logoBytes == null) {
      return _existingLogoUrl; // no new logo selected
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('company_logos')
        .child('$companyId.png');

    UploadTask uploadTask;

    if (kIsWeb) {
      uploadTask = ref.putData(
        _logoBytes!,
        SettableMetadata(contentType: 'image/png'),
      );
    } else {
      uploadTask = ref.putFile(
        _logoFile!,
        SettableMetadata(contentType: 'image/png'),
      );
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }


  void _goNext() {
    final isValid = _formKey.currentState?.validate() ?? true;
    if (!isValid) return;
    if (_currentStep < _effectiveStepLabels.length - 1) {
      setState(() => _currentStep += 1);
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<bool> _processGatewayPayment(String method, double amount) async {
   return false;

  }

  Future<void> _submit(Datafeed datafeed) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_mode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a branch mode")),
      );
      return;
    }

    setState(() => _loading = true);

    final staff = datafeed.staff;
    final companyName = _companyController.text.trim();
    final customDomains = _parseDomains(_domainsController.text);
    _address = _addressController.text.trim();

    try {
      if (widget.docId == null && _selectedPlan != 'free_trial') {
        final plan = _plans.firstWhere((p) => p['id'] == _selectedPlan);
        final amount = plan['amount'] as double;

        if (_paymentMethod == 'paystack' || _paymentMethod == 'hubtel') {

          final ok = await _processGatewayPayment(_paymentMethod, amount);
          if (!ok) {
            throw Exception("Payment could not be verified. Please try again.");
          }
        } else {
          // print(_paymentMethod);
          // print(_paymentNumberController.text.trim());
          // print(amount);
        }
      }


      if (widget.docId != null) {
        final id = widget.docId!;
        final logoUrl = await uploadLogo(id);

        await _db.collection('companies').doc(id).update({
          'company': companyName,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'address': _addressController.text.trim(),
          'customDomains': customDomains,
          'type': _branchType,
          'branch': _mode,
          'logo': logoUrl ?? "",
          'vat': double.tryParse(_vatRateController.text) ?? 0.0,
          'vatEnabled': _vatEnabled,
          'plan': _selectedPlan,
          'subscriptionTier': _selectedPlan,
          if (_selectedPlan != 'free_trial') 'paymentMethod': _paymentMethod,
          if (_selectedPlan != 'free_trial')
            'paymentReference': _paymentNumberController.text.trim(),
          'updatedat': DateTime.now(),
          'updatedby': staff,
        });
      }


      else {
        final existing = await _db
            .collection('companies')
            .where('company', isEqualTo: companyName)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          throw Exception("Company already exists");
        }

        await _db.runTransaction((tx) async {
          final counterRef = _db.collection('counters').doc('company_ids');

          final counterSnap = await tx.get(counterRef);

          int last = counterSnap.exists ? (counterSnap['last'] ?? 0) : 0;
          final next = last + 1;

          tx.set(counterRef, {'last': next});

          final newId = "KS00$next";
          idd = newId;
          final logoUrl = await uploadLogo(newId);

          final model = CompanyModel(
            id: newId,
            company: companyName,
            companyid: newId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            address: _addressController.text.trim(),
            branch: _mode!,
            type: _branchType,
            logo: logoUrl ?? "",
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            updatedBy: staff,
            customDomains: customDomains,
            subscriptionTier: _selectedPlan,
          );

          final companyMap = model.toMap();
          companyMap['vat'] = double.tryParse(_vatRateController.text) ?? 0.0;
          companyMap['vatEnabled'] = _vatEnabled;
          companyMap['plan'] = _selectedPlan;
          if (_selectedPlan != 'free_trial') {
            companyMap['paymentMethod'] = _paymentMethod;
            companyMap['paymentReference'] = _paymentNumberController.text.trim();
          }

          tx.set(_db.collection('companies').doc(newId), companyMap);

          final mainBranchId = '${newId}main';
          final staffId = _db.collection('staff').doc().id;
          final staffModel = StaffModel(
            company: companyName,
            id: staffId,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            accesslevel: 'super admin',
            allowedPaymentMethods: const [
              'cash',
              'credit',
              'momo',
              'bank_transfer',
              'cheque',
              'card',
            ],
            pricingmode: _branchType == 'retail'
                ? ['retail']
                : _branchType == 'wholesale'
                ? ['wholesale']
                : ['retail', 'wholesale'],
            createdat: Timestamp.now(),
            createdby: staff,
            companyid: newId,
            branchid: mainBranchId.toLowerCase(),
          );

          tx.set(
            _db
                .collection('staff')
                .doc(_emailController.text.toString().toLowerCase()),
            staffModel.toMap(),
          );
        });
      }

      if (widget.docId == null) {
        final branch = BranchModel(
          id: '${idd.toLowerCase()}main',
          branchname: 'Main',
          branchtype: 'Sales Point',
          address: _address,
          branchcontact: _phoneController.text.trim(),
          staff: _nameController.text.trim(),
          companyid: idd,
          companyemail: _emailController.text.toString().toLowerCase(),
          date: DateTime.now(),
          updatedat: DateTime.now(),
          deletedat: DateTime.now(),
          updatedby: '',
          deletedby: '',
        );
        await datafeed.addOrUpdateBranch(branch);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.docId == null
                ? (_selectedPlan == 'free_trial'
                ? "Company and Staff Registered Successfully"
                : "Payment received — your account has been created successfully")
                : "Company Updated Successfully",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: TextStyle(color: Colors.white))),
      );
    }

    setState(() => _loading = false);
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
        return Scaffold(
          backgroundColor: _kBg,
          appBar: AppBar(
            backgroundColor: _kBg,
            title: Text(
              widget.docId == null ? "Register Company" : "Edit Company",
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final wizardCard = _buildWizardCard(datafeed, isWide);

              if (!isWide) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      _buildLeftPanel(),
                      const SizedBox(height: 24),
                      Center(child: wizardCard),
                    ],
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(child: _buildLeftPanel()),
                  ),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: wizardCard,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWizardCard(Datafeed datafeed, bool isWide) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderStrip(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildStepContent(),
                    const SizedBox(height: 28),
                    _buildNavButtons(datafeed),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'login?',
                        style: TextStyle(color: Colors.white70),
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

  //desktop
  Widget _buildLeftPanel() {
    final features = <Map<String, dynamic>>[
      {'icon': Icons.point_of_sale, 'title': 'Sales & POS', 'desc': 'Fast checkout, multiple payment methods'},
      {'icon': Icons.inventory_2, 'title': 'Stock & Inventory', 'desc': 'Transfers, requests & stock levels'},
      {'icon': Icons.store, 'title': 'Multi-Branch', 'desc': 'Run several branches from one account'},
      {'icon': Icons.assignment_return, 'title': 'Damages & Returns', 'desc': 'Track returned and damaged stock'},
      {'icon': Icons.admin_panel_settings, 'title': 'Role-Based Access', 'desc': 'Control what each staff member can do'},
      {'icon': Icons.bar_chart, 'title': 'Sales Reports', 'desc': 'Staff, branch & payment breakdowns'},
      {'icon': Icons.print, 'title': 'Receipt Printing', 'desc': 'Silent printing straight to your printer'},
      {'icon': Icons.devices, 'title': 'Any Device', 'desc': 'Windows desktop, tablet or phone'},
    ];

    return Container(
      color: _kBg,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Run Your Business Smarter",
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const Text(
            "with KologSoft POS",
            style: TextStyle(color: _kAccent, fontSize: 30, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 14),
          const Text(
            "The all-in-one platform for sales, inventory, billing and multi-branch"
                " management — built for African businesses.",
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: const [
              _StatBadge(label: "10-day", note: "FREE TRIAL"),
              _StatBadge(label: "Multi-Branch", note: "READY"),
              _StatBadge(label: "Windows +", note: "MOBILE"),
            ],
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = features
                  .map((f) => _buildFeatureTile(f['icon'] as IconData, f['title'] as String, f['desc'] as String))
                  .toList();

              if (constraints.maxWidth < 420) {
                // Single column — let each tile take whatever height its text needs.
                return Column(
                  children: [
                    for (final tile in tiles) ...[
                      tile,
                      if (tile != tiles.last) const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              // Two columns — fixed width per tile, natural (unconstrained) height.
              final tileWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              randomTestimonial,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kFieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white70, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: brand strip + step indicator
  Widget _buildHeaderStrip() {
    return Container(
      width: double.infinity,
      color: _kHeaderStrip,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Column(
        children: [
          const Text(
            "KologSoft POS",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Company setup · takes about a minute",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 18),
          _buildStepper(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final labels = _effectiveStepLabels;
    return LayoutBuilder(
      builder: (context, constraints) {
        final connectorWidth = constraints.maxWidth < 340 ? 16.0 : 32.0;
        final circleRadius = constraints.maxWidth < 340 ? 12.0 : 15.0;

        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length * 2 - 1, (i) {
            if (i.isOdd) {
              final leftStep = i ~/ 2;
              final done = leftStep < _currentStep;
              return Container(
                width: connectorWidth,
                height: 2,
                color: done ? _kAccent : Colors.white24,
              );
            }
            final step = i ~/ 2;
            final isActive = step == _currentStep;
            final isDone = step < _currentStep;
            return SizedBox(
              width: circleRadius * 2 + 16,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: circleRadius,
                    backgroundColor: isActive || isDone ? _kAccent : _kFieldFill,
                    child: isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                      "${step + 1}",
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[step],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        );


        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(child: row),
          ),
        );
      },
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildCompanyStep();
      case 1:
        return _buildOwnerStep();
      case 2:
        return _buildSetupStep();
      case 3:
        return _buildPlanStep();
      default:
        return _buildPaymentStep();
    }
  }

  // ── Step 1: Company details
  Widget _buildCompanyStep() {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Tell us about your business",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: pickLogo,
          child: CircleAvatar(
            radius: 40,
            backgroundColor: _kFieldFill,
            backgroundImage: _logoBytes != null
                ? MemoryImage(_logoBytes!)
                : _logoFile != null
                ? FileImage(_logoFile!) as ImageProvider
                : _existingLogoUrl != null
                ? NetworkImage(_existingLogoUrl!)
                : null,
            child: (_logoBytes == null &&
                _logoFile == null &&
                _existingLogoUrl == null)
                ? const Icon(Icons.camera_alt, color: Colors.white70, size: 26)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Tap to add a logo (optional)",
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 20),
        _buildField(_companyController, "Company Name", Icons.business, enabled:widget.docId == null|| widget.isSuperAdmin || widget.isSystemAdmin),
        const SizedBox(height: 14),
        _buildField(_phoneController, "Phone Number", Icons.phone, enabled: widget.docId == null||widget.isSuperAdmin || widget.isSystemAdmin),
        const SizedBox(height: 14),
        _buildField(_addressController, "Address", Icons.location_on, enabled: widget.docId == null||widget.isSuperAdmin || widget.isSystemAdmin),

      ],
    );
  }

  Widget _buildTypeRadio(String label, String value) {
    final canEdit = widget.docId == null || widget.isSystemAdmin;
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      value: value,
      groupValue: _branchType,
      activeColor: _kAccent,
      contentPadding: EdgeInsets.zero,
      onChanged: canEdit
          ? (v) => setState(() => _branchType = v ?? _branchType)
          : null,
    );
  }
  // ── Step 2: Owner / admin details
  Widget _buildOwnerStep() {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Owner / Admin details",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildField(_nameController, "Contact Person", Icons.person,enabled:widget.docId==null|| widget.isSuperAdmin || widget.isSystemAdmin),
        const SizedBox(height: 14),
        _buildField(_emailController, "Email Address", Icons.email,enabled:widget.docId==null|| widget.isSystemAdmin ),
        const SizedBox(height: 6),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Your login credentials will be sent here.",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text("Business Type", style: TextStyle(color: Colors.white70)),
        ),
        _buildTypeRadio("Retail", "retail"),
        _buildTypeRadio("Wholesale", "wholesale"),
        _buildTypeRadio("Both", "both"),
      ],
    );
  }

  // ── Step 3: Setup (branch mode, VAT, domains)
  Widget _buildSetupStep() {
    return Column(

      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Business setup",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          dropdownColor: _kFieldFill,
          style: const TextStyle(color: Colors.white70),
          decoration: _inputDecoration("Branch Mode", icon: Icons.store),
          value: _mode,
          items: const [
            DropdownMenuItem(value: "single", child: Text("Single branch")),
            DropdownMenuItem(value: "multiple", child: Text("Multiple branches")),
          ],
         // onChanged: (val) => setState(() => _mode = val),
          onChanged: widget.docId==null||widget.isSystemAdmin ? (val) => setState(() => _mode = val) : null,
          validator: (val) => val == null ? "Please select a mode" : null,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final vatField = TextFormField(
              controller: _vatRateController,
              enabled: widget.docId==null || widget.isSystemAdmin,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white70),
              decoration: _inputDecoration(
                'VAT Rate (decimal)',
                icon: Icons.percent,
                hint: 'e.g. 0.15 for 15%',
              ),
            );
            final taxSwitch = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _kFieldFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: SwitchListTile(
                title: const Text('Enable Tax', style: TextStyle(color: Colors.white70, fontSize: 13)),
                value: _vatEnabled,
               // onChanged: (val) => setState(() => _vatEnabled = val),
                onChanged: widget.docId == null ||widget.isSystemAdmin ? (val) => setState(() => _vatEnabled = val) : null,
                activeColor: _kAccent,
                inactiveThumbColor: Colors.grey,
                contentPadding: EdgeInsets.zero,
              ),
            );

            if (constraints.maxWidth < 360) {
              return Column(
                children: [
                  vatField,
                  const SizedBox(height: 12),
                  taxSwitch,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: vatField),
                const SizedBox(width: 12),
                Expanded(child: taxSwitch),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _domainsController,
          enabled: widget.docId == null || widget.isSystemAdmin,
          style: const TextStyle(color: Colors.white70),
          decoration: _inputDecoration('Custom Domains (comma separated)', icon: Icons.public),
        ),
      ],
    );
  }


  // ── Step 4: Plan selection
  Widget _buildPlanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Choose your plan",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "All paid plans include a 10-day free trial. No card required to start.",
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 480) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPlanCard(_plans[0]),
                  const SizedBox(height: 12),
                  _buildPlanCard(_plans[1]),
                  const SizedBox(height: 12),
                  _buildPlanCard(_plans[2]),
                  const SizedBox(height: 12),
                  _buildPlanCard(_plans[3]),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPlanCard(_plans[0])),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPlanCard(_plans[1])),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPlanCard(_plans[2])),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPlanCard(_plans[3])),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final bool isSelected = _selectedPlan == plan['id'];
    final bool isPopular = plan['popular'] == true;

    Color iconColor;
    switch (plan['id'] as String) {
      case 'free_trial':
        iconColor = const Color(0xFFF5A623);
        break;
      case 'enterprise':
        iconColor = const Color(0xFF7B5EEA);
        break;
      default:
        iconColor = _kAccent;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: (widget.docId == null || widget.isSystemAdmin)
              ? () => setState(() => _selectedPlan = plan['id'] as String)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kFieldFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _kButton : _kFieldFill,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: _kAccent.withOpacity(0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(plan['icon'] as IconData, size: 18, color: iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, size: 18, color: _kAccent),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan['price'] as String,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan['priceNote'] as String,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 10),
                for (final f in (plan['features'] as List))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      f.toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isPopular)
          Positioned(
            top: -10,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "POPULAR",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Step 5: Payment

  Widget _buildPaymentStep() {
    final plan = _plans.firstWhere((p) => p['id'] == _selectedPlan, orElse: () => _plans[1]);
    final bool needsPhoneNumber =
        _paymentMethod == 'momo' ||
            _paymentMethod == 'vodafone_cash' ||
            _paymentMethod == 'airteltigo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payment",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          "You selected ${plan['name']} — ${plan['price']}",
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          dropdownColor: _kFieldFill,
          style: const TextStyle(color: Colors.white70),
          decoration: _inputDecoration("Payment Method", icon: Icons.payment),
          value: _paymentMethod,
          items: const [
            DropdownMenuItem(value: "momo", child: Text("MTN Mobile Money")),
            DropdownMenuItem(value: "vodafone_cash", child: Text("Vodafone Cash")),
            DropdownMenuItem(value: "airteltigo", child: Text("AirtelTigo Money")),
            DropdownMenuItem(value: "paystack", child: Text("Paystack (Card, MoMo, Bank)")),
            DropdownMenuItem(value: "hubtel", child: Text("Hubtel (MoMo, Card)")),

          ],
          onChanged: (val) => setState(() => _paymentMethod = val ?? _paymentMethod),
        ),
        const SizedBox(height: 14),
        if (needsPhoneNumber)
          TextFormField(
            controller: _paymentNumberController,
            style: const TextStyle(color: Colors.white70),
            validator: (v) => v == null || v.isEmpty ? "Required" : null,
            decoration: _inputDecoration(
              "Mobile Money Number",
              icon: Icons.phone_android,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kFieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.white54, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _redirectMethodLabel(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        const Text(
          "Payment confirmation is simulated here — wire this up to your actual "
              "payment gateway (e.g. Paystack/Flutterwave/Stripe) before this goes live.",
          style: TextStyle(color: Colors.white38, fontSize: 10.5, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  String _redirectMethodLabel() {
    switch (_paymentMethod) {
      case 'paystack':
        return "You'll be redirected to Paystack's secure checkout to pay by card, Mobile Money, or bank transfer.";
      case 'hubtel':
        return "You'll be redirected to Hubtel's secure checkout to pay by Mobile Money or card.";
      default:
        return "You'll be redirected to a secure checkout page to complete payment.";
    }
  }
  // ── Bottom nav: Back / Continue / Register
  Widget _buildNavButtons(Datafeed datafeed) {
    final isLastStep = _currentStep == _effectiveStepLabels.length - 1;
    final isPlanStep = _currentStep == 3;

    String label;
    if (isLastStep) {
      if (widget.docId != null) {
        label = "Update";
      } else if (_selectedPlan == 'free_trial') {
        label = "Create My Free Account";
      } else {
        label = "Pay & Create Account";
      }
    } else if (isPlanStep && _selectedPlan != 'free_trial' && widget.docId == null) {
      label = "Continue to Payment";
    } else {
      label = "Continue";
    }

    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : _goBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Back", style: TextStyle(color: Colors.white70)),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kButton,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loading
                ? null
                : () => isLastStep ? _submit(datafeed) : _goNext(),
            child: _loading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Text(label, style: const TextStyle(color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kAccent),
      ),
      fillColor: _kFieldFill,
      filled: true,
    );
  }

  Widget _buildField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool enabled = true,
      }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white70),
      validator: (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: _inputDecoration(label, icon: icon),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String note;
  const _StatBadge({required this.label, required this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _kAccent, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          note,
          style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.5),
        ),
      ],
    );
  }
}