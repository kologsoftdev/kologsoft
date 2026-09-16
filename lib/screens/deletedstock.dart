import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/constants.dart';
import '../providers/Datafeed.dart';
import '../providers/StockProvider.dart';

class DeletedStockScreen extends StatefulWidget {
  const DeletedStockScreen({super.key});

  @override
  State<DeletedStockScreen> createState() => _DeletedStockScreenState();
}

class _DeletedStockScreenState extends State<DeletedStockScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = "";
  String _selectedFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeActive = false;
  bool _isLoading = false;
  bool _searchInItems = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)async{
      final provider = Provider.of<Datafeed>(context, listen: false);
      await provider.getdata();
    });
  }
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  final List<String> _filterOptions = [
    'All',
    'Credit',
    'Cash',
  ];
  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0;
  }
  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
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
      }
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeActive = false;
    });
  }

  bool _filterStock(Map<String, dynamic> data) {
    // Search filter
    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      bool matches = false;

      // Search in main fields
      final searchableFields = [
        data['invoice']?.toString(),
        data['waybill']?.toString(),
        data['suppliername']?.toString(),
        data['branchname']?.toString(),
        data['recievebranchname']?.toString(),
        data['createdby']?.toString(),
        data['purchasetype']?.toString(),
        data['paymentaccount']?.toString(),
        data['transactionid']?.toString(),
        data['docid']?.toString(),
      ];

      for (var field in searchableFields) {
        if (field != null && field.toLowerCase().contains(searchLower)) {
          matches = true;
          break;
        }
      }

      // Search in items if enabled
      if (!matches && _searchInItems && data['items'] != null) {
        final items = data['items'] as List;
        for (var item in items) {
          if (item is Map) {
            for (var key in ['item', 'barcode', 'itemid']) {
              final value = item[key]?.toString();
              if (value != null && value.toLowerCase().contains(searchLower)) {
                matches = true;
                break;
              }
            }
          }
          if (matches) break;
        }
      }

      if (!matches) return false;
    }

    // Filter by purchase type or supplier/item
    if (_selectedFilter != 'All') {
      final filterLower = _selectedFilter.toLowerCase();
      final purchaseType = data['purchasetype']?.toString().toLowerCase() ?? '';
      final supplier = data['suppliername']?.toString().toLowerCase() ?? '';
      final paymentAccount = data['paymentaccount']?.toString().toLowerCase() ?? '';

      // Check if filter matches any main field
      bool fieldMatches = purchaseType.contains(filterLower) ||
          supplier.contains(filterLower) ||
          paymentAccount.contains(filterLower);

      // Check if filter matches any item
      if (!fieldMatches && data['items'] != null) {
        final items = data['items'] as List;
        for (var item in items) {
          if (item is Map) {
            final itemName = item['item']?.toString().toLowerCase() ?? '';
            if (itemName.contains(filterLower)) {
              fieldMatches = true;
              break;
            }
          }
        }
      }

      if (!fieldMatches) return false;
    }

    // Date range filter
    if (_isDateRangeActive && _startDate != null && _endDate != null) {
      final invoiceDate = data['invoicedate'] as Timestamp?;
      if (invoiceDate != null) {
        final date = invoiceDate.toDate();
        if (date.isBefore(_startDate!) || date.isAfter(_endDate!)) {
          return false;
        }
      }
    }

    return true;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
  }

  String _formatDateOnly(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: 'GHC ',
      decimalDigits: 2,
    ).format(amount);
  }

  Widget _buildDeletedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade300.withOpacity(0.5),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_forever, color: Colors.red, size: 14),
          SizedBox(width: 4),
          Text(
            'DELETED',
            style: TextStyle(
              color: Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseTypeChip(String type) {
    Color color;
    switch (type.toLowerCase()) {
      case 'credit':
        color = Colors.orange;
        break;
      case 'cash':
        color = Colors.green;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> data, int index) {
    final rawItems = data['items'];

    List<Map<String, dynamic>> items = [];

    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } else if (rawItems is Map) {
      items = rawItems.entries.map((entry) {
        final value = entry.value;

        if (value is Map) {
          return {
            'itemid': entry.key,
            ...Map<String, dynamic>.from(value),
          };
        }

        return <String, dynamic>{
          'itemid': entry.key,
          'item': value,
        };
      }).toList();
    }

    final totalItems = items.length;
    final gross = (data['gross'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 12,
      ),
      color: index.isEven
          ? const Color(0xFF0D1B2A)
          : const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.red.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                  Colors.red.shade900.withOpacity(0.3),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INV-${data['invoice'] ?? 'N/A'}',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        data['suppliername'] ??
                            data['supplywarehousename'] ??
                            'N/A',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildPurchaseTypeChip(
                  data['purchasetype'] ?? 'N/A',
                ),
              ],
            ),

            const Divider(
              color: Colors.white24,
              height: 20,
            ),

            // Details
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Invoice',
                  data['invoice'] ?? 'N/A',
                ),
                _buildInfoRow(
                  'Waybill',
                  data['waybill'] ?? 'N/A',
                ),
                _buildInfoRow(
                  'Date',
                  _formatDateOnly(data['invoicedate']),
                ),
                _buildInfoRow(
                  'Branch',
                  data['branchname'] ??
                      data['recievebranchname'] ??
                      'N/A',
                ),
                _buildInfoRow(
                  'Staff',
                  data['createdby'] ?? 'N/A',
                ),
                _buildInfoRow(
                  'Items',
                  '$totalItems',
                ),
                _buildInfoRow(
                  'Gross Value',
                  _formatCurrency(gross),
                ),
                _buildInfoRow(
                  'Payment',
                  data['paymentaccount'] ?? 'N/A',
                ),

                if (data['deletedat'] != null)
                  _buildInfoRow(
                    'Deleted At',
                    _formatDate(data['deletedat']),
                  ),

                if (data['deletedby'] != null)
                  _buildInfoRow(
                    'Deleted By',
                    data['deletedby'] ?? 'N/A',
                  ),

                if (data['reason'] != null)
                  _buildInfoRow(
                    'Reason',
                    data['reason'] ?? 'N/A',
                  ),
              ],
            ),

            // Items Preview
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),

              const Text(
                'Items:',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: items.take(3).map((item) {
                  return Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade900
                          .withOpacity(0.2),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item['item'] ?? item['itemname'] ?? 'Unknown'} '
                          'x${item['quantity'] ?? item['newBalance'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (items.length > 3)
                Text(
                  '+${items.length - 3} more items',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],

            const Divider(
              color: Colors.white24,
              height: 20,
            ),

            // Actions
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  Icons.visibility,
                  Colors.tealAccent,
                  'View',
                      () {
                    _showStockDetails(data);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStockDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B263B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          // ============================================================
          // ITEMS
          //
          // Current structure:
          //
          // items: {
          //   "itemid1": {...},
          //   "itemid2": {...},
          // }
          //
          // Also supports old List structure.
          // ============================================================

          final dynamic rawItems = data['items'];

          final List<dynamic> items;

          if (rawItems is Map) {
            items = rawItems.values.toList();
          } else if (rawItems is List) {
            items = rawItems;
          } else {
            items = [];
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================================
                // DRAG HANDLE
                // ==========================================================

                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius:
                      BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // HEADER
                // ==========================================================

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Deleted Stock Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    //_buildDeletedBadge(),

                    const SizedBox(width: 8),

                    _buildPurchaseTypeChip(
                      data['purchasetype'] ?? 'N/A',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // DETAILS
                // ==========================================================

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDetailRow(
                        'Invoice',
                        data['invoice'] ?? 'N/A',
                      ),

                      _buildDetailRow(
                        'Waybill',
                        data['waybill'] ?? 'N/A',
                      ),

                      _buildDetailRow(
                        'Supplier',
                        data['suppliername'] ??
                            data['supplywarehousename'] ??
                            'N/A',
                      ),

                      _buildDetailRow(
                        'Branch',
                        data['branchname'] ??
                            data['recievebranchname'] ??
                            'N/A',
                      ),

                      _buildDetailRow(
                        'Date',
                        _formatDateOnly(
                          data['invoicedate'],
                        ),
                      ),

                      _buildDetailRow(
                        'Staff',
                        data['createdby'] ?? 'N/A',
                      ),

                      _buildDetailRow(
                        'Purchase Type',
                        data['purchasetype'] ?? 'N/A',
                      ),

                      _buildDetailRow(
                        'Payment Account',
                        data['paymentaccount'] ?? 'N/A',
                      ),

                      _buildDetailRow(
                        'Gross Value',
                        _formatCurrency(
                          _toDouble(data['gross']),
                        ),
                      ),

                      _buildDetailRow(
                        'Net Value',
                        _formatCurrency(
                          _toDouble(data['netval']),
                        ),
                      ),

                      _buildDetailRow(
                        'Deleted At',
                        _formatDate(
                          data['deletedat'],
                        ),
                      ),

                      _buildDetailRow(
                        'Deleted By',
                        data['deletedby'] ?? 'N/A',
                      ),

                      _buildDetailRow(
                        'Reason',
                        data['reason'] ?? 'N/A',
                      ),

                      const SizedBox(height: 16),

                      // ======================================================
                      // ITEMS TITLE
                      // ======================================================

                      const Text(
                        'Items',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ======================================================
                      // ITEMS
                      // ======================================================

                      ...items.map((item) {
                        if (item is! Map) {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          padding:
                          const EdgeInsets.all(12),
                          margin:
                          const EdgeInsets.only(
                            bottom: 8,
                          ),
                          decoration:
                          BoxDecoration(
                            color:
                            const Color(0xFF22304A),
                            borderRadius:
                            BorderRadius.circular(
                              8,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // ============================================
                              // ITEM NAME / QUANTITY
                              // ============================================

                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['item']
                                          ?.toString() ??
                                          'Unknown',
                                      style:
                                      const TextStyle(
                                        color:
                                        Colors.white,
                                        fontWeight:
                                        FontWeight
                                            .bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),

                                  Text(
                                    'x${item['quantity'] ?? item['pieces'] ?? 0}',
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // ============================================
                              // ITEM INFORMATION
                              // ============================================

                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Barcode: ${item['barcode'] ?? 'N/A'}',
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),

                                  Text(
                                    'Price: ${_formatCurrency(_toDouble(item['price'] ?? item['cp']))}',
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),

                                  Text(
                                    'Total: ${_formatCurrency(_toDouble(item['total'] ?? item['stock_value']))}',
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),

                                  Text(
                                    'Mode: ${item['stockingmode'] ?? item['mode'] ?? 'N/A'}',
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),

                                  if (item['boxpieces'] !=
                                      null ||
                                      item['boxpiece'] !=
                                          null)
                                    Text(
                                      'Box Pieces: ${item['boxpieces'] ?? item['boxpiece']}',
                                      style:
                                      const TextStyle(
                                        color:
                                        Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreStock(Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text(
          'Restore Stock',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to restore this stock invoice?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Remove deleted fields
        // final restoredData = Map<String, dynamic>.from(data);
        // restoredData.remove('deletedat');
        // restoredData.remove('deletedby');
        // restoredData.remove('reason');

        // Save to stock_transactions collection
       // await _firestore.collection('stock_transactions').doc(data['docid']).set(restoredData);

        // Delete from deletedstock collection
        //await _firestore.collection('deletedstock').doc(data['docid']).delete();
        final provider = Provider.of<StockProvider>(context, listen: false);
        //await provider.deleteLedgersForCompany("KS005");

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stock restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _permanentDelete(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text(
          'Permanent Delete',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this stock invoice? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        //await _firestore.collection('deletedstock').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stock permanently deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final provider = Provider.of<Datafeed>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: const Text('Deleted Stock'),
        backgroundColor: const Color(0xFF1B263B),
        elevation: 0,
        centerTitle: true,
        actions: [
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
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh, color: Colors.white70),
            ),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      )
          : Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextFormField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    fillColor: const Color(0xFF22304A),
                    hintText: 'Search by invoice, supplier, item, barcode...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () {
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          ),
                        Tooltip(
                          message: _searchInItems ? 'Search in items enabled' : 'Search in items disabled',
                          child: IconButton(
                            icon: Icon(
                              _searchInItems ? Icons.list_alt : Icons.list_alt_outlined,
                              color: _searchInItems ? Colors.blue.shade300 : Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchInItems = !_searchInItems;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._filterOptions.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = selected ? filter : 'All';
                              });
                            },
                            backgroundColor: const Color(0xFF22304A),
                            selectedColor: Colors.blue.shade800,
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.blue.shade300
                                  : Colors.white24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }),
                      if (_isDateRangeActive)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade700.withOpacity(0.3)),
                          ),
                          child: Row(
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
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Search info
                if (_searchQuery.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Searching: "$_searchQuery" ${_searchInItems ? '(including items)' : '(main fields only)'}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Data Table / List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('deletedstock')
                  .where(
                'companyid',
                isEqualTo: provider.companyid,
              )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(
                        Colors.blue,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_forever,
                          color: Colors.white38,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No deleted stock found',
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ============================================================
                // Convert documents to map and filter
                // ============================================================

                final stocks = snapshot.data!.docs
                    .map((doc) {
                  final data =
                  doc.data() as Map<String, dynamic>;

                  data['docid'] = doc.id;

                  return data;
                })
                    .where((data) => _filterStock(data))
                    .toList();

                if (stocks.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No deleted stock matching "$_searchQuery"'
                          : 'No deleted stock found',
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  );
                }

                // ============================================================
                // Mobile Card View
                // ============================================================

                if (isMobile) {
                  return ListView.builder(
                    controller: _verticalController,
                    itemCount: stocks.length,
                    itemBuilder: (context, index) {
                      return _buildMobileCard(
                        stocks[index],
                        index,
                      );
                    },
                  );
                }

                // ============================================================
                // Desktop Table View
                // ============================================================

                return Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          child: DataTable(
                            headingRowColor:
                            WidgetStateProperty.all(
                              const Color(0xFF1B263B),
                            ),
                            columnSpacing: 12,
                            headingTextStyle:
                            const TextStyle(
                              color: Colors.white,
                              fontWeight:
                              FontWeight.bold,
                              fontSize: 13,
                            ),
                            dataTextStyle:
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),

                            // ==================================================
                            // TABLE COLUMNS
                            // ==================================================

                            columns: const [
                              DataColumn(
                                label: Text('#'),
                              ),
                              DataColumn(
                                label: Text('Invoice'),
                              ),
                              DataColumn(
                                label: Text('Waybill'),
                              ),
                              DataColumn(
                                label: Text('Supplier'),
                              ),
                              DataColumn(
                                label: Text('Branch'),
                              ),
                              DataColumn(
                                label: Text('Date'),
                              ),
                              DataColumn(
                                label: Text('Items'),
                              ),
                              DataColumn(
                                label: Text('Gross'),
                              ),
                              DataColumn(
                                label: Text('Mode'),
                              ),
                              DataColumn(
                                label: Text('Type'),
                              ),
                              DataColumn(
                                label: Text('Deleted'),
                              ),
                              DataColumn(
                                label: Text('Actions'),
                              ),
                            ],

                            // ==================================================
                            // TABLE ROWS
                            // ==================================================

                            rows: List.generate(
                              stocks.length,
                                  (index) {
                                final data =
                                stocks[index];

                                // =================================================
                                // ITEMS
                                //
                                // Your current documents may have:
                                //
                                // items: {
                                //   item_0: {...},
                                //   item_1: {...}
                                // }
                                //
                                // Older documents may have:
                                //
                                // items: [
                                //   {...},
                                //   {...}
                                // ]
                                //
                                // Handle both without changing your logic.
                                // =================================================

                                final dynamic rawItems =
                                data['items'];

                                final int itemCount =
                                rawItems is Map
                                    ? rawItems.length
                                    : rawItems is List
                                    ? rawItems.length
                                    : 0;

                                // =================================================
                                // GROSS
                                // =================================================

                                final double gross =
                                (data['gross'] ?? 0)
                                is num
                                    ? (data['gross'] ?? 0)
                                    .toDouble()
                                    : double.tryParse(
                                  data['gross']
                                      ?.toString() ??
                                      '0',
                                ) ??
                                    0;

                                // =================================================
                                // ROW
                                // =================================================

                                return DataRow(
                                  color: WidgetStateProperty
                                      .resolveWith<Color?>(
                                        (
                                        Set<WidgetState>
                                        states,
                                        ) {
                                      return index.isEven
                                          ? const Color(
                                        0xFF0D1B2A,
                                      )
                                          : const Color(
                                        0xFF1B263B,
                                      );
                                    },
                                  ),

                                  cells: [
                                    // =================================================
                                    // #
                                    // =================================================

                                    DataCell(
                                      Text(
                                        '${index + 1}',
                                      ),
                                    ),

                                    // =================================================
                                    // INVOICE
                                    // =================================================

                                    DataCell(
                                      Row(
                                        children: [
                                          Text(
                                            data['invoice']
                                                ?.toString() ??
                                                'N/A',
                                            style:
                                            const TextStyle(
                                              color:
                                              Colors.blueAccent,
                                              fontWeight:
                                              FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 4,
                                          ),

                                          // _buildDeletedBadge(),
                                        ],
                                      ),
                                    ),

                                    // =================================================
                                    // WAYBILL
                                    // =================================================

                                    DataCell(
                                      Text(
                                        data['waybill']
                                            ?.toString() ??
                                            'N/A',
                                      ),
                                    ),

                                    // =================================================
                                    // SUPPLIER
                                    // =================================================

                                    DataCell(
                                      Text(
                                        data['suppliername']
                                            ?.toString() ??
                                            data[
                                            'supplywarehousename']
                                                ?.toString() ??
                                            'N/A',
                                      ),
                                    ),

                                    // =================================================
                                    // BRANCH
                                    // =================================================

                                    DataCell(
                                      Text(
                                        data['branchname']
                                            ?.toString() ??
                                            data[
                                            'recievebranchname']
                                                ?.toString() ??
                                            'N/A',
                                      ),
                                    ),

                                    // =================================================
                                    // DATE
                                    // =================================================

                                    DataCell(
                                      Text(
                                        _formatDateOnly(
                                          data['invoicedate'] ??
                                              data[
                                              'transferdate'],
                                        ),
                                      ),
                                    ),

                                    // =================================================
                                    // ITEMS
                                    // =================================================

                                    DataCell(
                                      Text(
                                        '$itemCount',
                                      ),
                                    ),

                                    // =================================================
                                    // GROSS
                                    // =================================================

                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          gross,
                                        ),
                                        style:
                                        const TextStyle(
                                          color:
                                          Colors.greenAccent,
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    // =================================================
                                    // MODE
                                    // =================================================

                                    DataCell(
                                      _buildPurchaseTypeChip(
                                        data['purchasetype'] ??
                                            'N/A',
                                      ),
                                    ),

                                    // =================================================
                                    // TYPE
                                    // =================================================

                                    DataCell(
                                      _buildPurchaseTypeChip(
                                        data['deletetype'] ??
                                            'N/A',
                                      ),
                                    ),

                                    // =================================================
                                    // DELETED
                                    // =================================================

                                    DataCell(
                                      Text(
                                        _formatDate(
                                          data['deletedat'],
                                        ),
                                      ),
                                    ),

                                    // =================================================
                                    // ACTIONS
                                    // =================================================

                                    DataCell(
                                      Row(
                                        children: [
                                          // =========================================
                                          // VIEW
                                          // =========================================

                                          IconButton(
                                            icon:
                                            const Icon(
                                              Icons.visibility,
                                              color: Colors
                                                  .tealAccent,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _showStockDetails(
                                                  data,
                                                ),
                                            tooltip:
                                            'View',
                                            padding:
                                            const EdgeInsets
                                                .all(4),
                                            constraints:
                                            const BoxConstraints(),
                                          ),

                                          // =========================================
                                          // RESTORE
                                          // =========================================

                                          // IconButton(
                                          //   icon: const Icon(
                                          //     Icons.restore,
                                          //     color: Colors.green,
                                          //     size: 20,
                                          //   ),
                                          //   onPressed: () =>
                                          //       _restoreStock(data),
                                          //   tooltip: 'Restore',
                                          //   padding:
                                          //       const EdgeInsets.all(4),
                                          //   constraints:
                                          //       const BoxConstraints(),
                                          // ),

                                          // =========================================
                                          // PERMANENT DELETE
                                          // =========================================

                                          IconButton(
                                            icon:
                                            const Icon(
                                              Icons
                                                  .delete_forever,
                                              color: Colors
                                                  .redAccent,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _permanentDelete(
                                                  data['docid'],
                                                ),
                                            tooltip:
                                            'Permanent Delete',
                                            padding:
                                            const EdgeInsets
                                                .all(4),
                                            constraints:
                                            const BoxConstraints(),
                                          ),

                                          // =========================================
                                          // SYNC
                                          // =========================================

                                          // IconButton(
                                          //   icon: const Icon(
                                          //     Icons.sync,
                                          //     color: Colors.blue,
                                          //     size: 20,
                                          //   ),
                                          //   onPressed: () async {
                                          //     print(
                                          //       "Syncing stock transfer reports for docid: ${data['docid']}",
                                          //     );
                                          //
                                          //     bool loading = false;
                                          //
                                          //     setState(
                                          //       () => loading = true,
                                          //     );
                                          //
                                          //     LoadingDialog.show(
                                          //       context,
                                          //       message:
                                          //           "Please wait...",
                                          //     );
                                          //
                                          //     await context
                                          //         .read<StockProvider>()
                                          //         .syncStockTransfers(
                                          //           data['docid'],
                                          //         );
                                          //
                                          //     setState(
                                          //       () => loading = false,
                                          //     );
                                          //
                                          //     LoadingDialog.hide();
                                          //
                                          //     ScaffoldMessenger.of(
                                          //       context,
                                          //     ).showSnackBar(
                                          //       const SnackBar(
                                          //         content: Text(
                                          //           "Stock transfer reports updated.",
                                          //         ),
                                          //       ),
                                          //     );
                                          //   },
                                          // ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}