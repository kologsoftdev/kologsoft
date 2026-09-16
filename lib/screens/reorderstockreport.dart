import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../models/stockReport.dart';
import '../widgets/itemhistorypdf.dart';
import '../widgets/printStockReportPdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
class reOrderStockPage extends StatefulWidget {
  const reOrderStockPage({super.key});

  @override
  State<reOrderStockPage> createState() => _reOrderStockPageState();
}

class _reOrderStockPageState extends State<reOrderStockPage> {


  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  Set<String> _categories = {'All'};
  String _sortBy = 'lastUpdate';
  bool _sortAscending = false;
  String? selectedBranch;
  String? selectedBranchName;

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;
  late final ScrollController _vController;
  late final ScrollController _hController;
  late final ScrollController _vvController;
  late final ScrollController _hhController;


  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      _verticalController = ScrollController();
      _horizontalController = ScrollController();


      _vController = ScrollController();
      _hController = ScrollController();
      _vvController = ScrollController();
      _hhController = ScrollController();
      final datafeed = context.read<Datafeed>();
      await datafeed.fetchBranches();
      //  await datafeed.fetchstockreport();
      final access =  datafeed.accesslevel.toLowerCase().trim();

      final canSelectBranches = access == 'super admin' || access == 'systemadmin' ||  access == 'admin';

      if (!canSelectBranches) {
        selectedBranch = datafeed.branchid;
        selectedBranchName = datafeed.branch;
      }

