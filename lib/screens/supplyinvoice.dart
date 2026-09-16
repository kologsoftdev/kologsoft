import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

Future<void> generateInvoicePdf(data) async {
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

  // Calculate totals with proper type casting
  final grossTotal = (data['gross'] as num?)?.toDouble() ?? 0.0;
  final items = data['items'];
  final itemCount = items.fold<int>(0, (int sum, item) => sum + ((item['suppliedquantity'] as num?)?.toInt() ?? 0));

  // Get reference and notes if they exist
  final referenceNumber = data['reference'] ?? data['referencenumber'] ?? '';
  final notes = data['notes'] ?? data['generalnotes'] ?? '';

  pdf.addPage(
    pw.Page(
      margin: pw.EdgeInsets.all(30),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
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
                      "STOCK SUPPLY INVOICE",
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

            // Reference Number Section (if exists)
            if (referenceNumber.isNotEmpty) ...[
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  children: [
                    //pw.Icon(pw.Icons.receipt, size: 16, color: PdfColors.blue700),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      "Reference: ",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      referenceNumber,
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // Company & Transfer Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // From Warehouse Section
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "From: ${data['warehousename'] ?? 'Not Specified'}",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),

                    pw.SizedBox(height: 8),
                    pw.Text(
                      "To: ${data['branch'] ?? 'Not Specified'}",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                  ],
                ),

                // Transfer Details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          "Date: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(dateFormat.format(timestamp)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Time: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(timeFormat.format(timestamp)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Staff: ",
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(data['suppliedby'] ?? 'Unknown'),
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
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1.5), // Item
                2: pw.FlexColumnWidth(1.5), // mode
                3: pw.FlexColumnWidth(1.5), // reqQty
                4: pw.FlexColumnWidth(1.5), // supQty
                5: pw.FlexColumnWidth(1.5), // remarks
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _headerCell('Item Description'),
                    _headerCell('Mode'),
                    _headerCell('Requested'),
                    _headerCell('Supplied'),
                    _headerCell('Remarks'),
                  ],
                ),

                // Table Rows
                ...items.map((item) {
                  final requestedquantity = (item['requestedquantity'] as num?)?.toInt() ?? 0;
                  final suppliedquantity = (item['suppliedquantity'] as num?)?.toInt() ?? 0;
                  final mode = item['mode'];
                  final remarks = item['supplystatus'];

                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      _bodyCell(item['item']?.toString() ?? 'N/A'),
                      _bodyCellCenter(mode.toString()),
                      _bodyCellRight(requestedquantity.toString()),
                      _bodyCellRight(suppliedquantity.toString()),
                      _bodyCell(remarks.toString()),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 30),

            // Notes Section (if exists)
            if (notes.isNotEmpty) ...[
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        //pw.Icon(pw.Icons.note, size: 16, color: PdfColors.blue700),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          "Notes:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      notes,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Summary Section
            // pw.Container(
            //   alignment: pw.Alignment.centerRight,
            //   child: pw.Container(
            //     width: 250,
            //     padding: pw.EdgeInsets.all(16),
            //     decoration: pw.BoxDecoration(
            //       color: PdfColors.grey50,
            //       borderRadius: pw.BorderRadius.circular(8),
            //       border: pw.Border.all(color: PdfColors.grey300),
            //     ),
            //     child: pw.Column(
            //       crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            //       children: [
            //         pw.Row(
            //           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            //           children: [
            //             pw.Text(
            //               "Total Items:",
            //               style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            //             ),
            //             pw.Text(itemCount.toString()),
            //           ],
            //         ),
            //         pw.SizedBox(height: 8),
            //         pw.Divider(),
            //         pw.SizedBox(height: 8),
            //       ],
            //     ),
            //   ),
            // ),

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
        );
      },
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