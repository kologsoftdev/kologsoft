
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/routes.dart';


const String roleAccessSelectionsCollection = 'role_access_configurations';

class RoleAccessAction {
  const RoleAccessAction({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.badge,
    required this.color,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final String badge;
  final Color color;
}

class RolePageSelection {
  const RolePageSelection({required this.route, required this.label});

  final String route;
  final String label;

  factory RolePageSelection.fromMap(Map<String, dynamic> map) {
    return RolePageSelection(
      route: map['route']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'route': route,
      'label': label,
    };
  }
}

String normalizeRoleKey(String accessLevel) {
  return accessLevel
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '')
      .trim();
}

Map<String, List<String>> getDefaultRoleAccessSelections() {
  return {
    'salesattendance': [
      Routes.salesview,
      Routes.stockreport,
    ],
    'salesmanager': [
      Routes.sales,
      Routes.stockreport,
      Routes.salesregister,
      Routes.stockrequest,
      Routes.stockrequestlist,
    ],
    'operationsofficer': [
      Routes.sales,
      Routes.salesview,
      Routes.farmerreg,
      Routes.stockreport,
      Routes.salesreportsummary,
      Routes.salesregister,
      Routes.hampersalereport,
      Routes.newstock,
      Routes.stocklisttable,
      Routes.stocklist,
      Routes.stockrequest,
      Routes.stockrequestlist,
      Routes.expense,
      Routes.expenseview,
      Routes.itemreg,
      Routes.itemlist,
      Routes.damages,
      Routes.damagelist,
      Routes.uploadreceipt,
    ],
    'stockofficer': [
      Routes.newstock,
      Routes.stockrequest,
      Routes.stocklist,
      Routes.stocklisttable,
      Routes.stocksupply,
      Routes.stockrequestlist,
      Routes.stockreport,
      Routes.supplierlist,
      Routes.damages,
      Routes.damagelist,
      Routes.uploadreceipt,
      Routes.uploadreceiptview,
      Routes.warehousehomescreen,
    ],
    'accountant': [
      Routes.coa,
      Routes.activityChartReg,
      Routes.activityChartView,
      Routes.paymentaccounts,
      Routes.paymentdurationreg,
      Routes.paymentdurationview,
      Routes.creditopenbal,
      Routes.creditopenbalview,
      Routes.creditorpayable,
      Routes.creditorpayableview,
      Routes.debtorlist,
      Routes.debtorBal,
      Routes.debtpayments,
      Routes.debtorBalView,
      Routes.banktransfer,
      Routes.banktransferview,
      Routes.journalEntry,
      Routes.journalView,
      Routes.salesreportsummary,
      Routes.stockreport,
      Routes.staffsalereport,
      Routes.salesregister,
      Routes.hampersalereport,
      Routes.salesreport,
      Routes.uploadreceipt,
      Routes.uploadreceiptview,
    ],
  };
}

List<RoleAccessAction> buildRoleAccessActions(
    String accessLevel, {
      Map<String, List<String>>? roleSelections,
    }) {
  final roleKey = normalizeRoleKey(accessLevel);
  final selections = roleSelections ?? getDefaultRoleAccessSelections();
  final selectedRoutes = <String>[];

  if (selections.containsKey(roleKey)) {
    selectedRoutes.addAll(selections[roleKey]!);
  } else {
    final fallbackKey = _fallbackRoleKey(roleKey);
    if (selections.containsKey(fallbackKey)) {
      selectedRoutes.addAll(selections[fallbackKey]!);
    }
  }

  if (selectedRoutes.isEmpty) {
    return [];
  }

  return selectedRoutes
      .map((route) => _buildActionFromRoute(route))
      .whereType<RoleAccessAction>()
      .toList();
}

String _fallbackRoleKey(String roleKey) {
  if (roleKey.contains('salesmanager')) return 'salesmanager';
  if (roleKey.contains('salesattendance')) return 'salesattendance';
  if (roleKey.contains('operation') || roleKey.contains('officer')) {
    return 'operationsofficer';
  }
  if (roleKey.contains('stock')) return 'stockofficer';
  if (roleKey.contains('accountant')) return 'accountant';
  return roleKey;
}

RoleAccessAction? _buildActionFromRoute(String route) {
  final metadata = _routeMetadata[route];
  if (metadata == null) {
    return null;
  }

  return RoleAccessAction(
    id: route,
    title: metadata['title'] as String,
    description: metadata['description'] as String,
    icon: metadata['icon'] as IconData,
    route: route,
    badge: metadata['badge'] as String,
    color: metadata['color'] as Color,
  );
}


String pageLabelForRoute(String route) {
  return _routeMetadata[route]?['title']?.toString() ?? route;
}

final Map<String, Map<String, Object>> _routeMetadata = {
  Routes.sales: {
    'title': 'Sales',
    'description': 'Sales entry and management',
    'icon': Icons.point_of_sale,
    'badge': 'Entry',
    'color': const Color(0xFF1976D2),
  },
  Routes.dailysalesreport: {
    'title': 'Daily Sales Report',
    'description': 'Daily sales report',
    'icon': Icons.bar_chart,
    'badge': 'Report',
    'color': const Color(0xFF1976D2),
  },
  Routes.warehousehomescreen: {
    'title': 'Warehouse Home Screen',
    'description': 'Warehouse home screen',
    'icon': Icons.home,
    'badge': 'Home',
    'color': const Color(0xFF1976D2),
  },
  Routes.salesview: {
    'title': 'Sales View',
    'description': 'View sales records',
    'icon': Icons.visibility,
    'badge': 'View',
    'color': const Color(0xFF1976D2),
  },
  Routes.farmerreg: {
    'title': 'Farmer Registration',
    'description': 'Add and review farmer records',
    'icon': Icons.person_add,
    'badge': 'Entry',
    'color': const Color(0xFF388E3C),
  },
  Routes.viewfarmers: {
    'title': 'View Farmers',
    'description': 'Browse farmer records',
    'icon': Icons.people,
    'badge': 'View',
    'color': const Color(0xFF7B1FA2),
  },
  Routes.stockreport: {
    'title': 'Stock Report',
    'description': 'Branch stock overview',
    'icon': Icons.inventory_2,
    'badge': 'Report',
    'color': const Color(0xFFF57C00),
  },
  Routes.salesregister: {
    'title': 'Sales Register',
    'description': 'Daily sales register',
    'icon': Icons.receipt_long,
    'badge': 'Report',
    'color': const Color(0xFFD32F2F),
  },
  Routes.stockrequest: {
    'title': 'Stock Requests',
    'description': 'Create and track requests',
    'icon': Icons.request_page,
    'badge': 'Branch',
    'color': const Color(0xFF00897B),
  },
  Routes.stockrequestlist: {
    'title': 'Request List',
    'description': 'Review request history',
    'icon': Icons.list_alt,
    'badge': 'Branch',
    'color': const Color(0xFF6A1B9A),
  },
  Routes.salesreportsummary: {
    'title': 'Sales Summary',
    'description': 'Sales summary report',
    'icon': Icons.bar_chart,
    'badge': 'Report',
    'color': const Color(0xFFF57C00),
  },
  Routes.hampersalereport: {
    'title': 'Hamper Sales Report',
    'description': 'Hamper sales report',
    'icon': Icons.bar_chart,
    'badge': 'Report',
    'color': const Color(0xFFF57C00),
  },
  Routes.newstock: {
    'title': 'Stock Management',
    'description': 'Maintain stock entries',
    'icon': Icons.inventory_2,
    'badge': 'Read/Write',
    'color': const Color(0xFF00897B),
  },
  Routes.stocklisttable: {
    'title': 'Stock List Table',
    'description': 'View stock table',
    'icon': Icons.table_chart,
    'badge': 'Read/Write',
    'color': const Color(0xFF00897B),
  },
  Routes.stocklist: {
    'title': 'Stock List',
    'description': 'View stock list',
    'icon': Icons.list,
    'badge': 'Read/Write',
    'color': const Color(0xFF00897B),
  },
  Routes.expense: {
    'title': 'Expenses',
    'description': 'Entry and review expenses',
    'icon': Icons.receipt,
    'badge': 'Read/Write',
    'color': const Color(0xFF7B1FA2),
  },
  Routes.expenseview: {
    'title': 'Expense View',
    'description': 'View expense records',
    'icon': Icons.receipt_long,
    'badge': 'Read/Write',
    'color': const Color(0xFF7B1FA2),
  },
  Routes.itemreg: {
    'title': 'Items',
    'description': 'Manage item records',
    'icon': Icons.category,
    'badge': 'Read/Write',
    'color': const Color(0xFF5D4037),
  },
  Routes.itemlist: {
    'title': 'Item List',
    'description': 'Browse item records',
    'icon': Icons.category,
    'badge': 'Read/Write',
    'color': const Color(0xFF5D4037),
  },
  Routes.damages: {
    'title': 'Damages',
    'description': 'Log damages',
    'icon': Icons.warning_amber,
    'badge': 'Read/Write',
    'color': const Color(0xFFD32F2F),
  },
  Routes.damagelist: {
    'title': 'Damage List',
    'description': 'Review damages',
    'icon': Icons.warning_amber,
    'badge': 'Read/Write',
    'color': const Color(0xFFD32F2F),
  },
  Routes.uploadreceipt: {
    'title': 'Uploads',
    'description': 'Upload receipts and records',
    'icon': Icons.upload_file,
    'badge': 'Read/Write',
    'color': const Color(0xFF455A64),
  },
  Routes.uploadreceiptview: {
    'title': 'Upload History',
    'description': 'Review uploaded receipts',
    'icon': Icons.file_copy,
    'badge': 'Read/Write',
    'color': const Color(0xFF455A64),
  },
  Routes.stocksupply: {
    'title': 'Stock Supply',
    'description': 'Stock delivery overview',
    'icon': Icons.local_shipping,
    'badge': 'Read/Write',
    'color': const Color(0xFF00897B),
  },
  Routes.supplierlist: {
    'title': 'Suppliers',
    'description': 'Supplier activity overview',
    'icon': Icons.business,
    'badge': 'Report',
    'color': const Color(0xFF1976D2),
  },
  Routes.coa: {
    'title': 'Accounts',
    'description': 'Chart of accounts',
    'icon': Icons.account_balance,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.activityChartReg: {
    'title': 'Activity Chart',
    'description': 'Manage activity chart',
    'icon': Icons.account_tree,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.activityChartView: {
    'title': 'Activity Chart View',
    'description': 'View chart entries',
    'icon': Icons.account_tree,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.paymentaccounts: {
    'title': 'Payment Accounts',
    'description': 'Payment methods',
    'icon': Icons.payment,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.paymentdurationreg: {
    'title': 'Payment Duration',
    'description': 'Manage payment duration',
    'icon': Icons.timelapse,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.paymentdurationview: {
    'title': 'Payment Duration View',
    'description': 'View payment durations',
    'icon': Icons.timelapse,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.creditopenbal: {
    'title': 'Credit Opening Balance',
    'description': 'Manage credit opening balance',
    'icon': Icons.balance,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.creditopenbalview: {
    'title': 'Credit Opening Balance View',
    'description': 'View balances',
    'icon': Icons.balance,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.creditorpayable: {
    'title': 'Creditors Payable',
    'description': 'Manage creditors',
    'icon': Icons.account_balance_wallet,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.creditorpayableview: {
    'title': 'Creditors Payable View',
    'description': 'View creditor transactions',
    'icon': Icons.account_balance_wallet,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.debtorlist: {
    'title': 'Debtors',
    'description': 'Manage debtors',
    'icon': Icons.people_alt,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.debtorBal: {
    'title': 'Debtor Balance',
    'description': 'Debtor balance overview',
    'icon': Icons.currency_exchange,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.debtpayments: {
    'title': 'Debtor Payments',
    'description': 'Manage debtor payments',
    'icon': Icons.payments,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.debtorBalView: {
    'title': 'Debtor Balance View',
    'description': 'Browse debtor balances',
    'icon': Icons.currency_exchange,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.banktransfer: {
    'title': 'Bank Transfer',
    'description': 'Record bank transfers',
    'icon': Icons.swap_horiz,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.banktransferview: {
    'title': 'Bank Transfer View',
    'description': 'View transfers',
    'icon': Icons.swap_horiz,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.journalEntry: {
    'title': 'Journal Entry',
    'description': 'Create journal entries',
    'icon': Icons.book,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.journalView: {
    'title': 'Journal View',
    'description': 'View journal entries',
    'icon': Icons.book_outlined,
    'badge': 'Account',
    'color': const Color(0xFF1976D2),
  },
  Routes.staffsalereport: {
    'title': 'Staff Sales Report',
    'description': 'Staff sales overview',
    'icon': Icons.bar_chart,
    'badge': 'Report',
    'color': const Color(0xFFF57C00),
  },
  Routes.salesreport: {
    'title': 'Sales Report',
    'description': 'Sales report',
    'icon': Icons.bar_chart,
    'badge': 'Report',
    'color': const Color(0xFFF57C00),
  },
};

class RoleAccessConfigScreen extends StatefulWidget {
  const RoleAccessConfigScreen({super.key});

  @override
  State<RoleAccessConfigScreen> createState() =>
      _RoleAccessConfigScreenState();
}

class _RoleAccessConfigScreenState extends State<RoleAccessConfigScreen> {
  String _selectedRole = 'salesmanager';
  final Map<String, List<String>> _selections = {};
  bool _isSaving = false;
  bool _isLoading = true;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();

  static const List<_RoleOption> _roleOptions = [
    _RoleOption(value: 'salesattendance', label: 'Sales Attendance'),
    _RoleOption(value: 'salesmanager', label: 'Sales Manager'),
    _RoleOption(value: 'operationsofficer', label: 'Operations Officer'),
    _RoleOption(value: 'stockofficer', label: 'Stock Officer'),
    _RoleOption(value: 'accountant', label: 'Accountant'),
  ];

  static const List<_PageOption> _pageOptions = [
    _PageOption(route: Routes.sales, label: 'Sales'),
    _PageOption(route: Routes.warehousehomescreen, label: 'Warehouse Home Screen'),
    _PageOption(route: Routes.salesview, label: 'Sales View'),
    _PageOption(route: Routes.farmerreg, label: 'Farmer Registration'),
    _PageOption(route: Routes.viewfarmers, label: 'View Farmers'),
    _PageOption(route: Routes.stockreport, label: 'Stock Report'),
    _PageOption(route: Routes.salesregister, label: 'Sales Register'),
    _PageOption(route: Routes.stockrequest, label: 'Stock Requests'),
    _PageOption(route: Routes.stockrequestlist, label: 'Request List'),
    _PageOption(route: Routes.salesreportsummary, label: 'Sales Summary'),
    _PageOption(route: Routes.hampersalereport, label: 'Hamper Sales Report'),
    _PageOption(route: Routes.newstock, label: 'Stock Management'),
    _PageOption(route: Routes.stocklisttable, label: 'Stock List Table'),
    _PageOption(route: Routes.stocklist, label: 'Stock List'),
    _PageOption(route: Routes.expense, label: 'Expenses'),
    _PageOption(route: Routes.expenseview, label: 'Expense View'),
    _PageOption(route: Routes.itemreg, label: 'Items'),
    _PageOption(route: Routes.itemlist, label: 'Item List'),
    _PageOption(route: Routes.damages, label: 'Damages'),
    _PageOption(route: Routes.damagelist, label: 'Damage List'),
    _PageOption(route: Routes.uploadreceipt, label: 'Uploads'),
    _PageOption(route: Routes.uploadreceiptview, label: 'Upload History'),
    _PageOption(route: Routes.stocksupply, label: 'Stock Supply'),
    _PageOption(route: Routes.supplierlist, label: 'Suppliers'),
    _PageOption(route: Routes.coa, label: 'Accounts'),
    _PageOption(route: Routes.activityChartReg, label: 'Activity Chart'),
    _PageOption(
        route: Routes.activityChartView, label: 'Activity Chart View'),
    _PageOption(route: Routes.paymentaccounts, label: 'Payment Accounts'),
    _PageOption(route: Routes.paymentdurationreg, label: 'Payment Duration'),
    _PageOption(
        route: Routes.paymentdurationview, label: 'Payment Duration View'),
    _PageOption(
        route: Routes.creditopenbal, label: 'Credit Opening Balance'),
    _PageOption(
        route: Routes.creditopenbalview,
        label: 'Credit Opening Balance View'),
    _PageOption(route: Routes.creditorpayable, label: 'Creditors Payable'),
    _PageOption(
        route: Routes.creditorpayableview,
        label: 'Creditors Payable View'),
    _PageOption(route: Routes.debtorlist, label: 'Debtors'),
    _PageOption(route: Routes.debtorBal, label: 'Debtor Balance'),
    _PageOption(route: Routes.debtpayments, label: 'Debtor Payments'),
    _PageOption(route: Routes.debtorBalView, label: 'Debtor Balance View'),
    _PageOption(route: Routes.banktransfer, label: 'Bank Transfer'),
    _PageOption(route: Routes.banktransferview, label: 'Bank Transfer View'),
    _PageOption(route: Routes.journalEntry, label: 'Journal Entry'),
    _PageOption(route: Routes.journalView, label: 'Journal View'),
    _PageOption(route: Routes.staffsalereport, label: 'Staff Sales Report'),
    _PageOption(route: Routes.salesreport, label: 'Sales Report'),

  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSelections());
  }

  @override
  void dispose() {
    _labelController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  Future<void> _loadSelections() async {
    final datafeed = context.read<Datafeed>();
    await datafeed.loadRoleAccessSelections();
    if (!mounted) return;
    final loaded = datafeed.roleAccessSelections ?? getDefaultRoleAccessSelections();
    setState(() {
      _isLoading = false;
      _selections.clear();
      _selections.addAll(
        loaded.map((key, value) => MapEntry(key, List<String>.from(value))),
      );
      if (!_selections.containsKey(_selectedRole)) {
        _selections[_selectedRole] = List<String>.from(
          getDefaultRoleAccessSelections()[_selectedRole] ?? const <String>[],
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedPages = _selections[_selectedRole] ?? <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role page setup'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSelections,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose which pages appear for each access level.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Access level',
                border: OutlineInputBorder(),
              ),
              items: _roleOptions
                  .map(
                    (role) => DropdownMenuItem<String>(
                  value: role.value,
                  child: Text(role.label),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedRole = value;
                  if (!_selections.containsKey(_selectedRole)) {
                    _selections[_selectedRole] = List<String>.from(
                      getDefaultRoleAccessSelections()[_selectedRole] ??
                          const <String>[],
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final page in _pageOptions)
                    CheckboxListTile(
                      dense: true,
                      title: Text(page.label),
                      subtitle: const Text(''),
                      value: selectedPages.contains(page.route),
                      onChanged: (value) {
                        setState(() {
                          final current =
                          List<String>.from(selectedPages);
                          if (value == true) {
                            if (!current.contains(page.route)) {
                              current.add(page.route);
                            }
                          } else {
                            current.remove(page.route);
                          }
                          _selections[_selectedRole] = current;
                        });
                      },
                    ),
                  for (final page in selectedPages.where((route) =>
                  !_pageOptions.any((known) => known.route == route)))
                    ListTile(
                      title: Text(pageLabelForRoute(page)),
                      subtitle: Text(page),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            final current =
                            List<String>.from(selectedPages);
                            current.remove(page);
                            _selections[_selectedRole] = current;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              children: [
                OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Reset defaults',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSelections,
                  icon: _isSaving
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                    CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save changes'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCustomPage() async {
    final label = _labelController.text.trim();
    final route = _routeController.text.trim();
    if (label.isEmpty || route.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide both a label and route.')),
      );
      return;
    }

    setState(() {
      final current = List<String>.from(_selections[_selectedRole] ?? <String>[]);
      if (!current.contains(route)) {
        current.add(route);
      }
      _selections[_selectedRole] = current;
      _labelController.clear();
      _routeController.clear();
    });
  }

  Future<void> _saveSelections() async {
    setState(() => _isSaving = true);
    final datafeed = context.read<Datafeed>();
    await datafeed.saveRoleAccessSelections(_selections);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Role page selection saved.')),
    );
    setState(() => _isSaving = false);
    Navigator.pop(context, true);
  }

  void _resetToDefaults() {
    setState(() {
      _selections[_selectedRole] = List<String>.from(
        getDefaultRoleAccessSelections()[_selectedRole] ?? const <String>[],
      );
    });
  }
}

class _RoleOption {
  const _RoleOption({required this.value, required this.label});
  final String value;
  final String label;
}

class _PageOption {
  const _PageOption({required this.route, required this.label});
  final String route;
  final String label;
}