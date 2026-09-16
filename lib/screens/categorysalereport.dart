import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class CategorySummaryRow {
  final String category;
  final String companyId;
  final String company;
  final double cashSales;
  final double momoSales;
  final double creditSales;
  final double cashReturns;
  final double discount;
  final double cashDiscount;
  final double creditDiscount;
  final double purchaseReturns;
  final double damages;
  final double profit;
  final double costOfGoods;
  final double  qty;
  final double transactions;
  final double salesvalue;
  final double returnvalue;

  const CategorySummaryRow({
    required this.category,
    required this.companyId,
    required this.company,
    required this.cashSales,
    required this.momoSales,
    required this.creditSales,
    required this.cashReturns,
    required this.discount,
    required this.cashDiscount,
    required this.creditDiscount,
    required this.purchaseReturns,
    required this.damages,
    required this.profit,
    required this.costOfGoods,
    required this.qty,
    required this.transactions,
    required this.salesvalue,
    required this.returnvalue,
  });

  double get totalSales => cashSales + momoSales + creditSales;
  double get cashAtHand => cashSales - cashReturns;
}

class CategoryTransactionRow {
  final String date;
  final String item;
  final double qty;
  final double price;
  final double total;
  final String transactionMode;
  final String salesMode;
  final String customer;
  final String branch;
  final String staff;
  final String time;
  final String pricingMode;
  final String pcategory;
  final bool   isReturn;

  const CategoryTransactionRow({
    required this.date,
    required this.item,
    required this.qty,
    required this.price,
    required this.total,
    required this.transactionMode,
    required this.salesMode,
    required this.customer,
    required this.branch,
    required this.staff,
    required this.time,
    required this.pricingMode,
    required this.pcategory,
    required this.isReturn,
  });
}

class CategorySalesReport extends StatefulWidget {
  const CategorySalesReport({super.key});

  @override
  State<CategorySalesReport> createState() => _CategorySalesReportState();
}

