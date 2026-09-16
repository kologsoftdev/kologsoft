import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/StockProvider.dart';

class StockCostAnalysisPage extends StatefulWidget {
  const StockCostAnalysisPage({
    super.key,
  });

  @override
  State<StockCostAnalysisPage> createState() =>
      _StockCostAnalysisPageState();
}

class _StockCostAnalysisPageState
    extends State<StockCostAnalysisPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  final TextEditingController _searchController =
  TextEditingController();

  bool loading = true;
  bool updatingCp = false;

  List<ItemCostSummary> allItems = [];
  List<ItemCostSummary> filteredItems = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterItems);

    loadStockTransactions();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD STOCK TRANSACTIONS
  // ============================================================

  Future<void> loadStockTransactions() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final provider =
      Provider.of<StockProvider>(context, listen: false);

      await provider.getdata();

      final snapshot = await db
          .collection('stock_transactions')
          .where(
        'companyid',
        isEqualTo: provider.companyid,
      ).get();

      // ==========================================================
      // GROUP TRANSACTIONS BY ITEM ID
      // ==========================================================

      final Map<String, ItemCostSummary> groupedItems = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final dynamic rawItems = data['items'];

        if (rawItems is! List) {
          continue;
        }

        for (final rawItem in rawItems) {
          if (rawItem is! Map) {
            continue;
          }

          final item =
          Map<String, dynamic>.from(rawItem);

          final String itemId =
              item['itemid']?.toString() ?? '';

          if (itemId.isEmpty) {
            continue;
          }

          final String itemName =
              item['item']?.toString() ?? '';

          final String barcode =
              item['barcode']?.toString() ?? '';

          // ======================================================
          // CREATE ITEM GROUP
          // ======================================================

          final summary = groupedItems.putIfAbsent(
            itemId,
                () => ItemCostSummary(
              itemId: itemId,
              itemName: itemName,
              barcode: barcode,
            ),
          );

          // ======================================================
          // PIECES
          // ======================================================

          final double pieces =
          _toDouble(item['pieces']);

          // ======================================================
          // PRICE / COST PRICE
          // ======================================================

          final double price =
          _toDouble(item['price']);

          // ======================================================
          // STOCK VALUE
          //
          // Stock Value = Pieces × Price
          // ======================================================

          final double stockValue =
              pieces * price;

          // ======================================================
          // ADD TO TOTALS
          // ======================================================

          summary.totalPieces += pieces;

          summary.totalStockValue += stockValue;

          // ======================================================
          // TRANSACTION DETAIL
          // ======================================================

          summary.transactions.add(
            StockTransactionDetail(
              transactionId:
              data['transactionid']?.toString() ??
                  data['docid']?.toString() ??
                  doc.id,

              documentId: doc.id,

              date:
              data['date']?.toString() ?? '',

              supplierName:
              data['suppliername']?.toString() ?? '',

              supplierId:
              data['supplierid']?.toString() ?? '',

              waybill:
              data['waybill']?.toString() ?? '',

              purchaseType:
              data['purchasetype']?.toString() ?? '',

              pieces: pieces,

              price: price,

              stockValue: stockValue,

              oldPieces:
              _toDouble(item['oldPieces']),
            ),
          );
        }
      }

      // ==========================================================
      // LOAD CURRENT CP FROM ITEMSREG
      // ==========================================================
      // ==========================================================
