import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:provider/provider.dart';

import '../models/addtaxvatmodel.dart';

class addTaxVat extends StatefulWidget {
  final addTaxVatModel? vat;
  final String? docId;
  const addTaxVat({super.key, this.vat,this.docId});

  @override
  State<addTaxVat> createState() => _addTaxVatState();
}

class _addTaxVatState extends State<addTaxVat> {
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;

  // Controllers for VAT fields
  final TextEditingController _vatController = TextEditingController();
  final TextEditingController _getFundController = TextEditingController();
  final TextEditingController _nhilController = TextEditingController();
  final TextEditingController _covidController = TextEditingController();

  String? _selectedVatType;

  final List<String> _vattype = ["Standard", "Flat"];

  @override
  void initState() {
    super.initState();

    if (widget.vat != null) {
      _selectedVatType = widget.vat!.vattype;

      _vatController.text = widget.vat!.vatrate.toString();
      _getFundController.text = widget.vat!.vatgetfund.toString();
      _nhilController.text = widget.vat!.nhil.toString();
      _covidController.text = widget.vat!.covid19.toString();
    }
  }

  //function to handle VAT type change and set default values
  void _handleVatTypeChange(String? value) {
    setState(() {
      _selectedVatType = value;

      if (value == "Standard") {
        _vatController.text = "15";
        _getFundController.text = "2.5";
        _nhilController.text = "2.5";
        _covidController.text = "1";
      } else if (value == "Flat") {
        _vatController.text = "4";
        _getFundController.text = "0";
        _nhilController.text = "0";
        _covidController.text = "0";
      }
    });
  }

  Future<void> _saveVat(Datafeed value) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);


    final isEdit = widget.docId != null;

    final docId = isEdit  ? widget.docId!
        : '${value.companyid}_${value.staffPosition}_$_selectedVatType';

    final vatType = isEdit ? widget.vat!.vattype : _selectedVatType!;

    final vatModel = addTaxVatModel(
      id:  docId,
      staff: value.staff,
      companyid: value.companyid,
      companyemail: value.companyemail,
      date:  isEdit ? widget.vat!.date : DateTime.now(),
      updatedat:    DateTime.now(),
      deletedat:    null,
      updatedby:    value.staff,
      deletedby:    '',
      vattype:      vatType,
      vatrate:      double.parse(_vatController.text),
      vatgetfund:   double.parse(_getFundController.text),
      nhil:double.parse(_nhilController.text),
      covid19:double.parse(_covidController.text),
    );

    try {
      final docRef = value.db.collection('addvat').doc(docId);

      await value.db.runTransaction((txn) async {
        final snap = await txn.get(docRef);

        if (!isEdit && snap.exists) {
          // Duplicate: a record with this VAT type already exists — block it
          throw Exception('VAT type "$vatType" already exists. Use edit to update it.');
        }

        // Edit: allow overwrite. New: doc does not exist → safe to create.
        txn.set(docRef, vatModel.toMap());
      });

      // Update local list
      final index = value.addvatList.indexWhere((e) => e.id == docId);
      if (index != -1) {
        value.addvatList[index] = vatModel;
      } else {
        value.addvatList.add(vatModel);
      }
      value.notifyListeners();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'VAT updated successfully' : 'VAT saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      if (isEdit) {
        Navigator.pop(context);
        return;
      }

      // Reset form for new record after save
      setState(() {
        _selectedVatType = null;
        _vatController.clear();
        _getFundController.clear();
        _nhilController.clear();
        _covidController.clear();
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101A23),
          appBar: AppBar(
            title: const Text("Add VAT"),
            backgroundColor: const Color(0xFF0D1A26),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 700),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _buildDropdown(),

                      const SizedBox(height: 12),
                      _buildField("VAT", _vatController),

                      const SizedBox(height: 12),
                      _buildField("GETFund", _getFundController),

                      const SizedBox(height: 12),
                      _buildField("NHIL", _nhilController),

                      const SizedBox(height: 12),
                      _buildField("COVID-19", _covidController),

                      const SizedBox(height: 20),
                      Center(
                        child: Wrap(
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
                                onPressed: _isSaving      ? null
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
                                label: const Text( "View",  style: TextStyle(color: Colors.white70),
                                ),
                                onPressed: () {
                                  Navigator.pushNamed( context,
                                    Routes.addvatview,
                                  );
                                },
                              ),
                            ),
                          ],
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

  //  Dropdown
  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedVatType,
      dropdownColor: const Color(0xFF22304A),
      items: _vattype
          .map((e) => DropdownMenuItem(value: e, child: Text(e,style: TextStyle(color: Colors.white),)))
          .toList(),
      onChanged: widget.vat != null
          ? null
          : _handleVatTypeChange,
      decoration: _inputDecoration("VAT Type"),
      validator: (v) => v == null ? 'Select VAT type' : null,
    );
  }

  // Input field
  Widget _buildField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      cursorColor: Colors.white,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      validator: (v) => v == null || v.isEmpty ? 'Enter $label' : null,
    );
  }

  // Decoration
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      hintStyle: TextStyle(color: Colors.white),
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF22304A),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
}