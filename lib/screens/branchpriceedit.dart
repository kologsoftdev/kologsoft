
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/branch.dart';
import 'package:provider/provider.dart';

import '../models/itemmodel.dart';
import '../models/itemregmodel.dart';
import '../providers/Datafeed.dart';

class Branchitempriceupdate extends StatefulWidget {
  final ItemModel item;
  final String branchId;
  final String branchname;
  final String staff;

  const Branchitempriceupdate({
    super.key,
    required this.item,
    required this.branchId,
    required this.staff,
    required this.branchname,
  });
  @override
  State<Branchitempriceupdate> createState() => _BranchitempriceupdateState();
}

class _BranchitempriceupdateState extends State<Branchitempriceupdate> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costController = TextEditingController();
  int pricingStep = 0;
  bool _enableBoxPricing = false;
  bool _showBoxPricingSwitch = false;
  final _boxQtyController = TextEditingController();
  final _halfboxqty_controller = TextEditingController();
  final _quarterqty_controller = TextEditingController();
  final _retail_price = TextEditingController();
  final _packQtyController = TextEditingController();

  final _supplierPriceController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  final _halfboxprice_controller = TextEditingController();
  final _quarterprice_controller = TextEditingController();
  final _packprice_controller = TextEditingController();

  final _wholesaleMinQtyController = TextEditingController();
  final _supplierMinQtyController = TextEditingController();
  bool _loading = false;
  List<BranchModel> br = [];

  String? branchname;
  Mode? modess;

  String? _validateField(String fieldName, String? value) {
    if (value == null || value.isEmpty) {
      if (fieldName == 'supplierMinQty') return null;
      return 'Required';
    }

    switch (fieldName) {
      case 'retailPrice':
        double retailPrice = double.tryParse(value) ?? 0;
        double unitCost = double.tryParse(_costController.text) ?? 0;
        double boxPrice = double.tryParse(_wholesalePriceController.text) ?? 0;
        double supplierPrice =
            double.tryParse(_supplierPriceController.text) ?? 0;
        double boxQty = double.tryParse(_boxQtyController.text) ?? 1;
        double boxunitprice = boxPrice / boxQty;

        if (retailPrice <= 0) return 'Enter a valid retail price';
        if (boxQty == 1) {}
        if (unitCost > 0 && retailPrice < unitCost) {
          return 'Retail price GHS$retailPrice must be greater than\n Unit Cost which is GHS${boxPrice / boxQty}';
        }

        if (boxQty > 1) {
          if (retailPrice < boxunitprice) {
            return 'Retail price GHS$retailPrice must be equal to \n or greater than Box unit Price GHS${boxPrice / boxQty}';
          }

          if (supplierPrice > 0 && retailPrice < (supplierPrice / boxQty)) {
            return 'Unit retail price GHS$retailPrice must be equal \n to or greater than Supplier Price ${supplierPrice / boxQty}';
          }

          if (retailPrice < unitCost) {
            return 'Retail price GHS$retailPrice must be greater than\n or equal to Unit Cost GHS$unitCost';
          }
        }
        return null;

      case 'costPrice':
        final costPrice = double.tryParse(value) ?? 0;
        final retailPrice = double.tryParse(_retail_price.text) ?? 0;

        if (retailPrice > 0 && costPrice > retailPrice) {
          return 'Unit Cost Price GHS$costPrice must be less than Retail Price GHS$retailPrice';
        }
        return null;

      case 'boxQty':
        final boxQty = int.tryParse(value) ?? 0;
        if (boxQty < 1) {
          return 'Box quantity must be at least 1';
        }
        return null;

      case 'boxPrice':
        final boxQty = double.tryParse(_boxQtyController.text) ?? 0;

        double boxPrice = double.tryParse(value) ?? 0;
        double boxQtyVal = double.tryParse(_boxQtyController.text) ?? 1;
        double pricePerUnit = boxQtyVal > 0 ? boxPrice / boxQtyVal : 0;
        double retailPrice = double.tryParse(_retail_price.text) ?? 0;
        double costPrice = double.tryParse(_costController.text) ?? 0;

        if (boxQty == 1) {
          if (costPrice > boxPrice) {
            return 'Cost price  GHS$costPrice \n is more than Box Price GHS$boxPrice';
          }
          if (boxPrice > retailPrice) {
            return 'Box price  GHS$boxPrice \n can more than Retail Price GHS$retailPrice';
          }
          return null;
        }

        if (pricePerUnit > retailPrice) {
          return 'Price per unit which is GHS${boxPrice / boxQtyVal} \n Qty cannot be less than Retail Price';
        }

        if (pricePerUnit < costPrice) {
          return 'Price per unit which is GHS${boxPrice / boxQtyVal} \n Qty cannot be less than Unit Cost Price';
        }
        return null;

      case 'supplierPrice':
        final boxQty = double.tryParse(_boxQtyController.text) ?? 0;
        if (boxQty <= 0) return null;

        final supplierPrice = double.tryParse(value) ?? 0;
        final unitCost = double.tryParse(_costController.text) ?? 0;
        final boxPrice = double.tryParse(_wholesalePriceController.text) ?? 0;
        final retailPrice = double.tryParse(_retail_price.text) ?? 0;
        double costPrice = double.tryParse(_costController.text) ?? 0;
        if (boxQty == 1) {
          if (costPrice > supplierPrice) {
            return 'Cost price  GHS$costPrice \n is more than Supplier Price GHS$supplierPrice';
          }
          if (supplierPrice > retailPrice) {
            return 'Supplier price  GHS$supplierPrice \n is more than Retail Price GHS$retailPrice';
          }
          return null;
        }

        final minSupplierPrice = unitCost * boxQty;
        if (supplierPrice < minSupplierPrice) {
          return 'Supplier Price GHS$supplierPrice must be more\n or equal to  (${minSupplierPrice.toStringAsFixed(2)})';
        }

        if (supplierPrice > boxPrice) {
          return 'Supplier Price must be less than \n or equal to Box Price';
        }
        return null;

      case 'supplierMinQty':
        final supplierQty = int.tryParse(value) ?? 0;
        if (supplierQty == 1) return null;
        return null;

      case 'halfBoxQty':
        final halfBoxQty = int.tryParse(value) ?? 0;
        final boxQty = int.tryParse(_boxQtyController.text) ?? 0;

        if (boxQty == 0) return null;

        final requiredHalfQty = (boxQty / 2).ceil();
        if (halfBoxQty > boxQty) {
          return 'Half Box Qty cannot exceed Box Qty';
        }
        if (halfBoxQty < requiredHalfQty) {
          return 'Half Box Qty must be at least $requiredHalfQty';
        }
        return null;

      case 'halfBoxPrice':
        final halfBoxPrice = double.tryParse(value) ?? 0;
        final boxPrice = double.tryParse(_wholesalePriceController.text) ?? 0;
        if (boxPrice == 0) return null;

        final requiredHalfPrice = boxPrice / 2;
        if (halfBoxPrice > boxPrice) {
          return 'Half Box Price cannot exceed Box Price';
        }
        if (halfBoxPrice < requiredHalfPrice) {
          return 'Half Box Price must be at least ${requiredHalfPrice.toStringAsFixed(2)}';
        }
        return null;

      case 'quarterQty':
        final quarterQty = int.tryParse(value) ?? 0;
        final boxQty = int.tryParse(_boxQtyController.text) ?? 0;
        final halfQty = int.tryParse(_halfboxqty_controller.text) ?? 0;
        final packQty = int.tryParse(_packQtyController.text) ?? 0;

        if (boxQty == 0) return null;

        final requiredQuarterQty = (boxQty / 4).ceil();
        if (quarterQty > boxQty) {
          return 'Quarter Qty cannot exceed Box Qty';
        }
        if (quarterQty < requiredQuarterQty) {
          return 'Quarter Qty must be at least $requiredQuarterQty';
        }
        if (halfQty > 0 && quarterQty >= halfQty) {
          return 'Quarter Qty must be less than Half Qty';
        }
        if (packQty > 0 && quarterQty <= packQty) {
          return 'Quarter Qty must be greater than Pack Qty';
        }
        return null;

      case 'quarterPrice':
        final quarterPrice = double.tryParse(value) ?? 0;
        final boxPrice = double.tryParse(_wholesalePriceController.text) ?? 0;
        final halfBoxPrice =
            double.tryParse(_halfboxprice_controller.text) ?? 0;

        if (boxPrice == 0) return null;

        final requiredQuarterPrice = boxPrice / 4;
        if (quarterPrice > boxPrice) {
          return 'Quarter Price cannot exceed Box Price';
        }
        if (quarterPrice < requiredQuarterPrice) {
          return 'Quarter Price must be at least ${requiredQuarterPrice.toStringAsFixed(2)}';
        }
        if (halfBoxPrice > 0 && quarterPrice >= halfBoxPrice) {
          return 'Quarter Price must be less than Half Box Price';
        }
        return null;

      case 'packQty':
        if (!_enableBoxPricing) return null;

        final packQty = int.tryParse(value) ?? 0;
        final boxQty = int.tryParse(_boxQtyController.text) ?? 0;
        final halfQty = int.tryParse(_halfboxqty_controller.text) ?? 0;
        final quarterQty = int.tryParse(_quarterqty_controller.text) ?? 0;

        if (boxQty > 0 && packQty > 0 && boxQty % packQty != 0) {
          return 'Box Qty must be divisible by Pack Qty';
        }

        if (boxQty > 0 && packQty > boxQty) {
          return 'Pack Qty cannot exceed Box Qty';
        }

        if (halfQty > 0 && packQty >= halfQty) {
          return 'Pack Qty must be less than Half Qty';
        }

        if (quarterQty > 0 && packQty >= quarterQty) {
          return 'Pack Qty must be less than Quarter Qty';
        }

        final packUnitPrice = double.tryParse(_packprice_controller.text) ?? 0;
        final unitCost = double.tryParse(_costController.text) ?? 0;
        final totalPackPrice = packUnitPrice * boxQty;
        final totalUnitCost = unitCost * boxQty;

        if (totalPackPrice < totalUnitCost) {
          return 'Pack unit price × Box Qty must be ≥ Unit Cost × Box Qty';
        }
        return null;

      case 'packPrice':
        final packPrice = double.tryParse(value) ?? 0;
        final boxPrice = double.tryParse(_wholesalePriceController.text) ?? 0;
        final boxQty = double.tryParse(_boxQtyController.text) ?? 0;
        final packQty = double.tryParse(_packQtyController.text) ?? 0;
        final retailprice = double.tryParse(_retail_price.text) ?? 0;
        final unitcostprice =
            int.tryParse(_costController.text.toString()) ?? 0;

        if (boxQty == 0 || packQty == 0 || boxPrice == 0) return null;

        double unitboxprice = boxPrice / boxQty;
        final requiredPackPrice = packPrice / packQty;

        if (requiredPackPrice > retailprice ||
            requiredPackPrice < unitcostprice ||
            requiredPackPrice < unitboxprice) {
          return 'Please check Unit(box/cost/retail) price';
        }
        return null;

      case 'pQty':
        if (!_enableBoxPricing) return null;

        final packQty = int.tryParse(value ?? '') ?? 0;
        final boxQty = int.tryParse(_boxQtyController.text) ?? 0;
        final halfQty = int.tryParse(_halfboxqty_controller.text) ?? 0;
        final quarterQty = int.tryParse(_quarterqty_controller.text) ?? 0;

        if (boxQty > 0 && packQty > 0 && boxQty % packQty != 0) {
          return 'Box Qty must be divisible by Pack Qty';
        }

        if (boxQty > 0 && packQty > boxQty) {
          return 'Pack Qty cannot exceed Box Qty';
        }

        if (halfQty > 0 && packQty >= halfQty) {
          return 'Pack Qty must be less than Half Qty';
        }

        if (quarterQty > 0 && packQty >= quarterQty) {
          return 'Pack Qty must be less than Quarter Qty';
        }

        final packUnitPrice =
            double.tryParse(_packprice_controller.text) ?? 0;
        final unitCost =
            double.tryParse(_costController.text) ?? 0;

        final totalPackPrice = packUnitPrice * boxQty;
        final totalUnitCost = unitCost * boxQty;

        if (totalPackPrice < totalUnitCost) {
          return 'Pack unit price × Box Qty must be ≥ Unit Cost × Box Qty';
        }

        return null;

      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final datafeed = context.read<Datafeed>();
      datafeed.fetchproductcategory();
      datafeed.fetchBranches();
      if (mounted) {
        setState(() {
          br = datafeed.branches;
        });
      }
    });

    final d = widget.item;

    _nameController.text = d.name;
    _barcodeController.text = d.barcode;

    final Map<String, dynamic> branchData = Map<String, dynamic>.from(
        (d.branchprices?[widget.branchId] as Map<String, dynamic>?) ?? {});
    branchname = branchData['name'] ?? widget.branchname;
    _supplierMinQtyController.text =
        branchData['sminqty']?.toString() ?? d.sminqty;
    final pricing = Map<String, dynamic>.from(
        branchData['pricing'] as Map<String, dynamic>? ?? {});

    final List<Mode> branchPricing = pricing.entries
        .map((e) => Mode.fromMap(e.key, Map<String, dynamic>.from(e.value)))
        .toList();

    final List<Mode> modes =
    branchPricing.isNotEmpty ? branchPricing : d.modes ?? [];

    Mode? getMode(String id) {
      try {
        return modes.firstWhere((m) => (m.id).toLowerCase() == id);
      } catch (_) {
        return null;
      }
    }

    final single = getMode('single');
    if (single != null) {
      _costController.text = single.cp;
      _retail_price.text = single.rp;
      _boxQtyController.text = single.qty;
      _supplierPriceController.text = single.sp;
      _wholesalePriceController.text = single.wp;
    }

    final carton = getMode('carton');
    if (carton != null) {
      _costController.text = carton.cp;
      _boxQtyController.text = carton.qty;
      _supplierPriceController.text = carton.sp;
      _wholesalePriceController.text = carton.wp;
    }

    final half = getMode('half');
    if (half != null) {
      _costController.text = half.cp;
      _halfboxqty_controller.text = half.qty;
      _halfboxprice_controller.text = half.wp;
    }

    final quarter = getMode('quarter');
    if (quarter != null) {
      _costController.text = quarter.cp;
      _quarterqty_controller.text = quarter.qty;
      _quarterprice_controller.text = quarter.wp;
    }

    final pack = getMode('pack');
    if (pack != null) {
      _costController.text = pack.cp;
      _packQtyController.text = pack.qty;
      _packprice_controller.text = pack.wp;
    }

    pricingStep = 0;
    if (getMode('half') != null) pricingStep = 1;
    if (getMode('quarter') != null) pricingStep = 2;
    if (getMode('pack') != null) pricingStep = 3;

    _enableBoxPricing = modes.isNotEmpty;
    _showBoxPricingSwitch = _enableBoxPricing;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _boxQtyController.dispose();
    _halfboxqty_controller.dispose();
    _quarterqty_controller.dispose();
    _retail_price.dispose();
    _packQtyController.dispose();
    _supplierPriceController.dispose();
    _wholesalePriceController.dispose();
    _halfboxprice_controller.dispose();
    _quarterprice_controller.dispose();
    _packprice_controller.dispose();
    _wholesaleMinQtyController.dispose();
    _supplierMinQtyController.dispose();
    super.dispose();
  }


  void _syncLocalBranchPricing(String branchId, String name, List<Mode> modes) {
    widget.item.branchprices ??= {};
    widget.item.branchprices![branchId] = {
      'name': name,
      'pricing': {for (var m in modes) m.id: m.toMap()},
      'sminqty': _supplierMinQtyController.text.trim(),
    };
  }

  List<Mode> _currentModesForBranch(String branchId) {
    final branchData =
        widget.item.branchprices?[branchId] as Map<String, dynamic>? ?? {};
    final pricing = branchData['pricing'] as Map<String, dynamic>? ?? {};
    return pricing.entries
        .map((e) => Mode.fromMap(e.key, Map<String, dynamic>.from(e.value)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: Text(
              '${datafeed.company} - ${branchname != null && branchname!.isNotEmpty ? branchname : widget.branchname}',
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width < 610
                    ? width * 0.9
                    : width < 1024
                    ? 500
                    : 900,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    SizedBox(
                      child: _buildField(
                        enabled: false,
                        _nameController,
                        'Item Name',
                        Icons.label,
                        onChanged: (v) {
                          _formKey.currentState!.validate();
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      child: _buildField(
                        _retail_price,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$'),
                          ),
                        ],
                        'Retail Price',
                        Icons.attach_money,
                        isNumber: true,
                        validator: (v) => _validateField('retailPrice', v),
                        onChanged: (value) {
                          final boxQty =
                              double.tryParse(_boxQtyController.text) ?? 0;
                          if (boxQty == 1) {
                            setState(() {
                              if (_wholesalePriceController.text.trim().isEmpty) {
                                _wholesalePriceController.text = value;
                              }
                              if (_supplierPriceController.text.trim().isEmpty) {
                                _supplierPriceController.text = value;
                              }
                            });
                          }
                          _formKey.currentState?.validate();
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      child: _buildField(
                        _costController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$'),
                          ),
                        ],
                        'Unit Cost Price',
                        Icons.attach_money,
                        isNumber: true,
                        onChanged: (_) {
                          _formKey.currentState?.validate();
                        },
                        validator: (v) => _validateField('costPrice', v),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      child: _buildField(
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,1}$'),
                          ),
                        ],
                        _boxQtyController,
                        'Box quantity',
                        Icons.attach_money,
                        isNumber: true,
                        onChanged: (value) {
                          final qty = double.tryParse(value) ?? 0;
                          if (qty > 1) {
                            setState(() {
                              _showBoxPricingSwitch = true;
                              _enableBoxPricing = true;

                              _halfboxqty_controller.text =
                                  (qty / 2).ceil().toString();
                              _quarterqty_controller.text =
                                  (qty / 4).ceil().toString();
                            });
                          } else if (qty == 1) {
                            setState(() {
                              _showBoxPricingSwitch = true;
                              _enableBoxPricing = true;

                              final retailPrice = _retail_price.text;
                              if (_wholesalePriceController.text.trim().isEmpty) {
                                _wholesalePriceController.text = retailPrice;
                              }
                              if (_supplierPriceController.text.trim().isEmpty) {
                                _supplierPriceController.text = retailPrice;
                              }
                            });
                          } else {
                            setState(() {
                              _showBoxPricingSwitch = false;
                              _enableBoxPricing = false;
                              pricingStep = 0;
                            });
                          }
                          _formKey.currentState!.validate();
                        },
                        validator: (v) => _validateField('boxQty', v),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFieldWithEnabled(
                            onChanged: (val) {
                              final price = double.tryParse(val) ?? 0;
                              _halfboxprice_controller.text =
                                  (price / 2).toStringAsFixed(2);
                              _quarterprice_controller.text =
                                  (price / 4).toStringAsFixed(2);
                              _formKey.currentState?.validate();
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}$'),
                              ),
                            ],
                            _wholesalePriceController,
                            'Box Price',
                            Icons.attach_money,
                            isNumber: true,
                            validator: (v) => _validateField('boxPrice', v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildFieldWithEnabled(
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}$'),
                              ),
                            ],
                            _supplierPriceController,
                            'Supplier Price',
                            Icons.attach_money,
                            isNumber: true,
                            onChanged: (v) {
                              _formKey.currentState!.validate();
                            },
                            validator: (v) =>
                                _validateField('supplierPrice', v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      child: _buildField(
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$'),
                          ),
                        ],
                        _supplierMinQtyController,
                        'Supplier Min Qty',
                        Icons.numbers,
                        isNumber: true,
                        onChanged: (value) {
                          _formKey.currentState?.validate();
                        },
                        validator: (v) =>
                            _validateField('supplierMinQty', v),
                      ),
                    ),
                    if (_enableBoxPricing) ...[
                      const SizedBox(height: 15),

                      /// HALF ROW
                      if (pricingStep >= 1)
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}$'),
                                  ),
                                ],
                                enabled: false,
                                _halfboxqty_controller,
                                'Half Box Qty',
                                Icons.inventory,
                                isNumber: true,
                                validator: (v) =>
                                    _validateField('halfBoxQty', v),
                                onChanged: (value) {
                                  _formKey.currentState?.validate();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}$'),
                                  ),
                                ],
                                _halfboxprice_controller,
                                'Half Box Price',
                                Icons.attach_money,
                                isNumber: true,
                                validator: (v) =>
                                    _validateField('halfBoxPrice', v),
                                onChanged: (value) {
                                  _formKey.currentState?.validate();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22304A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: IconButton(
                                tooltip: 'Remove half pricing',
                                padding: EdgeInsets.zero,
                                splashRadius: 20,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.remove_circle,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => AlertDialog(
                                      backgroundColor:
                                      const Color(0xFF182232),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      title: const Text(
                                        'Confirm removal',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        'Remove half-box pricing for this item? This cannot be undone.',
                                        style:
                                        TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text(
                                            'Cancel',
                                            style:
                                            TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'Remove',
                                            style:
                                            TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm != true) return;

                                  final String targetBranchId =
                                      widget.branchId;

                                  setState(() {
                                    pricingStep = 0;

                                    _halfboxqty_controller.clear();
                                    _halfboxprice_controller.clear();
                                    _quarterqty_controller.clear();
                                    _quarterprice_controller.clear();
                                    _packQtyController.clear();
                                    _packprice_controller.clear();
                                  });

                                  if (widget.item.id != null) {
                                    try {
                                      final branchData = widget
                                          .item
                                          .branchprices?[targetBranchId] ??
                                          {};

                                      if (branchData.isNotEmpty) {
                                        final fieldPath = FieldPath([
                                          'branchprices',
                                          targetBranchId,
                                          'pricing',
                                          'half',
                                        ]);
                                        await db
                                            .collection('itemsreg')
                                            .doc(widget.item.id)
                                            .update({
                                          fieldPath: FieldValue.delete(),
                                        });
                                      }

                                      if (!mounted) return;

                                      final modes =
                                      _currentModesForBranch(
                                          targetBranchId)
                                        ..removeWhere(
                                                (m) => m.id == 'half');
                                      _syncLocalBranchPricing(
                                        targetBranchId,
                                        branchname ?? widget.branchname,
                                        modes,
                                      );
                                      context
                                          .read<Datafeed>()
                                          .notifyListeners();

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                          Text('Half pricing removed',style: TextStyle(color: Colors.white),),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Failed to remove half pricing: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                      if (pricingStep >= 1) const SizedBox(height: 15),

                      /// QUARTER ROW
                      if (pricingStep >= 2)
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,1}$'),
                                  ),
                                ],
                                enabled: false,
                                _quarterqty_controller,
                                'Quarter Qty',
                                Icons.inventory,
                                isNumber: true,
                                validator: (v) =>
                                    _validateField('quarterQty', v),
                                onChanged: (value) {
                                  _formKey.currentState?.validate();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}$'),
                                  ),
                                ],
                                _quarterprice_controller,
                                'Quarter Price',
                                Icons.attach_money,
                                isNumber: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Required';
                                  }
                                  final quarterPrice = double.tryParse(v) ?? 0;
                                  final boxPrice =
                                      double.tryParse(_wholesalePriceController.text) ?? 0;
                                  final halfBoxPrice =
                                      double.tryParse(_halfboxprice_controller.text) ?? 0;

                                  if (boxPrice == 0) return null;

                                  final requiredQuarterPrice = boxPrice / 4;
                                  if (quarterPrice > boxPrice) {
                                    return 'Quarter Price cannot exceed Box Price';
                                  }
                                  if (quarterPrice < requiredQuarterPrice) {
                                    return 'Quarter Price must be at least ${requiredQuarterPrice.toStringAsFixed(2)}';
                                  }
                                  if (halfBoxPrice > 0 && quarterPrice >= halfBoxPrice) {
                                    return 'Quarter Price must be less than Half Box Price';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  _formKey.currentState?.validate();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22304A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: IconButton(
                                tooltip: 'Remove quarter pricing',
                                padding: EdgeInsets.zero,
                                splashRadius: 20,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.remove_circle,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => AlertDialog(
                                      backgroundColor:
                                      const Color(0xFF182232),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      title: const Text(
                                        'Confirm removal',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        'Remove quarter pricing for this item? This cannot be undone.',
                                        style:
                                        TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text(
                                            'Cancel',
                                            style:
                                            TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'Remove',
                                            style:
                                            TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm != true) return;

                                  final String targetBranchId =
                                      widget.branchId;

                                  setState(() {
                                    pricingStep = 1;
                                    _quarterqty_controller.clear();
                                    _quarterprice_controller.clear();
                                  });

                                  if (widget.item.id != null) {
                                    try {
                                      final branchData = widget
                                          .item
                                          .branchprices?[targetBranchId] ??
                                          {};
                                      if (branchData.isNotEmpty) {
                                        final fieldPath = FieldPath([
                                          'branchprices',
                                          targetBranchId,
                                          'pricing',
                                          'quarter',
                                        ]);
                                        await db
                                            .collection('itemsreg')
                                            .doc(widget.item.id)
                                            .update({
                                          fieldPath: FieldValue.delete(),
                                        });
                                      }

                                      if (!mounted) return;

                                      final modes =
                                      _currentModesForBranch(
                                          targetBranchId)
                                        ..removeWhere(
                                                (m) => m.id == 'quarter');
                                      _syncLocalBranchPricing(
                                        targetBranchId,
                                        branchname ?? widget.branchname,
                                        modes,
                                      );
                                      context
                                          .read<Datafeed>()
                                          .notifyListeners();

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Quarter pricing removed',style: TextStyle(color: Colors.white),),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Failed to remove quarter pricing: $e',style: TextStyle(color: Colors.white),),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                      if (pricingStep >= 2) const SizedBox(height: 15),

                      /// PACK ROW
                      if (pricingStep >= 3)
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,1}$'),
                                  ),
                                ],
                                _packQtyController,
                                'Pack Qty',
                                Icons.inventory,
                                isNumber: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Required';
                                  }
                                  if (!_enableBoxPricing) return null;

                                  final packQty = int.tryParse(v) ?? 0;
                                  final boxQty = int.tryParse(
                                    _boxQtyController.text,
                                  ) ??
                                      0;
                                  final halfQty = int.tryParse(
                                    _halfboxqty_controller.text,
                                  ) ??
                                      0;
                                  final quarterQty = int.tryParse(
                                    _quarterqty_controller.text,
                                  ) ??
                                      0;

                                  if (boxQty > 0 &&
                                      packQty > 0 &&
                                      boxQty % packQty != 0) {
                                    return 'Box Qty must be divisible by Pack Qty';
                                  }

                                  if (boxQty > 0 && packQty > boxQty) {
                                    return 'Pack Qty cannot exceed Box Qty';
                                  }

                                  if (halfQty > 0 && packQty >= halfQty) {
                                    return 'Pack Qty must be less than Half Qty';
                                  }

                                  if (quarterQty > 0 &&
                                      packQty >= quarterQty) {
                                    return 'Pack Qty must be less than Quarter Qty';
                                  }

                                  final packUnitPrice = double.tryParse(
                                    _packprice_controller.text,
                                  ) ??
                                      0;
                                  final unitCost = double.tryParse(
                                    _costController.text,
                                  ) ??
                                      0;

                                  final totalPackPrice =
                                      packUnitPrice * boxQty;
                                  final totalUnitCost = unitCost * boxQty;

                                  if (totalPackPrice < totalUnitCost) {
                                    return 'Pack unit price × Box Qty must be ≥ Unit Cost × Box Qty';
                                  }

                                  return null;
                                },
                                onChanged: (v) {
                                  _formKey.currentState!.validate();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}$'),
                                  ),
                                ],
                                _packprice_controller,
                                'Pack Price',
                                Icons.attach_money,
                                isNumber: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Required';
                                  }

                                  final packPrice = double.tryParse(v) ?? 0;
                                  final boxPrice = double.tryParse(
                                    _wholesalePriceController.text,
                                  ) ??
                                      0;
                                  final boxQty = double.tryParse(
                                    _boxQtyController.text,
                                  ) ??
                                      0;
                                  final packQty = double.tryParse(
                                    _packQtyController.text,
                                  ) ??
                                      0;
                                  final retailprice = double.tryParse(
                                      _retail_price.text) ??
                                      0;
                                  final unitcostprice = int.tryParse(
                                    _costController.text.toString(),
                                  ) ??
                                      0;

                                  if (boxQty == 0 ||
                                      packQty == 0 ||
                                      boxPrice == 0) {
                                    return null;
                                  }

                                  double unitboxprice =
                                      boxPrice / boxQty;

                                  final requiredPackPrice =
                                      packPrice / packQty;

                                  if (requiredPackPrice > retailprice ||
                                      requiredPackPrice < unitcostprice ||
                                      requiredPackPrice < unitboxprice) {
                                    return 'Please check Unit(box/cost/retail) price ';
                                  }

                                  return null;
                                },
                                onChanged: (value) {
                                  _formKey.currentState?.validate();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22304A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: IconButton(
                                tooltip: 'Remove pack pricing',
                                padding: EdgeInsets.zero,
                                splashRadius: 20,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.remove_circle,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => AlertDialog(
                                      backgroundColor:
                                      const Color(0xFF182232),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      title: const Text(
                                        'Confirm removal',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        'Remove pack pricing for this item? This cannot be undone.',
                                        style:
                                        TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text(
                                            'Cancel',
                                            style:
                                            TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'Remove',
                                            style:
                                            TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm != true) return;

                                  final String targetBranchId =
                                      widget.branchId;

                                  setState(() {
                                    pricingStep = 2;
                                    _packQtyController.clear();
                                    _packprice_controller.clear();
                                  });

                                  try {
                                    final branchData = widget.item
                                        .branchprices?[targetBranchId] ??
                                        {};
                                    if (branchData.isNotEmpty) {
                                      final fieldPath = FieldPath([
                                        'branchprices',
                                        targetBranchId,
                                        'pricing',
                                        'pack',
                                      ]);
                                      await db
                                          .collection('itemsreg')
                                          .doc(widget.item.id)
                                          .update({
                                        fieldPath: FieldValue.delete(),
                                      });
                                    }

                                    if (!mounted) return;

                                    final modes =
                                    _currentModesForBranch(
                                        targetBranchId)
                                      ..removeWhere(
                                              (m) => m.id == 'pack');
                                    _syncLocalBranchPricing(
                                      targetBranchId,
                                      branchname ?? widget.branchname,
                                      modes,
                                    );
                                    context
                                        .read<Datafeed>()
                                        .notifyListeners();

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                        Text('Pack pricing removed'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Failed to remove pack pricing: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        onPressed: _loading
                            ? null
                            : () async {
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          setState(() => _loading = true);
                          try {
                            final String targetBranchId =
                                widget.branchId;
                            final String targetBranchName =
                            (branchname != null &&
                                branchname!.isNotEmpty)
                                ? branchname!
                                : widget.branchname;

                            final branchData = widget.item
                                .branchprices?[targetBranchId]
                            as Map<String, dynamic>? ??
                                {};
                            final pricing = branchData['pricing']
                            as Map<String, dynamic>? ??
                                {};
                            final List<Mode> modes = pricing.entries
                                .map((e) => Mode.fromMap(
                                e.key,
                                Map<String, dynamic>.from(
                                    e.value)))
                                .toList();

                            final double boxqty = double.tryParse(
                                _boxQtyController.text) ??
                                0;

                            void upsertMode(
                                String id, Mode newMode) {
                              int index = modes
                                  .indexWhere((m) => m.id == id);
                              if (index != -1) {
                                modes[index] = newMode;
                              } else {
                                modes.add(newMode);
                              }
                            }

                            void removeMode(String id) {
                              modes.removeWhere((m) => m.id == id);
                            }

                            final singleWp =
                            _wholesalePriceController.text.trim().isNotEmpty
                                ? _wholesalePriceController.text.trim()
                                : _retail_price.text.trim();
                            final singleSp =
                            _supplierPriceController.text.trim().isNotEmpty
                                ? _supplierPriceController.text.trim()
                                : _retail_price.text.trim();

                            upsertMode(
                              "single",
                              Mode(
                                id: "single",
                                name: "Single",
                                qty: "1",
                                cp: _costController.text.trim(),
                                rp: _retail_price.text.trim(),
                                wp: singleWp,
                                sp: singleSp,
                              ),
                            );

                            if (boxqty >= 2) {
                              upsertMode(
                                "carton",
                                Mode(
                                  id: "carton",
                                  name: "Carton",
                                  qty: _boxQtyController.text
                                      .trim(),
                                  cp: _costController.text.trim(),
                                  rp: _wholesalePriceController
                                      .text
                                      .trim(),
                                  wp: _wholesalePriceController
                                      .text
                                      .trim(),
                                  sp: _supplierPriceController
                                      .text
                                      .trim(),
                                ),
                              );
                            } else {
                              removeMode("carton");
                            }

                            if (_enableBoxPricing) {
                              if (pricingStep >= 1 &&
                                  _halfboxqty_controller
                                      .text.isNotEmpty &&
                                  _halfboxprice_controller
                                      .text.isNotEmpty) {
                                upsertMode(
                                  "half",
                                  Mode(
                                    id: "half",
                                    name: "Half Carton",
                                    qty: _halfboxqty_controller
                                        .text
                                        .trim(),
                                    cp: _costController.text
                                        .trim(),
                                    rp: _halfboxprice_controller
                                        .text
                                        .trim(),
                                    wp: _halfboxprice_controller
                                        .text
                                        .trim(),
                                    sp: _halfboxprice_controller
                                        .text
                                        .trim(),
                                  ),
                                );
                              } else {
                                removeMode("half");
                              }

                              if (pricingStep >= 2 &&
                                  _quarterqty_controller
                                      .text.isNotEmpty &&
                                  _quarterprice_controller
                                      .text.isNotEmpty) {
                                upsertMode(
                                  "quarter",
                                  Mode(
                                    id: "quarter",
                                    name: "Quarter Carton",
                                    qty: _quarterqty_controller
                                        .text
                                        .trim(),
                                    cp: _costController.text
                                        .trim(),
                                    rp: _quarterprice_controller
                                        .text
                                        .trim(),
                                    wp: _quarterprice_controller
                                        .text
                                        .trim(),
                                    sp: _quarterprice_controller
                                        .text
                                        .trim(),
                                  ),
                                );
                              } else {
                                removeMode("quarter");
                              }

                              if (pricingStep >= 3 &&
                                  _packQtyController
                                      .text.isNotEmpty &&
                                  _packprice_controller
                                      .text.isNotEmpty) {
                                upsertMode(
                                  "pack",
                                  Mode(
                                    id: "pack",
                                    name: "Pack",
                                    qty: _packQtyController.text
                                        .trim(),
                                    cp: _costController.text
                                        .trim(),
                                    rp: _packprice_controller
                                        .text
                                        .trim(),
                                    wp: _packprice_controller
                                        .text
                                        .trim(),
                                    sp: _packprice_controller
                                        .text
                                        .trim(),
                                  ),
                                );
                              } else {
                                removeMode("pack");
                              }
                            } else {
                              removeMode("half");
                              removeMode("quarter");
                              removeMode("pack");
                            }

                            final branchFieldPath = FieldPath(
                                ['branchprices', targetBranchId]);

                            await db
                                .collection('itemsreg')
                                .doc(widget.item.id)
                                .update({
                              branchFieldPath: {
                                'name': targetBranchName,
                                'pricing': {
                                  for (var m in modes)
                                    m.id: m.toMap(),
                                },
                                'sminqty': _supplierMinQtyController
                                    .text
                                    .trim(),
                                'updatedat':
                                FieldValue.serverTimestamp(),
                                'updatedby': widget.staff,
                              },
                              'pricingmode': true,
                            });

                            _syncLocalBranchPricing(
                              targetBranchId,
                              targetBranchName,
                              modes,
                            );

                            if (mounted) {
                              context
                                  .read<Datafeed>()
                                  .notifyListeners();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Item updated successfully!',style: TextStyle(color: Colors.white),),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e',style: TextStyle(color: Colors.white),),
                                  backgroundColor: Colors.red,
                                  duration:
                                  const Duration(seconds: 4),
                                ),
                              );
                            }
                          }

                          if (mounted) {
                            setState(() => _loading = false);
                          }
                        },
                        child: _loading
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                            : const Text('Update Item'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: _enableBoxPricing &&
              double.tryParse(_boxQtyController.text) != 1
              ? Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: 'add_pricing',
                  backgroundColor: Colors.green,
                  onPressed: () {
                    setState(() {
                      if (pricingStep < 3) pricingStep++;
                    });
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'toggle_pricing',
                  backgroundColor: Colors.blue,
                  onPressed: () {
                    setState(() => _enableBoxPricing = false);
                  },
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          )
              : null,
        );
      },
    );
  }

  TextFormField _buildField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool enabled = true,
        bool isNumber = false,
        Function(String)? onChanged,
        String? Function(String?)? validator,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return TextFormField(
      enabled: enabled,
      controller: controller,

      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.white70),
      validator: validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
      decoration: _inputDecoration(label, icon),
      onChanged: onChanged,
      inputFormatters: inputFormatters,
    );
  }

  TextFormField _buildFieldWithEnabled(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isNumber = false,
        bool enabled = true,
        Function(String)? onChanged,
        String? Function(String?)? validator,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.white70),
      validator: validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
      decoration: _inputDecoration(label, icon),
      inputFormatters: inputFormatters,
      onChanged: onChanged,
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
}