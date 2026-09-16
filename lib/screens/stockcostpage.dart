import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ItemStockCostPage extends StatefulWidget {
  final String companyId;
  final String itemId;
  final String itemName;

  const ItemStockCostPage({
    super.key,
    required this.companyId,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<ItemStockCostPage> createState() => _ItemStockCostPageState();
}

class _ItemStockCostPageState extends State<ItemStockCostPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  bool loading = true;
  bool updatingCp = false;

  List<Map<String, dynamic>> transactions = [];

  double totalPieces = 0;
  double totalStockValue = 0;
  double calculatedCp = 0;

  double? currentCp;

  @override
  void initState() {
    super.initState();
    loadItemTransactions();
  }

  // ============================================================
  // LOAD ALL TRANSACTIONS FOR THE ITEM
  // ============================================================

  Future<void> loadItemTransactions() async {
    setState(() {
      loading = true;
      transactions.clear();
      totalPieces = 0;
      totalStockValue = 0;
      calculatedCp = 0;
    });

    try {
      /*
       * We cannot use:
       *
       * where('items', arrayContains: {'itemid': widget.itemId})
       *
       * because Firestore arrayContains requires the COMPLETE map
       * to match.
       *
       * Therefore we query the company's transactions and inspect
       * the items array locally.
       */

      final snapshot = await db
          .collection('stock_transactions')
          .where(
        'companyid',
        isEqualTo: widget.companyId,
      ).get();

      double piecesTotal = 0;
      double valueTotal = 0;

      final List<Map<String, dynamic>> results = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final dynamic rawItems = data['items'];
        //print('rawItems: $rawItems');

        if (rawItems is! List) {
          continue;
        }

        for (final rawItem in rawItems) {
          if (rawItem is! Map) {
            continue;
          }

          final item = Map<String, dynamic>.from(rawItem);

          final itemId = item['itemid']?.toString();

          if (itemId != widget.itemId) {
            continue;
          }

          // ------------------------------------------------------
          // PIECES
          // ------------------------------------------------------

          final double pieces =
          _toDouble(item['pieces']);

          // ------------------------------------------------------
          // PRICE
          // ------------------------------------------------------

          final double price =
          _toDouble(item['price']);

          // ------------------------------------------------------
          // TOTAL VALUE
          // ------------------------------------------------------

          final double stockValue = price * pieces;

          piecesTotal += pieces;
          valueTotal += stockValue;

          results.add({
            'docid': doc.id,
            'transactionid':
            data['transactionid'] ?? data['docid'] ?? doc.id,

            'date': data['date'],

            'createdat': data['createdat'],

            'suppliername':
            data['suppliername'] ?? '',

            'supplierid':
            data['supplierid'] ?? '',

            'waybill':
            data['waybill'] ?? '',

            'purchasetype':
            data['purchasetype'] ?? '',

            'pieces': pieces,

            'price': price,

            'stockValue': stockValue,

            'oldPieces':
            _toDouble(item['oldPieces']),

            'barcode':
            item['barcode'] ?? '',

            'item':
            item['item'] ?? widget.itemName,
          });
        }
      }

      // Sort newest first
      results.sort((a, b) {
        final aDate = a['date']?.toString() ?? '';
        final bDate = b['date']?.toString() ?? '';

        return bDate.compareTo(aDate);
      });

      final double cp =
      piecesTotal > 0
          ? valueTotal / piecesTotal
          : 0;

      // Load current CP
      double? existingCp;

      final itemDoc = await db
          .collection('itemsreg')
          .doc(widget.itemId)
          .get();

      if (itemDoc.exists) {
        final itemData = itemDoc.data();

        if (itemData != null) {
          existingCp = _toDoubleNullable(itemData['cp']);
        }
      }

      if (!mounted) return;

      setState(() {
        transactions = results;

        totalPieces = piecesTotal;
        totalStockValue = valueTotal;
        calculatedCp = cp;

        currentCp = existingCp;

        loading = false;
      });
    } catch (e, stack) {
      debugPrint('loadItemTransactions error: $e');
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Failed to load item transactions: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // UPDATE CP
  // ============================================================

  Future<void> updateItemCp() async {
    if (totalPieces <= 0) {
      showMessage(
        'Cannot calculate CP because total pieces is zero.',
        error: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Update Item CP',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 20),

              _dialogRow(
                'Total Pieces',
                NumberFormat('#,##0.##')
                    .format(totalPieces),
              ),

              _dialogRow(
                'Total Stock Value',
                NumberFormat('#,##0.00')
                    .format(totalStockValue),
              ),

              _dialogRow(
                'Current CP',
                currentCp == null
                    ? 'Not set'
                    : NumberFormat('#,##0.00')
                    .format(currentCp),
              ),

              const Divider(),

              _dialogRow(
                'New CP',
                NumberFormat('#,##0.00')
                    .format(calculatedCp),
                bold: true,
              ),

              const SizedBox(height: 15),

              const Text(
                'The item CP will be updated using:',
                style: TextStyle(
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                'Total Stock Value ÷ Total Pieces',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('CANCEL',style: TextStyle(color: Colors.white)),
            ),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.update),
              label: const Text('UPDATE CP',style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      updatingCp = true;
    });

    try {
      await db
          .collection('itemsreg')
          .doc(widget.itemId)
          .update({
        'cp': calculatedCp,
        'cpUpdatedAt': FieldValue.serverTimestamp(),
        'cpUpdateSource': 'stock_transaction_average',
      });

      if (!mounted) return;

      setState(() {
        currentCp = calculatedCp;
        updatingCp = false;
      });

      showMessage(
        'Item CP updated successfully to ${calculatedCp.toStringAsFixed(2)}',
      );
    } catch (e, stack) {
      debugPrint('updateItemCp error: $e');
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      setState(() {
        updatingCp = false;
      });

      showMessage(
        'Failed to update CP: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().replaceAll(',', ''),
    ) ??
        0;
  }

  double? _toDoubleNullable(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().replaceAll(',', ''),
    );
  }

  String money(double value) {
    return NumberFormat('#,##0.00').format(value);
  }

  String number(double value) {
    return NumberFormat('#,##0.##').format(value);
  }

  Widget _dialogRow(
      String title,
      String value, {
        bool bold = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value,
            style: TextStyle(
              fontWeight:
              bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void showMessage(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        error ? Colors.red : Colors.green,
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.04),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.blue,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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

  // ============================================================
  // TRANSACTION TABLE
  // ============================================================

  Widget buildTransactionTable() {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: const [
            Icon(
              Icons.inventory_2_outlined,
              size: 50,
              color: Colors.grey,
            ),
            SizedBox(height: 10),
            Text(
              'No transactions found for this item.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
        WidgetStateProperty.all(
          Colors.grey.shade100,
        ),
        columnSpacing: 30,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('DATE')),
          DataColumn(label: Text('TRANSACTION')),
          DataColumn(label: Text('SUPPLIER')),
          DataColumn(label: Text('WAYBILL')),
          DataColumn(label: Text('PIECES')),
          DataColumn(label: Text('PRICE')),
          DataColumn(label: Text('STOCK VALUE')),
        ],
        rows: List.generate(
          transactions.length,
              (index) {
            final tx = transactions[index];

            return DataRow(
              cells: [
                DataCell(
                  Text('${index + 1}', style: TextStyle(color: Colors.black)),

                ),

                DataCell(
                  Text(
                    tx['date']?.toString() ?? '', style: TextStyle(color: Colors.black)
                  ),
                ),

                DataCell(
                  Text(
                    tx['transactionid']
                        ?.toString() ??
                        '', style: TextStyle(color: Colors.black)
                  ),
                ),

                DataCell(
                  Text(
                    tx['suppliername']
                        ?.toString() ??
                        '', style: TextStyle(color: Colors.black)
                  ),
                ),

                DataCell(
                  Text(
                    tx['waybill']
                        ?.toString() ??
                        '', style: TextStyle(color: Colors.black)
                  ),
                ),

                DataCell(
                  Text(
                    number(
                      tx['pieces'] ?? 0,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black
                    ),
                  ),
                ),

                DataCell(
                  Text(
                    money(
                      tx['price'] ?? 0,

                    ),
                style: TextStyle(color: Colors.black)
                  ),
                ),

                DataCell(
                  Text(
                    money(
                      tx['stockValue'] ?? 0,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),

      appBar: AppBar(
        title: const Text(
          'Item Stock Cost Analysis',
        ),
        centerTitle: false,
        backgroundColor:
        const Color(0xFF0D1A26),
        foregroundColor: Colors.white,

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
            loading ? null : loadItemTransactions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: loadItemTransactions,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ==================================================
            // ITEM HEADER
            // ==================================================

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue
                          .withOpacity(0.1),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Item ID: ${widget.itemId}',
                          style: TextStyle(
                            color:
                            Colors.black,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          'Company: ${widget.companyId}',
                          style: TextStyle(
                            color:
                            Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // SUMMARY
            // ==================================================

            Row(
              children: [
                buildSummaryCard(
                  title: 'TOTAL PIECES',
                  value: number(totalPieces),
                  icon: Icons.inventory,
                ),

                buildSummaryCard(
                  title: 'TOTAL STOCK VALUE',
                  value: money(totalStockValue),
                  icon: Icons.account_balance_wallet,
                ),

                buildSummaryCard(
                  title: 'CURRENT CP',
                  value: currentCp == null
                      ? 'Not set'
                      : money(currentCp!),
                  icon: Icons.price_check,
                ),

                buildSummaryCard(
                  title: 'CALCULATED CP',
                  value: money(calculatedCp),
                  icon: Icons.calculate,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ==================================================
            // CP UPDATE SECTION
            // ==================================================

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate,
                    color: Colors.blue,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weighted Average Cost',
                          style: TextStyle(
                            fontWeight:
                            FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'CP = Total Stock Value ÷ Total Pieces',
                          style: TextStyle(
                            color:
                            Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    money(calculatedCp),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 20),

                  ElevatedButton.icon(
                    onPressed: updatingCp
                        ? null
                        : updateItemCp,
                    icon: updatingCp
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.update,
                    ),
                    label: Text(
                      updatingCp
                          ? 'Updating...'
                          : 'Update Item CP',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // TRANSACTIONS
            // ==================================================

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                    const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                        ),

                        const SizedBox(width: 10),

                        const Text(
                          'Stock Transactions',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          '${transactions.length} transaction${transactions.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color:
                            Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  buildTransactionTable(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}