// LOAD CURRENT CP FROM ITEMSREG IN BATCHES
// ==========================================================

      final itemsList = groupedItems.values.toList();

      const int batchSize = 30;

      for (int start = 0;
      start < itemsList.length;
      start += batchSize) {

        final end = (start + batchSize > itemsList.length)
            ? itemsList.length
            : start + batchSize;

        final batchItems = itemsList.sublist(start, end);

        final itemIds = batchItems
            .map((item) => item.itemId)
            .where((id) => id.isNotEmpty)
            .toList();

        if (itemIds.isEmpty) {
          continue;
        }

        try {
          final cpSnapshot = await db
              .collection('itemsreg')
              .where(
            FieldPath.documentId,
            whereIn: itemIds,
          )
              .get();

          // Map the returned documents by ID
          final Map<String, double?> cpMap = {};

          for (final doc in cpSnapshot.docs) {
            final data = doc.data();

            cpMap[doc.id] = _toDoubleNullable(data['cp']);
          }

          // Apply CP to our grouped items
          for (final item in batchItems) {
            if (cpMap.containsKey(item.itemId)) {
              item.currentCp = cpMap[item.itemId];
            }
          }
        } catch (e) {
          debugPrint(
            'Error loading CP batch: $e',
          );
        }
      }

      // for (final item in groupedItems.values) {
      //   try {
      //     final itemDoc = await db.collection('itemsreg').doc(item.itemId).get();
      //
      //     if (itemDoc.exists) {
      //       final data = itemDoc.data();
      //
      //       if (data != null) {
      //         item.currentCp =
      //             _toDoubleNullable(data['cp']);
      //       }
      //     }
      //   } catch (e) {
      //     debugPrint(
      //       'Error loading CP for ${item.itemId}: $e',
      //     );
      //   }
      // }

      // ==========================================================
      // ONLY KEEP ITEMS WHERE CP IS DIFFERENT
      //
      // Items without a CP are excluded because this page is
      // specifically for correcting existing CP differences.
      // ==========================================================

      final List<ItemCostSummary> result =
      groupedItems.values.where((item) {
        if (item.currentCp == null) {
          return false;
        }

        return (item.currentCp! -
            item.calculatedCp)
            .abs() >
            0.001;
      }).toList();

      // ==========================================================
      // SORT BY ITEM NAME
      // ==========================================================

      result.sort(
            (a, b) => a.itemName
            .toLowerCase()
            .compareTo(
          b.itemName.toLowerCase(),
        ),
      );

      if (!mounted) return;

      setState(() {
        allItems = result;
        filteredItems = result;
        loading = false;
      });
    } catch (e, stack) {
      debugPrint(
        'loadStockTransactions error: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Failed to load stock transactions: $e',
        error: true,
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _filterItems() {
    final query =
    _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredItems = allItems;
      });

      return;
    }

    setState(() {
      filteredItems = allItems.where((item) {
        return item.itemName
            .toLowerCase()
            .contains(query) ||
            item.itemId
                .toLowerCase()
                .contains(query) ||
            item.barcode
                .toLowerCase()
                .contains(query);
      }).toList();
    });
  }

  // ============================================================
  // CHECK CP DIFFERENCE
  // ============================================================

  bool hasCpDifference(ItemCostSummary item) {
    if (item.currentCp == null) {
      return false;
    }

    return (item.currentCp! -
        item.calculatedCp)
        .abs() >
        0.001;
  }

  // ============================================================
  // UPDATE ITEM CP
  // ============================================================

  Future<void> updateItemCp(
      ItemCostSummary item,
      ) async {
    if (item.totalPieces <= 0) {
      showMessage(
        'Cannot calculate CP because total pieces is zero.',
        error: true,
      );

      return;
    }

    final double newCp = double.parse(item.calculatedCp.toStringAsFixed(2));

    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Update Item CP',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                item.itemId,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              _dialogRow(
                'Total Pieces',
                number(item.totalPieces),
              ),

              _dialogRow(
                'Total Stock Value',
                money(item.totalStockValue),
              ),

              _dialogRow(
                'Current CP',
                item.currentCp == null
                    ? 'Not set'
                    : money(item.currentCp!),
              ),

              const Divider(),

              _dialogRow(
                'Calculated CP',
                money(newCp),
                bold: true,
              ),

              if (item.currentCp != null) ...[
                const SizedBox(height: 5),

                _dialogRow(
                  'Difference',
                  money(
                    newCp - item.currentCp!,
                  ),
                ),
              ],

              const SizedBox(height: 15),

              Container(
                padding:
                const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue
                      .withOpacity(0.08),
                  borderRadius:
                  BorderRadius.circular(8),
                ),
                child: const Text(
                  'CP will be calculated as:\n'
                      'Total Stock Value ÷ Total Pieces',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              icon: const Icon(
                Icons.update,
              ),
              label: const Text(
                'UPDATE CP',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
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
      // ========================================================
      // ONLY UPDATE CP AND CP UPDATED TIME
      //
      // Other fields in itemsreg remain untouched.
      // ========================================================

      await db
          .collection('itemsreg')
          .doc(item.itemId)
          .update({
        'cp': newCp,
        'cpUpdatedAt':
        FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // ========================================================
      // REMOVE ITEM FROM LOCAL LIST
      //
      // Since its CP is now equal to the calculated CP,
      // it no longer belongs on this page.
      // ========================================================

      setState(() {
        allItems.removeWhere(
              (existingItem) =>
          existingItem.itemId ==
              item.itemId,
        );

        filteredItems.removeWhere(
              (existingItem) =>
          existingItem.itemId ==
              item.itemId,
        );

        updatingCp = false;
      });

      showMessage(
        '${item.itemName} CP updated to ${money(newCp)}',
      );
    } catch (e, stack) {
      debugPrint(
        'updateItemCp error: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

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
  // SUMMARY
  // ============================================================

  double get grandTotalPieces {
    return filteredItems.fold(
      0,
          (sum, item) =>
      sum + item.totalPieces,
    );
  }

  double get grandTotalValue {
    return filteredItems.fold(
      0,
          (sum, item) =>
      sum + item.totalStockValue,
    );
  }

  int get totalTransactions {
    return filteredItems.fold(
      0,
          (sum, item) =>
      sum + item.transactions.length,
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
        margin:
        const EdgeInsets.only(right: 10),
        padding:
        const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black
                  .withOpacity(0.04),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding:
              const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue
                    .withOpacity(0.1),
                borderRadius:
                BorderRadius.circular(10),
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
                      color: Colors
                          .grey.shade600,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.bold,
                      color: Colors.black,
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
  // ITEM ROW
  // ============================================================

  Widget buildItemRow(
      ItemCostSummary item,
      int index,
      ) {
    // Safety check.
    // Normally every item here already has a difference
    // because loadStockTransactions filters them.
    if (!hasCpDifference(item)) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      tilePadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      childrenPadding:
      const EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 15,
      ),

      leading: CircleAvatar(
        radius: 16,
        backgroundColor:
        Colors.blue.withOpacity(0.1),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      title: Text(
        item.itemName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),

      subtitle: Padding(
        padding:
        const EdgeInsets.only(top: 4),
        child: Text(
          '${item.itemId} • ${item.barcode}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ),

      trailing: SizedBox(
        width: 920,

        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.end,

          children: [
            _tableValue(
              number(
                item.transactions.length
                    .toDouble(),
              ),
            ),

            _tableValue(
              number(item.totalPieces),
            ),

            _tableValue(
              money(item.totalStockValue),
            ),

            SizedBox(
              width: 90,
              child: Text(
                item.currentCp == null
                    ? '-'
                    : money(item.currentCp!),
                textAlign:
                TextAlign.right,
                style: TextStyle(
                  fontWeight:
                  FontWeight.w500,
                  color:
                  Colors.orange.shade800,
                ),
              ),
            ),

            SizedBox(
              width: 100,
              child: Text(
                money(item.calculatedCp),
                textAlign:
                TextAlign.right,
                style: const TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            const SizedBox(width: 15),

            SizedBox(
              width: 110,
              child:
              ElevatedButton.icon(
                onPressed:
                updatingCp
                    ? null
                    : () =>
                    updateItemCp(
                      item,
                    ),

                icon: const Icon(
                  Icons.update,
                  size: 15,
                ),

                label: const Text(
                  'Update CP',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),

                style:
                ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      children: [
        buildTransactionDetails(item),
      ],
    );
  }

  // ============================================================
  // TRANSACTION DETAILS
  // ============================================================

  Widget buildTransactionDetails(
      ItemCostSummary item,
      ) {
    if (item.transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No transaction details.',
          style: TextStyle(
            color: Colors.black,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
        BorderRadius.circular(10),
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
            const EdgeInsets.all(14),

            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long,
                  size: 18,
                  color: Colors.black,
                ),

                const SizedBox(width: 8),

                const Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          SingleChildScrollView(
            scrollDirection:
            Axis.horizontal,

            child: DataTable(
              columnSpacing: 30,

              headingRowColor:
              WidgetStateProperty.all(
                Colors.grey.shade100,
              ),

              columns: const [
                DataColumn(
                  label: Text(
                    'DATE',
                    style: TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                ),

                DataColumn(
                  label: Text(
                    'TRANSACTION',
                    style: TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                ),

                DataColumn(
                  label: Text(
                    'SUPPLIER',
                    style: TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                ),

                DataColumn(
                  label: Text(
                    'WAYBILL',
                    style: TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                ),

                DataColumn(
                  label: Text(
                    'PIECES',
                    style: TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                ),

                DataColumn(
                  label: Text(
                    'PRICE',
                    style: TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                ),

                DataColumn(
                  label: Text(
                    'VALUE',
                    style: TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],

              rows: item.transactions
                  .map(
                    (tx) => DataRow(
                  cells: [
                    DataCell(
                      Text(
                        tx.date,
                        style:
                        const TextStyle(
                          color:
                          Colors.black87,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        tx.transactionId,
                        style:
                        const TextStyle(
                          color:
                          Colors.black87,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        tx.supplierName
                            .isEmpty
                            ? '-'
                            : tx.supplierName,
                        style:
                        const TextStyle(
                          color:
                          Colors.black87,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        tx.waybill.isEmpty
                            ? '-'
                            : tx.waybill,
                        style:
                        const TextStyle(
                          color:
                          Colors.black87,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        number(
                          tx.pieces,
                        ),
                        style:
                        const TextStyle(
                          color:
                          Colors.black87,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        money(
                          tx.price,
                        ),
                        style:
                        const TextStyle(
                          color:
                          Colors.black87,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        money(
                          tx.stockValue,
                        ),
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          color:
                          Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .toList(),
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding:
            const EdgeInsets.all(14),

            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.end,

              children: [
                const Text(
                  'TOTAL:',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(width: 20),

                Text(
                  '${number(item.totalPieces)} pieces',
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(width: 30),

                Text(
                  money(
                    item.totalStockValue,
                  ),
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget buildTableHeader() {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius:
        const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),

      child: Row(
        children: [
          const SizedBox(width: 48),

          const Expanded(
            flex: 4,
            child: Text(
              'ITEM',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),

          SizedBox(
            width: 80,
            child: Text(
              'TXNS',
              textAlign:
              TextAlign.right,
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),

          SizedBox(
            width: 100,
            child: Text(
              'PIECES',
              textAlign:
              TextAlign.right,
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),

          SizedBox(
            width: 130,
            child: Text(
              'STOCK VALUE',
              textAlign:
              TextAlign.right,
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),

          SizedBox(
            width: 110,
            child: Text(
              'CURRENT CP',
              textAlign:
              TextAlign.right,
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),

          SizedBox(
            width: 120,
            child: Text(
              'CALCULATED CP',
              textAlign:
              TextAlign.right,
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(width: 130),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE VALUE
  // ============================================================

  Widget _tableValue(
      String value,
      ) {
    return SizedBox(
      width: 100,
      child: Text(
        value,
        textAlign:
        TextAlign.right,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
        ),
      ),
    );
  }

  // ============================================================
  // DIALOG ROW
  // ============================================================

  Widget _dialogRow(
      String title,
      String value, {
        bool bold = false,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 5,
      ),

      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,

        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
            ),
          ),

          Text(
            value,
            style: TextStyle(
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONVERT TO DOUBLE
  // ============================================================

  double _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value
          .toString()
          .replaceAll(',', ''),
    ) ??
        0;
  }

  // ============================================================
  // CONVERT TO NULLABLE DOUBLE
  // ============================================================

  double? _toDoubleNullable(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value
          .toString()
          .replaceAll(',', ''),
    );
  }

  // ============================================================
  // MONEY FORMAT
  // ============================================================

  String money(
      double value,
      ) {
    return NumberFormat(
      '#,##0.00',
    ).format(value);
  }

  // ============================================================
  // NUMBER FORMAT
  // ============================================================

  String number(
      double value,
      ) {
    return NumberFormat(
      '#,##0.##',
    ).format(value);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor:
        error ? Colors.red : Colors.green,
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final provider =
    Provider.of<StockProvider>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor:
      const Color(0xFFF6F8FA),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Stock Cost Analysis',
        ),

        centerTitle: false,

        backgroundColor:
        const Color(0xFF0D1A26),

        foregroundColor:
        Colors.white,

        actions: [
          IconButton(
            tooltip: 'Refresh',

            onPressed:
            loading
                ? null
                : loadStockTransactions,

            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh:
        loadStockTransactions,

        child: ListView(
          padding:
          const EdgeInsets.all(20),

          children: [
            // =================================================
            // COMPANY HEADER
            // =================================================

            Container(
              padding:
              const EdgeInsets.all(
                20,
              ),

              decoration:
              BoxDecoration(
                color: Colors.white,

                borderRadius:
                BorderRadius.circular(
                  12,
                ),

                border: Border.all(
                  color:
                  Colors.grey.shade200,
                ),
              ),

              child: Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets
                        .all(
                      14,
                    ),

                    decoration:
                    BoxDecoration(
                      color: Colors.blue
                          .withOpacity(
                        0.1,
                      ),

                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),
                    ),

                    child:
                    const Icon(
                      Icons
                          .inventory_2,
                      color:
                      Colors.blue,
                      size: 30,
                    ),
                  ),

                  const SizedBox(
                    width: 15,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                      children: [
                        Text(
                          provider
                              .company,

                          style:
                          const TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight
                                .bold,
                            color:
                            Colors
                                .black,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          'Company ID: ${provider.companyid}',

                          style:
                          TextStyle(
                            color: Colors
                                .grey
                                .shade600,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          'Items with different current CP and calculated CP',

                          style:
                          TextStyle(
                            color: Colors
                                .grey
                                .shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // =================================================
            // SUMMARY CARDS
            // =================================================

            Row(
              children: [
                buildSummaryCard(
                  title: 'ITEMS',
                  value:
                  '${filteredItems.length}',
                  icon:
                  Icons.inventory_2,
                ),

                buildSummaryCard(
                  title:
                  'TOTAL PIECES',
                  value: number(
                    grandTotalPieces,
                  ),
                  icon:
                  Icons.layers,
                ),

                buildSummaryCard(
                  title:
                  'TOTAL STOCK VALUE',
                  value: money(
                    grandTotalValue,
                  ),
                  icon: Icons
                      .account_balance_wallet,
                ),

                buildSummaryCard(
                  title:
                  'TRANSACTIONS',
                  value: number(
                    totalTransactions
                        .toDouble(),
                  ),
                  icon:
                  Icons.receipt_long,
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            // =================================================
            // SEARCH
            // =================================================

            Container(
              padding:
              const EdgeInsets.all(
                15,
              ),

              decoration:
              BoxDecoration(
                color:
                Colors.white,

                borderRadius:
                BorderRadius.circular(
                  12,
                ),

                border: Border.all(
                  color:
                  Colors.grey.shade200,
                ),
              ),

              child: TextField(
                controller:
                _searchController,

                style:
                const TextStyle(
                  color: Colors.black,
                ),

                decoration:
                InputDecoration(
                  hintText:
                  'Search item name, item ID or barcode...',

                  hintStyle:
                  TextStyle(
                    color: Colors
                        .grey
                        .shade600,
                  ),

                  prefixIcon:
                  const Icon(
                    Icons.search,
                    color:
                    Colors.black54,
                  ),

                  suffixIcon:
                  _searchController
                      .text
                      .isNotEmpty
                      ? IconButton(
                    onPressed:
                        () {
                      _searchController
                          .clear();
                    },
                    icon:
                    const Icon(
                      Icons.clear,
                      color:
                      Colors.black,
                    ),
                  )
                      : null,

                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      10,
                    ),
                  ),

                  filled: true,

                  fillColor:
                  Colors.grey
                      .shade50,
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // =================================================
            // ITEMS TABLE
            // =================================================

            Container(
              decoration:
              BoxDecoration(
                color:
                Colors.white,

                borderRadius:
                BorderRadius.circular(
                  12,
                ),

                border: Border.all(
                  color:
                  Colors.grey.shade200,
                ),
              ),

              child: filteredItems
                  .isEmpty
                  ? Padding(
                padding:
                const EdgeInsets
                    .all(
                  50,
                ),

                child:
                Center(
                  child:
                  Column(
                    children: [
                      const Icon(
                        Icons
                            .check_circle,
                        size: 50,
                        color:
                        Colors.green,
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      const Text(
                        'No CP differences found.',
                        style:
                        TextStyle(
                          color:
                          Colors.black,
                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'All current CP values match their calculated CP.',
                        style:
                        TextStyle(
                          color: Colors
                              .grey
                              .shade600,
                          fontSize:
                          12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : Column(
                children: [
                  buildTableHeader(),

                  const Divider(
                    height: 1,
                  ),

                  ...List.generate(
                    filteredItems
                        .length,
                        (index) {
                      return Column(
                        children: [
                          buildItemRow(
                            filteredItems[
                            index],
                            index,
                          ),

                          if (index !=
                              filteredItems
                                  .length -
                                  1)
                            const Divider(
                              height:
                              1,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// ITEM COST SUMMARY MODEL
// ====================================================================

class ItemCostSummary {
  final String itemId;
  final String itemName;
  final String barcode;

  double totalPieces;
  double totalStockValue;

  double? currentCp;

  final List<
      StockTransactionDetail> transactions;

  ItemCostSummary({
    required this.itemId,
    required this.itemName,
    required this.barcode,
    this.totalPieces = 0,
    this.totalStockValue = 0,
    this.currentCp,
    List<StockTransactionDetail>?
    transactions,
  }) : transactions =
      transactions ?? [];

  // ================================================================
  // CALCULATED / WEIGHTED AVERAGE CP
  // ================================================================

  double get calculatedCp {
    if (totalPieces <= 0) {
      return 0;
    }

    return totalStockValue /
        totalPieces;
  }
}

// ====================================================================
// TRANSACTION DETAIL MODEL
// ====================================================================

class StockTransactionDetail {
  final String transactionId;
  final String documentId;

  final String date;

  final String supplierName;
  final String supplierId;

  final String waybill;
  final String purchaseType;

  final double pieces;
  final double price;
  final double stockValue;

  final double oldPieces;

  StockTransactionDetail({
    required this.transactionId,
    required this.documentId,
    required this.date,
    required this.supplierName,
    required this.supplierId,
    required this.waybill,
    required this.purchaseType,
    required this.pieces,
    required this.price,
    required this.stockValue,
    required this.oldPieces,
  });
}