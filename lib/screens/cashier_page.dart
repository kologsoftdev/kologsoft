import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/salesmodel.dart';
import 'package:kologsoft/screens/salesPointInvoicePriview.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/paymentMethod.dart';
import '../paymentwidgets/changepasswordDialog.dart';
import '../paymentwidgets/showlogout.dart';
import '../providers/cashier_provider.dart';
import '../providers/routes.dart';


class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> with SingleTickerProviderStateMixin {

  String _searchQuery = '';
  String _selectedFilter = 'Pending';
  final List<String> _filters = ['All', 'Pending', 'Paid','Credit'];
  late TabController _tabController;
  bool _isMobileView = false;
  bool _showInvoiceList = true;
  final GlobalKey<FormState> _cashierFormKey = GlobalKey<FormState>();
  final List<String> momoNetworks = ['MTN', 'Vodafone', 'AirtelTigo', 'Telecel'];
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeActive = false;
  List<String> _paymentMethods = [];
  String paymentMethod='';
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() async{
      final provider = Provider.of<CashierProvider>(context, listen: false);
      await provider.getdata();
      provider.listenToInvoices(context);
      _paymentMethods=provider.allowedPaymentMethods;
    });
  }

  TextEditingController? accountNumberController = TextEditingController();
  TextEditingController referenceController = TextEditingController();
  TextEditingController amountPaidController = TextEditingController();
  @override
  void dispose() {
    _tabController.dispose();
    accountNumberController?.dispose();
    referenceController.dispose();
    amountPaidController.dispose();
    super.dispose();
  }

  Future<void> _showDateRangePicker() async {
    final DateTime? start = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (start != null) {
      final DateTime? end = await showDatePicker(
        context: context,
        initialDate: _endDate ?? start,
        firstDate: start,
        lastDate: DateTime.now(),
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

      if (end != null) {
        setState(() {
          _startDate = DateTime(start.year, start.month, start.day);
          _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
          _isDateRangeActive = true;
        });
        if (_startDate == null || _endDate == null) return;
        final cashDate = Provider.of<CashierProvider>(context, listen: false);
        cashDate.listenToInvoices(context,todayOnly:false,startDate:_startDate ,endDate:_endDate);

        _showDateRangeBadge();
      }
    }
  }
  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeActive = false;
    });
    final cash = Provider.of<CashierProvider>(context, listen: false);
    cash.listenToInvoices(context);
    _showSuccessSnackBar('Date filters cleared');
  }
  void _showDateRangeBadge() {
    if (_startDate == null || _endDate == null) return;

    final message = 'Showing: ${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.date_range, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
  void _selectInvoice(SalesModel invoice) {
    context.read<CashierProvider>().selectInvoice(invoice.id, invoice);

    if (_isMobileView) {
      setState(() {
        _showInvoiceList = false;
      });
    }
  }

  String _getCustomerName(SalesModel invoice) {
    return invoice.customerName ?? 'Walk-in Customer';
  }

  List<SalesModel> get _filteredInvoices {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final invoices = provider.invoices;
    return invoices.where((invoice) {
      if (_selectedFilter != 'All') {
        final status = invoice.paymentStatus;
        final transmode = invoice.transMode;
        bool printed = invoice.printed;
        if (_selectedFilter == 'Pending' && status == 'paid') return false;
        if (_selectedFilter == 'Paid' && status != 'paid') return false;
        if (_selectedFilter == 'Credit' && transmode != 'credit') return false;
      }

      // Apply search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final receiptNumber = invoice.receiptNumber.toString().toLowerCase();
        final customerName = _getCustomerName(invoice).toLowerCase();
        final transmode = invoice.transMode.toString().toLowerCase();
        return receiptNumber.contains(query) || customerName.contains(query)|| transmode.contains(query);
      }

      return true;
    }).toList();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2A3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Invoices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return ListTile(
                leading: Icon(
                  _getFilterIcon(filter),
                  color: isSelected ? Colors.green : Colors.white70,
                ),
                title: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.green : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _selectedFilter = filter);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All': return Icons.list;
      case 'Pending': return Icons.pending;
      case 'Paid': return Icons.check_circle;
      case 'Today': return Icons.today;
      case 'Credit': return Icons.credit_card;
      default: return Icons.filter_list;
    }
  }

  Widget _buildDesktopLayout() {
    final provider=Provider.of<CashierProvider>(context,listen: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInvoicePanel(),

        if (provider.selectedInvoice != null)
          _buildInvoiceDetailsPanel()
        else
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final provider=Provider.of<CashierProvider>(context,listen: false);
    if (provider.selectedInvoice != null && !_showInvoiceList) {
      return _buildMobileInvoiceDetails();
    }
    return _buildMobileInvoiceList();
  }

  Widget _buildInvoicePanel() {
    final provider=Provider.of<CashierProvider>(context,listen: true);
    final filteredInvoices = _filteredInvoices;

    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: const Color(0xFF102433),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pending / Credit',
                    'GHS ${provider.totalPendingAmount.toStringAsFixed(2)}',
                    '${provider.pendingCount} invoices',
                    Colors.orange,
                    Icons.pending,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Paid Today',
                    'GHS ${provider.totalPaidToday.toStringAsFixed(2)}',
                    '${provider.paidCount} invoices',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
          ),

          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by receipt or customer...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E3A5A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedFilter = filter);
                          },
                          backgroundColor: const Color(0xFF1E3A5A),
                          selectedColor: Colors.green.shade800,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide.none,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade700.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range, size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _clearDateRange,
                        child: const Icon(Icons.close, size: 14, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Invoice List
          Expanded(
            child: filteredInvoices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _searchQuery.isNotEmpty ? Icons.search_off : Icons.receipt,
                      size: 48,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No matching invoices'
                        : 'No invoices found for selected filter',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      child: const Text('Clear search'),
                    ),
                  ],
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredInvoices.length,
              itemBuilder: (context, index) {
                final invoice = filteredInvoices[index];
                final isSelected = provider.selectedInvoiceId == invoice.id;
                return _buildInvoiceCard(invoice, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String amount, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(SalesModel invoice, bool isSelected) {
    final receiptNumber = invoice.receiptNumber;
    final customerName = _getCustomerName(invoice);
    final totalAmount = invoice.totalamount.toDouble();
    final amountPaid = invoice.amountPaid.toDouble();
    String paymentStatus = invoice.paymentStatus;
    if(invoice.transMode=='credit')
      {
        paymentStatus='credit';
      }
    final createdAt = invoice.createdAt?.toDate();

    Color getStatusColor() {
      switch (paymentStatus) {
        case 'paid':
          return Colors.green;
        case 'credit':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    }

    IconData getStatusIcon() {
      switch (paymentStatus) {
        case 'paid':
          return Icons.check_circle;
        case 'partial':
          return Icons.pending;
        default:
          return Icons.schedule;
      }
    }

    return GestureDetector(
      onTap: () => _selectInvoice(invoice),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade800.withOpacity(0.3),
              Colors.green.shade900.withOpacity(0.3),
            ],
          )
              : null,
          color: isSelected ? null : const Color(0xFF0D2A3C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.green.shade400
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  getStatusIcon(),
                  color: getStatusColor(),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receiptNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _dateTimeFormat.format(createdAt),
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'GHS ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (paymentStatus == 'partial') ...[
                      const SizedBox(height: 2),
                      Text(
                        'Paid: GHS ${amountPaid.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  paymentStatus.toUpperCase(),
                  style: TextStyle(
                    color: getStatusColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileInvoiceList() {
    final provider=Provider.of<CashierProvider>(context,listen: false);

    final filteredInvoices = _filteredInvoices;

    return Column(
      children: [
        // Stats Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF102433),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  'GHS ${provider.totalPendingAmount.toStringAsFixed(2)}',
                  '${provider.pendingCount} invoices',
                  Colors.orange,
                  Icons.pending,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Paid Today',
                  'GHS ${provider.totalPaidToday.toStringAsFixed(2)}',
                  '${provider.paidCount} invoices',
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF102433),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by receipt or customer...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white70),
                onPressed: () => setState(() => _searchQuery = ''),
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E3A5A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0D2A3C),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = filter);
                    },
                    backgroundColor: const Color(0xFF1E3A5A),
                    selectedColor: Colors.green.shade800,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide.none,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Results Count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0D2A3C),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredInvoices.length} invoices',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              Text(
                _selectedFilter,
                style: TextStyle(
                  color: Colors.green.shade300,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // date range display
        if (_startDate != null && _endDate != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade700.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _clearDateRange,
                  child: const Icon(Icons.close, size: 14, color: Colors.blue),
                ),
              ],
            ),
          ),
        // Invoice List
        Expanded(
          child: filteredInvoices.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _searchQuery.isNotEmpty ? Icons.search_off : Icons.receipt,
                    size: 48,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No matching invoices'
                      : 'No invoices found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _searchQuery = ''),
                    child: const Text('Clear search'),
                  ),
                ],
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredInvoices.length,
            itemBuilder: (context, index) {
              final invoice = filteredInvoices[index];
              final isSelected = provider.selectedInvoiceId == invoice.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMobileInvoiceCard(invoice, isSelected),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileInvoiceCard(SalesModel invoice, bool isSelected) {
    final receiptNumber = invoice.receiptNumber;
    final customerName = _getCustomerName(invoice);
    final totalAmount = (invoice.totalamount as num?)?.toDouble() ?? 0;
    final amountPaid = (invoice.amountPaid as num?)?.toDouble() ?? 0;
    String paymentStatus = invoice.paymentStatus;
    if(invoice.transMode=='credit')
      {
        paymentStatus='credit';
      }
    final createdAt = (invoice.createdAt as Timestamp?)?.toDate();

    Color getStatusColor() {
      switch (paymentStatus) {
        case 'paid':
          return Colors.green;
        case 'credit':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    }

    return GestureDetector(
      onTap: () => _selectInvoice(invoice),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade800.withOpacity(0.3),
              Colors.green.shade900.withOpacity(0.3),
            ],
          )
              : null,
          color: isSelected ? null : const Color(0xFF0D2A3C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.green.shade400
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      paymentStatus == 'paid' ? Icons.check_circle :
                      paymentStatus == 'partial' ? Icons.pending :
                      Icons.receipt,
                      color: getStatusColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receiptNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          customerName,
                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: getStatusColor().withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      paymentStatus.toUpperCase(),
                      style: TextStyle(
                        color: getStatusColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GHS ${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (amountPaid > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Paid',
                          style: TextStyle(
                            color: Colors.green.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'GHS ${amountPaid.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (totalAmount - amountPaid > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Balance',
                          style: TextStyle(
                            color: Colors.orange.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'GHS ${(totalAmount - amountPaid).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.orange.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _dateTimeFormat.format(createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceDetailsPanel() {
    final provider=Provider.of<CashierProvider>(context,listen: false);
    String paymentStatus = provider.selectedInvoice!.paymentStatus;
    if (provider.selectedInvoice!.transMode=='credit'){
      paymentStatus='credit';
    }
    return Expanded(
      child: Container(
        color: const Color(0xFF0F1E2E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade800.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt #${provider.selectedInvoice?.receiptNumber ?? ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.selectedInvoice != null ? _getCustomerName(provider.selectedInvoice!) : '',
                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(paymentStatus),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _buildPaymentSection(),
                    const SizedBox(height: 24),

                    _buildSummarySection(),

                    const SizedBox(height: 24),

                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileInvoiceDetails() {
    final provider=Provider.of<CashierProvider>(context,listen: false);

    final invoice = provider.selectedInvoice!;
    final totalAmount = (invoice.totalamount as num?)?.toDouble() ?? 0;
    final amountPaid = (invoice.amountPaid  as num?)?.toDouble() ?? 0;
    final balance = totalAmount - amountPaid;
    String paymentStatus = invoice.paymentStatus;
    if (invoice.transMode=='credit'){
      paymentStatus='credit';
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF102433),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt #${invoice.receiptNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCustomerName(invoice),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(paymentStatus),
            ],
          ),
        ),

        // Amount Summary
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF0D2A3C),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GHS ${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (amountPaid > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Paid',
                      style: TextStyle(color: Colors.green.withOpacity(0.6), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GHS ${amountPaid.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.green.shade300, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              if (balance > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(color: Colors.orange.withOpacity(0.6), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GHS ${balance.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.orange.shade300, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [

              _buildMobileDetailsTab(),

              _buildMobilePaymentTab(),

            ],
          ),
        ),
        _buildActionButtons()
      ],
    );
  }

  Widget _buildPaymentSection() {
    final provider = Provider.of<CashierProvider>(context, listen: false);

    final invoice = provider.selectedInvoice!;
    final invoiceId = invoice.id;
    final paymentStatus = invoice.paymentStatus;
    final transmode = invoice.transMode;
    final totalAmount = (invoice.totalamount as num?)?.toDouble() ?? 0.0;
    final amountPaid = (invoice.amountPaid as num?)?.toDouble() ?? 0.0;
    final change = (invoice.change as num?)?.toDouble() ?? 0.0;
    final balance = totalAmount - amountPaid;
      paymentMethod = provider.selectedPaymentMethods[invoiceId] ?? 'cash';
    String? selectedNetwork = provider.selectedNetworks[invoiceId];

    double currentChange=0.00;
    if (paymentStatus == 'paid') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withAlpha((0.3 * 255).round())),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Text(
            //   'Amount Paid: GHS ${amountPaid.toStringAsFixed(2)}',
            //   style: const TextStyle(color: Colors.white70, fontSize: 14),
            // ),
            if (change > 0)
              Text(
                'Change: GHS ${change.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      );
    }
    if (transmode == 'credit') {
  return  Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2A3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: balance > 0 ? Colors.orange : Colors.green, width: 1),
      ),
      child:const Text("Credit customer",style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),)
  );
}
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2A3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: balance > 0 ? Colors.orange : Colors.green, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(balance > 0 ? Icons.payment : Icons.check_circle, color: balance > 0 ? Colors.orange : Colors.green),
              const SizedBox(width: 8),
              Text(
                balance > 0 ? 'Process Payment' : 'Payment Successful',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: _paymentMethods.map((e) => e.toLowerCase())
           .contains(paymentMethod)
            ? paymentMethod
            : null,
            dropdownColor: const Color(0xFF1E3A5A),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Payment Method',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: const Icon(Icons.payment, color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF1E3A5A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _paymentMethods.map((method) {
              return DropdownMenuItem(
                value: method,
                child: Row(
                  children: [
                    Icon(
                      _getPaymentMethodIcon(method),
                      color: _getPaymentMethodColor(method),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(method, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              );
            }).toList(),
              onChanged: (value) {
                if (value != null && value.isNotEmpty) {
                  final methodKey = value.toLowerCase();

                  setState(() {
                    paymentMethod = methodKey;
                    provider.selectedPaymentMethods[invoiceId] = methodKey;
                    if (value.toLowerCase() == 'momo') {
                      provider.selectedNetworks[invoiceId] = 'mtn';
                    } else {
                      provider.selectedNetworks[invoiceId] = null;
                    }
                    if (methodKey != 'momo') {
                      provider.selectedNetworks[invoiceId] = null;
                    }

                    if (methodKey != 'card') {
                      provider.selectedCardTypes[invoiceId] = null;
                    }
                  });
                }
              }
              ),

          const SizedBox(height: 16),

          if (paymentMethod.toLowerCase() == 'momo') ...[
            DropdownButtonFormField<String>(
              value: selectedNetwork,
              dropdownColor: const Color(0xFF1E3A5A),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Select Network',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.sim_card, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E3A5A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: momoNetworks.map((network) {
                return DropdownMenuItem(
                  value: network.toLowerCase(),
                  child: Row(
                    children: [
                      Icon(
                        _getNetworkIcon(network),
                        color: _getNetworkColor(network),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(network, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    provider.selectedNetworks[invoiceId] = value;
                  });
                }
              },
              validator: (value) {
                if (paymentMethod.toLowerCase() == 'momo' && value == null) {
                  return 'Please select a network';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: accountNumberController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Mobile Money Number',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintText: 'e.g. 055XXXXXXX',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.phone_android, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E3A5A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (paymentMethod.toLowerCase() == 'momo' && (value == null || value.isEmpty)) {
                  return 'Please enter mobile money number';
                }
                if (value != null && value.isNotEmpty && !RegExp(r'^0\d{9}$').hasMatch(value)) {
                  return 'Enter a valid 10-digit number starting with 0';
                }
                return null;
              },
            ),
          ],

          if (paymentMethod.toLowerCase() == 'bank_transfer' || paymentMethod.toLowerCase() == 'cheque') ...[
              TextFormField(
                controller: referenceController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Reference Number',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintText: 'Enter Reference Number',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixIcon: const Icon(Icons.receipt, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E3A5A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (paymentMethod.toLowerCase() == 'cheque' && (value == null || value.isEmpty)) {
                    return 'Please enter reference number';
                  }
                  return null;
                },
              ),

          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Amount', style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).round()), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('GHS ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (amountPaid > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Already Paid', style: TextStyle(color: Colors.green.withAlpha((0.6 * 255).round()), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('GHS ${amountPaid.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade300, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (balance > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha((0.3 * 255).round())),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance Due:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  Text('GHS ${balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          const SizedBox(height: 16),

          if (paymentStatus != 'paid')
            TextFormField(
              enabled: transmode != 'credit',
              controller: amountPaidController,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (value) {
                final entered = double.tryParse(value) ?? 0.0;
                setState(() {
                  currentChange = entered - totalAmount;
                  provider.changeAmounts[invoiceId] = currentChange;
                });
              },
              validator: (value) {
                final number = double.tryParse(value!);

                if (value == null || value.isEmpty) {
                  return 'Enter amount paid';
                }

                if (number == null) {
                  return 'Enter a valid number';
                }

                if (number < 0.5) {
                  return 'Value must be greater than or equal to 0.5';
                }

                if (number < totalAmount && paymentMethod=='cash') {
                  return 'Amount paid cannot be less than $totalAmount';
                }

                return null;
              },
              decoration: InputDecoration(
                labelText: 'Amount Paid',
                labelStyle: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                ),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E3A5A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

          //const SizedBox(height: 12),
          if (currentChange > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha((0.3 * 255).round())),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance Due:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  Text('GHS ${currentChange.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          const SizedBox(height: 12),

          if (paymentMethod == 'cash' && (provider.changeAmounts[invoiceId] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withAlpha((0.3 * 255).round())),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Text('GHS ${(provider.changeAmounts[invoiceId] ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          if (paymentStatus != 'paid')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: provider.isLoadingpayment
                    ? null
                    : ()async {
                  if (_cashierFormKey.currentState!.validate()) {
                    if (paymentMethod.toLowerCase() == 'momo' && selectedNetwork == null) {

                      _showErrorSnackBar('Please select a mobile money network');
                      return;
                    }

                    final newamountPaid = double.tryParse(amountPaidController!.text) ?? totalAmount;
                    final totalamountPaid = newamountPaid + amountPaid;
                    final balance = totalAmount - totalamountPaid;
                    final change = totalamountPaid-totalAmount;
                    final accountNumber=accountNumberController?.text.toString().trim();
                    final reference=referenceController.text.toString().trim();
                    final paymentStatus = 'paid';

                    final  Map<String, Map<String, dynamic>>paymentMethodConfig = {
                      'cash': {
                        'accountNumber': 'cash',
                        'amountPaid': totalAmount,
                      },
                      'momo': {
                        'accountName': selectedNetwork,
                        'status': false,
                      },
                      'bank_transfer': {
                        'accountNumber': reference,
                      },
                      'cheque': {
                        'accountNumber': reference,
                      },
                      'card': {
                        'accountNumber': paymentMethod,
                      },
                    };

                    final config = paymentMethodConfig[paymentMethod] ?? {};

                    final paymentData =PaymentMethodModel(id: invoiceId, amount:config['amountPaid']?? newamountPaid,totalamount:totalAmount, paymentmethod:paymentMethod, accountName:config['accountName'] ?? paymentMethod, accountNumber: config['accountNumber'] ?? accountNumber, status: config['status'] ?? true,change:change,balance: balance,reference: reference);

                    try {
                      final res = await provider.processPayment(paymentData);
                      final change = res['change'] as double? ?? 0.0;

                      if (change > 0) {
                        _showSuccessSnackBar('Payment processed successfully. Change: GHS ${change.toStringAsFixed(2)}');
                      } else {
                        _showSuccessSnackBar('Payment processed successfully');
                      }
                      referenceController.clear();
                      amountPaidController!.clear();
                      accountNumberController?.clear();

                    } catch (e) {
                      _showErrorSnackBar('Failed to process payment: $e');
                    }

                  }
                },
                icon: provider.isLoadingpayment
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.payment),
                label: Text(
                  provider.isLoadingpayment ? 'Processing...' : 'Process Payment',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'momo':
        return Icons.phone_android;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'cheque':
        return Icons.receipt;
      case 'credit':
        return Icons.credit_score;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'momo':
        return Colors.orange;
      case 'bank_transfer':
        return Colors.purple;
      case 'cheque':
        return Colors.teal;
      case 'credit':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getNetworkIcon(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return Icons.network_cell;
      case 'vodafone':
        return Icons.signal_cellular_alt;
      case 'airteltigo':
        return Icons.wifi;
      case 'telecel':
        return Icons.phone_android;
      default:
        return Icons.sim_card;
    }
  }

  Color _getNetworkColor(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return const Color(0xFFFFCC00); // MTN Yellow
      case 'vodafone':
        return const Color(0xFFE60000); // Vodafone Red
      case 'airteltigo':
        return const Color(0xFFED1C24); // AirtelTigo Red
      case 'telecel':
        return const Color(0xFF662D91); // Telecel Purple
      default:
        return Colors.grey;
    }
  }

  Widget _buildSummarySection() {
    final provider=Provider.of<CashierProvider>(context,listen: false);

    final invoice = provider.selectedInvoice!;
    final totalAmount = (invoice.totalamount as num?)?.toDouble() ?? 0;
    final amountPaid = (invoice.amountPaid as num?)?.toDouble() ?? 0;
    final balance = totalAmount - amountPaid;
    final itemCount = invoice.itemCount ?? 0;
    final createdAt = (invoice.createdAt as Timestamp?)?.toDate();
    final printedAt = (invoice.printedat as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2A3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildSummaryRow('Items', itemCount.toString()),
          _buildSummaryRow('Total Amount', 'GHS ${totalAmount.toStringAsFixed(2)}'),
          if (amountPaid > 0)
            _buildSummaryRow('Amount Paid', 'GHS ${amountPaid.toStringAsFixed(2)}', color: Colors.green),
          if (balance > 0)
            _buildSummaryRow('Balance', 'GHS ${balance.toStringAsFixed(2)}', color: Colors.orange),

          const Divider(color: Colors.white24, height: 24),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final provider=Provider.of<CashierProvider>(context,listen: true);

    final invoiceId = provider.selectedInvoiceId;
    final paymentStatus = provider.selectedInvoice!.paymentStatus;
    bool printed = provider.selectedInvoice!.printed;
    final transmode = provider.selectedInvoice!.transMode;


    if (paymentStatus != 'pending' || transmode=='credit') {
      return SizedBox(
        width: 150,
        child: OutlinedButton(
          onPressed: provider.isLoadingpayment
              ? null
              : () async {
            try {
              if (printed) {
                _showErrorSnackBar('Invoice printed already');
                return;
              }

              await provider.printReceipt(
                  invoiceId!, provider.selectedInvoice!);

              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PrintPreviewWidget(
                    invoiceData: provider.selectedInvoice!,
                    showPrintButton: true,
                  ),
                ),
              );
            } catch (e) {
              _showErrorSnackBar('Error generating PDF: $e');
            }
          },

          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.lightBlue),
            foregroundColor: Colors.lightBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          child: provider.isLoadingpayment
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.lightBlue,
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.print),
              SizedBox(width: 8),
              Text('PRINT'),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMobileDetailsTab() {
    final provider=Provider.of<CashierProvider>(context,listen: false);
    final invoice = provider.selectedInvoice!;
    final totalAmount = (invoice.totalamount as num?)?.toDouble() ?? 0;
    final amountPaid = (invoice.amountPaid as num?)?.toDouble() ?? 0;
    final balance = totalAmount - amountPaid;
    final createdAt = (invoice.createdAt as Timestamp?)?.toDate();
    final printedAt = (invoice.printedat as Timestamp?)?.toDate();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2A3C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                _buildDetailRow('Receipt Number', invoice.receiptNumber ?? 'N/A'),
                _buildDetailRow('Customer', _getCustomerName(invoice)),
                _buildDetailRow('Date', createdAt != null ? _dateFormat.format(createdAt) : 'N/A'),
                _buildDetailRow('Time', createdAt != null ? _timeFormat.format(createdAt) : 'N/A'),
                _buildDetailRow('Payment Mode', invoice.transMode),
                _buildDetailRow('Cashier', invoice.createdBy!),
                if (printedAt != null)
                  _buildDetailRow('Printed', _dateTimeFormat.format(printedAt)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2A3C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                _buildAmountRow('Total Amount', totalAmount),
                if (amountPaid > 0)
                  _buildAmountRow('Amount Paid', amountPaid, color: Colors.green),
                if (balance > 0)
                  _buildAmountRow('Balance', balance, color: Colors.orange),
                if (amountPaid > 0) ...[
                  const Divider(color: Colors.white24, height: 24),
                  _buildAmountRow('Items', invoice.itemCount as double, isNumber: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePaymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildPaymentSection(),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {Color? color, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Text(
            isNumber ? amount.toStringAsFixed(0) : 'GHS ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 14,
              fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 13,
              fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'paid':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'PAID';
        break;
      case 'credit':
        color = Colors.orange;
        icon = Icons.pending;
        text = 'Credit';
        break;
      default:
        color = Colors.grey;
        icon = Icons.schedule;
        text = 'PENDING';
    }

    // Use withAlpha to avoid deprecated withOpacity calls
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.2 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Container(
        color: const Color(0xFF0F1E2E),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_outlined,
                  size: 64,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Invoice Selected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select an invoice from the list to process payment',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetSelection() {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    provider.resetSelection();
    setState(() {
      _showInvoiceList = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _isMobileView = screenWidth < 900;
    final provider=Provider.of<CashierProvider>(context,listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D2A3C),
        title: _isMobileView
            ? const Text(
          'Cashier',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )
            : Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade800.withAlpha((0.3 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.point_of_sale, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cashier',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Process payments and print receipts',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: _buildAppBarActions(),
        bottom: _isMobileView && provider.selectedInvoice != null && !_showInvoiceList
            ? TabBar(
          controller: _tabController,
          indicatorColor: Colors.green,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Payment'),

          ],
        )
            : null,
      ),
      body:Form(
        key: _cashierFormKey,
        child: _isMobileView ? _buildMobileLayout() : _buildDesktopLayout(),
      )

    );
  }

  List<Widget> _buildAppBarActions() {
    final provider=Provider.of<CashierProvider>(context,listen: false);
    final actions = <Widget>[];

    if (provider.selectedInvoice != null && _isMobileView) {
      actions.add(IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white70),
        ),
        onPressed: _resetSelection,
        tooltip: 'Back to invoices',
      ));
    }
    if(provider.accesslevel!='cashier')
    actions.add( IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isDateRangeActive
              ? Colors.blue.shade800.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.calendar_month,
          color: _isDateRangeActive ? Colors.blue.shade300 : Colors.white70,
        ),
      ),
      onPressed: _showDateRangePicker,
      tooltip: 'Filter by date range',
    ),);
    if (provider.selectedInvoice != null && !_isMobileView) {
      actions.add(IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close, color: Colors.white70),
        ),
        onPressed: _resetSelection,
        tooltip: 'Close',
      ));
    }

    if (_isMobileView && _showInvoiceList) {
      actions.add(IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.filter_list, color: Colors.white70),
        ),
        onPressed: _showFilterModal,
        tooltip: 'Filter',
      ));
    }

    actions.add(IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.refresh, color: Colors.white70),
      ),
      onPressed: () => Provider.of<CashierProvider>(context, listen: false).listenToInvoices(context),
      tooltip: 'Refresh',
    ));

    actions.add(const SizedBox(width: 8));
actions.add(PopupMenuButton<String>(
  onSelected: (selectedValue) {
    if (selectedValue == 'logout') {
      LogoutDialog.show(context, );
    } else if (selectedValue == 'password') {
      ChangePasswordDialog.changePassword(context,);
    } else if (selectedValue == 'profile') {
      Navigator.pushNamed(context, Routes.staffprofile);
    }
  },
  itemBuilder: (BuildContext context) => [
    PopupMenuItem<String>(
      value: 'profile',
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 20, color: Colors.green),
          SizedBox(width: 12),
          Text('My Profile'),
        ],
      ),
    ),
    PopupMenuItem<String>(
      value: 'password',
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 20, color: Colors.blue),
          SizedBox(width: 12),
          Text('Change Password'),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'logout',
      child: Row(
        children: const [
          Icon(Icons.logout, size: 20, color: Colors.red),
          SizedBox(width: 8),
          Text('Logout'),
        ],
      ),
    ),
  ],
));
    return actions;
  }
}

