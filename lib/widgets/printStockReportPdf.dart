import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


Future<void> printStockReportPdf({ required List<Map<String, dynamic>> reportData,required String companyName,  String branchName = 'All Branches',  String dateRange  = '',}) async {
  final pdf = pw.Document();

 const headerBg = PdfColor.fromInt(0xFF1E3A5F);
  const rowAlt   = PdfColor.fromInt(0xFFF0F4FA);
  const accent   = PdfColor.fromInt(0xFF1565C0);
  const dark     = PdfColor.fromInt(0xFF0D1B2A);
  const white    = PdfColors.white;
  final ttfRegular =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final ttfBold =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

  final bool showTransfers = branchName != 'All Branches';
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

  final headers = [
    '#', 'Product', 'Opening\nStock', 'New\nStock',
    if (showTransfers) 'Transfer\nIn',
    'Sale\nReturns', 'Total', 'Sales\nQty',

    'Purchase\nReturns', 'Damages',
    if (showTransfers) 'Transfer',
     'Balance', 'Carton',
  ];
  final colWidths = [
    18.0, 90.0, 38.0, 35.0,   if (showTransfers) 38.0,
    38.0, 35.0, 35.0, 38.0,
    38.0, 42.0, 35.0,   if (showTransfers) 35.0, 35.0, 40.0,
  ];
  double totOpening = 0, totNew = 0, totTransferIn = 0, totSaleReturns = 0;
  double totTotal = 0, totSalesQty = 0, totCash = 0, totCredit = 0;
  double totPurchaseRet = 0, totDamages = 0, totTransfer = 0, totBalance = 0;

  for (final item in reportData) {
    totOpening += (item['opening_stock'] ?? 0).toDouble();
    totNew += (item['newstock'] ?? 0).toDouble();
    totTransferIn += (item['transfer_recieved_qty'] ?? 0).toDouble();
    totSaleReturns  += (item['sale_returns']          ?? 0).toDouble();
    totTotal        += (item['total_stock']           ?? 0).toDouble();
    totSalesQty     += (item['sales_qty']             ?? 0).toDouble();
    totCash         += (item['cash_sales']            ?? 0).toDouble();
    totCredit       += (item['credit_sales']          ?? 0).toDouble();
    totPurchaseRet  += (item['purchase_returns']      ?? 0).toDouble();
    totDamages      += (item['damages']               ?? 0).toDouble();
    totTransfer     += (item['transfer_qty']          ?? 0).toDouble();
    totBalance      += (item['balance_cd']            ?? 0).toDouble();
  }

  const int rowsPerPage = 25;
  final pageCount = ((reportData.length) / rowsPerPage).ceil().clamp(1, 9999);

  for (int pageIdx = 0; pageIdx < pageCount; pageIdx++) {
    final pageRows = reportData
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
                      pw.Text('Stock Report', style: pw.TextStyle(
                        font: ttfBold,
                          color: PdfColors.blueGrey200, fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Branch: $branchName', style: boldWhite(9)),
                      if (dateRange.isNotEmpty)
                        pw.Text('Period: $dateRange',
                            style: pw.TextStyle(
                              font: ttfRegular,
                                color: PdfColors.blueGrey200, fontSize: 8)),

                      pw.Text(
                        'Generated:  ${DateFormat('d MMMM y').format(DateTime.now())}',
                        style: pw.TextStyle(
                          font: ttfRegular,
                            color: PdfColors.blueGrey200, fontSize: 8),
                      ),
                      pw.Text('Page ${pageIdx + 1} of $pageCount',
                          style: pw.TextStyle(
                              font: ttfRegular,
                              color: PdfColors.blueGrey200, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

            //Summary bar
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Wrap(
                spacing: 20,
                children: [
                  pw.Text('Products: ${reportData.length}', style: boldWhite(8)),
                  pw.Text('Total Sales Qty: ${fmt(totSalesQty)}', style: boldWhite(8)),

                  pw.Text('Closing Balance: ${fmt(totBalance)}', style: boldWhite(8)),
                ],
              ),
            ),

            pw.SizedBox(height: 8),

            //Table
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

                //Column headers
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

                //Data rows
                ...pageRows.asMap().entries.map((entry) {
                  final rowNum  = pageIdx * rowsPerPage + entry.key + 1;
                  final item    = entry.value;
                  final isAlt   = entry.key.isOdd;

                  final balanceCd  = (item['balance_cd'] ?? 0).toDouble();
                  final boxPiece   = double.tryParse(
                      item['cartonqty_bal'].toString()) ?? 1;
                  final carton     = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

                  final values = [
                    '$rowNum',
                    item['item']?.toString() ?? '',
                    fmt(item['opening_stock']),
                    fmt(item['newstock']),
                    if (showTransfers) fmt(item['transfer_recieved_qty']),
                    fmt(item['sale_returns']),
                    fmt(item['total_stock']),
                    fmt(item['sales_qty']),

                    fmt(item['purchase_returns']),
                    fmt(item['damages']),
                    if (showTransfers) fmt(item['transfer_qty']),
                    fmt(balanceCd),
                    carton > 0 ? fmt(carton) : '-',
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
                          // Bold the product name and balance
                          bold: e.key == 1 || e.key == 14,
                          // Red if balance is 0
                          color: (e.key == 14 && balanceCd <= 0)
                              ? PdfColors.red700
                              : null,
                        ),
                        textAlign: e.key == 1
                            ? pw.TextAlign.left
                            : pw.TextAlign.right,
                      ),
                    )).toList(),
                  );
                }),

                //Totals row (last page only)
                if (pageIdx == pageCount - 1)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBg),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('', style: boldWhite(7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('TOTAL', style: boldWhite(7)),
                      ),
                      ...[ totOpening, totNew,   if (showTransfers) totTransferIn, totSaleReturns,
                        totTotal, totSalesQty,

                        totPurchaseRet, totDamages,   if (showTransfers) totTransfer, 0, totBalance,
                      ].map((v) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          fmt(v),
                          style: boldWhite(7),
                          textAlign: pw.TextAlign.right,
                        ),
                      )),
                    ],
                  ),
              ],
            ),

            pw.Spacer(),

            //Footer
            pw.Divider(color: PdfColors.blueGrey200, thickness: 0.4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential \u002D $companyName',
                    style: pw.TextStyle(
                      font: ttfRegular,
                        fontSize: 7, color: PdfColors.blueGrey400)),
                pw.Text('Stock Report | $branchName',
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
    name: 'stock_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}