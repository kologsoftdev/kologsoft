
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/screens/supplyinvoice.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../providers/StockProvider.dart';



class StockSupply extends StatefulWidget {
  final String? requestId;
  final Map<String, dynamic>? requestData;
  final String? selectedRequestStatus;

  const StockSupply({
    super.key,
    this.requestId,
    this.requestData,
    this.selectedRequestStatus,
  });

  @override
  State<StockSupply> createState() => _StockSupplyState();
}

class _StockSupplyState extends State<StockSupply> with SingleTickerProviderStateMixin {
  String _searchQuery = '';

  // Supply Tracking
  final TextEditingController _notesController = TextEditingController();
  Map<String, TextEditingController> _supcontrollers = {};
  final GlobalKey<FormState> _supplyFormKey = GlobalKey<FormState>();

  // UI State
  String _selectedFilter = 'Pending';
  final List<String> _filters = ['All', 'Pending','Partial', 'Complete'];

  // Mobile State
  bool _isMobileView = false;
  bool _showRequestList = true;
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeActive = false;
  @override

  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stock = Provider.of<StockProvider>(context, listen: false);
      stock.subscribePendingRequests();
      _notesController.addListener(() {
        stock.notes = _notesController.text;
      });


      if (widget.requestId != null && widget.requestData != null) {
        stock.selectRequest(widget.requestId!, widget.requestData!, widget.selectedRequestStatus ?? 'pending');
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tabController.dispose();
    for (final controller in _supcontrollers.values) { controller.dispose(); }
    super.dispose();
  }

  void _selectRequest(String id, Map<String, dynamic> request, String requeststatus) {
    final stock = Provider.of<StockProvider>(context, listen: false);
    stock.selectRequest(id, request, requeststatus);
    setState(() {
      if (_isMobileView) {
        _showRequestList = false;
      }
    });
  }

//  date range picker
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

        // Apply date filter to your requests
        if (_startDate == null || _endDate == null) return;
        final stock = Provider.of<StockProvider>(context, listen: false);
        stock.subscribePendingRequests(startDate:_startDate ,endDate:_endDate);
        // Show date range badge
        _showDateRangeBadge();
      }
    }
  }

// clear the date range
  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeActive = false;
    });

    // Reload all pending requests without date filter
    final stock = Provider.of<StockProvider>(context, listen: false);
    stock.subscribePendingRequests();

    // Show confirmation
    _showSuccessSnackBar('Date filters cleared');
  }

