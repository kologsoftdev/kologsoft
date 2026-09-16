import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pricemodel.dart';
import '../providers/Datafeed.dart';

class ModePricingBuilder extends StatefulWidget {
  const ModePricingBuilder({super.key});

  @override
  State<ModePricingBuilder> createState() => _ModePricingBuilderState();
}

class _ModePricingBuilderState extends State<ModePricingBuilder> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  final TextEditingController itemNameCtrl = TextEditingController();
  final TextEditingController minCtrl = TextEditingController();
  final TextEditingController maxCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();

  String? selectedType;
  int? editingIndex;
  bool isSaving = false;

  final List<String> priceTypes = ['retail', 'wholesale', 'supplier'];
  final List<PricingRuleModel> rules = [];

  // ---------------- INTERCEPTION CHECK ----------------

  bool _intercepts(int min, int max, {int? ignoreIndex}) {
    for (int i = 0; i < rules.length; i++) {
      if (ignoreIndex != null && i == ignoreIndex) continue;
      final r = rules[i];
      if (!(max < r.minQty || min > r.maxQty)) return true;
    }
    return false;
  }

  // ---------------- RESET ----------------

  void _resetForm() {
    setState(() {
      selectedType = null;
      editingIndex = null;
      minCtrl.clear();
      maxCtrl.clear();
      priceCtrl.clear();
    });
  }

  // ---------------- ADD / UPDATE ----------------

  void _addOrUpdateRule() {
    if (selectedType == null ||
        minCtrl.text.isEmpty ||
        maxCtrl.text.isEmpty ||
        priceCtrl.text.isEmpty) return;

    final min = int.parse(minCtrl.text);
    final max = int.parse(maxCtrl.text);
    final price = double.parse(priceCtrl.text);

    if (min > max) return _toast("Min cannot be greater than Max");
    if (_intercepts(min, max, ignoreIndex: editingIndex)) {
      return _toast("Quantity range already exists");
    }

    final rule = PricingRuleModel(
      type: selectedType!,
      minQty: min,
      maxQty: max,
      price: price,
    );

    setState(() {
      if (editingIndex != null) {
        rules[editingIndex!] = rule;
      } else {
        rules.add(rule);
      }
      _resetForm();
    });
  }

  // ---------------- EDIT ----------------

  void _editRule(int index) {
    final r = rules[index];
    setState(() {
      editingIndex = index;
      selectedType = r.type;
      minCtrl.text = r.minQty.toString();
      maxCtrl.text = r.maxQty.toString();
      priceCtrl.text = r.price.toString();
    });
  }

  // ---------------- SAVE ----------------

  Future<void> _saveAll(Datafeed value) async {
    if (itemNameCtrl.text.isEmpty) {
      return _toast("Enter Item Name");
    }
    if (rules.isEmpty) {
      return _toast("Add at least one pricing rule");
    }

    setState(() => isSaving = true);

    final Map<String, Map<String, dynamic>> pricingMap = {};
    for (final r in rules) {
      final key = "${r.type}_${r.minQty}_${r.maxQty}";
      pricingMap[key] = r.toMap();
    }

    await db.collection('pricing_modes').add({
      'itemName': itemNameCtrl.text.trim(),
      'pricingRules': pricingMap,
      'companyId': value.companyid,
      'staff': value.staff,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    setState(() => isSaving = false);
    _toast("Pricing setup saved successfully");
    Navigator.pop(context);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final formWidth = screenWidth > 900 ? screenWidth * 0.6 : screenWidth * 0.95;

    return Consumer<Datafeed>(builder: (context, value, _) {
      return Scaffold(
        backgroundColor: const Color(0xFF101A23),
        appBar: AppBar(
          title: const Text("Setup Pricing"),
          backgroundColor: const Color(0xFF0D1A26),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: formWidth),
              child: ListView(
                children: [
                  Card(
                    color: const Color(0xFF182232),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          /// ITEM NAME
                          TextFormField(
                            controller: itemNameCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration:
                            _inputDecoration("Item Name", Icons.inventory),
                          ),

                          const SizedBox(height: 20),

                          /// TYPE
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            dropdownColor: const Color(0xFF101624),
                            style:
                            const TextStyle(color: Colors.white70),
                            decoration: _inputDecoration(
                                "Price Type", Icons.category),
                            items: priceTypes
                                .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.toUpperCase()),
                            ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selectedType = v),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              _miniField("Min Qty", minCtrl),
                              const SizedBox(width: 8),
                              _miniField("Max Qty", maxCtrl),
                              const SizedBox(width: 8),
                              _miniField("Price", priceCtrl),
                            ],
                          ),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: 220,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const Color(0xFF415A77),
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _addOrUpdateRule,
                              child: Text(
                                editingIndex != null
                                    ? "Update Rule"
                                    : "Add Rule",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          _buildRulesList(),

                          const SizedBox(height: 30),

                          SizedBox(
                            width: 220,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const Color(0xFF415A77),
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed:
                              isSaving ? null : () => _saveAll(value),
                              child: isSaving
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation(
                                        Colors.white)),
                              )
                                  : const Text("Save Pricing",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70)),
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
      );
    });
  }

  Widget _miniField(String label, TextEditingController c) {
    return Expanded(
      child: TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label, Icons.numbers),
      ),
    );
  }

  Widget _buildRulesList() {
    return Column(
      children: rules.asMap().entries.map((entry) {
        final index = entry.key;
        final r = entry.value;

        return Card(
          color: const Color(0xFF22304A),
          child: ListTile(
            title: Text(
              "${r.type.toUpperCase()}  |  ₵${r.price}",
              style: const TextStyle(color: Colors.white70),
            ),
            subtitle: Text(
              "Qty ${r.minQty} → ${r.maxQty}",
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editRule(index),
            ),
          ),
        );
      }).toList(),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
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
}
