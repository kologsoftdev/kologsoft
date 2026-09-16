import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import 'package:flutter/foundation.dart' show listEquals;

import '../models/itemhistory.dart';
import '../models/stockReport.dart';
import '../widgets/itemhistorypdf.dart';
import '../widgets/printStockReportPdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {

  Datafeed? _datafeed;
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
  late final TextEditingController _searchController;
  late final TextEditingController _dialogSearchController;
  late final TextEditingController _itemHistorySearchController;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Datafeed>().updateSearch('');
      context.read<Datafeed>().updateStockReportSearch('');
      context.read<Datafeed>().updateStockDialogSearch('');
      context.read<Datafeed>().updateItemHistorySearch('');
    });
    _verticalController = ScrollController();
    _horizontalController = ScrollController();


    _vController = ScrollController();
    _hController = ScrollController();
    _vvController = ScrollController();
    _hhController = ScrollController();
    _searchController = TextEditingController();
    _dialogSearchController = TextEditingController();
    _itemHistorySearchController = TextEditingController();
    Future.microtask(() async {
      if (!mounted) return;

      final datafeed = context.read<Datafeed>();
      await datafeed.fetchBranches();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _datafeed = context.read<Datafeed>();
  }
  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _vController.dispose();
    _hController.dispose();
    _vvController.dispose();
    _hhController.dispose();
    _searchController.dispose();
    _dialogSearchController.dispose();
    _itemHistorySearchController.dispose();

    // IMPORTANT: don't call notifyListeners() synchronously inside dispose() —
    // the widget tree is locked during unmount and this throws
    // "setState() or markNeedsBuild() called when widget tree was locked."
    // Defer the provider notifications to a microtask so they run
    // after the current unmount/frame cycle completes.
    final datafeed = _datafeed;
    if (datafeed != null) {
      Future.microtask(() {
        datafeed.updateSearch('');
        datafeed.updateStockReportSearch('');
        datafeed.updateStockDialogSearch('');
        datafeed.updateItemHistorySearch('');
      });
    }

    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    final provider = context.watch<Datafeed>();
    final stockreport = provider.filterstockreport();
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
            icon: const Icon(Icons.home, size: 25),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
          ),
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
                              child: TextFormField(
                                controller: _searchController,
                                onChanged: (value) {
                                  provider.updateStockReportSearch(value);

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
                              isExpanded: true,
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
                            isExpanded: true,
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
      const _StockColumn('#', 30),
      const _StockColumn('Product', 140),
      const _StockColumn('Opening Stock', 80, numeric: true),
      const _StockColumn('New Stock', 80, numeric: true),
      if (selectedBranch != null)
        const _StockColumn('Transfer In', 80, numeric: true),
      const _StockColumn('Sales Returns', 80, numeric: true),
      const _StockColumn('Total',80, numeric: true),
      const _StockColumn('Sales qty', 80, numeric: true),
      const _StockColumn('Purchase Returns', 80, numeric: true),
      const _StockColumn('Damages', 80, numeric: true),
      if (selectedBranch != null)
        const _StockColumn('Transfer Out', 80, numeric: true),

      const _StockColumn('balance', 80, numeric: true),
      const _StockColumn('Carton', 80, numeric: true),
    ];
  }

  Widget _buildStockTable() {
    final provider = context.watch<Datafeed>();
   final reportData = provider.filterstockreport();
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

      Text(_formatNumber(balanceCd),
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary)),
      Text(
        cartonQtyBal > 0 ? '${_formatNumber(cartonQtyBal)} ' : '_',
        textAlign: TextAlign.right,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ];

    return InkWell(
      onTap: () {
        showStockTransactionsDialog(
          context,
          itemId: itemid,
          itemName: itemname,
          boxpiece: boxPiece,
        );
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
          showStockTransactionsDialog(
            context,
            itemId:    itemid,
            itemName:  itemname,
            boxpiece: boxPiece,
          );
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


  Future<void> showStockTransactionsDialog( BuildContext context, { required String itemId, required String itemName,double? boxpiece}) async {
    _dialogSearchController.clear();
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
      final startDate = _selectedDateRange?.start ?? DateTime(now.year, now.month, now.day);
      final endDate   = _selectedDateRange?.end   ?? DateTime(now.year, now.month, now.day);

      await provider.loadStockTransactions(
        startDate: startDate,
        endDate: endDate,
        itemId: itemId,
        itemName: itemName,
        selectedBranch: selectedBranch,

      );
    } catch (e) {
      print(e);
    }

    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).pop();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<Datafeed>(
          builder: (context, provider, _) {
            final transactions =   provider.filterstockTransactions();

            final isSmallScreen =   MediaQuery.of(dialogContext).size.width < 600;

            return AlertDialog(
              backgroundColor: const Color(0xFF101624),

              title: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$itemName STOCK MOVEMENT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,color: Colors.white),
                        onPressed: () {
                          context.read<Datafeed>().updateStockDialogSearch('');
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dialogSearchController,
                          onChanged: (val){
                            provider.updateStockDialogSearch(val);
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search ...",
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
                      ),
                      SizedBox(width: 30,),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('Print', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF415A77),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () async {
                          final datafeed = Provider.of<Datafeed>(dialogContext, listen: false);
                          await printStockTransactionsPdf(
                            transactions: provider.filterstockTransactions(),
                            itemName: itemName,
                            companyName: datafeed.company,
                            branchName: selectedBranch ?? 'All Branches',
                            dateRange:
                            '${DateFormat('d MMMM y').format(_selectedDateRange?.start ?? DateTime.now())}'
                                ' \u002D '
                                '${DateFormat('d MMMM y').format(_selectedDateRange?.end ?? DateTime.now())}',
                            boxpiece: boxpiece,
                          );
                        },
                      ),
                    ],
                  ),

                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                height:
                MediaQuery.of(context).size.height * 0.94,
                child: transactions.isEmpty
                    ? const Text(
                  "No transactions found",
                  style:
                  TextStyle(color: Colors.white70),
                )
                    : isSmallScreen
                    ? _buildMobileStockCards(transactions,boxpiece)
                    : _buildDesktopStockTable(transactions,boxpiece),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileStockCards( List<Map<String, dynamic>> transactions,double? boxpiece ) {
    final verticalController = ScrollController();

    return Scrollbar(
      controller: verticalController,
      child: ListView.builder(
        controller: verticalController,
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final t = transactions[index];

          final no = index + 1;
          final item = t['item'] ?? '';
          final itemid = t['itemId'] ?? '';
          final branch = t['branch'] ?? '';


          final transferIn = t['transfer_recieved_qty']?? 0;
          final openingStock = t['opening_stock'] ?? 0;
          final newStock = t['newstock'] ?? 0;
          final creditSales = t['credit_sales'] ?? 0;
          final cashSales = t['cash_sales'] ?? 0;
          final salesQty = t['sales_qty'] ?? 0;
          final saleReturns = t['sale_returns'] ?? 0;
          final purchaseReturns = t['purchase_returns'] ?? 0;
          final damages = t['damages'] ?? 0;
          final transfer = t['transfer_qty'] ?? 0;

          final balance = t['balance_cd'] ?? 0;

          //final boxPiece =  double.tryParse(t['boxpieces'].toString()) ?? 1;
          final boxPiece =  double.tryParse(boxpiece.toString()) ?? 1;

          final cartonQtyBal = balance / (boxPiece == 0 ? 1 : boxPiece);
          final datte = t['date'] ?? '';

          String formattedDate = '-';

          if (datte is DateTime) {
            formattedDate = DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(datte);
          } else if (datte is Timestamp) {
            formattedDate = DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(datte.toDate());
          }

          return InkWell(
             onTap: (){
               showItemHistoryDialog(context,
                   itemId: itemid,
                   itemName: item,
                   branchId: selectedBranch,
                   boxpieces:boxPiece
               );
             },
            child: Card(
              color: const Color(0xFF1A2235),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                      item.toString(),
                      style: const TextStyle(
                        color: Colors.amberAccent,
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
                        _miniStatstring(
                          "Branch",
                          branch.toString(),
                        ),
                        _miniStatstring(
                          "Opening Stock",
                          openingStock.toString(),
                        ),


                        _miniStatstring(
                          "New Stock",
                          newStock.toString(),
                        ),
                        _miniStatstring(
                          "Sales Qty",
                          salesQty.toString(),
                        ),
                       // _miniStatstring( "Cash Sales", cashSales.toString(),),
                      //  _miniStatstring("Credit Sales", creditSales.toString(), ),
                        _miniStatstring(
                          "Sale Returns",
                          saleReturns.toString(),
                        ),
                        _miniStatstring("Transfer In",  transferIn?.toString() ?? '0'),
                        _miniStatstring("Transfer Out", t['transfer']?.toString() ?? '0'),
                        _miniStatstring(
                          "Purchase Returns",
                          purchaseReturns.toString(),
                        ),
                        _miniStatstring(
                          "Damages",
                          damages.toString(),
                        ),
                        _miniStatstring(
                          "Transfer",
                          transfer.toString(),
                        ),

                        _miniStatstring(
                          "Balance",
                          balance.toString(),
                        ),
                        _miniStatstring(
                          "Carton",
                          cartonQtyBal.toStringAsFixed(1),
                        ),
                      ],
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


  final List<_HistoryColumn> _historyColumns = const [
    _HistoryColumn('#', 40),
    _HistoryColumn('Date', 100),
    _HistoryColumn('Opening', 90),
    _HistoryColumn('New Stock', 100),
    _HistoryColumn('Transfer In', 100),
    _HistoryColumn('Transfer Out', 110),
    _HistoryColumn('Sales Qty', 90),
    _HistoryColumn('Sale Returns', 110),
    _HistoryColumn('Purchase Returns', 130),
    _HistoryColumn('Damages', 90),

    _HistoryColumn('Balance', 90),
    _HistoryColumn('Carton', 80),
    _HistoryColumn('Branch', 110),
  ];

  Widget _buildDesktopStockTable(
      List<Map<String, dynamic>> transactions, double? boxpiece) {
    final verticalController = ScrollController();
    final horizontalController = ScrollController();
    final double totalColsWidth =
        _historyColumns.fold<double>(0, (s, c) => s + c.width) +
            (_historyColumns.length - 1) * 24 +
            32;

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
        trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
        thickness: MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double contentWidth = constraints.maxWidth > totalColsWidth
              ? constraints.maxWidth
              : totalColsWidth;

          return Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalController,
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
                          for (int i = 0; i < _historyColumns.length; i++) ...[
                            SizedBox(
                              width: _historyColumns[i].width,
                              child: Text(
                                _historyColumns[i].label,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            if (i != _historyColumns.length - 1)
                              const SizedBox(width: 24),
                          ],
                        ],
                      ),
                    ),
                    // ── Body (virtualized rows)
                    Expanded(
                      child: Scrollbar(
                        controller: verticalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: ListView.builder(
                          controller: verticalController,
                          itemCount: transactions.length,
                          itemBuilder: (context, index) => _buildDesktopStockRow(
                              context, transactions[index], index, boxpiece),
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

  Widget _buildDesktopStockRow(BuildContext context, Map<String, dynamic> t,
      int index, double? boxpiece) {
    final summarydate = t['date'] ?? '';
    final opening_stock = t['opening_stock'] ?? 0;
    final newstock = t['newstock'] ?? 0;
    final salesQty = t['sales_qty'] ?? 0;
    final sale_returns = t['sale_returns'] ?? 0;
    final purchase_returns = t['purchase_returns'] ?? 0;
    final damages = t['damages'] ?? 0;
    final balance_cd = t['balance_cd'] ?? 0;
    final branch = t['branch'] ?? '';
    final transferIn = t['transfer_recieved_qty'] ?? 0;
    final transferOut = t['transfer_qty'] ?? 0;
    final item = t['item'] ?? '';
    final itemid = t['itemId'] ?? '';
    final boxPiece = double.tryParse(boxpiece.toString()) ?? 1;
    final cartonQtyBal = balance_cd / (boxPiece == 0 ? 1 : boxPiece);

    final cells = <Widget>[
      Text('${index + 1}', style: const TextStyle(color: Colors.white70)),
      Text(summarydate.toString(), style: const TextStyle(color: Colors.white70)),
      Text(opening_stock.toString(), style: const TextStyle(color: Colors.white70)),
      Text(newstock.toString(), style: const TextStyle(color: Colors.white70)),
      Text(transferIn.toString(), style: const TextStyle(color: Colors.white70)),
      Text(transferOut.toString(), style: const TextStyle(color: Colors.white70)),
      Text(salesQty.toString(), style: const TextStyle(color: Colors.white70)),
      Text(sale_returns.toString(), style: const TextStyle(color: Colors.white70)),
      Text(purchase_returns.toString(), style: const TextStyle(color: Colors.white70)),
      Text(damages.toString(), style: const TextStyle(color: Colors.white70)),

      Text(balance_cd.toString(), style: const TextStyle(color: Colors.white70)),
      Text(cartonQtyBal.toStringAsFixed(1), style: const TextStyle(color: Colors.white70)),
      Text(branch.toString(), style: const TextStyle(color: Colors.white70)),
    ];

    return InkWell(
      onTap: () {
        showItemHistoryDialog(context,
            itemId: itemid,
            itemName: item,
            branchId: selectedBranch,
            boxpieces: boxPiece);
      },
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            for (int i = 0; i < _historyColumns.length; i++) ...[
              SizedBox(width: _historyColumns[i].width, child: cells[i]),
              if (i != _historyColumns.length - 1) const SizedBox(width: 24),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> showItemHistoryDialog(BuildContext context, {required String itemId,required String itemName,required String? branchId,double? boxpieces}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final now = DateTime.now();

    final startDate = _selectedDateRange?.start ?? DateTime(now.year, now.month, now.day);
    final endDate = _selectedDateRange?.end ?? now;
    await context.read<Datafeed>().loadItemHistory(
      itemId:    itemId,
      itemName:  itemName,
      branchId:  branchId,
      startDate: startDate,
      endDate:  endDate,
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final dateLabel = _selectedDateRange == null
        ? DateFormat('dd MMM yyyy').format(DateTime.now())
        : '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} – '
        '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}';

    showDialog(
      context: context,
      builder: (dialogContext) {
        _itemHistorySearchController.clear();
        final datafeed  = context.read<Datafeed>();
        final entries   = datafeed.itemHistoryEntries;
        final isSmall   = MediaQuery.of(dialogContext).size.width < 600;

        Color signColor(String s) => s == '+' ? Colors.greenAccent : Colors.redAccent;
        Color typeColor(String t) {
          switch (t) {
            case 'Sale':          return Colors.redAccent;
            case 'Sales Return':  return Colors.greenAccent;
            case 'Purchase':      return Colors.blueAccent;
            case 'Transfer Out':  return Colors.orangeAccent;
            default:              return Colors.white54;
          }
        }


        return Consumer<Datafeed>(
          builder: (context, datafeed, _) {
            final entries = datafeed.filterItemHistoryEntries();

            return AlertDialog(
              backgroundColor: const Color(0xFF101624),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(itemName.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text('Stock History  ·  $dateLabel',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {
                          context.read<Datafeed>().updateItemHistorySearch('');
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _itemHistorySearchController,
                    onChanged: (val) {
                      context.read<Datafeed>().updateItemHistorySearch(val);
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search ...",
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
                width: double.maxFinite,
                height: MediaQuery.sizeOf(dialogContext).height * 0.82,
                child: entries.isEmpty
                    ? const Center(
                    child: Text('No transactions found.',
                        style: TextStyle(color: Colors.white54)))
                    : isSmall
                    ? ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final t = entries[i];
                    final double qty = (t.qty ?? 0).toDouble();
                    final box = boxpieces ?? 1;
                    final double cartonqty = boxpieces == 0 ? 0 : qty / box;
                    final dateStr = t.date != null
                        ? DateFormat('dd MMM yyyy  hh:mm a')
                        .format(t.date!)
                        : '-';
                    return Card(
                      color: const Color(0xFF1A2235),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: typeColor(t.type).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color:
                                      typeColor(t.type).withOpacity(0.5)),
                                ),
                                child: Text(t.type,
                                    style: TextStyle(
                                        color: typeColor(t.type),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const Spacer(),
                              Text(dateStr,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11)),
                            ]),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${t.sign}${t.qty.toStringAsFixed(0)} pcs',
                                    style: TextStyle(
                                        color: signColor(t.sign),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text('GHS ${t.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('${t.sign}${cartonqty.toStringAsFixed(0)} Carton',
                                style: TextStyle(
                                    color: signColor(t.sign),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('${t.branch}  ·  ${t.staff}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                            if (t.transactionid.isNotEmpty)
                              Text('Ref: ${t.transactionid}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  },
                )
                    : ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor:
                    MaterialStateProperty.all(const Color(0xFF415A77)),
                    trackColor:
                    MaterialStateProperty.all(const Color(0xFF22304A)),
                    thickness: MaterialStateProperty.all(8),
                    radius: const Radius.circular(6),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double gap =
                      MediaQuery.sizeOf(context).width < 1100 ? 14 : 40;
                      final isKS008 = datafeed.companyid == 'KS008';

                      final detailColumns = <_HistoryColumn>[
                        const _HistoryColumn('#', 30),
                        const _HistoryColumn('Entry Date', 130),
                        const _HistoryColumn('Txn Date', 90),
                        const _HistoryColumn('Type', 100),
                        if (isKS008) ...[
                          const _HistoryColumn('Carton', 70),
                        ],
                        const _HistoryColumn('±Qty (pcs)', 60),
                        const _HistoryColumn('Unit Price', 70),
                        const _HistoryColumn('Total', 80),
                        const _HistoryColumn('Mode', 80),
                        const _HistoryColumn('Branch', 80),
                        const _HistoryColumn('Staff', 60),
                        const _HistoryColumn('Record ID', 90),
                      ];

                      final double contentWidth = detailColumns
                          .fold<double>(0, (s, c) => s + c.width) +
                          (detailColumns.length - 1) * gap +
                          32;
                      final double tableWidth =
                      constraints.maxWidth > contentWidth
                          ? constraints.maxWidth
                          : contentWidth;

                      return Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      for (int i = 0;
                                      i < detailColumns.length;
                                      i++) ...[
                                        SizedBox(
                                          width: detailColumns[i].width,
                                          child: Text(
                                              detailColumns[i].label,
                                              style: const TextStyle(
                                                  color: Colors.white70)),
                                        ),
                                        if (i != detailColumns.length - 1)
                                          SizedBox(width: gap),
                                      ],
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Scrollbar(
                                    controller: _verticalController,
                                    thumbVisibility: true,
                                    child: ListView.builder(
                                      controller: _verticalController,
                                      itemCount: entries.length,
                                      itemBuilder: (context, i) {
                                        final t = entries[i];
                                        final dateStr = t.date != null
                                            ? DateFormat(
                                            'dd MMM yyyy  hh:mm a')
                                            .format(t.date!)
                                            : '-';
                                        final invoiceDateStr =
                                            t.invoiceDate ?? '';

                                        final double qty =
                                        (t.qty).toDouble();
                                        final box = boxpieces ?? 1;
                                        final double cartonqty =
                                        boxpieces == 0 ? 0 : qty / box;

                                        final detailCells = <Widget>[
                                          Text('${i + 1}',
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12)),
                                          Text(dateStr,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                          Text(invoiceDateStr,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                          Container(
                                            padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: typeColor(t.type)
                                                  .withOpacity(0.12),
                                              borderRadius:
                                              BorderRadius.circular(5),
                                            ),
                                            child: Text(t.type,
                                                style: TextStyle(
                                                    color:
                                                    typeColor(t.type),
                                                    fontSize: 11,
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          if (isKS008) ...[
                                            Text(
                                                '${t.sign}${cartonqty.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                    color:
                                                    signColor(t.sign),
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    fontSize: 13)),
                                          ],
                                          Text(
                                              '${t.sign}${t.qty.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                  color: signColor(t.sign),
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  fontSize: 13)),
                                          Text(t.price.toStringAsFixed(2),
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                          Text(t.total.toStringAsFixed(2),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight:
                                                  FontWeight.w600)),
                                          Text(t.mode,
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12)),
                                          Text(t.branch,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                          Text(t.staff,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                          Text(
                                              t.transactionid.isNotEmpty
                                                  ? t.transactionid
                                                  : '-',
                                              style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11)),
                                        ];

                                        return Padding(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8),
                                          child: Row(
                                            children: [
                                              for (int i = 0;
                                              i < detailColumns.length;
                                              i++) ...[
                                                SizedBox(
                                                    width: detailColumns[i]
                                                        .width,
                                                    child: detailCells[i]),
                                                if (i !=
                                                    detailColumns.length - 1)
                                                  SizedBox(width: gap),
                                              ],
                                            ],
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    printItemHistory(
                      context,
                      entries: datafeed.itemHistoryEntries,
                      itemName: itemName,
                      dateLabel: dateLabel,
                      companyName: datafeed.companyid,
                    );
                  },
                  child: const Text('Print / Download',
                      style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () {
                    context.read<Datafeed>().updateItemHistorySearch('');
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Close', style: TextStyle(color: Colors.white70)),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> printStockTransactionsPdf({
    required List<Map<String, dynamic>> transactions,
    required String itemName,
    required String companyName,
    String branchName = 'All Branches',
    String dateRange = '',
    double? boxpiece,
  }) async {
    final pdf = pw.Document();
    final ttfRegular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final ttfBold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    const headerBg = PdfColor.fromInt(0xFF1E3A5F);
    const rowAlt   = PdfColor.fromInt(0xFFF0F4FA);
    const accent   = PdfColor.fromInt(0xFF1565C0);
    const dark     = PdfColor.fromInt(0xFF0D1B2A);
    const white    = PdfColors.white;

    String fmt(dynamic v) {
      if (v == null) return '0';
      final d = double.tryParse(v.toString()) ?? 0.0;
      return d == d.truncateToDouble()
          ? d.toInt().toString()
          : d.toStringAsFixed(2);
    }

    pw.TextStyle boldWhite(double size) => pw.TextStyle(
      font: ttfBold,
        color: white, fontWeight: pw.FontWeight.bold, fontSize: size);

    pw.TextStyle cell({bool bold = false, PdfColor? color}) => pw.TextStyle(
      fontSize: 7,
      font: ttfRegular,
      color: color ?? dark,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    final hasCarton = boxpiece != null && boxpiece > 0;

    // Headers now match the screen exactly
    final headers = [
      '#', 'Date', 'Opening', 'New\nStock',
      'Transfer\nIn', 'Transfer\nOut', 'Sales\nQty',
      'Cash\nSales', 'Credit\nSales', 'Sale\nReturns',
      'Purchase\nReturns', 'Damages',
      'Balance',
      if (hasCarton) 'Carton',
      'Branch',
    ];

    final colWidths = [
      15.0, 52.0, 35.0, 35.0,
      38.0, 38.0, 35.0,
      38.0, 38.0, 35.0,
      42.0, 35.0,
      38.0,
      if (hasCarton) 35.0,

      40.0,
    ];

    const int rowsPerPage = 28;
    final pageCount = ((transactions.length) / rowsPerPage).ceil().clamp(1, 9999);

    // Totals to match summary bar
    double totSalesQty = 0, totCash = 0, totCredit = 0;
    double totTransferIn = 0, totTransferOut = 0;
    double totSaleReturns = 0, totPurchaseReturns = 0, totDamages = 0;
    double totNewStock = 0, totBalance = 0;

    for (final t in transactions) {
      totNewStock       += (t['newstock']            ?? 0).toDouble();
      totTransferIn     += (t['transfer_recieved_qty']?? 0).toDouble();
      totTransferOut    += (t['transfer_qty']         ?? 0).toDouble();
      totSalesQty       += (t['sales_qty']            ?? 0).toDouble();
      totCash           += (t['cash_sales']           ?? 0).toDouble();
      totCredit         += (t['credit_sales']         ?? 0).toDouble();
      totSaleReturns    += (t['sale_returns']         ?? 0).toDouble();
      totPurchaseReturns+= (t['purchase_returns']     ?? 0).toDouble();
      totDamages        += (t['damages']              ?? 0).toDouble();
      totBalance        += (t['balance_cd']           ?? 0).toDouble();
    }

    for (int pageIdx = 0; pageIdx < pageCount; pageIdx++) {
      final pageRows = transactions
          .skip(pageIdx * rowsPerPage)
          .take(rowsPerPage)
          .toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // Header banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: headerBg,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(companyName.toUpperCase(), style: boldWhite(13)),
                        pw.SizedBox(height: 2),
                        pw.Text('Stock Movement Report', style: pw.TextStyle(
                            color: PdfColors.blueGrey200, fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text('Item: $itemName', style: boldWhite(9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Branch: $branchName', style: boldWhite(9)),
                        if (dateRange.isNotEmpty)
                          pw.Text('Period: $dateRange',
                              style: pw.TextStyle(
                                  color: PdfColors.blueGrey200, fontSize: 8)),
                        pw.Text(
                          'Generated: ${DateFormat('d MMMM y').format(DateTime.now())}',
                          style: pw.TextStyle(
                              color: PdfColors.blueGrey200, fontSize: 8),
                        ),
                        pw.Text('Page ${pageIdx + 1} of $pageCount',
                            style: pw.TextStyle(
                                color: PdfColors.blueGrey200, fontSize: 8)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              //  Summary bar matches screen columns
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Wrap(
                  spacing: 16,
                  children: [
                    pw.Text('Total Transactions: ${transactions.length}', style: boldWhite(8)),
                    pw.Text('Transfer In: ${fmt(totTransferIn)}',   style: boldWhite(8)),
                    pw.Text('Transfer Out: ${fmt(totTransferOut)}', style: boldWhite(8)),
                    pw.Text('Sales Qty: ${fmt(totSalesQty)}',       style: boldWhite(8)),
                    pw.Text('Cash Sales: ${fmt(totCash)}',          style: boldWhite(8)),
                    pw.Text('Credit Sales: ${fmt(totCredit)}',      style: boldWhite(8)),
                    pw.Text('Sale Returns: ${fmt(totSaleReturns)}', style: boldWhite(8)),
                    pw.Text('Damages: ${fmt(totDamages)}',          style: boldWhite(8)),
                    pw.Text('Balance: ${fmt(totBalance)}',  style: boldWhite(8)),
                    if (hasCarton)
                      pw.Text('Carton: ${fmt(totBalance / boxpiece!)}', style: boldWhite(8)),

                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Table
              pw.Table(
                columnWidths: {
                  for (int i = 0; i < colWidths.length; i++)
                    i: pw.FixedColumnWidth(colWidths[i]),
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                      color: PdfColors.blueGrey100, width: 0.4),
                  bottom: pw.BorderSide(
                      color: PdfColors.blueGrey300, width: 0.5),
                ),
                children: [

                  // Column headers
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: headerBg),
                    children: headers.map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 3, vertical: 5),
                      child: pw.Text(h,
                          style: boldWhite(7),
                          textAlign: pw.TextAlign.center),
                    )).toList(),
                  ),

                  // Data rows using same keys as the screen table
                  ...pageRows.asMap().entries.map((entry) {
                    final rowNum = pageIdx * rowsPerPage + entry.key + 1;
                    final item   = entry.value;
                    final isAlt  = entry.key.isOdd;

                    final balance   = (item['balance_cd'] ?? 0).toDouble();
                    final bp        = boxpiece != null && boxpiece > 0 ? boxpiece : 1.0;
                    final carton    = balance / bp;

                    final values = [
                      '$rowNum',
                      item['date']?.toString() ?? '',
                      fmt(item['opening_stock']),
                      fmt(item['newstock']),
                      fmt(item['transfer_recieved_qty']),
                      fmt(item['transfer_qty']),
                      fmt(item['sales_qty']),
                      fmt(item['cash_sales']),
                      fmt(item['credit_sales']),
                      fmt(item['sale_returns']),
                      fmt(item['purchase_returns']),
                      fmt(item['damages']),
                      fmt(balance),
                      if (hasCarton) (carton > 0 ? fmt(carton) : '-'),

                      item['branch']?.toString() ?? branchName,
                    ];

                    return pw.TableRow(
                      decoration: isAlt
                          ? const pw.BoxDecoration(color: rowAlt)
                          : null,
                      children: values.asMap().entries.map((e) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 3, vertical: 4),
                        child: pw.Text(
                          e.value,
                          style: cell(
                            bold: e.key == values.length - 2, // bold Balance
                            color: (e.key == values.length - 2 && balance <= 0)
                                ? PdfColors.red700
                                : null,
                          ),
                          textAlign: (e.key == 1 || e.key == values.length - 1)
                              ? pw.TextAlign.left
                              : pw.TextAlign.right,
                        ),
                      )).toList(),
                    );
                  }),

                  // Totals row (last page only)
                  if (pageIdx == pageCount - 1)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: headerBg),
                      children: [
                        // #
                        pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('', style: boldWhite(7))),
                        // Date → "TOTAL" label
                        pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('TOTAL', style: boldWhite(7))),
                        // Opening
                        pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('', style: boldWhite(7))),
                        // New Stock
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totNewStock),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Transfer In
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totTransferIn),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Transfer Out
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totTransferOut),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Sales Qty
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totSalesQty),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Cash Sales
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totCash),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Credit Sales
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totCredit),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Sale Returns
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totSaleReturns),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Purchase Returns
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totPurchaseReturns),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Damages
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totDamages),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Carton (optional)
                        if (hasCarton)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(fmt(totBalance / boxpiece!),
                                style: boldWhite(7),
                                textAlign: pw.TextAlign.right),
                          ),
                        // Balance
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(fmt(totBalance),
                              style: boldWhite(7),
                              textAlign: pw.TextAlign.right),
                        ),
                        // Branch
                        pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('', style: boldWhite(7))),
                      ],
                    ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.blueGrey200, thickness: 0.4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Confidential \u002D $companyName',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey400)),
                  pw.Text('Stock Movement | $itemName',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey400)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'stock_movement_${itemName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
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