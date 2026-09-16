
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class DebtorReport extends StatefulWidget {
  const DebtorReport({super.key});

  @override
  State<DebtorReport> createState() => _DebtorReportState();
}

class _DebtorReportState extends State<DebtorReport> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  String _searchQuery = '';

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;
  late final ScrollController _dvController;
  late final ScrollController _dhController;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
    _dvController = ScrollController();
    _dhController = ScrollController();

    final feed = context.read<Datafeed>();
    final initialBranch = (feed.accesslevel.toLowerCase() != 'super admin' && feed.branchid.isNotEmpty)
        ? feed.branchid
        : _selectedBranch;
    Future.microtask(() {
      feed.fetchBranches();
      feed.fetchDebtorReport(
        selectedBranch: initialBranch,
        selectedDate: selectedDate,
      );
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _dvController.dispose();
    _dhController.dispose();
    super.dispose();
  }

  Widget _summaryTile(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              )),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(right: 8, top: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Consumer<Datafeed>(
      builder: (context, feed, child) {
        final isRestrictedBranch =
            feed.accesslevel.toLowerCase() != 'super admin' && feed.branchid.isNotEmpty;
        final effectiveBranch = isRestrictedBranch ? feed.branchid : _selectedBranch;

        final branches = feed.branches;
        final summaryRows = feed.debtorReportRows;
        final filteredRows = _searchQuery.isEmpty
            ? summaryRows
            : summaryRows.where((row) {
          final branchName = (row['branchName'] ?? '').toString().toLowerCase();
          final customerName = (row['customerName'] ?? '').toString().toLowerCase();
          final customerId = (row['customerId'] ?? '').toString().toLowerCase();
          return branchName.contains(_searchQuery.toLowerCase()) ||
              customerName.contains(_searchQuery.toLowerCase()) ||
              customerId.contains(_searchQuery.toLowerCase());
        }).toList();

        final totalDebt = feed.totalDebtorCreditBalance;
        final totalPaid = feed.totalDebtorAmountPaid;
        final isLoading = feed.isLoadingDebtorReport;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            title: Text('Debtor Report',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                )),
            actions: [
              ReusableDatePickerWidget(
                onDateSelected: (range) {
                  setState(() => selectedDate = range);
                  feed.fetchDebtorReport(
                    selectedDate: range,
                    selectedBranch: effectiveBranch,
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.colorScheme.onSurface.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (selectedDate != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5)),
                                const SizedBox(width: 6),
                                Text('Debt payment range',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    )),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Text(
                                    '${DateFormat.yMMMd().format(selectedDate!.start)}'
                                        ' — '
                                        '${DateFormat.yMMMd().format(selectedDate!.end)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 600;

                              final uniqueBranches = <String, dynamic>{};
                              for (final b in branches) {
                                uniqueBranches[b.id] = b;
                              }

                              final branchDropdown = DropdownButtonFormField<String?>(
                                initialValue: effectiveBranch,
                                dropdownColor: const Color(0xFF22304A),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                isDense: true,
                                decoration: InputDecoration(
                                  labelText: 'Branch',
                                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.white12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF415A77)),
                                  ),
                                  fillColor: const Color(0xFF1B263B),
                                  filled: true,
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('All Branches')),
                                  ...uniqueBranches.values.map((b) => DropdownMenuItem<String?>(
                                        value: b.id,
                                        child: Text(b.branchname),
                                      )),
                                ],
                                onChanged: isRestrictedBranch
                                    ? null
                                    : (val) {
                                        setState(() => _selectedBranch = val);
                                        feed.fetchDebtorReport(
                                          selectedBranch: val,
                                          selectedDate: selectedDate,
                                        );
                                      },
                              );

                              final searchField = TextFormField(
                                onChanged: (value) => setState(() {
                                  _searchQuery = value;
                                }),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Search branch ...',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: const Color(0xFF1B263B),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.white12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF415A77)),
                                  ),
                                ),
                              );

                              final printButton = ElevatedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                label: Text('Print', style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                )),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _printSummary(
                                  filteredRows,
                                  totalDebt,
                                  totalPaid,
                                  feed.company,
                                ),
                              );

                              if (isMobile) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    branchDropdown,
                                    const SizedBox(height: 8),
                                    searchField,
                                    const SizedBox(height: 8),
                                    printButton,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(flex: 3, child: branchDropdown),
                                  const SizedBox(width: 10),
                                  Expanded(flex: 3, child: searchField),
                                  const SizedBox(width: 10),
                                  printButton,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobileSummary = constraints.maxWidth < 600;

                              final branchFilterLabel = effectiveBranch == null || effectiveBranch.isEmpty
                                  ? 'All'
                                  : (branches.firstWhere(
                                      (branch) => branch.id == effectiveBranch,
                                  orElse: () => BranchModel(id: '', branchname: effectiveBranch))
                                  .branchname);

                              if (isMobileSummary) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _summaryTile(context, 'Total Debt', 'GHC ${totalDebt.toStringAsFixed(2)}')),
                                        const SizedBox(width: 10),
                                        Expanded(child: _summaryTile(context, 'Total Paid', 'GHC ${totalPaid.toStringAsFixed(2)}')),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(child: _summaryTile(context, 'Debtors', '${filteredRows.length}')),
                                        const SizedBox(width: 10),
                                        Expanded(child: _summaryTile(context, 'Branch filter', branchFilterLabel)),
                                      ],
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: _summaryTile(context, 'Total Debt', 'GHC ${totalDebt.toStringAsFixed(2)}')),
                                  const SizedBox(width: 10),
                                  Expanded(child: _summaryTile(context, 'Total Paid', 'GHC ${totalPaid.toStringAsFixed(2)}')),
                                  const SizedBox(width: 10),
                                  Expanded(child: _summaryTile(context, 'Debtors', '${filteredRows.length}')),
                                  const SizedBox(width: 10),
                                  Expanded(child: _summaryTile(context, 'Branch filter', branchFilterLabel)),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isLoading
                          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                          : filteredRows.isEmpty
                          ? Center(
                          child: Text('No debtor records found',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7))))
                          : Align(
                        alignment: Alignment.topLeft,
                            child: LayoutBuilder(
                                                    builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth > 700;
                            if (isDesktop) {
                              // return Scrollbar(
                              //   controller: _verticalController,
                              //   thumbVisibility: true,
                              //   trackVisibility: true,
                              //   child: SingleChildScrollView(
                              //     controller: _verticalController,
                              //     child: Scrollbar(
                              //       controller: _horizontalController,
                              //       thumbVisibility: true,
                              //       trackVisibility: true,
                              //       notificationPredicate: (n) => n.depth == 1,
                              //       child: SingleChildScrollView(
                              //         controller: _horizontalController,
                              //         scrollDirection: Axis.horizontal,
                              //         child: DataTable(
                              //           showCheckboxColumn: false,
                              //           columnSpacing: 60,
                              //           headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceVariant),
                              //           dataRowColor: MaterialStateProperty.all(theme.colorScheme.surface),
                              //           headingTextStyle: theme.textTheme.bodyMedium?.copyWith(
                              //               color: theme.colorScheme.onSurface,
                              //               fontWeight: FontWeight.bold),
                              //           columns: const [
                              //             DataColumn(label: Text('#')),
                              //             DataColumn(label: Text('Customer')),
                              //             DataColumn(label: Text('Branch')),
                              //             DataColumn(label: Text('Total Debt')),
                              //             DataColumn(label: Text('Paid')),
                              //             DataColumn(label: Text('Credit Limit')),
                              //             DataColumn(label: Text('Balance')),
                              //           ],
                              //           rows: [
                              //             ...filteredRows.asMap().entries.map((entry) {
                              //               final index = entry.key;
                              //               final debtor = entry.value;
                              //               return DataRow(
                              //                 onSelectChanged: (_) => _showCustomerDetail(
                              //                   context,
                              //                   customerId: debtor['customerId']?.toString() ?? '',
                              //                   customerName: debtor['customerName']?.toString() ?? 'Customer',
                              //                   selectedBranch: effectiveBranch,
                              //                   contact: debtor['contact']?.toString(),
                              //                   creditLimit: debtor['creditLimit']?.toString(),
                              //                 ),
                              //                 cells: [
                              //                   DataCell(Text('${index + 1}')),
                              //                   DataCell(Text(debtor['customerName']?.toString() ?? '')),
                              //                   DataCell(Text(debtor['branchName']?.toString() ?? '')),
                              //                   DataCell(Text((debtor['creditBalance'] as double?)?.toStringAsFixed(2) ?? '0.00')),
                              //                   DataCell(Text((debtor['amountPaid'] as double?)?.toStringAsFixed(2) ?? '0.00')),
                              //                   DataCell(Text(debtor['creditLimit']?.toString() ?? '-')),
                              //                   DataCell(Text((debtor['balance'] as double?)?.toStringAsFixed(2) ?? '0.00')),
                              //                 ],
                              //               );
                              //             }),
                              //           ],
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              // );
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  const widths = [32, 160, 130, 100, 100, 100, 100];
                                  const gap = 60.0;
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
                                      thumbColor: MaterialStateProperty.all(theme.colorScheme.primary.withOpacity(0.9)),
                                      trackColor: MaterialStateProperty.all(theme.colorScheme.surfaceVariant),
                                      thickness: MaterialStateProperty.all(10),
                                      radius: const Radius.circular(8),
                                    ),
                                    child: Scrollbar(
                                      controller: _horizontalController,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      notificationPredicate: (n) => n.depth == 1,
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
                                                  Text('#', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                  Text('Customer', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                  Text('Branch', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                  Text('Total Debt', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                  Text('Paid', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                  Text('Credit Limit', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                                  Text('Balance', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
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
                                                    itemCount: filteredRows.length,
                                                    itemBuilder: (context, index) {
                                                      final debtor = filteredRows[index];

                                                      return InkWell(
                                                        onTap: () => _showCustomerDetail(
                                                          context,
                                                          customerId: debtor['customerId']?.toString() ?? '',
                                                          customerName: debtor['customerName']?.toString() ?? 'Customer',
                                                          selectedBranch: effectiveBranch,
                                                          contact: debtor['contact']?.toString(),
                                                          creditLimit: debtor['creditLimit']?.toString(),
                                                        ),
                                                        child: rowOf(
                                                          [
                                                            Text('${index + 1}',
                                                                style: TextStyle(color: theme.colorScheme.onSurface)),
                                                            Text(debtor['customerName']?.toString() ?? '',
                                                                style: TextStyle(color: theme.colorScheme.onSurface)),
                                                            Text(debtor['branchName']?.toString() ?? '',
                                                                style: TextStyle(color: theme.colorScheme.onSurface)),
                                                            Text((debtor['creditBalance'] as double?)?.toStringAsFixed(2) ?? '0.00',
                                                                style: TextStyle(color: theme.colorScheme.onSurface)),
                                                            Text((debtor['amountPaid'] as double?)?.toStringAsFixed(2) ?? '0.00',
                                                                style: TextStyle(color: theme.colorScheme.onSurface)),
                                                            Text(debtor['creditLimit']?.toString() ?? '-',
                                                                style: TextStyle(color: theme.colorScheme.onSurface)),
                                                            Text((debtor['balance'] as double?)?.toStringAsFixed(2) ?? '0.00',
                                                                style: TextStyle(color: theme.colorScheme.onSurface)),
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
                            return ListView.separated(
                              itemCount: filteredRows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final debtor = filteredRows[index];
                                return InkWell(
                                  onTap: () => _showCustomerDetail(
                                    context,
                                    customerId: debtor['customerId']?.toString() ?? '',
                                    customerName: debtor['customerName']?.toString() ?? 'Customer',
                                    selectedBranch: effectiveBranch,
                                    contact: debtor['contact']?.toString(),
                                    creditLimit: debtor['creditLimit']?.toString(),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(debtor['customerName']?.toString() ?? '',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            )),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          runSpacing: 8,
                                          children: [
                                            _chip(context, 'Branch', debtor['branchName']?.toString() ?? '-'),
                                            _chip(context, 'Total debt', 'GHC ${(debtor['creditBalance'] as double?)?.toStringAsFixed(2) ?? '0.00'}'),
                                            _chip(context, 'Paid', 'GHC ${(debtor['amountPaid'] as double?)?.toStringAsFixed(2) ?? '0.00'}'),
                                            _chip(context, 'Balance', 'GHC ${(debtor['balance'] as double?)?.toStringAsFixed(2) ?? '0.00'}'),
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

  Future<void> _showCustomerDetail(
      BuildContext context, {
        required String customerId,
        required String customerName,
        String? selectedBranch,
        String? contact,
        String? creditLimit,
      }) async {
    final provider = Provider.of<Datafeed>(context, listen: false);
    final normalizedBranch = selectedBranch?.trim().isEmpty == true ? null : selectedBranch;
    provider.fetchDebtPaymentTransactions(
      selectedDate: selectedDate,
      selectedBranch: normalizedBranch,
      customerId: customerId,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<Datafeed>(
          builder: (context, feed, _) {
            final isLoading = feed.isLoadingDebtPaymentTransactions;
            final transactions = feed.debtPaymentTransactions;
            final totalAmount = transactions.fold<double>(0.0, (sum, item) {
              final amount = item['amount'];
              if (amount is num) return sum + amount.toDouble();
              return sum + double.tryParse(amount?.toString() ?? '0')!;
            });

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$customerName — Debt Payments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              // content: SizedBox(
              //   width: double.maxFinite,
              //   height: MediaQuery.sizeOf(context).height * 0.72,
              //   child: isLoading
              //       ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
              //       : transactions.isEmpty
              //       ? Center(child: Text('No debt payments found', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72))))
              //       : Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Padding(
              //         padding: const EdgeInsets.only(bottom: 12),
              //         child: Wrap(
              //           spacing: 10,
              //           runSpacing: 8,
              //           children: [
              //             _chip(context, 'Transactions', '${transactions.length}'),
              //             _chip(context, 'Total amount', 'GHC ${totalAmount.toStringAsFixed(2)}'),
              //           ],
              //         ),
              //       ),
              //       Expanded(
              //         child: Scrollbar(
              //           controller: _dvController,
              //           thumbVisibility: true,
              //           trackVisibility: true,
              //           child: SingleChildScrollView(
              //             controller: _dvController,
              //             child: Scrollbar(
              //               controller: _dhController,
              //               thumbVisibility: true,
              //               trackVisibility: true,
              //               notificationPredicate: (n) => n.depth == 1,
              //               child: SingleChildScrollView(
              //                 controller: _dhController,
              //                 scrollDirection: Axis.horizontal,
              //                 child: DataTable(
              //                   showCheckboxColumn: false,
              //                   columnSpacing: 18,
              //                   headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
              //                   dataRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surface),
              //                   headingTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              //                       color: Theme.of(context).colorScheme.onSurface,
              //                       fontWeight: FontWeight.bold),
              //                   columns: const [
              //                     DataColumn(label: Text('#')),
              //                     DataColumn(label: Text('Date')),
              //                     DataColumn(label: Text('Customer')),
              //                     DataColumn(label: Text('Amount')),
              //                     DataColumn(label: Text('Payment')),
              //                     DataColumn(label: Text('Reference')),
              //                     DataColumn(label: Text('Staff')),
              //                   ],
              //                   rows: transactions.asMap().entries.map((entry) {
              //                     final idx = entry.key;
              //                     final tx = entry.value;
              //                     return DataRow(
              //                       cells: [
              //                         DataCell(Text('${idx + 1}')),
              //                         DataCell(Text(tx['date']?.toString() ?? '-')),
              //                         DataCell(Text(tx['customername']?.toString() ?? '-')),
              //                         DataCell(Text((tx['amount'] is num ? (tx['amount'] as num).toStringAsFixed(2) : double.tryParse(tx['amount']?.toString() ?? '0')?.toStringAsFixed(2)) ?? '0.00')),
              //                         DataCell(Text(tx['paymentmethod']?.toString() ?? '-')),
              //                         DataCell(Text(tx['reference']?.toString() ?? tx['id']?.toString() ?? '-')),
              //                         DataCell(Text(tx['createdby']?.toString() ?? tx['staff']?.toString() ?? '-')),
              //                       ],
              //                     );
              //                   }).toList(),
              //                 ),
              //               ),
              //             ),
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                    : transactions.isEmpty
                    ? Center(
                  child: Text(
                    'No debt payments found',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72)),
                  ),
                )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _chip(context, 'Transactions', '${transactions.length}'),
                              _chip(context, 'Total amount', 'GHC ${totalAmount.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: isMobile
                              ? ListView.builder(
                            controller: _dvController,
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              final amount = (tx['amount'] is num
                                  ? (tx['amount'] as num).toStringAsFixed(2)
                                  : double.tryParse(tx['amount']?.toString() ?? '0')?.toStringAsFixed(2)) ??
                                  '0.00';

                              return Card(
                                color: Theme.of(context).colorScheme.surface,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '#${index + 1}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              tx['customername']?.toString() ?? '-',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Text(
                                            'GHC $amount',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        tx['date']?.toString() ?? '-',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _chip(context, 'Payment', tx['paymentmethod']?.toString() ?? '-'),
                                          _chip(context, 'Reference',
                                              tx['reference']?.toString() ?? tx['id']?.toString() ?? '-'),
                                          _chip(context, 'Staff',
                                              tx['createdby']?.toString() ?? tx['staff']?.toString() ?? '-'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                              : LayoutBuilder(
                            builder: (context, tableConstraints) {
                              const widths = [32, 100, 150, 90, 110, 130, 110];
                              const gap = 18.0;
                              final double contentWidth = widths.reduce((a, b) => a + b) +
                                  (widths.length - 1) * gap +
                                  32;
                              final double tableWidth = tableConstraints.maxWidth > contentWidth
                                  ? tableConstraints.maxWidth
                                  : contentWidth;

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
                                      Theme.of(context).colorScheme.primary.withOpacity(0.9)),
                                  trackColor: MaterialStateProperty.all(
                                      Theme.of(context).colorScheme.surfaceVariant),
                                  thickness: MaterialStateProperty.all(10),
                                  radius: const Radius.circular(8),
                                ),
                                child: Scrollbar(
                                  controller: _dhController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  notificationPredicate: (n) => n.depth == 1,
                                  child: SingleChildScrollView(
                                    controller: _dhController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      height: tableConstraints.maxHeight.isFinite ? tableConstraints.maxHeight : null,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            color: Theme.of(context).colorScheme.surfaceVariant,
                                            child: rowOf([
                                              Text('#',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontWeight: FontWeight.bold)),
                                              Text('Date',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontWeight: FontWeight.bold)),
                                              Text('Customer',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontWeight: FontWeight.bold)),
                                              Text('Amount',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontWeight: FontWeight.bold)),
                                              Text('Payment',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontWeight: FontWeight.bold)),
                                              Text('Reference',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontWeight: FontWeight.bold)),
                                              Text('Staff',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontWeight: FontWeight.bold)),
                                            ]),
                                          ),
                                          Divider(
                                              height: 0.5,
                                              thickness: 0.5,
                                              color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
                                          Expanded(
                                            child: Scrollbar(
                                              controller: _dvController,
                                              thumbVisibility: true,
                                              trackVisibility: true,
                                              child: ListView.builder(
                                                controller: _dvController,
                                                itemCount: transactions.length,
                                                itemBuilder: (context, index) {
                                                  final tx = transactions[index];
                                                  final amount = (tx['amount'] is num
                                                      ? (tx['amount'] as num).toStringAsFixed(2)
                                                      : double.tryParse(tx['amount']?.toString() ?? '0')
                                                      ?.toStringAsFixed(2)) ??
                                                      '0.00';

                                                  return rowOf(
                                                    [
                                                      Text('${index + 1}',
                                                          style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface)),
                                                      Text(tx['date']?.toString() ?? '-',
                                                          style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface)),
                                                      Text(tx['customername']?.toString() ?? '-',
                                                          style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface)),
                                                      Text(amount,
                                                          style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface)),
                                                      Text(tx['paymentmethod']?.toString() ?? '-',
                                                          style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface)),
                                                      Text(
                                                          tx['reference']?.toString() ??
                                                              tx['id']?.toString() ??
                                                              '-',
                                                          style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface)),
                                                      Text(
                                                          tx['createdby']?.toString() ??
                                                              tx['staff']?.toString() ??
                                                              '-',
                                                          style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface)),
                                                    ],
                                                    color: Theme.of(context).colorScheme.surface,
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
                      ],
                    );
                  },
                ),
              ),
              actions: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text('Print / Download',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: transactions.isEmpty
                      ? null
                      : () => _printDetail(transactions, customerName, Provider.of<Datafeed>(context, listen: false).company,contact,creditLimit),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Close', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _printSummary(
      List<Map<String, dynamic>> rows,
      double totalDebt,
      double totalPaid,
      String company,
      ) async {
    final pdf = pw.Document(title: 'Debtor Report');
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    // Light theme professional colors
    const primaryBlue = PdfColor.fromInt(0xFF0052CC);
    const accentGreen = PdfColor.fromInt(0xFF27AE60);
    const accentRed = PdfColor.fromInt(0xFFE74C3C);
    const accentOrange = PdfColor.fromInt(0xFFF39C12);
    const lightBg = PdfColor.fromInt(0xFFF5F7FA);
    const borderGray = PdfColor.fromInt(0xFFE0E0E0);

    pw.Widget cell(String text,
        {bool header = false, bool bold = false, bool right = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font: (header || bold) ? boldFont : baseFont,
              fontSize: 9,
              color: header ? PdfColors.white : PdfColors.grey700,
            )),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (_) => [
          // Header
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(company.toUpperCase(), 
                  style: pw.TextStyle(font: boldFont, fontSize: 24, color: primaryBlue)),
              pw.Text('Debtors Report',
                  style: pw.TextStyle(font: baseFont, fontSize: 12, color: PdfColors.grey600)),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 2, color: primaryBlue),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600)),
                  if (selectedDate != null)
                    pw.Text(
                      'Period: ${DateFormat('d MMM y').format(selectedDate!.start)} — ${DateFormat('d MMM y').format(selectedDate!.end)}',
                      style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600),
                    ),
                ],
              ),
              pw.SizedBox(height: 16),
            ],
          ),

          // Financial Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: lightBg,
              border: pw.Border.all(color: borderGray),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('FINANCIAL SUMMARY',
                    style: pw.TextStyle(font: boldFont, fontSize: 12, color: primaryBlue)),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('Total Debt',
                            style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('GHS ${totalDebt.toStringAsFixed(2)}',
                            style: pw.TextStyle(font: boldFont, fontSize: 13, color: accentRed)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Amount Paid',
                            style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('GHS ${totalPaid.toStringAsFixed(2)}',
                            style: pw.TextStyle(font: boldFont, fontSize: 13, color: accentGreen)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Balance',
                            style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('GHS ${(totalDebt - totalPaid).toStringAsFixed(2)}',
                            style: pw.TextStyle(font: boldFont, fontSize: 13, color: accentOrange)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Total Debtors',
                            style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(rows.length.toString(),
                            style: pw.TextStyle(font: boldFont, fontSize: 13, color: primaryBlue)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Debtors Table
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primaryBlue),
                children: [
                  cell('#', header: true),
                  cell('CUSTOMER', header: true),
                  cell('BRANCH', header: true),
                  cell('DEBT', header: true, right: true),
                  cell('PAID', header: true, right: true),
                  cell('LIMIT', header: true, right: true),
                  cell('BALANCE', header: true, right: true),
                ],
              ),
              ...rows.asMap().entries.map((entry) {
                final index = entry.key;
                final debtor = entry.value;
                final bg = index.isEven ? PdfColors.white : lightBg;
                final balance = (debtor['balance'] as double?) ?? 0.0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    cell('${index + 1}'),
                    cell(debtor['customerName']?.toString() ?? ''),
                    cell(debtor['branchName']?.toString() ?? ''),
                    cell('GHS ${(debtor['creditBalance'] as double?)?.toStringAsFixed(2) ?? '0.00'}', right: true),
                    cell('GHS ${(debtor['amountPaid'] as double?)?.toStringAsFixed(2) ?? '0.00'}', right: true),
                    cell('${debtor['creditLimit']?.toString() ?? '-'}', right: true),
                    cell('GHS ${balance.toStringAsFixed(2)}', right: true),
                  ],
                );
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primaryBlue),
                children: [
                  cell('', header: true),
                  cell('GRAND TOTAL', header: true, bold: true),
                  cell('', header: true),
                  cell('GHS ${totalDebt.toStringAsFixed(2)}', header: true, right: true, bold: true),
                  cell('GHS ${totalPaid.toStringAsFixed(2)}', header: true, right: true, bold: true),
                  cell('', header: true),
                  cell('GHS ${(totalDebt - totalPaid).toStringAsFixed(2)}', header: true, right: true, bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('This is a computer-generated document. No signature required.',
              style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey400)),
        ],
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: borderGray),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _printDetail(
      List<Map<String, dynamic>> transactions,
      String customerName,
      String company,
      String? contact,
      String? creditLimit,
      ) async {
    final pdf = pw.Document(title: '$customerName Debt Payments');
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    // Light theme professional colors
    const primaryBlue = PdfColor.fromInt(0xFF0052CC);
    const accentGreen = PdfColor.fromInt(0xFF27AE60);
    const accentRed = PdfColor.fromInt(0xFFE74C3C);
    const accentOrange = PdfColor.fromInt(0xFFF39C12);
    const lightBg = PdfColor.fromInt(0xFFF5F7FA);
    const borderGray = PdfColor.fromInt(0xFFE0E0E0);

    pw.Widget cell(String text, {bool header = false, bool right = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font: header ? boldFont : baseFont,
              fontSize: 9,
              color: header ? PdfColors.white : PdfColors.grey700,
            )),
      );
    }

    // Calculate totals
    double totalAmount = 0;
    for (final tx in transactions) {
      final amount = tx['amount'];
      final amountVal = amount is num ? amount.toDouble() : double.tryParse(amount?.toString() ?? '0') ?? 0.0;
      totalAmount += amountVal;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (_) => [
          // Header
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(company.toUpperCase(), 
                  style: pw.TextStyle(font: boldFont, fontSize: 24, color: primaryBlue)),
              pw.Text('Debtor Statement of Account',
                  style: pw.TextStyle(font: baseFont, fontSize: 12, color: PdfColors.grey600)),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 2, color: primaryBlue),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 16),
            ],
          ),

          // Debtor Information Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderGray),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DEBTOR INFORMATION',
                    style: pw.TextStyle(font: boldFont, fontSize: 10, color: primaryBlue)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Name: $customerName',
                        style: pw.TextStyle(font: baseFont, fontSize: 10, color: PdfColors.grey800)),
                    pw.Text('Contact: $contact',
                        style: pw.TextStyle(font: baseFont, fontSize: 10, color: PdfColors.grey800)),
                    pw.Text('Credit Limit: $creditLimit',
                        style: pw.TextStyle(font: baseFont, fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Financial Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: lightBg,
              border: pw.Border.all(color: borderGray),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('FINANCIAL SUMMARY',
                    style: pw.TextStyle(font: boldFont, fontSize: 12, color: primaryBlue)),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('Amount Paid',
                            style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('GHS ${totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(font: boldFont, fontSize: 14, color: accentGreen)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Total Transactions',
                            style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(transactions.length.toString(),
                            style: pw.TextStyle(font: boldFont, fontSize: 14, color: primaryBlue)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Transactions Table
          if (transactions.isNotEmpty)
            pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1.4),
                6: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: primaryBlue),
                  children: [
                    cell('#', header: true),
                    cell('DATE', header: true),
                    cell('CUSTOMER', header: true),
                    cell('AMOUNT', header: true, right: true),
                    cell('METHOD', header: true),
                    cell('REFERENCE', header: true),
                    cell('STAFF', header: true),
                  ],
                ),
                ...transactions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final tx = entry.value;
                  final bg = idx.isEven ? PdfColors.white : lightBg;
                  final amount = tx['amount'];
                  final amountText = amount is num
                      ? 'GHS ${amount.toStringAsFixed(2)}'
                      : 'GHS ${double.tryParse(amount?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}';
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      cell('${idx + 1}'),
                      cell(tx['date']?.toString() ?? '-'),
                      cell(tx['customername']?.toString() ?? '-'),
                      cell(amountText, right: true),
                      cell(tx['paymentmethod']?.toString() ?? tx['account']?.toString() ?? '-'),
                      cell(tx['reference']?.toString() ?? tx['id']?.toString() ?? '-'),
                      cell(tx['createdby']?.toString() ?? tx['staff']?.toString() ?? '-'),
                    ],
                  );
                }),
              ],
            )
          else
            pw.Center(
              child: pw.Text('No payment records found',
                  style: pw.TextStyle(font: baseFont, fontSize: 11, color: PdfColors.grey600)),
            ),
          pw.SizedBox(height: 20),
          pw.Text('This is a computer-generated document. No signature required.',
              style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey400)),
        ],
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: borderGray),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  BranchModel branchEmpty() => BranchModel(id: '', branchname: 'All Branches');
}