      await datafeed.fetchstockreport(
        selectedBranch: selectedBranch,
      );
    });

  }


  Future<void> _applyFilters() async {
    await context.read<Datafeed>().fetchstockreport(
      selectedDate: _selectedDateRange,
      selectedBranch: selectedBranch,
    );
  }
  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
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
                    _selectedDateRange = DateTimeRange(
                      start: range.startDate!,
                      end: range.endDate ?? range.startDate!,
                    );
                  });
                }
              },

              selectionMode: DateRangePickerSelectionMode.range,

              initialSelectedRange: _selectedDateRange != null
                  ? PickerDateRange(
                _selectedDateRange!.start,
                _selectedDateRange!.end,
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
            child: const Text('Clear', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  String _formatDateRange() {
    if (_selectedDateRange == null) return 'All dates';
    return '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}';
  }
  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _vController.dispose();
    _hController.dispose();
    _vvController.dispose();
    _hhController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    final provider = context.watch<Datafeed>();
    final stockreport = provider.filterReOrderstockreport();
    final canSelectAllBranches = provider.canDeleteRecords;
    final accesslevel = provider.accesslevel;
    final isSuperAdmin = accesslevel.toLowerCase().trim() == 'super admin';
    final systemadmin = accesslevel.toLowerCase().trim() == 'systemadmin';
    final admin = accesslevel.toLowerCase().trim() == 'admin';

    final canSelectBranches = isSuperAdmin || systemadmin || admin ||canSelectAllBranches;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:  Text(
          'Stock Report for ${selectedBranchName?? provider.company}',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _applyFilters,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1430),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Filter Bar
                Container(

                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                                onChanged: (value) {
                                  provider.updateSearch(value);

                                  _searchQuery = value;
                                  //  _applyFilters();
                                },
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Search ...',
                                  hintStyle: TextStyle(color: AppColors.textMuted),
                                  prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                  filled: true,
                                  fillColor: Color(0xFF22304A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _showDateRangePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                //color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: _selectedDateRange != null
                                    ? Border.all(color: AppColors.primary, width: 1.5)
                                    : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 20,
                                    color: _selectedDateRange != null ? AppColors.primary : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDateRange(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedDateRange != null ? AppColors.primary : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (_selectedDateRange != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedDateRange = null;
                                          _applyFilters();
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      isLargeScreen
                          ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              underline: const SizedBox(),
                              dropdownColor: AppColors.surface,
                              style: const TextStyle(color: AppColors.textPrimary),
                              iconEnabledColor: AppColors.textSecondary,
                              items: _categories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCategory = value;
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 300,
                            child: DropdownButtonFormField<String?>(
                              value: provider.canDeleteRecords ? selectedBranch : provider.branchid,
                              dropdownColor: const Color(0xFF22304A),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                fillColor: Color(0xFF22304A),
                                filled: true,
                                labelText: 'Select Branch',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                              items: provider.canDeleteRecords
                                  ? [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Branches', style: TextStyle(color: Colors.white)),
                                ),
                                ...provider.branches.map((branch) {
                                  final isUserBranch = branch.id == provider.branchid;
                                  return DropdownMenuItem<String?>(
                                    value: branch.id,
                                    child: Text(
                                      branch.branchname,
                                      style: TextStyle(color: isUserBranch ? Colors.grey : Colors.white),
                                    ),
                                  );
                                }),
                              ]
                                  : provider.branches
                                  .where((branch) => branch.id == provider.branchid)
                                  .map(
                                    (branch) => DropdownMenuItem<String?>(
                                  value: branch.id,
                                  child: Text(branch.branchname, style: const TextStyle(color: Colors.white)),
                                ),
                              )
                                  .toList(),
                              onChanged: provider.canDeleteRecords
                                  ? (val) async {
                                setState(() {
                                  selectedBranch = val;
                                  if (val != null) {
                                    final selected = provider.branches.firstWhere((b) => b.id == val);
                                    selectedBranchName = selected.branchname;
                                  } else {
                                    selectedBranchName = 'All Branches';
                                  }
                                });
                                await _applyFilters();
                              }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('Print/Download', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF415A77)),
                            onPressed: () {
                              final provider = context.read<Datafeed>();
                              printStockReportPdf(
                                reportData: provider.filterstockreport(),
                                companyName: provider.company,
                                branchName: selectedBranchName ?? 'All Branches',
                                dateRange:
                                '${DateFormat('d MMMM y').format(_selectedDateRange?.start ?? DateTime.now())} \u002D '
                                    '${DateFormat('d MMMM y').format(_selectedDateRange?.end ?? DateTime.now())}',
                              );
                            },
                          ),
                          const SizedBox(width: 20),
                          const Spacer(),
                        ],
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: AppColors.surface,
                              style: const TextStyle(color: AppColors.textPrimary),
                              iconEnabledColor: AppColors.textSecondary,
                              items: _categories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCategory = value;
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: 300,
                            child: DropdownButtonFormField<String?>(
                              value: canSelectBranches
                                  ? selectedBranch
                                  : provider.branchid,
                              dropdownColor: const Color(0xFF22304A),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                fillColor: Color(0xFF22304A),
                                filled: true,
                                labelText: 'Select Branch',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),

                              items: canSelectBranches
                                  ? [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'All Branches',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                ...provider.branches.map((branch) {
                                  return DropdownMenuItem<String?>(
                                    value: branch.id,
                                    child: Text(
                                      branch.branchname,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  );
                                }),
                              ]
                                  : provider.branches
                                  .where((b) => b.id == provider.branchid)
                                  .map(
                                    (branch) => DropdownMenuItem<String?>(
                                  value: branch.id,
                                  child: Text(
                                    branch.branchname,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                                  .toList(),

                              onChanged: canSelectBranches
                                  ? (val) async {
                                setState(() {
                                  selectedBranch = val;

                                  if (val == null) {
                                    selectedBranchName = 'All Branches';
                                  } else {
                                    final branch = provider.branches.firstWhere(
                                          (b) => b.id == val,
                                    );
                                    selectedBranchName = branch.branchname;
                                  }
                                });

                                await _applyFilters();
                              }
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('Print/Download', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF415A77)),
                            onPressed: () {
                              final provider = context.read<Datafeed>();
                              printStockReportPdf(
                                reportData: provider.filterstockreport(),
                                companyName: provider.company,
                                branchName: selectedBranchName ?? 'All Branches',
                                dateRange:
                                '${DateFormat('d MMMM y').format(_selectedDateRange?.start ?? DateTime.now())} \u002D '
                                    '${DateFormat('d MMMM y').format(_selectedDateRange?.end ?? DateTime.now())}',
                              );
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: provider.isloadingsalesreport
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)
                  )
                      :  stockreport.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'No stock items found',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                      : isLargeScreen
                      ? _buildStockTable()
                      :
                  ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: stockreport.length,

                    itemBuilder: (context, index) {
                      final item = stockreport[index];
                      return _buildStockCard(item);
                    },

                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }

  List<_StockColumn> _stockColumns() {
    return [
      const _StockColumn('#', 20),
      const _StockColumn('Product', 140),
      const _StockColumn('Opening Stock', 90, numeric: true),
      const _StockColumn('New Stock', 90, numeric: true),
      if (selectedBranch != null)
        const _StockColumn('Transfer In', 90, numeric: true),
      const _StockColumn('Sales Returns', 90, numeric: true),
      const _StockColumn('Total',80, numeric: true),
      const _StockColumn('Sales qty', 90, numeric: true),
      const _StockColumn('Purchase Returns', 80, numeric: true),
      const _StockColumn('Damages', 80, numeric: true),
      if (selectedBranch != null)
        const _StockColumn('Transfer Out', 80, numeric: true),
      const _StockColumn('Carton', 80, numeric: true),
      const _StockColumn('Piece balance', 80, numeric: true),
    ];
  }

  Widget _buildStockTable() {
    final provider = context.watch<Datafeed>();
    final reportData = provider.filterReOrderstockreport();
    final columns = _stockColumns();
    final double totalColsWidth =
        columns.fold<double>(0, (s, c) => s + c.width) +
            (columns.length - 1) * 24 +
            32;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = constraints.maxWidth > totalColsWidth
            ? constraints.maxWidth
            : totalColsWidth;

        return Scrollbar(
          controller: _hController,
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 0,
          child: SingleChildScrollView(
            controller: _hController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header
                  Container(
                    height: 40,
                    color: AppColors.surfaceLight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (int i = 0; i < columns.length; i++) ...[
                          SizedBox(
                            width: columns[i].width,
                            child: Text(
                              columns[i].label,
                              textAlign: columns[i].numeric
                                  ? TextAlign.right
                                  : TextAlign.left,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          if (i != columns.length - 1)
                            const SizedBox(width: 24),
                        ],
                      ],
                    ),
                  ),
                  // ── Body (virtualized rows) — takes remaining space
                  Expanded(
                    child: ListView.builder(
                      itemCount: reportData.length,
                      itemBuilder: (context, i) => _buildStockRow(
                          context, reportData[i], i, columns, selectedBranch),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildStockRow(BuildContext context, Map<String, dynamic> item,
      int index, List<_StockColumn> columns, dynamic selectedBranch) {
    final itemid = item['itemid'] ?? '';
    final itemname = item['item'] ?? '';

    final balanceCd = item['balance_cd'] ?? 0;
    final openingStock = item['opening_stock'] ?? 0;
    final transfer = item['transfer_qty'] ?? 0;
    final transferIn = item['transfer_recieved_qty'] ?? 0;
    final newStock = item['newstock'] ?? 0;
    final totalStock = item['total_stock'] ?? 0;
    final salesQty = item['sales_qty'] ?? 0;
    final purchaseReturns = item['purchase_returns'] ?? 0;
    final damages = item['damages'] ?? 0;
    final saleReturns = item['sale_returns'] ?? 0;
    final boxPiece = double.tryParse(item['cartonqty_bal'].toString()) ?? 1;
    final cartonQtyBal = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

    final cells = <Widget>[
      Text('${index + 1}',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      Text(itemname,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      Text(_formatNumber(openingStock),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      Text(_formatNumber(newStock),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      if (selectedBranch != null)
        Text(_formatNumber(transferIn),
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      Text(_formatNumber(saleReturns),
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary)),
      Text(_formatNumber(totalStock),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      Text(_formatNumber(salesQty),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      Text(_formatNumber(purchaseReturns),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      Text(_formatNumber(damages),
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary)),
      if (selectedBranch != null)
        Text(_formatNumber(transfer),
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textSecondary)),
      Text(
        cartonQtyBal > 0 ? '${_formatNumber(cartonQtyBal)} ' : '_',
        textAlign: TextAlign.right,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      Text(_formatNumber(balanceCd),
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary)),
    ];

    return InkWell(
      onTap: () {

      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, maxHeight: 60),
        alignment: Alignment.center,
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (int i = 0; i < columns.length; i++) ...[
              SizedBox(width: columns[i].width, child: cells[i]),
              if (i != columns.length - 1) const SizedBox(width: 24),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildStockCard(Map<String, dynamic> item) {

    final transfer = item['transfer_qty'] ?? 0;
    final transferIn = item['transfer_recieved_qty'] ?? 0;
    final itemid = item['itemid']?? '';
    final itemname = item['item']?? '';
    final balanceCd = item['balance_cd']?? 0;

    final openingStock = item['opening_stock']?? 0;
    final newStock = item['newstock']?? 0;
    final totalStock = item['total_stock']?? 0;
    final salesQty = item['sales_qty']?? 0;
    final cashSales = item['cash_sales']?? 0;
    final creditSales = item['credit_sales']?? 0;
    final purchaseReturns = item['purchase_returns']?? 0;
    final damages = item['damages']?? 0;

    final saleReturns = item['sale_returns']?? 0;
    final stockOut = item['stock_out']?? 0;

    final boxPiece =  double.tryParse(item['cartonqty_bal'].toString()) ?? 1;
    final cartonQtyBal = balanceCd / (boxPiece == 0 ? 1 : boxPiece);


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: (){

        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header — product name + balance
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item['item'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Balance: ${_formatNumber(balanceCd)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Carton: ${_formatNumber(cartonQtyBal)}',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 20, color: AppColors.border),

            //Stock movement
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _miniStat2("Opening", openingStock),
                _miniStat2("New Stock",newStock),
                _miniStat2("Total",totalStock),
                _miniStat2("Sales Qty",salesQty),
                //_miniStat2("Cash Sales",cashSales),
                //_miniStat2("Credit Sales",creditSales),
                _miniStat2("Sale Returns",saleReturns),
                _miniStat2("Purchase Returns",purchaseReturns),
                _miniStat2("Damages", damages),
                _miniStat2("Transfer Out",transfer),
                _miniStat2("Transfer In",transferIn),
                _miniStat2("Carton",cartonQtyBal),

              ],
            ),

          ],
        ),
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
            textAlign: TextAlign.right,
            value.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _miniStat2(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          _formatNumber(value),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }


  String _getSortDisplayName() {
    switch (_sortBy) {
      case 'name':
        return 'Name';
      case 'stockValue':
        return 'Value';
      case 'quantity':
        return 'Qty';
      default:
        return 'Date';
    }
  }

  String _formatNumber(dynamic number) {
    if (number is double) {
      return number.truncateToDouble() == number ? number.toInt().toString() : number.toStringAsFixed(1);
    }
    return number.toString();
  }




}
class _StockColumn {
  final String label;
  final double width;
  final bool numeric;
  const _StockColumn(this.label, this.width, {this.numeric = false});
}
class _HistoryColumn {
  final String label;
  final double width;
  const _HistoryColumn(this.label, this.width);
}