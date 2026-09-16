import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class BranchBalancePdf {
  static Future<void> print({
    required List<Map<String, dynamic>> rows,
    required String companyName,
    required String branchLabel,
    required DateTime? dateFrom,
    required DateTime? dateTo,
  }) async {
    final pdf = pw.Document();
    final font      = await PdfGoogleFonts.nunitoRegular();
    final fontBold  = await PdfGoogleFonts.nunitoBold();
    final now       = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final dateRange = dateFrom == null
        ? 'All dates'
        : '${DateFormat('dd MMM yyyy').format(dateFrom)} – ${DateFormat('dd MMM yyyy').format(dateTo ?? DateTime.now())}';

    final fmt = NumberFormat('#,##0.##');
    String fmtNum(dynamic v) {
      final d = v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
      return fmt.format(d);
    }

    double grandTotalQty  = 0;
    double grandPurchase  = 0;
    double grandSelling   = 0;
    for (final r in rows) {
      grandTotalQty += (r['balance']          ?? 0.0) as double;
      grandPurchase += (r['purchase_value']   ?? 0.0) as double;
      grandSelling  += (r['selling_value']    ?? 0.0) as double;
    }

    const cols = [
      '#', 'Branch', 'Product', 'Total Qty', 'Purchase Value', 'Selling Value',
    ];
    final colWidths = [
      0.04, 0.15, 0.32, 0.13, 0.18, 0.18,
    ];

    pw.Widget headerCell(String text, {bool right = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
      ),
    );

    pw.Widget dataCell(String text, {bool right = false, bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: bold ? fontBold : font,
          fontSize: 7.5,
          color: PdfColors.grey900,
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName,
                        style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    pw.SizedBox(height: 2),
                    pw.Text('Branch Stock Balance Report',
                        style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Printed: $now',
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Period: $dateRange',
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Branch: $branchLabel',
                        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1.5, color: PdfColors.blueGrey800),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('KologSoft', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey400)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey400)),
          ],
        ),
        build: (ctx) => [
          // Summary cards
          pw.Row(
            children: [
              _summaryCard('Total Items', '${rows.length}', fontBold, font),
              pw.SizedBox(width: 8),
              _summaryCard('Total Qty', fmtNum(grandTotalQty), fontBold, font),
              pw.SizedBox(width: 8),
              _summaryCard('Purchase Value', fmtNum(grandPurchase), fontBold, font),
              pw.SizedBox(width: 8),
              _summaryCard('Selling Value', fmtNum(grandSelling), fontBold, font),
            ],
          ),
          pw.SizedBox(height: 12),

          // Table header
          pw.Table(
            columnWidths: {
              for (int i = 0; i < colWidths.length; i++)
                i: pw.FlexColumnWidth(colWidths[i]),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  headerCell(cols[0]),
                  headerCell(cols[1]),
                  headerCell(cols[2]),
                  headerCell(cols[3], right: true),
                  headerCell(cols[4], right: true),
                  headerCell(cols[5], right: true),
                ],
              ),
              ...rows.asMap().entries.map((e) {
                final i   = e.key;
                final row = e.value;
                final bg  = i.isEven ? PdfColors.white : const PdfColor(0.96, 0.97, 0.98);
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    dataCell('${i + 1}'),
                    dataCell(row['branch']?.toString() ?? ''),
                    dataCell(row['item']?.toString() ?? ''),
                    dataCell(fmtNum(row['balance']), right: true),
                    dataCell(fmtNum(row['purchase_value']), right: true),
                    dataCell(fmtNum(row['selling_value']), right: true),
                  ],
                );
              }),
              // Grand total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor(0.9, 0.93, 0.97)),
                children: [
                  dataCell('', bold: true),
                  dataCell('', bold: true),
                  dataCell('GRAND TOTAL', bold: true),
                  dataCell(fmtNum(grandTotalQty), right: true, bold: true),
                  dataCell(fmtNum(grandPurchase), right: true, bold: true),
                  dataCell(fmtNum(grandSelling), right: true, bold: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  static pw.Widget _summaryCard(String label, String value, pw.Font bold, pw.Font regular) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.93, 0.95, 0.98),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: const PdfColor(0.82, 0.86, 0.92)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 7, color: PdfColors.grey600)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 10)),
            ],
          ),
        ),
      );
}