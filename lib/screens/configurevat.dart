import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/models/configurevatmodel.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:kologsoft/screens/branch_view.dart';

class ConfigureVatreg extends StatefulWidget {
  final ConfigureVatModel? vat;

  const ConfigureVatreg({super.key, this.vat});

  @override
  State<ConfigureVatreg> createState() => _ConfigureVatregState();
}

class _ConfigureVatregState extends State<ConfigureVatreg> {
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;

  String? _selectedProductType;
  String? _selectedVatType;
  String? _selectedComputationType;

  final List<String> _producttype = ["Product", "Service"];
  final List<String> _vattype = ["Standard", "Flat"];
  final List<String> _computationtype = ["Inclusive", "Exclusive"];

  @override
  void initState() {
    super.initState();

    if (widget.vat != null) {
      _selectedProductType = widget.vat!.producttype;
      _selectedVatType = widget.vat!.vatrate;
      _selectedComputationType = widget.vat!.computationalmethod;
    }
  }

  Future<void> _saveVat(Datafeed value) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isUpdate = widget.vat != null;

      final docId = isUpdate
          ? widget.vat!.id
          : "${value.companyid}_${_selectedVatType}_${_selectedProductType}"
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_');

      final vat = ConfigureVatModel(
        id: docId,
        staff: value.staff,
        companyid: value.companyid,
        companyemail: value.companyemail,
        date: isUpdate ? widget.vat!.date : DateTime.now(),
        updatedat: DateTime.now(),
        deletedat: null,
        updatedby: value.staff,
        deletedby: '',
        producttype: _selectedProductType!,
        vatrate: _selectedVatType!,
        computationalmethod: _selectedComputationType!,
      );

      await value.db.collection('vat').doc(docId)
          .set(vat.toMap(), SetOptions(merge: true));

      if (isUpdate) {
        final index = value.vatList.indexWhere((e) => e.id == docId);

        if (index != -1) {
          value.vatList[index] = vat;
        } else {
          value.vatList.add(vat);
        }
        value.notifyListeners();

        Navigator.pop(context);
      } else {
        setState(() {
          value.vatList.add(vat);
          _selectedProductType = null;
          _selectedVatType = null;
          _selectedComputationType = null;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdate ? 'Vat updated successfully' : 'Vat saved successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Operation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: Text(
              widget.vat != null
                  ? "Edit Vat Configuration"
                  : "Vat Configuration",
            ),
            backgroundColor: const Color(0xFF0D1A26),
            foregroundColor: Colors.white,
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BranchView()),
              );
            },
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildDropdown(
                                label: 'Product Type',
                                value: _selectedProductType,
                                items: _producttype,
                                onChanged: (v) =>
                                    setState(() => _selectedProductType = v),
                              ),
                              const SizedBox(height: 10),
                              _buildDropdown(
                                label: 'VAT Type',
                                value: _selectedVatType,
                                items: _vattype,
                                onChanged: (v) =>
                                    setState(() => _selectedVatType = v),
                              ),
                              const SizedBox(height: 10),
                              _buildDropdown(
                                label: 'Computation Type',
                                value: _selectedComputationType,
                                items: _computationtype,
                                onChanged: (v) =>
                                    setState(() => _selectedComputationType = v),
                              ),
                              const SizedBox(height: 20),

                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: 200,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _isSaving
                                          ? null
                                          : () => _saveVat(value),
                                      child: _isSaving
                                          ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                          : Text(
                                        widget.vat != null ? "Update" : "Add",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
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
                                        Navigator.pushNamed( context,
                                          Routes.configurevatview,
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

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      dropdownColor: const Color(0xFF22304A),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF22304A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Please select $label' : null,
    );
  }
}