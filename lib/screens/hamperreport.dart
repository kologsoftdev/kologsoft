import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class HamperSummaryRow {
  final String bundleId;
  final String bundleName;
  final double cashSales;
  final double creditSales;
  final double cashReturns;
  final double creditReturns;
  final double discount;
  final double profit;
  final double qty;

  const HamperSummaryRow({
    required this.bundleId,
    required this.bundleName,
    required this.cashSales,
    required this.creditSales,
    required this.cashReturns,
    required this.creditReturns,
    required this.discount,
    required this.profit,
    required this.qty,
  });

  double get totalSales  => cashSales + creditSales;
  double get totalReturns => cashReturns + creditReturns;
  double get cashAtHand  => cashSales - cashReturns;
}

class HamperItemRow {
  final String item;
  final String itemId;
  final double cashSales;
  final double creditSales;
  final double cashReturns;
  final double creditReturns;
  final double discount;
  final double profit;
  final double qty;

  const HamperItemRow({
    required this.item,
    required this.itemId,
    required this.cashSales,
    required this.creditSales,
    required this.cashReturns,
    required this.creditReturns,
    required this.discount,
    required this.profit,
    required this.qty,
  });

  double get totalSales   => cashSales + creditSales;
  double get totalReturns => cashReturns + creditReturns;
  double get cashAtHand   => cashSales - cashReturns;
}


class HamperTxnRow {
  final String date;
  final String time;
  final String item;
  final String bundleName;
  final double qty;
  final double price;
  final double total;
  final String transMode;
  final String salesMode;
  final String customer;
  final String branch;
  final String staff;
  final String pricingMode;
  final bool   isReturn;

  const HamperTxnRow({
    required this.date,
    required this.time,
    required this.item,
    required this.bundleName,
    required this.qty,
    required this.price,
    required this.total,
    required this.transMode,
    required this.salesMode,
    required this.customer,
    required this.branch,
    required this.staff,
    required this.pricingMode,
    required this.isReturn,
  });
}

class HamperSalesReport extends StatefulWidget {
  const HamperSalesReport({super.key});

  @override
  State<HamperSalesReport> createState() => _HamperSalesReportState();
}

class _HamperSalesReportState extends State<HamperSalesReport> {
  DateTimeRange? selectedDate;
  String?  _selectedBranch;
  String?  _selectedBranchName;
  String   _search = '';
  bool     _loading = false;

  List<Map<String, dynamic>> _rawSalesDocs = [];

  List<HamperSummaryRow> _allRows  = [];
  List<HamperSummaryRow> _filtered = [];
  double _debtPayment = 0;

  final _vertCtrl  = ScrollController();
  final _horizCtrl = ScrollController();


