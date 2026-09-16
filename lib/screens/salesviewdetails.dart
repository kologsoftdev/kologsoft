import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesDetailPage extends StatelessWidget {
  final dynamic salesview;

  const SalesDetailPage({super.key, required this.salesview});

  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final receipt = salesview.receiptNumber ?? '';
    final customerName = (salesview.customerName?.toString().isNotEmpty == true)
        ? salesview.customerName.toString()
        : '-';
    final createdBy = salesview.createdBy ?? '-';
    final transMode = salesview.transMode ?? '-';
    final paymentStatus = salesview.paymentStatus ?? '-';
    final branchName = salesview.branchName ?? salesview.branchname ?? '-';
    final companyName = salesview.companyname ?? salesview.companyName ?? '-';
    final approvedBy = salesview.approvedby ?? '-';
    final discount = salesview.discount?.toString() ?? '0';
    final amountPaid = salesview.amountPaid?.toString() ?? '0';
    final change = salesview.change?.toString() ?? '0';
    final isReturned = salesview.isreturned == true;
   // final stockCheckStatus = salesview.stockCheckStatus ?? '-';

    final dateStr = salesview.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a')
        .format(salesview.createdAt!.toDate())
        : '-';

    final Map<String, dynamic> itemMap =
    Map<String, dynamic>.from(salesview.items ?? {});

    final numberFormat = NumberFormat('#,##0.00');

    final totalAmount = itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum +
            (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
      }
      return sum;
    });

    final totalPieces = itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum +
            (double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0);
      }
      return sum;
    });

    // Payments list
    List<Map<String, dynamic>> payments = [];
    try {
      final raw = salesview.payments;
      if (raw is List) {
        payments = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        title: Text(
          'Receipt #$receipt',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFFFFC857)),
            tooltip: 'Print Receipt',
            onPressed: () => _printSalesDetail(
              receipt: receipt,
              customerName: customerName,
              createdBy: createdBy,
              transMode: transMode,
              paymentStatus: paymentStatus,
              branchName: branchName,
              companyName: companyName,
              approvedBy: approvedBy,
              discount: discount,
              amountPaid: amountPaid,
              change: change,
              dateStr: dateStr,
              itemMap: itemMap,
              payments: payments,
              totalAmount: totalAmount,
              totalPieces: totalPieces,
              isReturned: isReturned,
            ),
          ),
          if (isReturned)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.undo, color: Colors.redAccent, size: 12),
                  SizedBox(width: 4),
                  Text('RETURNED',
                      style:
                      TextStyle(color: Colors.redAccent, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 700;
          return isDesktop
              ? _buildDesktop(context, receipt, customerName, createdBy,
              transMode, paymentStatus, branchName, companyName,
              approvedBy, discount, amountPaid, change, dateStr,
              itemMap, payments, totalAmount, totalPieces,
              numberFormat, isReturned)
              : _buildMobile(context, receipt, customerName, createdBy,
              transMode, paymentStatus, branchName, companyName,
              approvedBy, discount, amountPaid, change, dateStr,
              itemMap, payments, totalAmount, totalPieces,
              numberFormat, isReturned);
        },
      ),
    );
  }

  Widget _buildDesktop(
      BuildContext context,
      String receipt,
      String customerName,
      String createdBy,
      String transMode,
      String paymentStatus,
      String branchName,
      String companyName,
      String approvedBy,
      String discount,
      String amountPaid,
      String change,
      String dateStr,
      Map<String, dynamic> itemMap,
      List<Map<String, dynamic>> payments,
      double totalAmount,
      double totalPieces,
      NumberFormat numberFormat,
      bool isReturned,
      ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: transaction info
                  Expanded(
                    child: _infoCard(
                      title: 'TRANSACTION INFO',
                      children: [
                        _infoRow('Company', companyName),
                        _infoRow('Branch', branchName),
                        _infoRow('Customer', customerName),
                        _infoRow('Staff', createdBy),
                        _infoRow('Approved By', approvedBy),
                        _infoRow('Date', dateStr),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right: payment info
                  Expanded(
                    child: _infoCard(
                      title: 'PAYMENT INFO',
                      children: [
                        _infoRow('Trans Mode', capitalize(transMode)),
                        _infoRow('Payment Status', paymentStatus,
                            valueColor: paymentStatus.toLowerCase() == 'paid'
                                ? Colors.greenAccent
                                : Colors.orangeAccent),

                        _infoRow('Discount', 'GHC $discount'),
                        _infoRow('Amount Paid', 'GHC $amountPaid',
                            valueColor: const Color(0xFFFFC857)),
                        _infoRow('Change', 'GHC $change'),
                        if (isReturned)
                          _infoRow('Returned', 'Yes',
                              valueColor: Colors.redAccent),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              _sectionHeader('ITEMS'),
              const SizedBox(height: 10),
              _desktopItemsTable(itemMap, numberFormat, totalPieces),

              const SizedBox(height: 20),

             Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payments breakdown
                  if (payments.isNotEmpty)
                    Expanded(
                      child: _infoCard(
                        title: 'PAYMENTS BREAKDOWN',
                        children: payments
                            .map((p) => _infoRow(
                          capitalize(p['method']?.toString()),
                          'GHC ${numberFormat.format(double.tryParse(p['amount']?.toString() ?? '0') ?? 0)}',
                          valueColor: const Color(0xFFFFC857),
                        ))
                            .toList(),
                      ),
                    ),
                  if (payments.isNotEmpty) const SizedBox(width: 16),
                  // Summary
                  Expanded(
                    child: _summaryCard(
                        totalAmount, totalPieces, itemMap.length, numberFormat),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopItemsTable(
      Map<String, dynamic> itemMap, NumberFormat nf, double totalPieces) {
    final items =
    itemMap.values.whereType<Map<String, dynamic>>().toList();
    final isReturned = items.any((i) => i['status'] == 'returned');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(0.4),  // #
            1: FlexColumnWidth(2.5),  // Item
            2: FlexColumnWidth(1),    // Mode
            3: FlexColumnWidth(0.8),  // Qty
            4: FlexColumnWidth(0.8),  // Pieces
            5: FlexColumnWidth(1),    // Price Mode
            6: FlexColumnWidth(1),    // Unit Price
            7: FlexColumnWidth(0.8),  // Discount
            8: FlexColumnWidth(1.2),  // Total
            9: FlexColumnWidth(1),    // Status
          },
          children: [
            // Header
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFF0D1B2A)),
              children: [
                _tHeader('#'),
                _tHeader('ITEM'),
                _tHeader('MODE'),
                _tHeader('QTY'),
                _tHeader('PIECES'),
                _tHeader('PRICE MODE'),
                _tHeader('UNIT PRICE'),
                _tHeader('DISCOUNT'),
                _tHeader('TOTAL'),
                _tHeader('STATUS'),
              ],
            ),
            // Rows
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final status = item['status']?.toString() ?? '';
              final isItemReturned = status == 'returned';
              final rowColor = isItemReturned
                  ? Colors.redAccent.withOpacity(0.07)
                  : i.isEven
                  ? const Color(0xFF1B263B)
                  : const Color(0xFF1A2844);

              return TableRow(
                decoration: BoxDecoration(color: rowColor),
                children: [
                  _tCell('${i + 1}', color: Colors.white38),
                  _tCell(item['item']?.toString().toUpperCase() ?? 'N/A',
                      bold: true),
                  _tCell(item['mode']?.toString() ?? '-',
                      align: TextAlign.center),
                  _tCell(item['quantity']?.toString() ?? '-',
                      align: TextAlign.right),
                  _tCell(item['totalpieces']?.toString() ?? '-',
                      align: TextAlign.right),
                  _tCell(capitalize(item['pricemode']?.toString()),
                      align: TextAlign.center),
                  _tCell('GHC ${item['price'] ?? '-'}',
                      align: TextAlign.right,
                      color: const Color(0xFFFFC857)),
                  _tCell(item['discount']?.toString() ?? '0',
                      align: TextAlign.right),
                  _tCell(
                      'GHC ${nf.format(double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0)}',
                      align: TextAlign.right,
                      bold: true),
                  _tCellStatus(status),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile(
      BuildContext context,
      String receipt,
      String customerName,
      String createdBy,
      String transMode,
      String paymentStatus,
      String branchName,
      String companyName,
      String approvedBy,
      String discount,
      String amountPaid,
      String change,
      String dateStr,
      Map<String, dynamic> itemMap,
      List<Map<String, dynamic>> payments,
      double totalAmount,
      double totalPieces,
      NumberFormat numberFormat,
      bool isReturned,
      ) {
    final items =
    itemMap.values.whereType<Map<String, dynamic>>().toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Transaction info
        _infoCard(
          title: 'TRANSACTION INFO',
          children: [
            _infoRow('Company', companyName),
            _infoRow('Branch', branchName),
            _infoRow('Customer', customerName),
            _infoRow('Staff', createdBy),
            _infoRow('Approved By', approvedBy),
            _infoRow('Date', dateStr),
          ],
        ),
        const SizedBox(height: 12),

        // Payment info
        _infoCard(
          title: 'PAYMENT INFO',
          children: [
            _infoRow('Trans Mode', capitalize(transMode)),
            _infoRow('Payment Status', paymentStatus,
                valueColor: paymentStatus.toLowerCase() == 'paid'
                    ? Colors.greenAccent
                    : Colors.orangeAccent),

            _infoRow('Discount', 'GHC $discount'),
            _infoRow('Amount Paid', 'GHC $amountPaid',
                valueColor: const Color(0xFFFFC857)),
            _infoRow('Change', 'GHC $change'),
            if (isReturned)
              _infoRow('Returned', 'Yes', valueColor: Colors.redAccent),
          ],
        ),
        const SizedBox(height: 12),

        // Items
        _sectionHeader('ITEMS'),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final status = item['status']?.toString() ?? '';
          final isItemReturned = status == 'returned';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isItemReturned
                  ? Colors.redAccent.withOpacity(0.08)
                  : const Color(0xFF1B263B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isItemReturned
                    ? Colors.redAccent.withOpacity(0.3)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${i + 1}. ${(item['item'] ?? '').toString().toUpperCase()}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      ),
                    ),
                    Text(
                      'GHC ${numberFormat.format(double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0)}',
                      style: const TextStyle(
                          color: Color(0xFFFFC857),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
                if (isItemReturned) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'RETURNED${item['returned_condition'] != null ? ' · ${item['returned_condition']}' : ''}',
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 9),
                    ),
                  ),
                ],
                const Divider(color: Colors.white10, height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _pair('Qty',
                        '${item['quantity']} (${item['mode']})'),
                    _pair('Pieces', item['totalpieces']?.toString() ?? '-'),
                    _pair('Unit Price', 'GHC ${item['price'] ?? '-'}'),
                    _pair('Discount', '${item['discount'] ?? '0'}'),
                    _pair('Price Mode',
                        capitalize(item['pricemode']?.toString())),
                    if (item['cp'] != null)
                      _pair('Cost Price', 'GHC ${item['cp']}'),
                  ],
                ),
              ],
            ),
          );
        }),

        // Payments breakdown
        if (payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _infoCard(
            title: 'PAYMENTS BREAKDOWN',
            children: payments
                .map((p) => _infoRow(
              capitalize(p['method']?.toString()),
              'GHC ${numberFormat.format(double.tryParse(p['amount']?.toString() ?? '0') ?? 0)}',
              valueColor: const Color(0xFFFFC857),
            ))
                .toList(),
          ),
        ],

        const SizedBox(height: 12),
        _summaryCard(
            totalAmount, totalPieces, itemMap.length, numberFormat),
        const SizedBox(height: 24),
      ],
    );
  }


  Widget _sectionHeader(String text) => Text(
    text,
    style: const TextStyle(
        color: Colors.white38, fontSize: 10, letterSpacing: 1.6),
  );

  Widget _infoCard(
      {required String title, required List<Widget> children}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.4)),
            const Divider(color: Colors.white12, height: 16),
            ...children,
          ],
        ),
      );

  Widget _infoRow(String label, String value, {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _summaryCard(double totalAmount, double totalPieces,
      int itemCount, NumberFormat nf) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('SUMMARY',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.4)),
            const Divider(color: Colors.white12, height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Items',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('$itemCount',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pieces',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(totalPieces.toStringAsFixed(0),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ]),
            const Divider(color: Colors.white12, height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('GRAND TOTAL',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  Text(
                    'GHC ${nf.format(totalAmount)}',
                    style: const TextStyle(
                        color: Color(0xFFFFC857),
                        fontSize: 18,
                        fontWeight: FontWeight.w900),
                  ),
                ]),
          ],
        ),
      );

  // Desktop table cell helpers
  Widget _tHeader(String text) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700)),
  );

  Widget _tCell(String text,
      {TextAlign align = TextAlign.left,
        Color? color,
        bool bold = false}) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      );

  Widget _tCellStatus(String status) {
    final isReturned = status == 'returned';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: status.isEmpty
          ? const SizedBox()
          : Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isReturned
              ? Colors.redAccent.withOpacity(0.15)
              : Colors.greenAccent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            color: isReturned ? Colors.redAccent : Colors.greenAccent,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _pair(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style:const TextStyle(color: Colors.white38, fontSize: 9)),
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ],
  );

  Future<void> _printSalesDetail({
    required String receipt,
    required String customerName,
    required String createdBy,
    required String transMode,
    required String paymentStatus,
    required String branchName,
    required String companyName,
    required String approvedBy,
    required String discount,
    required String amountPaid,
    required String change,
    required String dateStr,
    required Map<String, dynamic> itemMap,
    required List<Map<String, dynamic>> payments,
    required double totalAmount,
    required double totalPieces,
    required bool isReturned,
  }) async {
    final pdf = pw.Document();
    final nf = NumberFormat.currency(symbol: 'GHC ', decimalDigits: 2);
    final items = itemMap.values.whereType<Map<String, dynamic>>().toList();
    String capitalize(String? text) {
      if (text == null || text.isEmpty) return '';
      return text[0].toUpperCase() + text.substring(1);
    }
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) => [

          // ── Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    branchName,
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'SALES RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Receipt #$receipt',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if (isReturned)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 4),
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.red300),
                      ),
                      child: pw.Text(
                        'RETURNED',
                        style: pw.TextStyle(
                          color: PdfColors.red700,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          pw.Divider(height: 28, thickness: 1),

          // ── Transaction Info + Payment
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left — transaction
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSectionLabel('TRANSACTION INFO'),
                    pw.SizedBox(height: 6),
                    _pdfInfoRow('Customer', customerName),
                    _pdfInfoRow('Staff', createdBy),
                    _pdfInfoRow('Approved By', approvedBy),
                    _pdfInfoRow('Date', dateStr),
                  ],
                ),
              ),
              pw.SizedBox(width: 30),
              // Right — payment
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSectionLabel('PAYMENT INFO'),
                    pw.SizedBox(height: 6),
                    _pdfInfoRow('Trans Mode', capitalize(transMode)),
                    _pdfInfoRow('Payment Status', paymentStatus),
                    _pdfInfoRow('Discount', 'GHC $discount'),
                    _pdfInfoRow('Amount Paid', 'GHC $amountPaid'),
                    _pdfInfoRow('Change', 'GHC $change'),
                    if (isReturned) _pdfInfoRow('Returned', 'Yes'),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Items Table
          _pdfSectionLabel('ITEMS'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.4),  // #
              1: const pw.FlexColumnWidth(2.8),  // Item
              2: const pw.FlexColumnWidth(1),    // Mode
              3: const pw.FlexColumnWidth(0.7),  // Qty
              4: const pw.FlexColumnWidth(0.8),  // Pieces
              5: const pw.FlexColumnWidth(1),    // Price Mode
              6: const pw.FlexColumnWidth(1.1),  // Unit Price
              7: const pw.FlexColumnWidth(0.7),  // Disc
              8: const pw.FlexColumnWidth(1.2),  // Total
              9: const pw.FlexColumnWidth(0.9),  // Status
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  _pdfTHeader('#'),
                  _pdfTHeader('ITEM'),
                  _pdfTHeader('MODE'),
                  _pdfTHeader('QTY'),
                  _pdfTHeader('PIECES'),
                  _pdfTHeader('PRICE MODE'),
                  _pdfTHeader('UNIT PRICE'),
                  _pdfTHeader('DISC'),
                  _pdfTHeader('TOTAL'),
                  _pdfTHeader('STATUS'),
                ],
              ),
              // Data rows
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final status = item['status']?.toString() ?? '';
                final isItemReturned = status == 'returned';
                final rowBg = isItemReturned
                    ? PdfColors.red50
                    : i.isEven
                    ? PdfColors.white
                    : PdfColors.grey50;

                final itemTotal = double.tryParse(
                    item['totalamount']?.toString() ?? '0') ??
                    0;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: rowBg),
                  children: [
                    _pdfTCell('${i + 1}', color: PdfColors.grey600),
                    _pdfTCell(
                        item['item']?.toString().toUpperCase() ?? 'N/A',
                        bold: true),
                    _pdfTCell(item['mode']?.toString() ?? '-',
                        align: pw.TextAlign.center),
                    _pdfTCell(item['quantity']?.toString() ?? '-',
                        align: pw.TextAlign.right),
                    _pdfTCell(item['totalpieces']?.toString() ?? '-',
                        align: pw.TextAlign.right),
                    _pdfTCell(capitalize(item['pricemode']?.toString()),
                        align: pw.TextAlign.center),
                    _pdfTCell('GHC ${item['price'] ?? '-'}',
                        align: pw.TextAlign.right,
                        color: PdfColors.orange800),
                    _pdfTCell(item['discount']?.toString() ?? '0',
                        align: pw.TextAlign.right),
                    _pdfTCell(
                        'GHC ${nf.format(itemTotal).replaceAll('GHC ', '')}',
                        align: pw.TextAlign.right,
                        bold: true),
                    _pdfTCellStatus(status),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Payments + Summary
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Payments breakdown
              if (payments.isNotEmpty)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfSectionLabel('PAYMENTS BREAKDOWN'),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border:
                          pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Column(
                          children: payments.map((p) {
                            final amt = double.tryParse(
                                p['amount']?.toString() ?? '0') ??
                                0;
                            return pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  vertical: 3),
                              child: pw.Row(
                                mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    capitalize(p['method']?.toString()),
                                    style: pw.TextStyle(fontSize: 11),
                                  ),
                                  pw.Text(
                                    'GHC ${NumberFormat('#,##0.00').format(amt)}',
                                    style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.orange800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              if (payments.isNotEmpty) pw.SizedBox(width: 20),
              // Summary box
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSectionLabel('SUMMARY'),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey50,
                        border:
                        pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Total Items:',
                                  style: pw.TextStyle(fontSize: 11)),
                              pw.Text('${itemMap.length}',
                                  style: pw.TextStyle(fontSize: 11)),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Total Pieces:',
                                  style: pw.TextStyle(fontSize: 11)),
                              pw.Text(
                                  totalPieces.toStringAsFixed(0),
                                  style: pw.TextStyle(fontSize: 11)),
                            ],
                          ),
                          pw.Divider(height: 14),
                          pw.Row(
                            mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'GRAND TOTAL:',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                ),
                              ),
                              pw.Text(
                                'GHC ${NumberFormat('#,##0.00').format(totalAmount)}',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 40),

          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500),
              ),
              pw.Text(
                'Receipt #$receipt',
                style: pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }


  pw.Widget _pdfSectionLabel(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 9,
      color: PdfColors.grey500,
      letterSpacing: 1.4,
      fontWeight: pw.FontWeight.bold,
    ),
  );

  pw.Widget _pdfInfoRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600)),
        ),
        pw.Expanded(
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ),
  );

  pw.Widget _pdfTHeader(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    ),
  );

  pw.Widget _pdfTCell(String text,
      {pw.TextAlign align = pw.TextAlign.left,
        PdfColor? color,
        bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 10,
            color: color ?? PdfColors.black,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  pw.Widget _pdfTCellStatus(String status) {
    if (status.isEmpty) {
      return pw.Container(
          padding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8));
    }
    final isRet = status == 'returned';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Container(
        padding:
        const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: pw.BoxDecoration(
          color: isRet ? PdfColors.red50 : PdfColors.green50,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(
              color: isRet ? PdfColors.red300 : PdfColors.green300),
        ),
        child: pw.Text(
          status.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: isRet ? PdfColors.red700 : PdfColors.green700,
          ),
        ),
      ),
    );
  }
}