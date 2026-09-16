import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class DamageReport extends StatefulWidget {
  const DamageReport({super.key});

  @override
  State<DamageReport> createState() => _DamageReportState();
}

class _DamageReportState extends State<DamageReport> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  // controllers for detail dialog
  late final ScrollController _dvController;
  late final ScrollController _dhController;

  @override
  void initState() {
    super.initState();
    _verticalController   = ScrollController();
    _horizontalController = ScrollController();
    _dvController         = ScrollController();
    _dhController         = ScrollController();

    Future.microtask(() {
      final feed = context.read<Datafeed>();
      feed.fetchBranches();
      feed.fetchDamageReport(
        selectedDate: selectedDate,
        selectedBranch: _selectedBranch,
      );
    });
  }

  @override
  void dispose() {
    selectedDate    = null;
    _selectedBranch = null;
    _verticalController.dispose();
    _horizontalController.dispose();
    _dvController.dispose();
    _dhController.dispose();
    super.dispose();
  }

  Widget _miniStat(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
          Text(value,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _summaryTile(BuildContext context, String title, double value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold)),
        Text('GHC ${value.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final isMobile = screenWidth < 600;
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final resultList = value.filteredDamageReport();

        final totals = value.filteredDamageTotals();
        final totalCost = totals['totalCost'] ?? 0.0;
        final totalSelling = totals['totalSelling'] ?? 0.0;
        final totalPieces = totals['totalPieces'] ?? 0.0;
        final totalGroups = resultList.length.toDouble();

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            title: Text('Damage Report',
                style: textTheme.titleMedium?.copyWith(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary)),
            centerTitle: true,
            actions: [
              ReusableDatePickerWidget(
                onDateSelected: (sel) {
                  setState(() => selectedDate = sel);
                  context.read<Datafeed>().fetchDamageReport(
                    selectedDate: selectedDate,
                    selectedBranch: _selectedBranch,
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.calendar_today_rounded, size: 22),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: screenWidth),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: colorScheme.onSurface.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          if (selectedDate != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 14,
                                    color: colorScheme.onSurface
                                        .withOpacity(0.4)),
                                const SizedBox(width: 6),
                                Text('Damage report for  ',
                                    style: textTheme.bodySmall?.copyWith(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6))),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: colorScheme.primary
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    '${DateFormat.yMMMd().format(selectedDate!.start)}'
                                        ' — '
                                        '${DateFormat.yMMMd().format(selectedDate!.end)}',
                                    style: textTheme.bodySmall?.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 600;

                              final searchField = Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.08)),
                                ),
                                child: TextFormField(
                                  onChanged: value.updateSearch,
                                  style: textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSurface),
                                  decoration: InputDecoration(
                                    hintText: 'Search damage item...',
                                    hintStyle: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6)),
                                    prefixIcon: Icon(Icons.search,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6)),
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                    border: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(8)),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              );

                              final datePickerBox = ReusableDatePickerWidget(
                                onDateSelected: (sel) {
                                  setState(() => selectedDate = sel);
                                  context.read<Datafeed>().fetchDamageReport(
                                    selectedDate: selectedDate,
                                    selectedBranch: _selectedBranch,
                                  );
                                },
                                child: Container(
                                  height: 42,
                                  width: isMobile ? double.infinity : null,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.08)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today_rounded,
                                          size: 16,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.6)),
                                      const SizedBox(width: 7),
                                      Text('Pick date',
                                          style: textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.6),
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );

                              final branchDropdown = SizedBox(
                                width: isMobile ? double.infinity : null,
                                height: 42,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _selectedBranch ?? '',
                                  dropdownColor: theme.colorScheme.surface,
                                  style: textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSurface),
                                  decoration: InputDecoration(
                                    labelText: 'Select Branch',
                                    labelStyle: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.7)),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: colorScheme.onSurface
                                              .withOpacity(0.24)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: colorScheme.primary),
                                    ),
                                    fillColor: theme.colorScheme.surface,
                                    filled: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                        value: '',
                                        child: Text('All Branches')),
                                    ...value.branches.map((b) =>
                                        DropdownMenuItem<String>(
                                          value: b.id,
                                          child: Text(b.branchname),
                                        )),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedBranch = (val == null ||
                                          val.isEmpty)
                                          ? null
                                          : val;
                                    });
                                    value.fetchDamageReport(
                                      selectedDate: selectedDate,
                                      selectedBranch: _selectedBranch,
                                    );
                                  },
                                ),
                              );

                              final printButton = ElevatedButton.icon(
                                icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                    size: 18),
                                label: Text('Print/Download',
                                    style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onPrimary)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5)),
                                ),
                                onPressed: () => _printDamageSummary(
                                  resultList,
                                  totals,
                                  context.read<Datafeed>().company,
                                ),
                              );

                              if (isMobile) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    searchField,
                                    const SizedBox(height: 10),
                                    datePickerBox,
                                    const SizedBox(height: 10),
                                    branchDropdown,
                                    const SizedBox(height: 10),
                                    printButton,
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: searchField),
                                      const SizedBox(width: 10),
                                      datePickerBox,
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(Icons.storefront_rounded,
                                          size: 18,
                                          color: colorScheme.onSurface.withOpacity(0.35)),
                                      const SizedBox(width: 8),
                                      Expanded(child: branchDropdown),
                                      const SizedBox(width: 8),
                                      printButton,
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    Expanded(
                      child: value.isLoadingDamageReport
                          ? Center(
                          child: CircularProgressIndicator(
                              color: colorScheme.primary))
                          : resultList.isEmpty
                          ? Center(
                          child: Text('No damage items found',
                              style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.72))))
                          : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop =
                              constraints.maxWidth > 600;

                          if (isDesktop) {

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                const widths = [32, 200, 90, 100, 100, 90];
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
                                    thumbColor: MaterialStateProperty.all(colorScheme.primary.withOpacity(0.9)),
                                    trackColor: MaterialStateProperty.all(theme.colorScheme.surfaceVariant),
                                    trackBorderColor: MaterialStateProperty.all(theme.colorScheme.surface),
                                    thickness: MaterialStateProperty.all(10),
                                    radius: const Radius.circular(8),
                                  ),
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
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Container(
                                              color: theme.colorScheme.surfaceVariant,
                                              child: rowOf([
                                                Text('#', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                Text('Item', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                Text('Pieces', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                Text('Cost', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                Text('Selling', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                Text('Records', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                              ]),
                                            ),
                                            Divider(height: 0.5, thickness: 0.5, color: theme.colorScheme.outline.withOpacity(0.1)),
                                            Expanded(
                                              child: Scrollbar(
                                                controller: _verticalController,
                                                thumbVisibility: true,
                                                trackVisibility: true,
                                                child: ListView.builder(
                                                  controller: _verticalController,
                                                  itemCount: resultList.length + 1,
                                                  itemBuilder: (context, index) {
                                                    if (index == resultList.length) {
                                                      // Grand Total row
                                                      return rowOf(
                                                        [
                                                          const Text(''),
                                                          Text('Grand Total',
                                                              style: textTheme.bodyMedium?.copyWith(
                                                                  color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                          Text(totalPieces.toStringAsFixed(0),
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                          Text(totalCost.toStringAsFixed(2),
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                          Text(totalSelling.toStringAsFixed(2),
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                          Text(totalGroups.toStringAsFixed(0),
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                        ],
                                                        color: colorScheme.surfaceVariant,
                                                      );
                                                    }

                                                    final row = resultList[index];

                                                    return InkWell(
                                                      onTap: () => _showDamageItemDetail(
                                                        context,
                                                        itemKey: row['itemKey']?.toString() ??
                                                            row['itemId']?.toString() ??
                                                            row['itemName']?.toString().toLowerCase() ??
                                                            '',
                                                        itemName: row['itemName']?.toString() ?? '',
                                                      ),
                                                      child: rowOf(
                                                        [
                                                          Text('${index + 1}',
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                          Text(row['itemName'] ?? '',
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                          Text(_toDouble(row['totalPieces']).toStringAsFixed(0),
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                          Text(_toDouble(row['totalCost']).toStringAsFixed(2),
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                          Text(_toDouble(row['totalSelling']).toStringAsFixed(2),
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                          Text(_toInt(row['detailCount']).toString(),
                                                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                                                        ],
                                                        color: theme.colorScheme.surface,
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

                          // mobile
                          return ListView.separated(
                            itemCount: resultList.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final row = resultList[i];
                              return InkWell(
                                onTap: () => _showDamageItemDetail(
                                  context,
                                  itemKey: row['itemKey']?.toString() ??
                                      row['itemId']?.toString() ??
                                      row['itemName']?.toString().toLowerCase() ?? '',
                                  itemName: row['itemName']?.toString() ?? '',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius:
                                    BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          row['itemName'] ?? '',
                                          style: textTheme.titleMedium?.copyWith(
                                              color:Colors.white,
                                              fontWeight:
                                              FontWeight.bold,
                                              fontSize: 15)),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          _miniStat(context,
                                              'Pieces',
                                              _toDouble(row['totalPieces']).toStringAsFixed(0)),
                                          _miniStat(context,
                                              'Cost',
                                              _toDouble(row['totalCost']).toStringAsFixed(2)),
                                          _miniStat(context,
                                              'Selling',
                                              _toDouble(row['totalSelling']).toStringAsFixed(2)),
                                          _miniStat(context,
                                              'Records',
                                              _toInt(row['detailCount']).toString()),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
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

  // ── supplier detail dialog
  Future<void> _showSupplierDetail(
      BuildContext context, {
        required String supplierName,
        required String supplierId,
      }) async {
    final provider = Provider.of<Datafeed>(context, listen: false);

    // fire fetch — don't await here, dialog shows loading state via Consumer
    provider.fetchSupplierTransactions(
      supplierId: supplierId,
      selectedDate: selectedDate,
      selectedBranch: _selectedBranch,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<Datafeed>(
          builder: (context, prov, _) {
            final isLoading = prov.isLoadingSupplierTransactions;
            final transactions = prov.supplierTransactions;

            double gross = 0, net = 0, discount = 0, tax = 0;
            int purchases = 0, returns = 0;
            for (final t in transactions) {
              final isReturn = t['purchasereturntrue'] == true;
              gross    += (t['gross']    as num?)?.toDouble() ?? 0;
              net      += (t['netval']   as num?)?.toDouble() ?? 0;
              discount += (t['discount'] as num?)?.toDouble() ?? 0;
              tax      += (t['tax']      as num?)?.toDouble() ?? 0;
              if (isReturn) { returns++; } else { purchases++; }
            }

            final dialogTheme = Theme.of(context);
            return AlertDialog(
              backgroundColor: dialogTheme.cardColor,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$supplierName — Transactions',
                          style: dialogTheme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: dialogTheme.colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: dialogTheme.colorScheme.onSurface),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  if (!isLoading) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip(context, 'Purchases', '$purchases'),
                          _chip(context, 'Returns', '$returns'),
                          _chip(context, 'Gross', 'GHC ${gross.toStringAsFixed(2)}'),
                          _chip(context, 'Discount', 'GHC ${discount.toStringAsFixed(2)}'),
                          _chip(context, 'Tax', 'GHC ${tax.toStringAsFixed(2)}'),
                          _chip(context, 'Net Value', 'GHC ${net.toStringAsFixed(2)}',
                              highlight: true),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: isLoading
                    ? Center(
                    child: CircularProgressIndicator(color: dialogTheme.colorScheme.primary))
                    : transactions.isEmpty
                    ? Center(
                    child: Text('No transactions',
                        style: dialogTheme.textTheme.bodyMedium
                            ?.copyWith(color: dialogTheme.colorScheme.onSurface.withOpacity(0.72))))
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    if (isMobile) {
                      return ListView.builder(
                        controller: _dvController,
                        padding: const EdgeInsets.all(4),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final t = transactions[index];
                          final isReturn = t['purchasereturntrue'] == true;
                          final itemCount = (t['items'] as List?)?.length ?? 0;
                          final badgeColor =
                          isReturn ? dialogTheme.colorScheme.error : dialogTheme.colorScheme.secondary;

                          Widget chip(String label, String value) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: dialogTheme.colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$label: $value',
                                style: dialogTheme.textTheme.bodySmall
                                    ?.copyWith(color: dialogTheme.colorScheme.onSurface),
                              ),
                            );
                          }

                          return Card(
                            color: dialogTheme.colorScheme.surface,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isReturn
                                    ? dialogTheme.colorScheme.error.withOpacity(0.3)
                                    : dialogTheme.colorScheme.outline.withOpacity(0.2),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _showTransactionItems(context, t),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('#${index + 1}',
                                            style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                                color: dialogTheme.colorScheme.onSurface,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            t['invoice'] ?? '-',
                                            style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                                color: dialogTheme.colorScheme.onSurface,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: badgeColor.withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            isReturn ? 'Return' : (t['purchasetype'] ?? 'Purchase'),
                                            style: TextStyle(
                                                fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${t['date'] ?? '-'}  •  ${t['branchname'] ?? '-'}  •  ${t['createdby'] ?? '-'}',
                                      style: dialogTheme.textTheme.bodySmall?.copyWith(
                                          color: dialogTheme.colorScheme.onSurface.withOpacity(0.7)),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        chip('Waybill', t['waybill'] ?? '-'),
                                        chip('Gross', ((t['gross'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)),
                                        chip('Discount',
                                            ((t['discount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)),
                                        chip('Tax', ((t['tax'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)),
                                        chip('Items', '$itemCount'),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'Net: ${((t['netval'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.primary, fontWeight: FontWeight.bold),
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

                    // Desktop
                    const widths = [32, 90, 100, 100, 90, 110, 100, 90, 90, 80, 90, 90];
                    const gap = 16.0;
                    final double contentWidth =
                        widths.reduce((a, b) => a + b) + (widths.length - 1) * gap + 32;
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
                      data: ScrollbarThemeData(
                        thumbColor: MaterialStateProperty.all(
                            dialogTheme.colorScheme.primary.withOpacity(0.9)),
                        trackColor:
                        MaterialStateProperty.all(dialogTheme.colorScheme.surfaceVariant),
                        trackBorderColor:
                        MaterialStateProperty.all(dialogTheme.colorScheme.surface),
                        thickness: MaterialStateProperty.all(10),
                        radius: const Radius.circular(8),
                      ),
                      child: Scrollbar(
                        controller: _dhController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        notificationPredicate: (n) => n.depth == 0,
                        child: SingleChildScrollView(
                          controller: _dhController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  color: dialogTheme.colorScheme.surfaceVariant,
                                  child: rowOf([
                                    Text('#',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Date',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Invoice',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Waybill',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Type',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Branch',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Staff',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Gross',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Discount',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Tax',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Net',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                    Text('Items',
                                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                            color: dialogTheme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                                Divider(
                                    height: 0.5,
                                    thickness: 0.5,
                                    color: dialogTheme.colorScheme.outline.withOpacity(0.1)),
                                Expanded(
                                  child: Scrollbar(
                                    controller: _dvController,
                                    thumbVisibility: true,
                                    trackVisibility: true,
                                    child: ListView.builder(
                                      controller: _dvController,
                                      itemCount: transactions.length,
                                      itemBuilder: (context, index) {
                                        final t = transactions[index];
                                        final isReturn = t['purchasereturntrue'] == true;
                                        final itemCount = (t['items'] as List?)?.length ?? 0;
                                        final badgeColor = isReturn
                                            ? dialogTheme.colorScheme.error
                                            : dialogTheme.colorScheme.secondary;

                                        return InkWell(
                                          onTap: () => _showTransactionItems(context, t),
                                          child: rowOf(
                                            [
                                              Text('${index + 1}',
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text(t['date'] ?? '-',
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text(t['invoice'] ?? '-',
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text(t['waybill'] ?? '-',
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Container(
                                                padding:
                                                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: badgeColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: badgeColor.withOpacity(0.5)),
                                                ),
                                                child: Text(
                                                  isReturn ? 'Return' : (t['purchasetype'] ?? 'Purchase'),
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: badgeColor),
                                                ),
                                              ),
                                              Text(t['branchname'] ?? '-',
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text(t['createdby'] ?? '-',
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text(((t['gross'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text(
                                                  ((t['discount'] as num?)?.toDouble() ?? 0)
                                                      .toStringAsFixed(2),
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text(((t['tax'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text(
                                                  ((t['netval'] as num?)?.toDouble() ?? 0)
                                                      .toStringAsFixed(2),
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                              Text('$itemCount items',
                                                  style: dialogTheme.textTheme.bodyMedium
                                                      ?.copyWith(color: dialogTheme.colorScheme.onSurface)),
                                            ],
                                            color: isReturn
                                                ? dialogTheme.colorScheme.error.withOpacity(0.08)
                                                : dialogTheme.colorScheme.surface,
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
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => _printSupplierDetail(
                        transactions, supplierName, prov.company),
                    child: Text('Print / Download',
                        style: dialogTheme.textTheme.bodyMedium?.copyWith(
                            color: dialogTheme.colorScheme.onSurfaceVariant)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Close',
                      style: dialogTheme.textTheme.bodyMedium?.copyWith(
                          color: dialogTheme.colorScheme.onSurfaceVariant)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── items drill-down dialog
  void _showTransactionItems(
      BuildContext context, Map<String, dynamic> t) {
    final items =
        (t['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isReturn = t['purchasereturntrue'] == true;
    final dialogTheme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogTheme.cardColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${t['invoice'] ?? 'Invoice'} — Items',
              style: dialogTheme.textTheme.titleMedium?.copyWith(
                  color: dialogTheme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  color: dialogTheme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: items.isEmpty
              ? Text('No items',
              style: dialogTheme.textTheme.bodyMedium?.copyWith(
                  color: dialogTheme.colorScheme.onSurface
                      .withOpacity(0.72)))
              : SingleChildScrollView(
            child: DataTable(
              columnSpacing: 16,
              headingRowColor: MaterialStateProperty.all(
                  dialogTheme.colorScheme.surfaceVariant),
              dataRowColor: MaterialStateProperty.all(
                  dialogTheme.colorScheme.surface),
              headingTextStyle: dialogTheme.textTheme.bodyMedium?.copyWith(
                  color: dialogTheme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold),
              dataTextStyle:
              dialogTheme.textTheme.bodyMedium?.copyWith(
                  color: dialogTheme.colorScheme.onSurface),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Mode')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Pieces')),
                DataColumn(label: Text('Price')),
                DataColumn(label: Text('Total')),
              ],
              rows: items.asMap().entries.map((e) {
                final i    = e.key;
                final item = e.value;
                return DataRow(
                  color: isReturn
                      ? MaterialStateProperty.all(
                      dialogTheme.colorScheme.error.withOpacity(0.06))
                      : null,
                  cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(SizedBox(
                      width: 160,
                      child: Text(
                        item['item']?.toString() ?? '-',
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                    DataCell(Text(
                        item['stockingmode']?.toString() ?? '-')),
                    DataCell(Text(
                        item['quantity']?.toString() ?? '-')),
                    DataCell(Text(
                        item['pieces']?.toString() ?? '-')),
                    DataCell(Text(
                        item['price']?.toString() ?? '-')),
                    DataCell(Text(
                        item['total']?.toString() ?? '-')),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _printTransactionItems(
              items,
              t,
              isReturn,
              Provider.of<Datafeed>(context, listen: false).company,
            ),
            child: Text('Print / Download',
                style: dialogTheme.textTheme.bodyMedium?.copyWith(
                    color: dialogTheme.colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: dialogTheme.textTheme.bodyMedium?.copyWith(
                    color: dialogTheme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  // ── chip helper
  Widget _chip(BuildContext context, String label, String value,
      {bool highlight = false}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? theme.colorScheme.error.withOpacity(0.5)
              : theme.colorScheme.onSurface.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: highlight
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatDamageDate(dynamic value) {
    if (value == null) return '-';
    if (value is DateTime) return DateFormat.yMd().add_jm().format(value);
    if (value is Timestamp) {
      return DateFormat.yMd().add_jm().format(value.toDate());
    }
    return value.toString();
  }

  Future<void> _showDamageItemDetail(
      BuildContext context, {
        required String itemKey,
        required String itemName,
      }) async {
    final provider = Provider.of<Datafeed>(context, listen: false);
    provider.fetchDamageItemDetails(
      itemKey: itemKey,
      selectedDate: selectedDate,
      selectedBranch: _selectedBranch,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<Datafeed>(
          builder: (context, prov, _) {
            final isLoading = prov.isLoadingDamageDetails;
            final details = prov.damageReportDetails;

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Damage details • $itemName',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary))
                    : details.isEmpty
                        ? Center(
                            child: Text('No damage details found',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.72))))
                        : Scrollbar(
                            controller: _dvController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              controller: _dvController,
                              child: Scrollbar(
                                controller: _dhController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                notificationPredicate: (n) => n.depth == 0,
                                child: SingleChildScrollView(
                                  controller: _dhController,
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 16,
                                    headingRowColor:
                                        MaterialStateProperty.all(
                                            Theme.of(context)
                                                .colorScheme
                                                .surfaceVariant),
                                    dataRowColor: MaterialStateProperty.all(
                                        Theme.of(context)
                                            .colorScheme
                                            .surface),
                                    headingTextStyle: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontWeight: FontWeight.bold),
                                    dataTextStyle: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                    columns: const [
                                      DataColumn(label: Text('#')),
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Branch')),
                                      DataColumn(label: Text('Created By')),
                                      DataColumn(label: Text('Mode')),
                                      DataColumn(label: Text('Reason')),
                                      DataColumn(label: Text('Pieces')),
                                      DataColumn(label: Text('Cost')),
                                      DataColumn(label: Text('Selling')),
                                      DataColumn(label: Text('Reference')),
                                    ],
                                    rows: details.asMap().entries.map((e) {
                                      final i = e.key;
                                      final row = e.value;
                                      return DataRow(
                                        cells: [
                                          DataCell(Text('${i + 1}')),
                                          DataCell(Text(
                                              _formatDamageDate(row['createdAt']))),
                                          DataCell(Text(row['branchName'] ?? '-')),
                                          DataCell(Text(row['createdBy'] ?? '-')),
                                          DataCell(Text(row['mode'] ?? '-')),
                                          DataCell(Text(row['reason'] ?? '-')),
                                          DataCell(Text(_toDouble(row['totalPieces'])
                                              .toStringAsFixed(0))),
                                          DataCell(Text(_toDouble(row['cost'])
                                              .toStringAsFixed(2))),
                                          DataCell(Text(_toDouble(row['selling'])
                                              .toStringAsFixed(2))),
                                          DataCell(Text(row['reference'] ?? '-')),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => _printDamageItemDetails(
                      details,
                      itemName,
                      Provider.of<Datafeed>(context, listen: false).company,
                    ),
                    child: Text('Print / Download',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Close',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _printDamageSummary(
      List<Map<String, dynamic>> rows,
      Map<String, double> totals,
      String company,
      ) async {
    final pdf = pw.Document(title: 'Damage Item Report');
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    pw.Widget cell(String text,
        {bool header = false,
          bool bold = false,
          bool right = false,
          PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: (header || bold) ? boldFont : baseFont,
            fontSize: 8,
            color: header ? PdfColors.white : (color ?? PdfColors.grey800),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DAMAGE ITEM REPORT',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 18, color: PdfColors.blue900)),
                    pw.Text(company,
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 10,
                            color: PdfColors.grey600)),
                    if (selectedDate != null)
                      pw.Text(
                        'Period: ${DateFormat('d MMM y').format(selectedDate!.start)}'
                            ' – ${DateFormat('d MMM y').format(selectedDate!.end)}',
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.grey600),
                      ),
                  ],
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: PdfColors.blue900),
            pw.SizedBox(height: 6),
          ],
        ),
        build: (_) => [
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.0),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                children: [
                  cell('#', header: true),
                  cell('ITEM', header: true),
                  cell('PIECES', header: true, right: true),
                  cell('COST', header: true, right: true),
                  cell('SELLING', header: true, right: true),
                  cell('RECORDS', header: true, right: true),
                ],
              ),
              ...rows.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                final bg = i.isEven ? PdfColors.grey200 : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${i + 1}'),
                    cell(row['itemName']?.toString() ?? ''),
                    cell(_toDouble(row['totalPieces']).toStringAsFixed(0), right: true),
                    cell(_toDouble(row['totalCost']).toStringAsFixed(2), right: true),
                    cell(_toDouble(row['totalSelling']).toStringAsFixed(2), right: true),
                    cell(_toInt(row['detailCount']).toString(), right: true),
                  ],
                );
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                children: [
                  cell('', header: true),
                  cell('TOTAL', header: true),
                  cell(totals['totalPieces']?.toStringAsFixed(0) ?? '0', header: true, right: true),
                  cell(totals['totalCost']?.toStringAsFixed(2) ?? '0.00', header: true, right: true),
                  cell(totals['totalSelling']?.toStringAsFixed(2) ?? '0.00', header: true, right: true),
                  cell(totals['totalCount']?.toStringAsFixed(0) ?? '0', header: true, right: true),
                ],
              ),
            ],
          ),
        ],
        footer: (ctx) => pw.Column(children: [
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
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ]),
      ),
    );

    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  Future<void> _printDamageItemDetails(
      List<Map<String, dynamic>> details,
      String itemName,
      String company,
      ) async {
    final pdf = pw.Document(title: '$itemName Damage Details');
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    pw.Widget cell(String text,
        {bool header = false,
          bool bold = false,
          bool right = false,
          PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: (header || bold) ? boldFont : baseFont,
            fontSize: 8,
            color: header ? PdfColors.white : (color ?? PdfColors.grey800),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$itemName Damage Details',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 18, color: PdfColors.blue900)),
                    pw.Text(company,
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 10,
                            color: PdfColors.grey600)),
                  ],
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: PdfColors.blue900),
            pw.SizedBox(height: 6),
          ],
        ),
        build: (_) => [
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.0),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(1.2),
              6: const pw.FlexColumnWidth(0.8),
              7: const pw.FlexColumnWidth(0.8),
              8: const pw.FlexColumnWidth(0.8),
              9: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                children: [
                  cell('#', header: true),
                  cell('DATE', header: true),
                  cell('BRANCH', header: true),
                  cell('CREATED BY', header: true),
                  cell('MODE', header: true),
                  cell('REASON', header: true),
                  cell('PIECES', header: true, right: true),
                  cell('COST', header: true, right: true),
                  cell('SELLING', header: true, right: true),
                  cell('REFERENCE', header: true),
                ],
              ),
              ...details.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                final bg = i.isEven ? PdfColors.grey200 : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${i + 1}'),
                    cell(_formatDamageDate(row['createdAt'])),
                    cell(row['branchName'] ?? '-'),
                    cell(row['createdBy'] ?? '-'),
                    cell(row['mode'] ?? '-'),
                    cell(row['reason'] ?? '-'),
                    cell(_toDouble(row['totalPieces']).toStringAsFixed(0), right: true),
                    cell(_toDouble(row['cost']).toStringAsFixed(2), right: true),
                    cell(_toDouble(row['selling']).toStringAsFixed(2), right: true),
                    cell(row['reference'] ?? '-'),
                  ],
                );
              }),
            ],
          ),
        ],
        footer: (ctx) => pw.Column(children: [
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
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ]),
      ),
    );

    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  // ── PDF: summary
  Future<void> _printSupplierSummary(
      List<Map<String, dynamic>> rows,
      Map<String, double> totals,
      String company,
      ) async {
    final pdf      = pw.Document(title: 'Supplier Report');
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    const headerBg = PdfColor.fromInt(0xFF1B263B);
    const rowEven  = PdfColor.fromInt(0xFFF4F6FA);
    const accent   = PdfColor.fromInt(0xFF415A77);

    pw.Widget cell(String text,
        {bool header = false,
          bool bold = false,
          bool right = false,
          PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font: (header || bold) ? boldFont : baseFont,
              fontSize: 8,
              color: header ? PdfColors.white : (color ?? PdfColors.grey800),
            ),
          ),
        );

    double _d(dynamic v) =>
        v == null ? 0.0 : (v as num).toDouble();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SUPPLIER REPORT',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 18, color: accent)),
                    pw.Text(company,
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 10,
                            color: PdfColors.grey600)),
                    if (selectedDate != null)
                      pw.Text(
                        'Period: ${DateFormat('d MMM y').format(selectedDate!.start)}'
                            ' – ${DateFormat('d MMM y').format(selectedDate!.end)}',
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.grey600),
                      ),
                  ],
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: accent),
            pw.SizedBox(height: 6),
          ],
        ),
        build: (_) => [
          pw.Table(
            // 11 columns — matches UI exactly:
            // #, Supplier, Purchases, Cash, Credit, Opening Stock, Returns, Gross, Discount, Tax, Net Value
            columnWidths: {
              0:  const pw.FixedColumnWidth(22),   // #
              1:  const pw.FlexColumnWidth(2.5),   // Supplier
              2:  const pw.FlexColumnWidth(0.8),   // Purchases
              3:  const pw.FlexColumnWidth(1.1),   // Cash
              4:  const pw.FlexColumnWidth(1.1),   // Credit
              5:  const pw.FlexColumnWidth(1.1),   // Opening Stock
              6:  const pw.FlexColumnWidth(0.8),   // Returns
              7:  const pw.FlexColumnWidth(1.1),   // Gross
              8:  const pw.FlexColumnWidth(1.0),   // Discount
              9:  const pw.FlexColumnWidth(0.8),   // Tax
              10: const pw.FlexColumnWidth(1.1),   // Net Value
            },
            children: [
              // header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#',              header: true),
                  cell('SUPPLIER',       header: true),
                  cell('PURCHASES',      header: true, right: true),
                  cell('CASH',           header: true, right: true),
                  cell('CREDIT',         header: true, right: true),
                  cell('OPENING STOCK',  header: true, right: true),
                  cell('RETURNS',        header: true, right: true),
                  cell('GROSS',          header: true, right: true),
                  cell('DISCOUNT',       header: true, right: true),
                  cell('TAX',            header: true, right: true),
                  cell('NET VALUE',      header: true, right: true),
                ],
              ),

              // data rows
              ...rows.asMap().entries.map((e) {
                final i   = e.key;
                final row = e.value;
                final bg  = i.isEven ? rowEven : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${i + 1}'),
                    cell(row['supplierName']?.toString() ?? ''),
                    cell(_d(row['purchaseCount']).toStringAsFixed(0), right: true),
                    cell(_d(row['cashAmount']).toStringAsFixed(2),         right: true),
                    cell(_d(row['creditAmount']).toStringAsFixed(2),       right: true),
                    cell(_d(row['openingStockAmount']).toStringAsFixed(2), right: true),
                    cell(_d(row['returnCount']).toStringAsFixed(0),        right: true),
                    cell(_d(row['gross']).toStringAsFixed(2),              right: true),
                    cell(_d(row['discount']).toStringAsFixed(2),           right: true),
                    cell(_d(row['tax']).toStringAsFixed(2),                right: true),
                    cell(_d(row['net']).toStringAsFixed(2),  right: true, bold: true),
                  ],
                );
              }),

              // grand total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('',             header: true),
                  cell('GRAND TOTAL',  header: true),
                  cell((totals['totalCount']       ?? 0.0).toStringAsFixed(0), header: true, right: true),
                  cell((totals['totalCash']         ?? 0.0).toStringAsFixed(2), header: true, right: true),
                  cell((totals['totalCredit']       ?? 0.0).toStringAsFixed(2), header: true, right: true),
                  cell((totals['totalOpeningStock'] ?? 0.0).toStringAsFixed(2), header: true, right: true),
                  cell((totals['totalReturns']      ?? 0.0).toStringAsFixed(0), header: true, right: true),
                  cell((totals['totalGross']        ?? 0.0).toStringAsFixed(2), header: true, right: true),
                  cell((totals['totalDiscount']     ?? 0.0).toStringAsFixed(2), header: true, right: true),
                  cell((totals['totalTax']          ?? 0.0).toStringAsFixed(2), header: true, right: true),
                  cell((totals['totalNet']          ?? 0.0).toStringAsFixed(2), header: true, right: true),
                ],
              ),
            ],
          ),
        ],
        footer: (ctx) => pw.Column(children: [
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
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(
                    font: baseFont, fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ]),
      ),
    );

    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  // ── PDF: supplier detail
  Future<void> _printSupplierDetail(
      List<Map<String, dynamic>> transactions,
      String supplierName,
      String company,
      ) async {
    final pdf      = pw.Document(title: '$supplierName Transactions');
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    const headerBg  = PdfColor.fromInt(0xFF1B263B);
    const rowEven   = PdfColor.fromInt(0xFFF4F6FA);
    const returnBg  = PdfColor.fromInt(0x14FF5252);
    const accent    = PdfColor.fromInt(0xFF415A77);

    double totalGross = 0, totalNet = 0, totalDiscount = 0, totalTax = 0;
    for (final t in transactions) {
      totalGross    += (t['gross']    as num?)?.toDouble() ?? 0;
      totalNet      += (t['netval']   as num?)?.toDouble() ?? 0;
      totalDiscount += (t['discount'] as num?)?.toDouble() ?? 0;
      totalTax      += (t['tax']      as num?)?.toDouble() ?? 0;
    }

    pw.Widget cell(String text,
        {bool header = false,
          bool bold = false,
          bool right = false,
          PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 5, vertical: 6),
          child: pw.Text(text,
              textAlign:
              right ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(
                font: (header || bold) ? boldFont : baseFont,
                fontSize: 8,
                color: header
                    ? PdfColors.white
                    : (color ?? PdfColors.grey800),
              )),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(supplierName.toUpperCase(),
                        style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 16,
                            color: accent)),
                    pw.Text(company,
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 10,
                            color: PdfColors.grey600)),
                    pw.Text('Transaction History',
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.grey500)),
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
        build: (_) => [
          pw.Table(
            columnWidths: {
              0:  const pw.FixedColumnWidth(20),
              1:  const pw.FlexColumnWidth(1.2),
              2:  const pw.FlexColumnWidth(1.0),
              3:  const pw.FlexColumnWidth(1.4),
              4:  const pw.FlexColumnWidth(1.0),
              5:  const pw.FlexColumnWidth(1.4),
              6:  const pw.FlexColumnWidth(1.4),
              7:  const pw.FlexColumnWidth(1.0),
              8:  const pw.FlexColumnWidth(1.0),
              9:  const pw.FlexColumnWidth(0.7),
              10: const pw.FlexColumnWidth(1.0),
            },
            children: [
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#', header: true),
                  cell('DATE', header: true),
                  cell('INVOICE', header: true),
                  cell('WAYBILL', header: true),
                  cell('TYPE', header: true),
                  cell('BRANCH', header: true),
                  cell('STAFF', header: true),
                  cell('GROSS', header: true, right: true),
                  cell('DISCOUNT', header: true, right: true),
                  cell('TAX', header: true, right: true),
                  cell('NET', header: true, right: true),
                ],
              ),
              ...transactions.asMap().entries.map((e) {
                final i  = e.key;
                final t  = e.value;
                final isReturn = t['purchasereturntrue'] == true;
                final bg = isReturn
                    ? returnBg
                    : (i.isEven ? rowEven : PdfColors.white);
                final typeColor =
                isReturn ? PdfColors.red400 : PdfColors.green700;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${i + 1}'),
                    cell(t['date'] ?? '-'),
                    cell(t['invoice'] ?? '-'),
                    cell(t['waybill'] ?? '-'),
                    cell(
                        isReturn
                            ? 'Return'
                            : (t['purchasetype'] ?? 'Purchase'),
                        color: typeColor,
                        bold: true),
                    cell(t['branchname'] ?? '-'),
                    cell(t['createdby'] ?? '-'),
                    cell(
                        ((t['gross'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(2),
                        right: true),
                    cell(
                        ((t['discount'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(2),
                        right: true),
                    cell(
                        ((t['tax'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(2),
                        right: true),
                    cell(
                        ((t['netval'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(2),
                        right: true,
                        bold: true),
                  ],
                );
              }),
              // totals
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('', header: true),
                  cell('TOTAL', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell(totalGross.toStringAsFixed(2),
                      header: true, right: true),
                  cell(totalDiscount.toStringAsFixed(2),
                      header: true, right: true),
                  cell(totalTax.toStringAsFixed(2),
                      header: true, right: true),
                  cell(totalNet.toStringAsFixed(2),
                      header: true, right: true),
                ],
              ),
            ],
          ),
        ],
        footer: (ctx) => pw.Column(children: [
          pw.Divider(
              thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfColors.grey500),
              ),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 8,
                      color: PdfColors.grey500)),
            ],
          ),
        ]),
      ),
    );

    await Printing.layoutPdf(
        onLayout: (fmt) async => pdf.save());
  }

  Future<void> _printTransactionItems(
      List<Map<String, dynamic>> items,
      Map<String, dynamic> t,
      bool isReturn,
      String company,
      ) async {
    final pdf      = pw.Document(title: '${t['invoice'] ?? 'Invoice'} Items');
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    const headerBg = PdfColor.fromInt(0xFF1B263B);
    const rowEven  = PdfColor.fromInt(0xFFF4F6FA);
    const accent   = PdfColor.fromInt(0xFF415A77);

    double totalAmount = 0;
    for (final item in items) {
      totalAmount += (item['total'] as num?)?.toDouble() ?? 0;
    }

    pw.Widget cell(String text,
        {bool header = false,
          bool bold = false,
          bool right = false,
          PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 6, vertical: 7),
          child: pw.Text(text,
              textAlign:
              right ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(
                font: (header || bold) ? boldFont : baseFont,
                fontSize: 8,
                color: header
                    ? PdfColors.white
                    : (color ?? PdfColors.grey800),
              )),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${t['invoice'] ?? 'INVOICE'} — ITEMS',
                        style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 16,
                            color: accent)),
                    pw.Text(company,
                        style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 10,
                            color: PdfColors.grey600)),
                    pw.Text(
                      '${isReturn ? 'Return' : (t['purchasetype'] ?? 'Purchase')}'
                          '  •  ${t['date'] ?? '-'}'
                          '  •  Waybill: ${t['waybill'] ?? '-'}',
                      style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 9,
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
        build: (_) => [
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(3.0),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#', header: true),
                  cell('ITEM', header: true),
                  cell('MODE', header: true),
                  cell('QTY', header: true, right: true),
                  cell('PIECES', header: true, right: true),
                  cell('PRICE', header: true, right: true),
                  cell('TOTAL', header: true, right: true),
                ],
              ),
              ...items.asMap().entries.map((e) {
                final i    = e.key;
                final item = e.value;
                final bg   = i.isEven ? rowEven : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${i + 1}'),
                    cell(item['item']?.toString() ?? '-'),
                    cell(item['stockingmode']?.toString() ?? '-'),
                    cell(item['quantity']?.toString() ?? '-', right: true),
                    cell(item['pieces']?.toString() ?? '-', right: true),
                    cell(item['price']?.toString() ?? '-', right: true),
                    cell(item['total']?.toString() ?? '-', right: true, bold: true),
                  ],
                );
              }),
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('', header: true),
                  cell('TOTAL', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell(totalAmount.toStringAsFixed(2),
                      header: true, right: true),
                ],
              ),
            ],
          ),
        ],
        footer: (ctx) => pw.Column(children: [
          pw.Divider(
              thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment:
            pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfColors.grey500),
              ),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 8,
                      color: PdfColors.grey500)),
            ],
          ),
        ]),
      ),
    );

    await Printing.layoutPdf(
        onLayout: (fmt) async => pdf.save());
  }
}