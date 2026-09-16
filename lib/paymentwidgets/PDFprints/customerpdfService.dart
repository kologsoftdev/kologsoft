import 'dart:io';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import 'customerinforeceipt.dart';

Future<void> printReceiptPDF({
  required String companyName,
  required String receiptNumber,
  required String cashierName,
  required List salesItems,
  required double total,
  required double totalDiscount,
  required String customerName,
  required String phone,
  required String paymentLabel,
  required String bankName,
  required String reference,
}) async {

  final pdf = pw.Document();
  final now = DateTime.now();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (context) {
        return buildReceiptLayout(
          companyName: companyName,
          receiptNumber: receiptNumber,
          cashierName: cashierName,
          now: now,
          salesItems: salesItems,
          total: total,
          totalDiscount: totalDiscount,
          customerName: customerName,
          phone: phone,
          paymentLabel: paymentLabel,
          bankName: bankName,
          reference: reference,
        );
      },
    ),
  );

  /// WEB PRINT
  if (kIsWeb) {

    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final iframe = html.document.createElement('iframe') as html.IFrameElement
      ..src = url
      ..style.display = 'none';

    html.document.body?.children.add(iframe);

    iframe.onLoad.listen((_) {
      (iframe.contentWindow as dynamic).print();
    });

  } else {

    /// MOBILE / DESKTOP SHARE
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/receipt_$receiptNumber.pdf');

    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Receipt #$receiptNumber - Total: GHS ${total.toStringAsFixed(2)}',
    );
  }
}