import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/salesmodel.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class PaymentReportPage extends StatefulWidget {
  const PaymentReportPage({super.key});

  @override
  State<PaymentReportPage> createState() => _PaymentReportPageState();
}

class _PaymentReportPageState extends State<PaymentReportPage> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  String searchQuery = '';

  final now = DateTime.now();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _mobileVerticalController = ScrollController();

  static const Color _scrollColor = Color(0xFF415A77);
  static const double _scrollThickness = 8.0;

  ScrollbarThemeData get _scrollbarTheme => ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(_scrollColor),
        trackColor: WidgetStateProperty.all(_scrollColor.withOpacity(0.15)),
        trackBorderColor:
            WidgetStateProperty.all(_scrollColor.withOpacity(0.30)),
        thickness: WidgetStateProperty.all(_scrollThickness),
        radius: const Radius.circular(6),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
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
      provider.fetchsalesview(
        selectedDate: selectedDate,
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

  bool _isPaymentSale(SalesModel sale) {
    final payments = sale.payments;
    return payments is List && payments.isNotEmpty;
  }

  double _sumPayments(SalesModel sale, List<String> methodKeys) {
    final payments = sale.payments;
    if (payments is! List) return 0.0;
    double sum = 0.0;
    for (final item in payments) {
      if (item is! Map<String, dynamic>) continue;
      final method = item['method']?.toString().toLowerCase() ?? '';
      final amount = _parseAmount(item['amount']);
      if (methodKeys.any((key) => method.contains(key))) {
        sum += amount;
      }
    }
    return sum;
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, double> _computeTotals(List<SalesModel> list) {
    double totalPaid = 0.0;
    double totalMomo = 0.0;
    double totalHubtel = 0.0;
    double totalCash = 0.0;
    double totalCard = 0.0;
    double totalBank = 0.0;
    double totalCheque = 0.0;
    double totalOther = 0.0;

    for (final sale in list) {
      final momoAmount = _sumPayments(sale, ['momo']) +
          _sumPayments(sale, ['mobile_money']);
      final hubtelAmount = _sumPayments(sale, ['hubtel']);
      final cashAmount = _sumPayments(sale, ['cash']);
      final cardAmount = _sumPayments(sale, ['card']);
      final bankAmount =
          _sumPayments(sale, ['bank_transfer', 'bank']);
      final chequeAmount = _sumPayments(sale, ['cheque', 'cheques']);
      final paidTotal = _parseAmount(sale.totalamount) != 0
          ? _sumPayments(sale, ['cash', 'momo', 'hubtel', 'card', 'bank_transfer', 'bank', 'cheque', 'cheques'])
          : 0.0;
      final otherAmount = paidTotal -
          (cashAmount + momoAmount + hubtelAmount + cardAmount + bankAmount + chequeAmount);

      totalPaid += paidTotal;
      totalMomo += momoAmount;
      totalHubtel += hubtelAmount;
      totalCash += cashAmount;
      totalCard += cardAmount;
      totalBank += bankAmount;
      totalCheque += chequeAmount;
      totalOther += otherAmount;
    }

    return {
      'totalPaid': totalPaid,
      'momo': totalMomo,
      'hubtel': totalHubtel,
      'cash': totalCash,
      'card': totalCard,
      'bank': totalBank,
      'cheque': totalCheque,
      'other': totalOther,
    };
  }

  List<SalesModel> _filteredSales(Datafeed value) {
    final sales = value.salesview.where(_isPaymentSale).toList();
    if (searchQuery.isEmpty) return sales;
    final q = searchQuery.toLowerCase();
    return sales.where((sale) {
      final matchFields = [
        sale.receiptNumber,
        sale.branchName,
        sale.customerName,
        sale.customerPhone,
        sale.transMode,
        sale.paymentStatus,
        sale.receiptby,
        sale.createdBy,
        sale.approvedby,
        sale.branchId,
      ];
      final topMatch = matchFields.any((field) =>
          field?.toLowerCase().contains(q) == true);
      if (topMatch) return true;
      final payments = sale.payments;
      if (payments is List) {
        return payments.any((item) {
          if (item is! Map<String, dynamic>) return false;
          final method = item['method']?.toString().toLowerCase() ?? '';
          final amount = item['amount']?.toString().toLowerCase() ?? '';
          final ref = item['reference']?.toString().toLowerCase() ?? '';
          return method.contains(q) || amount.contains(q) || ref.contains(q);
        });
      }
      return false;
    }).toList();
  }
  Map<String, List<SalesModel>> _groupByStaff(List<SalesModel> list) {
    final Map<String, List<SalesModel>> grouped = {};
    for (final sale in list) {
      final staffKey = sale.staffemail?.isNotEmpty == true
          ? sale.staffemail!
          : (sale.createdBy?.isNotEmpty == true ? sale.createdBy! : '');
      grouped.putIfAbsent(staffKey, () => []).add(sale);
    }
    return grouped;
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, _) {
        final isBranchRestricted = _isBranchRestricted(value);
        final effectiveStart = selectedDate?.start ?? now;
        final effectiveEnd = selectedDate?.end ?? now;
        final filteredSales = _filteredSales(value);
        final totals = _computeTotals(filteredSales);
        final nf = NumberFormat('#,##0.00');

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1B263B),
            elevation: 0,
            title: const Text(
              'Payment Report',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Colors.white,
                ),
                tooltip: 'Print / Download',
                onPressed: filteredSales.isEmpty
                    ? null
                    : () => _printReport(
                          filteredSales,
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
                  value.fetchsalesview(
                    selectedDate: selectedDate,
                    selectedBranch: isBranchRestricted
                        ? value.branchid
                        : _selectedBranch,
                  );
                },
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'All payment methods • ' +
                          '${DateFormat('yyyy MMM dd').format(effectiveStart)} – ' +
                          '${DateFormat('yyyy MMM dd').format(effectiveEnd)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        final uniqueBranches = <String, dynamic>{};
                        for (final branch in value.branches) {
                          uniqueBranches[branch.id] = branch;
                        }

                        final branchDropdown = DropdownButtonFormField<String?>(
                          value: _selectedBranch,
                          isExpanded: true,
                          disabledHint: Text(
                            isBranchRestricted
                                ? (value.branch.isNotEmpty
                                    ? value.branch
                                    : 'My Branch')
                                : 'All Branches',
                            style: const TextStyle(color: Colors.white70),
                          ),
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
                                borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.white12),
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
                              child: Text('All Branches'),
                            ),
                            ...uniqueBranches.values.map((branch) {
                              return DropdownMenuItem<String?>(
                                value: branch.id,
                                child: Text(branch.branchname ?? ''),
                              );
                            }),
                          ],

                          onChanged: isBranchRestricted
                              ? null
                              : (val) {
                                  setState(() => _selectedBranch = val);
                                  value.fetchsalesview(
                                    selectedDate: selectedDate,
                                    selectedBranch: val,
                                  );
                                },
                        );

                        final searchField = TextFormField(
                          onChanged: (val) {
                            setState(() {
                              searchQuery = val;
                            });
                          },
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search receipt, customer, method...',
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
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.white12)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFF415A77))),
                          ),
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip('Receipts', filteredSales.length.toString(),
                              isCount: true),
                          _chip('Total Paid',
                              'GHC ${nf.format(totals['totalPaid'] ?? 0.0)}'),
                          _chip('Hubtel',
                              'GHC ${nf.format(totals['hubtel'] ?? 0.0)}'),
                          _chip('MoMo',
                              'GHC ${nf.format(totals['momo'] ?? 0.0)}'),
                          _chip('Cash',
                              'GHC ${nf.format(totals['cash'] ?? 0.0)}'),
                          _chip('Card',
                              'GHC ${nf.format(totals['card'] ?? 0.0)}'),
                          _chip('Bank',
                              'GHC ${nf.format(totals['bank'] ?? 0.0)}'),
                          _chip('Cheque',
                              'GHC ${nf.format(totals['cheque'] ?? 0.0)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: value.isloadingsalesview
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            )
                          : filteredSales.isEmpty
                              ? const Center(
                                  child: Text('No payment records found',
                                      style: TextStyle(
                                          color: Colors.white38)))
                              : LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    return constraints.maxWidth > 600
                                        ? _buildDesktopTable(
                                            filteredSales, nf)
                                        : _buildMobileList(
                                            filteredSales, nf);
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


  // Widget _buildDesktopTable(List<SalesModel> list, NumberFormat nf) {
  //   final grouped = _groupByStaff(list);
  //   final staffKeys = grouped.keys.toList()..sort();
  //
  //   return ScrollbarTheme(
  //     data: _scrollbarTheme,
  //     child: Scrollbar(
  //       controller: _verticalController,
  //       thumbVisibility: true,
  //       trackVisibility: true,
  //       child: Scrollbar(
  //         controller: _horizontalController,
  //         thumbVisibility: true,
  //         trackVisibility: true,
  //         notificationPredicate: (n) => n.depth == 1,
  //         child: SingleChildScrollView(
  //           controller: _verticalController,
  //           primary: false,
  //           child: SingleChildScrollView(
  //             controller: _horizontalController,
  //             scrollDirection: Axis.horizontal,
  //             child: Theme(
  //               data: Theme.of(context)
  //                   .copyWith(dividerColor: Colors.white.withOpacity(0.06)),
  //               child: DataTable(
  //                 headingRowColor: WidgetStateProperty.all(
  //                     const Color(0xFF1B263B)),
  //                 dataRowColor: WidgetStateProperty.resolveWith(
  //                         (_) => const Color(0xFF0D1B2A)),
  //                 headingTextStyle: const TextStyle(
  //                   color: Colors.white,
  //                   fontWeight: FontWeight.w700,
  //                   fontSize: 12,
  //                   letterSpacing: 0.4,
  //                 ),
  //                 dataTextStyle:
  //                 const TextStyle(color: Colors.white, fontSize: 12),
  //                 columnSpacing: 20,
  //                 dividerThickness: 0.4,
  //                 horizontalMargin: 16,
  //                 columns: const [
  //                   DataColumn(label: Text('#')),
  //                   DataColumn(label: Text('STAFF')),
  //                   DataColumn(label: Text('RECEIPTS'), numeric: true),
  //                   DataColumn(label: Text('MOMO'), numeric: true),
  //                   DataColumn(label: Text('HUBTEL'), numeric: true),
  //                   DataColumn(label: Text('CASH'), numeric: true),
  //                   DataColumn(label: Text('CARD'), numeric: true),
  //                   DataColumn(label: Text('BANK'), numeric: true),
  //                   DataColumn(label: Text('CHEQUE'), numeric: true),
  //                   DataColumn(label: Text('TOTAL'), numeric: true),
  //                 ],
  //                 rows: staffKeys.asMap().entries.map((entry) {
  //                   final index = entry.key;
  //                   final staffKey = entry.value;
  //                   final staffSales = grouped[staffKey]!;
  //                   final staffTotals = _computeTotals(staffSales);
  //                   final displayName = staffSales.first.createdBy?.isNotEmpty == true
  //                       ? staffSales.first.createdBy!
  //                       : staffKey;
  //
  //                   return DataRow(
  //                     cells: [
  //                       DataCell(Text('${index + 1}',
  //                           style: const TextStyle(
  //                               color: Colors.white38, fontSize: 12))),
  //                       DataCell(Text(displayName,
  //                           style: const TextStyle(fontSize: 12))),
  //                       DataCell(Text('${staffSales.length}',
  //                           style: const TextStyle(fontSize: 12))),
  //                       DataCell(Text(nf.format(staffTotals['momo'] ?? 0.0),
  //                           style: const TextStyle(fontSize: 12))),
  //                       DataCell(Text(nf.format(staffTotals['hubtel'] ?? 0.0),
  //                           style: const TextStyle(fontSize: 12))),
  //                       DataCell(Text(nf.format(staffTotals['cash'] ?? 0.0),
  //                           style: const TextStyle(fontSize: 12))),
  //                       DataCell(Text(nf.format(staffTotals['card'] ?? 0.0),
  //                           style: const TextStyle(fontSize: 12))),
  //                       DataCell(Text(nf.format(staffTotals['bank'] ?? 0.0),
  //                           style: const TextStyle(fontSize: 12))),
  //                       DataCell(Text(nf.format(staffTotals['cheque'] ?? 0.0),
  //                           style: const TextStyle(fontSize: 12))),
  //                       DataCell(Text(nf.format(staffTotals['totalPaid'] ?? 0.0),
  //                           style: const TextStyle(
  //                               fontSize: 12, fontWeight: FontWeight.w700))),
  //                     ],
  //                   );
  //                 }).toList(),
  //               ),
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildDesktopTable(List<SalesModel> list, NumberFormat nf) {
    final grouped = _groupByStaff(list);
    final staffKeys = grouped.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        const widths = [32, 140, 80, 90, 90, 90, 90, 90, 90, 100];
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
            notificationPredicate: (n) => n.depth == 1,
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
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('STAFF',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('RECEIPTS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('MOMO',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('HUBTEL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('CASH',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('CARD',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('BANK',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('CHEQUE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
                          Text('TOTAL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.4)),
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
                            itemCount: staffKeys.length,
                            itemBuilder: (context, index) {
                              final staffKey = staffKeys[index];
                              final staffSales = grouped[staffKey]!;
                              final staffTotals = _computeTotals(staffSales);
                              final displayName = staffSales.first.createdBy?.isNotEmpty == true
                                  ? staffSales.first.createdBy!
                                  : staffKey;

                              return rowOf(
                                [
                                  Text('${index + 1}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                  Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text('${staffSales.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(staffTotals['momo'] ?? 0.0),
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(staffTotals['hubtel'] ?? 0.0),
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(staffTotals['cash'] ?? 0.0),
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(staffTotals['card'] ?? 0.0),
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(staffTotals['bank'] ?? 0.0),
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(staffTotals['cheque'] ?? 0.0),
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(nf.format(staffTotals['totalPaid'] ?? 0.0),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                                color: const Color(0xFF0D1B2A),
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
  Widget _buildMobileList(List<SalesModel> list, NumberFormat nf) {
    final grouped = _groupByStaff(list);
    final staffKeys = grouped.keys.toList()..sort();

    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _mobileVerticalController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _mobileVerticalController,
              itemCount: staffKeys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final staffKey = staffKeys[index];
                final staffSales = grouped[staffKey]!;
                final staffTotals = _computeTotals(staffSales);
                final displayName = staffSales.first.createdBy?.isNotEmpty == true
                    ? staffSales.first.createdBy!
                    : staffKey;

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B263B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ExpansionTile(
                    collapsedIconColor: Colors.white54,
                    iconColor: Colors.white,
                    title: Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${staffSales.length} receipt${staffSales.length == 1 ? '' : 's'} • GHC ${nf.format(staffTotals['totalPaid'] ?? 0.0)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          children: [
                            _mobilePair('MoMo', 'GHC ${nf.format(staffTotals['momo'] ?? 0.0)}'),
                            _mobilePair('Hubtel', 'GHC ${nf.format(staffTotals['hubtel'] ?? 0.0)}'),
                            _mobilePair('Cash', 'GHC ${nf.format(staffTotals['cash'] ?? 0.0)}'),
                            _mobilePair('Card', 'GHC ${nf.format(staffTotals['card'] ?? 0.0)}'),
                            _mobilePair('Bank', 'GHC ${nf.format(staffTotals['bank'] ?? 0.0)}'),
                            _mobilePair('Cheque', 'GHC ${nf.format(staffTotals['cheque'] ?? 0.0)}'),
                            _mobilePair('Total', 'GHC ${nf.format(staffTotals['totalPaid'] ?? 0.0)}'),
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
  Future<void> _printReport(
    List<SalesModel> list,
    Map<String, double> totals,
    String company,
    String? branchFilter,
    DateTimeRange? dateRange,
  ) async {
    final pdf = pw.Document();
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final nf = NumberFormat('#,##0.00');

    final sorted = [...list]
      ..sort((a, b) =>
          (b.createdAt?.toDate()?.compareTo(a.createdAt?.toDate() ?? DateTime(0))) ?? 0);

    pw.Widget cell(String text,
        {bool header = false,
        bool bold = false,
        bool right = false,
        PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: (header || bold) ? boldFont : baseFont,
            fontSize: 9,
            color: header
                ? PdfColors.white
                : color ?? PdfColors.grey800,
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(company.toUpperCase(),
                          style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 18,
                              color: PdfColor.fromInt(0xFF415A77))),
                      pw.SizedBox(height: 4),
                      pw.Text('Payment Report',
                          style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 11,
                              color: PdfColors.grey700)),
                      if (dateRange != null)
                        pw.Text(
                            'Period: ${DateFormat('dd MMM yyyy').format(dateRange.start)} – ${DateFormat('dd MMM yyyy').format(dateRange.end)}',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 9,
                                color: PdfColors.grey700)),
                      pw.Text('Branch: ${branchFilter ?? 'All Branches'}',
                          style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 9,
                              color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text(
                      DateFormat('dd MMM yyyy, hh:mm a')
                          .format(DateTime.now()),
                      style: pw.TextStyle(
                          font: baseFont,
                          fontSize: 8,
                          color: PdfColors.grey500)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey400),
            ],
          ),
          pw.SizedBox(height: 10),
          // pw.Table(
          //   columnWidths: {
          //     0: const pw.FixedColumnWidth(22),
          //     1: const pw.FlexColumnWidth(2.5),
          //     2: const pw.FlexColumnWidth(2.0),
          //     3: const pw.FlexColumnWidth(1.2),
          //     4: const pw.FlexColumnWidth(2.0),
          //     5: const pw.FlexColumnWidth(1.0),
          //     6: const pw.FlexColumnWidth(1.0),
          //     7: const pw.FlexColumnWidth(1.0),
          //     8: const pw.FlexColumnWidth(1.0),
          //     9: const pw.FlexColumnWidth(1.0),
          //     10: const pw.FlexColumnWidth(1.0),
          //     11: const pw.FlexColumnWidth(1.0),
          //   },
          //   border: pw.TableBorder(
          //     horizontalInside: pw.BorderSide(
          //       width: 0.3,
          //       color: PdfColors.grey300,
          //     ),
          //   ),
          //   children: [
          //     pw.TableRow(
          //       decoration: const pw.BoxDecoration(
          //         color: PdfColor.fromInt(0xFF1B263B),
          //       ),
          //       children: [
          //         cell('#', header: true),
          //         cell('Receipt', header: true),
          //         cell('Branch', header: true),
          //         cell('Date', header: true),
          //         cell('Customer', header: true),
          //         cell('MoMo', header: true, right: true),
          //         cell('Hubtel', header: true, right: true),
          //         cell('Cash', header: true, right: true),
          //         cell('Card', header: true, right: true),
          //         cell('Bank', header: true, right: true),
          //         cell('Cheque', header: true, right: true),
          //         cell('Total', header: true, right: true),
          //       ],
          //     ),
          //     ...sorted.asMap().entries.map((entry) {
          //       final index = entry.key + 1;
          //       final sale = entry.value;
          //       final momoAmount = _sumPayments(sale, ['momo']) +
          //           _sumPayments(sale, ['mobile_money']);
          //       final hubtelAmount = _sumPayments(sale, ['hubtel']);
          //       final cashAmount = _sumPayments(sale, ['cash']);
          //       final cardAmount = _sumPayments(sale, ['card']);
          //       final bankAmount =
          //           _sumPayments(sale, ['bank_transfer', 'bank']);
          //       final chequeAmount = _sumPayments(sale, ['cheque', 'cheques']);
          //       final totalPaid = momoAmount + hubtelAmount + cashAmount +
          //           cardAmount + bankAmount + chequeAmount;
          //       final dateLabel = sale.createdAt != null
          //           ? DateFormat('dd MMM yyyy').format(sale.createdAt!.toDate())
          //           : sale.dateymd ?? '-';
          //       return pw.TableRow(
          //         decoration: const pw.BoxDecoration(color: PdfColors.white),
          //         children: [
          //           cell(index.toString(), right: true),
          //           cell(sale.receiptNumber, bold: true),
          //           cell(sale.branchName),
          //           cell(dateLabel),
          //           cell(sale.customerName ?? 'Cash Customer'),
          //           cell(nf.format(momoAmount), right: true),
          //           cell(nf.format(hubtelAmount), right: true),
          //           cell(nf.format(cashAmount), right: true),
          //           cell(nf.format(cardAmount), right: true),
          //           cell(nf.format(bankAmount), right: true),
          //           cell(nf.format(chequeAmount), right: true),
          //           cell(nf.format(totalPaid), right: true, bold: true),
          //         ],
          //       );
          //     }).toList(),
          //     pw.TableRow(
          //       decoration: const pw.BoxDecoration(
          //           color: PdfColor.fromInt(0xFF0D1B2A)),
          //       children: [
          //         cell('', header: true),
          //         cell('GRAND TOTAL', header: true, bold: true),
          //         cell('', header: true),
          //         cell('', header: true),
          //         cell('', header: true),
          //         cell(nf.format(totals['momo'] ?? 0.0),
          //             header: true, right: true),
          //         cell(nf.format(totals['hubtel'] ?? 0.0),
          //             header: true, right: true),
          //         cell(nf.format(totals['cash'] ?? 0.0),
          //             header: true, right: true),
          //         cell(nf.format(totals['card'] ?? 0.0),
          //             header: true, right: true),
          //         cell(nf.format(totals['bank'] ?? 0.0),
          //             header: true, right: true),
          //         cell(nf.format(totals['cheque'] ?? 0.0),
          //             header: true, right: true),
          //         cell(nf.format(totals['totalPaid'] ?? 0.0),
          //             header: true, right: true),
          //       ],
          //     ),
          //   ],
          // ),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(3.0),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.0),
              7: const pw.FlexColumnWidth(1.0),
              8: const pw.FlexColumnWidth(1.0),
              9: const pw.FlexColumnWidth(1.0),
            },
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                width: 0.3,
                color: PdfColors.grey300,
              ),
            ),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1B263B),
                ),
                children: [
                  cell('#', header: true),
                  cell('Staff', header: true),
                  cell('Receipts', header: true, right: true),
                  cell('MoMo', header: true, right: true),
                  cell('Hubtel', header: true, right: true),
                  cell('Cash', header: true, right: true),
                  cell('Card', header: true, right: true),
                  cell('Bank', header: true, right: true),
                  cell('Cheque', header: true, right: true),
                  cell('Total', header: true, right: true),
                ],
              ),
              ...() {
                final grouped = _groupByStaff(sorted);
                final staffKeys = grouped.keys.toList()..sort();
                return staffKeys.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final staffKey = entry.value;
                  final staffSales = grouped[staffKey]!;
                  final staffTotals = _computeTotals(staffSales);
                  final displayName = staffSales.first.createdBy?.isNotEmpty == true
                      ? staffSales.first.createdBy!
                      : staffKey;
                  return pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.white),
                    children: [
                      cell(index.toString(), right: true),
                      cell(displayName, bold: true),
                      cell(staffSales.length.toString(), right: true),
                      cell(nf.format(staffTotals['momo'] ?? 0.0), right: true),
                      cell(nf.format(staffTotals['hubtel'] ?? 0.0), right: true),
                      cell(nf.format(staffTotals['cash'] ?? 0.0), right: true),
                      cell(nf.format(staffTotals['card'] ?? 0.0), right: true),
                      cell(nf.format(staffTotals['bank'] ?? 0.0), right: true),
                      cell(nf.format(staffTotals['cheque'] ?? 0.0), right: true),
                      cell(nf.format(staffTotals['totalPaid'] ?? 0.0), right: true, bold: true),
                    ],
                  );
                }).toList();
              }(),
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF0D1B2A)),
                children: [
                  cell('', header: true),
                  cell('GRAND TOTAL', header: true, bold: true),
                  cell(sorted.length.toString(), header: true, right: true),
                  cell(nf.format(totals['momo'] ?? 0.0),
                      header: true, right: true),
                  cell(nf.format(totals['hubtel'] ?? 0.0),
                      header: true, right: true),
                  cell(nf.format(totals['cash'] ?? 0.0),
                      header: true, right: true),
                  cell(nf.format(totals['card'] ?? 0.0),
                      header: true, right: true),
                  cell(nf.format(totals['bank'] ?? 0.0),
                      header: true, right: true),
                  cell(nf.format(totals['cheque'] ?? 0.0),
                      header: true, right: true),
                  cell(nf.format(totals['totalPaid'] ?? 0.0),
                      header: true, right: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget _chip(String label, String value, {bool isCount = false}) {
    Color valueColor = Colors.white;
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
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  Widget _mobilePair(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ],
      );
}
