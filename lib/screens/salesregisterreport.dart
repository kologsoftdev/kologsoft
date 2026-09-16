
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:intl/intl.dart';
  import 'package:provider/provider.dart';
  import 'package:syncfusion_flutter_datepicker/datepicker.dart';

  import '../providers/Datafeed.dart';
  import '../widgets/printreportpdf.dart';
  import '../widgets/staffreportsalespdf.dart';


  class SalesRegister extends StatefulWidget {
    const SalesRegister({super.key});

    @override
    State<SalesRegister> createState() => _SalesRegisterState();
  }

  class _SalesRegisterState extends State<SalesRegister> {
    String searchQuery = '';
    late final TextEditingController searchController;
    DateTimeRange? selectedDate;
    String? _selectedBranch;
    late final ScrollController verticalController;
    late final ScrollController horizontalController;
    late final ScrollController _vController;
    late final ScrollController _hController;
    late final ScrollController _vvController;
    late final ScrollController _hhController;

    Future<void> _applyFilters() async {
      await context.read<Datafeed>().fetchsalesregister(
        selectedDate: selectedDate,
        selectedBranch: _selectedBranch == 'All'
            ? null
            : _selectedBranch,
      );
    }

    void _showDateRangePicker() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Color(0xFF0F172A),
          title: const Text('Select Date Range', style: TextStyle(color: Color(0xFFF9FAFB))),
          content: SizedBox(
              height: 400,
              width: 320,
              child: SfDateRangePicker(
                backgroundColor: const Color(0xFF101624),

                headerStyle: const DateRangePickerHeaderStyle(
                  backgroundColor: Color(0xFF1E293B),
                  textAlign: TextAlign.center,
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),

                monthViewSettings: const DateRangePickerMonthViewSettings(
                  viewHeaderStyle: DateRangePickerViewHeaderStyle(
                    textStyle: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                monthCellStyle: DateRangePickerMonthCellStyle(
                  textStyle: const TextStyle(
                    color: Colors.white,
                  ),

                  todayTextStyle: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),

                  weekendTextStyle: const TextStyle(
                    color: Colors.white60,
                  ),

                  disabledDatesTextStyle: const TextStyle(
                    color: Colors.white24,
                  ),
                ),

                selectionColor: Colors.blueAccent,
                startRangeSelectionColor: Colors.blueAccent,
                endRangeSelectionColor: Colors.blueAccent,
                rangeSelectionColor: Colors.blueAccent.withOpacity(0.15),

                todayHighlightColor: Colors.blueAccent,

                selectionTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),

                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                  if (args.value is PickerDateRange) {
                    final range = args.value as PickerDateRange;
                    setState(() {
                      selectedDate = DateTimeRange(
                        start: range.startDate!,
                        end: range.endDate ?? range.startDate!,
                      );
                    });
                  }
                },

                selectionMode: DateRangePickerSelectionMode.range,

                initialSelectedRange: selectedDate != null
                    ? PickerDateRange(
                  selectedDate!.start,
                  selectedDate!.end,
                )
                    : null,
              )
          ),

          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _applyFilters();
              },
              child: const Text('Clear', style: TextStyle(color: Color(0xFF9CA3AF))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
    }

    String _formatDateRange() {
      if (selectedDate == null) return 'All dates';
      return '${DateFormat('dd MMM yyyy').format(selectedDate!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDate!.end)}';
    }
    String capitalize(String? text) {
      if (text == null || text.isEmpty) return '';
      return text[0].toUpperCase() + text.substring(1);
    }

    @override
    void initState() {
      super.initState();

      verticalController = ScrollController();
      horizontalController = ScrollController();

      _vController = ScrollController();
      _hController = ScrollController();
      _vvController = ScrollController();
      _hhController = ScrollController();
      searchController = TextEditingController();
      Future.microtask(() async {
        if (!mounted) return;

        final provider = context.read<Datafeed>();

        await provider.fetchBranches();

        // Restrict non-admins to their own branch
        if (!provider.canDeleteRecords) {
          _selectedBranch = provider.branchid;
        }

        await provider.fetchsalesregister(
          selectedDate: selectedDate,
          selectedBranch: _selectedBranch,
        );
      });
    }
    @override
    void dispose() {
      verticalController.dispose();
      horizontalController.dispose();
      _vController.dispose();
      _hController.dispose();
      _vvController.dispose();
      _hhController.dispose();
      searchController.dispose();
      super.dispose();
    }

    /// Groups the flat sales-register rows into one aggregated row per branch.
    /// Falls back to using the branch display name as the grouping key/id when
    /// no explicit branch id field is present on the row.
    List<Map<String, dynamic>> _groupByBranch(List<dynamic> list) {
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final raw in list) {
        final item = raw as Map;
        final branchName = item['branchName']?.toString() ?? 'Unknown';
        final branchId = (item['branchId'] ?? item['branchid'] ?? branchName).toString();

        final row = grouped.putIfAbsent(branchId, () => {
          'branchId': branchId,
          'branchName': branchName,
          'cashSales': 0.0,
          'cashReturns': 0.0,
          'creditSales': 0.0,
          'creditReturns': 0.0,
          'cashDiscount': 0.0,
          'creditDiscount': 0.0,
          'damages': 0.0,
          'profit': 0.0,
          'cashAtHand': 0.0,
        });

        row['cashSales'] = (row['cashSales'] as double) + ((item['cashSales'] ?? 0) as num).toDouble();
        row['cashReturns'] = (row['cashReturns'] as double) + ((item['cashReturns'] ?? 0) as num).toDouble();
        row['creditSales'] = (row['creditSales'] as double) + ((item['creditSales'] ?? 0) as num).toDouble();
        row['creditReturns'] = (row['creditReturns'] as double) + ((item['creditReturns'] ?? 0) as num).toDouble();
        row['cashDiscount'] = (row['cashDiscount'] as double) + ((item['cashDiscount'] ?? 0) as num).toDouble();
        row['creditDiscount'] = (row['creditDiscount'] as double) + ((item['creditDiscount'] ?? 0) as num).toDouble();
        row['damages'] = (row['damages'] as double) + ((item['damages'] ?? 0) as num).toDouble();
        row['profit'] = (row['profit'] as double) + ((item['profit'] ?? 0) as num).toDouble();
        row['cashAtHand'] = (row['cashAtHand'] as double) + ((item['cashAtHand'] ?? 0) as num).toDouble();
      }

      final rows = grouped.values.toList();
      rows.sort((a, b) => (a['branchName'] as String).compareTo(b['branchName'] as String));
      return rows;
    }

    Map<String, double> _grandTotals(List<Map<String, dynamic>> branchRows) {
      final totals = <String, double>{
        'cashSales': 0.0,
        'cashReturns': 0.0,
        'creditSales': 0.0,
        'creditReturns': 0.0,
        'cashDiscount': 0.0,
        'creditDiscount': 0.0,
        'profit': 0.0,
        'cashAtHand': 0.0,
      };
      for (final row in branchRows) {
        totals['cashSales'] = totals['cashSales']! + (row['cashSales'] as double);
        totals['cashReturns'] = totals['cashReturns']! + (row['cashReturns'] as double);
        totals['creditSales'] = totals['creditSales']! + (row['creditSales'] as double);
        totals['creditReturns'] = totals['creditReturns']! + (row['creditReturns'] as double);
        totals['cashDiscount'] = totals['cashDiscount']! + (row['cashDiscount'] as double);
        totals['creditDiscount'] = totals['creditDiscount']! + (row['creditDiscount'] as double);
        totals['profit'] = totals['profit']! + (row['profit'] as double);
        totals['cashAtHand'] = totals['cashAtHand']! + (row['cashAtHand'] as double);
      }
      return totals;
    }

    @override
    Widget build(BuildContext context) {
      final screenWidth =MediaQuery.sizeOf(context).width;
      final isMobile = screenWidth < 600;
      return Consumer<Datafeed>(
        builder: (context, value, child) {
          final resultList = value.filterfetchsalesregister();
          final branchRows = _groupByBranch(resultList);
          final grandTotals = _grandTotals(branchRows);

          double totalCashSales = 0;
          double totalCashReturns = 0;

          double totalDamages = 0;
          for (var item in resultList) {
            totalCashSales += (item['cashSales'] ?? 0.0);
            totalCashReturns += (item['cashReturns'] ?? 0.0);
            totalDamages += (item['damages'] ?? 0.0);
          }
          final globalCashAtHand = totalCashSales - totalCashReturns - totalDamages;

          return Scaffold(
            backgroundColor: const Color(0xFF101624),
            appBar: AppBar(
              title: const Text('Sales Register Report'),
              actions: [

              ],
            ),


            body: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth:screenWidth),
                  child: Column(
                    children: [

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.07)),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                if (selectedDate != null) ...[

                                  SizedBox(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 14,
                                              color: Colors.white.withOpacity(0.4),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Sales Register for ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white.withOpacity(0.5),
                                              ),
                                            ),

                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                '${DateFormat.yMMMd().format(selectedDate!.start)}'
                                                    ' — '
                                                    '${DateFormat.yMMMd().format(selectedDate!.end)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.lightBlueAccent,
                                                ),
                                              ),
                                            ),

                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                SizedBox(height: 5,),

                                isMobile
                                    ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                                      ),
                                      child: TextFormField(
                                        controller: searchController,
                                        onChanged: (val){
                                          value.updateSearch(val);
                                        },
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(
                                          hintText: 'Search ...',
                                          hintStyle: TextStyle(color: Colors.white54),
                                          prefixIcon: Icon(Icons.search, color: Colors.white54),
                                          filled: true,
                                          fillColor: Color(0xFF22304A),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(8)),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: _showDateRangePicker,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: selectedDate != null
                                              ? Border.all(color: Color(0xFF6366F1), width: 1.5)
                                              : Border.all(color: Colors.white.withOpacity(0.08)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.date_range,
                                              size: 20,
                                              color: selectedDate != null ? Color(0xFF6366F1) : Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDateRange(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: selectedDate != null ? Color(0xFF6366F1) : Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            if (selectedDate != null)
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    selectedDate = null;
                                                    _applyFilters();
                                                  });
                                                },
                                                child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                    : Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                                        ),
                                        child: TextFormField(
                                          controller: searchController,
                                          onChanged: (val){
                                            value.updateSearch(val);
                                          },
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(
                                            hintText: 'Search ...',
                                            hintStyle: TextStyle(color: Colors.white54),
                                            prefixIcon: Icon(Icons.search, color: Colors.white54),
                                            filled: true,
                                            fillColor: Color(0xFF22304A),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.all(Radius.circular(8)),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: _showDateRangePicker,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(

                                          borderRadius: BorderRadius.circular(12),
                                          border: selectedDate != null
                                              ? Border.all(color: Color(0xFF6366F1), width: 1.5)
                                              : null,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.date_range,
                                              size: 20,
                                              color: selectedDate != null ? Color(0xFF6366F1) : Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDateRange(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: selectedDate != null ? Color(0xFF6366F1) : Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            if (selectedDate != null)
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    selectedDate = null;
                                                    _applyFilters();
                                                  });
                                                },
                                                child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  ],
                                ),

                                const SizedBox(height: 10),

                                //Branch filter removed: all branches now render as rows in the table below.
                                isMobile
                                    ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
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
                                        onPressed: () async {
                                          final provider = context.read<Datafeed>();
                                          final resultList = provider.filterfetchsalesregister();
                                          final branchRows = _groupByBranch(resultList);
                                          final grandTotals = _grandTotals(branchRows);

                                          String fmt(dynamic v) {
                                            if (v == null) return '0.00';
                                            final d = double.tryParse(v.toString()) ?? 0.0;
                                            return d.toStringAsFixed(2);
                                          }

                                          final rows = branchRows.asMap().entries.map((entry) {
                                            final i    = entry.key + 1;
                                            final item = entry.value;
                                            return [
                                              '$i',
                                              item['branchName']     ?.toString() ?? '',
                                              fmt(item['cashSales']),
                                              fmt(item['cashReturns']),
                                              fmt(item['creditSales']),
                                              fmt(item['creditReturns']),
                                              fmt(item['cashDiscount']),
                                              fmt(item['creditDiscount']),
                                              fmt(item['profit']),
                                              fmt(item['cashAtHand']),
                                            ];
                                          }).toList();

                                          String t(double v) => v.toStringAsFixed(2);

                                          await printReportPdf(
                                            context: context,
                                            reportTitle: 'Sales Register',
                                            companyName: provider.company,
                                            branchName: 'All Branches',
                                            dateRange: selectedDate,
                                            columns: const [
                                              PdfColumn('#',                width: 10),
                                              PdfColumn('Branch',           width: 55),
                                              PdfColumn('Cash\nSales',      width: 45),
                                              PdfColumn('Cash\nReturns',    width: 45),
                                              PdfColumn('Credit\nSales',    width: 45),
                                              PdfColumn('Credit\nReturns',  width: 45),
                                              PdfColumn('Cash\nDiscount',   width: 45),
                                              PdfColumn('Credit\nDiscount', width: 45),
                                              PdfColumn('Profit',           width: 38),
                                              PdfColumn('Cash @\nHand',     width: 42),
                                            ],
                                            rows: rows,
                                            totalsRow: [
                                              '', 'TOTAL',
                                              t(grandTotals['cashSales']!),
                                              t(grandTotals['cashReturns']!),
                                              t(grandTotals['creditSales']!),
                                              t(grandTotals['creditReturns']!),
                                              t(grandTotals['cashDiscount']!),
                                              t(grandTotals['creditDiscount']!),
                                              t(grandTotals['profit']!),
                                              t(grandTotals['cashAtHand']!),
                                            ],
                                            summaryLines: [
                                              PdfSummaryLine('Total Cash Sales',   grandTotals['cashSales']!),
                                              PdfSummaryLine('Total Credit Sales', grandTotals['creditSales']!),
                                              PdfSummaryLine('Total Profit',       grandTotals['profit']!,   highlight: true),
                                              PdfSummaryLine('Cash @ Hand',        grandTotals['cashAtHand']!, highlight: true),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                      label: const Text('Print', style: TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF415A77),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                      ),
                                      onPressed: () async {
                                        final provider = context.read<Datafeed>();
                                        final resultList = provider.filterfetchsalesregister();
                                        final branchRows = _groupByBranch(resultList);
                                        final grandTotals = _grandTotals(branchRows);

                                        String fmt(dynamic v) {
                                          if (v == null) return '0.00';
                                          final d = double.tryParse(v.toString()) ?? 0.0;
                                          return d.toStringAsFixed(2);
                                        }

                                        final rows = branchRows.asMap().entries.map((entry) {
                                          final i    = entry.key + 1;
                                          final item = entry.value;
                                          return [
                                            '$i',
                                            item['branchName']     ?.toString() ?? '',
                                            fmt(item['cashSales']),
                                            fmt(item['cashReturns']),
                                            fmt(item['creditSales']),
                                            fmt(item['creditReturns']),
                                            fmt(item['cashDiscount']),
                                            fmt(item['creditDiscount']),
                                            fmt(item['profit']),
                                            fmt(item['cashAtHand']),
                                          ];
                                        }).toList();

                                        String t(double v) => v.toStringAsFixed(2);

                                        await printReportPdf(
                                          context: context,
                                          reportTitle: 'Sales Register',
                                          companyName: provider.company,
                                          branchName: 'All Branches',
                                          dateRange: selectedDate,
                                          columns: const [
                                            PdfColumn('#',                width: 10),
                                            PdfColumn('Branch',           width: 55),
                                            PdfColumn('Cash\nSales',      width: 45),
                                            PdfColumn('Cash\nReturns',    width: 45),
                                            PdfColumn('Credit\nSales',    width: 45),
                                            PdfColumn('Credit\nReturns',  width: 45),
                                            PdfColumn('Cash\nDiscount',   width: 45),
                                            PdfColumn('Credit\nDiscount', width: 45),
                                            PdfColumn('Profit',           width: 38),
                                            PdfColumn('Cash @\nHand',     width: 42),
                                          ],
                                          rows: rows,
                                          totalsRow: [
                                            '', 'TOTAL',
                                            t(grandTotals['cashSales']!),
                                            t(grandTotals['cashReturns']!),
                                            t(grandTotals['creditSales']!),
                                            t(grandTotals['creditReturns']!),
                                            t(grandTotals['cashDiscount']!),
                                            t(grandTotals['creditDiscount']!),
                                            t(grandTotals['profit']!),
                                            t(grandTotals['cashAtHand']!),
                                          ],
                                          summaryLines: [
                                            PdfSummaryLine('Total Cash Sales',   grandTotals['cashSales']!),
                                            PdfSummaryLine('Total Credit Sales', grandTotals['creditSales']!),
                                            PdfSummaryLine('Total Profit',       grandTotals['profit']!,   highlight: true),
                                            PdfSummaryLine('Cash @ Hand',        grandTotals['cashAtHand']!, highlight: true),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),

                              ],
                            ),
                          ),


                        ],
                      ),

                      SizedBox(height: 5,),

                      Expanded(
                        child: value.isloadingsalesregister
                            ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                            : branchRows.isEmpty
                            ? const Center(
                          child: Text(
                            'No Sales register found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                            :LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth > 800;

                            ///  DESKTOP — one row per branch, grand totals fixed at the bottom
                            if (isDesktop) {

                              return Column(
                                children: [

                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1B263B),
                                    ),
                                    child: Row(
                                      children: [
                                        // #
                                        const SizedBox(
                                          width: 45,
                                          child: Text(
                                            '#',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Branch
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Branch',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Cash Sales
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Cash Sales',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Cash Returns
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Cash Returns',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Credit Sales
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Credit Sales',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Credit Returns
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Credit Returns',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Cash Discount
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Cash Discount',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Credit Discount
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Credit Discount',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Profit
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Profit',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Cash @ Hand
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Cash @ Hand',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 2),

                                  // =========================
                                  // BRANCH ROWS
                                  // =========================
                                  Expanded(
                                    child: RawScrollbar(
                                      controller: verticalController,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      thumbColor: const Color(0xFF415A77),
                                      trackColor: const Color(0xFF22304A),
                                      trackBorderColor: const Color(0xFF1B263B),
                                      thickness: 10,
                                      radius: const Radius.circular(8),
                                      child: ListView.builder(
                                        controller: verticalController,
                                        itemCount: branchRows.length,
                                        itemBuilder: (context, index) {
                                          final item = branchRows[index];

                                          final cashSales =
                                          (item['cashSales'] as double);

                                          final creditSales =
                                          (item['creditSales'] as double);

                                          final creditReturns =
                                          (item['creditReturns'] as double);

                                          final cashDiscount =
                                          (item['cashDiscount'] as double);

                                          final creditDiscount =
                                          (item['creditDiscount'] as double);

                                          final cashReturns =
                                          (item['cashReturns'] as double);

                                          final cashAtHand =
                                          (item['cashAtHand'] as double);

                                          final profit =
                                          (item['profit'] as double);

                                          final branchName =
                                              item['branchName']?.toString() ?? '';
                                          final branchId =
                                              item['branchId']?.toString() ?? branchName;

                                          return InkWell(
                                            onTap: () {
                                              showSalesStaffDialog(
                                                context,
                                                branchId: branchId,
                                                branchName: branchName,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 15,
                                              ),
                                              decoration: BoxDecoration(
                                                color: index.isEven
                                                    ? const Color(0xFF0D1B2A)
                                                    : const Color(0xFF101C2E),
                                                border: const Border(
                                                  bottom: BorderSide(
                                                    color: Colors.white10,
                                                    width: 0.5,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  // =====================
                                                  // #
                                                  // =====================
                                                  SizedBox(
                                                    width: 45,
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),

                                                  // =====================
                                                  // BRANCH
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      branchName,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),

                                                  // =====================
                                                  // CASH SALES
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      cashSales.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),

                                                  // =====================
                                                  // CASH RETURNS
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      cashReturns.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),

                                                  // =====================
                                                  // CREDIT SALES
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      creditSales.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),

                                                  // =====================
                                                  // CREDIT RETURNS
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      creditReturns.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),

                                                  // =====================
                                                  // CASH DISCOUNT
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      cashDiscount.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),

                                                  // =====================
                                                  // CREDIT DISCOUNT
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      creditDiscount.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),

                                                  // =====================
                                                  // PROFIT
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      profit.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),

                                                  // =====================
                                                  // CASH @ HAND
                                                  // =====================
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      cashAtHand.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontWeight: FontWeight.bold,
                                                      ),
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

                                  // =========================
                                  // GRAND TOTAL — fixed footer row
                                  // =========================
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 15,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1B263B),
                                      border: Border(
                                        top: BorderSide(color: Colors.white24, width: 1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 45),
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'GRAND TOTAL',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            grandTotals['cashSales']!.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            grandTotals['cashReturns']!.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            grandTotals['creditSales']!.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            grandTotals['creditReturns']!.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            grandTotals['cashDiscount']!.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            grandTotals['creditDiscount']!.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            grandTotals['profit']!.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            grandTotals['cashAtHand']!.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.lightBlueAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            /// MOBILE — one card per branch, grand total pinned at the top
                            return Column(
                              children: [
                                /// TOTAL CASH @ HAND
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF22304A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Wrap(
                                    //  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "TOTAL CASH @ HAND",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "GHC ${globalCashAtHand.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                /// LIST — one card per branch
                                Expanded(
                                  child: Scrollbar(
                                    controller: verticalController,
                                    child: ListView.separated(
                                      controller: verticalController,
                                      itemCount: branchRows.length,
                                      separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final reportItem = branchRows[index];

                                        final cashSales =
                                        (reportItem['cashSales'] as double);

                                        final creditSales =
                                        (reportItem['creditSales'] as double);

                                        final creditReturns =
                                        (reportItem['creditReturns'] as double);

                                        final cashDiscount =
                                        (reportItem['cashDiscount'] as double);

                                        final creditDiscount =
                                        (reportItem['creditDiscount'] as double);

                                        final cashReturns =
                                        (reportItem['cashReturns'] as double);

                                        final profit = (reportItem['profit'] as double);

                                        final cashAtHand = (reportItem['cashAtHand'] as double);
                                        final branchname = reportItem['branchName'] ?? '';
                                        final branchId =
                                            reportItem['branchId']?.toString() ?? branchname.toString();

                                        return InkWell(
                                          onTap: () {
                                            showSalesStaffDialog(
                                              context,
                                              branchId: branchId,
                                              branchName: branchname.toString(),
                                            );
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 10,
                                              horizontal: 4,
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1B263B),
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  branchname.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),

                                                const SizedBox(height: 14),

                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: [
                                                    _miniStat("Cash Sales", cashSales),
                                                    _miniStat("Credit Sales", creditSales),
                                                    _miniStat("Cash Returns", cashReturns),
                                                    _miniStat(
                                                        "Credit Returns",
                                                        creditReturns),
                                                    _miniStat(
                                                        "Cash Discount",
                                                        cashDiscount),
                                                    _miniStat(
                                                        "Credit Discount",
                                                        creditDiscount),
                                                    _miniStat("Profit", profit),
                                                  ],
                                                ),

                                                const Divider(
                                                  color: Colors.white24,
                                                  height: 25,
                                                ),

                                                _summaryTile(
                                                  "Cash @ Hand",
                                                  cashAtHand,
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
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

    }
    Widget _miniStat(String title, double value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10)),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    Widget _summaryTile(String title, double value) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold)),
          Text(
            "GHC ${value.toStringAsFixed(2)}",
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),
        ],
      );
    }


    /// Opens the staff transactions summary for a single branch.
    /// [branchId] / [branchName] identify which branch row was tapped in the
    /// grouped table — if omitted, falls back to the logged-in user's own
    /// branch restriction (_selectedBranch), same as before.
    Future<void> showSalesStaffDialog(
        BuildContext context, {
          String? branchId,
          String? branchName,
        }) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final provider = Provider.of<Datafeed>(context, listen: false);

      try {
        final now = DateTime.now();

        final startDate = selectedDate?.start ?? now;
        final endDate = selectedDate?.end ?? now;

        final effectiveBranch = branchId ?? _selectedBranch;

        final shouldFilterByBranch =
            effectiveBranch != null &&
                effectiveBranch.trim().isNotEmpty &&
                effectiveBranch.toLowerCase() != 'all';

        final selectedBranchId =
            effectiveBranch?.trim().toLowerCase() ?? '';

        await provider.loadSalesStaffSummary(
          startDate: startDate,
          endDate: endDate,
          shouldFilterByBranch: shouldFilterByBranch,
          selectedBranchId: selectedBranchId,
        );

      } catch (e) {
        debugPrint("Error: $e");
      }

      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      showDialog(
        context: context,
        builder: (dialogContext) {
          final isSmallScreen =
              MediaQuery.of(dialogContext).size.width < 600;

          return Consumer<Datafeed>(
            builder: (context, provider, _) {
              final rows = provider.filteredSalesStaffRows();

              return AlertDialog(
                backgroundColor: const Color(0xFF101624),

                title: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            branchName != null
                                ? '${branchName.toUpperCase()} — STAFF TRANSACTIONS SUMMARY'
                                : 'STAFF TRANSACTIONS SUMMARY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      onChanged: (val){
                        provider.updateSearch(val);
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search staff...",
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF1A2235),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                content: SizedBox(
                  width: MediaQuery.of(dialogContext).size.width * 0.95,
                  child: rows.isEmpty
                      ? const Text(
                    "No transactions found",
                    style: TextStyle(color: Colors.white70),
                  )

                      : isSmallScreen
                      ? ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final t = rows[index];

                      final no = index + 1;
                      final staffname = t['staff'] ?? '';
                      final staffEmail = t['staffEmail'] ?? 0;
                      final cashSales = t['cashSales'] ?? 0;
                      final creditSales = t['creditSales'] ?? 0;
                      final creditReturns = t['creditReturns'] ?? 0;
                      final cashReturns = t['cashReturns'] ?? 0;
                      final cashDiscount = t['cashDiscount'] ?? 0;
                      final creditDiscount = (t['creditDiscount'] ?? 0).toDouble();

                      final merchantmomo = t['merchantmomo'] ?? 0;
                      final hubtel = t['hubtel'] ?? 0;
                      final card = t['card'] ?? 0;
                      final bank = t['bank'] ?? 0;
                      final cheque = t['cheque'] ?? 0;
                      final profit = t['profit'] ?? 0;
                      final todebtPayment = t['debtPayment'] ?? 0;
                      final debtpayment_cash = t['debtpayment_cash'] ?? 0;
                      final debtcard = t['debtcard'] ?? 0;
                      final debtcheque = t['debtcheque'] ?? 0;
                      final debtbank = t['debtbank'] ?? 0;
                      final debtmerchantmomo = t['debtmerchantmomo'] ?? 0;
                      final debthubtel = t['debthubtel'] ?? 0;
                      final cashAtHand = t['cashAtHand'] ?? 0;

                      return InkWell(
                        onTap: () {
                          showSalesStaffTransactionsDialog(
                            context,
                            staffName: staffname.toString(),
                            staffEmail: staffEmail.toString(),
                          );
                        },
                        child: Card(
                          color: const Color(0xFF1A2235),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#$no',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  staffname.toString(),
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    //  _miniStatstring("Quantity", quantity.toString()),
                                    _miniStatstring("Cash Sales", cashSales.toString()),
                                    _miniStatstring("Credit Sales", creditSales.toString()),
                                    _miniStatstringTap(
                                      "Merchant MoMo",
                                      (merchantmomo + debtmerchantmomo).toString(),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Merchant MoMo Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _row('Sales', merchantmomo),
                                                _row('Debt Payment', debtmerchantmomo),
                                                const Divider(),
                                                _row(
                                                  'Total',
                                                  merchantmomo + debtmerchantmomo,
                                                  bold: true,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    _miniStatstringTap(
                                      "Hubtel",
                                      (hubtel + debthubtel).toString(),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Hubtel Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _row('Sales', hubtel),
                                                _row('Debt Payment', debthubtel),
                                                const Divider(),
                                                _row('Total', hubtel + debthubtel, bold: true),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    _miniStatstringTap(
                                      "Card",
                                      (card + debtcard).toString(),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Card Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _row('Sales', card),
                                                _row('Debt Payment', debtcard),
                                                const Divider(),
                                                _row('Total', card + debtcard, bold: true),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    _miniStatstringTap(
                                      "Bank",
                                      (bank + debtbank).toString(),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Bank Transfer Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _row('Sales', bank),
                                                _row('Debt Payment', debtbank),
                                                const Divider(),
                                                _row('Total', bank + debtbank, bold: true),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    _miniStatstringTap(
                                      "Cheque",
                                      (cheque + debtcheque).toString(),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Cheque Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _row('Sales', cheque),
                                                _row('Debt Payment', debtcheque),
                                                const Divider(),
                                                _row('Total', cheque + debtcheque, bold: true),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    _miniStatstringTap(
                                      "Cash Discount",
                                      cashDiscount.toString(),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Discount Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _row('Cash Discount', cashDiscount),
                                                _row('Credit Discount', creditDiscount),
                                                const Divider(),
                                                _row(
                                                  'Total Discount',
                                                  cashDiscount + creditDiscount,
                                                  bold: true,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    _miniStatstringTap(
                                      "Cash Returns",
                                      cashReturns.toString(),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Cash Returns Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _row('Cash Returns', cashReturns),
                                                _row('Credit Returns', creditReturns),
                                                const Divider(),
                                                _row(
                                                  'Total Returns',
                                                  cashReturns + creditReturns,
                                                  bold: true,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    _miniStatstring("Cash Debt Payment", debtpayment_cash.toString()),

                                    _miniStatstringTap(
                                      "Total Debt Payment",
                                      todebtPayment.toString(),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Debt Payment Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _row('Card', debtcard),
                                                _row('Cheque', debtcheque),
                                                _row('Bank', debtbank),
                                                _row('Merchant MoMo', debtmerchantmomo),
                                                _row('Hubtel', debthubtel),
                                                const Divider(),
                                                _row('Total', todebtPayment, bold: true),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    _miniStatstring("Profit", profit.toString()),
                                    _miniStatstringTap(
                                      "Cash @ Hand",
                                      cashAtHand.toString(),
                                      onTap: () {
                                        final computedCashAtHand =
                                            cashSales + debtpayment_cash - cashReturns;

                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Cash @ Hand Breakdown'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _row('Cash Sales', cashSales),
                                                _row('Cash Debt Payment', debtpayment_cash),
                                                _row('Cash Returns', cashReturns),
                                                const Divider(),
                                                _row('Calculated Total', computedCashAtHand, bold: true),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                      :

                  LayoutBuilder(
                    builder: (context, constraints) {
                      const widths = [20, 130, 70, 60, 80, 70, 70, 80, 70, 80, 80, 80, 80, 70, 90];
                      const gap = 20.0;
                      final double contentWidth = widths.reduce((a, b) => a + b) +
                          (widths.length - 1) * gap +
                          32;
                      final double tableWidth =
                      constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

                      Widget rowOf(List<Widget> cells) {
                        return Container(
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

                      return RawScrollbar(
                        controller: _hhController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        thumbColor: const Color(0xFF415A77),
                        trackColor: const Color(0xFF22304A),
                        trackBorderColor: const Color(0xFF1B263B),
                        thickness: 10,
                        radius: const Radius.circular(8),
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: _hhController,
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
                                    Text('#', style: TextStyle(color: Colors.white)),
                                    Text('Staff', style: TextStyle(color: Colors.white)),
                                    Text('Cash Sales', style: TextStyle(color: Colors.white)),
                                    Text('Credit Sales', style: TextStyle(color: Colors.white)),
                                    Text('Merchant MoMo', style: TextStyle(color: Colors.white)),
                                    Text('Hubtel', style: TextStyle(color: Colors.white)),
                                    Text('Card', style: TextStyle(color: Colors.white)),
                                    Text('Bank transfer', style: TextStyle(color: Colors.white)),
                                    Text('Cheque', style: TextStyle(color: Colors.white)),
                                    Text('Cash Returns', style: TextStyle(color: Colors.white)),
                                    Text('Cash Discount', style: TextStyle(color: Colors.white)),
                                    Text('Cash Debt Payment', style: TextStyle(color: Colors.white)),
                                    Text('TotalDebt Payment', style: TextStyle(color: Colors.white)),
                                    Text('Profit', style: TextStyle(color: Colors.white)),
                                    Text('Cash @ Hand', style: TextStyle(color: Colors.white)),
                                  ]),
                                ),
                                Expanded(
                                  child: RawScrollbar(
                                    controller: _vvController,
                                    thumbVisibility: true,
                                    trackVisibility: true,
                                    thumbColor: const Color(0xFF415A77),
                                    trackColor: const Color(0xFF22304A),
                                    trackBorderColor: const Color(0xFF1B263B),
                                    thickness: 10,
                                    radius: const Radius.circular(8),
                                    scrollbarOrientation: ScrollbarOrientation.right,
                                    child: ListView.builder(
                                      controller: _vvController,
                                      itemCount: rows.length,
                                      itemBuilder: (context, i) {
                                        final t = rows[i];

                                        final staffname = (t['staff'] ?? '').toString();
                                        final staffEmail = (t['staffEmail'] ?? '').toString();
                                        final cashSales = (t['cashSales'] ?? 0).toDouble();
                                        final creditSales = (t['creditSales'] ?? 0).toDouble();
                                        final creditReturns = (t['creditReturns'] ?? 0).toDouble();
                                        final cashDiscount = (t['cashDiscount'] ?? 0).toDouble();
                                        final creditDiscount = (t['creditDiscount'] ?? 0).toDouble();
                                        final merchantmomo = (t['merchantmomo'] ?? 0).toDouble();
                                        final cashReturns = (t['cashReturns'] ?? 0).toDouble();
                                        final hubtel = (t['hubtel'] ?? 0).toDouble();
                                        final card = (t['card'] ?? 0).toDouble();
                                        final bank = (t['bank'] ?? 0).toDouble();
                                        final cheque = (t['cheque'] ?? 0).toDouble();
                                        final todebtPayment = (t['debtPayment'] ?? 0).toDouble();
                                        final debtpayment_cash = (t['debtpayment_cash'] ?? 0).toDouble();
                                        final profit = (t['profit'] ?? 0).toDouble();
                                        final cashAtHand = (t['cashAtHand'] ?? 0).toDouble();
                                        final debtcard = t['debtcard'] ?? 0;
                                        final debtcheque = t['debtcheque'] ?? 0;
                                        final debtbank = t['debtbank'] ?? 0;
                                        final debtmerchantmomo = t['debtmerchantmomo'] ?? 0;
                                        final debthubtel = t['debthubtel'] ?? 0;

                                        return InkWell(
                                          onTap: () {
                                            showSalesStaffTransactionsDialog(
                                              context,
                                              staffName: staffname,
                                              staffEmail: staffEmail,
                                            );
                                          },
                                          child: rowOf([
                                            Text('${i + 1}', style: const TextStyle(color: Colors.white70)),
                                            Text(staffname, style: const TextStyle(color: Colors.white70)),
                                            Text(cashSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white70)),
                                            Text(creditSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white70)),

                                            _breakdownCell(
                                              tooltipMessage:
                                              'Sales: ${merchantmomo.toStringAsFixed(2)}\nDebt Payment: ${debtmerchantmomo.toStringAsFixed(2)}\n\nTotal: ${(merchantmomo + debtmerchantmomo).toStringAsFixed(2)}',
                                              displayValue: (merchantmomo + debtmerchantmomo).toStringAsFixed(2),
                                              dialogTitle: 'Merchant MoMo Breakdown',
                                              dialogRows: [
                                                _row('Sales', merchantmomo),
                                                _row('Debt Payment', debtmerchantmomo),
                                                const Divider(),
                                                _row('Total', merchantmomo + debtmerchantmomo, bold: true),
                                              ],
                                            ),

                                            _breakdownCell(
                                              tooltipMessage:
                                              'Sales: ${hubtel.toStringAsFixed(2)}\nDebt Payment: ${debthubtel.toStringAsFixed(2)}\n\nTotal: ${(hubtel + debthubtel).toStringAsFixed(2)}',
                                              displayValue: (hubtel + debthubtel).toStringAsFixed(2),
                                              dialogTitle: 'Hubtel Breakdown',
                                              dialogRows: [
                                                _row('Sales', hubtel),
                                                _row('Debt Payment', debthubtel),
                                                const Divider(),
                                                _row('Total', hubtel + debthubtel, bold: true),
                                              ],
                                            ),

                                            _breakdownCell(
                                              tooltipMessage:
                                              'Sales: ${card.toStringAsFixed(2)}\nDebt Payment: ${debtcard.toStringAsFixed(2)}\n\nTotal: ${(card + debtcard).toStringAsFixed(2)}',
                                              displayValue: (card + debtcard).toStringAsFixed(2),
                                              dialogTitle: 'Card Breakdown',
                                              dialogRows: [
                                                _row('Sales', card),
                                                _row('Debt Payment', debtcard),
                                                const Divider(),
                                                _row('Total', card + debtcard, bold: true),
                                              ],
                                            ),

                                            _breakdownCell(
                                              tooltipMessage:
                                              'Sales: ${bank.toStringAsFixed(2)}\nDebt Payment: ${debtbank.toStringAsFixed(2)}\n\nTotal: ${(bank + debtbank).toStringAsFixed(2)}',
                                              displayValue: (bank + debtbank).toStringAsFixed(2),
                                              dialogTitle: 'Bank Transfer Breakdown',
                                              dialogRows: [
                                                _row('Sales', bank),
                                                _row('Debt Payment', debtbank),
                                                const Divider(),
                                                _row('Total', bank + debtbank, bold: true),
                                              ],
                                            ),

                                            _breakdownCell(
                                              tooltipMessage:
                                              'Sales: ${cheque.toStringAsFixed(2)}\nDebt Payment: ${debtcheque.toStringAsFixed(2)}\n\nTotal: ${(cheque + debtcheque).toStringAsFixed(2)}',
                                              displayValue: (cheque + debtcheque).toStringAsFixed(2),
                                              dialogTitle: 'Cheque Breakdown',
                                              dialogRows: [
                                                _row('Sales', cheque),
                                                _row('Debt Payment', debtcheque),
                                                const Divider(),
                                                _row('Total', cheque + debtcheque, bold: true),
                                              ],
                                            ),

                                            Tooltip(
                                              message:
                                              'Cash Returns: ${cashReturns.toStringAsFixed(2)}\nCredit Returns: ${creditReturns.toStringAsFixed(2)}\n\nTotal Returns: ${(cashReturns + creditReturns).toStringAsFixed(2)}',
                                              child: Text(
                                                cashReturns.toStringAsFixed(2),
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),

                                            _breakdownCell(
                                              tooltipMessage:
                                              'Cash Discount: ${cashDiscount.toStringAsFixed(2)}\nCredit Discount: ${creditDiscount.toStringAsFixed(2)}\n\nTotal Discount: ${(cashDiscount + creditDiscount).toStringAsFixed(2)}',
                                              displayValue: cashDiscount.toStringAsFixed(2),
                                              dialogTitle: 'Discount Breakdown',
                                              dialogRows: [
                                                _row('Cash Discount', cashDiscount),
                                                _row('Credit Discount', creditDiscount),
                                                const Divider(),
                                                _row('Total Discount', cashDiscount + creditDiscount, bold: true),
                                              ],
                                            ),

                                            Text(debtpayment_cash.toStringAsFixed(2), style: const TextStyle(color: Colors.white70)),

                                            _breakdownCell(
                                              tooltipMessage:
                                              'Card: ${debtcard.toStringAsFixed(2)}\nCheque: ${debtcheque.toStringAsFixed(2)}\nBank: ${debtbank.toStringAsFixed(2)}\nMerchant MoMo: ${debtmerchantmomo.toStringAsFixed(2)}\nHubtel: ${debthubtel.toStringAsFixed(2)}\nTotal: ${todebtPayment.toStringAsFixed(2)}',
                                              displayValue: todebtPayment.toStringAsFixed(2),
                                              dialogTitle: 'Debt Payment Breakdown',
                                              dialogRows: [
                                                _row('Card', debtcard),
                                                _row('Cheque', debtcheque),
                                                _row('Bank', debtbank),
                                                _row('Merchant MoMo', debtmerchantmomo),
                                                _row('Hubtel', debthubtel),
                                                const Divider(),
                                                _row('Total', todebtPayment, bold: true),
                                              ],
                                            ),

                                            Text(profit.toStringAsFixed(2), style: const TextStyle(color: Colors.white70)),

                                            Tooltip(
                                              message:
                                              'Cash Sales: ${cashSales.toStringAsFixed(2)}\nCash Debt Payment: ${debtpayment_cash.toStringAsFixed(2)}\nCash Returns: ${cashReturns.toStringAsFixed(2)}\nCalculated Total: ${(cashSales + debtpayment_cash - cashReturns).toStringAsFixed(2)}',
                                              child: InkWell(
                                                onTap: () {
                                                  final computedCashAtHand =
                                                      cashSales + debtpayment_cash - cashReturns;
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text('Cash @ Hand Breakdown'),
                                                      content: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          _row('Cash Sales', cashSales),
                                                          _row('Cash Debt Payment', debtpayment_cash),
                                                          _row('Cash Returns', cashReturns),
                                                          const Divider(),
                                                          _row('Calculated Total', computedCashAtHand, bold: true),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  cashAtHand.toStringAsFixed(2),
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ]),
                                        );
                                      },
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
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      final rows = provider.filteredSalesStaffRows();

                      /// SAFE NUMBER PARSER
                      double n(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

                      String fmt(dynamic v) => n(v).toStringAsFixed(2);
                      String t(double v) => v.toStringAsFixed(2);

                      /// PAYMENT TOTALS
                      double momo(Map<String, dynamic> item) =>
                          n(item['merchantmomo']) + n(item['debtmerchantmomo']);

                      double hubtel(Map<String, dynamic> item) =>
                          n(item['hubtel']) + n(item['debthubtel']);

                      double card(Map<String, dynamic> item) =>
                          n(item['card']) + n(item['debtcard']);

                      double bank(Map<String, dynamic> item) =>
                          n(item['bank']) + n(item['debtbank']);

                      double cheque(Map<String, dynamic> item) =>
                          n(item['cheque']) + n(item['debtcheque']);

                      /// BUILD PDF ROWS
                      final pdfRows = rows.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final item = Map<String, dynamic>.from(entry.value);

                        return [
                          '$index',
                          (item['staff'] ?? '').toString(),
                          fmt(item['quantity']),
                          fmt(item['cashSales']),
                          fmt(item['creditSales']),
                          fmt(momo(item)),
                          fmt(hubtel(item)),
                          fmt(card(item)),
                          fmt(bank(item)),
                          fmt(cheque(item)),
                          fmt(item['cashReturns']),
                          fmt(item['creditReturns']),
                          fmt(item['cashDiscount']),
                          fmt(item['creditDiscount']),
                          fmt(item['debtPayment']),
                          fmt(item['profit']),
                          fmt(item['cashAtHand']),
                        ];
                      }).toList();

                      /// TOTALS
                      double totQty = 0;
                      double totCashSales = 0;
                      double totCreditSales = 0;
                      double totMomo = 0;
                      double totHubtel = 0;
                      double totCard = 0;
                      double totBank = 0;
                      double totCheque = 0;
                      double totCashRet = 0;
                      double totCreditRet = 0;
                      double totCashDisc = 0;
                      double totCreditDisc = 0;
                      double totDebtPayment = 0;
                      double totProfit = 0;
                      double totCashHand = 0;

                      for (final row in rows) {
                        final item = Map<String, dynamic>.from(row);

                        totQty += n(item['quantity']);

                        totCashSales += n(item['cashSales']);
                        totCreditSales += n(item['creditSales']);

                        totMomo += momo(item);
                        totHubtel += hubtel(item);
                        totCard += card(item);
                        totBank += bank(item);
                        totCheque += cheque(item);

                        totCashRet += n(item['cashReturns']);
                        totCreditRet += n(item['creditReturns']);

                        totCashDisc += n(item['cashDiscount']);
                        totCreditDisc += n(item['creditDiscount']);

                        totDebtPayment += n(item['debtPayment']);
                        totProfit += n(item['profit']);

                        totCashHand += n(item['cashAtHand']);
                      }

                      await printReportPdf(
                        context: context,
                        reportTitle: 'Staff Transactions Summary',
                        companyName: provider.company,
                        branchName: branchName ?? _selectedBranch ?? 'All Branches',
                        dateRange: selectedDate,

                        columns: const [
                          PdfColumn('#', width: 18),
                          PdfColumn('Staff', width: 70),
                          PdfColumn('Qty', width: 30),
                          PdfColumn('Cash\nSales', width: 42),
                          PdfColumn('Credit\nSales', width: 42),
                          PdfColumn('MoMo', width: 36),
                          PdfColumn('Hubtel', width: 36),
                          PdfColumn('Card', width: 36),
                          PdfColumn('Bank', width: 36),
                          PdfColumn('Cheque', width: 36),
                          PdfColumn('Cash\nReturns', width: 42),
                          PdfColumn('Credit\nReturns', width: 42),
                          PdfColumn('Cash\nDiscount', width: 42),
                          PdfColumn('Credit\nDiscount', width: 42),
                          PdfColumn('Debt\nPayment', width: 42),
                          PdfColumn('Profit', width: 42),
                          PdfColumn('Cash @\nHand', width: 42),
                        ],

                        rows: pdfRows,

                        totalsRow: [
                          '',
                          'TOTAL',
                          t(totQty),
                          t(totCashSales),
                          t(totCreditSales),
                          t(totMomo),
                          t(totHubtel),
                          t(totCard),
                          t(totBank),
                          t(totCheque),
                          t(totCashRet),
                          t(totCreditRet),
                          t(totCashDisc),
                          t(totCreditDisc),
                          t(totDebtPayment),
                          t(totProfit),
                          t(totCashHand),
                        ],

                        summaryLines: [
                          PdfSummaryLine('Total Quantity', totQty),
                          PdfSummaryLine('Total Cash Sales', totCashSales),
                          PdfSummaryLine('Total Credit Sales', totCreditSales),
                          PdfSummaryLine('Total Debt Payment', totDebtPayment),
                          PdfSummaryLine('Total Profit', totProfit, highlight: true),
                          PdfSummaryLine('Cash @ Hand', totCashHand, highlight: true),
                        ],
                      );
                    },
                    child: const Text(
                      'Print / Download',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }


    Future<void> showSalesStaffTransactionsDialog(
        BuildContext context, {required String staffName, required String staffEmail}) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final provider = Provider.of<Datafeed>(context, listen: false);

      try {
        final now = DateTime.now();

        final startDate = selectedDate?.start ?? now;
        final endDate = selectedDate?.end ?? now;

        await provider.loadSalesStaffTransactions(
          startDate: startDate,
          endDate: endDate,
          staffName: staffName,
          staffEmail: staffEmail,
          companyId: provider.companyid,
          selectedBranch: _selectedBranch,
        );
      } catch (e) {
        debugPrint(e.toString());
      }

      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      showDialog(
        context: context,
        builder: (dialogContext) {
          final isSmallScreen = MediaQuery.of(dialogContext).size.width < 600;
          bool searchExpanded = false;

          return StatefulBuilder(
            builder: (context, setModalState) {
              return Consumer<Datafeed>(
                builder: (context, provider, _) {
                  final displayedSales = provider.filteredSalesStaffTransactions();

                  DateTime resolveDate(Map<String, dynamic> t) {
                    final datetime = t['datetime'];
                    if (datetime is Timestamp) return datetime.toDate();
                    return DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now();
                  }

                  Map<String, dynamic> resolveItems(Map<String, dynamic> t) {
                    final raw = t['items'];
                    if (raw is Map) return Map<String, dynamic>.from(raw);
                    return {};
                  }

                  Widget miniStat(String label, String value) {
                    return _miniStatstring(label, value);
                  }
                  Widget _kv(String label, String value) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
                          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                        ],
                      ),
                    );
                  }


                  void showItemsPopup(String receipt, List<_ItemLine> lines) {
                    Widget rowOf(_ItemLine line) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.name, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            _kv('Barcode', line.barcode),
                            _kv('Category', line.pcategory),
                            _kv('Type', line.productType),
                            _kv('Mode', line.mode),
                            _kv('MQty', line.modeQty),
                            _kv('Qty', '${line.qty}'),
                            _kv('BoxPiece', line.boxpiece),
                            _kv('Pieces', '${line.totalPieces}'),
                            _kv('PriceMode', capitalize(line.priceMode)),
                            _kv('Price', line.price.toStringAsFixed(2)),
                            _kv('CP', line.cp.toStringAsFixed(2)),
                            _kv('Disc', line.discount.toStringAsFixed(2)),
                            _kv('Total', line.grossTotalAmount.toStringAsFixed(2)),
                            _kv('Amount', line.totalAmount.toStringAsFixed(2)),
                            _kv('Profit', line.profit.toStringAsFixed(2)),
                          ],
                        ),
                      );
                    }

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF101624),
                        title: Text(receipt, style: const TextStyle(color: Colors.white70)),
                        content: SizedBox(
                          width: 1000,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = MediaQuery.of(context).size.width < 600;
                              if (lines.isEmpty) {
                                return const Text('No item detail', style: TextStyle(color: Colors.white70));
                              }
                              if (isMobile) {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: lines.length,
                                    itemBuilder: (context, i) => rowOf(lines[i]),
                                  ),
                                );
                              }
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columnSpacing: 10,
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                                    dataRowColor: WidgetStateProperty.all(const Color(0xFF101624)),
                                    columns: const [
                                      DataColumn(label: Text('Item', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Barcode', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Category', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Type', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Mode', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Mode Qty', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(label: Text('Qty', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(label: Text('Box/Piece', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Pieces', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(label: Text('Price Mode', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Price', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(label: Text('Cost Price', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(label: Text('Discount', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(label: Text('Gross Total', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(label: Text('Amount', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(label: Text('Profit', style: TextStyle(color: Colors.white)), numeric: true),
                                    ],
                                    rows: lines.map((line) {
                                      return DataRow(cells: [
                                        DataCell(Text(line.name, style: const TextStyle(color: Colors.white))),
                                        DataCell(Text(line.barcode, style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.pcategory, style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.productType, style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.mode, style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.modeQty, style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text('${line.qty}', style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.boxpiece, style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text('${line.totalPieces}', style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(capitalize(line.priceMode), style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.price.toStringAsFixed(2), style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.cp.toStringAsFixed(2), style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.discount.toStringAsFixed(2), style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.grossTotalAmount.toStringAsFixed(2), style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.totalAmount.toStringAsFixed(2), style: const TextStyle(color: Colors.white70))),
                                        DataCell(Text(line.profit.toStringAsFixed(2), style: const TextStyle(color: Colors.white70))),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  }

                  void showPaymentPopup(
                      String receipt, {
                        required List<_PaymentLine> payments,
                        required String paymentStatus,
                        required double amountPaid,
                        required double totalAmount,
                      }) {
                    Widget rowOf(_PaymentLine p) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(capitalize(p.method), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            _kv('Account Name', p.accountName),
                            _kv('Account Number', p.accountNumber),
                            _kv('Reference', p.reference),
                            _kv('Amount', p.amount.toStringAsFixed(2)),
                            Row(
                              children: [
                                const Text('Status: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text(
                                  p.status ? 'Success' : 'Failed',
                                  style: TextStyle(color: p.status ? Colors.greenAccent : Colors.redAccent, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF101624),
                        title: Text(receipt, style: const TextStyle(color: Colors.amberAccent)),
                        content: SizedBox(
                          width: 700,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 24,
                                  runSpacing: 8,
                                  children: [
                                    _miniStatstring('Total Amount', totalAmount.toStringAsFixed(2)),
                                    _miniStatstring('Amount Paid', amountPaid.toStringAsFixed(2)),
                                    _miniStatstring('Payment Status', capitalize(paymentStatus)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'PAYMENT BREAKDOWN',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final isMobile = MediaQuery.of(context).size.width < 600;
                                    if (payments.isEmpty) {
                                      return const Text('No payment detail', style: TextStyle(color: Colors.white70));
                                    }
                                    if (isMobile) {
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: payments.length,
                                        itemBuilder: (context, i) => rowOf(payments[i]),
                                      );
                                    }
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                                        dataRowColor: WidgetStateProperty.all(const Color(0xFF101624)),
                                        columns: const [
                                          DataColumn(label: Text('Method', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Account Name', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Account Number', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Reference', style: TextStyle(color: Colors.white))),
                                          DataColumn(label: Text('Amount', style: TextStyle(color: Colors.white)), numeric: true),
                                          DataColumn(label: Text('Status', style: TextStyle(color: Colors.white))),
                                        ],
                                        rows: payments.map((p) {
                                          return DataRow(cells: [
                                            DataCell(Text(capitalize(p.method), style: const TextStyle(color: Colors.white))),
                                            DataCell(Text(p.accountName, style: const TextStyle(color: Colors.white70))),
                                            DataCell(Text(p.accountNumber, style: const TextStyle(color: Colors.white70))),
                                            DataCell(Text(p.reference, style: const TextStyle(color: Colors.white70))),
                                            DataCell(Text(p.amount.toStringAsFixed(2), style: const TextStyle(color: Colors.white70))),
                                            DataCell(Text(
                                              p.status ? 'Success' : 'Failed',
                                              style: TextStyle(color: p.status ? Colors.greenAccent : Colors.redAccent),
                                            )),
                                          ]);
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  }

                  Widget buildTitle() {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: searchExpanded
                          ? Row(
                        key: const ValueKey('search-expanded'),
                        children: [
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              onChanged: (val) {
                                provider.updateSearch(val);
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Search...",
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF1A2235),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setModalState(() {
                              searchExpanded = false;
                              provider.updateSearch('');
                            }),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      )
                          : Row(
                        key: const ValueKey('search-collapsed'),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$staffName SALES TRANSACTIONS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setModalState(() => searchExpanded = true),
                            child: const Text('Search', style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Close', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    );
                  }

                  return AlertDialog(
                    backgroundColor: const Color(0xFF101624),
                    insetPadding: const EdgeInsets.all(12),
                    title: buildTitle(),
                    content: SizedBox(
                      width: double.maxFinite,
                      height: MediaQuery.sizeOf(context).height * 0.95,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: displayedSales.isEmpty
                                ? const Center(
                              child: Text(
                                "No transactions found",
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                                : isSmallScreen
                                ? ListView.builder(
                              itemCount: displayedSales.length,
                              itemBuilder: (context, index) {
                                final t = displayedSales[index];

                                final no = index + 1;
                                final datee = resolveDate(t);
                                final formattedDate =
                                DateFormat('yyyy-MM-dd – hh:mm a').format(datee);
                                final receipt = t['receipt'] ?? '';
                                final customer = t['customer'] ?? '';
                                final amount =
                                    double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
                                final amountPaid =
                                    double.tryParse(t['amountPaid']?.toString() ?? '0') ?? 0.0;
                                final discount =
                                    double.tryParse(t['discount']?.toString() ?? '0') ?? 0.0;
                                final payment = (t['payment'] ?? '').toString();
                                final itemMap = resolveItems(t);
                                final itemLines = _parseItemLines(t['items']);

                                return Card(
                                  color: const Color(0xFF1A2235),
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '#$no',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          receipt.toString(),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            miniStat("Customer", customer.toString()),
                                            InkWell(
                                              onTap: () => showPaymentPopup(
                                                receipt.toString(),
                                                payments: _parsePaymentLines(t['payments']),
                                                paymentStatus: (t['paymentStatus'] ?? '').toString(),
                                                amountPaid: amountPaid,
                                                totalAmount: amount,
                                              ),
                                              child: miniStat("Payment", capitalize(payment)),
                                            ),
                                            miniStat("Amount", amount.toStringAsFixed(2)),
                                            miniStat("Amount Paid", amountPaid.toStringAsFixed(2)),
                                            miniStat("Discount", discount.toStringAsFixed(2)),
                                            InkWell(
                                              onTap: () =>
                                                  showItemsPopup(receipt.toString(), itemLines),
                                              child: miniStat("Items", '${itemMap.length}'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                                : LayoutBuilder(
                              builder: (context, constraints) {
                                const widths = [30, 170, 150, 190, 90, 60, 90, 80, 80];
                                const gap = 15.0;
                                final double contentWidth = widths.reduce((a, b) => a + b) +
                                    (widths.length - 1) * gap +
                                    32;
                                final double tableWidth = constraints.maxWidth > contentWidth
                                    ? constraints.maxWidth
                                    : contentWidth;

                                Widget rowOf(List<Widget> cells) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    constraints:
                                    const BoxConstraints(minHeight: 46, maxHeight: 64),
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

                                Widget headerCell(String label, {bool alignRight = false}) {
                                  return Text(
                                    label,
                                    textAlign: alignRight ? TextAlign.right : TextAlign.left,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }

                                return RawScrollbar(
                                  controller: _hController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  thumbColor: const Color(0xFF415A77),
                                  trackColor: const Color(0xFF22304A),
                                  trackBorderColor: const Color(0xFF1B263B),
                                  thickness: 10,
                                  radius: const Radius.circular(8),
                                  scrollbarOrientation: ScrollbarOrientation.bottom,
                                  child: SingleChildScrollView(
                                    controller: _hController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      height: constraints.maxHeight.isFinite
                                          ? constraints.maxHeight
                                          : null,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            color: const Color(0xFF1E2A3D),
                                            child: rowOf([
                                              headerCell('#'),
                                              headerCell('Date'),
                                              headerCell('Receipt'),
                                              headerCell('Customer'),
                                              headerCell('Items'),
                                              headerCell('Amount', alignRight: true),
                                              headerCell('Amount Paid', alignRight: true),
                                              headerCell('Discount', alignRight: true),
                                              headerCell('Payment'),
                                            ]),
                                          ),
                                          Expanded(
                                            child: RawScrollbar(
                                              controller: _vController,
                                              thumbVisibility: true,
                                              trackVisibility: true,
                                              thumbColor: const Color(0xFF415A77),
                                              trackColor: const Color(0xFF22304A),
                                              trackBorderColor: const Color(0xFF1B263B),
                                              thickness: 10,
                                              radius: const Radius.circular(8),
                                              scrollbarOrientation: ScrollbarOrientation.right,

                                              child: ListView.builder(
                                                controller: _vController,
                                                itemCount: displayedSales.length,
                                                itemBuilder: (context, i) {
                                                  final s = displayedSales[i];
                                                  final date = resolveDate(s);
                                                  final formattedDate =
                                                  DateFormat('yyyy-MM-dd – hh:mm a').format(date);
                                                  final amountRow = double.tryParse(
                                                      s['amount']?.toString() ?? '0') ??
                                                      0.0;
                                                  final amountPaidRow = double.tryParse(
                                                      s['amountPaid']?.toString() ?? '0') ??
                                                      0.0;
                                                  final discountRow = double.tryParse(
                                                      s['discount']?.toString() ?? '0') ??
                                                      0.0;
                                                  final paymentRow = (s['payment'] ?? '').toString();
                                                  final receiptRow = (s['receipt'] ?? '').toString();
                                                  final itemMapRow = resolveItems(s);
                                                  final itemLinesRow = _parseItemLines(s['items']);

                                                  return rowOf([
                                                    Text('${i + 1}',
                                                        style: const TextStyle(color: Colors.white70)),
                                                    Text(formattedDate,
                                                        style: const TextStyle(color: Colors.white70)),
                                                    InkWell(
                                                      onTap: () async {
                                                        await Clipboard.setData(
                                                          ClipboardData(text: receiptRow),
                                                        );
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Receipt copied')),
                                                        );
                                                      },
                                                      child: Text(
                                                        receiptRow,
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                      ),
                                                    ),
                                                    Text('${s['customer'] ?? ''}',
                                                        style: const TextStyle(color: Colors.white70)),
                                                    InkWell(
                                                      onTap: () => showItemsPopup(
                                                          receiptRow, itemLinesRow),
                                                      child: Text(
                                                        '${itemMapRow.length}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      amountRow.toStringAsFixed(2),
                                                      textAlign: TextAlign.right,
                                                      style: const TextStyle(color: Colors.white70),
                                                    ),
                                                    Text(
                                                      amountPaidRow.toStringAsFixed(2),
                                                      textAlign: TextAlign.right,
                                                      style: const TextStyle(color: Colors.white70),
                                                    ),
                                                    Text(
                                                      discountRow.toStringAsFixed(2),
                                                      textAlign: TextAlign.right,
                                                      style: const TextStyle(color: Colors.white70),
                                                    ),
                                                    InkWell(
                                                      onTap: () => showPaymentPopup(
                                                        receiptRow,
                                                        payments: _parsePaymentLines(s['payments']),
                                                        paymentStatus: (s['paymentStatus'] ?? '').toString(),
                                                        amountPaid: amountPaidRow,
                                                        totalAmount: amountRow,
                                                      ),
                                                      child: Text(
                                                        capitalize(paymentRow),
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                      ),
                                                    ),
                                                  ]);
                                                },
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
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          await printSalesStaffTransactionsPdf(
                            staffName: staffName,
                            sales: displayedSales,
                            companyName: provider.company,
                            branchName: _selectedBranch ?? 'All Branches',
                            dateRange: selectedDate,
                          );
                        },
                        child: const Text(
                          'Print/download',
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    }

    double n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

    Widget _miniStatstring(String title, dynamic value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10)),
            Text(
              value.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    Widget _row(String label, num value, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }
    Widget _miniStatstringTap(
        String label,
        String value, {
          VoidCallback? onTap,
        }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF22304A),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "$label: $value",
            style: const TextStyle(
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }
    DataCell paymentBreakdownCell(
        BuildContext context,
        String title,
        double sales,
        double debt,
        ) {
      return DataCell(
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('$title Breakdown'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _row('Sales', sales),
                    _row('Debt Payment', debt),
                    const Divider(),
                    _row('Total', sales + debt, bold: true),
                  ],
                ),
              ),
            );
          },
          child: Text(
            sales.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }

    Widget _breakdownCell({
      required String tooltipMessage,
      required String displayValue,
      required String dialogTitle,
      required List<Widget> dialogRows,
    }) {
      return Tooltip(
        message: tooltipMessage,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(dialogTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: dialogRows,
                ),
              ),
            );
          },
          child: Text(
            displayValue,
            style: const TextStyle(
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }

  }

  class _ItemLine {
    final String name;
    final num qty;
    final String barcode;
    final String boxpiece;
    final double cp;
    final double discount;
    final double grossTotalAmount;
    final String mode;
    final String modeQty;
    final String pcategory;
    final double price;
    final String priceMode;
    final String productType;
    final double profit;
    final double totalAmount;
    final num totalPieces;
    _ItemLine({
      required this.name,
      required this.qty,
      this.barcode = '',
      this.boxpiece = '',
      this.cp = 0.0,
      this.discount = 0.0,
      this.grossTotalAmount = 0.0,
      this.mode = '',
      this.modeQty = '',
      this.pcategory = '',
      this.price = 0.0,
      this.priceMode = '',
      this.productType = '',
      this.profit = 0.0,
      this.totalAmount = 0.0,
      this.totalPieces = 0,
    });
  }
  class _PaymentLine {
    final String accountName;
    final String accountNumber;
    final double amount;
    final String method;
    final String reference;
    final bool status;
    _PaymentLine({
      required this.accountName,
      required this.accountNumber,
      required this.amount,
      required this.method,
      required this.reference,
      required this.status,
    });
  }

  List<_PaymentLine> _parsePaymentLines(dynamic paymentsField) {
    final lines = <_PaymentLine>[];
    if (paymentsField is! List) return lines;

    for (final value in paymentsField) {
      if (value is! Map) continue;
      lines.add(_PaymentLine(
        accountName: (value['accountName'] ?? '').toString(),
        accountNumber: (value['accountNumber'] ?? '').toString(),
        amount: double.tryParse(value['amount']?.toString() ?? '0') ?? 0.0,
        method: (value['method'] ?? '').toString(),
        reference: (value['reference'] ?? '').toString(),
        status: value['status'] == true,
      ));
    }
    return lines;
  }

  List<_ItemLine> _parseItemLines(dynamic itemsField) {
    final lines = <_ItemLine>[];

    double d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
    num n(dynamic v) {
      final s = v?.toString() ?? '0';
      return num.tryParse(s) ?? 0;
    }

    void addEntry(dynamic value, String fallbackName) {
      if (value is! Map) return;
      final name = (value['item'] ?? value['name'] ?? fallbackName).toString();
      final rawQty = value['quantity'] ?? value['qty'] ?? 0;
      final qty = rawQty is num ? rawQty : num.tryParse(rawQty.toString()) ?? 0;

      lines.add(_ItemLine(
        name: name,
        qty: qty,
        barcode: (value['barcode'] ?? '').toString(),
        boxpiece: (value['boxpiece'] ?? '').toString(),
        cp: d(value['cp']),
        discount: d(value['discount']),
        grossTotalAmount: d(value['grosstotalamount']),
        mode: (value['mode'] ?? '').toString(),
        modeQty: (value['modeqty'] ?? '').toString(),
        pcategory: (value['pcategory'] ?? '').toString(),
        price: d(value['price']),
        priceMode: (value['pricemode'] ?? '').toString(),
        productType: (value['producttype'] ?? '').toString(),
        profit: d(value['profit']),
        totalAmount: d(value['totalamount']),
        totalPieces: n(value['totalpieces']),
      ));
    }

    if (itemsField is Map) {
      for (final entry in itemsField.entries) {
        addEntry(entry.value, entry.key.toString());
      }
    } else if (itemsField is List) {
      for (final value in itemsField) {
        addEntry(value, '');
      }
    }

    return lines;
  }
