import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: const Color(0xFF131921),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1200;
          final isTablet = constraints.maxWidth > 600;

          return Column(
            children: [
              _buildFilterChips(isDesktop),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ecommerce_orders')
                      .orderBy('orderDate', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    var orders = snapshot.data!.docs;

                    // Filter orders
                    if (_selectedFilter != 'all') {
                      orders = orders.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['status'] == _selectedFilter;
                      }).toList();
                    }

                    if (orders.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(isDesktop ? 24 : 16),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final orderDoc = orders[index];
                        final orderId = orderDoc.id;
                        final orderData =
                            orderDoc.data() as Map<String, dynamic>;

                        return Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 900 : double.infinity,
                          ),
                          margin: EdgeInsets.only(
                            bottom: isDesktop ? 16 : 12,
                            left: isDesktop
                                ? MediaQuery.of(context).size.width * 0.1
                                : 0,
                            right: isDesktop
                                ? MediaQuery.of(context).size.width * 0.1
                                : 0,
                          ),
                          child: _buildOrderCard(
                            orderId,
                            orderData,
                            isDesktop,
                            isTablet,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(bool isDesktop) {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'Pending', 'value': 'pending'},
      {'label': 'Processing', 'value': 'processing'},
      {'label': 'Delivered', 'value': 'delivered'},
      {'label': 'Cancelled', 'value': 'cancelled'},
    ];

    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      color: Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter['label'] as String),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedFilter = filter['value'] as String);
                  }
                },
                selectedColor: const Color(0xFFFF6B35),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No orders yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Your orders will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    String orderId,
    Map<String, dynamic> orderData,
    bool isDesktop,
    bool isTablet,
  ) {
    final items = orderData['items'] as List<dynamic>? ?? [];
    final totalAmount = orderData['totalAmount'] ?? 0.0;
    final status = orderData['status'] ?? 'pending';
    final orderDate = orderData['orderDate'] as Timestamp?;
    final customerName = orderData['customerName'] ?? 'Unknown';
    final customerPhone = orderData['customerPhone'] ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showOrderDetails(context, orderId, orderData, isDesktop),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${orderId.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (orderDate != null)
                          Text(
                            _formatDate(orderDate.toDate()),
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : 13,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const Divider(height: 24),

              // Customer info
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: isDesktop ? 20 : 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerName,
                      style: TextStyle(fontSize: isDesktop ? 15 : 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: isDesktop ? 20 : 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    customerPhone,
                    style: TextStyle(fontSize: isDesktop ? 15 : 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Items summary
              Text(
                '${items.length} ${items.length == 1 ? "item" : "items"}',
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'GHS ${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isDesktop ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF6B35),
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'delivered':
        color = Colors.green;
        break;
      case 'processing':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'pending':
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showOrderDetails(
    BuildContext context,
    String orderId,
    Map<String, dynamic> orderData,
    bool isDesktop,
  ) {
    final items = orderData['items'] as List<dynamic>? ?? [];
    final totalAmount = orderData['totalAmount'] ?? 0.0;
    final status = orderData['status'] ?? 'pending';
    final customerName = orderData['customerName'] ?? 'Unknown';
    final customerPhone = orderData['customerPhone'] ?? '';
    final customerAddress = orderData['customerAddress'] ?? '';
    final paymentMethod = orderData['paymentMethod'] ?? 'cash';
    final notes = orderData['notes'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(isDesktop ? 32 : 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 600 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Order #${orderId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Divider(height: 32),

                // Customer Information
                const Text(
                  'Customer Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Name', customerName),
                _buildDetailRow('Phone', customerPhone),
                _buildDetailRow('Address', customerAddress),
                _buildDetailRow('Payment Method', paymentMethod.toUpperCase()),
                if (notes.isNotEmpty) _buildDetailRow('Notes', notes),

                const Divider(height: 32),

                // Items
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...items.map((item) => _buildItemRow(item, isDesktop)).toList(),

                const Divider(height: 32),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'GHS ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['productName'] ?? 'Unknown Product',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['priceMode']} - GHS ${item['price']} x ${item['quantity']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            'GHS ${item['totalPrice'].toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
