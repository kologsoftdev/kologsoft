import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

Future<void> newStockInvoicePdf(Map<String, dynamic> data, List<Map<String, dynamic>> items) async {
  final pdf = pw.Document();

  // Format currency
  final currencyFormat = NumberFormat.currency(
    symbol: 'GHC ',
    decimalDigits: 2,
  );

  // Format date
  final dateFormat = DateFormat('dd MMM yyyy');
  final timeFormat = DateFormat('hh:mm a');
  final timestamp = (data['createdat'] as Timestamp).toDate();
  final invoicedate = (data['invoicedate'] as Timestamp).toDate();

  // Calculate totals with proper type casting
  final grossTotal = (data['gross'] as num?)?.toDouble() ?? 0.0;
  final itemCount = items.length.toInt();

  pdf.addPage(
    pw.MultiPage(
      margin: pw.EdgeInsets.all(30),
      build: (pw.Context context) => [

            // Header Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      "${data['company']}",
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "STOCK ENTRY INVOICE",
                      style: pw.TextStyle(
                        fontSize: 20,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.Divider(height: 30, thickness: 1),

            // Company & Transfer Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // From Warehouse Section
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          "Invoice Number: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(data['invoice'] ?? 'N/A'),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Waybill Number: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(data['waybill'] ?? 'N/A'),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Supplier: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(data['suppliername'] ?? 'Unknown'),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Mode: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(data['purchasetype'] ?? 'Unknown'),
                      ],
                    ),
                  ],
                ),

                // Transfer Details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          "Branch: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(data['branchname'] ?? 'Not Specified'),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Date: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text("${dateFormat.format(invoicedate)}"),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Staff: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(data['createdby'] ?? 'Unknown'),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              columnWidths: {
                0: pw.FlexColumnWidth(3), // Item
                1: pw.FlexColumnWidth(1), // mode
                2: pw.FlexColumnWidth(1.5), // modeqty
                2: pw.FlexColumnWidth(1.5), // qty
                3: pw.FlexColumnWidth(1.5), // Price
                4: pw.FlexColumnWidth(1.5), // Total
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _headerCell('ITEM DESCRIPTION'),
                    _headerCell('MODE'),
                    _headerCell('QTY'),
                    _headerCell('PCS'),
                    _headerCell('UNIT PRICE'),
                    _headerCell('TOTAL'),
                  ],
                ),

                // Table Rows
                ...items.map((item) {
                  final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
                  final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                  final total = (item['total'] as num?)?.toDouble() ?? 0.0;
                  final pieces = (item['pieces'] as num?)?.toDouble() ?? 0.0;

                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      _bodyCell(item['item']?.toString() ?? 'N/A'),
                      _bodyCellCenter(item['stockingmode']?.toString() ?? 'N/A'),
                      _bodyCellRight(quantity.toString()),
                      _bodyCellRight(pieces.toString()),
                      _bodyCellRight(item['price']?.toStringAsFixed(2) ?? 'N/A'),
                      _bodyCellRight(total.toStringAsFixed(2)),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 30),

            // Summary Section
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 250,
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "Total Items:",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(itemCount.toString()),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "TOTAL:",
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          currencyFormat.format(grossTotal),
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 40),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}",
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),

              ],
            ),
          ],
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}

// Helper methods for table cells
pw.Widget _headerCell(String text) {
  return pw.Container(
    padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 11,
        color: PdfColors.blue900,
      ),
    ),
  );
}

pw.Widget _bodyCell(String text) {
  return pw.Container(
    padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 11),
    ),
  );
}

pw.Widget _bodyCellCenter(String text) {
  return pw.Container(
    padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 11),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _bodyCellRight(String text) {
  return pw.Container(
    padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 11),
      textAlign: pw.TextAlign.right,
    ),
  );
}