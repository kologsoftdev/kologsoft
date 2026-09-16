
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

Future<void> salesViewPdf(dynamic salesview) async {
  final pdf = pw.Document();

  final currencyFormat = NumberFormat.currency(symbol: 'GHC ', decimalDigits: 2);
  final dateFormat     = DateFormat('dd MMM yyyy, hh:mm a');
  final nf             = NumberFormat('#,##0.00');
  final ttfRegular =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final ttfBold =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));


  final receipt      = salesview.receiptNumber?.toString() ?? '';
  final company      = salesview.companyname?.toString() ?? '';
  final branchName   = salesview.branchName?.toString() ?? '';
  final customerName = (salesview.customerName?.toString().isNotEmpty == true)
      ? salesview.customerName.toString() : 'Cash Customer';
  final customerPhone = _str(salesview, 'customerPhone') ?? '-';
  final createdBy     = salesview.createdBy?.toString()   ?? '-';
  final approvedBy    = _str(salesview, 'approvedby')     ?? '-';
  final transMode     = salesview.transMode?.toString()    ?? '-';
  final payStatus     = salesview.paymentStatus?.toString() ?? '-';
  final isReturned    = _bool(salesview, 'isreturned');
  final discount      = _num(salesview, 'discount');
  final change        = _num(salesview, 'change');
  final amountPaid    = _num(salesview, 'amountPaid');

  final dateStr = salesview.createdAt != null
      ? dateFormat.format((salesview.createdAt as Timestamp).toDate())
      : '-';

  //Items
  final Map<String, dynamic> itemMap =
  Map<String, dynamic>.from(salesview.items as Map);

  final items = itemMap.values.whereType<Map<String, dynamic>>().toList();

  final grandTotal = items.fold<double>(0, (s, item) =>
  s + (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0));

  final totalPieces = items.fold<double>(0, (s, item) =>
  s + (double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0));

  //Payments
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

  //Has any returned item?
  final returnedItems = items
      .where((item) => item['status']?.toString() == 'returned')
      .toList();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (pw.Context context) => [

      pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  company.toUpperCase(),
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  branchName,
                  style:  pw.TextStyle(
                      font: ttfRegular,
                      fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'SALES RECEIPT',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: isReturned ? PdfColors.red50 : PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(
                        color:
                        isReturned ? PdfColors.red200 : PdfColors.green200),
                  ),
                  child: pw.Text(
                    isReturned ? 'RETURNED' : payStatus.toUpperCase(),
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: isReturned ? PdfColors.red700 : PdfColors.green700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        pw.Divider(height: 28, thickness: 1.2),


        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _infoRow('Receipt #', receipt,ttfBold,ttfRegular),
                  _infoRow('Customer', customerName,ttfBold,ttfRegular),
                  _infoRow('Phone', customerPhone,ttfBold,ttfRegular),
                  _infoRow('Trans Mode', transMode,ttfBold,ttfRegular),
                ],
              ),
            ),
            // Right
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _infoRowRight('Date', dateStr,ttfBold,ttfRegular),
                  _infoRowRight('Staff', createdBy,ttfBold,ttfRegular),
                  _infoRowRight('Approved by', approvedBy,ttfBold,ttfRegular),
                  _infoRowRight('Payment Status', payStatus.toUpperCase(),ttfBold,ttfRegular),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 22),


        pw.Text('ITEMS',
            style: pw.TextStyle(
              font: ttfBold,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
                letterSpacing: 1.4)),
        pw.SizedBox(height: 6),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.5), // Item
            1: const pw.FlexColumnWidth(1.2), // Mode
            2: const pw.FlexColumnWidth(0.8), // Qty
            3: const pw.FlexColumnWidth(0.8), // Pcs
            4: const pw.FlexColumnWidth(1.2), // Price Mode
            5: const pw.FlexColumnWidth(1.3), // Unit Price
            6: const pw.FlexColumnWidth(0.9), // Discount
            7: const pw.FlexColumnWidth(1.5), // Total
          },
          children: [
            // Header row
            pw.TableRow(
              decoration:
              const pw.BoxDecoration(color: PdfColors.blue900),
              children: [
                _th('ITEM', ttfBold),
                _th('MODE', ttfBold),
                _th('QTY', ttfBold),
                _th('PCS', ttfBold),
                _th('PRICE MODE', ttfBold),
                _th('UNIT PRICE', ttfBold),
                _th('DISC', ttfBold),
                _th('TOTAL', ttfBold),
              ],
            ),

            // Data rows
            ...List.generate(items.length, (i) {
              final item      = items[i];
              final isRet     = item['status']?.toString() == 'returned';
              final qty       = item['quantity']?.toString() ?? '-';
              final mode      = item['mode']?.toString() ?? '-';
              final pcs       = item['totalpieces']?.toString() ?? '-';
              final priceMode = _capitalize(item['pricemode']?.toString());
              final price     = double.tryParse(
                  item['price']?.toString() ?? '0') ??
                  0;
              final disc      = item['discount']?.toString() ?? '0';
              final total     = double.tryParse(
                  item['totalamount']?.toString() ?? '0') ??
                  0;
              final bgColor   =
              i.isEven ? PdfColors.white : PdfColors.grey50;

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bgColor),
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  // Item name + returned badge
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 9, horizontal: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          (item['item'] ?? 'N/A').toString().toUpperCase(),
                          style: pw.TextStyle(
                            font: ttfBold,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold),
                        ),
                        if (item['barcode'] != null &&
                            item['barcode'] != item['item'])
                          pw.Text(
                            item['barcode'].toString(),
                            style:  pw.TextStyle(
                              font: ttfRegular,
                                fontSize: 8, color: PdfColors.grey600),
                          ),
                        if (isRet)
                          pw.Container(
                            margin: const pw.EdgeInsets.only(top: 3),
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.red100,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                            child: pw.Text('RETURNED',
                                style: pw.TextStyle(
                                  font: ttfBold,
                                    fontSize: 7,
                                    color: PdfColors.red700,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  _td(mode, ttfRegular),
                  _td(qty, ttfRegular),
                  _td(pcs, ttfRegular),
                  _tdCenter(priceMode, ttfRegular),
                  _tdRight('GHC ${nf.format(price)}', ttfRegular),
                  _tdRight(disc, ttfRegular),
                  _tdRight(
                    'GHC ${nf.format(total)}',ttfBold,
                    bold: true,
                    color: isRet ? PdfColors.red700 : PdfColors.blue900,
                  ),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 20),

        // ════════════════════════════════════════════════════════════════════
        // RETURN DETAILS  (only if isReturned)
        // ════════════════════════════════════════════════════════════════════
        if (isReturned && returnedItems.isNotEmpty) ...[
          pw.Text('RETURN DETAILS',
              style: pw.TextStyle(
                font: ttfBold,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700,
                  letterSpacing: 1.4)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.red200, width: 0.8),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: PdfColors.red700),
                children: [
                  _th('ITEM', ttfBold),
                  _th('TYPE', ttfBold),
                  _th('CONDITION', ttfBold),
                  _th('QTY', ttfBold),
                  _th('TOTAL', ttfBold),
                ],
              ),
              ...returnedItems.map((item) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColors.red50),
                verticalAlignment:
                pw.TableCellVerticalAlignment.middle,
                children: [
                  _td(item['returned_item']?.toString() ??
                      item['item']?.toString() ??'',ttfRegular),
                  _tdCenter(item['returned_type']?.toString() ?? '-', ttfRegular),
                  _tdCenter(
                      item['returned_condition']?.toString() ?? '-', ttfRegular),
                  _tdCenter(
                      item['returned_quantity']?.toString() ?? '-', ttfRegular),
                  _tdRight(
                    'GHC ${nf.format(double.tryParse(item['returned_totalamount']?.toString() ?? '0') ?? 0)}',ttfRegular,
                    color: PdfColors.red700,
                    bold: true,
                  ),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // ════════════════════════════════════════════════════════════════════
        // PAYMENTS  +  SUMMARY  (side by side)
        // ════════════════════════════════════════════════════════════════════
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Payments breakdown (left)
            if (payments.isNotEmpty)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PAYMENTS',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                            letterSpacing: 1.4)),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(
                          color: PdfColors.grey300, width: 0.8),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                              color: PdfColors.blueGrey800),
                          children: [
                            _th('METHOD',ttfBold),
                            _th('ACCOUNT',ttfBold),
                            _th('AMOUNT',ttfBold),
                          ],
                        ),
                        ...payments.map((p) => pw.TableRow(
                          decoration: const pw.BoxDecoration(
                              color: PdfColors.white),
                          verticalAlignment:
                          pw.TableCellVerticalAlignment.middle,
                          children: [
                            _td(_capitalize(
                                p['method']?.toString()),ttfRegular),
                            _td(p['accountName']?.toString() ??
                                '-', ttfRegular),
                            _tdRight(
                              'GHC ${nf.format((p['amount'] as num?)?.toDouble() ?? double.tryParse(p['amount']?.toString() ?? '0') ?? 0)}',ttfRegular,
                              bold: true,
                            ),
                          ],
                        )),
                      ],
                    ),
                  ],
                ),
              ),

            pw.SizedBox(width: 16),

            // Summary box (right)
            pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _summaryRow('Items', items.length.toString(),ttfBold,ttfRegular),
                  _summaryRow('Total Pieces',
                      totalPieces.toStringAsFixed(0),ttfBold,ttfRegular),
                  if (discount > 0)
                    _summaryRow('Discount',
                        'GHC ${nf.format(discount)}',ttfBold,ttfRegular,
                        color: PdfColors.orange700),
                  pw.Divider(color: PdfColors.grey300),
                  _summaryRow('Grand Total',
                      'GHC ${nf.format(grandTotal)}',ttfBold,ttfRegular),
                  if (amountPaid > 0)
                    _summaryRow('Amount Paid',
                        'GHC ${nf.format(amountPaid)}',ttfBold,ttfRegular,
                        bold: true, color: PdfColors.green700),
                  if (change > 0)
                    _summaryRow('Change',
                        'GHC ${nf.format(change)}',ttfBold,ttfRegular,
                        color: PdfColors.blueGrey600),
                  pw.Divider(color: PdfColors.grey400),
                  pw.Row(
                    mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL',
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          )),
                      pw.Text(
                        currencyFormat.format(grandTotal),
                        style: pw.TextStyle(
                          font: ttfBold,
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

        pw.SizedBox(height: 36),


        pw.Divider(thickness: 0.8),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style:  pw.TextStyle(
                font: ttfRegular,
                  fontSize: 9, color: PdfColors.grey500),
            ),
            pw.Text(
              'Receipt #$receipt - $company',
              style:  pw.TextStyle(
                  font: ttfRegular,
                  fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

// ── Helpers

String? _str(dynamic obj, String key) {
  try { return (obj as dynamic).toJson()[key]?.toString(); } catch (_) {}
  try { return obj[key]?.toString(); } catch (_) {}
  return null;
}

double _num(dynamic obj, String key) {
  try {
    final v = (obj as dynamic).toJson()[key];
    return (v as num?)?.toDouble() ?? 0;
  } catch (_) {}
  try {
    final v = obj[key];
    return (v as num?)?.toDouble() ??
        double.tryParse(v?.toString() ?? '0') ?? 0;
  } catch (_) {}
  return 0;
}

bool _bool(dynamic obj, String key) {
  try { return (obj as dynamic).toJson()[key] as bool? ?? false; } catch (_) {}
  try { return obj[key] as bool? ?? false; } catch (_) {}
  return false;
}

String _capitalize(String? text) {
  if (text == null || text.isEmpty) return '';
  return text[0].toUpperCase() + text.substring(1);
}

// ── Table cell builders

pw.Widget _th(String text, pw.Font ttBold) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
  child: pw.Text(text,
      style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          font: ttBold,
          fontSize: 9,
          color: PdfColors.white)),
);

pw.Widget _td(String text,pw.Font ttRegular) => pw.Container(
  padding:
  const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
  child:
  pw.Text(text, style:  pw.TextStyle(font:ttRegular,fontSize: 10)),
);

pw.Widget _tdCenter(String text,pw.Font ttRegular) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
  child: pw.Text(text,
      style:  pw.TextStyle(font:ttRegular,fontSize: 10),
      textAlign: pw.TextAlign.center),
);

pw.Widget _tdRight(String text,pw.Font ttBold,
    {bool bold = false, PdfColor color = PdfColors.black}) =>
    pw.Container(
      padding:
      const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 10,
              font: ttBold,
              fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color),
          textAlign: pw.TextAlign.right),
    );

pw.Widget _infoRow(String label, String value,pw.Font ttBold,pw.Font ttRegular) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Row(
    children: [
      pw.Text('$label:  ',
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,font: ttBold, fontSize: 10)),
      pw.Text(value,
          style:  pw.TextStyle(font: ttRegular, fontSize: 10)),
    ],
  ),
);

pw.Widget _infoRowRight(String label, String value,pw.Font ttBold,pw.Font ttRegular) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('$label:  ',
          style: pw.TextStyle(
            font: ttBold,
              fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.Text(value,
          style:  pw.TextStyle(font: ttRegular, fontSize: 10)),
    ],
  ),
);

pw.Widget _summaryRow(String label, String value, pw.Font ttBold, pw.Font ttRegular,
    {bool bold = false, PdfColor color = PdfColors.black}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                font: ttBold,
                  fontSize: 10,
                  fontWeight: bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  font: ttRegular,
                  fontSize: 10,
                  fontWeight: bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );