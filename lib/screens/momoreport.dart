import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class MomoReportPage extends StatefulWidget {
  const MomoReportPage({super.key});

  @override
  State<MomoReportPage> createState() => _MomoReportPageState();
}

class _MomoReportPageState extends State<MomoReportPage> {
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
      final provider = context.read<Datafeed>();
      provider.fetchBranches();
      if (_isBranchRestricted(provider)) {
        _selectedBranch = provider.branchid;
      }
      provider.fetchsalesreport(
        selectedDate:   selectedDate,
        selectedBranch: _selectedBranch,
      );
    });
  }

  bool _isBranchRestricted(Datafeed provider) {
    final access = provider.accesslevel.toLowerCase();
    return access == 'salesattendance' || access == 'sales manager';
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _mobileVerticalController.dispose();
    super.dispose();
  }

  Map<String, double> _computeTotals(List<Map<String, dynamic>> list) {
    double totalQty       = 0;
    double totalCash      = 0;
    double totalMerchant  = 0;
    double totalHubtel    = 0;
    double totalCard      = 0;
    double totalBank      = 0;
    double totalCheque    = 0;
    double totalReturns   = 0;
    double totalDiscount  = 0;
    double totalProfit    = 0;
    double totalRowTotal  = 0;

    for (final item in list) {
      double _d(String k) => (item[k] ?? 0.0) as double;
      totalQty      += _d('sales_qty');
      totalCash     += _d('cashSales');
      totalMerchant += _d('merchantmomo');
      totalHubtel   += _d('hubtel');
      totalCard     += _d('card');
      totalBank     += _d('bank');
      totalCheque   += _d('cheque');
      totalReturns  += _d('totalReturns') + _d('returns');
      totalDiscount += _d('discount');
      totalProfit   += _d('profit');
      totalRowTotal += _d('rowTotal') + _d('rowtotal');
    }

    return {
      'qty':      totalQty,
      'cash':     totalCash,
      'merchant': totalMerchant,
      'hubtel':   totalHubtel,
      'card':     totalCard,
      'bank':     totalBank,
      'cheque':   totalCheque,
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
        final isBranchRestricted = _isBranchRestricted(value);

        final filteredList = value.filterbranchsalesreport();
        final totals       = _computeTotals(filteredList);
        final nf           = NumberFormat('#,##0.00');

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1B263B),
            elevation: 0,
            title: const Text(
              'MoMo / Hubtel Payment Summary',
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
                      'MoMo / Hubtel summary  •  '
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

                        final branchDropdown =
                        DropdownButtonFormField<String?>(
                          value: _selectedBranch,
                          isExpanded: true,
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
                          onChanged: isBranchRestricted
                              ? null
                              : (val) {
                            setState(() => _selectedBranch = val);
                            value.fetchsalesreport(
                                selectedDate:   selectedDate,
                                selectedBranch: val);
                          },
                        );

                        final searchField = TextFormField(
                          onChanged: value.updateSearch,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search branch ...',
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
                          _chip('Merchant MoMo',
                              'GHC ${nf.format(totals['merchant']!)}'),
                          _chip('Hubtel',
                              'GHC ${nf.format(totals['hubtel']!)}'),
                          _chip('Card',
                              'GHC ${nf.format(totals['card']!)}'),
                          _chip('Bank',
                              'GHC ${nf.format(totals['bank']!)}'),
                          _chip('Cheque',
                              'GHC ${nf.format(totals['cheque']!)}'),
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


  Widget _buildDesktopTable(
      List<Map<String, dynamic>> list,
      Map<String, double> totals,
      NumberFormat nf,
      ) {
    // Sort by total descending
    final sorted = [...list]
      ..sort((a, b) => ((b['rowTotal'] ?? b['rowtotal'] ?? 0.0) as double)
          .compareTo((a['rowTotal'] ?? a['rowtotal'] ?? 0.0) as double));

    return LayoutBuilder(
      builder: (context, constraints) {
        const widths = [32, 200, 90, 100, 110, 90, 90, 90, 90, 100, 100, 110, 110];
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
          data: _scrollbarTheme,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.white.withOpacity(0.06)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: const Color(0xFF1B263B),
                        child: rowOf(const [
                          Text('#',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('BRANCH',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('QTY SOLD',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('CASH SALES',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('MERCHANT MoMo',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('HUBTEL',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('CARD',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('BANK',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('CHEQUE',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('RETURNS',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('DISCOUNT',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('TOTAL (GHC)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                          Text('PROFIT (GHC)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
                        ]),
                      ),
                      Divider(height: 0.4, thickness: 0.4, color: Colors.white.withOpacity(0.06)),
                      Expanded(
                        child: Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: ListView.builder(
                            controller: _verticalController,
                            itemCount: sorted.length + 1,
                            itemBuilder: (context, index) {
                              if (index == sorted.length) {
                                // Grand Total row
                                return rowOf(
                                  [
                                    const Text(''),
                                    const Text('GRAND TOTAL',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                                    Text(totals['qty']!.toStringAsFixed(0),
                                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['cash']!),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['merchant']!),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['hubtel']!),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['card']!),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['bank']!),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['cheque']!),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['returns']!),
                                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['discount']!),
                                        style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800)),
                                    Text(nf.format(totals['total']!),
                                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w900)),
                                    Text(nf.format(totals['profit']!),
                                        style: TextStyle(
                                            color: totals['profit']! >= 0 ? Colors.greenAccent : Colors.redAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900)),
                                  ],
                                  color: const Color(0xFF1B263B),
                                );
                              }

                              final i = index;
                              final item = sorted[i];
                              double d(String k) => (item[k] ?? 0.0) as double;

                              final profit = d('profit');
                              final rowTotal = d('rowTotal') + d('rowtotal');
                              final isPos = profit >= 0;

                              return rowOf(
                                [
                                  Text('${i + 1}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                  Text(
                                    item['branchName']?.toString() ?? '-',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(d('sales_qty').toStringAsFixed(0),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text(nf.format(d('cashSales')), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(d('merchantmomo')), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(d('hubtel')), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(d('card')), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(d('bank')), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(d('cheque')), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(
                                    nf.format(d('totalReturns')),
                                    style: TextStyle(
                                      color: d('totalReturns') > 0 ? Colors.white70 : Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(nf.format(d('discount')), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  Text(
                                    nf.format(rowTotal),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    nf.format(profit),
                                    style: TextStyle(
                                      color: isPos ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                color: i.isEven ? const Color(0xFF0D1B2A) : const Color(0xFF111E2F),
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
          ),
        );
      },
    );
  }
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
          child: Wrap(
           // mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                final rowtotal = _d('rowTotal') + _d('rowtotal');

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
                                item['branchName']?.toString() ?? '-',
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
                            _mobilePair('Merchant MoMo',
                                'GHC ${nf.format(_d('merchantmomo'))}'),
                            _mobilePair('Hubtel',
                                'GHC ${nf.format(_d('hubtel'))}'),
                            _mobilePair('Card',
                                'GHC ${nf.format(_d('card'))}'),
                            _mobilePair('Bank',
                                'GHC ${nf.format(_d('bank'))}'),
                            _mobilePair('Cheque',
                                'GHC ${nf.format(_d('cheque'))}'),
                            _mobilePair('Returns',
                                'GHC ${nf.format(_d('totalReturns'))}',
                                valueColor: _d('totalReturns') > 0
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
                      'MoMo / Hubtel Payment Summary',
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
              1: const pw.FlexColumnWidth(3.0),   // Branch
              2: const pw.FlexColumnWidth(0.9),   // Qty
              3: const pw.FlexColumnWidth(1.3),   // Cash Sales
              4: const pw.FlexColumnWidth(1.3),   // Merchant MoMo
              5: const pw.FlexColumnWidth(1.1),   // Hubtel
              6: const pw.FlexColumnWidth(1.1),   // Card
              7: const pw.FlexColumnWidth(1.1),   // Bank
              8: const pw.FlexColumnWidth(1.1),   // Cheque
              9: const pw.FlexColumnWidth(1.1),   // Returns
              10: const pw.FlexColumnWidth(1.0),  // Discount
              11: const pw.FlexColumnWidth(1.3),  // Total
              12: const pw.FlexColumnWidth(1.2),  // Profit
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#',             header: true),
                  cell('BRANCH',        header: true),
                  cell('QTY SOLD',      header: true, right: true),
                  cell('CASH SALES',    header: true, right: true),
                  cell('MERCHANT MoMo', header: true, right: true),
                  cell('HUBTEL',        header: true, right: true),
                  cell('CARD',          header: true, right: true),
                  cell('BANK',          header: true, right: true),
                  cell('CHEQUE',        header: true, right: true),
                  cell('RETURNS',       header: true, right: true),
                  cell('DISCOUNT',      header: true, right: true),
                  cell('TOTAL',         header: true, right: true),
                  cell('PROFIT',        header: true, right: true),
              ]
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
                    cell(item['branchName']?.toString() ?? '-', bold: true),
                    cell(_d(item, 'sales_qty').toStringAsFixed(0),
                        right: true),
                    cell(nf.format(_d(item, 'cashSales')),
                        right: true),
                    cell(nf.format(_d(item, 'merchantmomo')),
                        right: true),
                    cell(nf.format(_d(item, 'hubtel')),
                        right: true),
                    cell(nf.format(_d(item, 'card')),
                        right: true),
                    cell(nf.format(_d(item, 'bank')),
                        right: true),
                    cell(nf.format(_d(item, 'cheque')),
                        right: true),
                    cell(nf.format(_d(item, 'totalReturns')),
                        right: true),
                    cell(nf.format(_d(item, 'discount')),
                        right: true),
                    cell(nf.format(_d(item, 'rowTotal') + _d(item, 'rowtotal')),
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
                  cell(nf.format(totals['merchant']!),
                      header: true, right: true),
                  cell(nf.format(totals['hubtel']!),
                      header: true, right: true),
                  cell(nf.format(totals['card']!),
                      header: true, right: true),
                  cell(nf.format(totals['bank']!),
                      header: true, right: true),
                  cell(nf.format(totals['cheque']!),
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
                  summaryLine('Total Branches',
                      sorted.length.toString()),
                  summaryLine('Total Qty Sold',
                      totals['qty']!.toStringAsFixed(0)),
                  summaryLine('Total Cash Sales',
                      'GHC ${nf.format(totals['cash']!)}'),
                  summaryLine('Total Merchant MoMo',
                      'GHC ${nf.format(totals['merchant']!)}'),
                  summaryLine('Total Hubtel',
                      'GHC ${nf.format(totals['hubtel']!)}'),
                  summaryLine('Total Card',
                      'GHC ${nf.format(totals['card']!)}'),
                  summaryLine('Total Bank',
                      'GHC ${nf.format(totals['bank']!)}'),
                  summaryLine('Total Cheque',
                      'GHC ${nf.format(totals['cheque']!)}'),
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