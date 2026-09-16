import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../widgets/printStockReportPdf.dart';

class StockReportModal {
  static void show({
    required BuildContext context,
    required String branchId,
    required String branchName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: _StockReportModalContent(
          branchId: branchId,
          branchName: branchName,
        ),
      ),
    );
  }
}

class _StockReportModalContent extends StatefulWidget {
  final String branchId;
  final String branchName;

  const _StockReportModalContent({
    required this.branchId,
    required this.branchName,
  });

  @override
  State<_StockReportModalContent> createState() => _StockReportModalContentState();
}

class _StockReportModalContentState extends State<_StockReportModalContent> {
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
    Future.microtask(() async {
      if (!mounted) return;
      // Branch is fixed for this modal - always pass widget.branchId
      // so the fetch covers ALL items for this branch (no date filter yet).
      await context.read<Datafeed>().fetchstockreport(
        selectedBranch: widget.branchId,
      );
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _applyFilters() async {
    // Always keep selectedBranch: widget.branchId so this modal
    // never silently switches to "all branches" or another branch.
    await context.read<Datafeed>().fetchstockreport(
      selectedDate: _selectedDateRange,
      selectedBranch: widget.branchId,
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101624),
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
                textStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
              ),
            ),
            monthCellStyle: DateRangePickerMonthCellStyle(
              textStyle: const TextStyle(color: Colors.white),
              todayTextStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              weekendTextStyle: const TextStyle(color: Colors.white60),
              disabledDatesTextStyle: const TextStyle(color: Colors.white24),
            ),
            selectionColor: Colors.blueAccent,
            startRangeSelectionColor: Colors.blueAccent,
            endRangeSelectionColor: Colors.blueAccent,
            rangeSelectionColor: Colors.blueAccent.withOpacity(0.15),
            todayHighlightColor: Colors.blueAccent,
            selectionTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                ? PickerDateRange(_selectedDateRange!.start, _selectedDateRange!.end)
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() => _selectedDateRange = null);
              Navigator.pop(context);
              await _applyFilters();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  String _formatDateRange() {
    if (_selectedDateRange == null) return 'All dates';
    return '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - '
        '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Datafeed>();
    final stockreport = provider.filterstockreport();
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 900;

    return Container(
      width: screenSize.width * 0.95,
      height: screenSize.height * 0.90,
      decoration: BoxDecoration(
        color: const Color(0xFF101624),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1B263B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stock Report — ${widget.branchName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                  onPressed: _applyFilters,
                  tooltip: 'Refresh',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Filter bar
          Container(
            color: const Color(0xFF1B263B),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF22304A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          onChanged: (value) {
                            provider.updateSearch(value);
                            _searchQuery = value;
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search items...',
                            hintStyle: TextStyle(color: Colors.white38),
                            prefixIcon: Icon(Icons.search, size: 18, color: Colors.white38),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: _selectedDateRange != null
                              ? Border.all(color: Colors.blueAccent, width: 1.5)
                              : Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 18,
                              color: _selectedDateRange != null ? Colors.blueAccent : Colors.white38,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDateRange(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedDateRange != null ? Colors.blueAccent : Colors.white38,
                              ),
                            ),
                            if (_selectedDateRange != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _selectedDateRange = null);
                                  _applyFilters();
                                },
                                child: const Icon(Icons.close, size: 14, color: Colors.white38),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF415A77),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        printStockReportPdf(
                          reportData: provider.filterstockreport(),
                          companyName: provider.company,
                          branchName: widget.branchName,
                          dateRange:
                          '${DateFormat('d MMMM y').format(_selectedDateRange?.start ?? DateTime.now())} '
                              '- ${DateFormat('d MMMM y').format(_selectedDateRange?.end ?? DateTime.now())}',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: provider.isloadingsalesreport
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : stockreport.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('No stock items found', style: TextStyle(color: Colors.white38)),
                ],
              ),
            )
                : isLargeScreen
                ? _buildTable(stockreport)
                : _buildCardList(stockreport),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> stockreport) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          notificationPredicate: (n) => n.depth == 1,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.blueAccent.withOpacity(0.1)
                    : const Color(0xFF182232);
              }),
              columnSpacing: 24,
              headingTextStyle: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Opening')),
                DataColumn(label: Text('Stock In')),
                DataColumn(label: Text('Sales')),
                DataColumn(label: Text('Returns')),
                DataColumn(label: Text('Damages')),
                DataColumn(label: Text('Balance')),
                DataColumn(label: Text('Carton')),
              ],
              rows: stockreport.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;

                final balanceCd = (item['balance_cd'] ?? 0).toDouble();
                final boxPiece = double.tryParse(item['cartonqty_bal'].toString()) ?? 1;
                final cartonQtyBal = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(item['item']?.toString() ?? '')),
                  DataCell(Text('${item['opening_stock'] ?? 0}')),
                  DataCell(Text('${item['newstock'] ?? 0}')),
                  DataCell(Text('${item['sales_qty'] ?? 0}')),
                  DataCell(Text('${item['sale_returns'] ?? 0}')),
                  DataCell(Text('${item['damages'] ?? 0}')),
                  DataCell(Text('${item['balance_cd'] ?? 0}')),
                  DataCell(Text(cartonQtyBal.toStringAsFixed(1))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardList(List<Map<String, dynamic>> stockreport) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: stockreport.length,
      itemBuilder: (context, index) {
        final item = stockreport[index];

        final balanceCd = (item['balance_cd'] ?? 0).toDouble();
        final boxPiece = double.tryParse(item['cartonqty_bal'].toString()) ?? 1;
        final cartonQtyBal = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF182232),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['item']?.toString() ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _stat('Opening', '${item['opening_stock'] ?? 0}'),
                  _stat('Stock In', '${item['newstock'] ?? 0}'),
                  _stat('Sales', '${item['sales_qty'] ?? 0}'),
                  _stat('Returns', '${item['sale_returns'] ?? 0}'),
                  _stat('Damages', '${item['damages'] ?? 0}'),
                  _stat('Balance', '${item['balance_cd'] ?? 0}', highlight: true),
                  _stat('Carton', cartonQtyBal.toStringAsFixed(1), highlight: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(
          value,
          style: TextStyle(
            color: highlight ? Colors.blueAccent : Colors.white,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}