class _CategorySalesReportState extends State<CategorySalesReport> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  String? _selectedBranchname;
  String  _search = '';
  bool    _loading = false;

  List<CategorySummaryRow> _allRows  = [];
  List<CategorySummaryRow> _filtered = [];

  final _vertCtrl  = ScrollController();
  final _horizCtrl = ScrollController();

  double get _totCash     => _filtered.fold(0, (s, r) => s + r.cashSales);
  double get _totMomo     => _filtered.fold(0, (s, r) => s + r.momoSales);
  double get _totCredit   => _filtered.fold(0, (s, r) => s + r.creditSales);
  double get _totSales    => _filtered.fold(0, (s, r) => s + r.totalSales);
  double get _totReturns  => _filtered.fold(0, (s, r) => s + r.cashReturns);
  double get _totDiscount => _filtered.fold(0, (s, r) => s + r.discount);
  double get _totProfit   => _filtered.fold(0, (s, r) => s + r.profit);
  double get _totQty      => _filtered.fold(0, (s, r) => s + r.qty);
  double get _totSalesValue   => _filtered.fold(0, (s, r) => s + r.salesvalue);
  double get _totReturnValue  => _filtered.fold(0, (s, r) => s + r.returnvalue);
  double get _totCashDiscount => _filtered.fold(0, (s, r) => s + r.cashDiscount);
  double get _totCreditDiscount => _filtered.fold(0, (s, r) => s + r.creditDiscount);

  double get _totCashHand => _totCash - _totReturns;

  double _debtPayment = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask((){
      context.read<Datafeed>().fetchBranches();
      _fetch();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {

    });
  }

  @override
  void dispose() {
    _vertCtrl.dispose();
    _horizCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final provider  = context.read<Datafeed>();
      final companyId = provider.companyid;

      Query query = FirebaseFirestore.instance
          .collection('salesSummary')
          .where('companyid', isEqualTo: companyId);

      if (selectedDate != null) {
        final start = DateFormat('yyyy-MM-dd').format(selectedDate!.start);
        final end   = DateFormat('yyyy-MM-dd').format(selectedDate!.end);
        query = query
            .where('summarydate', isGreaterThanOrEqualTo: start)
            .where('summarydate', isLessThanOrEqualTo: end);
      }

      final snap = await query.get();

      final Map<String, Map<String, dynamic>> catMap = {};
      double debtTotal = 0;

      double _d(dynamic v) {
        if (v == null) return 0.0;
        if (v is double) return v;
        if (v is int) return v.toDouble();
        return (v as num).toDouble();
      }

      for (final doc in snap.docs) {
        final d           = doc.data() as Map<String, dynamic>;
        final companyName = (d['company'] ?? '').toString();

        final staffSummary = d['staffSummary'] as Map<String, dynamic>? ?? {};

        for (final branchStaff in staffSummary.values) {
          final bMap = branchStaff as Map<String, dynamic>? ?? {};
          for (final staffData in bMap.values) {
            final sd = staffData as Map<String, dynamic>? ?? {};
            debtTotal += _d(sd['debtpayments_value']);
          }
        }

        final branchSummary = d['branchSummary'] as Map<String, dynamic>? ?? {};

        for (final branchEntry in branchSummary.entries) {
          final branchData = branchEntry.value as Map<String, dynamic>? ?? {};
          final branchId   = (branchData['branchId'] ?? branchEntry.key).toString();

          if (_selectedBranch != null &&
              _selectedBranch!.isNotEmpty &&
              branchId != _selectedBranch) continue;

          final items = branchData['items'] as Map<String, dynamic>? ?? {};

          for (final itemEntry in items.entries) {
            final item   = itemEntry.value as Map<String, dynamic>? ?? {};
            final rawCat = (item['pcategory'] ?? 'Uncategorized').toString().trim();
            final catKey = rawCat.toLowerCase();

            if (!catMap.containsKey(catKey)) {
              catMap[catKey] = {
                'category':        rawCat,
                'companyId':       companyId,
                'company':         companyName,
                'cash':            0.0,
                'momo':            0.0,
                'credit':          0.0,
                'cash_returns':    0.0,
                'salesReturn_value': 0.0,
                'discount':        0.0,
                'cashDiscount':    0.0,
                'creditDiscount':  0.0,
                'purchaseReturns': 0.0,
                'damages':         0.0,
                'profit':          0.0,
                'costof_goods':    0.0,
                'sales_qty':       0.0,
                'cash_returnqty':  0.0,
                'transaction_count': 0.0,
                'sales_value': 0.0,
                'credit_returns': 0.0,
              };
            }

            catMap[catKey]!['cash'] = _d(catMap[catKey]!['cash'])+ _d(item['cash']);
            catMap[catKey]!['credit'] = _d(catMap[catKey]!['credit'])+ _d(item['credit']);
            catMap[catKey]!['momo'] = _d(catMap[catKey]!['momo'])  + _d(item['momo']);
            catMap[catKey]!['cash_returns'] = _d(catMap[catKey]!['cash_returns']) + _d(item['cash_returns']);
            catMap[catKey]!['credit_returns'] = _d(catMap[catKey]!['credit_returns']) + _d(item['credit_returns']);
            catMap[catKey]!['salesReturn_value']= _d(catMap[catKey]!['salesReturn_value']) + _d(item['salesReturn_value']);
            catMap[catKey]!['discount'] = _d(catMap[catKey]!['discount'])  + _d(item['discount']);
            catMap[catKey]!['profit'] = _d(catMap[catKey]!['profit']) + _d(item['profit']);

          //  catMap[catKey]!['sales_value'] = _d(catMap[catKey]!['sales_value']) + _d(item['sales_value']);
            catMap[catKey]!['sales_value'] = _d(catMap[catKey]!['cash']) +  _d(catMap[catKey]!['credit']);
            catMap[catKey]!['costof_goods'] = _d(catMap[catKey]!['costof_goods']) + _d(item['costof_goods']);
            catMap[catKey]!['sales_qty']  = (catMap[catKey]!['sales_qty']  as double) + _d(item['sales_qty']).toDouble();
            catMap[catKey]!['cash_returnqty']   = (catMap[catKey]!['cash_returnqty']   as double) + _d(item['cash_returnqty']).toDouble();
            catMap[catKey]!['transaction_count']= (catMap[catKey]!['transaction_count'] as double) + _d(item['transaction_count']).toDouble();

          }
        }
      }

      _debtPayment = debtTotal;

      _allRows = catMap.values.map((d) {
        double _d(dynamic v) {
          if (v == null) return 0.0;
          if (v is double) return v;
          if (v is int) return v.toDouble();
          return (v as num).toDouble();
        }
        return CategorySummaryRow(
          category: (d['category']   ?? '').toString(),
          companyId:(d['companyId']  ?? '').toString(),
          company:(d['company']    ?? '').toString(),
          cashSales: _d(d['cash']),
          momoSales: _d(d['momo']),
          creditSales: _d(d['credit']),
          cashReturns: _d(d['cash_returns']),
          discount:  _d(d['discount']),
          cashDiscount: _d(d['cashDiscount']),
          creditDiscount: _d(d['creditDiscount']),
          purchaseReturns: _d(d['purchaseReturns']),
          damages: _d(d['damages']),
          profit:  _d(d['profit']),
          costOfGoods:_d(d['costof_goods']),
          qty:  (d['sales_qty'] ?? 0) as double,
          transactions: (d['transaction_count'] ?? 0) as double,
          salesvalue: (d['sales_value'] ?? 0) as double,
          returnvalue: (d['salesReturn_value'] ?? 0) as double,
        );
      }).toList()
        ..sort((a, b) => a.category.compareTo(b.category));

      _applyFilter();
    } catch (e) {
      debugPrint('CategorySalesReport _fetch error: $e');
    }
    setState(() => _loading = false);
  }

  void _applyFilter() {
    setState(() {
      _filtered = _allRows.where((r) {
        return _search.isEmpty ||
            r.category.toLowerCase().contains(_search.toLowerCase()) ||
            r.company.toLowerCase().contains(_search.toLowerCase());
      }).toList();
    });
  }

  Future<List<CategoryTransactionRow>> _loadCategoryTransactions( String category) async {
    final provider = context.read<Datafeed>();
    final companyId = provider.companyid;


    Query query = FirebaseFirestore.instance
        .collection('sales')
        .where('companyId', isEqualTo: companyId);

    if (_selectedBranch != null && _selectedBranch!.isNotEmpty) {
      query = query.where('branchId', isEqualTo: _selectedBranch);
    }

    if (selectedDate != null) {
      final start = DateFormat('yyyy-MM-dd').format(selectedDate!.start);
      final end = DateFormat('yyyy-MM-dd').format(selectedDate!.end);
      query = query
          .where('dateymd', isGreaterThanOrEqualTo: start)
          .where('dateymd', isLessThanOrEqualTo: end);
    }

    query = query.orderBy('dateymd', descending: true);

    final snap = await query.get();

    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final List<CategoryTransactionRow> results = [];

    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;

      String dateStr = d['dateymd'] ?? '';
      String timeStr = '';
      final raw = d['createdAt'];
      if (raw is Timestamp) {
        timeStr = DateFormat('HH:mm:ss').format(raw.toDate());
      }

      final bool isReturned = d['isreturned'] == true;

      final itemsMap = d['items'] as Map<String, dynamic>?;
      if (itemsMap == null) continue;

      for (final itemEntry in itemsMap.entries) {
        final item = itemEntry.value as Map<String, dynamic>?;
        if (item == null) continue;

        final itemCategory = (item['pcategory'] ?? '').toString().trim();

        final bool matchesCategory;
        if (category == 'Uncategorized') {
          matchesCategory = itemCategory.isEmpty;
        } else {
          matchesCategory = itemCategory == category;
        }
        if (!matchesCategory) continue;

        results.add(CategoryTransactionRow(
          date: dateStr,
          time: timeStr,
          item: (item['item'] ?? item['barcode'] ?? '').toString(),
          qty: _d(item['quantity'] ?? item['modeqty']),
          price: _d(item['price']),
          total: _d(item['totalamount'] ?? item['grosstotalamount']),
          transactionMode: (item['mode'] ?? 'Single').toString(),
          salesMode: (d['transMode'] ?? 'cash').toString(),
          customer: (d['customerName'] ?? 'Cash Customer').toString(),
          branch: (d['branchName'] ?? '').toString(),
          staff: (d['createdBy'] ?? d['printedby'] ?? '').toString(),
          pricingMode: (item['pricemode'] ?? 'retail').toString(),
          pcategory: itemCategory.isEmpty ? 'Uncategorized' : itemCategory,
          isReturn: isReturned,
        ));
      }
    }

    return results;
  }
  Future<void> _showCategoryTransactionsDialog(BuildContext context, CategorySummaryRow row) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<CategoryTransactionRow> transactions = [];
    try {
      transactions = await _loadCategoryTransactions(row.category);
    } catch (e) {
      debugPrint('_loadCategoryTransactions error: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final vCtrl = ScrollController();
    final hCtrl = ScrollController();
    String search = '';

    final provider = context.read<Datafeed>();


    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final filtered = transactions.where((t) {
            if (search.isEmpty) return true;
            return t.item.toLowerCase().contains(search.toLowerCase()) ||
                t.branch.toLowerCase().contains(search.toLowerCase()) ||
                t.staff.toLowerCase().contains(search.toLowerCase()) ||
                t.customer.toLowerCase().contains(search.toLowerCase());
          }).toList();

          final totQty   = filtered.fold(0.0, (s, t) => s + t.qty);
          final totTotal = filtered.fold(0.0, (s, t) => s + t.total);
          final startDate = selectedDate?.start ?? DateTime.now();
          final endDate = selectedDate?.end ?? DateTime.now();

          final startStr = DateFormat('d MMMM y').format(startDate);
          final endStr = DateFormat('d MMMM y').format(endDate);
          return AlertDialog(
            backgroundColor: const Color(0xFF101624),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${row.category.toUpperCase()} SALES TRANSACTIONS FOR THE PERIOD OF '
                            '$startStr TO $endStr',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoBadge(Icons.business, row.company),
                    const SizedBox(width: 8),
                    _infoBadge(Icons.store, _selectedBranchname ?? 'All Branches'),
                    const SizedBox(width: 8),
                    _infoBadge(Icons.category, row.category),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setDlg(() => search = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search item, branch, staff, customer...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1A2235),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(dialogContext).size.height * 0.80,
              child: filtered.isEmpty
                  ? const Center(
                  child: Text('No transactions found',
                      style: TextStyle(color: Colors.white70)))
                  : MediaQuery.of(dialogContext).size.width < 700
                  ? _buildTxnCards(filtered)
                  : _buildTxnTable(filtered, vCtrl, hCtrl, totQty, totTotal),
            ),
            actions: [
              TextButton(
                onPressed: () => _printTransactionsPdf(
                    filtered, row, provider.company,
                    _selectedBranch ?? 'All Branches',
                    startStr, endStr),
                child: const Text('Print / Download',
                    style: TextStyle(color: Colors.blueAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    ),
  );

  Widget _buildTxnCards(List<CategoryTransactionRow> txns) {
    return ListView.separated(
      itemCount: txns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = txns[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.isReturn
                ? Colors.red.withOpacity(0.08)
                : const Color(0xFF1B263B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${i + 1}. ',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                  Expanded(
                    child: Text(t.item,
                        style: const TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (t.isReturn ? Colors.redAccent : Colors.greenAccent)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: (t.isReturn
                              ? Colors.redAccent
                              : Colors.greenAccent)
                              .withOpacity(0.5)),
                    ),
                    child: Text(
                      t.isReturn ? 'Return' : 'Sale',
                      style: TextStyle(
                          color: t.isReturn
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${t.date}  ${DateFormat('hh:mm a').format(DateFormat('HH:mm:ss').parse(t.time))}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip('Qty',      t.qty.toStringAsFixed(0)),
                  _chip('Price',    t.price.toStringAsFixed(2)),
                  _chip('Total',    t.total.toStringAsFixed(2)),
                  _chip('Branch',   t.branch),
                  _chip('Staff',    t.staff),
                  _chip('Customer', t.customer),
                  _chip('Mode',     t.transactionMode),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTxnTable(
      List<CategoryTransactionRow> txns,
      ScrollController vCtrl,
      ScrollController hCtrl,
      double totQty,
      double totTotal,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const widths = [32, 110, 140, 90, 90, 100, 110, 100, 130, 100, 110, 80, 110];
        const gap = 20.0;
        final double contentWidth = widths.reduce((a, b) => a + b) +
            (widths.length - 1) * gap +
            32;
        final double tableWidth =
        constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

        Widget rowOf(List<Widget> cells, {Color? color}) {
          return Container(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: const BoxConstraints(minHeight: 44, maxHeight: 60),
            alignment: Alignment.center,
            child: Row(
              children: [
                for (int i = 0; i < cells.length; i++) ...[
                  SizedBox(width: widths[i].toDouble(), child: cells[i]),
                  if (i != cells.length - 1) const SizedBox(width: gap),
                ],
              ],
            ),
          );
        }

        return ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
            trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
            thickness: MaterialStateProperty.all(10),
            radius: const Radius.circular(8),
          ),
          child: Scrollbar(
            controller: hCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: hCtrl,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: const Color(0xFF1E2A3D),
                      child: rowOf(const [
                        Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Date/TIME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Quantity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Transaction\nMode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Sales\nMode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Branch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Pricing\nMode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    Divider(height: 0.5, thickness: 0.5, color: Colors.white.withOpacity(0.1)),
                    Expanded(
                      child: Scrollbar(
                        controller: vCtrl,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: ListView.builder(
                          controller: vCtrl,
                          itemCount: txns.length + 1,
                          itemBuilder: (context, index) {
                            if (index == txns.length) {
                              // Grand Total row
                              return rowOf(
                                [
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  const Text('GRAND TOTAL',
                                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                  Text(totQty.toStringAsFixed(0),
                                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  Text(totTotal.toStringAsFixed(2),
                                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                  const Text('', style: TextStyle(color: Colors.white70)),
                                ],
                                color: const Color(0xFF16213E),
                              );
                            }

                            final t = txns[index];
                            final formattedTime = DateFormat('hh:mm a')
                                .format(DateFormat('HH:mm:ss').parse(t.time));

                            return rowOf(
                              [
                                Text('${index + 1}', style: const TextStyle(color: Colors.white70)),
                                Text('${t.date}\n$formattedTime',
                                    style: const TextStyle(color: Colors.white70)),
                                Text(t.item,
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                Text(t.qty.toStringAsFixed(0), style: const TextStyle(color: Colors.white70)),
                                Text(t.price.toStringAsFixed(2), style: const TextStyle(color: Colors.white70)),
                                Text(t.total.toStringAsFixed(2),
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                Text(t.transactionMode,
                                    style: TextStyle(
                                        color: t.isReturn ? Colors.redAccent : Colors.white70)),
                                Text(t.salesMode, style: const TextStyle(color: Colors.white70)),
                                Text(t.customer, style: const TextStyle(color: Colors.white70)),
                                Text(t.branch,
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                Text(t.staff, style: const TextStyle(color: Colors.white70)),
                                Text(t.time, style: const TextStyle(color: Colors.white70)),
                                Text(t.pricingMode, style: const TextStyle(color: Colors.white70)),
                              ],
                              color: t.isReturn ? Colors.red.withOpacity(0.08) : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 9)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Datafeed>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final startStr = selectedDate != null
        ? DateFormat('dd-MM-yyyy').format(selectedDate!.start)
        :DateFormat('dd-MM-yyyy').format(DateTime.now());

    final endStr = selectedDate != null
        ? DateFormat('dd-MM-yyyy').format(selectedDate!.end)
        : DateFormat('dd-MM-yyyy').format(DateTime.now());
    final startDate = selectedDate?.start ?? DateTime.now();
    final endDate = selectedDate?.end ?? DateTime.now();
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: Text(
          'CATEGORY SALES REPORT FOR THE PERIOD OF '
              '${DateFormat('d MMMM y').format(startDate)} TO '
              '${DateFormat('d MMMM y').format(endDate)}',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        actions: [
          ReusableDatePickerWidget(
            onDateSelected: (sel) {
              setState(() => selectedDate = sel);
              _fetch();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.calendar_today_rounded,
                  size: 22, color: Colors.white70),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1480),
            child: Column(
              children: [

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: isMobile
                      ? Column(
                    children: [
                      // SEARCH
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: TextField(
                          onChanged: (v) {
                            _search = v;
                            _applyFilter();
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search category...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF22304A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // DATE PICKER
                      ReusableDatePickerWidget(
                        onDateSelected: (sel) {
                          setState(() => selectedDate = sel);
                          _fetch();
                        },
                        child: Container(
                          height: 42,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22304A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: selectedDate != null
                                    ? const Color(0xFF6366F1)
                                    : Colors.white12,
                                width: selectedDate != null ? 1.5 : 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.date_range,
                                  size: 16,
                                  color: selectedDate != null
                                      ? const Color(0xFF6366F1)
                                      : Colors.white38),
                              const SizedBox(width: 6),
                              Text(
                                selectedDate != null
                                    ? '$startStr – $endStr'
                                    : 'Pick date range',
                                style: TextStyle(
                                    color: selectedDate != null
                                        ? const Color(0xFF6366F1)
                                        : Colors.white38,
                                    fontSize: 12),
                              ),
                              if (selectedDate != null) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => selectedDate = null);
                                    _fetch();
                                  },
                                  child: const Icon(Icons.close, size: 14, color: Colors.white54),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // BRANCH
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: DropdownButtonFormField<String>(
                         isExpanded: true,
                          value: _selectedBranch ?? '',
                          dropdownColor: const Color(0xFF22304A),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Select Branch',
                            labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF22304A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('All Branches')),
                            ...provider.branches.map((b) => DropdownMenuItem(
                                value: b.id, child: Text(b.branchname))),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedBranch = (v == null || v.isEmpty) ? null : v;
                              _selectedBranchname = (v == null || v.isEmpty)
                                  ? null
                                  : provider.branches.firstWhere((b) => b.id == v).branchname;
                            });
                            _fetch();
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // PRINT BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: const Text('Print', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF415A77),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          onPressed: _printSummaryPdf,
                        ),
                      ),
                    ],
                  )
                      : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: TextField(
                                onChanged: (v) {
                                  _search = v;
                                  _applyFilter();
                                },
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search category...',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                                  filled: true,
                                  fillColor: const Color(0xFF22304A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ReusableDatePickerWidget(
                            onDateSelected: (sel) {
                              setState(() => selectedDate = sel);
                              _fetch();
                            },
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22304A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: selectedDate != null
                                        ? const Color(0xFF6366F1)
                                        : Colors.white12,
                                    width: selectedDate != null ? 1.5 : 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.date_range,
                                      size: 16,
                                      color: selectedDate != null
                                          ? const Color(0xFF6366F1)
                                          : Colors.white38),
                                  const SizedBox(width: 6),
                                  Text(
                                    selectedDate != null
                                        ? '$startStr – $endStr'
                                        : 'Pick date range',
                                    style: TextStyle(
                                        color: selectedDate != null
                                            ? const Color(0xFF6366F1)
                                            : Colors.white38,
                                        fontSize: 12),
                                  ),
                                  if (selectedDate != null) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => selectedDate = null);
                                        _fetch();
                                      },
                                      child: const Icon(Icons.close, size: 14, color: Colors.white54),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              width: 180,
                              height: 42,
                              child: DropdownButtonFormField<String>(
                                value: _selectedBranch ?? '',
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Select Branch',
                                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                                  filled: true,
                                  fillColor: const Color(0xFF22304A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.white24),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('All Branches')),
                                  ...provider.branches.map((b) => DropdownMenuItem(
                                      value: b.id, child: Text(b.branchname))),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _selectedBranch = (v == null || v.isEmpty) ? null : v;
                                    _selectedBranchname = (v == null || v.isEmpty)
                                        ? null
                                        : provider.branches.firstWhere((b) => b.id == v).branchname;
                                  });
                                  _fetch();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('Print', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF415A77),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                            onPressed: _printSummaryPdf,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(
                      child:
                      CircularProgressIndicator(color: Colors.white))
                      : _filtered.isEmpty
                      ? const Center(
                      child: Text('No category sales found',
                          style: TextStyle(color: Colors.white70)))
                      : _buildTable(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTable() {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      final isMobileTable = constraints.maxWidth < 600;

      if (isMobileTable) {
        return ListView.separated(
          itemCount: _filtered.length + 1, // +1 for grand total card
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == _filtered.length) {
              // GRAND TOTAL CARD
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GRAND TOTAL',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _chip('Qty', _totQty.toStringAsFixed(0)),
                        _chip('Cash', _totCash.toStringAsFixed(2)),
                        _chip('Credit', _totCredit.toStringAsFixed(2)),
                        _chip('Total Sales', _totSalesValue.toStringAsFixed(2)),
                        _chip('Returns', _totReturnValue.toStringAsFixed(2)),
                        _chip('Discount', _totDiscount.toStringAsFixed(2)),
                        _chip('Profit', _totProfit.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Cash @ Hand',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('GHC ${_totCashHand.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              );
            }

            final r = _filtered[index];

            return GestureDetector(
              onTap: () => _showCategoryTransactionsDialog(context, r),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    Wrap(
                      spacing: 5,
                    //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(r.category,
                            style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 12),
                        Text('GHC ${r.cashAtHand.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _chip('Qty', '${r.qty}'),
                        _chip('Cash Sales', r.cashSales.toStringAsFixed(2)),
                        _chip('Credit Sales', r.creditSales.toStringAsFixed(2)),
                        _chip('Total Sales', r.salesvalue.toStringAsFixed(2)),
                        _chip('Cash Returns', r.cashReturns.toStringAsFixed(2)),
                        _chip('Total Returns', r.returnvalue.toStringAsFixed(2)),
                        _chip('Discount', r.discount.toStringAsFixed(2)),
                        _chip('Profit', r.profit.toStringAsFixed(2)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }


      return LayoutBuilder(
        builder: (context, constraints) {
          const widths = [32, 100, 70, 90, 90, 120, 90, 100, 120, 110, 80, 130];
          const gap = 20.0;
          final double contentWidth = widths.reduce((a, b) => a + b) +
              (widths.length - 1) * gap +
              32;
          final double tableWidth =
          constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

          Widget rowOf(List<Widget> cells, {Color? color}) {
            return Container(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 60),
              alignment: Alignment.center,
              child: Row(
                children: [
                  for (int i = 0; i < cells.length; i++) ...[
                    SizedBox(width: widths[i].toDouble(), child: cells[i]),
                    if (i != cells.length - 1) const SizedBox(width: gap),
                  ],
                ],
              ),
            );
          }

          return ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
              trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
              thickness: MaterialStateProperty.all(10),
              radius: const Radius.circular(8),
            ),
            child: Scrollbar(
              controller: _horizCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              notificationPredicate: (n) => n.depth == 0,
              child: SingleChildScrollView(
                controller: _horizCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: const Color(0xFF1B263B),
                        child: rowOf(const [
                          Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Quantity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Cash Sales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Credit Sales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Total Sales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Cash Returns', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Credit Returns', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Total Returns', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Total Discount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Profit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Cash @ Hand', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      Divider(height: 0.5, thickness: 0.5, color: Colors.white.withOpacity(0.1)),
                      Expanded(
                        child: Scrollbar(
                          controller: _vertCtrl,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: ListView.builder(
                            controller: _vertCtrl,
                            itemCount: _filtered.length + 2,
                            itemBuilder: (context, index) {
                              if (index == _filtered.length) {
                                // Grand Total row
                                return rowOf(
                                  [
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('Grand Total',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    Text(_totQty.toStringAsFixed(0), style: const TextStyle(color: Colors.white)),
                                    Text(_totCash.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(_totCredit.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(_totSalesValue.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(_totReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(_totReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(_totReturnValue.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(_totDiscount.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(_totProfit.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(_totCashHand.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                  ],
                                  color: const Color(0xFF16213E),
                                );
                              }
                              if (index == _filtered.length + 1) {
                                // Total Cash @ Hand row
                                return rowOf(
                                  [
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('Total Cash @ Hand',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    const Text('', style: TextStyle(color: Colors.white)),
                                    Text(
                                      (_totCashHand).toStringAsFixed(2),
                                      style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                  color: const Color(0xFF1D3557),
                                );
                              }

                              final r = _filtered[index];

                              return InkWell(
                                onTap: () => _showCategoryTransactionsDialog(context, r),
                                child: rowOf(
                                  [
                                    Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                                    Text(r.category,
                                        style: const TextStyle(
                                            color: Colors.lightBlueAccent,
                                            fontWeight: FontWeight.bold)),
                                    Text('${r.qty}', style: const TextStyle(color: Colors.white)),
                                    Text(r.cashSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(r.creditSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(r.salesvalue.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(r.cashReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(r.cashReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(r.returnvalue.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(r.discount.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(r.profit.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                    Text(
                                      r.cashAtHand.toStringAsFixed(2),
                                      style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                  color: const Color(0xFF0D1B2A),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },

    );
  }
  Future<void> _printSummaryPdf() async {
    final provider = context.read<Datafeed>();
    final pdf = pw.Document(title: 'Category Sales Report');
    final ttfRegular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final ttfBold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    const headerBg = PdfColor.fromInt(0xFF1E3A5F);
    const rowAlt   = PdfColor.fromInt(0xFFF0F4FA);
    const accent   = PdfColor.fromInt(0xFF1565C0);
    const dark     = PdfColor.fromInt(0xFF0D1B2A);
    const white    = PdfColors.white;

    pw.TextStyle boldWhite(double sz) => pw.TextStyle(
        color: white, fontWeight: pw.FontWeight.bold,font: ttfBold, fontSize: sz);
    pw.TextStyle cell({bool bold = false, PdfColor? color}) => pw.TextStyle(
        fontSize: 7.5,
        font: ttfRegular,
        color: color ?? dark,
        fontWeight:
        bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    final headers = [
      '#', 'Category', 'Qty',
      'Cash Sales', 'Credit Sales', 'Credit Returns',
      'Cash Discount', 'Credit Discount',
      //'Purchase Returns',
      'Cash Returns',
     // 'Damages',
      'Profit', 'Cash@Hand',
    ];
    final widths = [
      15.0, 65.0, 28.0,
      45.0, 45.0, 45.0,
      40.0, 40.0, 45.0,
      45.0, 35.0, 38.0, 45.0,
    ];

    const rowsPerPage = 28;
    final pageCount =
    (_filtered.length / rowsPerPage).ceil().clamp(1, 9999);
    final period = selectedDate != null
        ? '${DateFormat('d MMM y').format(selectedDate!.start)}\u002D${DateFormat('d MMM y').format(selectedDate!.end)}'
        : 'All Dates';

    for (int pg = 0; pg < pageCount; pg++) {
      final pageRows =
      _filtered.skip(pg * rowsPerPage).take(rowsPerPage).toList();
      final isLast = pg == pageCount - 1;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                  color: headerBg,
                  borderRadius: pw.BorderRadius.circular(5)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(provider.company.toUpperCase(),
                          style: boldWhite(13)),
                      pw.SizedBox(height: 2),
                      pw.Text('Category Sales Report',
                          style: pw.TextStyle(
                            font: ttfRegular,
                              color: PdfColors.blueGrey200,
                              fontSize: 9)),
                      pw.Text(
                          'Branch: ${_selectedBranchname ?? "All Branches"}',
                          style: pw.TextStyle(
                            font: ttfRegular,
                              color: PdfColors.blueGrey200,
                              fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Period: $period',
                          style: boldWhite(9)),
                      pw.Text(
                          'Generated: ${DateFormat('d MMMM y').format(DateTime.now())}',
                          style: pw.TextStyle(
                              font: ttfRegular,
                              color: PdfColors.blueGrey200,
                              fontSize: 8)),
                      pw.Text('Page ${pg + 1} of $pageCount',
                          style: pw.TextStyle(
                              font: ttfRegular,
                              color: PdfColors.blueGrey200,
                              fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Wrap(spacing: 14, children: [
                pw.Text('Categories: ${_filtered.length}',
                    style: boldWhite(8)),
                pw.Text(
                    'Cash Sales: ${_totCash.toStringAsFixed(2)}',
                    style: boldWhite(8)),
                pw.Text(
                    'Returns: ${_totReturns.toStringAsFixed(2)}',
                    style: boldWhite(8)),
                pw.Text(
                    'Profit: ${_totProfit.toStringAsFixed(2)}',
                    style: boldWhite(8)),
                pw.Text(
                    'Cash @ Hand: ${_totCashHand.toStringAsFixed(2)}',
                    style: boldWhite(8)),
              ]),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                for (int i = 0; i < widths.length; i++)
                  i: pw.FixedColumnWidth(widths[i])
              },
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                    color: PdfColors.blueGrey100, width: 0.4),
                bottom: pw.BorderSide(
                    color: PdfColors.blueGrey300, width: 0.5),
              ),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBg),
                  children: headers
                      .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3, vertical: 5),
                    child: pw.Text(h,
                        style: boldWhite(7),
                        textAlign: pw.TextAlign.center),
                  ))
                      .toList(),
                ),
                ...pageRows.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  final vals = [
                    '${pg * rowsPerPage + i + 1}',
                    r.category,
                    '${r.qty}',
                    r.cashSales.toStringAsFixed(2),
                    r.creditSales.toStringAsFixed(2),
                    r.cashReturns.toStringAsFixed(2),
                    r.cashDiscount.toStringAsFixed(2),
                    r.creditDiscount.toStringAsFixed(2),
                   // r.purchaseReturns.toStringAsFixed(2),
                    r.cashReturns.toStringAsFixed(2),
                   // r.damages.toStringAsFixed(2),
                    r.profit.toStringAsFixed(2),
                    r.cashAtHand.toStringAsFixed(2),
                  ];
                  return pw.TableRow(
                    decoration: i.isOdd
                        ? const pw.BoxDecoration(color: rowAlt)
                        : null,
                    children: vals.asMap().entries
                        .map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 3, vertical: 4),
                      child: pw.Text(v.value,
                          style: cell(bold: v.key == 1),
                          textAlign: v.key <= 1
                              ? pw.TextAlign.left
                              : pw.TextAlign.right),
                    ))
                        .toList(),
                  );
                }),
                if (isLast)
                  pw.TableRow(
                    decoration:
                    const pw.BoxDecoration(color: headerBg),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TOTAL', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_totQty.toStringAsFixed(0), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_totCash.toStringAsFixed(2), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_totCredit.toStringAsFixed(2), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_totReturns.toStringAsFixed(2), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      //pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                     // pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_totReturns.toStringAsFixed(2), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_totProfit.toStringAsFixed(2), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_totCashHand.toStringAsFixed(2), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                    ],
                  ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.blueGrey200, thickness: 0.4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential-${provider.company}',
                    style: pw.TextStyle(
                        fontSize: 7, font: ttfRegular, color: PdfColors.blueGrey400)),
                pw.Text('Category Sales Report | $period',
                    style: pw.TextStyle(
                        fontSize: 7, font: ttfRegular, color: PdfColors.blueGrey400)),
              ],
            ),
          ],
        ),
      ));
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
      'category_sales_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _printTransactionsPdf(
      List<CategoryTransactionRow> txns,
      CategorySummaryRow row,
      String company,
      String branch,
      String startStr,
      String endStr,
      ) async {
    final pdf = pw.Document(
      title: 'Category Sales Report'
    );

    const headerBg = PdfColor.fromInt(0xFF1E3A5F);
    const rowAlt   = PdfColor.fromInt(0xFFF0F4FA);
    const returnBg = PdfColor.fromInt(0x14FF5252);
    const accent   = PdfColor.fromInt(0xFF1565C0);
    const dark     = PdfColor.fromInt(0xFF0D1B2A);
    const white    = PdfColors.white;
    final ttfRegular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final ttfBold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    pw.TextStyle boldWhite(double sz) => pw.TextStyle(
        color: white, fontWeight: pw.FontWeight.bold, font: ttfBold, fontSize: sz);
    pw.TextStyle cell({bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
            fontSize: 7,
            font: ttfRegular,
            color: color ?? dark,
            fontWeight:
            bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    final totQty   = txns.fold(0.0, (s, t) => s + t.qty);
    final totTotal = txns.fold(0.0, (s, t) => s + t.total);

    final headers = [
      '#', 'Date/TIME', 'Item', 'Quantity', 'Price', 'Total',
      'Transaction\nMode', 'Sales\nMode', 'Customer',
      'Branch', 'Staff', 'Time', 'Pricing\nMode',
    ];
    final widths = [
      15.0, 65.0, 80.0, 28.0, 32.0, 38.0,
      45.0, 40.0, 55.0,
      55.0, 45.0, 30.0, 45.0,
    ];

    const rowsPerPage = 25;
    final pageCount =
    (txns.length / rowsPerPage).ceil().clamp(1, 9999);

    for (int pg = 0; pg < pageCount; pg++) {
      final pageRows =
      txns.skip(pg * rowsPerPage).take(rowsPerPage).toList();
      final isLast = pg == pageCount - 1;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                  color: headerBg,
                  borderRadius: pw.BorderRadius.circular(5)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(company.toUpperCase(),
                          style: boldWhite(13)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                          '${row.category.toUpperCase()} SALES TRANSACTIONS',
                          style: pw.TextStyle(
                              color: PdfColors.blueGrey200,
                              font: ttfRegular,
                              fontSize: 9)
                      ),
                      pw.Text('Branch: $branch',
                          style: pw.TextStyle(
                              color: PdfColors.blueGrey200,
                              font: ttfRegular,
                              fontSize: 8)),
                      pw.Text('Category: ${row.category}',
                          style: pw.TextStyle(
                            font: ttfRegular,
                              color: PdfColors.blueGrey200,
                              fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Period: $startStr-$endStr',
                          style: boldWhite(9)),
                      pw.Text(
                          'Generated: ${DateFormat('d MMMM y').format(DateTime.now())}',
                          style: pw.TextStyle(
                              color: PdfColors.blueGrey200,
                              fontSize: 8,
                            font: ttfRegular
                          )),
                      pw.Text('Page ${pg + 1} of $pageCount',
                          style: pw.TextStyle(
                              color: PdfColors.blueGrey200,
                              fontSize: 8,
                              font: ttfRegular)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Wrap(spacing: 16, children: [
                pw.Text('Total Transactions: ${txns.length}',
                    style: boldWhite(8)),
                pw.Text(
                    'Total Qty: ${totQty.toStringAsFixed(0)}',
                    style: boldWhite(8)),
                pw.Text(
                    'Total Amount: ${totTotal.toStringAsFixed(2)}',
                    style: boldWhite(8)),
              ]),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                for (int i = 0; i < widths.length; i++)
                  i: pw.FixedColumnWidth(widths[i])
              },
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                    color: PdfColors.blueGrey100, width: 0.4),
                bottom: pw.BorderSide(
                    color: PdfColors.blueGrey300, width: 0.5),
              ),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBg),
                  children: headers
                      .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3, vertical: 5),
                    child: pw.Text(h,
                        style: boldWhite(7),
                        textAlign: pw.TextAlign.center),
                  ))
                      .toList(),
                ),
                ...pageRows.asMap().entries.map((e) {
                  final i  = e.key;
                  final t  = e.value;
                  final bg = t.isReturn
                      ? returnBg
                      : (i.isOdd ? rowAlt : PdfColors.white);
                  final vals = [
                    '${pg * rowsPerPage + i + 1}',
                    '${t.date}\n/${t.time}',
                    t.item,
                    t.qty.toStringAsFixed(0),
                    t.price.toStringAsFixed(2),
                    t.total.toStringAsFixed(2),
                    t.transactionMode,
                    t.salesMode,
                    t.customer,
                    t.branch,
                    t.staff,
                    t.time,
                    t.pricingMode,
                  ];
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: vals.asMap().entries
                        .map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 3, vertical: 4),
                      child: pw.Text(v.value,
                          style: cell(
                              bold: v.key == 2 || v.key == 5,
                              color: (v.key == 6 && t.isReturn)
                                  ? PdfColors.red700
                                  : null),
                          textAlign: (v.key == 1 ||
                              v.key == 2 ||
                              v.key == 6 ||
                              v.key == 7 ||
                              v.key == 8 ||
                              v.key == 9 ||
                              v.key == 10 ||
                              v.key == 12)
                              ? pw.TextAlign.left
                              : pw.TextAlign.right),
                    ))
                        .toList(),
                  );
                }),
                if (isLast)
                  pw.TableRow(
                    decoration:
                    const pw.BoxDecoration(color: headerBg),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TOTAL', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(totQty.toStringAsFixed(0), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(totTotal.toStringAsFixed(2), style: boldWhite(7), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: boldWhite(7))),
                    ],
                  ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.blueGrey200, thickness: 0.4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential - $company',
                    style: pw.TextStyle(
                        fontSize: 7,font: ttfRegular, color: PdfColors.blueGrey400)),
                pw.Text(
                    '${row.category} Transactions | $startStr - $endStr',
                    style: pw.TextStyle(
                        fontSize: 7, font: ttfRegular, color: PdfColors.blueGrey400)),
              ],
            ),
          ],
        ),
      ));
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
      'category_txns_${row.category}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}