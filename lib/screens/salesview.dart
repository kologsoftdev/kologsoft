

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/screens/salesviewdetails.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import '../widgets/salesviewpdf.dart';

class SalesViewPage extends StatefulWidget {
  const SalesViewPage({super.key});

  @override
  State<SalesViewPage> createState() => _SalesViewPageState();
}

class _SalesViewPageState extends State<SalesViewPage> {
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
      final provider = context.read<Datafeed>();
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchsalesview();
      _selectedBranch = provider.branchid;
      provider.fetchsalesview(
        selectedBranch: _selectedBranch,
      );
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
    final canSelectDate = context.read<Datafeed>().accesslevel == 'super admin' ||
        context.read<Datafeed>().accesslevel == 'systemadmin' ||
        context.read<Datafeed>().accesslevel == 'admin';

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
                // ── Header
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
                // ── Body
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
                              // ── replaced Items chip with Customer Name ──
                              _chip(Icons.person_outline, 'Customer',
                                  customerName),
                              _chip(Icons.person_outline, 'Staff',
                                  salesview.createdBy ?? '-'),
                              _chip(
                                Icons.calendar_today_outlined,
                                'Date',
                                salesview.dateymd != null && salesview.dateymd!.isNotEmpty
                                    ? DateFormat('dd MMM yyyy')
                                    .format(DateTime.parse(salesview.dateymd!))
                                    : '-',
                              ),
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
                                      if (item['item'] != null)
                                        _pair('Item Name', '${item['item']}'),
                                      if (item['barcode'] != null)
                                        _pair('Barcode', '${item['barcode']}'),
                                      _pair('Qty',
                                          '${item['quantity']} (${item['mode']})'),
                                      _pair('Pieces in receipt',
                                          totalQty.toStringAsFixed(0)),
                                      _pair('Price', 'GHC ${item['price']}'),
                                      _pair('Discount', '${item['discount']}'),
                                      if (canSelectDate)
                                        _pair(
                                            'Price Mode',
                                            capitalize(
                                                item['pricemode']?.toString())),
                                      if (canSelectDate && item['cp'] != null)
                                        _pair('Cost Price',
                                            'GHC ${item['cp']}'),
                                      if (canSelectDate && item['profit'] != null)
                                        _pair('Profit',
                                            'GHC ${item['profit']}'),

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
                // ── Footer
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
            content: Text('$itemName deleted successfully',style: TextStyle(color: ColorScheme.of(context).onPrimary),),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to delete item', style: TextStyle(color: ColorScheme.of(context).onPrimary)),
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
        final effectiveStart = selectedDate?.start ?? now;
        final effectiveEnd = selectedDate?.end ?? now;
        final filteredSalesview = value.filtersalesview();
        final canSelectDate = value.accesslevel == 'super admin' ||
            value.accesslevel == 'systemadmin' ||
            value.accesslevel == 'admin';
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
              if (canSelectDate)
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
              constraints: const BoxConstraints(maxWidth: 1000),
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
                          isMobile
                              ? value.isSalesStaff
                              ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B263B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              value.branch,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          )
                              : DropdownButtonFormField<String?>(
                            value: value.selectedBranch?.id,
                            dropdownColor: const Color(0xFF22304A),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: 'Branch',
                              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF415A77)),
                              ),
                              fillColor: const Color(0xFF1B263B),
                              filled: true,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Branches'),
                              ),
                              ...{
                                for (final b in value.branches) b.id: b
                              }.values
                                  .where((b) => b.id != null && b.id!.isNotEmpty)
                                  .map(
                                    (b) => DropdownMenuItem<String?>(
                                  value: b.id,
                                  child: Text(b.branchname),
                                ),
                              ),
                            ],
                            isExpanded: true,
                            onChanged: (val) {
                              _selectedBranch = val;
                              value.fetchsalesview(
                                selectedDate: selectedDate,
                                selectedBranch: val,
                              );
                            },
                          )
                              :value.isSalesStaff
                              ? Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B263B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                value.branch,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                              : Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String?>(
                              value: [
                                null,
                                ...{
                                  for (final b in value.branches) b.id: b
                                }.values
                                    .where((b) => b.id != null && b.id!.isNotEmpty)
                                    .map((b) => b.id)
                              ].contains(value.selectedBranch?.id)
                                  ? value.selectedBranch?.id
                                  : null,
                              dropdownColor: const Color(0xFF22304A),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              isDense: true,
                              decoration: InputDecoration(
                                labelText: 'Branch',
                                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.white12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF415A77)),
                                ),
                                fillColor: const Color(0xFF1B263B),
                                filled: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Branches'),
                                ),
                                ...{
                                  for (final b in value.branches) b.id: b
                                }.values
                                    .where((b) => b.id != null && b.id!.isNotEmpty)
                                    .map(
                                      (b) => DropdownMenuItem<String?>(
                                    value: b.id,
                                    child: Text(b.branchname),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                _selectedBranch = val;
                                value.fetchsalesview(
                                  selectedDate: selectedDate,
                                  selectedBranch: val,
                                );
                              },
                            ),
                          ),
                          SizedBox(height: isMobile ? 8 : 0, width: isMobile ? 0 : 10),
                          isMobile
                              ? TextFormField(
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
                          )
                              : Expanded(
                            flex: 3,
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
                          final isDesktop =
                              constraints.maxWidth > 600;
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

  Widget _buildDesktopRow(
      BuildContext context, dynamic sv, int index, Datafeed value) {
    final receipt = sv.receiptNumber;

    final customerName = (sv.customerName?.toString().isNotEmpty == true)
        ? sv.customerName.toString()
        : '-';
    final branchName = (sv.branchName?.toString().isNotEmpty == true)
        ? sv.branchName.toString()
        : '-';
    final itemMap = Map<String, dynamic>.from(sv.items);

    final total = itemMap.values.fold<double>(0, (s, item) {
      if (item is Map<String, dynamic>) {
        return s +
            (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
      }
      return s;
    });

    final nf = NumberFormat('#,##0.00');
    final dateStr = sv.dateymd ?? '-';

    return InkWell(
      onTap: () => _showViewModal(context, sv),
      child: Container(
        color: index.isEven
            ? const Color(0xFF0D1B2A)
            : const Color(0xFF111E2F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: _colWidths[0],
              child: Text('${index + 1}',
                  style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: _colWidths[1],
              child: GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: '$receipt'));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: Colors.green,
                      content: Text('Receipt copied',
                          style: TextStyle(
                              color: ColorScheme.of(context).onPrimary))));
                },
                child: Text('#$receipt',
                    style:
                    const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: _colWidths[2],
              child: Text(
                customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: _colWidths[3],
              child: Text(branchName,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: _colWidths[4],
              child: Text(dateStr,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: _colWidths[5],
              child: Text(sv.transMode ?? '-',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: _colWidths[6],
              child: Text('GHC ${nf.format(total)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: _colWidths[7],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.canView(AppModules.sales))
                  _actionIcon(
                      Icons.visibility,
                      Colors.cyanAccent,
                      'View',
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SalesDetailPage(salesview: sv)),
                      )),
                  if (value.can_Print(AppModules.sales))
                    _actionIcon(Icons.print, const Color(0xFFFFC857), 'Print',
                            () => salesViewPdf(sv)),
                  Visibility(
                    visible: value.canDelete(AppModules.sales),
                    child: _actionIcon(Icons.delete, Colors.white, 'Delete',
                            () => _handleDelete(
                            context, customerName, sv.id, receipt)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<double> _colWidths = [40, 120, 120, 130, 90, 60, 120, 140];

  Widget _sortableHeaderCell(String label, double width, int columnIndex,
      Comparable Function(dynamic d) getField, List list,
      {bool numeric = false}) {
    final isSorted = _sortColumnIndex == columnIndex;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _sort(getField, columnIndex,
            isSorted ? !_sortAscending : true, list),
        child: Row(
          mainAxisAlignment:
          numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.4)),
            if (isSorted)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white70,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  Widget _plainHeaderCell(String label, double width, {bool numeric = false}) {
    return SizedBox(
      width: width,
      child: Text(label,
          textAlign: numeric ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.4)),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, List filteredSalesview,
      Datafeed value, double availableWidth) {
    const double minTableWidth = 1100.0; // sum(colWidths) + gaps + padding
    final double contentWidth =
    availableWidth > minTableWidth ? availableWidth : minTableWidth;

    return ScrollbarTheme(
      data: _scrollbarTheme,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (n) => n.depth == 1,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.white.withOpacity(0.06)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header row
                  Container(
                    color: const Color(0xFF1B263B),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _plainHeaderCell('#', _colWidths[0]),
                        const SizedBox(width: 24),
                        _sortableHeaderCell(
                            'Receipt', _colWidths[1], 1,
                                (d) => d.receiptNumber, filteredSalesview),
                        const SizedBox(width: 24),
                        _sortableHeaderCell(
                            'Customer', _colWidths[2], 2,
                                (d) => (d.customerName?.toString() ?? '')
                                .toLowerCase(),
                            filteredSalesview),
                        const SizedBox(width: 24),
                        _sortableHeaderCell(
                            'Branch', _colWidths[3], 3,
                                (d) => d.branchName ?? '', filteredSalesview),
                        const SizedBox(width: 24),
                        _sortableHeaderCell(
                            'Date', _colWidths[4], 4,
                                (d) => d.dateymd ?? '',
                            filteredSalesview),
                        const SizedBox(width: 24),
                        _sortableHeaderCell(
                            'Mode', _colWidths[5], 5,
                                (d) => d.transMode ?? '', filteredSalesview),
                        const SizedBox(width: 18),
                        _sortableHeaderCell(
                          'Total',
                          _colWidths[6],
                          6,
                              (d) {
                            final m = Map<String, dynamic>.from(d.items);
                            return m.values.fold<double>(0, (s, item) {
                              if (item is Map<String, dynamic>) {
                                return s +
                                    (double.tryParse(
                                        item['totalamount']?.toString() ??
                                            '0') ??
                                        0);
                              }
                              return s;
                            });
                          },
                          filteredSalesview,
                          numeric: true,
                        ),
                        const SizedBox(width: 24),
                        _plainHeaderCell('Action', _colWidths[7]),
                      ],
                    ),
                  ),
                  Divider(
                      height: 0.4,
                      thickness: 0.4,
                      color: Colors.white.withOpacity(0.06)),
                  // ── Body (virtualized rows)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: ListView.builder(
                        controller: _verticalController,
                        itemCount: filteredSalesview.length,
                        itemBuilder: (context, index) => _buildDesktopRow(
                            context, filteredSalesview[index], index, value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                                const Spacer(),
                                // Text('GHC ${nf.format(total)}',
                                //     style: const TextStyle(
                                //         color: Colors.white,
                                //         fontWeight: FontWeight.w900,
                                //         fontSize: 13)),
                              ],
                            ),
                          ),
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
                                        sv.dateymd ?? '-'),
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
                                if(value.canView(AppModules.sales))
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
                                if(value.can_Print(AppModules.sales))
                                IconButton(
                                  icon: const Icon(Icons.print, color: Color(0xFFFFC857), size: 20),
                                  tooltip: 'Print',
                                  onPressed: () => salesViewPdf(sv),
                                ),
                                Visibility(
                                  visible: value.canDelete(AppModules.sales),
                                    child:  IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                      tooltip: 'Delete',
                                      onPressed: () => _handleDelete(context, customerName, id, receipt),
                                    )
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