import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../models/itemmodel.dart';
import '../paymentwidgets/BarcodeScannerScreen.dart';
import '../paymentwidgets/changepasswordDialog.dart';
import '../paymentwidgets/customerinfodialog.dart';
import '../paymentwidgets/momoDialog.dart';
import '../paymentwidgets/printDialog.dart';
import '../paymentwidgets/showlogout.dart';
import '../providers/SalesProvider.dart';
import '../providers/routes.dart';
import '../widgets/salespagewidgets/hamper.dart';
import '../widgets/salespagewidgets/mobilesalespreview.dart';
import '../widgets/salespagewidgets/snackmsg.dart';
import '../widgets/salespagewidgets/validators/salespagevalidator.dart';
import '../widgets/stockreportmodal.dart';


class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _totalPiecesController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _gtotalAmountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedSalesMode;
  List<String> _salesMode = [];
  String? _selectedPriceMode;
  List<dynamic> _priceMode = [];
  Map<String, dynamic>? _itemModes;
  Map<String, dynamic>? _currentModeData;
  bool showHamperSection = false;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  bool _showMobilePreview = false;
  ItemModel? _selectedItem;
  String _searchQuery = '';

  String branchid = "";
  String branchtype = "";
  String _superAdminBranchId = "";
  String _superAdminBranchName = "";
  String _displayBranchName = "";
  String _loginBranchId = '';
  String _loginBranchName = '';
  String get _activeBranchId =>  _superAdminBranchId.isNotEmpty ? _superAdminBranchId : branchid.isNotEmpty ? branchid : Provider.of<Datafeed>(context, listen: false).activeBranchId;

  String get _activeBranchName => _superAdminBranchName.isNotEmpty ? _superAdminBranchName : Provider.of<Datafeed>(context, listen: false).activeBranchName;
  String? cp;
  Map<String, dynamic>? branchbalance;
  final List<Map<String, dynamic>>? items = [];
  final TextEditingController _discountCodeController = TextEditingController();
  String? _appliedDiscountCode;
  bool _showDiscountCodeField = false;
  final TextEditingController _bulkDiscountController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    Future.microtask(() async {
      context.read<Datafeed>().fetchItems();
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchDiscountCodes();
      final value = Provider.of<Datafeed>(context, listen: false);
      await value.getdata();

      if (!mounted) return;
      if(branchid.isEmpty){
        branchid = value.branchid;
      }

      _displayBranchName = value.branch;
      _loginBranchId = value.branchid;
      _loginBranchName = value.branch;
      _barcodeController.addListener(_onBarcodeChanged);
      _quantityController.addListener(_onQuantityChanged);
      _discountController.addListener(_calculateTotals);
      _priceController.addListener(_calculateTotals);

      branchtype = value.branchtype;
      _priceMode = value.pricingmode.map((e) => e.toString()).toList();
      if (_selectedPriceMode == null && _priceMode.isNotEmpty) {
        _selectedPriceMode = _priceMode.first;
      }

    });

    _selectedDate = DateTime.now();
    _dateController.text =
        DateFormat('yyyy-MM-dd').format(_selectedDate!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().setSaleDate(_selectedDate);
    });
  }

  double _currentQuantityValue() {
    final parsed = double.tryParse(_quantityController.text.trim());
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  void _setQuantityValue(double value) {
    final normalized = value <= 0 ? 1 : value;
    final text = normalized % 1 == 0
        ? normalized.toStringAsFixed(0)
        : normalized.toString();
    _quantityController.text = text;
    _quantityController.selection = TextSelection.collapsed(
      offset: text.length,
    );
  }

  void _incrementQuantity() {
    _setQuantityValue(_currentQuantityValue() + 1);
  }

  void _decrementQuantity() {
    final next = _currentQuantityValue() - 1;
    _setQuantityValue(next <= 0 ? 1 : next);
  }
  String _calculateGrossAmount() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;

    final gross = price * qty;

    return gross.toStringAsFixed(2);
  }
  void _refreshPricingForBranch(String newBranchId) {
    if (_selectedItem == null) return;

    final item = _selectedItem!;
    Map<String, dynamic> effectivePricing = {};

    final branchPrices = item.branchprices;
    final modes = item.modes;

    // Try branch-specific pricing first
    if (branchPrices != null &&
        branchPrices.containsKey(newBranchId) &&
        branchPrices[newBranchId]['pricing'] != null) {
      effectivePricing = Map<String, dynamic>.from(
        branchPrices[newBranchId]['pricing'],
      );
    } else if (modes != null) {
      // Fall back to item modes
      for (var mode in modes) {
        effectivePricing[mode.name] = {
          'id': mode.id,
          'name': mode.name,
          'qty': mode.qty,
          'cp': mode.cp,
          'rp': mode.rp,
          'wp': mode.wp,
          'sp': mode.sp,
        };
      }
    }

    _itemModes = effectivePricing;

    // Rebuild sales mode list
    /*
    if (_itemModes != null && _itemModes!.isNotEmpty) {
      _salesMode = _itemModes!.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        return data['name']?.toString() ?? e.key;
      }).toList();

      _salesMode.sort((a, b) {
        if (a.toLowerCase() == 'single') return -1;
        if (b.toLowerCase() == 'single') return 1;
        return 0;
      });

      // Keep same mode if it still exists in new branch, else reset to first
      if (!_salesMode.contains(_selectedSalesMode)) {
        _selectedSalesMode = _salesMode.first;
      }
    } else {
      _salesMode = const ['single'];
      _selectedSalesMode = null;
      _currentModeData = null;
    }
    */
    if (_itemModes != null && _itemModes!.isNotEmpty) {
      _salesMode = _itemModes!.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        return data['name']?.toString() ?? e.key;
      }).toList();

      final bool isWholesale = (_selectedPriceMode ?? '').toLowerCase() == 'wholesale';
      double cartonQty = 0;
      for (final entry in _itemModes!.entries) {
        if (entry.key.toLowerCase().trim() == 'carton') {
          cartonQty = double.tryParse(entry.value['qty']?.toString() ?? '0') ?? 0;
          break;
        }
      }
      if (isWholesale) {
        _salesMode = _salesMode
            .where((m) => m.toLowerCase().contains('carton'))
            .toList();
        if (_salesMode.isEmpty) {
          _salesMode = _itemModes!.entries.map((e) {
            final data = e.value as Map<String, dynamic>;
            return data['name']?.toString() ?? e.key;
          }).toList();
        }
        _salesMode.sort((a, b) {
          if (a.toLowerCase() == 'carton') return -1;
          if (b.toLowerCase() == 'carton') return 1;
          return 0;
        });
      } else {
        if (cartonQty <= 1) {
          _salesMode = _salesMode.where((m) => !m.toLowerCase().contains('carton')).toList();
        }
        _salesMode.sort((a, b) {
          if (a.toLowerCase() == 'single') return -1;
          if (b.toLowerCase() == 'single') return 1;
          return 0;
        });
      }

      // Keep same mode if it still exists in new branch, else reset to first
      if (!_salesMode.contains(_selectedSalesMode)) {
        _selectedSalesMode = _salesMode.first;
      }
    } else {
      _salesMode = const ['single'];
      _selectedSalesMode = null;
      _currentModeData = null;
    }
    // Recalculate price under new branch
    _updatePrice();
  }
  void _showChangePasswordDialog(BuildContext context, Datafeed datafeed) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.lock_reset,
                                color: colorScheme.onPrimary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Change Password',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Update your account password',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: currentPasswordController,
                          obscureText: !showCurrentPassword,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: colorScheme.onPrimary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              color: colorScheme.onPrimary,
                              onPressed: () {
                                setState(() {
                                  showCurrentPassword = !showCurrentPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter current password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: !showNewPassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(
                              Icons.lock,
                              color: colorScheme.onPrimary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              color: colorScheme.onSurfaceVariant,
                              onPressed: () {
                                setState(() {
                                  showNewPassword = !showNewPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            helperText: 'Must be at least 6 characters',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter new password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: !showConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: Icon(
                              Icons.lock,
                              color: colorScheme.onPrimary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              color: colorScheme.onSurfaceVariant,
                              onPressed: () {
                                setState(() {
                                  showConfirmPassword = !showConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm password';
                            }
                            if (value != newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Cancel',style: TextStyle(color: Colors.white),),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                if (formKey.currentState!.validate()) {
                                  setState(() => isLoading = true);
                                  try {
                                    await datafeed.changePassword(
                                      currentPasswordController.text,
                                      newPasswordController.text,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Password changed successfully',style: TextStyle(color: ColorScheme.of(context).onPrimary),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e',style: TextStyle(color: ColorScheme.of(context).onPrimary),),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text('Update Password'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext parentcontext, Datafeed datafeed) {
    showDialog(
      context: parentcontext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                datafeed.logout(parentcontext);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _quantityController.removeListener(_onQuantityChanged);
    _discountController.removeListener(_calculateTotals);
    _priceController.removeListener(_calculateTotals);
    _discountCodeController.dispose();
    _bulkDiscountController.dispose();
   // _dateController.clear();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
      );

      if (result != null && result is String) {
        setState(() {
          _barcodeController.text = result;
        });
        _formKey.currentState?.validate();
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

  void _onBarcodeChanged() {
    setState(() {
      _searchQuery = _barcodeController.text.trim();
      _showSuggestions = _searchQuery.isNotEmpty;
    });
  }

  void _onQuantityChanged() {
    _updatePrice();
  }

  void _calculateTotals() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    final result = salesProvider.calculateTotals(
      quantityText: _quantityController.text,
      priceText: _priceController.text,
      discountText: _discountController.text,
      modeData: _currentModeData,
    );

    _totalPiecesController.text = result['pieces']!;
    _totalAmountController.text = result['amount']!;

    setState(() {});
  }


  Widget _buildSalesWarehouseSelector(Datafeed datafeed) {
    final accesslevel = datafeed.accesslevel;
    final isSuperAdmin = accesslevel.toLowerCase().trim() == 'super admin';



    if (isSuperAdmin || datafeed.canSellAnyBranch) {
      final dedupedBranches = datafeed.branches.fold<Map<String, dynamic>>({}, (map, b) {
        if (!map.containsKey(b.id)) map[b.id] = b;
        return map;
      }).values.toList();

      if (dedupedBranches.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Loading branches…',
            style: TextStyle(color: Colors.white54),
          ),
        );
      }

      final dedupedIds = dedupedBranches.map((b) => b.id as String).toList();

      final rawValue = _superAdminBranchId.isNotEmpty
          ? _superAdminBranchId
          : datafeed.branchid;
      final bool needsCorrection = !dedupedIds.contains(rawValue);
      final String safeValue = needsCorrection ? dedupedIds.first : rawValue;

      if (needsCorrection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final fallbackBranch =
          dedupedBranches.firstWhere((b) => b.id == dedupedIds.first);
          setState(() {
            _superAdminBranchId = dedupedIds.first;
            _superAdminBranchName = fallbackBranch.branchname;
            _displayBranchName = fallbackBranch.branchname;
            branchid = dedupedIds.first;
            branchtype = fallbackBranch.branchtype ?? '';
          });
        });
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: const Color(0xFF22304A),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Select Branch',
            labelStyle: const TextStyle(color: Colors.white70),
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
          ),
          items: dedupedBranches
              .map((b) => DropdownMenuItem<String>(
            value: b.id,
            child: Text(b.branchname,
                style: const TextStyle(color: Colors.white)),
          ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;

            final branch = dedupedBranches.firstWhere((b) => b.id == v);

            datafeed.setBranch(
              v,
              branch.branchname,
              branch.address,
              branch.branchcontact,
            );
            setState(() {
              branchid = v;
              branchtype = branch.branchtype ?? '';
              _superAdminBranchId = v;
              _superAdminBranchName = branch.branchname;
              _displayBranchName = branch.branchname;

              if (_selectedItem != null) {
                _refreshPricingForBranch(v);
              }
            });
          },
        ),
      );
    }
    if (!datafeed.isSalesPoint) {
      final t = datafeed.branchtype.toLowerCase().trim();
      if (t == 'sales branch' || t == 'salesbranch') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: DropdownButtonFormField<String>(
            value: datafeed.branchid,
            dropdownColor: const Color(0xFF22304A),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Sales Branch',
              labelStyle: const TextStyle(color: Colors.white70),
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
            ),
            items: [
              DropdownMenuItem<String>(
                value: datafeed.branchid,
                child: Text(
                  datafeed.branch,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
            onChanged: null,
          ),
        );
      }
      return const SizedBox.shrink();
    }
    if (_selectedItem == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12.0),
        child: Text(
          'Select an item first to choose warehouse.',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }
    final isService =
        (_selectedItem?.producttype ?? '').toLowerCase().trim() == 'service';
    if (isService) {
      return const SizedBox.shrink();
    }
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final ids = salesProvider.availableSalesWarehousesForItem(
      datafeed,
      _selectedItem!,
    );
    if (ids.isEmpty) {
      // Check if it's because no warehouses are assigned to this staff
      if (datafeed.salesWarehouseIds.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            'No warehouses assigned to your account. Contact admin.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.only(bottom: 12.0),
        child: Text(
          'Selected item has no balance in your assigned warehouses.',
          style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
        ),
      );
    }

    final nameById = <String, String>{};

    // Build id -> name from the source arrays, keyed by id (NOT by position
    // within `ids`). `ids` can be reordered/filtered relative to
    // salesWarehouseIds/salesWarehouseNames, so indexing by `i` mismatches
    // names to the wrong id (e.g. Bakery's balance showing under "OA").
    for (int i = 0;
    i < datafeed.salesWarehouseIds.length &&
        i < datafeed.salesWarehouseNames.length;
    i++) {
      final srcId = datafeed.salesWarehouseIds[i];
      final srcName = datafeed.salesWarehouseNames[i];
      if (srcName.isNotEmpty) {
        nameById[srcId] = srcName;
      }
    }

    // Fallback: if any id in `ids` didn't get a name above, look it up from
    // datafeed.branches, or fall back to the raw id.
    for (final id in ids) {
      if (!nameById.containsKey(id) || nameById[id]!.isEmpty) {
        final branch = datafeed.branches.firstWhere(
              (b) => b.id == id,
          orElse: () => BranchModel(),
        );
        nameById[id] = branch.branchname.isNotEmpty ? branch.branchname : id;
      }
    }

    // De-duplicate ONCE and reuse everywhere below, so `value` and `items`
    // can never disagree within a single build pass.
    final dedupedIds = ids.toSet().toList();

    final activeId = datafeed.salesWarehouseId;
    final bool needsCorrection =
        activeId == null || !dedupedIds.contains(activeId);

    // Compute a value that is GUARANTEED to be in dedupedIds for this build,
    // instead of trusting datafeed.salesWarehouseId which may still be
    // stale/invalid until setSalesWarehouse finishes updating it.
    final String safeValue =
    needsCorrection ? dedupedIds.first : activeId!;

    if (needsCorrection) {
      // Defer the provider mutation until after this frame completes.
      // Calling datafeed.setSalesWarehouse(...) synchronously here and then
      // immediately reading datafeed.salesWarehouseId again for `value:`
      // is what caused the dropdown assertion — the field isn't guaranteed
      // to reflect the new id in time for this same build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        datafeed.setSalesWarehouse(
          dedupedIds.first,
          nameById[dedupedIds.first] ?? '',
        );
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        dropdownColor: const Color(0xFF22304A),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Sell From Warehouse',
          labelStyle: const TextStyle(color: Colors.white70),
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
        ),
        items: dedupedIds.map((id) {
          final balance =
              _selectedItem?.branchbalance?[id] as Map<String, dynamic>? ?? {};
          final netPieces = salesProvider.parseNetPieces(balance);

          double boxQty = 1.0;

          final modes = _selectedItem?.modes;

          if (modes != null) {
            final carton = modes.where((m) => m.name.toLowerCase() == 'carton');
            final single = modes.where((m) => m.name.toLowerCase() == 'single');

            final qtyString = carton.isNotEmpty
                ? carton.first.qty
                : single.isNotEmpty
                ? single.first.qty
                : '1';

            boxQty = double.tryParse(qtyString) ?? 1.0;
          }

          final boxes = boxQty > 0 ? (netPieces / boxQty) : 0.0;

          final label =
              '${nameById[id] ?? id} - ${netPieces.toStringAsFixed(0)} pcs / ${boxes.toStringAsFixed(2)} boxes';
          return DropdownMenuItem<String>(
            value: id,
            child: Text(label, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
        onChanged: (v) {
          if (v == null) return;
          datafeed.setSalesWarehouse(v, nameById[v] ?? '');
        },

        validator: SalesFormValidators.warehouse,
      ),
    );
  }

  Future<void> _addToSalesPreview() async {
    if (_formKey.currentState!.validate()) {
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final isService = (_selectedItem?.producttype ?? '').toLowerCase().trim() == 'service';

      if (!isService && !salesProvider.ensureSalesWarehouseSelected(
        context, datafeed, _selectedItem, ))
        return;

      final activeBranchId = _activeBranchId;
      final activeBranchName = _activeBranchName;

      final bool useSalesWarehouse = !isService &&
          datafeed.isSalesPoint &&
          (datafeed.salesWarehouseId?.isNotEmpty ?? false);

      final balanceBranchId = useSalesWarehouse
          ? datafeed.salesWarehouseId!
          : activeBranchId;

      final balanceBranchName = useSalesWarehouse
          ? (datafeed.branches.firstWhere(
            (b) => b.id == balanceBranchId,
        orElse: () => BranchModel(), ).branchname.isNotEmpty
          ? datafeed.branches.firstWhere((b) => b.id == balanceBranchId).branchname
          : balanceBranchId)
          : activeBranchName;

      final balanceBranchType = useSalesWarehouse
          ? datafeed.branches.firstWhere(
            (b) => b.id == balanceBranchId,
        orElse: () => BranchModel(),
      ).branchtype ?? ''
          : branchtype;
      final totalPieces = double.tryParse(_totalPiecesController.text) ?? 0;

      if (!isService) {
        final branchBalance = salesProvider.resolveBranchBalance(
          _selectedItem?.branchbalance,
          balanceBranchId,
          datafeed,
        );

        final availableNetPieces = salesProvider.parseNetPieces(branchBalance);

        if (totalPieces > availableNetPieces) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        _syncItemBalance(
                          _selectedItem?.id ?? '',
                          _selectedItem?.name ?? '',
                          balanceBranchId,
                          balanceBranchName,
                        );
                      },
                      child: Text('Click to update balance ', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 17)),
                    ),
                  ),
                  Expanded(
                    child: Text('Insufficient stock: ${availableNetPieces.toStringAsFixed(0)} pcs available'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      double totalAmt = double.parse(_totalAmountController.text.toString());
      double totalpcs = double.parse(_totalPiecesController.text.toString());
      double qty = double.parse(_quantityController.text.toString());
      double cp = double.tryParse(_selectedItem?.cp ?? '') ?? 0;
      double profitonsale = totalAmt - (totalpcs * cp);

      final salesItem = {
        'itemid': _selectedItem?.id ?? '',
        'branchid': balanceBranchId,
        'branchname': balanceBranchName,
        'branchtype': balanceBranchType,
        'modeqty': _currentModeData?['qty'] ?? '',
        'item': _itemController.text.toString(),
        'barcode': _barcodeController.text.trim().toString(),
        'mode': _selectedSalesMode ?? '',
        'quantity': _quantityController.text.trim().toString(),
        'price': _priceController.text.trim().toString(),
        'profit': profitonsale.toString(),
        'discount': _discountController.text.trim().toString().isEmpty ? '0' : _discountController.text.trim().toString(),
        'cp': cp.toString(),
        'pcategory': _selectedItem?.pcategory ?? '',
        'producttype': _selectedItem?.producttype ?? '',
        'totalpieces': totalpcs.toString(),
        'totalamount': totalAmt.toString(),
        'grosstotalamount': _calculateGrossAmount(),
        'pricemode': _selectedPriceMode ?? 'retail',
        'boxpiece': (_itemModes?['carton']?['qty'] ?? _itemModes?['Carton']?['qty'] ?? '1'),
      };
      salesProvider.addToSalesPreview(salesItem);

      if (_appliedDiscountCode != null) {
        await context.read<Datafeed>().markDiscountCodeUsed(
          _appliedDiscountCode!,
          usedBy: Provider.of<Datafeed>(context, listen: false).staff,
          usedBranch: Provider.of<Datafeed>(context, listen: false).branch,
        );
      }

      //Clear form
      _resetForm();
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item added to sales preview', style: TextStyle(color: theme.colorScheme.onSurface)),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  void _resetForm() {
    _itemController.clear();
    _barcodeController.clear();
    _quantityController.text = '1';
    _priceController.clear();
    _discountController.clear();
    _totalPiecesController.clear();
    _totalAmountController.clear();
    setState(() {
      //  _selectedItem = null;
      _selectedSalesMode = null;
      _selectedPriceMode = null;
      _currentModeData = null;
      _itemModes = null;
      _salesMode = [];

      _discountCodeController.clear();
      _appliedDiscountCode = null;
      _showDiscountCodeField = false;
    });
  }

  Future<void> _printReceipt() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final value = Provider.of<Datafeed>(context, listen: false);
   final isService = (_selectedItem?.producttype ?? '').toLowerCase().trim() == 'service';

    if (!isService) {
      bool isValid = await salesProvider.validateCartStockOnSaves(
        _activeBranchId,
      );

      if (!isValid) {
        snackMsg(context, 'Insufficient stock detected. Please adjust cart.', Colors.red);
        return;
      }
    }
    await printReceipt(
      context: context,
      salesItems: salesProvider.salesItems,
      selectedItem: _selectedItem,
    );
  }
  Future<void> _syncItemBalance(String itemId, String itemName, String branchId, String branchName) async {
    final provider = context.read<Datafeed>();
    final balance = await provider.fetchItemCurrentBalance(
      itemId: itemId,
      selectedBranch: branchId,
    );
    if (balance == null) return;
    await provider.db.collection('itemsreg').doc(itemId).update({
      'branchbalance.$branchId.netpieces': balance,
      'branchbalance.$branchId.lastupdate': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      snackMsg(context, 'Balance synced: $itemName → $branchName | $balance pcs', Colors.green);
    }
  }
  void _selectItem(ItemModel? item, Datafeed datafeed) {
    if (item == null) return;
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    setState(() {
      _selectedItem = item;

      /// Ensure correct warehouse when in sales point
      if (datafeed.isSalesPoint) {
        final available = salesProvider.availableSalesWarehousesForItem(
          datafeed,
          item,
        );

        if (available.isNotEmpty &&
            !available.contains(datafeed.salesWarehouseId)) {
          final selectedId = available.first;
          String selectedName = '';

          final index = datafeed.salesWarehouseIds.indexOf(selectedId);

          if (index >= 0 && index < datafeed.salesWarehouseNames.length) {
            selectedName = datafeed.salesWarehouseNames[index];
          }

          if (selectedName.isEmpty) {
            final branch = datafeed.branches.firstWhere(
              (b) => b.id == selectedId,
              orElse: () => BranchModel(),
            );
            selectedName = branch.branchname;
          }

          datafeed.setSalesWarehouse(selectedId, selectedName);
        }
      }

      /// Fill text fields
      _itemController.text = item.name;
      _barcodeController.text = item.barcode;

      Map<String, dynamic> effectivePricing = {};

      final branchPrices = item.branchprices;
      final modes = item.modes;
      final String branchId = datafeed.activeBranchId;

      if (branchPrices != null &&
          branchPrices.containsKey(branchId) &&
          branchPrices[branchId]['pricing'] != null) {
        effectivePricing = Map<String, dynamic>.from(
          branchPrices[branchId]['pricing'],
        );
      } else if (modes != null) {
        for (var mode in modes) {
          effectivePricing[mode.name] = {
            'id': mode.id,
            'name': mode.name,
            'qty': mode.qty,
            'cp': mode.cp,
            'rp': mode.rp,
            'wp': mode.wp,
            'sp': mode.sp,
          };
        }
      }

      _itemModes = effectivePricing;

      /// Build sales mode list

      /// Build sales mode list
      if (_itemModes != null && _itemModes!.isNotEmpty) {
        _salesMode = _itemModes!.entries.map((e) {
          final data = e.value as Map<String, dynamic>;
          return data['name']?.toString() ?? e.key;
        }).toList();

        final bool isWholesale = (_selectedPriceMode ?? '').toLowerCase() == 'wholesale';
        double cartonQty = 0;
        for (final entry in _itemModes!.entries) {
          if (entry.key.toLowerCase().trim() == 'carton') {
            cartonQty = double.tryParse(entry.value['qty']?.toString() ?? '0') ?? 0;
            break;
          }
        }
        if (isWholesale) {
          _salesMode = _salesMode.where((m) => m.toLowerCase().contains('carton')).toList();

          if (_salesMode.isEmpty) {
            _salesMode = _itemModes!.entries.map((e) {
              final data = e.value as Map<String, dynamic>;
              return data['name']?.toString() ?? e.key;
            }).toList();
          }
          _salesMode.sort((a, b) {
            if (a.toLowerCase() == 'carton') return -1;
            if (b.toLowerCase() == 'carton') return 1;
            return 0;
          });
        } else {
          if (cartonQty <= 1) {
            _salesMode = _salesMode.where((m) => !m.toLowerCase().contains('carton')).toList();
          }
          /// Put "Single" first
          if (datafeed.isSalesPoint) {
            _salesMode.sort((a, b) {
              if (a.toLowerCase() == 'carton') return -1;
              if (b.toLowerCase() == 'carton') return 1;
              return 0;
            });
          } else {
            _salesMode.sort((a, b) {
              if (a.toLowerCase() == 'single') return -1;
              if (b.toLowerCase() == 'single') return 1;
              return 0;
            });
          }
        }

        _selectedSalesMode = _salesMode.first;

        _updatePrice();
      } else {
        _salesMode = const ['single'];
        _selectedSalesMode = null;
        _currentModeData = null;
      }
      _showSuggestions = false;
      _suggestions.clear();
    });
  }


  void _updatePrice() {
    if (_selectedItem == null ||
        _selectedSalesMode == null ||
        _itemModes == null ||
        _itemModes!.isEmpty) {
      _priceController.text = '0';
      _currentModeData = null;
      return;
    }
    final double qty = double.tryParse(_quantityController.text) ?? 0;
    final double sminqty =
        double.tryParse(_selectedItem?.sminqty?.toString() ?? '0') ?? 0;

    Map<String, dynamic>? selectedModeData;

    for (final entry in _itemModes!.entries) {
      if (entry.key.toLowerCase().trim() ==
          _selectedSalesMode!.toLowerCase().trim()) {
        selectedModeData = Map<String, dynamic>.from(entry.value);
        break;
      }
    }

    if (selectedModeData == null) {
      _priceController.text = '0';
      _currentModeData = null;
      return;
    }

    _currentModeData = selectedModeData;

    String price = '0';

    String pickRetail(Map<String, dynamic> data) {
      return data['rp']?.toString() ??
          data['sp']?.toString() ??
          data['cp']?.toString() ??
          '0';
    }

    final bool isCarton = _selectedSalesMode?.toLowerCase().contains('carton') ?? false;

    if (isCarton) {
      double effectiveThreshold = sminqty;

      if (sminqty > 0) {
        Map<String, dynamic>? fullCartonMode;
        for (final entry in _itemModes!.entries) {
          if (entry.key.toLowerCase().trim() == 'carton') {
            fullCartonMode = Map<String, dynamic>.from(entry.value);
            break;
          }
        }

        final double fullCartonQty =
            double.tryParse(fullCartonMode?['qty']?.toString() ?? '0') ?? 0;
        final double currentModeQty =
            double.tryParse(selectedModeData['qty']?.toString() ?? '0') ?? 0;

        if (fullCartonQty > 0 && currentModeQty > 0 && currentModeQty != fullCartonQty) {
          final double multiplier = fullCartonQty / currentModeQty;
          effectiveThreshold = sminqty * multiplier;
        }
      }

      if (effectiveThreshold > 0 && qty >= effectiveThreshold) {
        price = selectedModeData['sp']?.toString() ?? '0';
      } else {
        price = pickRetail(selectedModeData);
      }
    } else {
      if (_selectedPriceMode == 'Wholesale') {
        price = selectedModeData['wp']?.toString() ?? '0';
      } else {
        price = pickRetail(selectedModeData);
      }
    }
    _priceController.text = price;

    _calculateTotals();
  }
  Widget _previewActionTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double minWidth,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyDiscountCode(String code) async {
    final upperCaseCode = code.trim().toUpperCase();
    if (upperCaseCode.isEmpty) return;

    try {
      final datafeed = context.read<Datafeed>();

      final match = await datafeed.validateDiscountCode(upperCaseCode);

      if (match == null) {
        snackMsg(context, 'Invalid or used discount code', Colors.red);
        return;
      }

      final amount = (match['amount'] as num).toDouble();

      setState(() {
        _appliedDiscountCode = match['code'];
        _discountController.text = amount.toStringAsFixed(2);
      });

      _calculateTotals();

      snackMsg(
        context,
        'Code "${match['code']}" applied - GHS ${amount.toStringAsFixed(2)} off',
        Colors.green,
      );
    } catch (e) {
      print('Error applying discount code: $e');

      snackMsg(
        context,
        'Failed to apply discount. Check connection and try again.',
        Colors.red,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final salesItems = context.watch<SalesProvider>().salesItems;
        final allowed = value.allowedPaymentMethods;
        final bool cashAllowed = allowed.map((e) => e.toLowerCase()).contains('cash');

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: Text(
              "SALES TRANSACTIONS ${(_displayBranchName.isNotEmpty ? _displayBranchName : value.branch).toString().toUpperCase()}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFF1B263B),
            actions: [
              // IconButton(
              //   icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
              //   tooltip: 'Stock Report',
              //   onPressed: () => StockReportModal.show(
              //     context: context,
              //     branchId: _loginBranchId,
              //     branchName: _loginBranchName,
              //   ),
              // ),
              // PopupMenuButton<String>(
              //   onSelected: (selectedValue) {
              //     if (selectedValue == 'logout') {
              //       LogoutDialog.show(context);
              //     } else if (selectedValue == 'password') {
              //       ChangePasswordDialog.changePassword(context);
              //     } else if (selectedValue == 'profile') {
              //       Navigator.pushNamed(context, Routes.staffprofile);
              //     }
              //   },
              //   itemBuilder: (BuildContext context) => [
              //     PopupMenuItem<String>(
              //       value: 'profile',
              //       child: Row(
              //         children: [
              //           Icon(
              //             Icons.person_outline,
              //             size: 20,
              //             color: Colors.green,
              //           ),
              //           SizedBox(width: 12),
              //           Text('My Profile'),
              //         ],
              //       ),
              //     ),
              //     PopupMenuItem<String>(
              //       value: 'password',
              //       child: Row(
              //         children: [
              //           Icon(Icons.lock_outline, size: 20, color: Colors.blue),
              //           SizedBox(width: 12),
              //           Text('Change Password'),
              //         ],
              //       ),
              //     ),
              //     PopupMenuItem(
              //       value: 'logout',
              //       child: Row(
              //         children: const [
              //           Icon(Icons.logout, size: 20, color: Colors.red),
              //           SizedBox(width: 8),
              //           Text('Logout'),
              //         ],
              //       ),
              //     ),
              //   ],
              // ),

            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 8.0,
                  top: 8,
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
                          final bool isMobile = constraints.maxWidth < 600;
                          final provider = Provider.of<Datafeed>(context, listen: false, );
                          final salesProvider = Provider.of<SalesProvider>(context,listen: false,);
                          final isSalesBranch =  provider.branchtype ==   "Sales Branch"; //"Sales Point";
                          final accesslevel = provider.accesslevel;
                          final isSuperAdmin = accesslevel.toLowerCase().trim() == 'super admin';
                          final canPrint = provider.canPrint;
                          final posPrint = isSalesBranch || canPrint;
                          return Column(
                            children: [
                              if (isMobile)
                                Container(
                                  width: itemWidth,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF182232),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: !_showMobilePreview
                                                ? Colors.orange
                                                : const Color(0xFF22304A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            elevation: !_showMobilePreview
                                                ? 2
                                                : 0,
                                          ),

                                          onPressed: () {
                                            FocusScope.of(context).unfocus();
                                            setState(
                                              () => _showMobilePreview = false,
                                            );
                                          },
                                          child: const Text('Sale Form'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _showMobilePreview
                                                ? Colors.lightBlue
                                                : const Color(0xFF22304A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            elevation: _showMobilePreview
                                                ? 2
                                                : 0,
                                          ),
                                          onPressed: () {
                                            FocusScope.of(context).unfocus();
                                            setState(
                                              () => _showMobilePreview = true,
                                            );
                                          },
                                          child: const Text('Preview'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (isMobile) const SizedBox(height: 12),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  if (!isMobile || !_showMobilePreview)
                                 SizedBox(
                                      width: itemWidth,
                                      child: Container(
                                        color: Color(0xFF182232),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (isMobile)
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF22304A,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white24,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.shopping_cart,
                                                            color:
                                                                Colors.orange,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              'Open: Cart ${salesProvider.currentCartId.split('_').length > 1 ? salesProvider.currentCartId.split('_')[1] : salesProvider.currentCartId}',
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            '${salesItems.length} item(s)',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white60,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          const Text(
                                                            'Total Amount',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white60,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Text(
                                                            'GHC ${salesProvider.calculateTaxableTotal().toStringAsFixed(2)}',
                                                            style:  const TextStyle(
                                                                  color: Colors .white,
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                              if (isMobile)
                                                const SizedBox(height: 12),
                                              const Text(
                                                "SALES ENTRIES",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const Divider(
                                                color: Colors.white24,
                                              ),
                                              Visibility(
                                                visible: value.hamperEnabled,
                                                maintainState: false,
                                                child: Column(
                                                  children: [
                                                    HamperSection(
                                                      datafeed: value,
                                                      activeBranchId: _activeBranchId,
                                                      activeBranchName: _activeBranchName,
                                                    ),
                                                    const Divider(
                                                      color: Colors.white24,
                                                    ),
                                                  ],
                                                ),
                                              ),



                                              SizedBox(height: 8),
                                              Form(
                                                key: _formKey,
                                                child: Column(
                                                  children: [

                                                  if(value.canSelectDate)...[
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
                                                        DateTime? picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: _selectedDate ?? DateTime.now(),
                                                          firstDate: DateTime(2020),
                                                          lastDate: DateTime(2100),
                                                          builder: (context, child) {
                                                            return Theme(
                                                              data: Theme.of(context).copyWith(
                                                                colorScheme: const ColorScheme.dark(
                                                                  primary: Colors.blue,
                                                                  onPrimary: Colors.white,
                                                                  surface: Color(0xFF22304A),
                                                                  onSurface: Colors.white,
                                                                ),
                                                              ),
                                                              child: child!,
                                                            );
                                                          },
                                                        );

                                                        if (picked != null) {
                                                          context.read<SalesProvider>().setSaleDate(picked);

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
                                                    )
                                                    ]
                                                    ,
                                                    SizedBox(height:8,),
                                                    _buildSalesWarehouseSelector(
                                                      value,
                                                    ),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:  _barcodeController,
                                                            style: TextStyle(
                                                              color:  Colors.white,
                                                            ),
                                                            decoration: InputDecoration(
                                                              labelText: 'Barcode',
                                                              labelStyle: const TextStyle(
                                                                    color: Colors.white70,
                                                                  ),
                                                              border: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular( 12, ),
                                                              ),
                                                              enabledBorder: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                borderSide:
                                                                    const BorderSide(
                                                                      color: Colors
                                                                          .white24,
                                                                    ),
                                                              ),
                                                              focusedBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                borderSide:
                                                                    const BorderSide(
                                                                      color: Colors
                                                                          .blue,
                                                                    ),
                                                              ),
                                                              fillColor:
                                                                  const Color(
                                                                    0xFF22304A,
                                                                  ),
                                                              filled: true,
                                                            ),

                                                           validator: SalesFormValidators.barcode,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          height: 56,
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFF22304A,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            border: Border.all(
                                                              color: Colors
                                                                  .white24,
                                                            ),
                                                          ),
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .qr_code_scanner,
                                                              color: Colors
                                                                  .white70,
                                                            ),
                                                            onPressed:
                                                                _scanBarcode,
                                                            tooltip:
                                                                'Scan Barcode/QR Code',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (_showSuggestions)
                                                         value.loading
                                                          ? const Center(
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    color: Colors
                                                                        .blue,
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                            )
                                                          : (() {
                                                              final query =
                                                                  _searchQuery
                                                                      .toLowerCase();

                                                              final filteredItems =
                                                                  query.isEmpty ? value.items
                                                                  : value.items .where((item) => item.isActive == true).where(( item, ) {
                                                                          final name = item.name.toLowerCase();
                                                                          final barcode = item.barcode.toLowerCase();
                                                                          final company = item.company.toLowerCase();
                                                                          final category = item.pcategory.toLowerCase();

                                                                          return name.contains( query,) ||
                                                                              barcode.contains(query, ) ||
                                                                              company.contains(
                                                                                query,
                                                                              ) ||
                                                                              category.contains(
                                                                                query,
                                                                              );
                                                                        })
                                                                        .take(
                                                                          10,
                                                                        )
                                                                        .toList();

                                                              if (filteredItems
                                                                  .isEmpty) {
                                                                return const SizedBox.shrink();
                                                              }

                                                              return Container(
                                                                margin:
                                                                    const EdgeInsets.only(
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
                                                                    color: Colors
                                                                        .blue
                                                                        .withOpacity(
                                                                          0.3,
                                                                        ),
                                                                  ),
                                                                  boxShadow: const [
                                                                    BoxShadow(
                                                                      color: Colors
                                                                          .black26,
                                                                      blurRadius:
                                                                          8,
                                                                      offset:
                                                                          Offset(
                                                                            0,
                                                                            4,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                ),

                                                                constraints:
                                                                    const BoxConstraints(
                                                                      maxHeight:
                                                                          250,
                                                                    ),
                                                                child: ListView.builder(
                                                                  shrinkWrap:  true,
                                                                  itemCount: filteredItems.length,
                                                                  itemBuilder: (context, index,) {
                                                                  final item =  filteredItems[index];
                                                                  final branchId =  value.activeBranchId;
                                                                  final branchbalance =  item.branchbalance?[branchId]  as Map<String, dynamic  >? ?? {};

                                                                 final double   netPieces = (branchbalance['netpieces'] as num?) ?.toDouble() ?? 0.0;

                                                                 double boxQty = double.tryParse(_selectedItem?.modes ?.firstWhere(
                                                                              (m) => m.name.toLowerCase() == 'carton',
                                                                          orElse: () => Mode(
                                                                            id: '',
                                                                            name: '',
                                                                            qty: '1',
                                                                            cp: '',
                                                                            rp: '',
                                                                            wp: '',
                                                                            sp: '',
                                                                          ),
                                                                        ).qty ?? _selectedItem?.modes
                                                                                ?.firstWhere(
                                                                                  (m) => m.name.toLowerCase() == 'single',
                                                                              orElse: () => Mode(
                                                                                id: '',
                                                                                name: '',
                                                                                qty: '1',
                                                                                cp: '',
                                                                                rp: '',
                                                                                wp: '',
                                                                                sp: '',
                                                                              ),
                                                                            )
                                                                                .qty ??
                                                                            '1',
                                                                      ) ??
                                                                          1.0;
                                                                        final double   cartonsLeft = boxQty > 0 ? (netPieces / boxQty) : 0.0;
                                                                  final cartonMode = item.modes?.firstWhere(
                                                                        (m) => m.name.toLowerCase() == 'carton',
                                                                    orElse: () => Mode(
                                                                      id: '',
                                                                      name: '',
                                                                      qty: '1',
                                                                      cp: '',
                                                                      rp: '',
                                                                      wp: '',
                                                                      sp: '',
                                                                    ),
                                                                  );

                                                                  final singleMode = item.modes?.firstWhere(
                                                                        (m) => m.name.toLowerCase() == 'single',
                                                                    orElse: () => Mode(
                                                                      id: '',
                                                                      name: '',
                                                                      qty: '1',
                                                                      cp: '',
                                                                      rp: '',
                                                                      wp: '',
                                                                      sp: '',
                                                                    ),
                                                                  );

                                                                  final String boxPrice =
                                                                  (cartonMode?.wp?.isNotEmpty ?? false)
                                                                      ? cartonMode!.wp
                                                                      : (singleMode?.wp ?? '0');
                                                                        return ListTile(
                                                                          dense: true,
                                                                          leading: const Icon(
                                                                            Icons.inventory_2,
                                                                            color: Colors.blue,
                                                                            size: 20,
                                                                          ),
                                                                          title: Text(
                                                                            item.name,
                                                                            style: const TextStyle(
                                                                              color: Colors.white,
                                                                              fontSize: 14,
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                          subtitle: Text(
                                                                            'Barcode: ${item.barcode} | Box Price: GHS $boxPrice | Retail Price: GHS ${singleMode?.rp} '
                                                                                //'| Boxes Balance: ${cartonsLeft.toStringAsFixed(2)}'
                                                                                ' | Pieces: ${netPieces.toStringAsFixed(0)}',
                                                                            style: const TextStyle(
                                                                              color: Colors.white70,
                                                                              fontSize: 11,
                                                                            ),
                                                                          ),
                                                                          trailing: const Icon(
                                                                            Icons.arrow_forward_ios,
                                                                            color:
                                                                                Colors.white54,
                                                                            size:
                                                                                14,
                                                                          ),
                                                                          onTap: () {
                                                                            _selectItem(
                                                                              item,
                                                                              value,
                                                                            );
                                                                          },
                                                                        );
                                                                      },
                                                                ),
                                                              );
                                                            })(),

                                                    SizedBox(height: 8),
                                                    TextFormField(
                                                      enabled: false,
                                                      controller:
                                                          _itemController,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText: 'Item',
                                                        labelStyle:
                                                            const TextStyle(
                                                              color: Colors
                                                                  .white70,
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
                                                                    color: Colors
                                                                        .blue,
                                                                  ),
                                                            ),
                                                        fillColor: const Color(
                                                          0xFF22304A,
                                                        ),
                                                        filled: true,
                                                      ),

                                                      validator: SalesFormValidators.item,
                                                    ),
                                                    SizedBox(height: 8),
                                                    DropdownButtonFormField<String>(
                                                      value: _selectedSalesMode,
                                                      dropdownColor:
                                                          const Color(
                                                            0xFF22304A,
                                                          ),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText: 'Sales Mode',
                                                        labelStyle:  const TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                            ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
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
                                                                    color: Colors
                                                                        .blue,
                                                                  ),
                                                            ),
                                                        fillColor: const Color(
                                                          0xFF22304A,
                                                        ),
                                                        filled: true,
                                                      ),
                                                      items: _salesMode.isEmpty
                                                          ? null
                                                          : _salesMode.map((
                                                              type,
                                                            ) {
                                                              return DropdownMenuItem<
                                                                String
                                                              >(
                                                                value: type,
                                                                child: Text(
                                                                  type,
                                                                ),
                                                              );
                                                            }).toList(),
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _selectedSalesMode =
                                                              value;
                                                          _updatePrice();
                                                        });
                                                      },

                                                      validator: SalesFormValidators.salesMode,
                                                    ),
                                                    SizedBox(height: 8),
                                                    TextFormField(
                                                      controller:  _priceController,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      decoration: InputDecoration(
                                                        labelText: 'Price',
                                                        labelStyle:
                                                            const TextStyle(
                                                              color: Colors
                                                                  .white70,
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
                                                                    color: Colors
                                                                        .blue,
                                                                  ),
                                                            ),
                                                        fillColor: const Color(
                                                          0xFF22304A,
                                                        ),
                                                        filled: true,
                                                      ),
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.allow(
                                                          RegExp(
                                                            r'^\d*\.?\d*$',
                                                          ),
                                                        ),
                                                      ],

                                                      validator: SalesFormValidators.price,
                                                      enabled: value.canEditPrice,
                                                    ),
                                                    Visibility(
                                                      visible: false,
                                                      child: Row(
                                                        children: [
                                                          Visibility(
                                                            visible: false,
                                                            child: Expanded(
                                                              child: DropdownButtonFormField<String>(
                                                                initialValue:
                                                                    _selectedPriceMode,
                                                                dropdownColor:
                                                                    const Color(
                                                                      0xFF22304A,
                                                                    ),
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                decoration: InputDecoration(
                                                                  border: OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          12,
                                                                        ),
                                                                  ),
                                                                  enabledBorder: OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          12,
                                                                        ),
                                                                    borderSide:
                                                                        const BorderSide(
                                                                          color:
                                                                              Colors.white24,
                                                                        ),
                                                                  ),
                                                                  focusedBorder: OutlineInputBorder(
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
                                                                  fillColor:
                                                                      const Color(
                                                                        0xFF22304A,
                                                                      ),
                                                                  filled: true,
                                                                ),
                                                                items: _priceMode.map((
                                                                  type,
                                                                ) {
                                                                  return DropdownMenuItem<
                                                                    String
                                                                  >(
                                                                    value: type,
                                                                    child: Text(
                                                                      type,
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                                onChanged: (value) {
                                                                  setState(() {
                                                                    _selectedPriceMode =
                                                                        value;
                                                                    _updatePrice();
                                                                  });
                                                                },

                                                                validator: SalesFormValidators.priceMode,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        SizedBox(
                                                          width: 52,
                                                          height: 52,
                                                          child: Material(
                                                            color: const Color(
                                                              0xFF22304A,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            child: InkWell(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              onTap:
                                                                  _decrementQuantity,
                                                              child: const Icon(
                                                                Icons.remove,
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller: _quantityController,
                                                            textAlign: TextAlign.center,
                                                            style:  const TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight:  FontWeight.w600,
                                                                ),
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true,),
                                                            inputFormatters: [
                                                              FilteringTextInputFormatter.allow(
                                                                RegExp(
                                                                  r'^(0(\.\d*)?|[1-9]\d*(\.\d*)?)?$',
                                                                ),
                                                              ),
                                                            ],
                                                            decoration: InputDecoration(
                                                              labelText:
                                                                  'Quantity',
                                                              labelStyle:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                  ),
                                                              border: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              enabledBorder: OutlineInputBorder(
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
                                                              focusedBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                borderSide:
                                                                    const BorderSide(
                                                                      color: Colors
                                                                          .blue,
                                                                    ),
                                                              ),
                                                              fillColor:
                                                                  const Color(
                                                                    0xFF22304A,
                                                                  ),
                                                              filled: true,
                                                            ),

                                                              validator: SalesFormValidators.quantity,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        SizedBox(
                                                          width: 52,
                                                          height: 52,
                                                          child: Material(
                                                            color: const Color(
                                                              0xFF22304A,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            child: InkWell(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              onTap:
                                                                  _incrementQuantity,
                                                              child: const Icon(
                                                                Icons.add,
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                _totalPiecesController,
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            readOnly: true,
                                                            decoration: InputDecoration(
                                                              labelText:
                                                                  'Total Pieces',
                                                              labelStyle:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                  ),
                                                              border: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              enabledBorder: OutlineInputBorder(
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
                                                              focusedBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                borderSide:
                                                                    const BorderSide(
                                                                      color: Colors
                                                                          .blue,
                                                                    ),
                                                              ),
                                                              fillColor:
                                                                  const Color(
                                                                    0xFF22304A,
                                                                  ),
                                                              filled: true,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(width: 10),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                _totalAmountController,
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            readOnly: true,
                                                            decoration: InputDecoration(
                                                              labelText:
                                                                  'Total Amount',
                                                              labelStyle:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                  ),
                                                              border: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              enabledBorder: OutlineInputBorder(
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
                                                              focusedBorder: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                borderSide:
                                                                    const BorderSide(
                                                                      color: Colors
                                                                          .blue,
                                                                    ),
                                                              ),
                                                              fillColor:
                                                                  const Color(
                                                                    0xFF22304A,
                                                                  ),
                                                              filled: true,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    SizedBox(height: 8),
                                                    if(value.allowDiscount) ...[
                                                    TextFormField(
                                                      controller: _discountController,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      keyboardType:  const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.allow(
                                                          RegExp(
                                                            r'^(0(\.\d*)?|[1-9]\d*(\.\d*)?)?$',
                                                          ),
                                                        ),
                                                      ],
                                                      decoration: InputDecoration(
                                                        labelText:'Discount',
                                                        labelStyle: const TextStyle(
                                                          color: Colors.white70, ),
                                                        prefixText: 'GHS ',
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12, ),
                                                        ),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius:
                                                          BorderRadius.circular( 12, ),
                                                          borderSide:
                                                          const BorderSide(
                                                            color: Colors
                                                                .white24,
                                                          ),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                          borderSide:
                                                          const BorderSide(
                                                            color: Colors
                                                                .blue,
                                                          ),
                                                        ),
                                                        fillColor:
                                                        const Color(
                                                          0xFF22304A,
                                                        ),
                                                        filled: true,
                                                      ),
                                                      validator: (value) {
                                                        if (value == null ||value.trim().isEmpty) {
                                                          return null;
                                                        }
                                                        final parsed = double.tryParse(value.trim(), );
                                                        if (parsed == null) {
                                                          return 'Enter a valid discount';
                                                        }
                                                        if (parsed < 0) {
                                                          return 'Discount cannot be negative';
                                                        }
                                                        return null;
                                                      },
                                                    ),
                                                    ],
                                                    SizedBox(height: 8),
                                                     if(value.allowDiscountCode)...[
                                                    // clickable discount code field
                                                    GestureDetector(
                                                      onTap: () => setState(
                                                        () => _showDiscountCodeField = !_showDiscountCodeField,
                                                      ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFF22304A,
                                                          ),
                                                          borderRadius:  BorderRadius.circular(12,),
                                                          border: Border.all(
                                                            color: _appliedDiscountCode != null
                                                                ? Colors.greenAccent.withOpacity(0.6, )
                                                                : Colors.white24,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.discount_outlined,
                                                              color:_appliedDiscountCode != null
                                                                  ? Colors.greenAccent
                                                                  : Colors.white54,
                                                              size: 18,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                _appliedDiscountCode !=null
                                                                    ? 'Code "$_appliedDiscountCode" applied'
                                                                    : 'Have a discount code? Tap to enter',
                                                                style: TextStyle(
                                                                  color:_appliedDiscountCode != null
                                                                      ? Colors.greenAccent
                                                                      : Colors.white54,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            ),
                                                            Icon(
                                                              _showDiscountCodeField
                                                                  ? Icons.keyboard_arrow_up
                                                                  : Icons.keyboard_arrow_down,
                                                              color: Colors.white38,
                                                              size: 18,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),

                                                    // Expandable code entry
                                                    if (_showDiscountCodeField) ...[
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller:
                                                                  _discountCodeController,
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                letterSpacing:
                                                                    2,
                                                              ),
                                                              textCapitalization:
                                                                  TextCapitalization
                                                                      .characters,
                                                              inputFormatters: [
                                                                FilteringTextInputFormatter.allow(
                                                                  RegExp(
                                                                    r'[A-Za-z0-9]',
                                                                  ),
                                                                ),
                                                              ],
                                                              onFieldSubmitted:  _applyDiscountCode,
                                                              decoration: InputDecoration(
                                                                labelText:  'Enter Discount Code',
                                                                labelStyle:  const TextStyle(
                                                                  color: Colors.white70, ),
                                                                hintText:  'e.g. ABC12345',
                                                                hintStyle:  const TextStyle(
                                                                      color: Colors.white30,
                                                                      fontSize: 12,
                                                                    ),
                                                                filled: true,
                                                                fillColor: const Color( 0xFF22304A,),
                                                                suffixIcon:  _appliedDiscountCode !=                                                            null
                                                                    ? const Icon(
                                                                        Icons.check_circle,
                                                                        color: Colors.greenAccent,
                                                                        size:  20,
                                                                      )
                                                                    : null,
                                                                enabledBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color:
                                                                        _appliedDiscountCode !=
                                                                            null
                                                                        ? Colors
                                                                              .greenAccent
                                                                        : Colors
                                                                              .white24,
                                                                  ),
                                                                ),
                                                                focusedBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide:
                                                                      const BorderSide(
                                                                        color: Colors
                                                                            .blue,
                                                                      ),
                                                                ),
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          SizedBox(
                                                            height: 56,
                                                            child: ElevatedButton(
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.orangeAccent,
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular( 12, ),
                                                                ),
                                                              ),
                                                              onPressed: () =>
                                                                  _applyDiscountCode(
                                                                    _discountCodeController
                                                                        .text,
                                                                  ),
                                                              child: const Text(
                                                                'Apply',
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (_appliedDiscountCode !=  null)
                                                        Padding(
                                                          padding:  const EdgeInsets.only( top: 6,),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.check_circle,
                                                                color: Colors.greenAccent,
                                                                size: 13,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  '$_appliedDiscountCode applied',
                                                                  style: const TextStyle(
                                                                    color: Colors.greenAccent,
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                              ),
                                                              GestureDetector(
                                                                onTap: () => setState(() {
                                                                  _appliedDiscountCode = null;
                                                                  _discountCodeController.clear();
                                                                  _discountController .clear();
                                                                  _calculateTotals();
                                                                }),
                                                                child: const Text(
                                                                  'Remove',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .redAccent,
                                                                    fontSize:
                                                                        12,
                                                                    decoration:
                                                                        TextDecoration
                                                                            .underline,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      if (!_showDiscountCodeField &&
                                                          _appliedDiscountCode == null) ...[
                                                        TextFormField(
                                                          controller: _discountController,
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                          keyboardType:  const TextInputType.numberWithOptions(
                                                                decimal: true,
                                                              ),
                                                          inputFormatters: [
                                                            FilteringTextInputFormatter.allow(
                                                              RegExp(
                                                                r'^(0(\.\d*)?|[1-9]\d*(\.\d*)?)?$',
                                                              ),
                                                            ),
                                                          ],
                                                          decoration: InputDecoration(
                                                            labelText:'Discount',
                                                            labelStyle: const TextStyle(
                                                                  color: Colors.white70, ),
                                                            prefixText: 'GHS ',
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(12, ),
                                                            ),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular( 12, ),
                                                              borderSide:
                                                                  const BorderSide(
                                                                    color: Colors
                                                                        .white24,
                                                                  ),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide:
                                                                  const BorderSide(
                                                                    color: Colors
                                                                        .blue,
                                                                  ),
                                                            ),
                                                            fillColor:
                                                                const Color(
                                                                  0xFF22304A,
                                                                ),
                                                            filled: true,
                                                          ),
                                                          validator: (value) {
                                                            if (value == null ||value.trim().isEmpty) {
                                                              return null;
                                                            }
                                                            final parsed = double.tryParse(value.trim(), );
                                                            if (parsed == null) {
                                                              return 'Enter a valid discount';
                                                            }
                                                            if (parsed < 0) {
                                                              return 'Discount cannot be negative';
                                                            }
                                                            return null;
                                                          },
                                                        ),
                                                      ],
                                                    ],
                                                    ],
                                                    SizedBox(height: 8),

                                                    const Divider(
                                                      color: Colors.white24,
                                                    ),
                                                    Wrap(
                                                      spacing: 10,
                                                      runSpacing: 10,
                                                      children: [
                                                        SizedBox(
                                                          width: 150,
                                                          child: ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:  Colors.orangeAccent,
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        16,
                                                                  ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                            ),
                                                            onPressed:
                                                                _addToSalesPreview,
                                                            child: Text(
                                                              "Save Record",
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 150,
                                                          child: ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors
                                                                      .lightBlue,
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        16,
                                                                  ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                            ),
                                                            onPressed:
                                                                _resetForm,
                                                            child: Text(
                                                              "Reset",
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
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
                                  Visibility(
                                    visible: !isMobile,
                                    child: SizedBox(
                                      width: itemWidth,
                                      child: Container(
                                        color: Color(0xFF182232),
                                        //height: 300,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    "SALES PREVIEW",
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  // Cart switcher
                                                  if (salesProvider
                                                          .customerCarts
                                                          .length >
                                                      1)
                                                    PopupMenuButton<String>(
                                                      icon: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.shopping_cart,
                                                            color:
                                                                Colors.orange,
                                                            size: 20,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            'Cart ${salesProvider.currentCartId.split('_')[1]} (${salesProvider.customerCarts.length})',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons
                                                                .arrow_drop_down,
                                                            color: Colors.white,
                                                            size: 20,
                                                          ),
                                                        ],
                                                      ),
                                                      color: Color(0xFF22304A),
                                                      itemBuilder: (context) {
                                                        return salesProvider.customerCarts.keys.map((
                                                          cartId,
                                                        ) {
                                                          final cartNum = cartId
                                                              .split('_')[1];
                                                          final itemCount =
                                                              salesProvider
                                                                  .customerCarts[cartId]
                                                                  ?.length ??
                                                              0;
                                                          final isActive = cartId == salesProvider.currentCartId;
                                                          return PopupMenuItem<String>(
                                                            value: cartId,
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  isActive
                                                                      ? Icons
                                                                            .radio_button_checked
                                                                      : Icons
                                                                            .radio_button_unchecked,
                                                                  color:
                                                                      isActive
                                                                      ? Colors
                                                                            .orange
                                                                      : Colors
                                                                            .white70,
                                                                  size: 18,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Cart $cartNum ($itemCount items)',
                                                                    style: TextStyle(
                                                                      color:
                                                                          isActive
                                                                          ? Colors.orange
                                                                          : Colors.white,
                                                                      fontWeight:
                                                                          isActive
                                                                          ? FontWeight.bold
                                                                          : FontWeight.normal,
                                                                    ),
                                                                  ),
                                                                ),
                                                                if (!isActive &&
                                                                    salesProvider
                                                                            .customerCarts
                                                                            .length >
                                                                        1)
                                                                  IconButton(
                                                                    icon: Icon(
                                                                      Icons
                                                                          .delete,
                                                                      color: Colors
                                                                          .red,
                                                                      size: 18,
                                                                    ),
                                                                    onPressed: () {
                                                                      Navigator.pop(
                                                                        context,
                                                                      );

                                                                      salesProvider
                                                                          .deleteCart(
                                                                            cartId,
                                                                          );
                                                                    },
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    constraints:
                                                                        BoxConstraints(),
                                                                  ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList();
                                                      },
                                                      onSelected: (cartId) {
                                                        context
                                                            .read<
                                                              SalesProvider
                                                            >()
                                                            .switchCart(cartId);
                                                      },
                                                    ),
                                                ],
                                              ),
                                              const Divider(
                                                color: Colors.white24,
                                              ),
                                              SizedBox(height: 15),

                                              Table(
                                                border: TableBorder.all(
                                                  color: Colors.grey,
                                                ),
                                                columnWidths: const {
                                                  0: FixedColumnWidth(40),
                                                  1: FlexColumnWidth(2),
                                                  2: FlexColumnWidth(1),
                                                  3: FlexColumnWidth(1),
                                                  4: FlexColumnWidth(1),
                                                  5: FlexColumnWidth(1),
                                                  6: FixedColumnWidth(60),
                                                },
                                                children: [
                                                  _tableRow([
                                                    "#",
                                                    "Item",
                                                    "Quantity",
                                                    "Price",
                                                    "Discount",
                                                    "Total",
                                                    "Action",
                                                  ], isHeader: true),
                                                  // Display sales items
                                                  ...salesItems.asMap().entries.map((
                                                    entry,
                                                  ) {
                                                    final index = entry.key;
                                                    final item = entry.value;
                                                    final isInsufficient =
                                                        salesProvider
                                                            .isPreviewItemInsufficient(
                                                              item,
                                                              value,
                                                            );
                                                    final isUnapproved =
                                                        item['isUnapproved'] ==
                                                        true;
                                                    // return _tableRowWithAction(
                                                    //   (index + 1).toString(),
                                                    //   item['item'] ?? '',
                                                    //
                                                    //   "${item['quantity'] ?? '0'}${item['mode'] ?? ''}",
                                                    //   item['price'] ?? '0',
                                                    //   item['discount']
                                                    //           ?.toString() ??
                                                    //       '0',
                                                    //   item['totalamount'] ??
                                                    //       '0',
                                                    //
                                                    //   () => context
                                                    //       .read<SalesProvider>()
                                                    //       .removeFromSalesPreview(
                                                    //         index,
                                                    //       ),
                                                    //   isInsufficient:
                                                    //       isInsufficient,
                                                    //   isUnapproved:
                                                    //       isUnapproved,
                                                    // );
                                                    return _tableRowWithAction(
                                                      (index + 1).toString(),
                                                      item['item'] ?? '',
                                                      "${item['quantity'] ?? '0'}${item['mode'] ?? ''}",
                                                      item['price'] ?? '0',
                                                      item['discount']?.toString() ?? '0',
                                                      item['totalamount'] ?? '0',
                                                          () => context.read<SalesProvider>().removeFromSalesPreview(index),
                                                      isInsufficient: isInsufficient,
                                                      isUnapproved: isUnapproved,
                                                      onSync: isInsufficient
                                                          ? () => _syncItemBalance(
                                                        item['itemid'] ?? '',
                                                        item['item'] ?? '',
                                                        item['branchid'] ?? '',
                                                        item['branchname'] ?? '',
                                                      )
                                                          : null,
                                                    );
                                                  }).toList(),
                                                  _tableRow([
                                                    "",
                                                    "Taxable Total",
                                                    "",
                                                    "",
                                                    "",
                                                    salesProvider
                                                        .calculateTaxableTotal()
                                                        .toStringAsFixed(2),
                                                    "",
                                                  ]),
                                                  if (salesProvider
                                                          .calculateDiscountTotal() >
                                                      0)
                                                    _tableRow([
                                                      "",
                                                      "Discount Total",
                                                      "",
                                                      "",
                                                      "",
                                                      salesProvider.calculateDiscountTotal().toStringAsFixed(2),
                                                      "",
                                                    ]),
                                                  _tableRow([
                                                    "",
                                                    "Payable Amount",
                                                    "",
                                                    "",
                                                    "",
                                                    salesProvider.calculateTaxableTotal()
                                                        .toStringAsFixed(2),
                                                    "",
                                                  ]),
                                                ],
                                              ),

                                              SizedBox(height: 20),
                                              LayoutBuilder(
                                                builder: (context, constraints) {
                                                  final isWideScreen =
                                                      constraints.maxWidth >
                                                      600;
                                                  final minWidth = isWideScreen
                                                      ? 170.0
                                                      : 130.0;

                                                  return Wrap(
                                                    spacing: isWideScreen
                                                        ? 12
                                                        : 10,
                                                    runSpacing: isWideScreen
                                                        ? 12
                                                        : 10,
                                                    alignment:
                                                        WrapAlignment.center,
                                                    children: [
                                                      // if (posPrint) ...[
                                                      //   _previewActionTile(
                                                      //     label: 'POS PRINT',
                                                      //     icon: Icons.print,
                                                      //     color: Colors.teal,
                                                      //     onTap: _printReceipt,
                                                      //     minWidth: minWidth,
                                                      //   ),
                                                      // ],
                                                      if (posPrint && cashAllowed) ...[
                                                        _previewActionTile(
                                                          label: 'POS PRINT',
                                                          icon: Icons.print,
                                                          color: Colors.teal,
                                                          onTap: _printReceipt,
                                                          minWidth: minWidth,
                                                        ),
                                                      ],
                                                      _previewActionTile(
                                                        label:
                                                            'NEW TRANSACTION',
                                                        icon: Icons
                                                            .add_shopping_cart,
                                                        color: Colors.lightBlue,

                                                        onTap: () {
                                                          final provider =
                                                              context
                                                                  .read<
                                                                    SalesProvider
                                                                  >();
                                                          provider
                                                              .createNewCart();

                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'New transaction created: ${provider.currentCartId}',
                                                              ),
                                                              backgroundColor:
                                                                  Colors.blue,
                                                              duration:
                                                                  const Duration(
                                                                    seconds: 2,
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                        minWidth: minWidth,
                                                      ),
                                                      _previewActionTile(
                                                        label: 'CUSTOMER INFO',
                                                        icon: Icons.person,
                                                        color: Colors.orange,
                                                        onTap: () async {
                                                          final salesProvider = Provider.of<SalesProvider>( context, listen: false, );
                                                          final activeBranchId = _activeBranchId;
                                                          // bool   isValid = await salesProvider.validateCartStockOnSaves(activeBranchId, );
                                                          //
                                                          // if (!isValid) {
                                                          //   snackMsg(context,'Insufficient stock detected. Please adjust cart.', Colors.red);
                                                          //
                                                          //   return;
                                                          // }

                                                          final isService = (_selectedItem?.producttype ?? '').toLowerCase().trim() == 'service';

                                                          if (!isService) {
                                                            bool isValid = await salesProvider.validateCartStockOnSaves(activeBranchId, );

                                                            if (!isValid) {
                                                              snackMsg(context,'Insufficient stock detected. Please adjust cart.', Colors.red);

                                                              return;
                                                            }
                                                          }
                                                          CustomerInfoDialog.show(
                                                            context: context,
                                                           // activeBranchId: value.activeBranchId,
                                                            activeBranchId: activeBranchId,
                                                            selectedItem: _selectedItem,
                                                          );
                                                        },
                                                        minWidth: minWidth,
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  Visibility(
                                    visible: isMobile && _showMobilePreview,
                                    child: MobileSalesPreview(
                                      cartItems: salesProvider.salesItems,
                                      customerCarts: salesProvider.customerCarts,
                                      currentCartId: salesProvider.currentCartId,
                                      taxableTotal: salesProvider.calculateTaxableTotal(),
                                      payableTotal: salesProvider.calculateTaxableTotal(),
                                      insufficientIndices: {
                                        for (int i = 0; i < salesProvider.salesItems.length; i++)
                                          if (salesProvider.isPreviewItemInsufficient(salesProvider.salesItems[i], value,)) i,
                                      },
                                      onSwitchCart: salesProvider.switchCart,
                                      onDeleteCart: salesProvider.deleteCart,
                                      onPrintReceipt: _printReceipt,
                                      onMomo: () {
                                        MomoDialog.showMomo(
                                          context: context,
                                          salesItems: salesProvider.salesItems,
                                        );
                                      },
                                      onNewTransaction: salesProvider.createNewCart,
                                      onCustomerInfo: () {
                                        CustomerInfoDialog.show(
                                          context: context,
                                          activeBranchId: _activeBranchId,
                                         // activeBranchId: value.activeBranchId,
                                          selectedItem: _selectedItem,
                                        );
                                      },
                                      onRemoveItem: (int index) {
                                        salesProvider.removeFromSalesPreview(index);
                                      },
                                      posPrint: posPrint,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells
          .map(
            (e) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                e,
                textAlign: isHeader ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  color: Colors.white,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _tableRowWithAction(
    String index,
    String item,
    String quantity,
    String price,
    String discount,
    String total,
    VoidCallback onDelete, {
    bool isInsufficient = false,
    bool isUnapproved = false,
    VoidCallback? onSync,
      }) {
    final textColor = isInsufficient ? Colors.redAccent : Colors.white;

    return TableRow(
      decoration: isInsufficient
          ? BoxDecoration(color: Colors.red.withOpacity(0.12))
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(index, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(item, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(quantity, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(price, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(discount, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(total, style: TextStyle(color: textColor)),
        ),

        Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (isInsufficient && onSync != null)
                IconButton(
                  icon: const Icon(Icons.sync, color: Colors.orange, size: 18),
                  onPressed: onSync,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}



