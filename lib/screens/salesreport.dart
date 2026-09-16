
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import '../widgets/printreportpdf.dart';


class SalesReport extends StatefulWidget {
  const SalesReport({super.key});

  @override
  State<SalesReport> createState() => _SalesReportState();
}

class _SalesReportState extends State<SalesReport> {
  String searchQuery = '';
  DateTimeRange? selectedDate;
  String? _selectedBranch;

  late final ScrollController verticalController;
  late final ScrollController horizontalController;
  final TextEditingController _mainSearchController = TextEditingController();
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  late final ScrollController _vverticalController;
  late final ScrollController _vhorizontalController;

  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void dispose() {
    selectedDate = null;
    _selectedBranch = null;
    verticalController.dispose();
    horizontalController.dispose();
    _mainSearchController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();

    _vverticalController.dispose();
    _vhorizontalController.dispose();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    horizontalController = ScrollController();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();

    _vverticalController = ScrollController();
    _vhorizontalController = ScrollController();
    Future.microtask((){
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchsalesreport(selectedDate: selectedDate,);
    });

  }
  @override
  Widget build(BuildContext context) {

    final screenWidth =MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final resultList = value.filterbranchsalesreport();
        final totalCashSales = value.branchTotalCashSales;
        final totalCreditSales = value.branchTotalCreditSales;
        final totalCashReturns = value.branchTotalCashReturns;
        final totalCreditReturns  = value.branchTotalCreditReturns;
        final totalReturns = value.branchTotalReturns;
        final totalDiscount = value.branchTotalDiscount;
        final totalprofit   = value.branchTotalProfit;
        final totalRowTotal  = value.branchTotalRowTotal;
        final debttotal    = value.branchreportDebttotal;
        final grandTotal   = value.branchGrandTotal;
        final globalCashAtHand = value.branchCashAtHand ;
        final totallcash = totalCashSales - totalCashReturns;

        final totalsal = totalCashSales + totalCreditSales;

        return Scaffold(
          backgroundColor: const Color(0xFF101624),

         appBar: AppBar(
           title: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text(
                 'Sales Report',
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
               ),
             ],
           ),
           centerTitle: true,
           actions: [
             TextButton(
                 onPressed: (){
                   Navigator.pushNamed(context, Routes.home);
                 }, child: Text('Home',style: TextStyle(color: Colors.white),)
             ),
             ReusableDatePickerWidget(
               onDateSelected: (selection) {
                 setState(() => selectedDate = selection);
                 context.read<Datafeed>().fetchsalesreport(
                   selectedDate: selectedDate,
                   selectedBranch: _selectedBranch,
                 );
               },
               child: Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 12),
                 child: Icon(Icons.calendar_today_rounded, size: 22),
               ),
             ),
           ],
         ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth),
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
                                              'Sales report for  ',
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
                                        controller: _mainSearchController,
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
                                    ReusableDatePickerWidget(
                                      onDateSelected: (selection) {
                                        setState(() => selectedDate = selection);
                                        context.read<Datafeed>().fetchsalesreport(
                                          selectedDate: selectedDate,
                                          selectedBranch: _selectedBranch,
                                        );
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22304A),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              size: 16,
                                              color: Colors.white.withOpacity(0.5),
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              'Pick date range',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 13,
                                              ),
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
                                          controller: _mainSearchController,
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
                                    ReusableDatePickerWidget(
                                      onDateSelected: (selection) {
                                        setState(() => selectedDate = selection);
                                        context.read<Datafeed>().fetchsalesreport(
                                          selectedDate: selectedDate,
                                          selectedBranch: _selectedBranch,
                                        );
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22304A),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              size: 16,
                                              color: Colors.white.withOpacity(0.5),
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              'Pick date range',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),


                                isMobile
                                    ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [

                                        Expanded(
                                          child: SizedBox(
                                            height: 42,
                                            child: DropdownButtonFormField<String>(
                                              value: _selectedBranch ?? '',
                                              isExpanded: true,
                                              dropdownColor: const Color(0xFF22304A),
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: 'Select Branch',
                                                labelStyle: const TextStyle(color: Colors.white70),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Colors.white24),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Colors.blue),
                                                ),
                                                fillColor: const Color(0xFF22304A),
                                                filled: true,
                                              ),
                                              items: [
                                                const DropdownMenuItem<String>(
                                                  value: '',
                                                  child: Text('All Branches'),
                                                ),
                                                ...value.branches.map((branch) {
                                                  return DropdownMenuItem<String>(
                                                    value: branch.id,
                                                    child: Text(branch.branchname),
                                                  );
                                                }).toList(),
                                              ],
                                              onChanged: (val) {
                                                setState(() {
                                                  _selectedBranch = (val == null || val.isEmpty)
                                                      ? null
                                                      : val;
                                                });
                                                value.fetchsalesreport(
                                                  selectedDate: selectedDate,
                                                  selectedBranch: _selectedBranch,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                        label: const Text(
                                          'Print/Download',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF22304A),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                        ),
                                        onPressed: () {
                                          final provider = context.read<Datafeed>();
                                          final cashAtHand = totalCashSales - totalCashReturns;

                                          printReportPdf(
                                            context: context,
                                            reportTitle: 'Sales Report',
                                            companyName:  provider.company,
                                            branchName: _selectedBranch ?? 'All Branches',
                                            dateRange: selectedDate,
                                            columns: const [
                                              PdfColumn('#',width: 18),
                                              PdfColumn('Branch',width: 100),
                                              PdfColumn('Cash Sales',width: 52),
                                              PdfColumn('Credit Sales',width: 52),
                                              PdfColumn('Total Sales',width: 30),
                                              PdfColumn('Cash Returns',width: 52),
                                              PdfColumn('Credit Returns',width: 55),
                                              PdfColumn('Total Returns',width: 42),
                                              PdfColumn('Discount',width: 42),
                                              PdfColumn('Profit',width: 45),
                                              PdfColumn('Cash@Hand', width: 50),
                                            ],
                                            rows: resultList.asMap().entries.map((e) {
                                              final i    = e.key;
                                              final item = e.value;
                                              final branch =   item['branchName']?.toString()   ?? '';
                                              final cashsales = (item['cashSales'] ?? 0.0).toDouble();
                                              final creditsales = (item['creditSales'] ?? 0.0).toDouble();
                                              final totalsales = cashsales + creditsales;
                                              final cashreturns = (item['cashReturns'] ?? 0.0).toDouble();
                                              final creditreturns = (item['creditReturns'] ?? 0.0).toDouble();
                                              final totalreturns = (item['totalReturns'] ?? 0.0).toDouble();
                                              final discount = (item['discount'] ?? 0.0).toDouble();
                                              final profit = (item['profit'] ?? 0.0).toDouble();
                                              final cashtotal = cashsales - cashreturns;
                                              return <String>[
                                                '${i + 1}',
                                                branch,
                                                cashsales.toStringAsFixed(2),
                                                creditsales.toStringAsFixed(2),
                                                totalsales.toStringAsFixed(2),
                                                cashreturns.toStringAsFixed(2),
                                                creditreturns.toStringAsFixed(2),
                                                totalreturns.toStringAsFixed(2),
                                                discount.toStringAsFixed(2),
                                                profit.toStringAsFixed(2),
                                                cashtotal.toStringAsFixed(2),
                                              ];
                                            }).toList(),
                                            totalsRow: [
                                              '',
                                              'Grand Total',
                                              totalCashSales.toStringAsFixed(2),
                                              totalCreditSales.toStringAsFixed(2),
                                              totalsal.toStringAsFixed(2),
                                              totalCashReturns.toStringAsFixed(2),
                                              totalCreditReturns.toStringAsFixed(2),
                                              totalReturns.toStringAsFixed(2),
                                              totalDiscount.toStringAsFixed(2),
                                              totalprofit.toStringAsFixed(2),
                                              (totallcash).toStringAsFixed(2),
                                            ],
                                            summaryLines: [
                                              PdfSummaryLine('Cash Sales',    totalCashSales),
                                              PdfSummaryLine('Credit Sales',  totalCreditSales),
                                              PdfSummaryLine('Total Returns', totalReturns),
                                              PdfSummaryLine('Discount',      totalDiscount),
                                              PdfSummaryLine('Profit',        totalprofit),
                                              PdfSummaryLine('Debt Payment',  debttotal),
                                              PdfSummaryLine('Grand Total',   totalRowTotal ),
                                              PdfSummaryLine('Cash @ Hand',   cashAtHand, highlight: true),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                                    : Row(
                                  children: [
                                    Icon(
                                      Icons.storefront_rounded,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 42,
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedBranch ?? '',
                                          dropdownColor: const Color(0xFF22304A),
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            labelText: 'Select Branch',
                                            labelStyle: const TextStyle(color: Colors.white70),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Colors.white24),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Colors.blue),
                                            ),
                                            fillColor: const Color(0xFF22304A),
                                            filled: true,
                                          ),
                                          items: [
                                            const DropdownMenuItem<String>(
                                              value: '',
                                              child: Text('All Branches'),
                                            ),
                                            ...value.branches.map((branch) {
                                              return DropdownMenuItem<String>(
                                                value: branch.id,
                                                child: Text(branch.branchname),
                                              );
                                            }).toList(),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              _selectedBranch = (val == null || val.isEmpty)
                                                  ? null
                                                  : val;
                                            });
                                            value.fetchsalesreport(
                                              selectedDate: selectedDate,
                                              selectedBranch: _selectedBranch,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                      label: const Text(
                                        'Print/Download',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF22304A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                      ),
                                      onPressed: () {
                                        final provider = context.read<Datafeed>();
                                        final cashAtHand = totalCashSales - totalCashReturns;

                                        printReportPdf(
                                          context: context,
                                          reportTitle: 'Sales Report',
                                          companyName:  provider.company,
                                          branchName: _selectedBranch ?? 'All Branches',
                                          dateRange: selectedDate,
                                          columns: const [
                                            PdfColumn('#',width: 18),
                                            PdfColumn('Branch',width: 100),
                                            PdfColumn('Cash Sales',width: 52),
                                            PdfColumn('Credit Sales',width: 52),
                                            PdfColumn('Total Sales',width: 30),
                                            PdfColumn('Cash Returns',width: 52),
                                            PdfColumn('Credit Returns',width: 55),
                                            PdfColumn('Total Returns',width: 42),
                                            PdfColumn('Discount',width: 42),
                                            PdfColumn('Profit',width: 45),
                                            PdfColumn('Cash@Hand', width: 50),
                                          ],
                                          rows: resultList.asMap().entries.map((e) {
                                            final i    = e.key;
                                            final item = e.value;
                                            final branch =   item['branchName']?.toString()   ?? '';
                                            final cashsales = (item['cashSales'] ?? 0.0).toDouble();
                                            final creditsales = (item['creditSales'] ?? 0.0).toDouble();
                                            final totalsales = cashsales + creditsales;
                                            final cashreturns = (item['cashReturns'] ?? 0.0).toDouble();
                                            final creditreturns = (item['creditReturns'] ?? 0.0).toDouble();
                                            final totalreturns = (item['totalReturns'] ?? 0.0).toDouble();
                                            final discount = (item['discount'] ?? 0.0).toDouble();
                                            final profit = (item['profit'] ?? 0.0).toDouble();
                                            final cashtotal = cashsales - cashreturns;
                                            return <String>[
                                              '${i + 1}',
                                              branch,
                                              cashsales.toStringAsFixed(2),
                                              creditsales.toStringAsFixed(2),
                                              totalsales.toStringAsFixed(2),
                                              cashreturns.toStringAsFixed(2),
                                              creditreturns.toStringAsFixed(2),
                                              totalreturns.toStringAsFixed(2),
                                              discount.toStringAsFixed(2),
                                              profit.toStringAsFixed(2),
                                              cashtotal.toStringAsFixed(2),
                                            ];
                                          }).toList(),
                                          totalsRow: [
                                            '',
                                            'Grand Total',
                                            totalCashSales.toStringAsFixed(2),
                                            totalCreditSales.toStringAsFixed(2),
                                            totalsal.toStringAsFixed(2),
                                            totalCashReturns.toStringAsFixed(2),
                                            totalCreditReturns.toStringAsFixed(2),
                                            totalReturns.toStringAsFixed(2),
                                            totalDiscount.toStringAsFixed(2),
                                            totalprofit.toStringAsFixed(2),
                                            (totallcash).toStringAsFixed(2),
                                          ],
                                          summaryLines: [
                                            PdfSummaryLine('Cash Sales',    totalCashSales),
                                            PdfSummaryLine('Credit Sales',  totalCreditSales),
                                            PdfSummaryLine('Total Returns', totalReturns),
                                            PdfSummaryLine('Discount',      totalDiscount),
                                            PdfSummaryLine('Profit',        totalprofit),
                                            PdfSummaryLine('Debt Payment',  debttotal),
                                            PdfSummaryLine('Grand Total',   totalRowTotal ),
                                            PdfSummaryLine('Cash @ Hand',   cashAtHand, highlight: true),
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
                        child: value.isloadingsalesreport
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : resultList.isEmpty
                            ? const Center(
                            child: Text('No Sales found',
                                style: TextStyle(color: Colors.white70)))
                            : LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth > 600;

                            final grandTotalRow    = value.calcGrandTotal(resultList);
                            final totalQty         = grandTotalRow['sales_qty']     as double;
                            final totalCashSales   = grandTotalRow['cashSales']     as double;
                            final totalCreditSales = grandTotalRow['creditSales']   as double;
                            final totalTotalSales  = grandTotalRow['totalSales']    as double;
                            final totalCashRet     = grandTotalRow['cashReturns']   as double;
                            final totalCreditRet   = grandTotalRow['creditReturns'] as double;
                            final totalReturns     = grandTotalRow['totalReturns']  as double;
                            final totalDiscount    = grandTotalRow['discount']      as double;
                            final totalProfit      = grandTotalRow['profit']        as double;

                            if (isDesktop) {

                              return ScrollbarTheme(
                                data: ScrollbarThemeData(
                                  thumbColor:       MaterialStateProperty.all(const Color(0xFF415A77)),
                                  trackColor:       MaterialStateProperty.all(const Color(0xFF22304A)),
                                  trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
                                  thickness:        MaterialStateProperty.all(10),
                                  radius:           const Radius.circular(8),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    const widths = [30, 130, 90, 90, 90, 100, 90, 80, 80, 90];
                                    const gap = 24.0;
                                    final double contentWidth = widths.reduce((a, b) => a + b) +
                                        (widths.length - 1) * gap +
                                        32;
                                    final double tableWidth =
                                    constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

                                    Widget rowOf(List<Widget> cells, {Color? color}) {
                                      return Container(
                                        color: color,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

                                    return Scrollbar(
                                      controller: _vhorizontalController,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _vhorizontalController,
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
                                                  Text("#", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                //  Text("Branch", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Cash Sales", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Credit Sales", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Total Sales", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Cash Returns", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Credit Returns", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Total Returns", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Discount", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Profit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Cash@Hand", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                ]),
                                              ),
                                              Expanded(
                                                child: Scrollbar(
                                                  controller: _vverticalController,
                                                  thumbVisibility: true,
                                                  trackVisibility: true,
                                                  child: ListView.builder(
                                                    controller: _vverticalController,
                                                    itemCount: resultList.length + 2,
                                                    itemBuilder: (context, index) {
                                                      if (index == resultList.length) {
                                                        // Grand Total row
                                                        return rowOf(
                                                          [
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            const Text("Grand Total",
                                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                            Text(totalCashSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(totalCreditSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(totalTotalSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(totalCashRet.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(totalCreditRet.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(totalReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(totalDiscount.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text((totalProfit).toStringAsFixed(2), style: const TextStyle(color: Colors.white)),

                                                          ],
                                                          color: const Color(0xFF16213E),
                                                        );
                                                      }
                                                      if (index == resultList.length + 1) {
                                                        // Total Cash @ Hand row
                                                        return rowOf(
                                                          [
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            const Text("Total Cash @ Hand",
                                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            const Text("", style: TextStyle(color: Colors.white)),
                                                            Text(
                                                              globalCashAtHand.toStringAsFixed(2),
                                                              style: const TextStyle(
                                                                color: Colors.greenAccent,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                          color: const Color(0xFF1D3557),
                                                        );
                                                      }

                                                      final row           = resultList[index];
                                                      final branchId      = row['branchId']      ?? '';
                                                      final branchName    = row['branchName']    ?? '';
                                                      final cashSales     = (row['cashSales']    ?? 0.0) as double;
                                                      final creditSales   = (row['creditSales']  ?? 0.0) as double;
                                                      final totalSales    = (row['totalSales']   ?? 0.0) as double;
                                                      final cashReturns   = (row['cashReturns']  ?? 0.0) as double;
                                                      final creditReturns = (row['creditReturns']?? 0.0) as double;
                                                      final returns       = (row['totalReturns'] ?? 0.0) as double;
                                                      final discount      = (row['discount']     ?? 0.0) as double;
                                                      final profit        = (row['profit']       ?? 0.0) as double;
                                                      final cashAtHand    = cashSales - cashReturns;

                                                      return InkWell(
                                                        onTap: () => showBranchItemTransactionsDialog(
                                                          context,
                                                          itemId:   branchId,
                                                          itemName: branchName,
                                                          branchId: branchId,
                                                        ),
                                                        child: rowOf(
                                                          [
                                                            Text("${index + 1}", style: const TextStyle(color: Colors.white)),
                                                           // Text(branchName, style: const TextStyle(color: Colors.white)),
                                                            Text(cashSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(creditSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(totalSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(cashReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(creditReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(returns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(discount.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(profit.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                            Text(cashAtHand.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
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
                                    );
                                  },
                                ),
                              );
                            }

                            // mobile view
                            return Column(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("TOTAL CASH @ HAND",
                                          style: TextStyle(
                                              color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text(
                                        "GHC ${globalCashAtHand.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: resultList.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final row           = resultList[index];
                                      final branchId      = row['branchId']      ?? '';
                                      final branchName    = row['branchName']    ?? '';
                                      final company       = row['company']       ?? '';
                                      final qty           = (row['sales_qty']    ?? 0.0) as double;
                                      final cashSales     = (row['cashSales']    ?? 0.0) as double;
                                      final creditSales   = (row['creditSales']  ?? 0.0) as double;
                                      final cashReturns   = (row['cashReturns']  ?? 0.0) as double;
                                      final creditReturns = (row['creditReturns']?? 0.0) as double;
                                      final discount      = (row['discount']     ?? 0.0) as double;
                                      final profit        = (row['profit']       ?? 0.0) as double;

                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B263B),
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: InkWell(
                                          onTap: () => showBranchItemTransactionsDialog(
                                            context,
                                            itemId:   branchId,
                                            itemName: branchName,
                                            branchId: branchId,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(branchName,
                                                  style: const TextStyle(
                                                      color: Colors.amberAccent,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16)),
                                              if (company.isNotEmpty)
                                                Text(company,
                                                    style: const TextStyle(
                                                        color: Colors.white54, fontSize: 12)),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                children: [
                                                 // _miniStat("Qty",            qty),
                                                  _miniStat("Cash Sales",     cashSales),
                                                  _miniStat("Credit Sales",   creditSales),
                                                  _miniStat("Cash Returns",   cashReturns),
                                                  _miniStat("Credit Returns", creditReturns),
                                                  _miniStat("Discount",       discount),
                                                  _miniStat("Profit",         profit),
                                                ],
                                              ),
                                              const Divider(color: Colors.white24),
                                              _summaryTile("Total Cash Sales",   totalCashSales),
                                              const SizedBox(height: 3),
                                              _summaryTile("Total Credit Sales", totalCreditSales),
                                              const SizedBox(height: 3),
                                              _summaryTile("Total Sales",        totalTotalSales),
                                              const SizedBox(height: 3),
                                              _summaryTile("Total Returns",      totalReturns),
                                              const SizedBox(height: 3),
                                              _summaryTile("Total Discount",     totalDiscount),
                                              const SizedBox(height: 3),
                                              _summaryTile("Total Profit",       totalProfit),
                                              const SizedBox(height: 3),
                                              _summaryTile("Total Cash @ Hand",  globalCashAtHand),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
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



  Future<void> showBranchItemTransactionsDialog( BuildContext context, {required String itemId, required String itemName, required String? branchId,   }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final provider = Provider.of<Datafeed>(context, listen: false);

    final previousSearch = provider.searchQuery;
    provider.updateSearch('');
    final _dialogSearchController = TextEditingController();
    try {
      final startDate = selectedDate?.start ?? DateTime.now();
      final endDate   = selectedDate?.end   ?? DateTime.now();

      await provider.loadBranchItemsReport(
        startDate: startDate,
        endDate:   endDate,
        branchId:  branchId,
      );
    } catch (e) {
      debugPrint('showBranchItemTransactionsDialog error: $e');
    }

    if (!context.mounted) {
      _dialogSearchController.dispose();
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    DateTimeRange? dialogDateRange = selectedDate;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            final filteredList        = provider.filterBranchItems();
            final totals              = provider.computeBranchItemTotals(filteredList);
            final fTotalCashSales     = totals['totalCashSales']!;
            final fTotalCreditSales   = totals['totalCreditSales']!;
            final fTotalCashReturns   = totals['totalCashReturns']!;
            final fTotalCreditReturns = totals['totalCreditReturns']!;
            final fTotalReturns       = totals['totalReturns']!;
            final fTotalDiscount      = totals['totalDiscount']!;
            final fTotalProfit        = totals['totalProfit']!;
            final fTotalRowTotal      = totals['totalRowTotal']!;
            final fGrandTotal         = totals['grandTotal']!;
            final fCashAtHand         = totals['globalCashAtHand']!;
             final totalsales         =fTotalCreditSales+ fTotalCashSales;
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
                          "$itemName — Branch Sales Report",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),


                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dialogSearchController,
                          onChanged: (val) {
                            provider.updateSearch(val);
                            setDialogState(() {});
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText:   "Search item...",
                            hintStyle:  const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            filled:     true,
                            fillColor:  const Color(0xFF1A2235),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:   BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Date range picker
                      ReusableDatePickerWidget(
                        onDateSelected: (selection) {
                          setState(() {
                            selectedDate = selection;
                          });

                          context.read<Datafeed>().fetchsalesreport(
                            selectedDate: selectedDate,
                            selectedBranch: _selectedBranch,
                          );
                        },

                        child: InkWell(
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: dialogDateRange,
                              builder: (context, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFF415A77),
                                    surface: Color(0xFF1B263B),
                                  ),
                                ),
                                child: child!,
                              ),
                            );

                            if (picked != null) {
                              setState(() {
                                dialogDateRange = picked;
                                selectedDate = picked;
                              });

                              context.read<Datafeed>().fetchsalesreport(
                                selectedDate: picked,
                                selectedBranch: _selectedBranch,
                              );
                            }
                          },

                          borderRadius: BorderRadius.circular(10),

                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2235),
                              borderRadius: BorderRadius.circular(10),
                            ),

                            child: Row(
                              children: [
                                const Icon(
                                  Icons.date_range,
                                  color: Colors.white70,
                                  size: 18,
                                ),

                                const SizedBox(width: 6),

                                Text(
                                  dialogDateRange != null
                                      ? "${DateFormat('dd MMM').format(dialogDateRange!.start)} - "
                                      "${DateFormat('dd MMM yyyy').format(dialogDateRange!.end)}"
                                      : "Pick dates",

                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              content: SizedBox(
                width:  double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.95,
                child: provider.isloadingsalesreport
                    ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                    : filteredList.isEmpty
                    ? const Center(
                    child: Text('No Sales found',
                        style: TextStyle(color: Colors.white70)))
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 600;

                    // ── Desktop: DataTable
                    if (isDesktop) {

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          const widths = [30, 180, 90, 90, 90, 90, 100, 90, 80, 80, 90];
                          const gap = 24.0;
                          final double contentWidth = widths.reduce((a, b) => a + b) +
                              (widths.length - 1) * gap +
                              32;
                          final double tableWidth =
                          constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

                          double _d(dynamic v) {
                            if (v == null) return 0.0;
                            if (v is double) return v;
                            if (v is int) return v.toDouble();
                            return (v as num).toDouble();
                          }

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
                              trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
                              thickness: MaterialStateProperty.all(10),
                              radius: const Radius.circular(8),
                            ),
                            child: Scrollbar(
                              controller: horizontalController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                controller: horizontalController,
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
                                          Text("#", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Item", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Cash Sales", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Credit Sales", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Total Sales", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Cash Returns", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Credit Returns", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Total Returns", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Discount", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Profit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text("Cash@Hand", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ]),
                                      ),
                                      Expanded(
                                        child: Scrollbar(
                                          controller: verticalController,
                                          thumbVisibility: true,
                                          trackVisibility: true,
                                          child: ListView.builder(
                                            controller: verticalController,
                                            itemCount: filteredList.length + 2,
                                            itemBuilder: (context, index) {
                                              if (index == filteredList.length) {
                                                // Grand Total row
                                                return rowOf(
                                                  [
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("Grand Total",
                                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                    Text(fTotalCashSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(fTotalCreditSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(totalsales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(fTotalCashReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(fTotalCreditReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(fTotalReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(fTotalDiscount.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(fTotalProfit.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(fGrandTotal.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                  ],
                                                  color: const Color(0xFF16213E),
                                                );
                                              }
                                              if (index == filteredList.length + 1) {
                                                // Total Cash @ Hand row
                                                return rowOf(
                                                  [
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("Total Cash @ Hand",
                                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    const Text("", style: TextStyle(color: Colors.white)),
                                                    Text(
                                                      fCashAtHand.toStringAsFixed(2),
                                                      style: const TextStyle(
                                                        color: Colors.greenAccent,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                  color: const Color(0xFF1D3557),
                                                );
                                              }

                                              final item = filteredList[index];
                                              final rowBranchId = item['branchId'] ?? '';
                                              final rowItemId   = item['itemid']   ?? '';
                                              final rowItemName = item['item']     ?? '';

                                              final cashSales     = _d(item['cashSales']);
                                              final creditSales   = _d(item['creditSales']);
                                              final cashReturns   = _d(item['cashReturns']);
                                              final creditReturns = _d(item['creditReturns']);
                                              final returns       = _d(item['returns']);
                                              final profit        = _d(item['profit']);
                                              final discount      = _d(item['discount']);
                                              final rowtotal      = _d(item['rowtotal']);

                                              return InkWell(
                                                onTap: () {
                                                  showSalesTransactionsDialog(
                                                    context,
                                                    itemId:   rowItemId,
                                                    itemName: rowItemName,
                                                    branchId: rowBranchId,
                                                  );
                                                },
                                                child: rowOf(
                                                  [
                                                    Text("${index + 1}", style: const TextStyle(color: Colors.white)),
                                                    Text(
                                                      rowItemName,
                                                      softWrap: true,
                                                      overflow: TextOverflow.visible,
                                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                                    ),
                                                    Text(cashSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(creditSales.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text((cashSales + creditSales).toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(cashReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(creditReturns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(returns.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(discount.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(profit.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
                                                    Text(rowtotal.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
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
                    }

                    // Mobile: Card list
                    return Column(
                      children: [
                        // Cash @ Hand banner
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "TOTAL CASH @ HAND",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "GHC ${fCashAtHand.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Expanded(
                          child: ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final reportItem    = filteredList[index];
                              final item          = reportItem['item']   ?? '';
                              final rowItemId     = reportItem['itemid'] ?? '';
                              final rowBranchId   = reportItem['branchId'] ?? '';
                              double _d(dynamic v) {
                                if (v == null) return 0.0;
                                if (v is double) return v;
                                if (v is int)    return v.toDouble();
                                return (v as num).toDouble();
                              }
                              final cashSales     = _d(reportItem['cashSales']);
                              final creditSales   = _d(reportItem['creditSales']);
                              final cashReturns   = _d(reportItem['cashReturns']);
                              final creditReturns = _d(reportItem['creditReturns']);
                              final profit        = _d(reportItem['profit']);
                              final discount      = _d(reportItem['discount']);
                              final salesQty      = _d(reportItem['sales_qty']);

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 4),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B263B),
                                  borderRadius:
                                  BorderRadius.circular(18),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    showSalesTransactionsDialog(
                                      context,
                                      itemId:   rowItemId,
                                      itemName: item,
                                      branchId: rowBranchId,
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(item,
                                          style: const TextStyle(
                                              color: Colors.amberAccent,
                                              fontWeight:
                                              FontWeight.bold)),
                                      Wrap(
                                        spacing:    12,
                                        runSpacing: 12,
                                        children: [
                                      //    _miniStat("Quantity",       salesQty),
                                          _miniStat("Cash Sales",     cashSales),
                                          _miniStat("Credit Sales",   creditSales),
                                          _miniStat("Cash Returns",   cashReturns),
                                          _miniStat("Credit Returns", creditReturns),
                                          _miniStat("Discount",       discount),
                                          _miniStat("Profit",         profit),
                                        ],
                                      ),
                                      const Divider(color: Colors.white24),
                                      _summaryTile("Total Cash Sales",   fTotalCashSales),
                                      const SizedBox(height: 3),
                                      _summaryTile("Total Credit Sales", fTotalCreditSales),
                                      const SizedBox(height: 3),
                                      _summaryTile("Total  Sales", totalsales),
                                      const SizedBox(height: 3),
                                      _summaryTile("Total Returns",      fTotalReturns),
                                      const SizedBox(height: 3),
                                      _summaryTile("Total Discount",     fTotalDiscount),
                                      const SizedBox(height: 3),
                                      _summaryTile("Total Profit",       fTotalProfit),
                                      const SizedBox(height: 3),
                                      _summaryTile("Grand Total",        fGrandTotal),
                                      const SizedBox(height: 3),
                                      _summaryTile("Total Cash @ Hand",  fCashAtHand),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => printTransactionsbr(
                      filteredList,
                      itemName,
                    '${DateFormat('d MMMM y').format(selectedDate?.start ?? DateTime.now())} ',

                DateFormat('d MMMM y').format(selectedDate?.end ?? DateTime.now()),
                  ),
                  child: const Text("Print / Download",
                      style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Close",
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      provider.updateSearch(previousSearch);
      _mainSearchController.text = previousSearch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dialogSearchController.dispose();
      });
    });
  }

    Future<void> showSalesTransactionsDialog( BuildContext context, {required String itemId, required String itemName,required String? branchId, }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final provider = Provider.of<Datafeed>(context, listen: false);
    final previousSearch = provider.searchQuery;
    provider.updateSearch('');
    final _dialogSearchController = TextEditingController();
    try {
      final startDate = selectedDate?.start ?? DateTime.now();
      final endDate = selectedDate?.end ?? DateTime.now();

      await provider.loadItemSalesTransactions(
        startDate: startDate,
        endDate: endDate,
        itemId: itemId,
        itemName: itemName,
        branchId: branchId,
      );
    } catch (e) {
      print('Error from individual sales $e');
    }

    if (!context.mounted) {
      _dialogSearchController.dispose();
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isSmallScreen = MediaQuery.of(dialogContext).size.width < 600;

        return Consumer<Datafeed>(
          builder: (context, provider, _) {
            final transactions = provider.filteredItemTransactions();
            final stats = aggregateItemStats(transactions);

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
                          "$itemName SALES TRANSACTIONS",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _dialogSearchController,
                    onChanged: provider.updateSearch,
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
                      suffixIcon: _dialogSearchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _dialogSearchController.clear();
                          provider.updateSearch('');
                        },
                      )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _showCategoryTransactionsPopup(
                            context, 'Cash Sales',
                            _filterTransactionsByCategory(transactions, 'cashSales'),
                          ),
                          child: _statChip("Cash Sales", stats['cashSales']),
                        ),

                        InkWell(
                          onTap: () => _showCategoryTransactionsPopup(
                            context, 'Credit Sales',
                            _filterTransactionsByCategory(transactions, 'creditSales'),
                          ),
                          child: _statChip("Credit Sales", stats['creditSales']),
                        ),


                        InkWell(
                          onTap: () => _showCategoryTransactionsPopup(
                            context, 'Cash Returns',
                            _filterTransactionsByCategory(transactions, 'cashReturns'),
                          ),
                          child: _statChip("Cash Returns", stats['cashReturns'], color: Colors.white70),
                        ),


                        InkWell(
                          onTap: () => _showCategoryTransactionsPopup(
                            context, 'Credit Returns',
                            _filterTransactionsByCategory(transactions, 'creditReturns'),
                          ),
                          child: _statChip("Credit Returns", stats['creditReturns'], color: Colors.white70),
                        ),

                        InkWell(
                          onTap: () => _showCategoryTransactionsPopup(
                            context, 'Total Returns',
                            _filterTransactionsByCategory(transactions, 'totalReturns'),
                          ),
                          child: _statChip("Total Returns", stats['totalReturns'], color: Colors.white70),
                        ),
                        InkWell(
                          onTap: () => _showCategoryTransactionsPopup(
                            context, 'Discount',
                            _filterTransactionsByCategory(transactions, 'discount'),
                          ),
                          child: _statChip("Discount", stats['totalDiscount'], color: Colors.white70),
                        ),

                        _statChip("Qty Sold", stats['totalQty'], isCurrency: false),
                        _statChip("Net Revenue", stats['total'], color: Colors.white70),
                        _statChip("Profit", stats['profit'], color: Colors.white70),
                      ],
                    ),
                  ),
                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.95,
                child: transactions.isEmpty
                    ? const Text(
                  "No transactions found",
                  style: TextStyle(color: Colors.white70),
                )
                    : isSmallScreen
                    ? ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final no = index + 1;

                    final item = t['item'] ?? '';
                    final qty = t['qty'] ?? '';
                    final price = t['price'] ?? '';
                    final profit = t['profit'] ?? '';
                    final discount = t['discount'] ?? '';
                    final total = t['total'] ?? '';
                    final transMode = t['transMode'] ?? '';
                    final salesMode = t['salesMode'] ?? '';
                    final customer = t['customer'] ?? '';
                    final branch = t['branch'] ?? '';
                    final pricingMode = t['pricingMode'] ?? '';
                    final staff = t['staff'] ?? '';
                    final datte = t['date'];

                    final formattedDate = datte != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(
                      (datte as Timestamp).toDate(),
                    )
                        : '-';

                    return Card(
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (t['isReturned'] == true ? Colors.redAccent : Colors.greenAccent)
                                        .withOpacity(0.15),
                                    border: Border.all(
                                      color: (t['isReturned'] == true ? Colors.redAccent : Colors.greenAccent)
                                          .withOpacity(0.6),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t['isReturned'] == true
                                        ? ((t['returnedTransMode'] == 'credit') ? 'Credit Return' : 'Cash Return')
                                        : 'Sale',
                                    style: TextStyle(
                                      color: t['isReturned'] == true ? Colors.redAccent : Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _miniStatstring("Qty", qty),
                                _miniStatstring("Price", price),
                                _miniStatstring("Profit", profit ),
                                _miniStatstring("Discount", discount),
                                _miniStatstring("Total", total),
                                _miniStatstring("TransMode", transMode),
                                _miniStatstring("SalesMode", salesMode),
                                _miniStatstring("Customer", customer),
                                _miniStatstring("Branch", branch),
                                _miniStatstring("PricingMode", pricingMode),
                                _miniStatstring("Staff", staff),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
                    :

                ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
                    trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
                    trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
                    thickness: MaterialStateProperty.all(10),
                    radius: const Radius.circular(8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const widths = [30, 150, 180, 50, 50, 50, 50, 50, 120, 80, 100, 90, 110, 100];
                      const gap = 12.0;
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

                      return Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
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
                                    Text('#', style: TextStyle(color: Colors.white70)),
                                    Text('Date', style: TextStyle(color: Colors.white70)),
                                    Text('Item', style: TextStyle(color: Colors.white70)),
                                    Text('Qty', style: TextStyle(color: Colors.white70)),
                                    Text('Price', style: TextStyle(color: Colors.white70)),
                                    Text('Profit', style: TextStyle(color: Colors.white70)),
                                    Text('Disc', style: TextStyle(color: Colors.white70)),
                                    Text('Total', style: TextStyle(color: Colors.white70)),
                                    Text('Trx Mode', style: TextStyle(color: Colors.white70)),
                                    Text('Sales Mode', style: TextStyle(color: Colors.white70)),
                                    Text('Customer', style: TextStyle(color: Colors.white70)),
                                    Text('Branch', style: TextStyle(color: Colors.white70)),
                                    Text('Price Mode', style: TextStyle(color: Colors.white70)),
                                    Text('Staff', style: TextStyle(color: Colors.white70)),
                                  ]),
                                ),
                                Divider(height: 1.2, thickness: 1.2, color: Colors.white.withOpacity(0.12)),
                                Expanded(
                                  child: Scrollbar(
                                    controller: _verticalController,
                                    thumbVisibility: true,
                                    trackVisibility: true,
                                    child: ListView.builder(
                                      controller: _verticalController,
                                      itemCount: transactions.length,
                                      itemBuilder: (context, index) {
                                        final t = transactions[index];

                                        final item = t['item'] ?? '';
                                        final qty = t['qty'] ?? '';
                                        final price = t['price'] ?? '';
                                        final profit = t['profit'].toStringAsFixed(2) ?? '';
                                        final discount = t['discount'] ?? '';
                                        final total = t['total'] ?? '';
                                        final transMode = t['transMode'] ?? '';
                                        final salesMode = t['salesMode'] ?? '';
                                        final customer = t['customer'] ?? '';
                                        final branch = t['branch'] ?? '';
                                        final pricingMode = t['pricingMode'] ?? '';
                                        final staff = t['staff'] ?? '';
                                        final datte = t['date'];
                                        final isReturned = t['isReturned'] == true;
                                        final returnedTransMode = t['returnedTransMode'] ?? '';

                                        final formattedDate = datte != null
                                            ? DateFormat('dd MMM yyyy, hh:mm a')
                                            .format((datte as Timestamp).toDate())
                                            : '-';

                                        final String rowTypeLabel = isReturned
                                            ? (returnedTransMode == 'credit' ? 'Credit Return' : 'Cash Return')
                                            : 'Sale';

                                        final Color rowTypeColor = isReturned
                                            ? (returnedTransMode == 'credit' ? Colors.orange : Colors.redAccent)
                                            : Colors.greenAccent;

                                        final Color? rowBg = isReturned ? Colors.red.withOpacity(0.08) : null;

                                        return rowOf(
                                          [
                                            Text('${index + 1}', style: const TextStyle(color: Colors.white70)),
                                            Text(formattedDate, style: const TextStyle(color: Colors.white70)),
                                            Text(
                                              item.toString(),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                                            ),
                                            Text(qty.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(price.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(profit.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(discount.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(total.toString(), style: const TextStyle(color: Colors.white70)),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: rowTypeColor.withOpacity(0.15),
                                                    border: Border.all(color: rowTypeColor.withOpacity(0.6)),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    rowTypeLabel,
                                                    style: TextStyle(
                                                      color: rowTypeColor,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isReturned ? returnedTransMode : transMode.toString(),
                                                  style: const TextStyle(color: Colors.white70),
                                                ),
                                              ],
                                            ),
                                            Text(salesMode.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(customer.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(branch.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(pricingMode.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(staff.toString(), style: const TextStyle(color: Colors.white70)),
                                          ],
                                          color: rowBg,
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
              ),

              actions: [
                TextButton(
                  onPressed: () => printTransactions(transactions, itemName,DateFormat('d MMMM y').format(selectedDate?.start ?? DateTime.now()),DateFormat('d MMMM y').format(selectedDate?.end ?? DateTime.now()),provider.company,_selectedBranch ?? 'All Branches'),
                  child: const Text(
                    "Print / Download",
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
    ).then((_) {
      provider.updateSearch(previousSearch);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dialogSearchController.dispose();
      });
    });
  }

  Widget _statChip(String label,dynamic value, { Color color = Colors.white, bool isCurrency = true,}) {
    final formatted = isCurrency
        ? "GHC ${(value as double).toStringAsFixed(2)}"
        : (value as double).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(formatted,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              )),
        ],
      ),
    );
  }

  Map<String, dynamic> aggregateItemStats(List<Map<String, dynamic>> transactions) {
    double cashSales = 0;
    double creditSales = 0;
    double cashReturns = 0;
    double creditReturns = 0;
    double totalDiscount = 0;
    double totalQty = 0;
    double totalCost = 0;
    double profit = 0;

    for (final t in transactions) {
      final total = (t['total'] as num?)?.toDouble() ?? 0;
      final qty = (t['qty'] as num?)?.toDouble() ?? 0;
      final discount = (t['discount'] as num?)?.toDouble() ?? 0;
      final cp = (t['cp'] as num?)?.toDouble() ?? 0;
      final profitt = (t['profit'] as num?)?.toDouble() ?? 0;
      final returnedAmount = (t['returnedAmount'] as num?)?.toDouble() ?? 0;
      final isReturned = t['isReturned'] == true;

      if (isReturned) {
        // Returns: subtract qty, profit, discount — don't add to sales
        totalQty -= qty;
        totalDiscount -= discount;
        totalCost -= qty * cp;
        profit -= profitt;

        if (t['isCashReturn'] == true) {
          cashReturns += returnedAmount;
        } else if (t['isCreditReturn'] == true) {
          creditReturns += returnedAmount;
        }
      } else {
        // Normal sales only
        totalQty += qty;
        totalDiscount += discount;
        totalCost += qty * cp;
        profit += profitt;

        if (t['isCredit'] == true) {
          creditSales += total;
        } else {
          cashSales += total;
        }
      }
    }

    final totalReturns = cashReturns + creditReturns;
    final grossRevenue = (cashSales + creditSales) - totalReturns;

    return {
      'cashSales': cashSales,
      'creditSales': creditSales,
      'cashReturns': cashReturns,
      'creditReturns': creditReturns,
      'totalReturns': totalReturns,
      'totalDiscount': totalDiscount,
      'totalQty': totalQty,
      'profit': profit,
      'total': grossRevenue,
    };
  }

  List<Map<String, dynamic>> _filterTransactionsByCategory(
      List<Map<String, dynamic>> transactions, String category) {
    switch (category) {
      case 'cashSales':
        return transactions.where((t) =>
        t['isReturned'] != true && t['isCredit'] != true).toList();
      case 'creditSales':
        return transactions.where((t) =>
        t['isReturned'] != true && t['isCredit'] == true).toList();
      case 'cashReturns':
        return transactions.where((t) =>
        t['isReturned'] == true && t['isCashReturn'] == true).toList();
      case 'creditReturns':
        return transactions.where((t) =>
        t['isReturned'] == true && t['isCreditReturn'] == true).toList();
      case 'totalReturns':
        return transactions.where((t) => t['isReturned'] == true).toList();
      case 'discount':
        return transactions.where((t) {
          final d = (t['discount'] as num?) ?? 0;
          return d > 0;
        }).toList();
      case 'total':
      case 'profit':
      case 'qty':
      default:
        return transactions;
    }
  }

  void _showCategoryTransactionsPopup(
      BuildContext context, String title, List<Map<String, dynamic>> filtered) {
    showDialog(
      context: context,
      builder: (_) {
        const widths = [30, 130, 50, 60, 60, 60, 60, 60];
        const gap = 12.0;

        Widget rowOf(List<Widget> cells, {Color? color}) {
          return Container(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

        double totalQty = 0, totalAmt = 0, totalDisc = 0, totalProfit = 0;
        for (final t in filtered) {
          totalQty += ((t['qty'] as num?) ?? 0).toDouble();
          totalAmt += ((t['total'] as num?) ?? 0).toDouble();
          totalDisc += ((t['discount'] as num?) ?? 0).toDouble();
          totalProfit += ((t['profit'] as num?) ?? 0).toDouble();
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF101624),
          title: Text(title, style: const TextStyle(color: Colors.amberAccent)),
          content: SizedBox(
            width: 640,
            height: 480,
            child: filtered.isEmpty
                ? const Center(
                child: Text('No transactions found',
                    style: TextStyle(color: Colors.white70)))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFF1E2A3D),
                  child: rowOf(const [
                    Text('#', style: TextStyle(color: Colors.white70)),
                    Text('Item', style: TextStyle(color: Colors.white70)),
                    Text('Qty', style: TextStyle(color: Colors.white70)),
                    Text('Price', style: TextStyle(color: Colors.white70)),
                    Text('Discount', style: TextStyle(color: Colors.white70)),
                    Text('Total', style: TextStyle(color: Colors.white70)),
                    Text('Profit', style: TextStyle(color: Colors.white70)),
                    Text('Mode', style: TextStyle(color: Colors.white70)),
                  ]),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      return rowOf(
                        [
                          Text('${index + 1}', style: const TextStyle(color: Colors.white70)),
                          Text('${t['item'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          Text('${t['qty'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          Text('${t['price'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          Text('${t['discount'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          Text('${t['total'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          Text('${t['profit'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          Text('${t['transMode'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                        ],
                        color: index.isEven ? const Color(0xFF0D1B2A) : const Color(0xFF101C2E),
                      );
                    },
                  ),
                ),
                rowOf(
                  [
                    const Text('', style: TextStyle(color: Colors.white)),
                    const Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(totalQty.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Text('', style: TextStyle(color: Colors.white)),
                    Text(totalDisc.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(totalAmt.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(totalProfit.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Text('', style: TextStyle(color: Colors.white)),
                  ],
                  color: const Color(0xFF16213E),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Future<void> printTransactions(
      List transactions,
      String itemName,
      String startdate,
      String endDate,
      String company,
      String branch
      ) async {
    final pdf = pw.Document(title: itemName);

    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    final currencyFormat = NumberFormat.currency(symbol: 'GHC ', decimalDigits: 2);
    String fmt(dynamic v) {
      if (v == null) return 'GHC 0.00';
      final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
      return currencyFormat.format(d);
    }

    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return (v as num).toDouble();
    }

    // ── Compute summary totals
    double totalCashSales     = 0;
    double totalCreditSales   = 0;
    double totalCashReturns   = 0;
    double totalCreditReturns = 0;
    double totalReturns       = 0;
    double totalDiscount      = 0;
    double totalQtySold       = 0;
    double totalNetRevenue    = 0;
    double totalProfit        = 0;

    for (final t in transactions) {
      final isReturned       = t['isReturned'] == true;
      final transMode        = (t['transMode']         ?? '').toString().toLowerCase();
      final returnedTransMode= (t['returnedTransMode'] ?? '').toString().toLowerCase();
      final total            = _d(t['total']);
      final qty              = _d(t['qty']);
      final discount         = _d(t['discount']);
      final profit           = _d(t['profit']);

      if (isReturned) {
        // use returnedTransMode to bucket the return
        if (returnedTransMode == 'cash')   totalCashReturns   += total;
        if (returnedTransMode == 'credit') totalCreditReturns += total;
        totalReturns += total;
      } else {
        if (transMode == 'cash')   totalCashSales   += total;
        if (transMode == 'credit') totalCreditSales += total;
        totalNetRevenue += total;
      }

      totalDiscount += discount;
      totalQtySold  += qty;
      totalProfit   += profit;
    }

    // ── Colours
    const headerBg  = PdfColor.fromInt(0xFF1B263B);
    const rowEven   = PdfColor.fromInt(0xFFF4F6FA);
    const returnBg  = PdfColor.fromInt(0x14FF5252); // red tint — matches UI rowBg
    const accent    = PdfColor.fromInt(0xFF415A77);

    // ── Helpers
    pw.Widget cell(
        String text, {
          bool header = false,
          bool bold   = false,
          bool right  = false,
          PdfColor? color,
        }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font:     (header || bold) ? boldFont : baseFont,
              fontSize: 8,
              color:    header ? PdfColors.white : (color ?? PdfColors.grey800),
            ),
          ),
        );

    pw.Widget chipBox(String label, String value, {PdfColor? valueColor}) =>
        pw.Container(
          margin:  const pw.EdgeInsets.only(right: 6, bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            border:       pw.Border.all(color: accent, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
            color:        PdfColor.fromInt(0xFF1A2235),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 7, color: PdfColors.grey400)),
              pw.SizedBox(height: 2),
              pw.Text(value,
                  style: pw.TextStyle(
                      font: boldFont, fontSize: 9,
                      color: valueColor ?? PdfColors.white)),
            ],
          ),
        );

    //Page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin:     const pw.EdgeInsets.all(28),
        theme:      pw.ThemeData.withFont(base: baseFont, bold: boldFont),

        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$itemName SALES TRANSACTIONS',
                  style: pw.TextStyle(font: boldFont, fontSize: 16, color: accent),
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  company,
                  style: pw.TextStyle(font: boldFont, fontSize: 10, color: accent),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Branch: $branch',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Period: $startdate  –  $endDate',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.2, color: accent),
            pw.SizedBox(height: 10),

            //Summary chips
            pw.Wrap(
              spacing:    6,
              runSpacing: 4,
              children: [
                chipBox('Cash Sales',     fmt(totalCashSales)),
                chipBox('Credit Sales',   fmt(totalCreditSales)),
                chipBox('Cash Returns',   fmt(totalCashReturns)),
                chipBox('Credit Returns', fmt(totalCreditReturns)),
                chipBox('Total Returns',  fmt(totalReturns)),
                chipBox('Discount',       fmt(totalDiscount)),
                chipBox('Qty Sold',       totalQtySold.toStringAsFixed(0)),
                chipBox('Net Revenue',    fmt(totalNetRevenue)),
                chipBox('Profit',         fmt(totalProfit),
                    valueColor: totalProfit < 0
                        ? PdfColors.red400
                        : PdfColors.greenAccent700),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        ),

        build: (context) => [
          pw.Table(
            columnWidths: {
              0:  const pw.FixedColumnWidth(20),  // #
              1:  const pw.FlexColumnWidth(2.0),  // Date/Time
              2:  const pw.FlexColumnWidth(2.2),  // Item
              3:  const pw.FixedColumnWidth(30),  // Qty
              4:  const pw.FixedColumnWidth(36),  // Price
              5:  const pw.FixedColumnWidth(44),  // Total
              6:  const pw.FlexColumnWidth(1.2),  // Txn Mode
              7:  const pw.FlexColumnWidth(0.8),  // Sales Mode
              8:  const pw.FlexColumnWidth(1.4),  // Customer
              9:  const pw.FlexColumnWidth(0.9),  // Branch
              10: const pw.FlexColumnWidth(0.8),  // Pricing Mode
              11: const pw.FlexColumnWidth(1.2),  // Staff
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#',            header: true),
                  cell('DATE/TIME',    header: true),
                  cell('ITEM',         header: true),
                  cell('QTY',          header: true, right: true),
                  cell('PRICE',        header: true, right: true),
                  cell('TOTAL',        header: true, right: true),
                  cell('TXN MODE',     header: true),
                  cell('SALES MODE',   header: true),
                  cell('CUSTOMER',     header: true),
                  cell('BRANCH',       header: true),
                  cell('PRICING MODE', header: true),
                  cell('STAFF',        header: true),
                ],
              ),

              // Data rows
              ...transactions.asMap().entries.map((entry) {
                final i          = entry.key;
                final t          = entry.value as Map<String, dynamic>;
                final isReturned = t['isReturned'] == true;
                final returnedTransMode = (t['returnedTransMode'] ?? '').toString();

                // Row background: red tint for returns, alternating for sales
                final bg = isReturned
                    ? returnBg
                    : (i.isEven ? rowEven : PdfColors.white);

                // Label: matches UI exactly
                final String rowTypeLabel = isReturned
                    ? (returnedTransMode == 'credit' ? 'Credit Return' : 'Cash Return')
                    : 'Sale';

                // Colour: matches UI — orange=credit return, red=cash return, green=sale
                final PdfColor labelColor = isReturned
                    ? (returnedTransMode == 'credit'
                    ? PdfColors.orange
                    : PdfColors.red400)
                    : PdfColors.green700;

                String dateStr = '-';
                final rawDate = t['date'];
                if (rawDate is Timestamp) {
                  dateStr = DateFormat('dd MMM yyyy, hh:mm a')
                      .format(rawDate.toDate());
                } else if (rawDate is DateTime) {
                  dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(rawDate);
                }


                final item        = (t['item']        ?? '-').toString();
                final transMode   = (t['transMode']   ?? '-').toString();
                final salesMode   = (t['salesMode']   ?? '-').toString();
                final customer    = (t['customer']    ?? '-').toString();
                final branch      = (t['branch']      ?? '-').toString();
                final pricingMode = (t['pricingMode'] ?? '-').toString();
                final staff       = (t['staff']       ?? '-').toString();

                // TXN MODE cell: "Sale / cash" or "Cash Return / cash" — mirrors UI
                final txnModeDisplay = isReturned
                    ? '$rowTypeLabel / $returnedTransMode'
                    : '$rowTypeLabel / $transMode';

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${i + 1}'),
                    cell(dateStr),
                    cell(item),
                    cell(_d(t['qty']).toStringAsFixed(0),    right: true),
                    cell(_d(t['price']).toStringAsFixed(2),  right: true),
                    cell(_d(t['total']).toStringAsFixed(2),  right: true, bold: true),
                    cell(txnModeDisplay, color: labelColor,  bold: true),
                    cell(salesMode),
                    cell(customer),
                    cell(branch),
                    cell(pricingMode),
                    cell(staff),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 6),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Transactions: ${transactions.length}',
              style: pw.TextStyle(
                  font: baseFont, fontSize: 8, color: PdfColors.grey500),
            ),
          ),
        ],

        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
  Future<void> printTransactionsbr(List<Map<String, dynamic>> filteredList, String itemName, String startDate,String endDate ) async {
    final pdf = pw.Document(title: itemName.trim().isEmpty ? 'Sales Report' : '$itemName Sales Report');
   final provider = context.read<Datafeed>();
    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return (v as num).toDouble();
    }

    final currencyFormat = NumberFormat.currency(symbol: 'GHC ', decimalDigits: 2);
    String fmt(double v) => currencyFormat.format(v);
    String fmtQty(double v) => v.toStringAsFixed(1);

    double totalCashSales     = 0;
    double totalCreditSales   = 0;
    double totalCashReturns   = 0;
    double totalCreditReturns = 0;
    double totalReturns       = 0;
    double totalDiscount      = 0;
    double totalProfit        = 0;
    double grandTotal         = 0;
    double totalQty           = 0;

    for (final item in filteredList) {
      totalCashSales     += _d(item['cashSales']);
      totalCreditSales   += _d(item['creditSales']);
      totalCashReturns   += _d(item['cashReturns']);
      totalCreditReturns += _d(item['creditReturns']);
      totalReturns       += _d(item['totalReturns']);
      totalDiscount      += _d(item['discount']);
      totalProfit        += _d(item['profit']);
      grandTotal         += _d(item['rowtotal']);
      totalQty           += _d(item['quantity']);
    }

    final cashAtHand = (totalCashSales - totalCashReturns);

    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    const headerBg   = PdfColor.fromInt(0xFF1B263B); // dark navy
    const rowEven    = PdfColor.fromInt(0xFFF4F6FA); // very light grey
    const rowOdd     = PdfColors.white;
    const totalRowBg = PdfColor.fromInt(0xFF0D1B2A); // darker navy
    const cashRowBg  = PdfColor.fromInt(0xFF1D3557); // mid navy
    const accent     = PdfColor.fromInt(0xFF415A77); // muted blue

    pw.Widget cell(
        String text, {
          bool header  = false,
          bool bold    = false,
          bool right   = false,
          PdfColor? color,
        }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font:      (header || bold) ? boldFont : baseFont,
            fontSize:  header ? 8 : 8,
            color:     header ? PdfColors.white : (color ?? PdfColors.grey800),
          ),
        ),
      );
    }

    pw.Widget summaryLine(String label, String value, {bool highlight = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                    font:     highlight ? boldFont : baseFont,
                    fontSize: highlight ? 10 : 9,
                    color:    highlight ? accent : PdfColors.grey700,
                  )),
              pw.Text(value,
                  style: pw.TextStyle(
                    font:     boldFont,
                    fontSize: highlight ? 11 : 9,
                    color:    highlight ? accent : PdfColors.grey800,
                  )),
            ],
          ),
        );
     pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin:     const pw.EdgeInsets.all(28),
        theme:      pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      itemName.toUpperCase(),
                      style: pw.TextStyle(
                          font: boldFont, fontSize: 18, color: accent),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(provider.company                     ,
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 11, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Branch Sales Report',
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 11, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Period $startDate \u002D $endDate',
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 11, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Text('Date${
                  DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: accent),
            pw.SizedBox(height: 6),
          ],
        ),
        build: (context) => [

          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(24),   // #
              1: const pw.FlexColumnWidth(2.8),   // Item
              2: const pw.FlexColumnWidth(0.8),   // Qty
              3: const pw.FlexColumnWidth(1.2),   // Cash Sales
              4: const pw.FlexColumnWidth(1.2),   // Credit Sales
              5: const pw.FlexColumnWidth(1.1),   // Cash Returns
              6: const pw.FlexColumnWidth(1.1),   // Credit Returns
              7: const pw.FlexColumnWidth(1.0),   // Returns
              8: const pw.FlexColumnWidth(1.0),   // Discount
              9: const pw.FlexColumnWidth(1.0),   // Profit
              10: const pw.FlexColumnWidth(1.2),  // Total
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#',              header: true),
                  cell('ITEM',           header: true),
                  cell('QTY',            header: true, right: true),
                  cell('CASH SALES',     header: true, right: true),
                  cell('CREDIT SALES',   header: true, right: true),
                  cell('CASH RET.',      header: true, right: true),
                  cell('CREDIT RET.',    header: true, right: true),
                  cell('RETURNS',        header: true, right: true),
                  cell('DISCOUNT',       header: true, right: true),
                  cell('PROFIT',         header: true, right: true),
                  cell('TOTAL',          header: true, right: true),
                ],
              ),

              // Data rows
              ...filteredList.asMap().entries.map((entry) {
                final i    = entry.key;
                final item = entry.value;
                final bg   = i.isEven ? rowEven : rowOdd;

                final profit = _d(item['profit']);
                final profitColor = profit < 0 ? PdfColors.red700 : PdfColors.grey800;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${i + 1}'),
                    cell(item['item']?.toString() ?? '-'),
                    cell(fmtQty(_d(item['quantity'])),         right: true),
                    cell(fmt(_d(item['cashSales'])),           right: true),
                    cell(fmt(_d(item['creditSales'])),         right: true),
                    cell(fmt(_d(item['cashReturns'])),         right: true),
                    cell(fmt(_d(item['creditReturns'])),       right: true),
                    cell(fmt(_d(item['totalReturns'])),        right: true),
                    cell(fmt(_d(item['discount'])),            right: true),
                    cell(fmt(profit), right: true, color: profitColor),
                    cell(fmt(_d(item['rowtotal'])),            right: true, bold: true),
                  ],
                );
              }),

              // Grand Total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: totalRowBg),
                children: [
                  cell('', bold: true, header: true),
                  cell('GRAND TOTAL', bold: true, header: true),
                  cell(fmtQty(totalQty),right: true,  bold: true, header: true),
                  cell(fmt(totalCashSales),  right: true, bold: true, header: true),
                  cell(fmt(totalCreditSales),   right: true, bold: true, header: true),
                  cell(fmt(totalCashReturns),   right: true, bold: true, header: true),
                  cell(fmt(totalCreditReturns), right: true, bold: true, header: true),
                  cell(fmt(totalReturns),       right: true, bold: true, header: true),
                  cell(fmt(totalDiscount),      right: true, bold: true, header: true),
                  cell(fmt(totalProfit),        right: true, bold: true, header: true),
                  cell(fmt(grandTotal),         right: true, bold: true, header: true),
                ],
              ),

              // Cash @ Hand row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: cashRowBg),
                children: [
                  cell('', header: true),
                  cell('TOTAL CASH @ HAND', bold: true, header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    child: pw.Text(
                      fmt(cashAtHand),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font:      boldFont,
                        fontSize:  9,
                        color:     PdfColors.greenAccent700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),

           pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 280,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color:        rowEven,
                border:       pw.Border.all(color: accent, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('SUMMARY',
                      style: pw.TextStyle(
                          font: boldFont, fontSize: 11, color: accent)),
                  pw.SizedBox(height: 10),
                  summaryLine('Total Cash Sales',     fmt(totalCashSales)),
                  summaryLine('Total Credit Sales',   fmt(totalCreditSales)),
                  summaryLine('Total Returns',        fmt(totalReturns)),
                  summaryLine('Total Discount',       fmt(totalDiscount)),
                  summaryLine('Total Profit',         fmt(totalProfit)),
                  pw.Divider(thickness: 0.8, color: accent),
                  summaryLine('Grand Total', fmt(grandTotal),   highlight: true),
                  pw.SizedBox(height: 4),
                  summaryLine('Total Cash @ Hand',    fmt(cashAtHand),   highlight: true),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Total Items: ${filteredList.length}',
                    style: pw.TextStyle(
                        font: baseFont, fontSize: 8, color: PdfColors.grey500),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],

        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

}

