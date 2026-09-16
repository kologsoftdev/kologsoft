
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> printSalesStaffTransactionsPdf({
  required String staffName,
  required List<Map<String, dynamic>> sales,
  String companyName      = '',
  String branchName       = 'All Branches',
  DateTimeRange? dateRange,
}) async {
  final ttfRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final ttfBold    = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  final pdf = pw.Document(
    title: '$companyName Sales Staff Transactions Report',
    theme: pw.ThemeData.withFont(
  base: ttfRegular,
    bold: ttfBold,
    italic: ttfRegular,
    boldItalic: ttfBold,
  ),
  );



  const accent   = PdfColor.fromInt(0xFF1565C0);
  const headerBg = PdfColor.fromInt(0xFF1E3A5F);
  const rowAlt   = PdfColor.fromInt(0xFFF0F4FA);
  const white    = PdfColors.white;
  const dark     = PdfColor.fromInt(0xFF0D1B2A);

  double totalAmount   = 0;
  double totalDiscount = 0;
  for (final s in sales) {
    totalAmount   += (s['amount']   ?? 0).toDouble();
    totalDiscount += (s['discount'] ?? 0).toDouble();
  }

  pw.TextStyle boldWhite(double size) =>
      pw.TextStyle(font: ttfBold, color: white, fontWeight: pw.FontWeight.bold, fontSize: size);

  pw.TextStyle cellStyle({bool bold = false, PdfColor? color}) => pw.TextStyle(
    font: ttfRegular,

    fontSize: 8,
    color: color ?? dark,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

  final headers = [
    '#', 'Date', 'Receipt', 'Customer',
    'Items', 'Amount', 'Discount',
    'Payment', 'Branch', 'Mode',
  ];
  final widths = [
    20.0, 75.0, 75.0, 75.0,
    30.0, 55.0, 50.0,
    50.0, 55.0, 40.0,
  ];

  const int rowsPerPage = 20;
  final pageCount = (sales.length / rowsPerPage).ceil().clamp(1, 9999);

  for (int pageIdx = 0; pageIdx < pageCount; pageIdx++) {
    final pageRows = sales
        .skip(pageIdx * rowsPerPage)
        .take(rowsPerPage)
        .toList();
    final isLastPage = pageIdx == pageCount - 1;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            //Header banner
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: pw.BoxDecoration(
                color: headerBg,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(companyName.toUpperCase(), style: boldWhite(14)),
                      pw.SizedBox(height: 2),
                      pw.Text('Sales Staff Transactions Report',
                          style: pw.TextStyle(
                              color: PdfColors.blueGrey200, fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Text('Staff: ${staffName.toUpperCase()}',
                          style: boldWhite(9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Branch: $branchName', style: boldWhite(9)),
                      pw.SizedBox(height: 2),
                      if (dateRange != null)
                        pw.Text(
                          'Period: ${DateFormat('d MMM y').format(dateRange.start)}'
                              ' - ${DateFormat('d MMM y').format(dateRange.end)}',
                          style: pw.TextStyle(
                              color: PdfColors.blueGrey200,font: ttfRegular, fontSize: 8),
                        ),
                      pw.Text(
                        'Generated: ${DateFormat('d MMMM y').format(DateTime.now())}',
                        style: pw.TextStyle(
                            color: PdfColors.blueGrey200,font: ttfRegular, fontSize: 8),
                      ),
                      pw.Text('Page ${pageIdx + 1} of $pageCount',
                          style: pw.TextStyle(
                              color: PdfColors.blueGrey200,font: ttfRegular, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 10),

            // ── Summary bar
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Wrap(
                spacing: 24,
                children: [
                  pw.Text('Total Transactions: ${sales.length}',
                      style: boldWhite(9)),
                  pw.Text(
                      'Total Amount: GHC ${totalAmount.toStringAsFixed(2)}',
                      style: boldWhite(9)),
                  pw.Text(
                      'Total Discount: GHC ${totalDiscount.toStringAsFixed(2)}',
                      style: boldWhite(9)),
                ],
              ),
            ),

            pw.SizedBox(height: 6),

            // ── Table
            pw.Table(
              columnWidths: {
                for (int i = 0; i < widths.length; i++)
                  i: pw.FixedColumnWidth(widths[i]),
              },
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                    color: PdfColors.blueGrey100, width: 0.5),
                bottom: pw.BorderSide(
                    color: PdfColors.blueGrey200, width: 0.5),
              ),
              children: [

                // Column headers
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBg),
                  children: headers.map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    child: pw.Text(h,
                        style: boldWhite(8),
                        textAlign: pw.TextAlign.center),
                  )).toList(),
                ),

                // Data rows
                ...pageRows.asMap().entries.map((entry) {
                  final rowNum = pageIdx * rowsPerPage + entry.key + 1;
                  final s      = entry.value;
                  final isAlt  = entry.key.isOdd;


                  String formattedDate = '';
                  try {
                    final date = (s['datetime'] as Timestamp).toDate();
                    formattedDate =
                        DateFormat('yyyy-MM-dd  hh:mm a').format(date);
                  } catch (_) {
                    formattedDate = s['datetime']?.toString() ?? '';
                  }

                  final amount   = (s['amount']   ?? 0).toDouble();
                  final discount = (s['discount'] ?? 0).toDouble();

                  final cells = [
                    '$rowNum',
                    formattedDate,
                    '${s['receipt']  ?? ''}',
                    '${s['customer'] ?? ''}',
                    '${s['items']    ?? ''}',
                    'GHC ${amount.toStringAsFixed(2)}',
                    'GHC ${discount.toStringAsFixed(2)}',
                    '${s['payment']  ?? ''}',
                    '${s['branch']   ?? ''}',
                    '${s['mode']     ?? ''}',
                  ];

                  return pw.TableRow(
                    decoration: isAlt
                        ? const pw.BoxDecoration(color: rowAlt)
                        : null,
                    children: cells.asMap().entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 5),
                      child: pw.Text(
                        e.value,
                        style: cellStyle(bold: e.key == 5),
                        textAlign: (e.key == 1 || e.key == 2 ||
                            e.key == 3 || e.key == 7 ||
                            e.key == 8 || e.key == 9)
                            ? pw.TextAlign.left
                            : pw.TextAlign.right,
                      ),
                    )).toList(),
                  );
                }),

                // Totals row on last page
                if (isLastPage)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBg),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('TOTAL', style: boldWhite(8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'GHC ${totalAmount.toStringAsFixed(2)}',
                          style: boldWhite(8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'GHC ${totalDiscount.toStringAsFixed(2)}',
                          style: boldWhite(8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('', style: boldWhite(7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('', style: boldWhite(7))),
                    ],
                  ),
              ],
            ),

            pw.Spacer(),

            // ── Footer
            pw.Divider(color: PdfColors.blueGrey200, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential - $companyName',
                    style: pw.TextStyle(
                        fontSize: 7, font: ttfRegular, color: PdfColors.blueGrey400)),
                pw.Text('${staffName.toUpperCase()} | Sales Transactions',
                    style: pw.TextStyle(
                        fontSize: 7, font: ttfRegular, color: PdfColors.blueGrey400)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  await Printing.layoutPdf(
    onLayout: (_) async => pdf.save(),
    name: '${staffName}_sales_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}