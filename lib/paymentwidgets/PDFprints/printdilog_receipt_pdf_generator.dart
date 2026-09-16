import 'dart:io';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

Future<void> generateAndPrintReceipt({
  required String companyName,
  required String receiptNumber,
  required String cashierName,
  required List salesItems,
  required double total,
  required double totalDiscount,
  required double amountPaid,
  required double change,
  required DateTime now,
}) async {

  /// LOAD FONTS
  final ttfRegular =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final ttfBold =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

  /// CREATE DOCUMENT
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            /// HEADER
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    companyName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 18,
                      font: ttfRegular,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 3),

                  pw.Text(
                    'SALES RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 16,
                      font: ttfBold,
                    ),
                  ),

                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),

            /// RECEIPT DETAILS
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Receipt #:', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                  receiptNumber,
                  style: pw.TextStyle(fontSize: 10, font: ttfBold),
                ),
              ],
            ),

            pw.SizedBox(height: 2),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date:', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                  '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),

            pw.SizedBox(height: 2),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Cashier:', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(cashierName, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),

            pw.SizedBox(height: 8),
            pw.Divider(),

            /// ITEMS
            pw.SizedBox(height: 5),

            ...salesItems.map((item) {

              final lineDiscount =
                  double.tryParse(item['discount']?.toString() ?? '0') ?? 0;

              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [

                    pw.Text(
                      item['item'] ?? '',
                      style: pw.TextStyle(fontSize: 11, font: ttfBold),
                    ),

                    pw.SizedBox(height: 2),

                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${item['quantity']} x GHS ${item['price']}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'GHS ${item['totalamount']}',
                          style: pw.TextStyle(fontSize: 10, font: ttfBold),
                        ),
                      ],
                    ),

                    if (lineDiscount > 0)
                      pw.Text(
                        'Discount: GHS ${lineDiscount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2),

            /// TOTALS
            if (totalDiscount > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DISCOUNT', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text(
                    '- GHS ${totalDiscount.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),

            pw.SizedBox(height: 5),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(fontSize: 14, font: ttfBold)),
                pw.Text(
                  'GHS ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 14, font: ttfBold),
                ),
              ],
            ),

            pw.SizedBox(height: 5),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Amount Paid', style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                  'GHS ${amountPaid.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),

            pw.SizedBox(height: 5),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('CHANGE',
                    style: pw.TextStyle(fontSize: 13, font: ttfBold)),
                pw.Text(
                  'GHS ${change.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 13, font: ttfBold),
                ),
              ],
            ),

            pw.SizedBox(height: 12),
            pw.Divider(thickness: 2),

            /// FOOTER
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for your business!',
                    style: pw.TextStyle(fontSize: 11, font: ttfBold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Powered by KologSoft',
                    style:  pw.TextStyle(
                      fontSize: 8,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  /// PRINT HANDLING

  if (kIsWeb) {
    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final iframe = html.document.createElement('iframe') as html.IFrameElement
      ..src = url
      ..style.display = 'none';

    html.document.body?.children.add(iframe);

    iframe.onLoad.listen((_) {
      try {
        final contentWindow = iframe.contentWindow;
        if (contentWindow != null) {
          (contentWindow as dynamic).print();
        }
      } catch (_) {}

      Future.delayed(const Duration(seconds: 2), () {
        html.document.body?.children.remove(iframe);
        html.Url.revokeObjectUrl(url);
      });
    });

  } else {

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/receipt_$receiptNumber.pdf');

    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Receipt #$receiptNumber - Total: GHS ${total.toStringAsFixed(2)}',
    );
  }
}