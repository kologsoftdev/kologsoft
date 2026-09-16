import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/stockmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/StockProvider.dart';
import 'package:kologsoft/screens/stocksupply.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';


class PurchaseReturn extends StatefulWidget {
  final String? transactionId;
  final StockModel? transactionData;

  const PurchaseReturn({
    super.key,
    this.transactionId,
    this.transactionData,
  });

  @override
  State<PurchaseReturn> createState() => _PurchaseReturnState();
}

class _PurchaseReturnState extends State<PurchaseReturn> with SingleTickerProviderStateMixin {
  List<StockModel> purchaseTransactions = [];
  StockModel? _selectedTransaction;
  String? _selectedTransactionId;
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _invoiceSearchController = TextEditingController();
  Map<String, TextEditingController> _returncontrollers = {};
  final Map<String, Map<String, dynamic>> _returnItems = {};
  String? _activeReturnId;
  final TextEditingController _returnNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final GlobalKey<FormState> _purchasereturnFormKey = GlobalKey<FormState>();
  // UI State
  late TabController _tabController;
  bool _isMobileView = false;
  bool _showTransactionList = true;
  DateTime? _selectedDate;


  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
      WidgetsBinding.instance.addPostFrameCallback((_)async {
        final provider = Provider.of<Datafeed>(context, listen: false);
         await provider.fetchReturnreasons();
        if (widget.transactionId != null && widget.transactionData != null) {
        _selectTransaction(widget.transactionId!, widget.transactionData!);
          }
      });

  }

  @override
  void dispose() {
    _returnNumberController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    _invoiceSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchInvoice() async {
  final invoiceNumber=_invoiceSearchController.text.trim().toString();
  if (invoiceNumber.isEmpty) {
    _showErrorSnackBar('Please enter an invoice number');
    return;
  }
  try{
    setState(() {
      _isSearching = true;
    });
    final purchase = Provider.of<StockProvider>(context, listen: false);
    await purchase.loadPurchaseTransactions(invoiceNumber);
    purchaseTransactions=purchase.purchaseTransactions;
    if (purchaseTransactions.isEmpty) {
      _showErrorSnackBar('Invoice #$invoiceNumber not found');
      return;
    }

    final firstTransaction = purchaseTransactions.first;
    _selectTransaction(purchaseTransactions[0].docId,firstTransaction);

  }catch(e){
    _showErrorSnackBar('Failed: $e');
  }finally{
    setState(() {
      _isSearching = false;
    });
  }

  }

  void _clearSearch() {
    _invoiceSearchController.clear();
    setState(() {
      purchaseTransactions = [];
      _selectedTransaction = null;
      _selectedTransactionId = null;
      _searchQuery = '';
    });
  }

  void _selectTransaction(String id, StockModel transaction) {
    setState(() {
      _selectedTransactionId = id;
      _selectedTransaction = transaction;

      _activeReturnId = id;
      _returnItems.clear();
      for (var item in _selectedTransaction!.items) {
        final purchasedQty = item.quantity.toDouble();

        _returnItems[item.itemId] = {
          'purchased': purchasedQty,
          'returned': 0,
          'reason': '',
          'itemName': item.item,
          'barcode': item.barcode,
          'mode': item.stockingMode,
          'price': item.price,
          'total': item.total,
          'boxpieces':item.boxpieces,
        };
      }
      if (_isMobileView) {
        _showTransactionList = false;
      }
    });
  }

  void _updateReturnQuantity(String itemId, double purchasedQty, double returnQty){
    setState(() {
      if (_returnItems.containsKey(itemId)){
        final clampedQty = returnQty.clamp(0, purchasedQty);
        _returnItems[itemId] = {
          ..._returnItems[itemId]!,
          'returned': clampedQty,
        };
      }
    });
  }

  void _updateReturnReason(String itemId, String reason) {
    setState(() {
      if (_returnItems.containsKey(itemId)) {
        _returnItems[itemId] = {
          ..._returnItems[itemId]!,
          'reason': reason,
        };
      }
    });
  }

  double _calculateReturnValue() {
    if (_selectedTransaction == null) return 0;

    double totalReturnValue = 0;
    _returnItems.forEach((itemId, data) {
      final returned = data['returned'] ?? 0;
      final boxpieces = data['boxpieces'] ?? 1;
      final modeqty=data['modeqty'] ?? 1;
      final price = data['price'] ?? 0;
      final pieces = returned * modeqty;
      totalReturnValue += pieces * price;
    });

    return totalReturnValue;
  }

 _submitReturn() async {
    if (!_purchasereturnFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<StockProvider>(context, listen: false);
      await provider.submitReturn(
        transaction: _selectedTransaction!,
        returnItems: _returnItems,
        returnId: _activeReturnId!,
        returndate: _dateController.text,
      );

      _showSuccessSnackBar('Return processed successfully');
      _resetReturn();

    } catch (e) {
      print(e);
      _showErrorSnackBar(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetReturn() {
    setState(() {
      _selectedTransaction = null;
      _selectedTransactionId = null;
      _activeReturnId = null;
      _returnItems.clear();
      _returnNumberController.clear();
      _notesController.clear();
      _dateController.clear();
      _selectedDate = null;

      if (_isMobileView) {
        _showTransactionList = true;
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

  void _showReasonSelector(String itemId, String currentReason) {
    final reasons = Provider.of<Datafeed>(context, listen: false).returnitemreasons;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2A3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6, // limit height
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Return Reason',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...reasons.map((reason) {
              final isSelected = currentReason == reason.name;
              return ListTile(
                title: Text(
                  reason.name,
                  style: TextStyle(
                    color: isSelected ? Colors.orange : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.orange)
                    : null,
                onTap: () {
                  _updateReturnReason(itemId, reason.name);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),    );
  }


  Widget buildSupplyField({
    required TextEditingController controller,
    required double purchaseQty,
    required double returnQty,
    required String itemId,
    required String dbstatus,
    required void Function(String itemId, double purchaseQty, double safeQty) onUpdate,
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
        MaxValueInputFormatter(purchaseQty),
      ],

      validator: (value) {
        final qty = double.tryParse(value ?? '0');
        if (qty == null) return 'Enter a valid number';
        if (qty < 0) return 'Quantity cannot be negative';
        if (qty > purchaseQty) {
          return 'Cannot exceed purchased quantity of ($purchaseQty)';
        }
        return null;
      },
      onChanged: (value) {
        final qty = double.tryParse(value) ?? returnQty;
        final safeQty = (qty.clamp(0, purchaseQty)).toDouble();
        onUpdate(itemId, purchaseQty, safeQty);
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
          'Purchase Returns',
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
                color: Colors.orange.shade800.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_return, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchase Returns',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Process returns to suppliers',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: _buildAppBarActions(),
        bottom: _isMobileView && _selectedTransaction != null && !_showTransactionList
            ? TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Items'),
            Tab(text: 'Reasons'),
            Tab(text: 'Summary'),
          ],
        )
            : null,
      ),
      body: Form(
        key: _purchasereturnFormKey,
        child:_isMobileView ? _buildMobileLayout() : _buildDesktopLayout(),
      ));
  }

  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[
      if (_selectedTransaction != null && _isMobileView)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white70),
          ),
          onPressed: _resetReturn,
          tooltip: 'Back to search',
        ),
      if (_selectedTransaction != null && !_isMobileView)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close, color: Colors.white70),
          ),
          onPressed: _resetReturn,
          tooltip: 'Clear selection',
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
        onPressed: _clearSearch,
        tooltip: 'Clear search',
      ),
      const SizedBox(width: 8),
    ];

    return actions;
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel - Search and Results
        _buildSearchPanel(),

        // Right Panel - Return Form
        if (_selectedTransaction != null)
          _buildReturnPanel()
        else
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildSearchPanel() {
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
          // Search Header
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
                const Text(
                  'Find Purchase Invoice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // Invoice Search Field with Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _invoiceSearchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter invoice number...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          prefixIcon: const Icon(Icons.receipt, color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF1E3A5A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _searchInvoice(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSearching ? null : _searchInvoice,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: _isSearching
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.search, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Clear button
                if (purchaseTransactions.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear, size: 16, color: Colors.white70),
                    label: const Text(
                      'Clear results',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),

          // Results Section
          if (purchaseTransactions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2A3C),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Search Result',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${purchaseTransactions.length} found',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Transactions List
          Expanded(
            child: purchaseTransactions.isEmpty
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
                      Icons.search_off,
                      size: 48,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No invoice loaded',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter an invoice number and click search',
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
              itemCount: purchaseTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final transaction = purchaseTransactions[index];
                final isSelected = _selectedTransactionId == transaction.docId;
                return _buildTransactionCard(transaction, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(StockModel transaction, bool isSelected) {
    final items = transaction.items;
    final totalItems = items.length;
    final purchasereturn = transaction.purchasereturn;
    final date = transaction.createdAt;

    Color getStatusColor() {
      if (purchasereturn == true) return Colors.green;
      if (purchasereturn == false) return Colors.orange;
      return Colors.grey;
    }

    return GestureDetector(
      onTap: () => _selectTransaction(transaction.docId, transaction),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade800.withOpacity(0.3),
              Colors.orange.shade900.withOpacity(0.3),
            ],
          )
              : null,
          color: isSelected ? null : const Color(0xFF0D2A3C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.orange.shade400
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
                      purchasereturn == true ? Icons.check_circle :
                      purchasereturn == false ? Icons.pending : Icons.shopping_cart,
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
                          transaction.supplierName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invoice: ${transaction.invoice}',
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
                      purchasereturn == true ? 'Returned' :
                      purchasereturn == false ? 'Pending' : 'New',
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
                        _dateFormat.format(date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt,
                        size: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Waybill: ${transaction.waybill}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'GHS ${(transaction.gross).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
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
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedTransaction != null && !_showTransactionList) {
      return _buildMobileReturnPanel();
    }

    return _buildMobileSearchPanel();
  }

  Widget _buildMobileSearchPanel() {
    return Column(
      children: [
        // Search Section
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
              const Text(
                'Find Purchase Invoice',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _invoiceSearchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter invoice number...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.receipt, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF1E3A5A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _searchInvoice(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSearching ? null : _searchInvoice,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: _isSearching
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.search, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (purchaseTransactions.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.clear, size: 16, color: Colors.white70),
                  label: const Text('Clear', style: TextStyle(color: Colors.white70)),
                ),
            ],
          ),
        ),

        if (purchaseTransactions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0D2A3C),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Result',
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${purchaseTransactions.length} invoice found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: purchaseTransactions.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No invoice loaded',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter invoice number and tap search',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: purchaseTransactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final transaction = purchaseTransactions[index];
              final isSelected = _selectedTransactionId == transaction.docId;
              return _buildMobileTransactionCard(transaction, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTransactionCard(StockModel transaction, bool isSelected) {
    final items = transaction.items;
    final totalItems = items.length;
    final purchasereturn = transaction.purchasereturn;
    final date = transaction.createdAt;

    return GestureDetector(
      onTap: () => _selectTransaction(transaction.docId, transaction),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade800.withOpacity(0.3),
              Colors.orange.shade900.withOpacity(0.3),
            ],
          )
              : null,
          color: isSelected ? null : const Color(0xFF0D2A3C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.orange.shade400
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
                      color: purchasereturn == true ? Colors.green.withOpacity(0.2) :
                      purchasereturn == false ? Colors.orange.withOpacity(0.2) :
                      Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      purchasereturn == true ? Icons.check_circle :
                      purchasereturn == false ? Icons.pending : Icons.shopping_cart,
                      color: purchasereturn == true ? Colors.green :
                      purchasereturn == false ? Colors.orange : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.supplierName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invoice: ${transaction.invoice}',
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
                    Icons.receipt,
                    'Waybill: ${transaction.waybill}',
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
                    _dateFormat.format(date),
                    Colors.orange,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: purchasereturn == true ? Colors.green.withOpacity(0.2) :
                      purchasereturn == false ? Colors.orange.withOpacity(0.2) :
                      Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: purchasereturn == true ? Colors.green.withOpacity(0.3) :
                        purchasereturn == false ? Colors.orange.withOpacity(0.3) :
                        Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          purchasereturn == true ? Icons.check_circle :
                          purchasereturn == false ? Icons.pending : Icons.schedule,
                          size: 14,
                          color: purchasereturn == true ? Colors.green :
                          purchasereturn == false ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          purchasereturn == true ? 'Returned' :
                          purchasereturn == false ? 'Pending' : 'New',
                          style: TextStyle(
                            color: purchasereturn == true ? Colors.green :
                            purchasereturn == false ? Colors.orange : Colors.grey,
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

  Widget _buildMobileReturnPanel() {
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
                          _selectedTransaction!.supplierName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invoice: ${_selectedTransaction!.invoice}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Waybill: ${_selectedTransaction!.waybill}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
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

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMobileItemsTab(),
              _buildMobileReasonsTab(),
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
                    onPressed: _resetReturn,
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
                if (_returnItems.values.any((item) => (item['returned'] ?? 0) > 0))
                  SizedBox(
                    width: 150,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
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
                        : const Icon(Icons.assignment_return, size: 18),
                    label: Text(
                      style: TextStyle(color: Colors.white),
                      _isLoading ? 'Processing...' : 'Process Return',
                    ),
                  ),)
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileItemsTab() {
    final items = _selectedTransaction!.items;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final itemId = item.itemId;
        final purchasedQty = item.quantity.toDouble();
        final returnData = _returnItems[itemId];
        final returnedQty = returnData?['returned'] ?? 0;
        final returnedpcs = returnData?['returnpieces'] ?? 0;
        final price = item.price.toDouble();
        final controllerid='$_selectedTransactionId$index';
        _returncontrollers[controllerid] ??= TextEditingController( text: returnedQty.toStringAsFixed(0) );

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D2A3C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: returnedQty > 0
                  ? (returnedQty == purchasedQty ? Colors.green : Colors.orange)
                  : Colors.white.withOpacity(0.1),
              width: returnedQty > 0 ? 1.5 : 1,
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
                        color: Colors.orange.shade900.withOpacity(0.3),
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
                            item.item,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.barcode != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Barcode: ${item.barcode}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchased',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            purchasedQty.toStringAsFixed(0),
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
                            'Return',
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
                                  color: const Color(0xFF1E3A5A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: returnedQty > 0
                                        ? (returnedQty == purchasedQty
                                        ? Colors.green
                                        : Colors.orange)
                                        : Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: buildSupplyField(controller:_returncontrollers[controllerid]!, purchaseQty: purchasedQty, returnQty: returnedQty, itemId: itemId, dbstatus: 'pending', onUpdate: (String itemId, double purchaseQty, double safeQty) {
                                  _updateReturnQuantity(itemId, purchaseQty, safeQty);
                                })
                              ),

                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (returnedQty > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        size: 14,
                        color: Colors.orange.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Return Value: GHS ${(returnedpcs * price).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileReasonsTab() {
    final items = _selectedTransaction!.items;
    final itemsWithReturns = items.where((item) {
      final returnData = _returnItems[item.itemId];
      return (returnData?['returned'] ?? 0) > 0;
    }).toList();

    if (itemsWithReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No items selected for return',
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
      itemCount: itemsWithReturns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = itemsWithReturns[index];
        final itemId = item.itemId;
        final returnData = _returnItems[itemId]!;
        final returnedQty = returnData['returned'] ?? 0;
        final currentReason = returnData['reason'] ?? '';

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D2A3C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: currentReason.isNotEmpty ? Colors.orange : Colors.white.withOpacity(0.1),
              width: currentReason.isNotEmpty ? 1.5 : 1,
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
                        item.item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Qty: ${returnedQty.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showReasonSelector(itemId, currentReason),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: currentReason.isNotEmpty ? Colors.orange : Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          currentReason.isNotEmpty ? Icons.check_circle : Icons.info,
                          size: 16,
                          color: currentReason.isNotEmpty ? Colors.orange : Colors.white70,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Return Reason',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentReason.isNotEmpty ? currentReason : 'Tap to select reason',
                                style: TextStyle(
                                  color: currentReason.isNotEmpty ? Colors.white : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: currentReason.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      ],
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

  Widget _buildMobileSummaryTab() {
    final items = _selectedTransaction!.items;
    final totalItems = items.length;
    final returnedItems = _returnItems.values.where((item) => (item['returned'] ?? 0) > 0).length;
    final totalPurchased = items.fold(0.0, (sum, item) => sum + item.quantity.toDouble());
    final totalReturned = _returnItems.values.fold(0.0,
            (sum, item) => sum + (item['returned'] ?? 0));
    final returnValue = _calculateReturnValue();

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.summarize, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Return Summary',
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
                  returnedItems as double,
                  totalItems as double,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildSummaryProgress(
                  'Quantity Progress',
                  totalReturned,
                  totalPurchased,
                  Colors.orange,
                ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Return Details',
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
                  controller: _returnNumberController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Return Number (Optional)',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    hintText: 'Enter return reference',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                    ),
                    prefixIcon: const Icon(Icons.numbers, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E3A5A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please select a return date';
                    }
                    return null;
                  },
                  controller: _dateController,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Return Date',
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
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.orange,
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
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    hintText: 'Add any return notes...',
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
                    Icon(Icons.attach_money, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Financial Summary',
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
                  'Total Purchase',
                  'GHS ${(_selectedTransaction!.gross).toStringAsFixed(2)}',
                  Icons.shopping_cart,
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Return Value',
                  'GHS ${returnValue.toStringAsFixed(2)}',
                  Icons.assignment_return,
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Net Payable',
                  'GHS ${((_selectedTransaction!.gross) - returnValue).toStringAsFixed(2)}',
                  Icons.account_balance,
                  Colors.green,
                  highlight: true,
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

  Widget _buildInfoRow(String label, String value, IconData icon, Color color, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
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
            color: highlight ? color : Colors.white,
            fontSize: 13,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildReturnPanel() {
    final items = _selectedTransaction!.items;
    final returnValue = _calculateReturnValue();

    final reasons = Provider.of<Datafeed>(context, listen: false).returnitemreasons;
    return Expanded(
      child: Container(
        color: const Color(0xFF0F1E2E),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.assignment_return,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice: ${_selectedTransaction!.invoice}',
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
                                Icons.business,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedTransaction!.supplierName,
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
                                Icons.receipt,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Waybill: ${_selectedTransaction!.waybill}',
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
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Purchase Items',
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
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: _tableHeaderCell('Item')),
                                Expanded(flex: 1, child: _tableHeaderCell('Mode', align: TextAlign.center)),
                                Expanded(flex: 1, child: _tableHeaderCell('Purchased', align: TextAlign.right)),
                                Expanded(flex: 2, child: _tableHeaderCell('Return Qty', align: TextAlign.right)),
                                Expanded(flex: 1, child: _tableHeaderCell('Reason', align: TextAlign.center)),
                              ],
                            ),
                          ),

                          ...items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final itemId = item.itemId;
                            final purchasedQty = item.quantity.toDouble();
                            final returnData = _returnItems[itemId];
                            final returnedQty = returnData?['returned'] ?? 0;
                            final currentReason = returnData?['reason'];
                            final controllerid='$_selectedTransactionId$index';
                            _returncontrollers[controllerid] ??= TextEditingController( text: returnedQty.toStringAsFixed(0) );

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
                                          item.item,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (item.barcode != null)
                                          Text(
                                            'Barcode: ${item.barcode}',
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
                                        color: Colors.orange.shade900.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        item.stockingMode,
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
                                      purchasedQty.toStringAsFixed(0),
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
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E3A5A),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: returnedQty > 0
                                                  ? (returnedQty == purchasedQty
                                                  ? Colors.green
                                                  : Colors.orange)
                                                  : Colors.white.withOpacity(0.2),
                                            ),
                                          ),
                                          child: buildSupplyField(controller:_returncontrollers[controllerid]!, purchaseQty: purchasedQty, returnQty: returnedQty, itemId: itemId, dbstatus: 'pending', onUpdate: (String itemId, double purchaseQty, double safeQty) {
                                            _updateReturnQuantity(itemId, purchaseQty, safeQty);
                                          })
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 1,
                                    child: SizedBox(
                                      width: 120,
                                      child: DropdownButtonFormField<String>(
                                        value: reasons.contains(currentReason)
                                            ? currentReason
                                            : null,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF1E3A5A),
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          filled: true,
                                          fillColor: const Color(0xFF1E3A5A),
                                        ),
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        iconEnabledColor: Colors.white54,
                                        items: reasons.map((cat) {
                                          return DropdownMenuItem(
                                            value: cat.name,
                                            child: Text(
                                              cat.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _updateReturnReason(itemId, value);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),

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
                                      '${_returnItems.values.where((item) => (item['returned'] ?? 0) > 0).length} of ${items.length} items returned',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Return Value: GHS ${returnValue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.orange,
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
                            'Return Information',
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
                                  controller: _returnNumberController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Return Number',
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    hintText: 'Enter return reference',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    prefixIcon: const Icon(Icons.numbers, color: Colors.white70),
                                    filled: true,
                                    fillColor: const Color(0xFF1E3A5A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please select a return date';
                                    }
                                    return null;
                                  },
                                  controller: _dateController,
                                  readOnly: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Return Date',
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
                                      lastDate: DateTime.now(),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.dark(
                                              primary: Colors.orange,
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
                                  controller: _notesController,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Notes',
                                    labelStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    hintText: 'Add any return notes...',
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
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2A3C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Financial Summary',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildSummaryRow(
                                  'Total Purchase',
                                  'GHS ${(_selectedTransaction!.gross).toStringAsFixed(2)}',
                                ),
                                const SizedBox(height: 8),
                                _buildSummaryRow(
                                  'Return Value',
                                  'GHS ${returnValue.toStringAsFixed(2)}',
                                  valueColor: Colors.orange,
                                ),
                                const Divider(color: Colors.white24, height: 16),
                                _buildSummaryRow(
                                  'Net Payable',
                                  'GHS ${(_selectedTransaction!.gross - returnValue).toStringAsFixed(2)}',
                                  valueColor: Colors.green,
                                  bold: true,
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
                    onPressed: _resetReturn,
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
                  if (_returnItems.values.any((item) => (item['returned'] ?? 0) > 0))
                    SizedBox(
                      width: 150,
                   child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitReturn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
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
                          : const Icon(Icons.save),
                      label: Text(
                        style: TextStyle(color: Colors.white),
                        _isLoading ? 'Processing...' : 'Save',
                      ),
                    ),)
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
                  Icons.search,
                  size: 64,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Search for an Invoice',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter an invoice number and click search',
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

  Widget _tableHeaderCell(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      textAlign: align,
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool bold = false}) {
    return Row(
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
            color: valueColor ?? Colors.white,
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}