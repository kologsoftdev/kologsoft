
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/screens/salesviewdetails.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import '../widgets/salesviewpdf.dart';

class SalesInvoice extends StatefulWidget {
  const SalesInvoice({super.key});

  @override
  State<SalesInvoice> createState() => _SalesInvoiceState();
}

class _SalesInvoiceState extends State<SalesInvoice> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final now = DateTime.now();

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController   = ScrollController();
  final ScrollController _mobileListController = ScrollController();

  static const Color   _scrollColor     = Color(0xFF415A77);
  static const double  _scrollThickness = 8.0;

  ScrollbarThemeData get _scrollbarTheme => ScrollbarThemeData(
    thumbColor:       WidgetStateProperty.all(_scrollColor),
    trackColor:       WidgetStateProperty.all(_scrollColor.withOpacity(0.15)),
    trackBorderColor: WidgetStateProperty.all(_scrollColor.withOpacity(0.30)),
    thickness:        WidgetStateProperty.all(_scrollThickness),
    radius:           const Radius.circular(6),
    thumbVisibility:  WidgetStateProperty.all(true),
    trackVisibility:  WidgetStateProperty.all(true),
  );

  void _sort<T>(Comparable<T> Function(dynamic d) getField,
      int columnIndex, bool ascending, List list) {
    list.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending   = ascending;
    });
  }

  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchsalesview();
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _mobileListController.dispose();
    super.dispose();
  }


  void _showViewModal(BuildContext context, dynamic salesview) {
    final receipt  = salesview.receiptNumber;
    final customerName = (salesview.customerName?.toString().isNotEmpty == true)
        ? salesview.customerName.toString() : '-';

    final Map<String, dynamic> itemMap =
    Map<String, dynamic>.from(salesview.items);
    final numberFormat = NumberFormat('#,##0.00');

    final totalamountt = itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum +  (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
      }
      return sum;
    });

    final totalQty = itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum + (double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0);
      }
      return sum;
    });

    final modalScrollController = ScrollController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isSmall = MediaQuery.sizeOf(ctx).width < 600;
        return Dialog(
          backgroundColor: const Color(0xFF101624),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:  isSmall ? double.infinity : 680,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B263B),
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long,
                          color: Color(0xFFFFC857), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Receipt  #$receipt',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 20),
                        onPressed: () {
                          modalScrollController.dispose();
                          Navigator.pop(ctx);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Scrollbar(
                    controller: modalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: modalScrollController,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _chip(Icons.person_outline, 'Customer',
                                  customerName),
                              _chip(Icons.person_outline, 'Staff',
                                  salesview.createdBy ?? '-'),
                              _chip(
                                  Icons.calendar_today_outlined,
                                  'Date',
                                  salesview.dateymd != null && salesview.dateymd!.isNotEmpty
                                      ? DateFormat('dd MMM yyyy, hh:mm a')
                                      .format(DateTime.parse(salesview.dateymd!))
                                      : '-'),
                              _chip(Icons.swap_horiz, 'Trans Mode',
                                  salesview.transMode ?? '-'),
                              _chip(Icons.payment, 'Status',
                                  salesview.paymentStatus ?? '-'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _sectionLabel('ITEMS'),
                          const SizedBox(height: 8),
                          ...itemMap.values.map((item) {
                            if (item is! Map<String, dynamic>) {
                              return const SizedBox();
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B263B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (item['item'] ?? '')
                                              .toString()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13),
                                        ),
                                      ),
                                      Text('GHC ${item['totalamount']}',
                                          style: const TextStyle(
                                              color: Color(0xFFFFC857),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                    ],
                                  ),
                                  const Divider(
                                      color: Colors.white10, height: 14),
                                  Wrap(
                                    spacing: 18,
                                    runSpacing: 8,
                                    children: [
                                      _pair('Qty',
                                          '${item['quantity']} (${item['mode']})'),
                                      _pair('Pieces in receipt',
                                          totalQty.toStringAsFixed(0)),
                                      _pair('Price', 'GHC ${item['price']}'),
                                      _pair('Discount', '${item['discount']}'),
                                      _pair(
                                          'Price Mode',
                                          capitalize(
                                              item['pricemode']?.toString())),
                                      if (item['cp'] != null)
                                        _pair('Cost Price',
                                            'GHC ${item['cp']}'),
                                      if (item['barcode'] != null)
                                        _pair('Barcode', '${item['barcode']}'),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL AMOUNT',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      letterSpacing: 1.2)),
                              Text(
                                'GHC ${numberFormat.format(totalamountt)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B263B),
                    borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          modalScrollController.dispose();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Close',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white38, fontSize: 10, letterSpacing: 1.6));

  Widget _chip(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF1B263B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white30, size: 13),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 9)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    ),
  );

  Widget _pair(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 9)),
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ],
  );

  Future<void> _handleDelete(BuildContext context, String itemName, String id, String receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text('Delete $itemName?',
            style: const TextStyle(color: Colors.white)),
        content: Text('This action cannot be undone. Are you sure?',
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(innerContext, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              style:
              ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(innerContext, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<Datafeed>().deletesalesview(id, receipt);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$itemName deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to delete item'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final effectiveStart = selectedDate?.start ?? now.subtract(const Duration(days: 30));
        final effectiveEnd = selectedDate?.end ?? now;
        final filteredSalesview = value.filtersalesview();

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1B263B),
            elevation: 0,
            title: const Text('Sales View List',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              ReusableDatePickerWidget(
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.calendar_today,
                      size: 20, color: Colors.white70),
                ),
                onDateSelected: (selection) {
                  setState(() => selectedDate = selection);
                  context.read<Datafeed>().fetchsalesview(
                      selectedDate: selectedDate,
                      selectedBranch: _selectedBranch);
                },
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sales report • '
                          '${DateFormat('yyyy MMM dd').format(effectiveStart)}  –  '
                          '${DateFormat('yyyy MMM dd').format(effectiveEnd)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        final fields = [
                          Expanded(
                            flex: isMobile ? 0 : 3,
                            child: DropdownButtonFormField<String?>(
                              value: value.branches.any((b) => b.id == value.selectedBranch?.id)
                                  ? value.selectedBranch?.id
                                  : null,   // ← falls back to null if the id isn't in the list
                              dropdownColor: const Color(0xFF22304A),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              isDense: true,
                              decoration: InputDecoration( /* unchanged */ ),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('All Branches')),
                                ...{ for (final b in value.branches) b.id: b }.values.map(   // ← dedupe by id
                                      (b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.branchname)),
                                ),
                              ],
                              isExpanded: true,
                              onChanged: (val) {
                                _selectedBranch = val;
                                value.fetchsalesview(selectedDate: selectedDate, selectedBranch: val);
                              },
                            ),
                          ),
                          SizedBox(height: isMobile ? 8 : 0, width: isMobile ? 0 : 10),
                          Expanded(
                            flex: isMobile ? 0 : 3,
                            child: TextFormField(
                              onChanged: value.updateSearch,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search ...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true,
                                fillColor: const Color(0xFF1B263B),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.white12)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF415A77))),
                              ),
                            ),
                          ),
                        ];

                        return isMobile
                            ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: fields,
                        )
                            : Row(
                          children: fields,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: value.isloadingsalesview
                          ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white))
                          : value.salesview.isEmpty
                          ? const Center(
                          child: Text('No Sales found',
                              style: TextStyle(
                                  color: Colors.white38)))
                          : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop =  constraints.maxWidth > 900;
                          if (isDesktop) {
                            return _buildDesktopLayout(
                                context,
                                filteredSalesview,
                                value,
                                constraints.maxWidth);
                          }
                          return _buildMobileList(
                              context, filteredSalesview);
                        },
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


  List<_SalesColumn> _salesColumns() {
    return const [
      _SalesColumn('#', 30),
      _SalesColumn('Receipt', 90),
      _SalesColumn('Customer', 180),
      _SalesColumn('Branch', 120),
      _SalesColumn('Entry Date', 100),
      _SalesColumn('Trx Date', 100),
      _SalesColumn('Mode', 90),
      _SalesColumn('Total', 100, numeric: true),
      _SalesColumn('Action', 90),
    ];
  }

  Widget _buildDesktopLayout(BuildContext context, List filteredSalesview,
      Datafeed value, double availableWidth) {
    final columns = _salesColumns();
    const double gap = 24.0;
    final double totalColsWidth =
        columns.fold<double>(0, (s, c) => s + c.width) +
            (columns.length - 1) * gap +
            32;

    return ScrollbarTheme(
      data: _scrollbarTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {

          final double contentWidth = totalColsWidth;
          return Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header (tap-to-sort)
                    Container(
                      width: contentWidth,
                      height: 44,
                      color: const Color(0xFF1B263B),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          for (int i = 0; i < columns.length; i++) ...[
                            SizedBox(
                              width: columns[i].width,
                              child: _sortableHeaderCell(
                                columns[i].label,
                                i,
                                numeric: columns[i].numeric,
                                filteredSalesview: filteredSalesview,
                              ),
                            ),
                            if (i != columns.length - 1)
                              const SizedBox(width: gap),
                          ],
                        ],
                      ),
                    ),
                    Divider(
                        height: 0.4,
                        thickness: 0.4,
                        color: Colors.white.withOpacity(0.06)),
                    // ── Body (virtualized rows)
                    Expanded(
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: ListView.builder(
                          controller: _verticalController,
                          itemCount: filteredSalesview.length,
                          itemBuilder: (context, index) => _buildDesktopRow(
                              context,
                              filteredSalesview[index],
                              index,
                              columns,
                              gap),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sortableHeaderCell(String label, int columnIndex,
      {bool numeric = false, required List filteredSalesview}) {
    final isSorted = _sortColumnIndex == columnIndex;

    Comparable Function(dynamic) getField;
    switch (columnIndex) {
      case 1:
        getField = (d) => d.receiptNumber;
        break;
      case 2:
        getField = (d) => (d.customerName?.toString() ?? '').toLowerCase();
        break;
      case 3:
        getField = (d) => d.branchName ?? '';
        break;
      case 4:
      case 5:
        getField = (d) => d.createdAt?.toDate().toString() ?? '';
        break;
      case 6:
        getField = (d) => d.transMode ?? '';
        break;
      case 7:
        getField = (d) {
          final m = Map<String, dynamic>.from(d.items);
          return m.values.fold<double>(0, (s, item) {
            if (item is Map<String, dynamic>) {
              return s + (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
            }
            return s;
          });
        };
        break;
      default:
        getField = (d) => '';
    }

    final sortable = columnIndex >= 1 && columnIndex <= 7;

    return InkWell(
      onTap: sortable
          ? () => _sort(getField, columnIndex,
          isSorted ? !_sortAscending : true, filteredSalesview)
          : null,
      child: Row(
        mainAxisAlignment:
        numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 13,
              color: Colors.white70,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopRow(BuildContext context, dynamic sv, int index,
      List<_SalesColumn> columns, double gap) {
    final receipt = sv.receiptNumber;

    final customerName = (sv.customerName?.toString().isNotEmpty == true)
        ? sv.customerName.toString() : '-';
    final branchName = (sv.branchName?.toString().isNotEmpty == true)
        ? sv.branchName.toString() : '-';
    final itemMap = Map<String, dynamic>.from(sv.items);

    final total = itemMap.values.fold<double>(0, (s, item) {
      if (item is Map<String, dynamic>) {
        return s + (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
      }
      return s;
    });

    final nf = NumberFormat('#,##0.00');
    final dateStr = sv.createdAt != null
        ? sv.createdAt!.toDate().toString().split(' ').first
        : '-';
    final dateymd = sv.dateymd != null && sv.dateymd!.isNotEmpty
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(sv.dateymd!))
        : '-';

    final cells = <Widget>[
      Text('${index + 1}',
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: '#$receipt'));
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.green,
                  content: Text('Receipt copied',style: TextStyle(color: Colors.white),)));
        },
        child: Text('#$receipt',
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
      Text(customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      Text(branchName,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      Text(dateStr,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      Text(dateymd,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      Text(sv.transMode ?? '-',
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      Text('GHC ${nf.format(total)}',
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionIcon(Icons.visibility, Colors.cyanAccent, 'View', () =>
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SalesDetailPage(salesview: sv)))),
          _actionIcon(Icons.print, const Color(0xFFFFC857), 'Print',
                  () => salesViewPdf(sv)),
        ],
      ),
    ];

    return InkWell(
      onTap: () => _showViewModal(context, sv),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 64),
        alignment: Alignment.center,
        color: index.isEven
            ? const Color(0xFF0D1B2A)
            : const Color(0xFF111E2F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (int i = 0; i < columns.length; i++) ...[
              SizedBox(width: columns[i].width, child: cells[i]),
              if (i != columns.length - 1)
                 SizedBox(width: gap),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildMobileList(BuildContext context, List filteredSalesview) {
    return Consumer<Datafeed>(
      builder: (context, value, _) => Column(

        children: [

          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              controller: _mobileListController,
              thumbVisibility: true,
              child: ListView.separated(
                controller: _mobileListController,
                itemCount: filteredSalesview.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final sv = filteredSalesview[index];
                  final id = sv.id;
                  final receipt = sv.receiptNumber;
                  final customerName = (sv.customerName?.toString().isNotEmpty == true)
                      ? sv.customerName.toString()
                      : '-';
                  final branchName = (sv.branchName?.toString().isNotEmpty == true)
                      ? sv.branchName.toString()
                      : '-';

                  final Map<String, dynamic> iMap = Map<String, dynamic>.from(sv.items);
                  final total = iMap.values.fold<double>(0, (s, item) {
                    if (item is Map<String, dynamic>) {
                      return s + (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
                    }
                    return s;
                  });
                  final nf = NumberFormat('#,##0.00');


                  return GestureDetector(
                    onTap: () => _showViewModal(context, sv),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B263B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // card header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D1B2A),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                Text('#${index + 1}',
                                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                const SizedBox(width: 8),


                              ],
                            ),
                          ),
                          SizedBox(height: 5,),
                          GestureDetector(

                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: 'Receipt #$receipt'));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('Copied')));
                            },
                            child: Text('Receipt #$receipt',
                                style: const TextStyle(
                                    color: Color(0xFFFFC857),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                          SizedBox(height: 5,),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D1B2A),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 8),

                                const Spacer(),
                                Text('GHC ${nf.format(total)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          // card body
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, color: Colors.white38, size: 13),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(branchName,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(customerName,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),

                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _pair('Mode', sv.transMode ?? '-'),
                                    _pair('Status', sv.paymentStatus ?? '-'),
                                    _pair('Date',
                                        sv.createdAt != null
                                            ? DateFormat('dd MMM yyyy').format(sv.createdAt!.toDate())
                                            : '-'),
                                    _pair('Trx Date',
                                        sv.dateymd != null && sv.dateymd!.isNotEmpty
                                            ? DateFormat('dd MMM yyyy').format(DateTime.parse(sv.dateymd!))
                                            : '-'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // card footer actions
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D1B2A),
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, color: Colors.cyanAccent, size: 20),
                                  tooltip: 'View',
                                  onPressed: () =>Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SalesDetailPage(salesview: sv),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.print, color: Color(0xFFFFC857), size: 20),
                                  tooltip: 'Print',
                                  onPressed: () => salesViewPdf(sv),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, String tooltip,
      VoidCallback onTap) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      );
}

class _SalesColumn {
  final String label;
  final double width;
  final bool numeric;
  const _SalesColumn(this.label, this.width, {this.numeric = false});
}