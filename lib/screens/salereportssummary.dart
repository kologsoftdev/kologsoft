import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class SalesSummaryPage extends StatefulWidget {
  const SalesSummaryPage({super.key});

  @override
  State<SalesSummaryPage> createState() => _SalesSummaryPageState();
}

class _SalesSummaryPageState extends State<SalesSummaryPage> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  final now = DateTime.now();

  final ScrollController _verticalController   = ScrollController();
  final ScrollController _horizontalController = ScrollController();


  final ScrollController _mobileVerticalController  = ScrollController();

  static const Color  _scrollColor     = Color(0xFF415A77);
  static const double _scrollThickness = 8.0;

  ScrollbarThemeData get _scrollbarTheme => ScrollbarThemeData(
    thumbColor:       WidgetStateProperty.all(_scrollColor),
    trackColor:       WidgetStateProperty.all(_scrollColor.withOpacity(0.15)),
    trackBorderColor: WidgetStateProperty.all(_scrollColor.withOpacity(0.30)),
    thickness:        WidgetStateProperty.all(_scrollThickness),
    radius:           const Radius.circular(6),
    thumbVisibility:  WidgetStateProperty.all(true),
    trackVisibility:  WidgetStateProperty.all(true),
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchsalesreport(
        selectedDate:   selectedDate,
        selectedBranch: _selectedBranch,
      );
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _mobileVerticalController.dispose();
    super.dispose();
  }

  Map<String, double> _computeTotals(List<Map<String, dynamic>> list) {
    double totalQty      = 0;
    double totalCash     = 0;
    double totalCredit   = 0;
    double totalReturns  = 0;
    double totalDiscount = 0;
    double totalProfit   = 0;
    double totalRowTotal = 0;

    for (final item in list) {
      double _d(String k) => (item[k] ?? 0.0) as double;
      totalQty      += _d('sales_qty');
      totalCash     += _d('cashSales');
      totalCredit   += _d('creditSales');
      totalReturns  += _d('returns');
      totalDiscount += _d('discount');
      totalProfit   += _d('profit');
      totalRowTotal += _d('rowtotal');
    }

    return {
      'qty':      totalQty,
      'cash':     totalCash,
      'credit':   totalCredit,
      'returns':  totalReturns,
      'discount': totalDiscount,
      'profit':   totalProfit,
      'total':    totalRowTotal,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, _) {
        final effectiveStart =
            selectedDate?.start ?? now;
        final effectiveEnd = selectedDate?.end ?? now;

       final filteredList = value.filtersalesreport();
        final totals       = _computeTotals(filteredList);
        final nf           = NumberFormat('#,##0.00');

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1B263B),
            elevation: 0,
            title: const Text(
              'Sales Summary',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.white
                ),
                tooltip: 'Print / Download',
                onPressed: filteredList.isEmpty
                    ? null
                    : () => _printSummary(
                  filteredList,
                  totals,
                  value.company,
                  _selectedBranch,
                  selectedDate,
                ),
              ),
              ReusableDatePickerWidget(
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.calendar_today,
                      size: 20, color: Colors.white70),
                ),
                onDateSelected: (selection) {
                  setState(() => selectedDate = selection);
                  value.fetchsalesreport(
                      selectedDate:   selectedDate,
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
                      'Sales summary  •  '
                          '${DateFormat('yyyy MMM dd').format(effectiveStart)}  –  '
                          '${DateFormat('yyyy MMM dd').format(effectiveEnd)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),


                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;

                        final uniqueBranches = <String, dynamic>{};
                        for (final b in value.branches) {
                          uniqueBranches[b.id] = b;
                        }

                        final validBranchIds = uniqueBranches.keys.toSet();
                        final safeSelectedBranchId =
                        validBranchIds.contains(value.selectedBranch?.id)
                            ? value.selectedBranch?.id
                            : null;

                        final branchDropdown =
                        DropdownButtonFormField<String?>(
                          value: safeSelectedBranchId,
                          dropdownColor: const Color(0xFF22304A),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Branch',
                            labelStyle: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFF415A77)),
                            ),
                            fillColor: const Color(0xFF1B263B),
                            filled: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Branches')),
                            ...uniqueBranches.values.map((b) =>
                                DropdownMenuItem<String?>(
                                    value: b.id,
                                    child: Text(b.branchname))),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedBranch = val);
                            value.fetchsalesreport(
                                selectedDate:   selectedDate,
                                selectedBranch: val);
                          },
                          isExpanded: true,
                        );

                        final searchField = TextFormField(
                          onChanged: value.updateSearch,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search item ...',
                            hintStyle: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.white38, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFF1B263B),
                            border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white12)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFF415A77))),
                          ),
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                            children: [
                              branchDropdown,
                              const SizedBox(height: 8),
                              searchField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 3, child: branchDropdown),
                            const SizedBox(width: 10),
                            Expanded(flex: 3, child: searchField),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── Summary chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip('Items',    filteredList.length.toString(),
                              isCount: true),
                          _chip('Total Sales',
                              'GHC ${nf.format(totals['total']!)}'),
                          _chip('Cash Sales',
                              'GHC ${nf.format(totals['cash']!)}'),
                          _chip('Credit Sales',
                              'GHC ${nf.format(totals['credit']!)}'),
                          _chip('Returns',
                              'GHC ${nf.format(totals['returns']!)}',
                              warn: true),
                          _chip('Discount',
                              'GHC ${nf.format(totals['discount']!)}',
                              warn: true),
                          _chip('Profit',
                              'GHC ${nf.format(totals['profit']!)}',
                              profit: true,
                              profitValue: totals['profit']!),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    //Table
                    Expanded(
                      child: value.isloadingsalesreport
                          ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white))
                          : filteredList.isEmpty
                          ? const Center(
                          child: Text('No items found',
                              style: TextStyle(
                                  color: Colors.white38)))
                          : LayoutBuilder(
                        builder: (ctx, constraints) {
                          return constraints.maxWidth > 600
                              ? _buildDesktopTable(
                              filteredList, totals, nf)
                              : _buildMobileList(
                              filteredList, totals, nf);
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

  //Desktop DataTable
  Widget _buildDesktopTable(
      List<Map<String, dynamic>> list,
      Map<String, double> totals,
      NumberFormat nf,
      ) {
    // Sort by total descending
    final sorted = [...list]
      ..sort((a, b) => ((b['rowtotal'] ?? 0.0) as double)
              .compareTo((a['rowtotal'] ?? 0.0) as double));

    return ScrollbarTheme(
      data: _scrollbarTheme,
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        trackVisibility: true,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
         // notificationPredicate: (n) => n.depth == 0,
          child: SingleChildScrollView(
            controller: _verticalController,
            primary: false,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.white.withOpacity(0.06)),
                child: DataTable(
                  sortColumnIndex: null,
                  headingRowColor: WidgetStateProperty.all(
                      const Color(0xFF1B263B)),
                  dataRowColor: WidgetStateProperty.resolveWith(
                          (_) => const Color(0xFF0D1B2A)),
                  headingTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                  dataTextStyle:
                  const TextStyle(color: Colors.white, fontSize: 12),
                  columnSpacing: 20,
                  dividerThickness: 0.4,
                  horizontalMargin: 16,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('ITEM')),
                    DataColumn(label: Text('QTY SOLD'),   numeric: true),
                    DataColumn(label: Text('CASH SALES'), numeric: true),
                    DataColumn(label: Text('CREDIT SALES'), numeric: true),
                    DataColumn(label: Text('RETURNS'),    numeric: true),
                    DataColumn(label: Text('DISCOUNT'),   numeric: true),
                    DataColumn(label: Text('TOTAL (GHC)'), numeric: true),
                    DataColumn(label: Text('PROFIT (GHC)'), numeric: true),
                  ],
                  rows: [
                    ...sorted.asMap().entries.map((e) {
                      final i    = e.key;
                      final item = e.value;
                      double _d(String k) =>
                          (item[k] ?? 0.0) as double;

                      final profit = _d('profit');
                      final isPos  = profit >= 0;

                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>(
                              (_) => i.isEven
                              ? const Color(0xFF0D1B2A)
                              : const Color(0xFF111E2F),
                        ),
                        cells: [
                          DataCell(Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12))),
                          DataCell(SizedBox(
                            width: 200,
                            child: Text(
                              item['item']?.toString() ?? '-',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Text(
                            _d('sales_qty').toStringAsFixed(0),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          )),
                          DataCell(Text(
                            nf.format(_d('cashSales')),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          )),
                          DataCell(Text(
                            nf.format(_d('creditSales')),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          )),
                          DataCell(Text(
                            nf.format(_d('returns')),
                            style: TextStyle(
                              color: _d('returns') > 0
                                  ? Colors.white70
                                  : Colors.white54,
                              fontSize: 12,
                            ),
                          )),
                          DataCell(Text(
                            nf.format(_d('discount')),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          )),
                          DataCell(Text(
                            nf.format(_d('rowtotal')),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          )),
                          DataCell(Text(
                            nf.format(profit),
                            style: TextStyle(
                              color: isPos
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          )),
                        ],
                      );
                    }),

                    // ── Grand Total row ─────────────────────────────────
                    DataRow(
                      color: WidgetStateProperty.all(
                          const Color(0xFF1B263B)),
                      cells: [
                        const DataCell(Text('')),
                        const DataCell(Text(
                          'GRAND TOTAL',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                        )),
                        DataCell(Text(
                          totals['qty']!.toStringAsFixed(0),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800),
                        )),
                        DataCell(Text(nf.format(totals['cash']!),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800))),
                        DataCell(Text(nf.format(totals['credit']!),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800))),
                        DataCell(Text(nf.format(totals['returns']!),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800))),
                        DataCell(Text(nf.format(totals['discount']!),
                            style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w800))),
                        DataCell(Text(
                          nf.format(totals['total']!),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        )),
                        DataCell(Text(
                          nf.format(totals['profit']!),
                          style: TextStyle(
                            color: totals['profit']! >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile card list
  Widget _buildMobileList(
      List<Map<String, dynamic>> list,
      Map<String, double> totals,
      NumberFormat nf,
      ) {
    final sorted = [...list]
      ..sort((a, b) =>
          ((b['rowtotal'] ?? 0.0) as double)
              .compareTo((a['rowtotal'] ?? 0.0) as double));

    return Column(
      children: [
        // Grand total banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B263B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL SALES',
                  style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
              Text(
                'GHC ${nf.format(totals['total']!)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Flexible(
          child: Scrollbar(
            controller: _mobileVerticalController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _mobileVerticalController,
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = sorted[index];
                double _d(String k) => (item[k] ?? 0.0) as double;
                final profit  = _d('profit');
                final isPos   = profit >= 0;
                final rowtotal = _d('rowtotal');

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B263B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D1B2A),
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Text('${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['item']?.toString() ?? '-',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'GHC ${nf.format(rowtotal)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Card body
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _mobilePair(
                                'Qty Sold',
                                _d('sales_qty')
                                    .toStringAsFixed(0)),
                            _mobilePair('Cash Sales',
                                'GHC ${nf.format(_d('cashSales'))}'),
                            _mobilePair('Credit Sales',
                                'GHC ${nf.format(_d('creditSales'))}'),
                            _mobilePair('Returns',
                                'GHC ${nf.format(_d('returns'))}',
                                valueColor: _d('returns') > 0
                                    ? Colors.orangeAccent
                                    : null),
                            _mobilePair('Discount',
                                'GHC ${nf.format(_d('discount'))}'),
                            _mobilePair(
                              'Profit',
                              'GHC ${nf.format(profit)}',
                              valueColor: isPos
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  //Print PDF
  Future<void> _printSummary(List<Map<String, dynamic>> list,Map<String, double> totals,String company,String? branchFilter,DateTimeRange? dateRange,) async {
    final pdf      = pw.Document();
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final nf       = NumberFormat('#,##0.00');

    final sorted = [...list]
      ..sort((a, b) =>
          ((b['rowtotal'] ?? 0.0) as double)
              .compareTo((a['rowtotal'] ?? 0.0) as double));

    double _d(Map m, String k) => (m[k] ?? 0.0) as double;

    const accent     = PdfColor.fromInt(0xFF415A77);
    const headerBg   = PdfColor.fromInt(0xFF1B263B);
    const rowEven    = PdfColor.fromInt(0xFFF4F6FA);
    const totalRowBg = PdfColor.fromInt(0xFF0D1B2A);

    pw.Widget cell(
        String text, {
          bool   header = false,
          bool   bold   = false,
          bool   right  = false,
          PdfColor? color,
        }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 6, vertical: 7),
          child: pw.Text(
            text,
            textAlign:
            right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font:     (header || bold) ? boldFont : baseFont,
              fontSize: 9,
              color: header
                  ? PdfColors.white
                  : (color ?? PdfColors.grey800),
            ),
          ),
        );

    pw.Widget summaryLine(String label, String value,
        {bool highlight = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: highlight ? boldFont : baseFont,
                      fontSize: highlight ? 10 : 9,
                      color:
                      highlight ? accent : PdfColors.grey700)),
              pw.Text(value,
                  style: pw.TextStyle(
                      font: boldFont,
                      fontSize: highlight ? 11 : 9,
                      color:
                      highlight ? accent : PdfColors.grey800)),
            ],
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin:     const pw.EdgeInsets.all(28),
        theme:      pw.ThemeData.withFont(base: baseFont, bold: boldFont),

        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company.toUpperCase(),
                      style: pw.TextStyle(
                          font: boldFont, fontSize: 18, color: accent),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'SALES SUMMARY REPORT',
                      style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 11,
                          color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Branch: ${branchFilter ?? 'All Branches'}',
                      style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 10,
                          color: PdfColors.grey600),
                    ),
                    if (dateRange != null)
                      pw.Text(
                        'Period: ${DateFormat('dd MMM yyyy').format(dateRange.start)}'
                            '  –  ${DateFormat('dd MMM yyyy').format(dateRange.end)}',
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 10,
                            color: PdfColors.grey600),
                      ),
                  ],
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy, hh:mm a')
                      .format(DateTime.now()),
                  style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 8,
                      color: PdfColors.grey500),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: accent),
            pw.SizedBox(height: 6),
          ],
        ),

        build: (ctx) => [
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(22),   // #
              1: const pw.FlexColumnWidth(3.0),   // Item
              2: const pw.FlexColumnWidth(0.9),   // Qty
              3: const pw.FlexColumnWidth(1.3),   // Cash Sales
              4: const pw.FlexColumnWidth(1.3),   // Credit Sales
              5: const pw.FlexColumnWidth(1.1),   // Returns
              6: const pw.FlexColumnWidth(1.0),   // Discount
              7: const pw.FlexColumnWidth(1.3),   // Total
              8: const pw.FlexColumnWidth(1.2),   // Profit
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#',             header: true),
                  cell('ITEM',          header: true),
                  cell('QTY SOLD',      header: true, right: true),
                  cell('CASH SALES',    header: true, right: true),
                  cell('CREDIT SALES',  header: true, right: true),
                  cell('RETURNS',       header: true, right: true),
                  cell('DISCOUNT',      header: true, right: true),
                  cell('TOTAL (GHC)',   header: true, right: true),
                  cell('PROFIT (GHC)',  header: true, right: true),
                ],
              ),

              // Data rows
              ...sorted.asMap().entries.map((e) {
                final i    = e.key;
                final item = e.value;
                final bg   = i.isEven ? rowEven : PdfColors.white;
                final profit = _d(item, 'profit');
                final profitColor = profit < 0
                    ? PdfColors.red700
                    : PdfColors.green700;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${i + 1}'),
                    cell(item['item']?.toString() ?? '-', bold: true),
                    cell(_d(item, 'sales_qty').toStringAsFixed(0),
                        right: true),
                    cell(nf.format(_d(item, 'cashSales')),
                        right: true),
                    cell(nf.format(_d(item, 'creditSales')),
                        right: true),
                    cell(nf.format(_d(item, 'returns')),
                        right: true),
                    cell(nf.format(_d(item, 'discount')),
                        right: true),
                    cell(nf.format(_d(item, 'rowtotal')),
                        right: true, bold: true),
                    cell(nf.format(profit),
                        right: true,
                        bold: true,
                        color: profitColor),
                  ],
                );
              }),

              // Grand Total row
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: totalRowBg),
                children: [
                  cell('',                header: true),
                  cell('GRAND TOTAL',     header: true, bold: true),
                  cell(totals['qty']!.toStringAsFixed(0),
                      header: true, right: true),
                  cell(nf.format(totals['cash']!),
                      header: true, right: true),
                  cell(nf.format(totals['credit']!),
                      header: true, right: true),
                  cell(nf.format(totals['returns']!),
                      header: true, right: true),
                  cell(nf.format(totals['discount']!),
                      header: true, right: true),
                  cell(nf.format(totals['total']!),
                      header: true, right: true),
                  cell(nf.format(totals['profit']!),
                      header: true, right: true),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // Summary box
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 280,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: rowEven,
                border: pw.Border.all(color: accent, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('SUMMARY',
                      style: pw.TextStyle(
                          font:      boldFont,
                          fontSize:  11,
                          color:     accent)),
                  pw.SizedBox(height: 10),
                  summaryLine('Total Items',
                      sorted.length.toString()),
                  summaryLine('Total Qty Sold',
                      totals['qty']!.toStringAsFixed(0)),
                  summaryLine('Total Cash Sales',
                      'GHC ${nf.format(totals['cash']!)}'),
                  summaryLine('Total Credit Sales',
                      'GHC ${nf.format(totals['credit']!)}'),
                  summaryLine('Total Returns',
                      'GHC ${nf.format(totals['returns']!)}'),
                  summaryLine('Total Discount',
                      'GHC ${nf.format(totals['discount']!)}'),
                  summaryLine('Total Profit',
                      'GHC ${nf.format(totals['profit']!)}'),
                  pw.Divider(thickness: 0.8, color: accent),
                  summaryLine(
                      'GRAND TOTAL',
                      'GHC ${nf.format(totals['total']!)}',
                      highlight: true),
                ],
              ),
            ),
          ),
        ],

        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                      font:      baseFont,
                      fontSize:  8,
                      color:     PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font:      baseFont,
                      fontSize:  8,
                      color:     PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // Widget helpers

  Widget _chip(String label, String value,
      {bool isCount = false,
        bool warn = false,
        bool profit = false,
        double profitValue = 0}) {
    Color valueColor = Colors.white;
    if (warn)   valueColor = Colors.orangeAccent;
    if (profit) valueColor = profitValue >= 0 ? Colors.greenAccent : Colors.redAccent;
    if (isCount) valueColor = const Color(0xFFFFC857);

    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _mobilePair(String label, String value,
      {Color? valueColor}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      );
}