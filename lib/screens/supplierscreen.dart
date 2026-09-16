import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/suppliermodel.dart';
import '../providers/routes.dart';

class SupplierRegistration extends StatefulWidget {
  final Supplier? supplier;
  const SupplierRegistration({super.key, this.supplier});

  @override
  State<SupplierRegistration> createState() => _SupplierRegistrationState();
}

class _SupplierRegistrationState extends State<SupplierRegistration> {
  final _formKey = GlobalKey<FormState>();

  final _supplierController = TextEditingController();
  final _contactController = TextEditingController();

  bool _isSubmitting = false;

  String? validateField(String? value, {required String type}) {
    final v = value?.trim() ?? '';

    final validators = <String, String? Function(String)>{
      'text': (val) => val.isEmpty ? 'Required' : null,
      'phone': (val) {
        if (val.isEmpty) return 'Phone number is required';
        if (!RegExp(r'^\+?[0-9]+$').hasMatch(val)) return 'Enter a valid phone number';
        final length = val.replaceAll('+', '').length;
        if (length < 9 || length > 15) return 'Enter a valid phone number';
        return null;
      },
      'email': (val) {
        if (val.isEmpty) return 'Email is required';
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) return 'Enter a valid email';
        return null;
      },
    };

    final validator = validators[type];
    if (validator != null) return validator(v);

    return null;
  }
  @override
  void initState() {
    super.initState();

    if (widget.supplier != null) {
      _supplierController.text = widget.supplier!.supplier;
      _contactController.text = widget.supplier!.contact;
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final formWidth = screenWidth > 900 ? screenWidth * 0.6 : screenWidth * 0.95;

    return Consumer<Datafeed>(builder: (context, value, child) {
      return Scaffold(
        backgroundColor: const Color(0xFF101624),
        appBar: AppBar(
          title: const Text('Register Supplier'), // header stays consistent
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Container(
                  width: formWidth,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B263B),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Supplier field
                        TextFormField(
                          controller: _supplierController,
                          cursorColor: Colors.white,
                          style: const TextStyle(color: Colors.white70),
                          decoration: _inputDecoration('Supplier', Icons.store),
                          validator: (v) => validateField(v, type: 'text')
                        ),
                        const SizedBox(height: 14),
                        // Contact field
                        TextFormField(
                          controller: _contactController,
                          cursorColor: Colors.white,
                          style: const TextStyle(color: Colors.white70),
                          decoration: _inputDecoration('Contact', Icons.phone),
                          validator: (v) => validateField(v, type: 'phone')
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            // Save
                            SizedBox(
                              width:200,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  Colors.lightBlue,
                                  padding:
                                  const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:  BorderRadius.circular(
                                      8,
                                    ),
                                  ),
                                ),

                                onPressed: _isSubmitting
                                    ? null
                                    : () async {
                                  if (!_formKey.currentState!.validate() || _isSubmitting) return;
                                  setState(() => _isSubmitting = true);

                                  final nameInput = _supplierController.text.trim();

                                  final query = await value.db
                                      .collection('suppliers')
                                      .where('supplier', isEqualTo: nameInput)
                                      .where('companyid', isEqualTo: value.companyid)
                                      .limit(1)
                                      .get();

                                  if (query.docs.isNotEmpty && query.docs.first.id != widget.supplier?.id) {
                                    setState(() => _isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text('A supplier with this name already exists'),
                                      ),
                                    );
                                    return;
                                  }

                                  final id = widget.supplier?.id ??
                                      '${value.companyid}_${value.staffPosition}_${nameInput.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')}';

                                  final supplier = Supplier(
                                    id: id,
                                    supplier: nameInput,
                                    contact: _contactController.text.trim(),
                                    company: value.company,
                                    companyid: value.companyid,
                                    branchid: value.branchid,
                                    datecreated: Timestamp.now(),
                                    staff: value.staff,
                                  );

                                 await value.addOrUpdateSupplier(supplier);

                                  setState(() {
                                    _isSubmitting = false;
                                    _supplierController.clear();
                                    _contactController.clear();
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Text(
                                      widget.supplier == null ? 'Supplier saved successfully' : 'Supplier updated successfully',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ));

                                  if (!mounted) return;
                                  if (widget.supplier?.id != null) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: _isSubmitting
                                    ? const CircularProgressIndicator(
                                    color: Colors.white)
                                    : Text(widget.supplier == null ? 'Save Supplier' : 'Update Supplier',
                                   style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                            // View
                            SizedBox(
                              width: 200,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white70),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.view_list, color: Colors.white70),
                                label: const Text(
                                  "View",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(context, Routes.supplierlist);
                                },
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
      );
    });
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
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
}
