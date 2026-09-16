import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

class TierFeatureConfigScreen extends StatefulWidget {
  const TierFeatureConfigScreen({Key? key}) : super(key: key);

  @override
  State<TierFeatureConfigScreen> createState() => _TierFeatureConfigScreenState();
}

class _TierFeatureConfigScreenState extends State<TierFeatureConfigScreen>
    with SingleTickerProviderStateMixin {
  static const List<Map<String, String>> allFeatures = [

    {'key': 'user_management', 'label': 'User Management'},
    {'key': 'register_staff', 'label': 'Register Staff'},
    {'key': 'view_staff', 'label': 'View Staff'},
    {'key': 'role_access_config', 'label': 'Role Access Configuration'},
    {'key': 'register_branch', 'label': 'Register Branch'},
    {'key': 'view_branch', 'label': 'View Branch'},
    {'key': 'system_setup', 'label': 'System Setup'},
    {'key': 'supplier_registration', 'label': 'Supplier Registration'},
    {'key': 'branch_registration', 'label': 'Branch Registration'},
    {'key': 'return_damage_reasons', 'label': 'Return/Damage Reasons'},
    {'key': 'stocking_mode', 'label': 'Stocking Mode'},
    {'key': 'add_community', 'label': 'Add Community'},
    {'key': 'sms_setup', 'label': 'SMS Setup'},
    {'key': 'stock_management', 'label': 'Stock Management'},
    {'key': 'new_stock_entry', 'label': 'New Stock Entry'},
    {'key': 'view_stock_entries', 'label': 'View Stock Entries'},
    {'key': 'view_stock', 'label': 'View Stock'},
    {'key': 'view_transfers', 'label': 'View Transfer'},
    {'key': 'view_transfer_list', 'label': 'View Transfer List'},
    {'key': 'view_stock_transfers', 'label': 'View Stock Transfers'},
    {'key': 'purchase_returns', 'label': 'Purchase Returns'},
    {'key': 'view_purchase_returns', 'label': 'View Purchase Returns'},
    {'key': 'warehouse_supply', 'label': 'Warehouse Supply'},
    {'key': 'deleted_stock', 'label': 'Deleted Stock'},
    {'key': 'account', 'label': 'Account'},
    {'key': 'chart_of_accounts', 'label': 'Chart of Accounts'},
    {'key': 'activity_chart', 'label': 'Activity Chart'},
    {'key': 'payment_accounts', 'label': 'Payment Accounts'},
    {'key': 'payment_duration', 'label': 'Payment Duration'},
    {'key': 'configure_vat', 'label': 'Configure Vat'},
    {'key': 'add_vat', 'label': 'Add Vat'},
    {'key': 'creditor_openbal', 'label': 'Creditors Open Balance'},
    {'key': 'creditor_openbalview', 'label': 'View Creditors Balance'},
    {'key': 'creditor_payable', 'label': 'Creditor Payable'},
    {'key': 'view_account_payable', 'label': 'View Account Payable'},
    {'key': 'receivables', 'label': 'Receivables'},
    {'key': 'view_receivables', 'label': 'View Receivables'},
    {'key': 'debtor_bal', 'label': 'Debtors Balance'},
    {'key': 'bank_transfer', 'label': 'Bank Transfer'},
    {'key': 'banktransferview', 'label': 'Bank Transfer View'},
    {'key': 'journal_entry', 'label': 'Journal Entry'},
    {'key': 'journal_view', 'label': 'View Journal'},
    {'key': 'transactions', 'label': 'transactions'},
    {'key': 'sales', 'label': 'Sales'},
    {'key': 'cashier', 'label': 'cashier'},
    {'key': 'sales_view', 'label': 'sales_view'},
    {'key': 'close_sale', 'label': 'close_sale'},
    {'key': 'close_sale', 'label': 'close_sale'},
    {'key': 'discount', 'label': 'discount'},
    {'key': 'discount_view', 'label': 'discount_view'},
    {'key': 'reports', 'label': 'reports'},
    {'key': 'stock_report', 'label': 'Stock Report'},
    {'key': 'sales_report_summary', 'label': 'Sales Report Summary'},
    {'key': 'sales_report_summary', 'label': 'Sales Report Summary'},
    {'key': 'sales_report', 'label': 'Sales Report'},
    {'key': 'sales_register', 'label': 'sales_register Report'},
    {'key': 'general_ledger', 'label': 'General Ledger'},
    {'key': 'profit_and_loss', 'label': 'Profit and Loss'},
    {'key': 'category_sales_report', 'label': 'Category Sales Report'},
    {'key': 'sales_invoice', 'label': 'sales_invoice'},
    {'key': 'hamper_sales_report', 'label': 'Hamper Sales Report'},
    {'key': 'branch_balance', 'label': 'Branch Balance'},
    {'key': 'supplier_report', 'label': 'Supplier Report'},
    {'key': 'payment_report', 'label': 'Payment Report'},
    {'key': 'momo_report', 'label': 'Momo Report'},
    {'key': 'damage_report', 'label': 'Damage Report'},
    {'key': 'debtor_report', 'label': 'Debtor Report'},
    {'key': 'reorder_stock_report', 'label': 'Reorder Stock Report'},
    {'key': 'finished_stock_report', 'label': 'Finished Stock Report'},

    {'key': 'expenses', 'label': 'Expenses'},
    {'key': 'entry_expense', 'label': 'entry_expense'},
    {'key': 'view_expense', 'label': 'View Expense'},
    {'key': 'item', 'label': 'item'},
    {'key': 'item_category', 'label': 'item_category'},
    {'key': 'register_item', 'label': 'Register Item'},
    {'key': 'view_item', 'label': 'View Item'},
    {'key': 'branch_price', 'label': 'Branch Price'},
    {'key': 'print_barcode', 'label': 'Print Barcode'},
    {'key': 'bundle_item', 'label': 'Bundle Item'},
    {'key': 'view_bundle', 'label': 'View Bundle Item'},
    {'key': 'turn_off_bundle', 'label': 'Turn Off Bundle Item'},
    {'key': 'item_balance_sync', 'label': 'Item Balance Sync'},
    {'key': 'damages', 'label': 'damages'},
    {'key': 'register_damage', 'label': 'Register Damage'},
    {'key': 'damagelist', 'label': 'Damage view'},
    {'key': 'sales_return', 'label': 'sales_return'},
    {'key': 'return_sales', 'label': 'Return Sales'},
    {'key': 'sales_return_view', 'label': 'sales_return_view'},
    {'key': 'uploads', 'label': 'uploads'},
    {'key': 'receipt_upload', 'label': 'Receipt Upload'},
    {'key': 'receipt_upload_view', 'label': 'Receipt Upload View'},
    {'key': 'upload_item', 'label': 'Upload Item'},
    {'key': 'sms-management', 'label': 'SMS Management'},
    {'key': 'sales_register', 'label': 'Sales Register'},
    {'key': 'stock_report', 'label': 'Stock Report'},
    {'key': 'staff_sales_report', 'label': 'Staff Sales Report'},
    {'key': 'category_sales_report', 'label': 'Category Sales Report'},
    {'key': 'supplier_report', 'label': 'Supplier Report'},
    {'key': 'payment_report', 'label': 'Payment Report'},
    {'key': 'creditor_payable', 'label': 'Creditor Payable'},
    {'key': 'discount_codes', 'label': 'Discount Codes'},
    {'key': 'bundle_management', 'label': 'Bundle Management'},
    {'key': 'sales_return', 'label': 'Sales Return'},
    {'key': 'stock_transfer', 'label': 'Stock Transfer'},
    {'key': 'thermal_printing', 'label': 'Thermal Printing'},
    {'key': 'hubtel_payment', 'label': 'Hubtel Payment'},
    {'key': 'momo_payment', 'label': 'MoMo Payment'},
    {'key': 'general_ledger', 'label': 'General Ledger'},
    {'key': 'profit_and_loss', 'label': 'Profit and Loss'},
    {'key': 'multi_company', 'label': 'Multi Company'},
    {'key': 'bulk_stock_sync', 'label': 'Bulk Stock Sync'},
    {'key': 'salesupload', 'label': 'Sales Upload'},
    {'key': 'synczero', 'label': 'Sync Item to Zero'},
    {'key': 'salesunovalidate', 'label': 'Sales Upload (Without Validation)'},
  ];

  static const List<String> tiers = ['free_trial','starter', 'professional', 'enterprise'];

  late TabController _tabController;
  Map<String, Set<String>> _selections = {
    'free_trial': <String>{},
    'starter': <String>{},
    'professional': <String>{},
    'enterprise': <String>{},
  };
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tiers.length, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final datafeed = context.read<Datafeed>();
    await datafeed.loadTierFeatures(force: true);

    setState(() {
      for (final tier in tiers) {
        _selections[tier] = Set<String>.from(datafeed.tierFeatureSelections[tier] ?? []);
      }
      _loading = false;
    });
  }

  Future<void> _saveTier(String tier) async {
    setState(() => _saving = true);

    try {
      final datafeed = context.read<Datafeed>();
      await datafeed.saveTierFeatures(tier, _selections[tier]!.toList());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tier[0].toUpperCase()}${tier.substring(1)} tier updated successfully',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e', style: const TextStyle(color: Colors.white))),
      );
    }

    setState(() => _saving = false);
  }

  void _toggleFeature(String tier, String key, bool value) {
    setState(() {
      if (value) {
        _selections[tier]!.add(key);
      } else {
        _selections[tier]!.remove(key);
      }
    });
  }

  Widget _buildTierList(String tier) {
    final selected = _selections[tier]!;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: allFeatures.length,
            itemBuilder: (context, index) {
              final feature = allFeatures[index];
              final key = feature['key']!;
              final label = feature['label']!;
              final isChecked = selected.contains(key);

              return CheckboxListTile(
                value: isChecked,
                title: Text(label),
                subtitle: Text(key, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                onChanged: (value) => _toggleFeature(tier, key, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF1976D2),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _saveTier(tier),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
              ),
              child: _saving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text(
                'Save ${tier[0].toUpperCase()}${tier.substring(1)} Tier',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Tier Features'),
        backgroundColor: const Color(0xFF0D1A26),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.greenAccent,
          isScrollable: true,
          tabs: const [
            Tab(text: 'free_trial'),
            Tab(text: 'Starter'),
            Tab(text: 'Professional'),
            Tab(text: 'Enterprise'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: tiers.map(_buildTierList).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}