  double get _totCash    => _filtered.fold(0, (s, r) => s + r.cashSales);
  double get _totCredit  => _filtered.fold(0, (s, r) => s + r.creditSales);
  double get _totSales   => _filtered.fold(0, (s, r) => s + r.totalSales);
  double get _totCashRet => _filtered.fold(0, (s, r) => s + r.cashReturns);
  double get _totCredRet => _filtered.fold(0, (s, r) => s + r.creditReturns);
  double get _totRet     => _filtered.fold(0, (s, r) => s + r.totalReturns);
  double get _totDisc    => _filtered.fold(0, (s, r) => s + r.discount);
  double get _totProfit  => _filtered.fold(0, (s, r) => s + r.profit);
  double get _totQty     => _filtered.fold(0, (s, r) => s + r.qty);
  double get _totCash$   => _totCash - _totCashRet;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchBranches();
      _fetch();
    });
  }

  @override
  void dispose() {
    _vertCtrl.dispose();
    _horizCtrl.dispose();
    super.dispose();
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;

    if (v is num) return v.toDouble();

    if (v is String) {
      return double.tryParse(v.trim()) ?? 0.0;
    }

    return 0.0;
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final provider  = context.read<Datafeed>();
      final companyId = provider.companyid;

      Query query = FirebaseFirestore.instance
          .collection('sales')
          .where('companyId', isEqualTo: companyId);

      if (_selectedBranch != null && _selectedBranch!.isNotEmpty) {
        query = query.where('branchId', isEqualTo: _selectedBranch);
      }

      if (selectedDate != null) {
        final start = DateFormat('yyyy-MM-dd').format(selectedDate!.start);
        final end   = DateFormat('yyyy-MM-dd').format(selectedDate!.end);
        query = query
            .where('dateymd', isGreaterThanOrEqualTo: start)
            .where('dateymd', isLessThanOrEqualTo: end);
      }

      query = query.orderBy('dateymd', descending: true);

      final snap = await query.get();

      // Cache raw docs so bundle/item drill-downs reuse this instead of
      // re-hitting Firestore with the exact same filters.
      _rawSalesDocs = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

      final Map<String, Map<String, dynamic>> bundleMap = {};

      for (final d in _rawSalesDocs) {
        final isReturned = d['isreturned'] == true;
        final transMode  = (d['transMode'] ?? 'cash').toString().toLowerCase();
        final isCash     = transMode != 'credit';

        final itemsMap = d['items'] as Map<String, dynamic>?;
        if (itemsMap == null) continue;

        for (final itemEntry in itemsMap.entries) {
          final item = itemEntry.value as Map<String, dynamic>?;
          if (item == null) continue;

          final rawBundle     = (item['bundle']     ?? '').toString().trim();
          final rawBundleName = (item['bundleName'] ?? '').toString().trim();
          if (rawBundle.isEmpty) continue;

          final key = rawBundle;

          if (!bundleMap.containsKey(key)) {
            bundleMap[key] = {
              'bundleId':       rawBundle,
              'bundleName':     rawBundleName.isEmpty ? rawBundle : rawBundleName,
              'cash':           0.0,
              'credit':         0.0,
              'cash_returns':   0.0,
              'credit_returns': 0.0,
              'discount':       0.0,
              'profit':         0.0,
              'sales_qty':      0.0,
            };
          }

          final amount   = _d(item['totalamount'] ?? item['grosstotalamount']);
          final qty      = _d(item['quantity']    ?? item['modeqty']);
          final discount = _d(item['discount']);
          final cp       = _d(item['cp']);
          final profit   = amount - (cp * qty);

          if (isReturned) {
            if (isCash) {
              bundleMap[key]!['cash_returns'] =
                  _d(bundleMap[key]!['cash_returns']) + amount;
            } else {
              bundleMap[key]!['credit_returns'] =
                  _d(bundleMap[key]!['credit_returns']) + amount;
            }
          } else {
            if (isCash) {
              bundleMap[key]!['cash']   = _d(bundleMap[key]!['cash'])   + amount;
            } else {
              bundleMap[key]!['credit'] = _d(bundleMap[key]!['credit']) + amount;
            }
            bundleMap[key]!['discount']  = _d(bundleMap[key]!['discount'])  + discount;
            bundleMap[key]!['profit']    = _d(bundleMap[key]!['profit'])    + profit;
            bundleMap[key]!['sales_qty'] = _d(bundleMap[key]!['sales_qty']) + qty;
          }
        }
      }

      _debtPayment = 0;

      _allRows = bundleMap.values.map((d) => HamperSummaryRow(
        bundleId:      d['bundleId'].toString(),
        bundleName:    d['bundleName'].toString(),
        cashSales:     _d(d['cash']),
        creditSales:   _d(d['credit']),
        cashReturns:   _d(d['cash_returns']),
        creditReturns: _d(d['credit_returns']),
        discount:      _d(d['discount']),
        profit:        _d(d['profit']),
        qty:           _d(d['sales_qty']),
      )).toList()
        ..sort((a, b) => a.bundleName.compareTo(b.bundleName));

      _applyFilter();
    } catch (e) {
      debugPrint('HamperSalesReport _fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

// No longer async-necessary (no Firestore call), but kept async so
// existing `await _loadBundleItems(...)` call sites don't need changes.
  Future<List<HamperItemRow>> _loadBundleItems(String bundleId) async {
    final Map<String, Map<String, dynamic>> itemMap = {};

    for (final d in _rawSalesDocs) {
      final isReturned = d['isreturned'] == true;
      final transMode  = (d['transMode'] ?? 'cash').toString().toLowerCase();
      final isCash     = transMode != 'credit';

      final itemsMap = d['items'] as Map<String, dynamic>?;
      if (itemsMap == null) continue;

      for (final itemEntry in itemsMap.entries) {
        final item = itemEntry.value as Map<String, dynamic>?;
        if (item == null) continue;

        if ((item['bundle'] ?? '').toString().trim() != bundleId) continue;

        final itemId   = (item['itemid']   ?? itemEntry.key).toString();
        final itemName = (item['item']     ?? item['barcode'] ?? itemId).toString();
        final key      = itemId;

        if (!itemMap.containsKey(key)) {
          itemMap[key] = {
            'item':           itemName,
            'itemId':         itemId,
            'cash':           0.0,
            'credit':         0.0,
            'cash_returns':   0.0,
            'credit_returns': 0.0,
            'discount':       0.0,
            'profit':         0.0,
            'sales_qty':      0.0,
          };
        }

        final amount   = _d(item['totalamount'] ?? item['grosstotalamount']);
        final qty      = _d(item['quantity']    ?? item['modeqty']);
        final discount = _d(item['discount']);
        final cp       = _d(item['cp']);
        final profit   = amount - (cp * qty);

        if (isReturned) {
          if (isCash) {
            itemMap[key]!['cash_returns'] =
                _d(itemMap[key]!['cash_returns']) + amount;
          } else {
            itemMap[key]!['credit_returns'] =
                _d(itemMap[key]!['credit_returns']) + amount;
          }
        } else {
          if (isCash) {
            itemMap[key]!['cash']   = _d(itemMap[key]!['cash'])   + amount;
          } else {
            itemMap[key]!['credit'] = _d(itemMap[key]!['credit']) + amount;
          }
          itemMap[key]!['discount']  = _d(itemMap[key]!['discount'])  + discount;
          itemMap[key]!['profit']    = _d(itemMap[key]!['profit'])    + profit;
          itemMap[key]!['sales_qty'] = _d(itemMap[key]!['sales_qty']) + qty;
        }
      }
    }

    return itemMap.values.map((d) => HamperItemRow(
      item:          d['item'].toString(),
      itemId:        d['itemId'].toString(),
      cashSales:     _d(d['cash']),
      creditSales:   _d(d['credit']),
      cashReturns:   _d(d['cash_returns']),
      creditReturns: _d(d['credit_returns']),
      discount:      _d(d['discount']),
      profit:        _d(d['profit']),
      qty:           _d(d['sales_qty']),
    )).toList()
      ..sort((a, b) => a.item.compareTo(b.item));
  }

  Future<List<HamperTxnRow>> _loadBundleTxns({
    required String bundleId,
    String? itemId,
  }) async {
    final List<HamperTxnRow> results = [];

    for (final d in _rawSalesDocs) {
      final dateStr = (d['dateymd'] ?? '').toString();
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

        final rowBundle = (item['bundle'] ?? '').toString().trim();
        if (rowBundle != bundleId) continue;

        if (itemId != null && itemId.isNotEmpty) {
          final rowItemId = (item['itemid'] ?? '').toString();
          if (rowItemId != itemId) continue;
        }

        results.add(HamperTxnRow(
          date:        dateStr,
          time:        timeStr,
          item:        (item['item'] ?? item['barcode'] ?? '').toString(),
          bundleName:  (item['bundleName'] ?? '').toString(),
          qty:         _d(item['quantity'] ?? item['modeqty']),
          price:       _d(item['price']),
          total:       _d(item['totalamount'] ?? item['grosstotalamount']),
          transMode:   (item['mode']     ?? 'Single').toString(),
          salesMode:   (d['transMode']   ?? 'cash').toString(),
          customer:    (d['customerName'] ?? 'Cash Customer').toString(),
          branch:      (d['branchName']  ?? '').toString(),
          staff:       (d['createdBy']   ?? d['printedby'] ?? '').toString(),
          pricingMode: (item['pricemode'] ?? 'retail').toString(),
          isReturn:    isReturned,
        ));
      }
    }

    return results;
  }
  void _applyFilter() {
    if (!mounted) return;
    setState(() {
      _filtered = _allRows.where((r) {
        return _search.isEmpty ||
            r.bundleName.toLowerCase().contains(_search.toLowerCase()) ||
            r.bundleId.toLowerCase().contains(_search.toLowerCase());
      }).toList();
    });
  }

  // ── DIALOG: level-2 — items inside one bundle
  Future<void> _showBundleItemsDialog(
      BuildContext context, HamperSummaryRow bundle) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<HamperItemRow> items = [];
    try {
      items = await _loadBundleItems(bundle.bundleId);
    } catch (e) {
      debugPrint('_loadBundleItems error: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final vCtrl = ScrollController();
    final hCtrl = ScrollController();
    String search = '';

    final startStr = DateFormat('d MMMM y').format(selectedDate?.start ?? DateTime.now());
    final endStr   = DateFormat('d MMMM y').format(selectedDate?.end   ?? DateTime.now());

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final filtered = items.where((r) {
            if (search.isEmpty) return true;
            return r.item.toLowerCase().contains(search.toLowerCase());
          }).toList();

          double tot(double Function(HamperItemRow) f) =>
              filtered.fold(0, (s, r) => s + f(r));

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
                        '${bundle.bundleName.toUpperCase()} — ITEMS',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(dlgCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _infoBadge(Icons.inventory_2,
                        _selectedBranchName ?? 'All Branches'),
                    const SizedBox(width: 8),
                    _infoBadge(Icons.calendar_today,
                        '$startStr → $endStr'),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setDlg(() => search = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search item...',
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
              height: MediaQuery.of(dlgCtx).size.height * 0.80,
              child: filtered.isEmpty
                  ? const Center(
                  child: Text('No items found',
                      style: TextStyle(color: Colors.white70)))
                  : MediaQuery.of(dlgCtx).size.width < 700
                  ? _buildItemCards(filtered, bundle)
                  : _buildItemTable(filtered, vCtrl, hCtrl, tot,bundle),
            ),
            actions: [
              TextButton(
                onPressed: () => _printBundleItemsPdf(
                    filtered, bundle, startStr, endStr),
                child: const Text('Print / Download',
                    style: TextStyle(color: Colors.blueAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Close',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── DIALOG: level-3 raw transactions
  Future<void> _showTxnDialog(
      BuildContext context, {
        required String bundleId,
        required String bundleName,
        String? itemId,
        String? itemName,
      }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<HamperTxnRow> txns = [];
    try {
      txns = await _loadBundleTxns(bundleId: bundleId, itemId: itemId);
    } catch (e) {
      debugPrint('_loadBundleTxns error: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final vCtrl = ScrollController();
    final hCtrl = ScrollController();
    String search = '';

    final startStr = DateFormat('d MMMM y')
        .format(selectedDate?.start ?? DateTime.now());
    final endStr = DateFormat('d MMMM y')
        .format(selectedDate?.end ?? DateTime.now());
    final title = itemName != null
        ? '$itemName — TRANSACTIONS'
        : '$bundleName — ALL TRANSACTIONS';
    final provider = context.read<Datafeed>();

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final filtered = txns.where((t) {
            if (search.isEmpty) return true;
            return t.item.toLowerCase().contains(search.toLowerCase()) ||
                t.staff.toLowerCase().contains(search.toLowerCase()) ||
                t.customer.toLowerCase().contains(search.toLowerCase()) ||
                t.branch.toLowerCase().contains(search.toLowerCase());
          }).toList();

          final stats = _aggregateTxns(filtered);

          return AlertDialog(
            backgroundColor: const Color(0xFF101624),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(dlgCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => setDlg(() => search = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search...',
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
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statChip('Cash Sales',     stats['cashSales']),
                      _statChip('Credit Sales',   stats['creditSales']),
                      _statChip('Cash Returns',   stats['cashReturns'],   color: Colors.white70),
                      _statChip('Credit Returns', stats['creditReturns'], color: Colors.white70),
                      _statChip('Discount',       stats['discount'],      color: Colors.white70),
                      _statChip('Profit',         stats['profit'],        color: Colors.white70),
                      _statChip('Qty',            stats['qty'],
                          color: Colors.white, isCurrency: false),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(dlgCtx).size.height * 0.80,
              child: filtered.isEmpty
                  ? const Center(
                  child: Text('No transactions found',
                      style: TextStyle(color: Colors.white70)))
                  : MediaQuery.of(dlgCtx).size.width < 700
                  ? _buildTxnCards(filtered)
                  : _buildTxnTable(filtered, vCtrl, hCtrl),
            ),
            actions: [
              TextButton(
                onPressed: () => _printTxnsPdf(
                    filtered, title, provider.company,
                    _selectedBranchName ?? 'All Branches',
                    startStr, endStr),
                child: const Text('Print / Download',
                    style: TextStyle(color: Colors.blueAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Close',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      ),
    );
  }

  //WIDGETS

  Widget _infoBadge(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white54),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );

  Widget _chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(7)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 9)),
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11)),
    ]),
  );

  Widget _statChip(String label, dynamic value,
      {Color color = Colors.white, bool isCurrency = true}) {
    final fmt = isCurrency
        ? 'GHC ${(value as double).toStringAsFixed(2)}'
        : (value as double).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(fmt,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ]),
    );
  }

  // level-2 cards (mobile)
  Widget _buildItemCards(
      List<HamperItemRow> items, HamperSummaryRow bundle) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = items[i];
        return InkWell(
          onTap: () => _showTxnDialog(context,
              bundleId:   bundle.bundleId,
              bundleName: bundle.bundleName,
              itemId:     r.itemId,
              itemName:   r.item),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF1B263B),
                borderRadius: BorderRadius.circular(10)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ${r.item}',
                      style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _chip('Cash Sales',     r.cashSales.toStringAsFixed(2)),
                    _chip('Credit Sales',   r.creditSales.toStringAsFixed(2)),
                    _chip('Cash Returns',   r.cashReturns.toStringAsFixed(2)),
                    _chip('Credit Returns', r.creditReturns.toStringAsFixed(2)),
                    _chip('Discount',       r.discount.toStringAsFixed(2)),
                    _chip('Profit',         r.profit.toStringAsFixed(2)),
                    _chip('Cash@Hand',      r.cashAtHand.toStringAsFixed(2)),
                  ]),
                ]),
          ),
        );
      },
    );
  }

  // level-2 table (desktop)
  Widget _buildItemTable(
      List<HamperItemRow> items,
      ScrollController vCtrl,
      ScrollController hCtrl,
      double Function(double Function(HamperItemRow)) tot,
      HamperSummaryRow bundle) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
        thickness:  MaterialStateProperty.all(10),
        radius:     const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: vCtrl,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: vCtrl,
          child: Scrollbar(
            controller: hCtrl,
            thumbVisibility: true,
            trackVisibility: true,

            child: SingleChildScrollView(
              controller: hCtrl,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 20,
                headingRowColor:
                MaterialStateProperty.all(const Color(0xFF1E2A3D)),
                dataRowColor:
                MaterialStateProperty.resolveWith((_) => null),
                headingTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Colors.white70),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Cash Sales')),
                  DataColumn(label: Text('Credit Sales')),
                  DataColumn(label: Text('Total Sales')),
                  DataColumn(label: Text('Cash Returns')),
                  DataColumn(label: Text('Credit Returns')),
                  DataColumn(label: Text('Total Returns')),
                  DataColumn(label: Text('Discount')),
                  DataColumn(label: Text('Profit')),
                  DataColumn(label: Text('Cash@Hand')),
                ],
                rows: [
                  ...items.asMap().entries.map((e) {
                    final i = e.key;
                    final r = e.value;
                    return DataRow(
                      onSelectChanged: (_) => _showTxnDialog(context,
                          bundleId:   bundle.bundleId,
                          bundleName: bundle.bundleName,
                          itemId:     r.itemId,
                          itemName:   r.item),
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(r.item,
                            style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontWeight: FontWeight.bold))),
                        DataCell(Text(r.qty.toStringAsFixed(0))),
                        DataCell(Text(r.cashSales.toStringAsFixed(2))),
                        DataCell(Text(r.creditSales.toStringAsFixed(2))),
                        DataCell(Text(r.totalSales.toStringAsFixed(2))),
                        DataCell(Text(r.cashReturns.toStringAsFixed(2))),
                        DataCell(Text(r.creditReturns.toStringAsFixed(2))),
                        DataCell(Text(r.totalReturns.toStringAsFixed(2))),
                        DataCell(Text(r.discount.toStringAsFixed(2))),
                        DataCell(Text(r.profit.toStringAsFixed(2))),
                        DataCell(Text(r.cashAtHand.toStringAsFixed(2),
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold))),
                      ],
                    );
                  }),
                  // Grand Total
                  DataRow(
                    color: MaterialStateProperty.all(
                        const Color(0xFF16213E)),
                    cells: [
                      const DataCell(Text('')),
                      const DataCell(Text('Grand Total',
                          style:
                          TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(tot((r) => r.qty).toStringAsFixed(0))),
                      DataCell(Text(
                          tot((r) => r.cashSales).toStringAsFixed(2))),
                      DataCell(Text(
                          tot((r) => r.creditSales).toStringAsFixed(2))),
                      DataCell(Text(
                          tot((r) => r.totalSales).toStringAsFixed(2))),
                      DataCell(Text(
                          tot((r) => r.cashReturns).toStringAsFixed(2))),
                      DataCell(Text(
                          tot((r) => r.creditReturns).toStringAsFixed(2))),
                      DataCell(Text(
                          tot((r) => r.totalReturns).toStringAsFixed(2))),
                      DataCell(Text(
                          tot((r) => r.discount).toStringAsFixed(2))),
                      DataCell(Text(
                          tot((r) => r.profit).toStringAsFixed(2))),
                      DataCell(Text(
                        tot((r) => r.cashAtHand).toStringAsFixed(2),
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // level-3 cards (mobile)
  Widget _buildTxnCards(List<HamperTxnRow> txns) {
    return ListView.separated(
      itemCount: txns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = txns[i];
        String fmtTime = t.time;
        try {
          fmtTime = DateFormat('hh:mm a')
              .format(DateFormat('HH:mm:ss').parse(t.time));
        } catch (_) {}
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
                Row(children: [
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
                      color: (t.isReturn
                          ? Colors.redAccent
                          : Colors.greenAccent)
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
                ]),
                const SizedBox(height: 4),
                Text('${t.date}  $fmtTime',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip('Qty',      t.qty.toStringAsFixed(0)),
                  _chip('Price',    t.price.toStringAsFixed(2)),
                  _chip('Total',    t.total.toStringAsFixed(2)),
                  _chip('Bundle',   t.bundleName),
                  _chip('Branch',   t.branch),
                  _chip('Staff',    t.staff),
                  _chip('Customer', t.customer),
                  _chip('Mode',     t.salesMode),
                ]),
              ]),
        );
      },
    );
  }

  // level-3 table (desktop)
  Widget _buildTxnTable(List<HamperTxnRow> txns,
      ScrollController vCtrl, ScrollController hCtrl) {
    final totQty   = txns.fold(0.0, (s, t) => s + t.qty);
    final totTotal = txns.fold(0.0, (s, t) => s + t.total);

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
        thickness:  MaterialStateProperty.all(10),
        radius:     const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: vCtrl,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: vCtrl,
          child: Scrollbar(
            controller: hCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: hCtrl,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 16,
                headingRowColor:
                MaterialStateProperty.all(const Color(0xFF1E2A3D)),
                dataRowColor:
                MaterialStateProperty.resolveWith((_) => null),
                headingTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Colors.white70),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Date/Time')),
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Bundle')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Trans\nMode')),
                  DataColumn(label: Text('Sales\nMode')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Branch')),
                  DataColumn(label: Text('Staff')),
                  DataColumn(label: Text('Pricing\nMode')),
                ],
                rows: [
                  ...txns.asMap().entries.map((e) {
                    final i = e.key;
                    final t = e.value;
                    String fmtTime = t.time;
                    try {
                      fmtTime = DateFormat('hh:mm a')
                          .format(DateFormat('HH:mm:ss').parse(t.time));
                    } catch (_) {}
                    final rowColor = t.isReturn
                        ? Colors.red.withOpacity(0.08)
                        : null;
                    return DataRow(
                      color: MaterialStateProperty.all(rowColor),
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text('${t.date}\n$fmtTime')),
                        DataCell(Text(t.item,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold))),
                        DataCell(Text(t.bundleName)),
                        DataCell(Text(t.qty.toStringAsFixed(0))),
                        DataCell(Text(t.price.toStringAsFixed(2))),
                        DataCell(Text(t.total.toStringAsFixed(2),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold))),
                        DataCell(Text(t.salesMode,
                            style: TextStyle(
                                color: t.isReturn
                                    ? Colors.redAccent
                                    : Colors.white70))),
                        DataCell(Text(t.transMode)),
                        DataCell(Text(t.customer)),
                        DataCell(Text(t.branch,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold))),
                        DataCell(Text(t.staff)),
                        DataCell(Text(t.pricingMode)),
                      ],
                    );
                  }),
                  DataRow(
                    color: MaterialStateProperty.all(
                        const Color(0xFF16213E)),
                    cells: [
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('GRAND TOTAL',
                          style:
                          TextStyle(fontWeight: FontWeight.bold))),
                      const DataCell(Text('')),
                      DataCell(Text(totQty.toStringAsFixed(0),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold))),
                      const DataCell(Text('')),
                      DataCell(Text(totTotal.toStringAsFixed(2),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold))),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return ListView.separated(
            itemCount: _filtered.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == _filtered.length) {
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
                          _chip('Total Sales', _totSales.toStringAsFixed(2)),
                          _chip('Cash Returns', _totCashRet.toStringAsFixed(2)),
                          _chip('Credit Returns', _totCredRet.toStringAsFixed(2)),
                          _chip('Total Returns', _totRet.toStringAsFixed(2)),
                          _chip('Discount', _totDisc.toStringAsFixed(2)),
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
                          Text('GHC ${_totCash$.toStringAsFixed(2)}',
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
                onTap: () => _showBundleItemsDialog(context, r),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
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
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(r.bundleName,
                                    style: const TextStyle(
                                        color: Colors.lightBlueAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ),
                            ],
                          ),
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
                          _chip('Qty', r.qty.toStringAsFixed(0)),
                          _chip('Cash Sales', r.cashSales.toStringAsFixed(2)),
                          _chip('Credit Sales', r.creditSales.toStringAsFixed(2)),
                          _chip('Total Sales', r.totalSales.toStringAsFixed(2)),
                          _chip('Cash Returns', r.cashReturns.toStringAsFixed(2)),
                          _chip('Credit Returns', r.creditReturns.toStringAsFixed(2)),
                          _chip('Total Returns', r.totalReturns.toStringAsFixed(2)),
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
            const widths = [32, 180, 70, 90, 90, 100, 90, 100, 100, 90, 80, 120];
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
                            Text('Bundle Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Cash Sales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Credit Sales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Total Sales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Cash Returns', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Credit Returns', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Total Returns', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('Discount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                      Text(_totSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(_totCashRet.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(_totCredRet.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(_totRet.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(_totDisc.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(_totProfit.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(_totCash$.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
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
                                        _totCash$.toStringAsFixed(2),
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
                                  onTap: () => _showBundleItemsDialog(context, r),
                                  child: rowOf(
                                    [
                                      Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                                      Text(r.bundleName,
                                          style: const TextStyle(
                                              color: Colors.lightBlueAccent,
                                              fontWeight: FontWeight.bold)),
                                      Text(r.qty.toStringAsFixed(0), style: const TextStyle(color: Colors.white)),
                                      Text(r.cashSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(r.creditSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(r.totalSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(r.cashReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(r.creditReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                      Text(r.totalReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
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
  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<Datafeed>();
    final startDate = selectedDate?.start ?? DateTime.now();
    final endDate   = selectedDate?.end   ?? DateTime.now();
    final startStr  = DateFormat('dd-MM-yyyy').format(startDate);
    final endStr    = DateFormat('dd-MM-yyyy').format(endDate);

    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: Text(
          'HAMPER / BUNDLE SALES REPORT  '
              '${DateFormat('d MMMM y').format(startDate)} TO '
              '${DateFormat('d MMMM y').format(endDate)}',
          style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14),
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
            constraints: const BoxConstraints(maxWidth: 1480),
            child: Column(children: [
            //branch filter
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.07)),
                ),
                padding: const EdgeInsets.all(12),
                child: MediaQuery.sizeOf(context).width < 600
                    ? Column(
                  children: [
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
                          hintText: 'Search bundle...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF22304A),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                            ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: DropdownButtonFormField<String>(
                        value: _selectedBranch ?? '',
                        isExpanded:true,
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
                            _selectedBranchName = (v == null || v.isEmpty)
                                ? null
                                : provider.branches.firstWhere((b) => b.id == v).branchname;
                          });
                          _fetch();
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    Row(children: [
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
                              hintText: 'Search bundle...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              prefixIcon: const Icon(Icons.search, color: Colors.white54),
                              filled: true,
                              fillColor: const Color(0xFF22304A),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none),
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
                              ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: SizedBox(
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
                                _selectedBranchName = (v == null || v.isEmpty)
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
                    ]),
                  ],
                ),
              ),


              const SizedBox(height: 8),

              //table
              Expanded(
                child: _loading
                    ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white))
                    : _filtered.isEmpty
                    ? const Center(
                    child: Text(
                        'No hamper/bundle sales found',
                        style: TextStyle(
                            color: Colors.white70)))
                    : _buildTable(),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // helpers
  Map<String, double> _aggregateTxns(List<HamperTxnRow> txns) {
    double cash = 0, credit = 0, cashRet = 0, credRet = 0,
        disc = 0, profit = 0, qty = 0;
    for (final t in txns) {
      qty += t.qty;
      if (t.isReturn) {
        if (t.salesMode.toLowerCase() == 'credit') {
          credRet += t.total;
        } else {
          cashRet += t.total;
        }
      } else {
        if (t.salesMode.toLowerCase() == 'credit') {
          credit += t.total;
        } else {
          cash += t.total;
        }
      }
    }
    return {
      'cashSales':    cash,
      'creditSales':  credit,
      'cashReturns':  cashRet,
      'creditReturns':credRet,
      'discount':     disc,
      'profit':       profit,
      'qty':          qty,
    };
  }

  // ── PDF: level-1 summary
  Future<void> _printSummaryPdf() async {
    final provider  = context.read<Datafeed>();
    final pdf       = pw.Document();
    final baseFont  = await PdfGoogleFonts.openSansRegular();
    final boldFont  = await PdfGoogleFonts.openSansBold();

    const headerBg  = PdfColor.fromInt(0xFF1B263B);
    const rowEven   = PdfColor.fromInt(0xFFF4F6FA);
    const accent    = PdfColor.fromInt(0xFF415A77);

    pw.TextStyle hdr(double sz) => pw.TextStyle(
        font: boldFont,
        color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: sz);
    pw.TextStyle cell({bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
            font:      bold ? boldFont : baseFont,
            fontSize:  7.5,
            color:     color ?? const PdfColor.fromInt(0xFF0D1B2A),
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    final period = selectedDate != null
        ? '${DateFormat('d MMM y').format(selectedDate!.start)} – '
        '${DateFormat('d MMM y').format(selectedDate!.end)}'
        : 'All Dates';

    final headers = [
      '#', 'Bundle Name', 'Qty',
      'Cash Sales', 'Credit Sales', 'Total Sales',
      'Cash Ret.', 'Credit Ret.', 'Total Ret.',
      'Discount', 'Profit', 'Cash@Hand',
    ];
    final widths = [
      18.0, 110.0, 28.0,
      52.0, 52.0, 52.0,
      48.0, 52.0, 48.0,
      42.0, 42.0, 50.0,
    ];

    const rpp = 28;
    final pages = (_filtered.length / rpp).ceil().clamp(1, 9999);

    for (int pg = 0; pg < pages; pg++) {
      final pageRows = _filtered.skip(pg * rpp).take(rpp).toList();
      final isLast   = pg == pages - 1;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // header
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
                            style: hdr(13)),
                        pw.SizedBox(height: 2),
                        pw.Text('Hamper / Bundle Sales Report',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 9)),
                        pw.Text(
                            'Branch: ${_selectedBranchName ?? "All Branches"}',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 8)),
                      ]),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Period: $period', style: hdr(9)),
                        pw.Text(
                            'Generated: ${DateFormat('d MMMM y').format(DateTime.now())}',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 8)),
                        pw.Text('Page ${pg + 1} of $pages',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 8)),
                      ]),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            // summary strip
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Wrap(spacing: 14, children: [
                pw.Text('Bundles: ${_filtered.length}',
                    style: hdr(8)),
                pw.Text(
                    'Cash Sales: ${_totCash.toStringAsFixed(2)}',
                    style: hdr(8)),
                pw.Text(
                    'Returns: ${_totRet.toStringAsFixed(2)}',
                    style: hdr(8)),
                pw.Text(
                    'Profit: ${_totProfit.toStringAsFixed(2)}',
                    style: hdr(8)),
                pw.Text(
                    'Cash@Hand: ${_totCash$.toStringAsFixed(2)}',
                    style: hdr(8)),
              ]),
            ),
            pw.SizedBox(height: 8),
            // table
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
                // header row
                pw.TableRow(
                  decoration:
                  pw.BoxDecoration(color: headerBg),
                  children: headers
                      .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3, vertical: 5),
                    child: pw.Text(h,
                        style: hdr(7),
                        textAlign: pw.TextAlign.center),
                  ))
                      .toList(),
                ),
                // data rows
                ...pageRows.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  final bg = i.isOdd ? rowEven : PdfColors.white;
                  final vals = [
                    '${pg * rpp + i + 1}',
                    r.bundleName,
                    r.qty.toStringAsFixed(0),
                    r.cashSales.toStringAsFixed(2),
                    r.creditSales.toStringAsFixed(2),
                    r.totalSales.toStringAsFixed(2),
                    r.cashReturns.toStringAsFixed(2),
                    r.creditReturns.toStringAsFixed(2),
                    r.totalReturns.toStringAsFixed(2),
                    r.discount.toStringAsFixed(2),
                    r.profit.toStringAsFixed(2),
                    r.cashAtHand.toStringAsFixed(2),
                  ];
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: vals.asMap().entries
                        .map((v) => pw.Padding(
                      padding:
                      const pw.EdgeInsets.symmetric(
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
                // totals row
                if (isLast)
                  pw.TableRow(
                    decoration:
                    const pw.BoxDecoration(color: headerBg),
                    children: [
                      '', 'TOTAL',
                      _totQty.toStringAsFixed(0),
                      _totCash.toStringAsFixed(2),
                      _totCredit.toStringAsFixed(2),
                      _totSales.toStringAsFixed(2),
                      _totCashRet.toStringAsFixed(2),
                      _totCredRet.toStringAsFixed(2),
                      _totRet.toStringAsFixed(2),
                      _totDisc.toStringAsFixed(2),
                      _totProfit.toStringAsFixed(2),
                      _totCash$.toStringAsFixed(2),
                    ]
                        .asMap()
                        .entries
                        .map((v) => pw.Padding(
                      padding:
                      const pw.EdgeInsets.all(4),
                      child: pw.Text(v.value,
                          style: hdr(7),
                          textAlign: v.key <= 1
                              ? pw.TextAlign.left
                              : pw.TextAlign.right),
                    ))
                        .toList(),
                  ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(
                color: PdfColors.blueGrey200, thickness: 0.4),
            pw.Row(
              mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Confidential – ${provider.company}',
                    style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 7,
                        color: PdfColors.blueGrey400)),
                pw.Text(
                    'Hamper Sales Report | $period',
                    style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 7,
                        color: PdfColors.blueGrey400)),
              ],
            ),
          ],
        ),
      ));
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
      'hamper_sales_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  //PDF: level-2 bundle items
  Future<void> _printBundleItemsPdf(
      List<HamperItemRow> items,
      HamperSummaryRow bundle,
      String startStr,
      String endStr) async {
    final provider = context.read<Datafeed>();
    final pdf      = pw.Document();
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    const headerBg = PdfColor.fromInt(0xFF1B263B);
    const rowEven  = PdfColor.fromInt(0xFFF4F6FA);
    const accent   = PdfColor.fromInt(0xFF415A77);

    pw.TextStyle hdr(double sz) => pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: sz);
    pw.TextStyle cell({bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
            font:      bold ? boldFont : baseFont,
            fontSize:  7.5,
            color:     color ?? const PdfColor.fromInt(0xFF0D1B2A),
            fontWeight: bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal);

    double tot(double Function(HamperItemRow) f) =>
        items.fold(0, (s, r) => s + f(r));

    final headers = [
      '#', 'Item', 'Qty',
      'Cash Sales', 'Credit Sales', 'Total Sales',
      'Cash Ret.', 'Credit Ret.', 'Total Ret.',
      'Discount', 'Profit', 'Cash@Hand',
    ];
    final widths = [
      18.0, 120.0, 28.0,
      52.0, 52.0, 52.0,
      48.0, 52.0, 48.0,
      42.0, 42.0, 50.0,
    ];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
      header: (ctx) => pw.Column(
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
                mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(provider.company.toUpperCase(),
                            style: hdr(13)),
                        pw.Text(
                            '${bundle.bundleName.toUpperCase()} — ITEMS',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 9)),
                        pw.Text(
                            'Branch: ${_selectedBranchName ?? "All Branches"}',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 8)),
                      ]),
                  pw.Column(
                      crossAxisAlignment:
                      pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            'Period: $startStr - $endStr',
                            style: hdr(9)),
                        pw.Text(
                            'Generated: ${DateFormat('d MMMM y').format(DateTime.now())}',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 8)),
                      ]),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ]),
      build: (ctx) => [
        pw.Table(
          columnWidths: {
            for (int i = 0; i < widths.length; i++)
              i: pw.FixedColumnWidth(widths[i])
          },
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(
                color: PdfColors.blueGrey100, width: 0.4),
          ),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerBg),
              children: headers
                  .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 3, vertical: 5),
                child: pw.Text(h,
                    style: hdr(7),
                    textAlign: pw.TextAlign.center),
              ))
                  .toList(),
            ),
            ...items.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              final vals = [
                '${i + 1}',
                r.item,
                r.qty.toStringAsFixed(0),
                r.cashSales.toStringAsFixed(2),
                r.creditSales.toStringAsFixed(2),
                r.totalSales.toStringAsFixed(2),
                r.cashReturns.toStringAsFixed(2),
                r.creditReturns.toStringAsFixed(2),
                r.totalReturns.toStringAsFixed(2),
                r.discount.toStringAsFixed(2),
                r.profit.toStringAsFixed(2),
                r.cashAtHand.toStringAsFixed(2),
              ];
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color:
                    i.isOdd ? rowEven : PdfColors.white),
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
            // totals
            pw.TableRow(
              decoration:
              const pw.BoxDecoration(color: headerBg),
              children: [
                '', 'TOTAL',
                tot((r) => r.qty).toStringAsFixed(0),
                tot((r) => r.cashSales).toStringAsFixed(2),
                tot((r) => r.creditSales).toStringAsFixed(2),
                tot((r) => r.totalSales).toStringAsFixed(2),
                tot((r) => r.cashReturns).toStringAsFixed(2),
                tot((r) => r.creditReturns)
                    .toStringAsFixed(2),
                tot((r) => r.totalReturns).toStringAsFixed(2),
                tot((r) => r.discount).toStringAsFixed(2),
                tot((r) => r.profit).toStringAsFixed(2),
                tot((r) => r.cashAtHand).toStringAsFixed(2),
              ]
                  .asMap()
                  .entries
                  .map((v) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(v.value,
                    style: hdr(7),
                    textAlign: v.key <= 1
                        ? pw.TextAlign.left
                        : pw.TextAlign.right),
              ))
                  .toList(),
            ),
          ],
        ),
      ],
      footer: (ctx) => pw.Row(
        mainAxisAlignment:
        pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Confidential – ${provider.company}',
              style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 7,
                  color: PdfColors.blueGrey400)),
          pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 7,
                  color: PdfColors.blueGrey400)),
        ],
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
      'hamper_items_${bundle.bundleName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ── PDF: level-3 transactions
  Future<void> _printTxnsPdf(
      List<HamperTxnRow> txns,
      String title,
      String company,
      String branch,
      String startStr,
      String endStr) async {
    final pdf      = pw.Document();
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    const headerBg = PdfColor.fromInt(0xFF1B263B);
    const rowEven  = PdfColor.fromInt(0xFFF4F6FA);
    const returnBg = PdfColor.fromInt(0x14FF5252);
    const accent   = PdfColor.fromInt(0xFF415A77);

    pw.TextStyle hdr(double sz) => pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: sz);
    pw.TextStyle cell({bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
            font:      bold ? boldFont : baseFont,
            fontSize:  7,
            color:     color ?? const PdfColor.fromInt(0xFF0D1B2A),
            fontWeight: bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal);

    final totQty   = txns.fold(0.0, (s, t) => s + t.qty);
    final totTotal = txns.fold(0.0, (s, t) => s + t.total);

    final headers = [
      '#', 'Date/Time', 'Item', 'Bundle',
      'Qty', 'Price', 'Total',
      'Trans Mode', 'Sales Mode', 'Customer',
      'Branch', 'Staff', 'Pricing Mode',
    ];
    final widths = [
      15.0, 60.0, 75.0, 75.0,
      24.0, 30.0, 36.0,
      42.0, 38.0, 52.0,
      50.0, 42.0, 38.0,
    ];

    const rpp = 25;
    final pages = (txns.length / rpp).ceil().clamp(1, 9999);

    for (int pg = 0; pg < pages; pg++) {
      final pageRows = txns.skip(pg * rpp).take(rpp).toList();
      final isLast   = pg == pages - 1;

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
                mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(company.toUpperCase(),
                            style: hdr(13)),
                        pw.Text(title,
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 9)),
                        pw.Text('Branch: $branch',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 8)),
                      ]),
                  pw.Column(
                      crossAxisAlignment:
                      pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            'Period: $startStr - $endStr',
                            style: hdr(9)),
                        pw.Text(
                            'Generated: ${DateFormat('d MMMM y').format(DateTime.now())}',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 8)),
                        pw.Text('Page ${pg + 1} of $pages',
                            style: pw.TextStyle(
                                font: baseFont,
                                color: PdfColors.blueGrey200,
                                fontSize: 8)),
                      ]),
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
                pw.Text(
                    'Transactions: ${txns.length}',
                    style: hdr(8)),
                pw.Text(
                    'Total Qty: ${totQty.toStringAsFixed(0)}',
                    style: hdr(8)),
                pw.Text(
                    'Total: ${totTotal.toStringAsFixed(2)}',
                    style: hdr(8)),
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
                  decoration:
                  pw.BoxDecoration(color: headerBg),
                  children: headers
                      .map((h) => pw.Padding(
                    padding:
                    const pw.EdgeInsets.symmetric(
                        horizontal: 3, vertical: 5),
                    child: pw.Text(h,
                        style: hdr(7),
                        textAlign:
                        pw.TextAlign.center),
                  ))
                      .toList(),
                ),
                ...pageRows.asMap().entries.map((e) {
                  final i  = e.key;
                  final t  = e.value;
                  final bg = t.isReturn
                      ? returnBg
                      : (i.isOdd ? rowEven : PdfColors.white);
                  String fmtTime = t.time;
                  try {
                    fmtTime = DateFormat('hh:mm a').format(
                        DateFormat('HH:mm:ss').parse(t.time));
                  } catch (_) {}
                  final typeLabel = t.isReturn ? 'Return' : 'Sale';
                  final typeColor = t.isReturn
                      ? PdfColors.red700
                      : PdfColors.green700;
                  final vals = [
                    '${pg * rpp + i + 1}',
                    '${t.date}\n$fmtTime',
                    t.item,
                    t.bundleName,
                    t.qty.toStringAsFixed(0),
                    t.price.toStringAsFixed(2),
                    t.total.toStringAsFixed(2),
                    '$typeLabel / ${t.salesMode}',
                    t.transMode,
                    t.customer,
                    t.branch,
                    t.staff,
                    t.pricingMode,
                  ];
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: vals.asMap().entries
                        .map((v) => pw.Padding(
                      padding:
                      const pw.EdgeInsets.symmetric(
                          horizontal: 3, vertical: 4),
                      child: pw.Text(v.value,
                          style: cell(
                              bold: v.key == 2 ||
                                  v.key == 6,
                              color: v.key == 7
                                  ? typeColor
                                  : null),
                          textAlign: (v.key == 4 ||
                              v.key == 5 ||
                              v.key == 6)
                              ? pw.TextAlign.right
                              : pw.TextAlign.left),
                    ))
                        .toList(),
                  );
                }),
                if (isLast)
                  pw.TableRow(
                    decoration:
                    const pw.BoxDecoration(color: headerBg),
                    children: [
                      '', '', 'TOTAL', '',
                      totQty.toStringAsFixed(0),
                      '',
                      totTotal.toStringAsFixed(2),
                      '', '', '', '', '', '',
                    ]
                        .asMap()
                        .entries
                        .map((v) => pw.Padding(
                      padding:
                      const pw.EdgeInsets.all(4),
                      child: pw.Text(v.value,
                          style: hdr(7),
                          textAlign: (v.key == 4 ||
                              v.key == 6)
                              ? pw.TextAlign.right
                              : pw.TextAlign.left),
                    ))
                        .toList(),
                  ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(
                color: PdfColors.blueGrey200, thickness: 0.4),
            pw.Row(
              mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential – $company',
                    style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 7,
                        color: PdfColors.blueGrey400)),
                pw.Text('$title | $startStr – $endStr',
                    style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 7,
                        color: PdfColors.blueGrey400)),
              ],
            ),
          ],
        ),
      ));
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
      'hamper_txns_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}