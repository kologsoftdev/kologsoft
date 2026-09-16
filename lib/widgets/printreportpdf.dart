import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfColumn {
  final String label;
  final double width;
  const PdfColumn(this.label, {this.width = 50});
}

class PdfSummaryLine {
  final String label;
  final double value;
  final bool highlight; // green + bold
  const PdfSummaryLine(this.label, this.value, {this.highlight = false});
}


Future<void> printReportPdf({
  required BuildContext context,
  required String reportTitle,
  required String companyName,
  required List<PdfColumn> columns,
  required List<List<String>> rows,
  String branchName = 'All Branches',
  DateTimeRange? dateRange ,
  List<PdfSummaryLine> summaryLines = const [],
  List<String>? totalsRow,
  int rowsPerPage          = 28,
  PdfPageFormat pageFormat = PdfPageFormat.a4,
  bool landscape           = true,
}) async {
  final pdf = pw.Document(
    title: '$companyName - $reportTitle'
  );

  final ttfRegular =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final ttfBold =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  // ── Palette
  const headerBg  = PdfColor.fromInt(0xFF1E3A5F);
  const rowAlt    = PdfColor.fromInt(0xFFF0F4FA);
  const accentBg  = PdfColor.fromInt(0xFF1565C0);
  const totalsBg  = PdfColor.fromInt(0xFF0D2137);
  const dark      = PdfColor.fromInt(0xFF0D1B2A);
  const white     = PdfColors.white;
  const greenText = PdfColor.fromInt(0xFF2E7D32);

  pw.TextStyle boldWhite(double sz) =>
      pw.TextStyle(font: ttfBold, color: white, fontWeight: pw.FontWeight.bold, fontSize: sz);

  pw.TextStyle cellStyle({bool bold = false, PdfColor? color}) => pw.TextStyle(
    font: ttfRegular,
    fontSize: 7.5,
    color: color ?? dark,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

 Map<int, pw.TableColumnWidth> colWidths() => {
    for (int i = 0; i < columns.length; i++)
      i: pw.FlexColumnWidth(columns[i].width),
  };

  final pageCount = (rows.length / rowsPerPage).ceil().clamp(1, 9999);
  final format    = landscape ? pageFormat.landscape : pageFormat;

  for (int pageIdx = 0; pageIdx < pageCount; pageIdx++) {
    final pageRows = rows.skip(pageIdx * rowsPerPage).take(rowsPerPage).toList();
    final isLastPage = pageIdx == pageCount - 1;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

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
                      pw.Text(reportTitle,
                          style: pw.TextStyle(
                              font: ttfRegular,
                              color: PdfColors.blueGrey200, fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Branch: $branchName', style: boldWhite(9)),
                      if (dateRange != null)
                        pw.Text('Period: ${DateFormat('MMMM d, y').format(dateRange.start)} - ' '${DateFormat('MMMM d, y').format(dateRange.end)}',
                          style: pw.TextStyle(font: ttfRegular, color: PdfColors.blueGrey200, fontSize: 8,),),

                      pw.Text(
                        'Generated: ${DateFormat('MMMM d, y').format(DateTime.now())}',
                        style: pw.TextStyle(
                          font: ttfRegular,
                          color: PdfColors.blueGrey200,
                          fontSize: 7,
                        ),
                      ),

                      pw.Text('Page ${pageIdx + 1} of $pageCount',
                          style: pw.TextStyle(
                              font: ttfRegular,
                              color: PdfColors.blueGrey200, fontSize: 7)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

            if (pageIdx == 0 && summaryLines.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: accentBg,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: summaryLines.map((s) => pw.Text(
                    '${s.label}: GHC ${s.value.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      font: ttfRegular,
                      color: s.highlight ? const PdfColor.fromInt(0xFF90EE90) : white,
                      fontWeight: s.highlight
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      fontSize: 8,
                    ),
                  )).toList(),
                ),
              ),
              pw.SizedBox(height: 8),
            ],


            pw.Table(
              columnWidths: colWidths(),
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                    color: PdfColors.blueGrey100, width: 0.4),
                bottom: pw.BorderSide(
                    color: PdfColors.blueGrey300, width: 0.5),
              ),
              children: [


                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBg),
                  children: columns.map((col) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    child: pw.Text(
                      col.label,
                      style: boldWhite(7.5),
                      textAlign: pw.TextAlign.center,
                    ),
                  )).toList(),
                ),


                ...pageRows.asMap().entries.map((entry) {
                  final isAlt = entry.key.isOdd;
                  final cells = entry.value;

                  return pw.TableRow(
                    decoration: isAlt
                        ? const pw.BoxDecoration(color: rowAlt)
                        : null,
                    children: cells.asMap().entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: pw.Text(
                        e.value,
                        style: cellStyle(bold: e.key == 1),

                        textAlign: e.key <= 1
                            ? pw.TextAlign.left
                            : pw.TextAlign.right,
                      ),
                    )).toList(),
                  );
                }),


                if (isLastPage && totalsRow != null)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: totalsBg),
                    children: totalsRow.asMap().entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 5),
                      child: pw.Text(
                        e.value,
                        style: boldWhite(7.5),
                        textAlign: e.key <= 1
                            ? pw.TextAlign.left
                            : pw.TextAlign.right,
                      ),
                    )).toList(),
                  ),
              ],
            ),

            pw.Spacer(),


            if (isLastPage && summaryLines.any((s) => s.highlight)) ...[
              pw.SizedBox(height: 6),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFF1B4332),
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFF2D6A4F), width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: summaryLines
                        .where((s) => s.highlight)
                        .map((s) => pw.Text(
                      '${s.label}:  GHC ${s.value.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        font: ttfRegular,
                        color: const PdfColor.fromInt(0xFF90EE90),
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ))
                        .toList(),
                  ),
                ),
              ),
            ],

            pw.SizedBox(height: 4),


            pw.Divider(color: PdfColors.blueGrey300, thickness: 0.4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential  $companyName',
                    style: pw.TextStyle(
                      font: ttfRegular,
                        fontSize: 7, color: PdfColors.blueGrey400)),
                pw.Text('$reportTitle  |  $branchName',
                    style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: 7, color: PdfColors.blueGrey400)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  await Printing.layoutPdf(
    onLayout: (_) async => pdf.save(),
    name:
    '${reportTitle.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}