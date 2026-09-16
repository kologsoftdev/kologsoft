
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import '../widgets/printreportpdf.dart';


class generalLedger extends StatefulWidget {
  const generalLedger({super.key});

  @override
  State<generalLedger> createState() => _generalLedgerState();
}
class _ScrollScope extends StatefulWidget {
  final Widget Function(
      BuildContext context,
      ScrollController horizontal,
      ScrollController vertical,
      ) builder;

  const _ScrollScope({required this.builder});

  @override
  State<_ScrollScope> createState() => _ScrollScopeState();
}

class _ScrollScopeState extends State<_ScrollScope> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _horizontal, _vertical);
}
class _generalLedgerState extends State<generalLedger> {
  String searchQuery = '';
  DateTimeRange? selectedDate;
  String? _selectedBranch;

  late final ScrollController verticalController;
  late final ScrollController horizontalController;
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
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    horizontalController = ScrollController();

    Future.microtask((){
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchgeneralledgerreport(selectedDate: selectedDate,);
    });

  }
  @override
  Widget build(BuildContext context) {

    final screenWidth =MediaQuery.sizeOf(context).width;

    final isMobile = screenWidth < 600;
    final double columnSpacing = screenWidth > 1300
        ? 130
        : screenWidth > 800
        ? 100
        : 13;
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final resultList = value.filtergeneralledgerreport();

        return Scaffold(
          backgroundColor: const Color(0xFF101624),

          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'General Ledger',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
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
            padding: const EdgeInsets.all(5.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(5.0),
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
                            child: Container(
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
                                                'General Ledger for',
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

                                  if (isMobile) ...[
                                    // BRANCH FIRST
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 42,
                                            child: DropdownButtonFormField<String?>(
                                              isExpanded: true,
                                              value: _selectedBranch,
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
                                                const DropdownMenuItem<String?>(
                                                  value: null,
                                                  child: Text('All Branches'),
                                                ),
                                                ...value.branches.map((branch) {
                                                  return DropdownMenuItem<String?>(
                                                    value: branch.id,
                                                    child: Text(branch.branchname),
                                                  );
                                                }).toList(),
                                              ],
                                              onChanged: (val) {
                                                setState(() {
                                                  _selectedBranch = val;
                                                });
                                                value.fetchgeneralledgerreport(
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

                                    // PDF BUTTON ALONE, FULL WIDTH
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _printLedgerPdf(context),
                                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                        label: const Text(
                                          'Download / Print',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    // SEARCH BELOW ON MOBILE
                                    Container(
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                                      ),
                                      child: TextFormField(
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
                                        context.read<Datafeed>().fetchgeneralledgerreport(
                                          selectedDate: selectedDate,
                                          selectedBranch: _selectedBranch,
                                        );
                                      },
                                      child: Container(
                                        height: 42,
                                        width: double.infinity,
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
                                  ] else ...[
                                    // DESKTOP
                                    Row(
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
                                            context.read<Datafeed>().fetchgeneralledgerreport(
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

                                    Row(
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
                                            child: DropdownButtonFormField<String?>(
                                              value: _selectedBranch,
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
                                                const DropdownMenuItem<String?>(
                                                  value: null,
                                                  child: Text('All Branches'),
                                                ),
                                                ...value.branches.map((branch) {
                                                  return DropdownMenuItem<String?>(
                                                    value: branch.id,
                                                    child: Text(branch.branchname),
                                                  );
                                                }).toList(),
                                              ],
                                              onChanged: (val) {
                                                setState(() {
                                                  _selectedBranch = val;
                                                });
                                                value.fetchgeneralledgerreport(
                                                  selectedDate: selectedDate,
                                                  selectedBranch: _selectedBranch,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                          tooltip: 'Download/print',
                                          onPressed: () => _printLedgerPdf(context),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),


                        ],
                      ),

                      SizedBox(height: 5,),
                      Expanded(
                        child: value.isloadingledgerreport
                            ?
                        const Center( child: CircularProgressIndicator(color: Colors.white),)
                            :   resultList.isEmpty
                            ?
                        const Center(  child: Text('No Sales found', style: TextStyle(color: Colors.white70),),)
                            :
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth > 600;


                            if (isDesktop) {

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  const widths = [30, 180, 130, 100, 100, 100];
                                  const gap = 24.0;
                                  final double contentWidth = widths.reduce((a, b) => a + b) +
                                      (widths.length - 1) * gap +
                                      32;
                                  final double tableWidth =
                                  constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

                                  Widget rowOf(List<Widget> cells) {
                                    return Container(
                                      color: const Color(0xFF0D1B2A),
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
                                                  Text("Account/Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Opening Balance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Debit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Credit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text("Balance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                ]),
                                              ),
                                              Expanded(
                                                child: Scrollbar(
                                                  controller: verticalController,
                                                  thumbVisibility: true,
                                                  trackVisibility: true,
                                                  child: ListView.builder(
                                                    controller: verticalController,
                                                    itemCount: resultList.length,
                                                    itemBuilder: (context, index) {
                                                      final ledger = resultList[index];
                                                      final formatter = NumberFormat('#,##0.00');
                                                      final openingBalance = formatter
                                                          .format((ledger['openingBalance'] ?? 0.0).toDouble().abs());
                                                      final debit = formatter.format((ledger['debit'] ?? 0.0).toDouble());
                                                      final credit = formatter.format((ledger['credit'] ?? 0.0).toDouble());
                                                      final balance =
                                                      formatter.format((ledger['balance'] ?? 0.0).toDouble().abs());

                                                      return InkWell(
                                                        onTap: () {
                                                          showLedgerDetailsDialog(
                                                            context,
                                                            itemId: ledger['account'].toString().toLowerCase(),
                                                            itemName: ledger['account'] ?? '',
                                                            branchId: _selectedBranch,
                                                          );
                                                        },
                                                        child: rowOf([
                                                          Text("${index + 1}", style: const TextStyle(color: Colors.white)),
                                                          Text(capitalize(ledger['account'] ?? ''), style: const TextStyle(color: Colors.white)),
                                                          Text(openingBalance, style: const TextStyle(color: Colors.white)),
                                                          Text(debit, style: const TextStyle(color: Colors.white)),
                                                          Text(credit, style: const TextStyle(color: Colors.white)),
                                                          Text(balance, style: const TextStyle(color: Colors.white)),
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
                                    ),
                                  );
                                },
                              );
                            }

                           // MOBILE
                            final totalBalance = resultList.fold<double>(
                              0.0,  (sum, item) => sum + (item['balance'] ?? 0.0).toDouble(), );

                            return Column(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "TOTAL BALANCE",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "GHC ${totalBalance.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          color: Colors.white,
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
                                    itemCount: resultList.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final ledger = resultList[index];
                                      final number = ledger['number'] ?? index + 1;
                                      final account = ledger['account'] ?? '';
                                      final openingBalance = (ledger['openingBalance'] ?? 0.0).toDouble();
                                      final debit = (ledger['debit'] ?? 0.0).toDouble();
                                      final credit = (ledger['credit'] ?? 0.0).toDouble();
                                      final balance = (ledger['balance'] ?? 0.0).toDouble();

                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B263B),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            /// Header row
                                            Wrap(
                                             // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          "$number",
                                                          style: const TextStyle(
                                                            color: Colors.blue,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(capitalize(account) ,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  "GHC ${balance.toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 12),
                                            const Divider(color: Colors.white10, height: 1),
                                            const SizedBox(height: 12),

                                            /// Stats row
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 8,
                                              children: [
                                                _miniStat("Opening Bal", openingBalance),
                                                _miniStat("Debit", debit),
                                                _miniStat("Credit", credit),
                                              ],
                                            ),

                                            const SizedBox(height: 12),
                                            const Divider(color: Colors.white10, height: 1),
                                            const SizedBox(height: 8),

                                            _summaryTile("Balance", balance),
                                          ],
                                        ),
                                      );
                                    },
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
          ),
        );
      },
    );

  }

  Widget _miniStat(String title, double value) {
    final formatter = NumberFormat('#,##0.00');
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
            formatter.format(value),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }

  Widget _summaryTile(String title, double value) {
    final formatter = NumberFormat('#,##0.00');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold)),
        Text(
          "GHC ${ formatter.format(value)}",
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }


  Future<void> showLedgerDetailsDialog( BuildContext context, {required String itemId, required String itemName, required String? branchId, }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final provider = Provider.of<Datafeed>(context, listen: false);

    try {
      final startDate = selectedDate?.start ?? DateTime.now();
      final endDate   = selectedDate?.end   ?? DateTime.now();

      await provider.showLedgerDetailsDialog(
        startDate: startDate,
        endDate: endDate,
        Id: itemId,
        Name: itemName,
        branchId: branchId,
      );
    } catch (e) {
      debugPrint('Error loading ledger details: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isSmallScreen = MediaQuery.of(dialogContext).size.width < 600;

        return Consumer<Datafeed>(
          builder: (context, provider, _) {
            final transactions = provider.filteredshowLedgerDetailsDialog();


            final totalOpening = transactions.fold<double>(
                0.0, (s, t) => s + (t['openingBalance'] ?? 0.0));
            final totalDebit   = transactions.fold<double>(
                0.0, (s, t) => s + (t['debit']   ?? 0.0));
            final totalCredit  = transactions.fold<double>(
                0.0, (s, t) => s + (t['credit']  ?? 0.0));

            final totalBal = (totalDebit - totalCredit).abs();

            final totalBalance = transactions.fold<double>(
                0.0, (s, t) => s + (t['balance'] ?? 0.0));
            final formatter = NumberFormat('#,##0.00');

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
                          "GENERAL LEDGER – $itemName",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15,
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
                    onChanged: provider.updateSearch,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search customer / account...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1A2235),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.85,
                child: transactions.isEmpty
                    ? const Center(
                  child: Text(
                    "No ledger entries found",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
                    : isSmallScreen

                //MOBILE
                    ? Column(
                  children: [

                    Expanded(
                      child: ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final t = transactions[index];
                          final number = t['number'] ?? index + 1;
                          final account = t['account'] ?? '';
                          final description = t['description'] ?? '';
                          final customer = t['customerName'] ?? '';
                          final opening  = (t['openingBalance'] ?? 0.0).toDouble().abs();
                          final debit  = (t['debit']   ?? 0.0).toDouble();
                          final credit  = (t['credit']  ?? 0.0).toDouble();
                          final balance = (t['balance'] ?? 0.0).toDouble().abs();

                          return Card(
                            color: const Color(0xFF1A2235),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: Colors.blue
                                                  .withOpacity(0.15),
                                              borderRadius:
                                              BorderRadius.circular(6),
                                            ),
                                            child: Center(
                                              child: Text(
                                                "$number",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            description,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "GHC ${balance.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: balance < 0
                                              ? Colors.white
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(
                                      color: Colors.white10, height: 1),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      _miniStat("Opening Bal", opening),
                                      _miniStat("Debit",  debit),
                                      _miniStat("Credit", credit),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )

                //DESKTOP
                    :

                _ScrollScope(
                  builder: (context, horizontal, vertical) => LayoutBuilder(
                    builder: (context, constraints) {
                      const widths = [30, 100, 120, 130, 90, 90, 100, 20];
                    const gap = 50.0;
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

                    return ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
                        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
                        trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
                        thickness: MaterialStateProperty.all(10),
                        radius: const Radius.circular(8),
                      ),
                      child: Scrollbar(
                        controller: horizontal,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: SingleChildScrollView(
                          controller: horizontal,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  color: const Color(0xFF1E2A3D),
                                  child: rowOf([
                                    const Text('#', style: TextStyle(color: Colors.white70)),
                                    const Text('Date', style: TextStyle(color: Colors.white70)),
                                    Tooltip(
                                      message: 'Description',
                                      child: Text(
                                        'Description',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                    const Text('Opening Balance', style: TextStyle(color: Colors.white70)),
                                    const Text('Debit', style: TextStyle(color: Colors.white70)),
                                    const Text('Credit', style: TextStyle(color: Colors.white70)),
                                    const Text('Balance', style: TextStyle(color: Colors.white70)),
                                    const Text('', style: TextStyle(color: Colors.white70)),
                                  ]),
                                ),
                                Divider(height: 0.5, thickness: 0.5, color: Colors.white.withOpacity(0.1)),
                                Expanded(
                                  child: Scrollbar(
                                    controller: vertical,
                                    thumbVisibility: true,
                                    trackVisibility: true,
                                    child: ListView.builder(
                                      controller: vertical,
                                      itemCount: transactions.length,
                                      itemBuilder: (context, index) {
                                        final t = transactions[index];
                                        final number = index + 1;
                                        final account = t['account']?.toString().isNotEmpty == true
                                            ? t['account']
                                            : t['customerName'] ?? '';
                                        final datete = t['date'] ?? '';
                                        final description = t['description'] ?? '';

                                        final opening = (t['openingBalance'] ?? 0.0).toDouble().abs();
                                        final debit = (t['debit'] ?? 0.0).toDouble();
                                        final credit = (t['credit'] ?? 0.0).toDouble();
                                        final balance = (t['balance'] ?? 0.0).toDouble().abs();

                                        final formatter = NumberFormat('#,##0.00');

                                        return InkWell(
                                          onTap: () {
                                            showLedgerAccountDetailsUIDialog(
                                              context,
                                              itemId: account,
                                              itemName: account,
                                              branchId: _selectedBranch,
                                            );
                                          },
                                          child: rowOf([
                                            Text('$number', style: const TextStyle(color: Colors.white70)),
                                            Text(datete.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(description.toString(), style: const TextStyle(color: Colors.white70)),
                                            Text(formatter.format(opening), style: const TextStyle(color: Colors.white70)),
                                            Text(NumberFormat('#,##0.00').format(debit), style: const TextStyle(color: Colors.white70)),
                                            Text(formatter.format(credit), style: const TextStyle(color: Colors.white70)),
                                            Text(
                                              formatter.format(balance),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const Text(''),
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
                      ),
                    );
                    },
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => printTransactions(transactions, itemName),
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
    );
  }

  Future<void> showLedgerAccountDetailsUIDialog( BuildContext context, { required String itemId, required String itemName, required String? branchId, }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final provider = Provider.of<Datafeed>(context, listen: false);

    try {
      final startDate = selectedDate?.start ?? DateTime.now();
      final endDate   = selectedDate?.end   ?? DateTime.now();

      await provider.showLedgerAccountDetailsDialog(
        startDate: startDate,
        endDate:   endDate,
        itemId:    itemId,
        itemName:  itemName,
        branchId:  branchId,
      );
    } catch (e) {
      debugPrint('Error loading ledger account details: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final startLabel = DateFormat('yyyy MMMM EEEE dd').format(selectedDate?.start ?? DateTime.now());
    final endLabel   = DateFormat('yyyy MMMM EEEE dd').format(selectedDate?.end   ?? DateTime.now());

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isSmallScreen = MediaQuery.of(dialogContext).size.width < 600;

        return Consumer<Datafeed>(
          builder: (context, provider, _) {
            final transactions = provider.filteredshowLedgerAccountDetailsDialog();

            // totals
            final totalDebit  = transactions.fold<double>(
                0.0, (s, t) => s + (t['debit']  ?? 0.0));
            final totalCredit = transactions.fold<double>(
                0.0, (s, t) => s + (t['credit'] ?? 0.0));
            final totalBalance = transactions.isEmpty
                ? 0.0
                : (transactions.last['balance'] ?? 0.0).toDouble();

            return AlertDialog(
              backgroundColor: const Color(0xFF101624),

              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Address: ${provider.branchaddress}",
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Account Name: $itemName",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "ACCOUNT STATEMENT FROM $startLabel TO $endLabel",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: transactions.isEmpty
                    ? const Center(
                  child: Text(
                    "No entries found",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
                    : isSmallScreen

                //MOBILE
                    ? Column(
                  children: [


                    Expanded(
                      child: ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final t           = transactions[index];
                          final date        = t['transactionDate'] ?? '';
                          final description = t['description'] ?? '';
                          final debit       = (t['debit']   ?? 0.0).toDouble();
                          final credit      = (t['credit']  ?? 0.0).toDouble();
                          final balance = (t['balance'] ?? 0.0).toDouble().abs();

                          return Card(
                            color: const Color(0xFF1A2235),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        date,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        "GHC ${NumberFormat('#,##0.00').format(balance)}",
                                        style: TextStyle(
                                          color: balance < 0
                                              ? Colors.white
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(
                                      color: Colors.white10, height: 1),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                    children: [
                                      _miniStat("Debit",  debit),
                                      _miniStat("Credit", credit),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )

                //DESKTOP
                    :

                _ScrollScope(
                  builder: (context, horizontal, vertical) => LayoutBuilder(
                    builder: (context, constraints) {
                      const widths = [30, 130, 200, 100, 100, 100];
                    const gap = 24.0;
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

                    return ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
                        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
                        trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
                        thickness: MaterialStateProperty.all(10),
                        radius: const Radius.circular(8),
                      ),
                      child: Scrollbar(
                        controller: horizontal,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: SingleChildScrollView(
                          controller: horizontal,
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
                                    Text('Transaction_Date', style: TextStyle(color: Colors.white70)),
                                    Text('Description', style: TextStyle(color: Colors.white70)),
                                    Text('Debit', style: TextStyle(color: Colors.white70)),
                                    Text('Credit', style: TextStyle(color: Colors.white70)),
                                    Text('Balance', style: TextStyle(color: Colors.white70)),
                                  ]),
                                ),
                                Divider(height: 0.5, thickness: 0.5, color: Colors.white.withOpacity(0.1)),
                                Expanded(
                                  child: Scrollbar(
                                    controller: vertical,
                                    thumbVisibility: true,
                                    trackVisibility: true,
                                    child: ListView.builder(
                                      controller: vertical,
                                      itemCount: transactions.length,
                                      itemBuilder: (context, index) {
                                        final t = transactions[index];
                                        final date = t['transactionDate'] ?? '';
                                        final description = t['description'] ?? '';
                                        final debit = (t['debit'] ?? 0.0).toDouble();
                                        final credit = (t['credit'] ?? 0.0).toDouble();
                                        final balance = (t['balance'] ?? 0.0).toDouble();

                                        return InkWell(
                                          onTap: () {
                                            showLedgerAccountDetailsUIDialog(
                                              context,
                                              itemId: t['accountId']?.toString() ?? t['account']?.toString() ?? '',
                                              itemName: t['customerName']?.toString().isNotEmpty == true
                                                  ? t['customerName'].toString()
                                                  : t['account']?.toString() ?? '',
                                              branchId: t['branch']?.toString(),
                                            );
                                          },
                                          child: rowOf([
                                            Text('${index + 1}', style: const TextStyle(color: Colors.white70)),
                                            Text(date, style: const TextStyle(color: Colors.white70)),
                                            Tooltip(
                                              message: description,
                                              child: Text(
                                                description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              debit > 0 ? NumberFormat('#,##0.00').format(debit) : '',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                            Text(
                                              credit > 0 ? NumberFormat('#,##0.00').format(credit) : '',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                            Text(
                                              NumberFormat('#,##0.00').format(balance.abs()),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
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
                      ),
                    );
                    },
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => printItemTransactions(transactions, itemName),
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
    );
  }


  Future<void> printTransactions(List transactions, String itemName) async {
    final pdf      = pw.Document(
      title: "General Ledger - $itemName"
    );
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final provider = context.read<Datafeed>();

   DateTime _parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String)    return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    String _fmtDate(dynamic v) {
      try {
        return DateFormat('dd MMM yyyy').format(_parseDate(v));
      } catch (_) {
        return v?.toString() ?? '-';
      }
    }

    // ── number helper
    double _d(dynamic v) {
      if (v == null)   return 0.0;
      if (v is double) return v;
      if (v is int)    return v.toDouble();
      return (v as num).toDouble();
    }

    final fmt = NumberFormat('#,##0.00');
    String _fmt(dynamic v) => fmt.format(_d(v));

    // ── totals
    double totOpening = 0, totDebit = 0, totCredit = 0, totBalance = 0;
    for (final t in transactions) {
      totOpening += _d(t['openingBalance']).abs();
      totDebit   += _d(t['debit']).abs();
      totCredit  += _d(t['credit']).abs();
      totBalance += _d(t['balance']).abs();
    }
    final netBalance = (totDebit - totCredit).abs();

    // ── colours
    const headerBg  = PdfColor.fromInt(0xFF1B263B);
    const totalBg   = PdfColor.fromInt(0xFF0D1B2A);
    const rowEven   = PdfColor.fromInt(0xFFF4F6FA);
    const accent    = PdfColor.fromInt(0xFF415A77);

    // ── cell helpers
    pw.Widget _cell(String text, {
      bool header = false,
      bool bold   = false,
      bool right  = false,
      PdfColor? color,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font:      (header || bold) ? boldFont : baseFont,
              fontSize:  8,
              color:     header
                  ? PdfColors.white
                  : (color ?? const PdfColor.fromInt(0xFF1A1A2E)),
            ),
          ),
        );

    pw.Widget _summaryLine(String label, String value,
        {bool highlight = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font:      highlight ? boldFont : baseFont,
                      fontSize:  highlight ? 10 : 9,
                      color:     highlight ? accent : PdfColors.grey700)),
              pw.Text(value,
                  style: pw.TextStyle(
                      font:      boldFont,
                      fontSize:  highlight ? 11 : 9,
                      color:     highlight ? accent : PdfColors.grey800)),
            ],
          ),
        );

   const rpp = 30;
    final pages = (transactions.length / rpp).ceil().clamp(1, 9999);

    final period = selectedDate != null
        ? '${DateFormat('d MMM y').format(selectedDate!.start)}'
        ' – ${DateFormat('d MMM y').format(selectedDate!.end)}'
        : 'All Dates';

    for (int pg = 0; pg < pages; pg++) {
      final pageRows = transactions.skip(pg * rpp).take(rpp).toList();
      final isLast   = pg == pages - 1;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // ── header band
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: pw.BoxDecoration(
                  color: headerBg,
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(provider.company.toUpperCase(),
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 14,
                                color: PdfColors.white)),
                        pw.SizedBox(height: 3),
                        pw.Text('GENERAL LEDGER',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 9,
                                color: PdfColors.blueGrey200)),
                        pw.Text('Account: $itemName',
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 10,
                                color: PdfColors.white)),
                        pw.Text(
                            'Branch: ${_selectedBranch ?? "All Branches"}',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColors.blueGrey200)),
                      ]),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Period: $period',
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 9,
                                color: PdfColors.white)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                            'Generated: ${DateFormat('d MMMM y, hh:mm a').format(DateTime.now())}',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColors.blueGrey200)),
                        pw.Text('Page ${pg + 1} of $pages',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColors.blueGrey200)),
                      ]),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

            // ── summary strip
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Wrap(spacing: 18, children: [
                pw.Text('Entries: ${transactions.length}',
                    style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white)),
                pw.Text('Total Debit: ${fmt.format(totDebit)}',
                    style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white)),
                pw.Text('Total Credit: ${fmt.format(totCredit)}',
                    style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white)),
                pw.Text('Net Balance: ${fmt.format(netBalance)}',
                    style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.greenAccent700)),
              ]),
            ),

            pw.SizedBox(height: 8),

            // ── data table
            pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(22),   // #
                1: const pw.FixedColumnWidth(65),   // Date
                2: const pw.FlexColumnWidth(3.0),   // Description
                3: const pw.FlexColumnWidth(1.4),   // Opening Balance
                4: const pw.FlexColumnWidth(1.4),   // Debit
                5: const pw.FlexColumnWidth(1.4),   // Credit
                6: const pw.FlexColumnWidth(1.4),   // Balance
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
                  decoration: const pw.BoxDecoration(color: headerBg),
                  children: [
                    _cell('#',               header: true),
                    _cell('DATE',            header: true),
                    _cell('DESCRIPTION',     header: true),
                    _cell('OPENING BAL.',    header: true, right: true),
                    _cell('DEBIT',           header: true, right: true),
                    _cell('CREDIT',          header: true, right: true),
                    _cell('BALANCE',         header: true, right: true),
                  ],
                ),

                // data rows
                ...pageRows.asMap().entries.map((e) {
                  final i   = e.key;
                  final t   = e.value;
                  final bg  = i.isOdd ? rowEven : PdfColors.white;

                  final desc    = (t['description'] ?? '').toString();
                  final opening = _d(t['openingBalance']);
                  final debit   = _d(t['debit']);
                  final credit  = _d(t['credit']);
                  final balance = _d(t['balance']).abs();

                  final balColor = balance < 0
                      ? PdfColors.red700
                      : const PdfColor.fromInt(0xFF1A1A2E);

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _cell('${pg * rpp + i + 1}'),
                      _cell(_fmtDate(t['date'])),
                      _cell(desc),
                      _cell(fmt.format(opening), right: true),
                      _cell(fmt.format(debit),   right: true,
                          color: debit > 0
                              ? const PdfColor.fromInt(0xFF1565C0)
                              : null),
                      _cell(fmt.format(credit),  right: true,
                          color: credit > 0
                              ? PdfColors.red700
                              : null),
                      _cell(fmt.format(balance), right: true,
                          bold: true, color: balColor),
                    ],
                  );
                }),

                // totals row
                // if (isLast)
                //   pw.TableRow(
                //     decoration: const pw.BoxDecoration(color: totalBg),
                //     children: [
                //       _cell('',                         header: true),
                //       _cell('',                         header: true),
                //       _cell('TOTAL',                    header: true),
                //       _cell(fmt.format(totOpening),     header: true, right: true),
                //       _cell(fmt.format(totDebit),       header: true, right: true),
                //       _cell(fmt.format(totCredit),      header: true, right: true),
                //       _cell(fmt.format(netBalance),     header: true, right: true),
                //     ],
                //   ),
              ],
            ),

            pw.Spacer(),

            // ── summary box (last page only)
            if (isLast)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 260,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: rowEven,
                    border: pw.Border.all(color: accent, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text('LEDGER SUMMARY',
                          style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: accent)),
                      pw.SizedBox(height: 8),
                      _summaryLine('Opening Balance',  fmt.format(totOpening)),
                      _summaryLine('Total Debit',      fmt.format(totDebit)),
                      _summaryLine('Total Credit',     fmt.format(totCredit)),
                      pw.Divider(thickness: 0.8, color: accent),
                      _summaryLine('Net Balance',      fmt.format(netBalance),
                          highlight: true),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Total Entries: ${transactions.length}',
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: PdfColors.grey500),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            pw.SizedBox(height: 6),

            // ── footer ───────────────────────────────────────────────────────
            pw.Divider(color: PdfColors.blueGrey200, thickness: 0.4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Confidential – ${provider.company}',
                    style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 7,
                        color: PdfColors.blueGrey400)),
                pw.Text(
                    'General Ledger | $itemName | $period',
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
      name: 'ledger_${itemName.replaceAll(' ', '_')}'
          '_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }


  Future<void> _printLedgerPdf(BuildContext context) async {
    final provider = context.read<Datafeed>();
    final resultList = provider.ledgerreport;
    final formatter = NumberFormat('#,##0.00');

    final totalOpening = resultList.fold<double>(
        0.0, (s, e) => s + (e['openingBalance'] ?? 0.0).toDouble().abs());
    final totalDebit = resultList.fold<double>(
        0.0, (s, e) => s + (e['debit'] ?? 0.0).toDouble().abs());
    final totalCredit = resultList.fold<double>(
        0.0, (s, e) => s + (e['credit'] ?? 0.0).toDouble().abs());
    final totalBalance = resultList.fold<double>(
        0.0, (s, e) => s + (e['balance'] ?? 0.0).toDouble().abs());

    final rows = resultList.asMap().entries.map((entry) {
      final i = entry.key;
      final ledger = entry.value;
      return [
        '${i + 1}',
        ledger['account']?.toString() ?? '',
        formatter.format((ledger['openingBalance'] ?? 0.0).toDouble().abs()),
        formatter.format((ledger['debit'] ?? 0.0).toDouble().abs()),
        formatter.format((ledger['credit'] ?? 0.0).toDouble().abs()),
        formatter.format((ledger['balance'] ?? 0.0).toDouble().abs()),
      ];
    }).toList();

    await printReportPdf(
      context: context,
      reportTitle: 'General Ledger Report',
      companyName: provider.company,
      branchName: _selectedBranch?.isEmpty ?? true ? 'All Branches' : _selectedBranch!,
      dateRange: selectedDate,
      columns: const [
        PdfColumn('#',               width: 22),
        PdfColumn('Account/Name',    width: 120),
        PdfColumn('Opening Balance', width: 70),
        PdfColumn('Debit',           width: 70),
        PdfColumn('Credit',          width: 70),
        PdfColumn('Balance',         width: 70),
      ],
      rows: rows,

      landscape: true,
      rowsPerPage: 30,
    );
  }
  Future<void> printItemTransactions(List transactions, String itemName) async {
    final pdf      = pw.Document(
      title: "Item Transactions - $itemName"
    );
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final provider = context.read<Datafeed>();

    DateTime _parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String)    return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    String _fmtDate(dynamic v) {
      try {
        return DateFormat('dd MMM yyyy').format(_parseDate(v));
      } catch (_) {
        return v?.toString() ?? '-';
      }
    }

    // number helper
    double _d(dynamic v) {
      if (v == null)   return 0.0;
      if (v is double) return v;
      if (v is int)    return v.toDouble();
      return (v as num).toDouble();
    }

    final fmt = NumberFormat('#,##0.00');
    String _fmt(dynamic v) => fmt.format(_d(v));

    // totals
    double totOpening = 0, totDebit = 0, totCredit = 0, totBalance = 0;
    for (final t in transactions) {
      totOpening += _d(t['openingBalance']).abs();
      totDebit   += _d(t['debit']).abs();
      totCredit  += _d(t['credit']).abs();
      totBalance += _d(t['balance']).abs();
    }
    final netBalance = (totDebit - totCredit).abs();

    // colours
    const headerBg  = PdfColor.fromInt(0xFF1B263B);
    const totalBg   = PdfColor.fromInt(0xFF0D1B2A);
    const rowEven   = PdfColor.fromInt(0xFFF4F6FA);
    const accent    = PdfColor.fromInt(0xFF415A77);

    // cell helpers
    pw.Widget _cell(String text, {
      bool header = false,
      bool bold   = false,
      bool right  = false,
      PdfColor? color,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font:      (header || bold) ? boldFont : baseFont,
              fontSize:  8,
              color:     header
                  ? PdfColors.white
                  : (color ?? const PdfColor.fromInt(0xFF1A1A2E)),
            ),
          ),
        );

    pw.Widget _summaryLine(String label, String value,
        {bool highlight = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font:      highlight ? boldFont : baseFont,
                      fontSize:  highlight ? 10 : 9,
                      color:     highlight ? accent : PdfColors.grey700)),
              pw.Text(value,
                  style: pw.TextStyle(
                      font:      boldFont,
                      fontSize:  highlight ? 11 : 9,
                      color:     highlight ? accent : PdfColors.grey800)),
            ],
          ),
        );

    const rpp = 30;
    final pages = (transactions.length / rpp).ceil().clamp(1, 9999);

    final period = selectedDate != null
        ? '${DateFormat('d MMM y').format(selectedDate!.start)}'
        ' – ${DateFormat('d MMM y').format(selectedDate!.end)}'
        : 'All Dates';

    // account statement period label (mirrors the dialog's startLabel/endLabel)
    final statementStart = DateFormat('yyyy MMMM EEEE dd')
        .format(selectedDate?.start ?? DateTime.now());
    final statementEnd = DateFormat('yyyy MMMM EEEE dd')
        .format(selectedDate?.end ?? DateTime.now());

    for (int pg = 0; pg < pages; pg++) {
      final pageRows = transactions.skip(pg * rpp).take(rpp).toList();
      final isLast   = pg == pages - 1;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // header band
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: pw.BoxDecoration(
                  color: headerBg,
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(provider.company.toUpperCase(),
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 14,
                                  color: PdfColors.white)),
                          pw.SizedBox(height: 3),
                          pw.Text('GENERAL LEDGER',
                              style: pw.TextStyle(
                                  font: baseFont,
                                  fontSize: 9,
                                  color: PdfColors.blueGrey200)),
                          pw.Text('Address: ${provider.branchaddress}',
                              style: pw.TextStyle(
                                  font: baseFont,
                                  fontSize: 8,
                                  color: PdfColors.blueGrey200)),
                          pw.SizedBox(height: 2),
                          pw.Text('Account Name: $itemName',
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 10,
                                  color: PdfColors.white)),
                          pw.Text(
                              'Branch: ${_selectedBranch ?? "All Branches"}',
                              style: pw.TextStyle(
                                  font: baseFont,
                                  fontSize: 8,
                                  color: PdfColors.blueGrey200)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                              'ACCOUNT STATEMENT FROM $statementStart TO $statementEnd',
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 8,
                                  color: PdfColors.white)),
                        ]),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Period: $period',
                            style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 9,
                                color: PdfColors.white)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                            'Generated: ${DateFormat('d MMMM y, hh:mm a').format(DateTime.now())}',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColors.blueGrey200)),
                        pw.Text('Page ${pg + 1} of $pages',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColors.blueGrey200)),
                      ]),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

            // summary strip
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Wrap(spacing: 18, children: [
                pw.Text('Entries: ${transactions.length}',
                    style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white)),
                pw.Text('Total Debit: ${fmt.format(totDebit)}',
                    style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white)),
                pw.Text('Total Credit: ${fmt.format(totCredit)}',
                    style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white)),
                pw.Text('Net Balance: ${fmt.format(netBalance)}',
                    style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.greenAccent700)),
              ]),
            ),

            pw.SizedBox(height: 8),

            // data table
            pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(22),   // #
                1: const pw.FixedColumnWidth(65),   // Date
                2: const pw.FlexColumnWidth(3.0),   // Description
                3: const pw.FlexColumnWidth(1.4),   // Opening Balance
                4: const pw.FlexColumnWidth(1.4),   // Debit
                5: const pw.FlexColumnWidth(1.4),   // Credit
                6: const pw.FlexColumnWidth(1.4),   // Balance
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
                  decoration: const pw.BoxDecoration(color: headerBg),
                  children: [
                    _cell('#',               header: true),
                    _cell('DATE',            header: true),
                    _cell('DESCRIPTION',     header: true),
                    _cell('OPENING BAL.',    header: true, right: true),
                    _cell('DEBIT',           header: true, right: true),
                    _cell('CREDIT',          header: true, right: true),
                    _cell('BALANCE',         header: true, right: true),
                  ],
                ),

                // data rows
                ...pageRows.asMap().entries.map((e) {
                  final i   = e.key;
                  final t   = e.value;
                  final bg  = i.isOdd ? rowEven : PdfColors.white;

                  final desc    = (t['description'] ?? '').toString();
                  final opening = _d(t['openingBalance']);
                  final debit   = _d(t['debit']);
                  final credit  = _d(t['credit']);
                  final balance = _d(t['balance']).abs();

                  final balColor = balance < 0
                      ? PdfColors.red700
                      : const PdfColor.fromInt(0xFF1A1A2E);

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _cell('${pg * rpp + i + 1}'),
                      _cell(_fmtDate(t['date'])),
                      _cell(desc),
                      _cell(fmt.format(opening), right: true),
                      _cell(fmt.format(debit),   right: true,
                          color: debit > 0
                              ? const PdfColor.fromInt(0xFF1565C0)
                              : null),
                      _cell(fmt.format(credit),  right: true,
                          color: credit > 0
                              ? PdfColors.red700
                              : null),
                      _cell(fmt.format(balance), right: true,
                          bold: true, color: balColor),
                    ],
                  );
                }),
              ],
            ),

            pw.Spacer(),

            // summary box (last page only)
            if (isLast)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 260,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: rowEven,
                    border: pw.Border.all(color: accent, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text('LEDGER SUMMARY',
                          style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: accent)),
                      pw.SizedBox(height: 8),
                      _summaryLine('Opening Balance',  fmt.format(totOpening)),
                      _summaryLine('Total Debit',      fmt.format(totDebit)),
                      _summaryLine('Total Credit',     fmt.format(totCredit)),
                      pw.Divider(thickness: 0.8, color: accent),
                      _summaryLine('Net Balance',      fmt.format(netBalance),
                          highlight: true),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Total Entries: ${transactions.length}',
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: PdfColors.grey500),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            pw.SizedBox(height: 6),

            // footer
            pw.Divider(color: PdfColors.blueGrey200, thickness: 0.4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Confidential – ${provider.company}',
                    style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 7,
                        color: PdfColors.blueGrey400)),
                pw.Text(
                    'General Ledger | $itemName | $period',
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
      name: 'ledger_${itemName.replaceAll(' ', '_')}'
          '_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }


}
