import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../providers/Datafeed.dart';
import 'dart:async';

class StockReceiving extends StatefulWidget {
  final String? transferId;
  final Map<String, dynamic>? transferData;

  const StockReceiving({
    super.key,
    this.transferId,
    this.transferData,
  });

  @override
  State<StockReceiving> createState() => _StockReceivingState();
}

class _StockReceivingState extends State<StockReceiving> with SingleTickerProviderStateMixin {
  // Core Data
  List<Map<String, dynamic>> _pendingTransfers = [];
  Map<String, dynamic>? _selectedTransfer;
  String? _selectedTransferId;
  bool _isLoading = false;
  String _searchQuery = '';

  // Receiving Tracking
  final Map<String, Map<String, dynamic>> _receivedItems = {};
  String? _activeReceiptId;
  Map<String, dynamic>? _activeReceipt;
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _receivedByController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // UI State
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Pending', 'Partial', 'Completed', 'Discrepant'];
  late TabController _tabController;
  bool _isMobileView = false;
  bool _showTransferList = true;
  DateTime? _selectedDate;

  // Date Formatting
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingTransfers();
      if (widget.transferId != null && widget.transferData != null) {
        _selectTransfer(widget.transferId!, widget.transferData!);
      }
    });
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    _receivedByController.dispose();
    _dateController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingTransfers() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<Datafeed>(context, listen: false);

      Query query = FirebaseFirestore.instance
          .collection('stock_transfer')
          .where('recievebranchid', isEqualTo: provider.branchid)
          .orderBy('createdat', descending: true);

      final snapshot = await query.get();

      setState(() {
        _pendingTransfers = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['status'] = data['status']??'pending';
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load transfers: $e');
    }
  }

  void _selectTransfer(String id, Map<String, dynamic> transfer) {
    setState(() {
      _selectedTransferId = id;
      _selectedTransfer = transfer;
      _activeReceiptId = 'RCPT-${DateTime.now().millisecondsSinceEpoch}';
      _activeReceipt = {
        'transferid': id,
        'transferref': transfer['transferid'] ?? transfer['transactionid'],
        'sourcewarehouse': transfer['supplywarehousename'],
        'sourcewarehouseId': transfer['supplywarehouseid'],
        'destinationbranch': transfer['recievebranchname'],
        'destinationbranchId': transfer['recievebranchid'],
        'transferdate': transfer['transferdate'],
        'createdby': transfer['createdby'],
        'receiptdate': Timestamp.fromDate(DateTime.now()),
        'items': [],
        'status': 'processing',
        'receivingstatus': 'partial',
        'reference': _referenceController.text,
        'notes': _notesController.text,
      };

      // Initialize received items from transfer
      final items = transfer['items'] as List? ?? [];
      for (var item in items) {
        final transferredQty = (item['quantity'] as num?)?.toDouble() ?? 0;
        if (transferredQty > 0) {
          _receivedItems[item['itemid']] = {
            'expected': transferredQty,
            'received': 0,
            'status': 'pending',
            'condition': 'good',
            'remarks': '',
            'itemname': item['item'],
            'barcode': item['barcode'],
            'mode': item['transfermode'],
            'price': item['price'],
            'pieces': item['pieces'],
          };
        }

      }

      // Set default received by
      final provider = Provider.of<Datafeed>(context, listen: false);
      _receivedByController.text = provider.staff ?? '';

      // On mobile, hide transfer list and show receiving panel
      if (_isMobileView) {
        _showTransferList = false;
      }
    });
  }

  void _updateItemCondition(String itemId, String condition) {
    setState(() {
      if (_receivedItems.containsKey(itemId)) {
        _receivedItems[itemId] = {
          ..._receivedItems[itemId]!,
          'condition': condition,
        };
      }
    });
  }

  void _updateItemRemarks(String itemId, String remarks) {
    setState(() {
      if (_receivedItems.containsKey(itemId)) {
        _receivedItems[itemId] = {
          ..._receivedItems[itemId]!,
          'remarks': remarks,
        };
      }
    });
  }

  double _calculateReceivingPercentage() {
    if (_selectedTransfer == null) return 0;
    final items = _selectedTransfer!['items'] as List;
    if (items.isEmpty) return 0;

    int totalItems = items.length;

    int receivedItems = _receivedItems.values
        .where((item) => ((item['received'] ?? 0) as num) > 0)
        .length;

    int alreadyReceivedItems = items
        .where((item) => ((item['receivedquantity'] ?? 0) as num) > 0)
        .length;

    //  old + new
    int effectiveReceivedItems = receivedItems + alreadyReceivedItems;

    if (totalItems == 0) return 0;
    return (effectiveReceivedItems / totalItems * 100).clamp(0, 100);
  }

  double _calculateQuantityPercentage() {
    if (_selectedTransfer == null) return 0;
    final items = _selectedTransfer!['items'] as List;
    if (items.isEmpty) return 0;

    double totalExpected = items.fold(0.0, (sum, item) =>
    sum + ((item['quantity'] as num?)?.toDouble() ?? 0.0));

    double alreadyReceived = items.fold(0.0, (sum, item) =>
    sum + ((item['receivedquantity'] as num?)?.toDouble() ?? 0.0));

    double newlyReceived = _receivedItems.values.fold(0.0, (sum, item) =>
    sum + ((item['received'] as num?)?.toDouble() ?? 0.0));

    double effectiveReceived = alreadyReceived + newlyReceived;

    if (totalExpected == 0) return 0;
    return (effectiveReceived / totalExpected * 100).clamp(0, 100);
  }

  String getReceivingStatus() {
    if (_selectedTransfer == null) return 'pending';

    bool hasPartial = false;
    bool allReceived = true;
    bool allOver = true;

    for (final item in _receivedItems.values) {
      final received = item['received'] ?? 0;
      final expected = item['expected'] ?? 0;

      if (received > expected) {
        allReceived = false;
      } else {
        allOver = false;
      }

      if (received > 0 && received < expected) {
        hasPartial = true;
        allReceived = false;
        allOver = false;
      }

      if (received < expected) {
        allReceived = false;
        allOver = false;
      }
    }

    if (allOver) return 'over';
    if (allReceived) return 'completed';
    if (hasPartial) return 'partial';

    return 'pending';
  }

  bool _validateReceiving() {
    if (_receivedItems.isEmpty) {
      _showErrorSnackBar('No items received');
      return false;
    }

    final hasReceived = _receivedItems.values.any((item) => (item['received'] ?? 0) > 0);

    if (!hasReceived!) {
      _showErrorSnackBar('Please enter received quantities');
      return false;
    }

    return true;
  }

  Future<void> _submitReceiving() async {
    if (!_validateReceiving()) return;

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<Datafeed>(context, listen: false);
      final receivingstatus = getReceivingStatus();

      // Prepare updated items with received quantities
      final updatedItems = (_selectedTransfer!['items'] as List).map((item) {
        final received = _receivedItems[item['itemid']];
        final alreadyreceived=item['receivedquantity'] ?? 0;
        final transferredQty=item['quantity'] ?? 0;
        final receivedQty = received?['received'] ?? 0;
        final modeQty = (item['modeqty'] as num?)?.toDouble() ?? 1.0;
        final receivedPieces = receivedQty * modeQty;
        double effectiveQty=0;
        effectiveQty = alreadyreceived > 0
            ? alreadyreceived
            : (receivedQty > 0 ? receivedQty :transferredQty );
        return {
          ...item,
          'receivedquantity': effectiveQty,
          'receivedpieces': receivedPieces,
          'receivingstatus': received?['status'] ?? 'pending',
          'condition': received?['condition'] ?? 'good',
          'remarks': received?['remarks'] ?? '',
          'staff': provider.staff,
          'receiptdate': Timestamp.fromDate(DateTime.now()),

        };
      }).toList();

      final batch = FirebaseFirestore.instance.batch();

      // Update transfer record with received quantities in items array
      final transferRef = FirebaseFirestore.instance
          .collection('stock_transfer')
          .doc(_selectedTransferId);

      batch.update(transferRef, {
        'items': updatedItems,
        'status': receivingstatus,
        'lastreceiptdate': Timestamp.fromDate(DateTime.now()),
      });


      await batch.commit();

      _showSuccessSnackBar('Stock received successfully');
      _resetReceiving();
      _loadPendingTransfers();
    } catch (e) {
      _showErrorSnackBar('Failed to submit receiving: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateReceivedQuantity(String itemId, double expectedQty, double receivedQty) {
    setState(() {
      if (_receivedItems.containsKey(itemId)) {


        final clampedQty = receivedQty>0?receivedQty.clamp(0, expectedQty * 2):expectedQty.clamp(0, expectedQty *2); // Allow up to double for over-receiving
        final status = clampedQty == 0
            ? 'pending'
            : clampedQty == expectedQty
            ? 'completed'
            : clampedQty > expectedQty
            ? 'over'
            : 'partial';

        // Get mode quantity from original item for pieces calculation
        final items = _selectedTransfer!['items'] as List;
        final originalItem = items.firstWhere(
              (item) => item['itemid'] == itemId,
          orElse: () => null,
        );

        final modeQty = (originalItem?['modeqty'] as num?)?.toDouble() ?? 1;
        final receivedPieces = clampedQty * modeQty;

        _receivedItems[itemId] = {
          ..._receivedItems[itemId]!,
          'received': clampedQty,
          'receivedPieces': receivedPieces,
          'status': status,
        };
      }
    });
  }

  double _calculateTotalReceivedPieces() {
    if (_selectedTransfer == null) return 0;

    double totalPieces = 0;
    _receivedItems.forEach((itemId, data) {
      totalPieces += (data['receivedPieces'] ?? 0);
    });

    return totalPieces;
  }

  void _resetReceiving() {
    setState(() {
      _selectedTransfer = null;
      _selectedTransferId = null;
      _activeReceipt = null;
      _activeReceiptId = null;
      _receivedItems.clear();
      _referenceController.clear();
      _notesController.clear();
      _receivedByController.clear();
      _dateController.clear();
      _selectedDate = null;

      // On mobile, show transfer list again
      if (_isMobileView) {
        _showTransferList = true;
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
              'Filter Transfers',
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
                  color: isSelected ? Colors.blue : Colors.white70,
                ),
                title: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
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

  void _showConditionSelector(String itemId, String currentCondition) {
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
              'Item Condition',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildConditionOption(
              'Good - Item in perfect condition',
              Icons.check_circle,
              Colors.green,
              itemId,
              currentCondition == 'good',
            ),
            _buildConditionOption(
              'Damaged - Physical damage',
              Icons.error,
              Colors.orange,
              itemId,
              currentCondition == 'damaged',
            ),
            _buildConditionOption(
              'Expired - Past expiry date',
              Icons.warning,
              Colors.red,
              itemId,
              currentCondition == 'expired',
            ),
            _buildConditionOption(
              'Wrong Item - Item mismatch',
              Icons.swap_horiz,
              Colors.purple,
              itemId,
              currentCondition == 'wrong',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionOption(String label, IconData icon, Color color, String itemId, bool isSelected) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: color) : null,
      onTap: () {
        _updateItemCondition(itemId, label.split(' ')[0].toLowerCase());
        Navigator.pop(context);
      },
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All': return Icons.list;
      case 'Pending': return Icons.schedule;
      case 'Partial': return Icons.pending;
      case 'Completed': return Icons.check_circle;
      case 'Discrepant': return Icons.warning;
      default: return Icons.filter_list;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'discrepant':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'partial':
        return Icons.pending;
      case 'discrepant':
        return Icons.warning;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _isMobileView = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D2A3C),
        title: _isMobileView
            ? const Text(
          'Stock Receiving',
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
                color: Colors.green.shade800.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock Receiving',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Confirm and receive transferred stock',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: _buildAppBarActions(),
        bottom: _isMobileView && _selectedTransfer != null && !_showTransferList
            ? TabBar(
          controller: _tabController,
          indicatorColor: Colors.green,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Items'),
            Tab(text: 'Inspection'),
            Tab(text: 'Summary'),
          ],
        )
            : null,
      ),
      body: _isMobileView ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[
      if (_selectedTransfer != null && _isMobileView)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white70),
          ),
          onPressed: _resetReceiving,
          tooltip: 'Back to transfers',
        ),
      if (_selectedTransfer != null && !_isMobileView)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close, color: Colors.white70),
          ),
          onPressed: _resetReceiving,
          tooltip: 'Cancel receiving',
        ),
      if (_isMobileView && _showTransferList)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.filter_list, color: Colors.white70),
          ),
          onPressed: _showFilterModal,
          tooltip: 'Filter',
        ),
      IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.refresh, color: Colors.white70),
        ),
        onPressed: _loadPendingTransfers,
        tooltip: 'Refresh',
      ),
      const SizedBox(width: 8),
    ];

    return actions;
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel - Transfers List
        _buildTransfersPanel(),

        // Right Panel - Receiving Form
        if (_selectedTransfer != null)
          _buildReceivingPanel()
        else
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_isLoading && _pendingTransfers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    // Show receiving panel when transfer is selected
    if (_selectedTransfer != null && !_showTransferList) {
      return _buildMobileReceivingPanel();
    }

    // Show transfers list
    return _buildMobileTransfersPanel();
  }

  Widget _buildTransfersPanel() {
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF102433),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Header
          Container(
            padding: const EdgeInsets.all(20),
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
                    const Text(
                      'Incoming Transfers',
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
                        color: Colors.green.shade900,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_pendingTransfers.length}',
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
                // Search
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search transfers...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
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
                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedFilter = filter.toLowerCase());
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

          // Transfers List
          Expanded(
            child: _pendingTransfers.isEmpty
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
                    child: const Icon(
                      Icons.inventory,
                      size: 48,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No incoming transfers',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New transfers will appear here',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingTransfers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final transfer = _pendingTransfers[index];
                final isSelected = _selectedTransferId == transfer['id'];
                return _buildTransferCard(transfer, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> transfer, bool isSelected) {
    final items = transfer['items'] as List? ?? [];
    final totalItems = items.length;
    final receivingStatus = transfer['status'] ?? 'pending';
    final transferDate = transfer['transferdate'] != null
        ? (transfer['transferdate'] as Timestamp).toDate()
        : (transfer['createdat'] as Timestamp?)?.toDate() ?? DateTime.now();

    return GestureDetector(
      onTap: () => _selectTransfer(transfer['id'], transfer),
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
                      color: _getStatusColor(receivingStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(receivingStatus),
                      color: _getStatusColor(receivingStatus),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer['supplywarehousename'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ref: ${transfer['docid']?.toString().substring(0, 10) ?? ''}',
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
                      color: _getStatusColor(receivingStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(receivingStatus).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      receivingStatus.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(receivingStatus),
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
                  Row(
                    children: [
                      Icon(
                        Icons.inventory,
                        size: 16,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalItems items',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _dateFormat.format(transferDate),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (transfer['createdby'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'From: ${transfer['createdby']}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
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

  Widget _buildMobileTransfersPanel() {
    final filteredTransfers = _pendingTransfers.where((transfer) {
      if (_selectedFilter != 'All' && transfer['status'] != _selectedFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final warehouse = (transfer['supplywarehousename'] ?? '').toString().toLowerCase();
        final ref = (transfer['docid'] ?? '').toString().toLowerCase();
        return warehouse.contains(query) || ref.contains(query);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF102433),
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
                  hintText: 'Search transfers...',
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
            ],
          ),
        ),

        // Transfers Count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF0D2A3C),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredTransfers.length} transfers found',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedFilter,
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Transfers List
        Expanded(
          child: filteredTransfers.isEmpty
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
                    _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox,
                    size: 48,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No matching transfers'
                      : 'No incoming transfers',
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
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredTransfers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final transfer = filteredTransfers[index];
              final isSelected = _selectedTransferId == transfer['id'];
              return _buildMobileTransferCard(transfer, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTransferCard(Map<String, dynamic> transfer, bool isSelected) {
    final items = transfer['items'] as List? ?? [];
    final totalItems = items.length;
    final receivingStatus = transfer['status'] ?? 'pending';
    final transferDate = transfer['transferdate'] != null
        ? (transfer['transferdate'] as Timestamp).toDate()
        : (transfer['createdat'] as Timestamp?)?.toDate() ?? DateTime.now();

    return GestureDetector(
      onTap: () => _selectTransfer(transfer['id'], transfer),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(receivingStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(receivingStatus),
                      color: _getStatusColor(receivingStatus),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer['supplywarehousename'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ref: ${transfer['docid']?.toString().substring(0, 8) ?? ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(
                    Icons.inventory,
                    '$totalItems items',
                    Colors.blue,
                  ),
                  _buildInfoChip(
                    Icons.person,
                    transfer['createdby'] ?? 'Unknown',
                    Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(
                    Icons.calendar_today,
                    _dateFormat.format(transferDate),
                    Colors.orange,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(receivingStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(receivingStatus).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(receivingStatus),
                          size: 14,
                          color: _getStatusColor(receivingStatus),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          receivingStatus.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(receivingStatus),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileReceivingPanel() {
    final receivingPercentage = _calculateReceivingPercentage();
    final quantityPercentage = _calculateQuantityPercentage();
    final receivingStatus = getReceivingStatus();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTransfer!['supplywarehousename'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transfer: ${_selectedTransfer!['docid']?.toString().substring(0, 8) ?? ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Date: ${_selectedTransfer!['transferdate'] != null ? _dateFormat.format((_selectedTransfer!['transferdate'] as Timestamp).toDate()) : 'N/A'}',
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
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(receivingStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(receivingStatus).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(receivingStatus),
                          size: 14,
                          color: _getStatusColor(receivingStatus),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          receivingStatus.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(receivingStatus),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Progress Bars
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF0D2A3C),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Items Progress',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${receivingPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: receivingPercentage / 100,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation(Colors.blue),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quantity Progress',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${quantityPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: quantityPercentage / 100,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation(Colors.green),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
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
              // Items Tab
              _buildMobileItemsTab(),

              // Inspection Tab
              _buildMobileInspectionTab(),

              // Summary Tab
              _buildMobileSummaryTab(),
            ],
          ),
        ),

        // Submit Button
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
                    onPressed: _resetReceiving,
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
                if (_receivedItems.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitReceiving,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: receivingStatus == 'completed'
                            ? Colors.green.shade700
                            : receivingStatus == 'discrepant'
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Icon(
                        receivingStatus == 'completed'
                            ? Icons.check_circle
                            : Icons.download_done,
                        size: 18,
                      ),
                      label: Text(
                        _isLoading
                            ? 'Confirming...'
                            : receivingStatus == 'completed'
                            ? 'Complete Receiving'
                            : 'Confirm Receipt',
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

  Widget _buildMobileItemsTab() {
    final items = _selectedTransfer!['items'] as List;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final itemId = item['itemid'] ?? '';
        final expectedQty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final alreadyreceivedqty = (item['receivedquantity'] as num?)?.toDouble() ?? 0;
        final received = _receivedItems[itemId];
        final receivedQty = received?['received'] ?? 0;
        final condition = received?['condition'] ?? 'good';

        double effectiveqty=0;
        effectiveqty = alreadyreceivedqty > 0
            ? alreadyreceivedqty
            : (receivedQty > 0 ? receivedQty :expectedQty );

        Color getStatusColor() {
          if (effectiveqty == 0) return Colors.grey;
          if (effectiveqty == expectedQty) return Colors.green;
          if (effectiveqty > expectedQty) return Colors.orange;
          return Colors.blue;
        }

        String getStatusText() {
          if (effectiveqty == 0) return 'Pending';
          if (effectiveqty == expectedQty) return 'Complete';
          if (effectiveqty > expectedQty) return 'Over';
          return 'Partial';
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D2A3C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: effectiveqty > 0
                  ? (effectiveqty == expectedQty
                  ? Colors.green
                  : effectiveqty > expectedQty
                  ? Colors.orange
                  : Colors.blue)
                  : Colors.white.withOpacity(0.1),
              width: effectiveqty > 0 ? 1.5 : 1,
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
                            const SizedBox(height: 2),
                            Text(
                              'Barcode: ${item['barcode']}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item['transfermode'] ?? 'N/A',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
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
                      ),
                      child: Text(
                        getStatusText(),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transferred',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              expectedQty.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Receiving',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 80,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D2A3C),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: effectiveqty > 0
                                          ? (effectiveqty == expectedQty
                                          ? Colors.green
                                          : effectiveqty > expectedQty
                                          ? Colors.orange
                                          : Colors.blue)
                                          : Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: TextFormField(
                                    initialValue: effectiveqty.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (value) {
                                      final qty = double.tryParse(value) ?? 0;
                                      _updateReceivedQuantity(
                                        itemId,
                                        expectedQty,
                                        qty,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '/ ${expectedQty.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
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
                if (receivedQty > 0 && receivedQty < expectedQty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          size: 16,
                          color: Colors.blue.shade300,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Shortage: ${(expectedQty - receivedQty).toStringAsFixed(0)} units',
                            style: TextStyle(
                              color: Colors.blue.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (receivedQty > expectedQty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          size: 16,
                          color: Colors.orange.shade300,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Excess: ${(receivedQty - expectedQty).toStringAsFixed(0)} units',
                            style: TextStyle(
                              color: Colors.orange.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileInspectionTab() {
    final items = _selectedTransfer!['items'] as List;
    final itemsWithReceiving = items.where((item) {
      final received = _receivedItems[item['itemid']];
      return (received?['received'] ?? 0) > 0;
    }).toList();

    if (itemsWithReceiving.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No items received yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter quantities in the Items tab first',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemsWithReceiving.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = itemsWithReceiving[index];
        final itemId = item['itemid'] ?? '';
        final received = _receivedItems[itemId]!;
        final receivedQty = received['received'] ?? 0;
        final condition = received['condition'] ?? 'good';
        final remarks = received['remarks'] ?? '';

        Color getConditionColor() {
          switch (condition) {
            case 'good': return Colors.green;
            case 'damaged': return Colors.orange;
            case 'expired': return Colors.red;
            case 'wrong': return Colors.purple;
            default: return Colors.grey;
          }
        }

        IconData getConditionIcon() {
          switch (condition) {
            case 'good': return Icons.check_circle;
            case 'damaged': return Icons.error;
            case 'expired': return Icons.warning;
            case 'wrong': return Icons.swap_horiz;
            default: return Icons.help;
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D2A3C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: getConditionColor().withOpacity(0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['item'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: getConditionColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: getConditionColor().withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            getConditionIcon(),
                            size: 12,
                            color: getConditionColor(),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            condition.toUpperCase(),
                            style: TextStyle(
                              color: getConditionColor(),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        'Received',
                        receivedQty.toStringAsFixed(0),
                        Icons.inventory,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showConditionSelector(itemId, condition),
                        child: _buildInfoRow(
                          'Condition',
                          condition,
                          getConditionIcon(),
                          getConditionColor(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Condition Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildConditionChip(
                        'Good',
                        Icons.check_circle,
                        Colors.green,
                        condition == 'good',
                            () => _updateItemCondition(itemId, 'good'),
                      ),
                      const SizedBox(width: 8),
                      _buildConditionChip(
                        'Damaged',
                        Icons.error,
                        Colors.orange,
                        condition == 'damaged',
                            () => _updateItemCondition(itemId, 'damaged'),
                      ),
                      const SizedBox(width: 8),
                      _buildConditionChip(
                        'Expired',
                        Icons.warning,
                        Colors.red,
                        condition == 'expired',
                            () => _updateItemCondition(itemId, 'expired'),
                      ),
                      const SizedBox(width: 8),
                      _buildConditionChip(
                        'Wrong',
                        Icons.swap_horiz,
                        Colors.purple,
                        condition == 'wrong',
                            () => _updateItemCondition(itemId, 'wrong'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Remarks
                TextField(
                  onChanged: (value) => _updateItemRemarks(itemId, value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Remarks (optional)',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    hintText: 'Add inspection remarks...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E3A5A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConditionChip(String label, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : color.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : color.withOpacity(0.7),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSummaryTab() {
    final items = _selectedTransfer!['items'] as List;
    final totalItems = items.length;
    final receivedItems = _receivedItems.values.where((item) => (item['received'] ?? 0) > 0).length;
    final totalTransferred = items.fold(0.0, (sum, item) =>
    sum + ((item['quantity'] as num?)?.toDouble() ?? 0));
    final totalReceived = _receivedItems.values.fold(0.0,
            (sum, item) => sum + (item['received'] ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Receiving Summary
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
                    Icon(Icons.summarize, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Receiving Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSummaryProgress(
                  'Items Progress',
                  receivedItems as double,
                  totalItems as double,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildSummaryProgress(
                  'Quantity Progress',
                  totalReceived,
                  totalTransferred,
                  Colors.green,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Receipt Details
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
                    Icon(Icons.receipt, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Receipt Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _receivedByController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Received By *',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    hintText: 'Enter name of receiver',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E3A5A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Receiver name required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Receipt Date',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    hintText: 'Select date',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E3A5A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
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
                              primary: Colors.green,
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
                      setState(() {
                        _selectedDate = picked;
                        _dateController.text = _dateFormat.format(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _referenceController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Reference Number',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    hintText: 'Enter reference (optional)',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                    ),
                    prefixIcon: const Icon(Icons.receipt, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E3A5A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
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
                    hintText: 'Add any receiving notes...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                    ),
                    prefixIcon: const Icon(Icons.note, color: Colors.white70),
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

          // Condition Summary
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
                    Icon(Icons.assignment_turned_in, color: Colors.purple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Condition Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildConditionSummary(
                  'Good',
                  _receivedItems.values.where((item) => item['condition'] == 'good').length,
                  receivedItems,
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildConditionSummary(
                  'Damaged',
                  _receivedItems.values.where((item) => item['condition'] == 'damaged').length,
                  receivedItems,
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildConditionSummary(
                  'Expired',
                  _receivedItems.values.where((item) => item['condition'] == 'expired').length,
                  receivedItems,
                  Colors.red,
                ),
                const SizedBox(height: 8),
                _buildConditionSummary(
                  'Wrong',
                  _receivedItems.values.where((item) => item['condition'] == 'wrong').length,
                  receivedItems,
                  Colors.purple,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Discrepancy Alert
          if (getReceivingStatus() == 'discrepant')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade300),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discrepancy Detected',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Some items have quantity discrepancies. Please review before confirming.',
                          style: TextStyle(
                            color: Colors.red.shade200,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryProgress(String label, double current, double total, Color color) {
    final percentage = total > 0 ? (current / total * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              '${current.toStringAsFixed(0)} / ${total.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionSummary(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100) : 0;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            '(${percentage.toStringAsFixed(0)}%)',
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivingPanel() {
    final items = _selectedTransfer!['items'] as List;
    final receivingPercentage = _calculateReceivingPercentage();
    final quantityPercentage = _calculateQuantityPercentage();
    final receivingStatus = getReceivingStatus();

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
                              color: Colors.green.shade800.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.inventory,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transfer #${_selectedTransfer!['transferid']?.toString() ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                                    _selectedTransfer!['supplywarehousename'] ?? '',
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
                                    Icons.arrow_forward,
                                    size: 12,
                                    color: Colors.white70,
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
                                    _selectedTransfer!['recievebranchname'] ?? '',
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(receivingStatus).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _getStatusColor(receivingStatus).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(receivingStatus),
                              size: 16,
                              color: _getStatusColor(receivingStatus),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              receivingStatus.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(receivingStatus),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Items Progress',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: receivingPercentage / 100,
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        valueColor: const AlwaysStoppedAnimation(Colors.blue),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${receivingPercentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade900.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quantity Progress',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: quantityPercentage / 100,
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        valueColor: const AlwaysStoppedAnimation(Colors.green),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${quantityPercentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
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
                      'Transfer Items',
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
                      child: Column(
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
                                    'Transferred',
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
                                    'Receive',
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
                            final transferredQty = (item['quantity'] as num?)?.toDouble() ?? 0;
                            final oldreceivedQty = (item['receivedquantity'] as num?)?.toDouble() ?? 0;
                            final received = _receivedItems[itemId];
                            final receivedQty = (received?['received'] as num?)?.toDouble() ?? 0;
                            final status = item?['receivingstatus'];
                            double effectiveQty=0;
                            effectiveQty = oldreceivedQty > 0 ? oldreceivedQty : (receivedQty > 0 ? receivedQty :transferredQty );


                            Color getStatusColor() {
                              if (effectiveQty == 0) return Colors.grey;
                              if (effectiveQty == transferredQty) return Colors.green;
                              if (effectiveQty > transferredQty) return Colors.orange;
                              return Colors.blue;
                            }

                            String getStatusText() {
                              if (effectiveQty == 0) return 'Pending';
                              if (effectiveQty == transferredQty) return 'Complete';
                              if (effectiveQty > transferredQty) return 'Over';
                              return 'Partial';
                            }

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
                                        item['transfermode'] ?? '',
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
                                      transferredQty.toStringAsFixed(0),
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
                                          width: 80,
                                          height: 36,
                                          // decoration: BoxDecoration(
                                          //   color: const Color(0xFF1E3A5A),
                                          //   borderRadius: BorderRadius.circular(6),
                                          //   border: Border.all(
                                          //     color: (() {
                                          //
                                          //       if (effectiveQty == 0) {
                                          //         return Colors.white.withOpacity(0.2);
                                          //       } else if (effectiveQty == transferredQty) {
                                          //         return Colors.green;
                                          //       } else if (effectiveQty > transferredQty) {
                                          //         return Colors.orange;
                                          //       } else {
                                          //         return Colors.blue;
                                          //       }
                                          //     })(),
                                          //   ),
                                          // ),
                                          child: TextFormField(
                                            initialValue: effectiveQty.toStringAsFixed(0),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: const Color(0xFF1E3A5A),
                                              hintText: '0',
                                              hintStyle: TextStyle(
                                                color: Colors.white,
                                              ),
                                              border: InputBorder.none,
                                            ),
                                            //enabled: status!='completed',
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                            ],
                                            onChanged: (value) {
                                              final qty = double.tryParse(value) ?? 0;
                                              _updateReceivedQuantity(
                                                itemId,
                                                effectiveQty,
                                                qty,
                                              );
                                            },
                                          ),

                                        ),


                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: getStatusColor().withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          getStatusText(),
                                          style: TextStyle(
                                            color: getStatusColor(),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
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
                                      '${_receivedItems.values.where((item) => (item['received'] ?? 0) > 0).length} of ${items.length} items received',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Total: GHS ${_selectedTransfer!['gross']?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Receiving Information
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
                          const Text(
                            'Receiving Information',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _receivedByController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Received By *',
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    hintText: 'Enter name',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    prefixIcon: const Icon(Icons.person, color: Colors.white70),
                                    filled: true,
                                    fillColor: const Color(0xFF1E3A5A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _dateController,
                                  readOnly: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Receipt Date',
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    hintText: 'Select date',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                                    filled: true,
                                    fillColor: const Color(0xFF1E3A5A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
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
                                              primary: Colors.green,
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
                                      setState(() {
                                        _selectedDate = picked;
                                        _dateController.text = _dateFormat.format(picked);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _referenceController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Reference Number',
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    hintText: 'Enter reference',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    prefixIcon: const Icon(Icons.receipt, color: Colors.white70),
                                    filled: true,
                                    fillColor: const Color(0xFF1E3A5A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Notes',
                              labelStyle: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                              ),
                              hintText: 'Add any receiving notes...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                              ),
                              prefixIcon: const Icon(Icons.note, color: Colors.white70),
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

                    const SizedBox(height: 24),

                    // Discrepancy Alert
                    if (receivingStatus == 'discrepant')
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade300),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quantity Discrepancy Detected',
                                    style: TextStyle(
                                      color: Colors.red.shade300,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Some items have received quantities that differ from transferred quantities. Please verify before confirming.',
                                    style: TextStyle(
                                      color: Colors.red.shade200,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
                    onPressed: _resetReceiving,
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
                  if (_receivedItems.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitReceiving,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: receivingStatus == 'completed'
                            ? Colors.green.shade700
                            : receivingStatus == 'discrepant'
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Icon(
                        receivingStatus == 'completed'
                            ? Icons.check_circle
                            : Icons.download_done,
                      ),
                      label: Text(
                        _isLoading
                            ? 'Confirming...'
                            : receivingStatus == 'completed'
                            ? 'Complete Receiving'
                            : 'Confirm Receipt',
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
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Transfer Selected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a transfer from the left panel to receive stock',
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
}