// show a date range badge
  void _showDateRangeBadge() {
    if (_startDate == null || _endDate == null) return;

    final dateFormat = DateFormat('dd MMM yyyy');
    final message = 'Showing: ${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}';

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

  Future<void> _submitSupply() async {
    if (_supplyFormKey.currentState!.validate()) {
      final stock = Provider.of<StockProvider>(context, listen: false);

      if (stock.isLoading) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) =>
            AlertDialog(
              title: const Text('Confirm Save'),
              content: const Text(
                'Are you sure you want to save this supply record?\n'
                    'Once saved, records cannot be changed.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Save'),
                ),
              ],
            ),
      );

      if (confirm != true) return;


      try {
        await stock.submitSupply();

        if (mounted) {
          _showSuccessSnackBar("Supply record saved successfully");
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar("Error saving supply record: $e");
        }
      } finally {}
    }
  }

  void _resetSupply() {
    Provider.of<StockProvider>(context, listen: false).resetSupply();
    setState(() {
      _notesController.clear();
      if (_isMobileView) {
        _showRequestList = true;
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final stock = Provider.of<StockProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    _isMobileView = screenWidth < 900;

    return Scaffold(
        backgroundColor: const Color(0xFF0A1A2F),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0D2A3C),
          title: _isMobileView
              ? const Text(
            'Stock Supply',
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
                  color: Colors.blue.shade800.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock Supply',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Fulfill warehouse requests',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: _buildAppBarActions(),
          bottom: _isMobileView && stock.selectedRequest != null && !_showRequestList
              ? TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Items'),
              Tab(text: 'Details'),
            ],
          )
              : null,
        ),
        body: Form(
          key: _supplyFormKey,
          child: _isMobileView ? _buildMobileLayout() : _buildDesktopLayout(),
        )

    );
  }

  List<Widget> _buildAppBarActions() {
    final stock = Provider.of<StockProvider>(context);
    final actions = <Widget>[
      if (stock.selectedRequest != null && _isMobileView)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white70),
          ),
          onPressed: _resetSupply,
          tooltip: 'Back to requests',
        ),
      if (stock.selectedRequest != null && !_isMobileView)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close, color: Colors.white70),
          ),
          onPressed: _resetSupply,
          tooltip: 'Cancel supply',
        ),
      // Date Range Picker Button
      IconButton(
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
      ),
      if (_isMobileView && _showRequestList)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh, color: Colors.white70),
          ),
          onPressed: stock.subscribePendingRequests,
          tooltip: 'Refresh',
        ),
      const SizedBox(width: 8),
    ];

    return actions;
  }

  Widget _buildDesktopLayout() {
    final stock = Provider.of<StockProvider>(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel - Requests List
        _buildRequestsPanel(),

        // Right Panel - Supply Fulfillment
        if (stock.selectedRequest != null)
          _buildSupplyPanel()
        else
          Expanded(child: _buildEmptyState(),)
      ],
    );
  }

  Widget _buildMobileLayout() {
    final stock = Provider.of<StockProvider>(context);

    if (stock.isLoading && stock.pendingRequests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (stock.selectedRequest != null && !_showRequestList) {
      return _buildMobileSupplyPanel();
    }
    return _buildRequestsPanel();
  }

  Widget _buildMobileSupplyPanel() {
    final stock = Provider.of<StockProvider>(context);
    final items = stock.selectedRequest!['items'] as List;
    double? dbsupplyPercentage = double.tryParse(stock.selectedRequest!['supplypercentage']?.toString() ?? '0');
    final supplyPercentage = (stock.calculateSupplyPercentage() > 0 ? stock.calculateSupplyPercentage() : dbsupplyPercentage)!;

    return Column(
      children: [
        // Request Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF102433),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (supplyPercentage > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Supply Progress',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: supplyPercentage / 100,
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      valueColor: AlwaysStoppedAnimation(
                                        supplyPercentage == 100
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${supplyPercentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: supplyPercentage == 100
                                        ? Colors.green.shade300
                                        : Colors.blue.shade300,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
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
              ],
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Items Tab

              _buildMobileItemsTab(items),

              // Details Tab
              _buildMobileDetailsTab(),
            ],
          ),
        ),

        // Submit Button (Fixed at bottom)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2A3C),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetSupply,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (stock.selectedRequestStatus=='pending')
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: stock.isLoading ? null :()async{
                        try{
                          await _submitSupply();
                        } catch (e) {
                          _showErrorSnackBar('Error submitting supply: $e');
                        }

                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: supplyPercentage == 100
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: stock.isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Text(
                        (supplyPercentage == 100 ? 'Complete Supply ' : 'Partial Supply'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                if (stock.selectedRequestStatus!='pending')
                  SizedBox(
                    width: 150,
                    child: OutlinedButton.icon(
                      onPressed: ()async {
                        try {
                          await generateInvoicePdf(stock.selectedRequest!);
                        } catch (e) {
                          _showErrorSnackBar('Error generating PDF: $e');

                        }
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('PRINT'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.lightBlue),
                        foregroundColor: Colors.lightBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileItemsTab(List items) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stock = Provider.of<StockProvider>(context);
        final item = items[index];
        final itemId = item['itemid'] ?? '';
        final dbstatus=item['supplystatus'];
        final requestedQty = (item['requestedquantity'] as num?)?.toDouble() ?? 0;
        final previousSupply = (item['suppliedquantity'] as num?)?.toDouble() ?? 0;
        final suppliedData = stock.supplyItems?[itemId];
        final rawsupply = suppliedData?['supplied'];
        final status = suppliedData?['status'] ?? item['supplystatus'];
        final controllerid="${stock.selectedRequestId}${itemId}";
        double suppliedQty;
        if (dbstatus == 'pending') {
          suppliedQty = rawsupply ?? requestedQty;
        } else {
          suppliedQty = previousSupply;
        }
        _supcontrollers[controllerid] ??= TextEditingController( text: suppliedQty.toStringAsFixed(0) );

        return Container (
            decoration: BoxDecoration(
              color: const Color(0xFF0D2A3C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['item'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item['barcode'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Barcode: ${item['barcode']}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade900.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item['mode'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const Divider(
                    color: Colors.white24,
                    height: 24,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Requested Quantity',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              requestedQty.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supply Quantity',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E3A5A),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: suppliedQty > 0
                                              ? Colors.blue.shade400
                                              : Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                      child: buildSupplyField(

                                          controller: _supcontrollers[controllerid]!,
                                          requestedQty: requestedQty,
                                          suppliedQty: suppliedQty,
                                          itemId: itemId,
                                          onUpdate: (String itemId, double requestedQty, double suppliedQty) {
                                            stock.updateSupplyQuantity(itemId, requestedQty, suppliedQty);
                                          },dbstatus:dbstatus)

                                  ),
                                ),

                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),)
        );
      },
    );
  }

  Widget _buildMobileDetailsTab() {
    final stock = Provider.of<StockProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Supply Information
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Supply Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    hintText: 'Add any additional notes...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                    ),
                    prefixIcon: const Icon(
                      Icons.note,
                      color: Colors.white70,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E3A5A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Request Summary
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.summarize, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Request Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  'Warehouse',
                  stock.selectedRequest!['warehousename'] ?? '',
                  Icons.store,
                ),
                _buildInfoRow(
                  'Branch',
                  stock.selectedRequest!['branch'] ?? '',
                  Icons.business,
                ),
                _buildInfoRow(
                  'Request Date',
                  _formatDate(
                    (stock.selectedRequest!['createdat'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  ),
                  Icons.calendar_today,
                ),
                _buildInfoRow(
                  'Total Items',
                  '${stock.selectedRequest!['items']?.length ?? 0} items',
                  Icons.inventory,
                ),

              ],
            ),
          ),

          const SizedBox(height: 16),

          // Supply Summary
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Supply Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  'Items Supplied',
                  '${stock.supplyItems.length} of ${stock.selectedRequest!['items']?.length ?? 0}',
                  Icons.check_circle,
                  valueColor: Colors.green,
                ),
                _buildInfoRow(
                  'Supply Progress',
                  '${stock.calculateSupplyPercentage().toStringAsFixed(0)}%',
                  Icons.pie_chart,
                  valueColor: stock.calculateSupplyPercentage() == 100
                      ? Colors.green
                      : Colors.blue,
                ),
                _buildInfoRow(
                  'Status',
                  stock.selectedRequestStatus!.toUpperCase(),
                  _getStatusIcon(stock.selectedRequestStatus!),
                  valueColor: _getStatusColor(stock.selectedRequestStatus!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {
    Color? valueColor,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? (highlight ? Colors.blue.shade300 : Colors.white),
              fontSize: 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSupplyField({
    required TextEditingController controller,
    required double requestedQty,
    required double suppliedQty,
    required String itemId,
    required String dbstatus,
    required void Function(String itemId, double requestedQty, double safeQty) onUpdate,
  }) {
    return TextFormField(
      enabled: dbstatus=='pending',
      controller: controller,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
        MaxValueInputFormatter(requestedQty),
      ],
      validator: (value) {
        final qty = double.tryParse(value ?? '0');
        if (qty == null) return 'Enter a valid number';
        if (qty < 0) return 'Quantity cannot be negative';
        if (qty > requestedQty) {
          return 'Cannot exceed requested quantity of ($requestedQty)';
        }
        return null;
      },
      onChanged: (value) {
        final qty = double.tryParse(value) ?? suppliedQty;
        final safeQty = (qty.clamp(0, requestedQty)).toDouble();
        onUpdate(itemId, requestedQty, safeQty);
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1E3A5A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        errorStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
      ),
    );
  }

  Widget _buildRequestsPanel() {
    final stock = context.watch<StockProvider>();

    final filteredRequests = stock.pendingRequests.where((request) {
      if (_selectedFilter != 'All' && request['status'] != _selectedFilter.toLowerCase()) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final warehouse = (request['warehousename'] ?? '').toString().toLowerCase();
        final branch = (request['branch'] ?? '').toString().toLowerCase();
        final stats = (request['status'] ?? '').toString().toLowerCase();

        return warehouse.contains(query) || branch.contains(query) || stats.contains(query);
      }

      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final bool isMobile = width < 700;
        final bool isTablet = width >= 700 && width < 1100;
        final bool isDesktop = width >= 1100;

        final panelWidth = isDesktop
            ? 380.0
            : double.infinity;

        return Container(
          width: panelWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF102433),
            border: isDesktop
                ? Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            )
                : null,
          ),
          child: Column(
            children: [
              // 🔹 Header + Search + Filters
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Count
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pending Requests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900,
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${filteredRequests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 🔎 Search
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      style:
                      const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search requests...',
                        hintStyle: TextStyle(
                          color:
                          Colors.white.withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.white70,
                          ),
                          onPressed: () =>
                              setState(() =>
                              _searchQuery = ''),
                        )
                            : null,
                        filled: true,
                        fillColor:
                        const Color(0xFF1E3A5A),
                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 🏷 Filters (Responsive Wrap)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filters.map((filter) {
                        final isSelected =
                            _selectedFilter == filter;

                        return FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() =>
                            _selectedFilter = filter);
                          },
                          backgroundColor:
                          const Color(0xFF1E3A5A),
                          selectedColor:
                          Colors.blue.shade800,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 12,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(8),
                            side: BorderSide.none,
                          ),
                        );

                      }).toList(),
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
              // 📋 List
              Flexible(
                child: filteredRequests.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                  padding:
                  const EdgeInsets.all(16),
                  itemCount: filteredRequests.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final request =
                    filteredRequests[index];
                    final isSelected = stock.selectedRequestId == request['id'];

                    return _buildRequestCard(request, isSelected,);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isSelected) {
    final items = request['items'] as List? ?? [];
    final totalItems = items.length;
    final supplyStatus = request['status'] ?? 'pending';
    final date = (request['createdat'] as Timestamp?)?.toDate() ?? DateTime.now();

    Color getStatusColor() {
      switch (supplyStatus) {
        case 'complete':
          return Colors.green;
        case 'partial':
          return Colors.orange;
        case 'processing':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    return GestureDetector(
      onTap: () => _selectRequest(request['id'], request, supplyStatus),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade800.withOpacity(0.3),
              Colors.blue.shade900.withOpacity(0.3),
            ],
          )
              : null,
          color: isSelected ? null : const Color(0xFF0D2A3C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.blue.shade400
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(supplyStatus),
                      color: getStatusColor(),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['warehousename'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${request['branch'] ?? 'Branch'} • ${_formatDate(date)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
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
                      supplyStatus.toUpperCase(),
                      style: TextStyle(
                        color: getStatusColor(),
                        fontSize: 10,
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
                  Text(
                    '$totalItems items',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'GHS ${(request['gross'] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (supplyStatus == 'partial' && request['supplyPercentage'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Supply Progress',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${request['supplyPercentage']?.toStringAsFixed(0) ?? 0}%',
                            style: TextStyle(
                              color: Colors.orange.shade300,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (request['supplyPercentage'] ?? 0) / 100,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(
                            getStatusColor(),
                          ),
                          minHeight: 4,
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

  Widget _buildSupplyPanel() {
    final stock = Provider.of<StockProvider>(context);
    final items = stock.selectedRequest!['items'] as List;
    double? dbsupplyPercentage = double.tryParse(stock.selectedRequest!['supplypercentage']?.toString() ?? '0');
    final supplyPercentage = (stock.calculateSupplyPercentage() > 0 ? stock.calculateSupplyPercentage() : dbsupplyPercentage)!;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade800.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.store,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    stock.selectedRequest!['warehousename'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.business,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    stock.selectedRequest!['branch'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (supplyPercentage > 0) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.shade700.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Overall Supply Progress',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: supplyPercentage / 100,
                                          backgroundColor: Colors.white.withOpacity(0.1),
                                          valueColor: AlwaysStoppedAnimation(
                                            supplyPercentage == 100
                                                ? Colors.green
                                                : Colors.blue,
                                          ),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${supplyPercentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: supplyPercentage == 100
                                            ? Colors.green.shade300
                                            : Colors.blue.shade300,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
                  ],
                ],
              ),
            ),

            // Items Table
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Items',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D2A3C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child:  Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5A),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Item',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Mode',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Requested',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Supply Quantity',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Table Body
                            ...items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final itemId = item['itemid'] ?? '';
                              final dbstatus = item['supplystatus'];
                              final requestedQty = (item['requestedquantity'] as num?)?.toDouble() ?? 0;
                              final previousSupply = (item['suppliedquantity'] as num?)?.toDouble() ?? 0;
                              final suppliedData = stock.supplyItems[itemId];
                              final rawsupply = suppliedData?['supplied'];
                              final status = suppliedData?['status'] ?? item['supplystatus'] ?? "no stock";
                              final controllerids="${stock.selectedRequestId}${itemId}";
                              double suppliedQty;
                              if (dbstatus == 'pending') {
                                suppliedQty = rawsupply ?? requestedQty;
                              } else {
                                suppliedQty = previousSupply;
                              }
                              _supcontrollers[controllerids] ??= TextEditingController( text: suppliedQty.toStringAsFixed(0) );

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: index < items.length - 1
                                      ? Border(
                                    bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['item'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (item['barcode'] != null)
                                            Text(
                                              'Barcode: ${item['barcode']}',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.5),
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade900.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          item['mode'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        requestedQty.toStringAsFixed(0),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Container(
                                              width: 100,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E3A5A),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: suppliedQty > 0
                                                      ? Colors.blue.shade400
                                                      : Colors.white.withOpacity(0.2),
                                                ),
                                              ),
                                              child: buildSupplyField(
                                                  controller: _supcontrollers[controllerids]!,
                                                  requestedQty: requestedQty,
                                                  suppliedQty: suppliedQty,
                                                  itemId: itemId,
                                                  onUpdate: (String itemId, double requestedQty, double suppliedQty) {
                                                    stock.updateSupplyQuantity(itemId, requestedQty, suppliedQty);
                                                  },dbstatus:dbstatus
                                              )

                                          ),

                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: _buildStatusBadge(status),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            // Footer
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5A).withOpacity(0.5),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.inventory,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${items.length} items',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                    ),

                    const SizedBox(height: 24),

                    // Additional Information
                    Container(
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
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Notes',
                              labelStyle: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                              ),
                              hintText: 'Add any additional notes...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                              ),
                              prefixIcon: const Icon(
                                Icons.note,
                                color: Colors.white70,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1E3A5A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2A3C),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _resetSupply,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (stock.selectedRequestStatus=='pending')

                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: stock.isLoading ? null :()async{
                          try{
                            await _submitSupply();
                          } catch (e) {
                            _showErrorSnackBar('Error submitting supply: $e');
                          }

                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: supplyPercentage == 100
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: stock.isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          (supplyPercentage == 100 ? 'Complete Supply ' : 'Partial Supply'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (stock.selectedRequestStatus!='pending')
                    SizedBox(
                      width: 150,
                      child: OutlinedButton.icon(
                        onPressed: ()async {
                          try {
                            await generateInvoicePdf(stock.selectedRequest!);
                          } catch (e) {
                            _showErrorSnackBar('Error generating PDF: $e');

                          }
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('PRINT'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.lightBlue),
                          foregroundColor: Colors.lightBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
        color: const Color(0xFF0F1E2E),
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
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.white24,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Request Selected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a request from the left panel to start supplying',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        )
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'partial':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'no stock':
        color = Colors.redAccent;
        icon = Icons.remove_circle;
        break;
      default:
        color = Colors.grey;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.toLowerCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'complete':
        return Icons.check_circle;
      case 'partial':
        return Icons.pending;
      case 'processing':
        return Icons.inventory;
      default:
        return Icons.schedule;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class MaxValueInputFormatter extends TextInputFormatter {
  final double maxValue;

  MaxValueInputFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text;
    final value = double.tryParse(text);

    if (value != null && value > maxValue) {
      return oldValue;
    }
    return newValue;
  }
}
