import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';
import '../models/stockReport.dart';
import '../widgets/branch_balance_pdf.dart';
import '../widgets/datepicker.dart';

class branchBalanceReportPage extends StatefulWidget {
  const branchBalanceReportPage({super.key});

  @override
  State<branchBalanceReportPage> createState() => _branchBalanceReportPageState();
}

class _branchBalanceReportPageState extends State<branchBalanceReportPage> {
  String _search   = '';
  String _branchId = '';
  final _searchCtrl = TextEditingController();
  DateTimeRange? selectedDate;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      context.read<Datafeed>().fetchItems();
      final datafeed = context.read<Datafeed>();
      await context.read<Datafeed>().fetchstockreport();
      await context.read<Datafeed>().fetchBranches();
      await datafeed.fetchBranches();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    final provider      = context.watch<Datafeed>();
    final branches      = provider.branches
        .where((b) => b.branchtype != 'Sales Point')
        .toList();

    final rows = provider.FetchBranchBalances(
      branchId: _branchId.isEmpty ? null : _branchId,
      search  : _search.isEmpty   ? null : _search,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Branch Balance',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white70),
            tooltip: 'Print PDF',
            onPressed: () {
              final provider = context.read<Datafeed>();
              final rows = provider.FetchBranchBalances(
                branchId: _branchId.isEmpty ? null : _branchId,
                search  : _search.isEmpty   ? null : _search,
              );
              BranchBalancePdf.print(
                rows : rows,
                companyName : provider.company,
                branchLabel : _branchId.isEmpty ? 'All Branches'
                    : provider.branches.firstWhere((b) => b.id == _branchId,
                    orElse: () => provider.branches.first).branchname,
                dateFrom  : selectedDate?.start,
                dateTo  : selectedDate?.end,
              );
            },
          ),
          ReusableDatePickerWidget(
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.calendar_today,
                  size: 20, color: Colors.white70),
            ),
            onDateSelected: (selection) {
              setState(() => selectedDate = selection);
              // context.read<Datafeed>().FetchBranchBalances(
              //     selectedDate: selectedDate,
              //     selectedBranch: _branchId);
            },
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      // Search
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) => setState(() => _search = v),
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Search by name or barcode...',
                                  hintStyle: const TextStyle(color: AppColors.textMuted),
                                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  filled: true,
                                  fillColor: const Color(0xFF22304A),
                                  suffixIcon: _search.isNotEmpty
                                      ? IconButton(
                                      icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _search = '');
                                      })
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Branch dropdown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: isLargeScreen ? 300 : 150,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _branchId.isEmpty ? null : _branchId,
                              dropdownColor: const Color(0xFF22304A),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                fillColor: Color(0xFF22304A),
                                filled: true,
                                labelText: 'Select Branch',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              hint: const Text('All Branches',
                                  style: TextStyle(color: Colors.white70)),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('All Branches',
                                      style: TextStyle(color: Colors.white)),
                                ),
                                ...branches.map((b) => DropdownMenuItem<String>(
                                  value: b.id,
                                  child: Text(b.branchname,
                                      style: TextStyle(
                                        color: b.id == provider.branchid
                                            ? Colors.grey
                                            : Colors.white,
                                      )),
                                )),
                              ],
                              //onChanged: (val) => setState(() => _branchId = val ?? ''),
                              onChanged: (val) {
                                setState(() => _branchId = val ?? '');
                                context.read<Datafeed>().applyStockBranch(
                                  val == null || val.isEmpty ? null : val,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: provider.isloadingsalesreport
                      ? const Center(child: CircularProgressIndicator())
                      : rows.isEmpty
                      ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('No records found',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                    ]),
                  )
                      : isLargeScreen
                      ? _buildStockTable(rows)
                      : _buildCardsList(rows),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildStockTable(List<Map<String, dynamic>> rows) {
  //   int index = 1;
  //   final provider = context.read<Datafeed>();
  //   return LayoutBuilder(
  //     builder: (context, constraints) {
  //       return SingleChildScrollView(
  //         child: ConstrainedBox(
  //           constraints: BoxConstraints(minWidth: constraints.maxWidth),
  //           child: DataTable(
  //             columnSpacing: 24,
  //             horizontalMargin: 16,
  //             headingRowHeight: 40,
  //             dataRowMinHeight: 44,
  //             dataRowMaxHeight: 44,
  //             showCheckboxColumn: false,
  //             headingRowColor: MaterialStateProperty.resolveWith<Color?>(
  //                     (states) => AppColors.surfaceLight),
  //             dataRowColor: MaterialStateProperty.resolveWith<Color?>(
  //                     (states) => AppColors.surface),
  //             dividerThickness: 1,
  //             columns: const [
  //               DataColumn(label: Text('#',
  //                   style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //               DataColumn(label: Text('Branch',
  //                   style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //               DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //               // DataColumn(label: Text('Carton Qty', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //               // DataColumn(label: Text('Carton balance', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //               //
  //               // DataColumn(numeric: true,
  //               //     label: Text('Balance',
  //               //         style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //               DataColumn(label: Text('Total Qty', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //               DataColumn(label: Text('Purchase Value', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //               DataColumn(numeric: true, label: Text('Selling Value', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
  //             ],
  //             rows: rows.map((item) {
  //               final branch    = item['branch'];
  //               final itemname  = item['item'];
  //               final balanceCd = item['balance'];
  //               final itemcp = double.tryParse(item['itemcp']?.toString() ?? '0') ?? 0.0;
  //               final itemsp = double.tryParse(item['itemsp']?.toString() ?? '0') ?? 0.0;
  //               // final carton_qty = item['carton_qty'];
  //               // final carton_balance = item['carton_balance'];
  //               final total_qty = item['total_qty'];
  //               final purchase_value = balanceCd * itemcp;
  //               final selling_value = balanceCd * itemsp;
  //               return DataRow(
  //                 onSelectChanged: (_) {},
  //                 cells: [
  //                   DataCell(Text('${index++}',
  //                       style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
  //                   DataCell(Text(_formatNumber(branch),
  //                       style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
  //                   DataCell(Text(itemname ?? '',
  //                       style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
  //                  // DataCell(Text(_formatNumber(carton_qty), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
  //                  // DataCell(Text(_formatNumber(carton_balance), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
  //                  // DataCell(Text(_formatNumber(balanceCd), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
  //                   DataCell(Text(_formatNumber(balanceCd), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
  //                   DataCell(Text(_formatNumber(purchase_value), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
  //                   DataCell(Text(_formatNumber(selling_value), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
  //                 ],
  //               );
  //             }).toList(),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }
  Widget _buildStockTable(List<Map<String, dynamic>> rows) {
    final provider = context.read<Datafeed>();

    return LayoutBuilder(
      builder: (context, constraints) {
        const widths = [30, 100, 200, 100, 90, 90];
        const gap = 24.0;
        final double contentWidth = widths.reduce((a, b) => a + b) +
            (widths.length - 1) * gap +
            32;
        final double tableWidth =
        constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

        Widget rowOf(List<Widget> cells) {
          return Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
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

        return SizedBox(
          width: tableWidth,
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 40,
                color: AppColors.surfaceLight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(width: widths[0].toDouble(), child: const Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    const SizedBox(width: gap),
                    SizedBox(width: widths[1].toDouble(), child: const Text('Branch', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    const SizedBox(width: gap),
                    SizedBox(width: widths[2].toDouble(), child: const Text('Product', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    const SizedBox(width: gap),
                    SizedBox(width: widths[3].toDouble(), child: const Text('Total Qty', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    const SizedBox(width: gap),
                    SizedBox(width: widths[4].toDouble(), child: const Text('Purchase Value', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    const SizedBox(width: gap),
                    SizedBox(width: widths[5].toDouble(), child: const Text('Selling Value', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final item = rows[i];
                    final branch = item['branch'];
                    final itemname = item['item'];
                    final balanceCd = item['balance'];
                    final itemcp = double.tryParse(item['itemcp']?.toString() ?? '0') ?? 0.0;
                    final itemsp = double.tryParse(item['itemsp']?.toString() ?? '0') ?? 0.0;
                    final purchase_value = balanceCd * itemcp;
                    final selling_value = balanceCd * itemsp;

                    return rowOf([
                      Text('${i + 1}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                      Text(_formatNumber(branch), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text(itemname ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                      Text(_formatNumber(balanceCd), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text(_formatNumber(purchase_value), style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text(_formatNumber(selling_value), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    ]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildCardsList(List<Map<String, dynamic>> rows) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rows.length,
      itemBuilder: (context, index) => _buildStockCard(rows[index]),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> item) {
    final branch    = item['branch'];
    final itemname  = item['item'];
    final balanceCd = item['balance'];
    final itemcp = double.tryParse(item['itemcp']?.toString() ?? '0') ?? 0.0;
    final itemsp = double.tryParse(item['itemsp']?.toString() ?? '0') ?? 0.0;
    // final carton_qty = item['carton_qty'];
    // final carton_balance = item['carton_balance'];

    final purchase_value = balanceCd * itemcp;
    final selling_value = balanceCd * itemsp;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(itemname ?? '',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Text('Balance: ${_formatNumber(balanceCd)}',
                    //     style: const TextStyle(
                    //         fontSize: 16, fontWeight: FontWeight.bold,
                    //         color: Colors.white70)),
                    // Text('Branch: ${_formatNumber(branch)}',
                    //     style: const TextStyle(
                    //         fontSize: 16, fontWeight: FontWeight.bold,
                    //         color: Colors.white70)),
                    Text('Selling: ${_formatNumber(selling_value)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
                    Text('Branch: $branch', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 2),
                  ],
                ),
              ],
            ),
            const Divider(height: 20, color: AppColors.border),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _miniStat2('Total Qty', balanceCd),
                _miniStat2('Purchase Value', purchase_value),
                _miniStat2('Selling Value', selling_value),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat2(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(_formatNumber(value),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
      ],
    );
  }

  String _formatNumber(dynamic number) {
    if (number is double) {
      return number.truncateToDouble() == number
          ? number.toInt().toString()
          : number.toStringAsFixed(1);
    }
    return number.toString();
  }
}