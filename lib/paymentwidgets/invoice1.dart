

import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../models/Receiptdatamodel.dart';

class ReceiptPrinter {
  static PdfPageFormat getFormat(String size) {
    switch (size.toLowerCase()) {
      case 'thermal':
      case '80mm':
      case '58mm':
        return PdfPageFormat(72.1 * PdfPageFormat.mm, 5000 * PdfPageFormat.mm);
      case 'a4':
      default:
        return PdfPageFormat.a4;
    }
  }

  PdfPageFormat _sanitizeFormat(PdfPageFormat format) {
    final width = (format.width.isFinite && format.width > 0)
        ? format.width
        : 72.1 * PdfPageFormat.mm;
    final height = (format.height.isFinite && format.height > 0)
        ? format.height
        : 5000 * PdfPageFormat.mm;
    return PdfPageFormat(width, height);
  }

  Future<pw.Document> buildPdf(
      ReceiptData data, {
        PdfPageFormat pageFormat = PdfPageFormat.a4,
      }) async {
    pageFormat = _sanitizeFormat(pageFormat);

    final ttfRegular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final ttfBold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final doc = pw.Document(title: data.transactionId);

    final isThermal = pageFormat.width <= 80 * PdfPageFormat.mm;
    final pageMargin = isThermal ? 0.0 : 10.0;
    final cardPadding = isThermal ? 4.0 : 14.0;
    final qrSize = (pageFormat.width - (pageMargin * 2) - (cardPadding * 2)) *
        (isThermal ? 0.2 : 0.18);
    final barcodeWidth = (pageFormat.width - (pageMargin * 2) - (cardPadding * 2)) *
        (isThermal ? 0.85 : 0.5);
    final barcodeHeight = isThermal ? 36.0 : 44.0;
    final now = DateTime.now();
    final isChristmas = now.month == 12;
    final cashierName = data.cashier.trim().split(' ').first;
    final receiptTitle = data.receiptName.trim().isEmpty
        ? 'SALES RECEIPT'
        : data.receiptName.toUpperCase();
    final companyName = data.companyName.trim().toUpperCase();
    final branchName = (data.branch ?? '').trim();
    final address = (data.address ?? '').trim();
    final customerName = data.customername.trim().isEmpty
        ? 'Cash Customer'
        : data.customername.trim();
    final hasEmail = data.email.trim().isNotEmpty;
    final barcodeText = data.barcode.trim().isNotEmpty
        ? data.barcode.trim()
        : data.receiptNumber;

    final receiptContent = pw.Container(
      decoration: isThermal
          ? null
          : pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
      ),
      padding: pw.EdgeInsets.all(cardPadding),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              receiptTitle,
              style: pw.TextStyle(font: ttfBold, fontSize: 16, color: PdfColors.black),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              companyName,
              style: pw.TextStyle(font: ttfBold, fontSize: 12),
            ),
          ),
          pw.SizedBox(height: 0),
          pw.Divider(color: PdfColors.grey300, thickness: 0.8),
          pw.SizedBox(height: 0),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (branchName.isNotEmpty)
                      pw.Text('Branch: $branchName', style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
                    if (address.isNotEmpty)
                      pw.Text('Address: $address', style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
                    pw.Text('Contact: ${data.contact}', style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
                    // if (hasEmail)
                    //   pw.Text('Email: ${data.email}', style: pw.TextStyle(font: ttfRegular, fontSize: 9)),

                    pw.Text('Receipt: ${data.receiptNumber}', style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
                    pw.Text('Date: ${_formatPdfDate(data.datetime)}', style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
                    pw.Text('Cashier: $cashierName', style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
                    pw.Text('Customer: $customerName', style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
                    pw.SizedBox(height:6),
                    pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // pw.BarcodeWidget(
                          //   barcode: pw.Barcode.code128(),
                          //   data: barcodeText,
                          //   width: barcodeWidth,
                          //   height: barcodeHeight,
                          //   drawText: false,
                          // ),
                          pw.SizedBox(height: 2),
                          pw.SizedBox(
                            width: barcodeWidth,
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: barcodeText.split('').map((char) {
                                return pw.Text(
                                  char,
                                  style: pw.TextStyle(font: ttfRegular, fontSize: 8),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height:4),
                  ],
                ),
              ),

            ],
          ),
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Qty', 'Price', 'Total'],
            data: data.items.map((i) {
              final qtyText = i.qty == i.qty.roundToDouble()
                  ? i.qty.toStringAsFixed(0)
                  : i.qty.toStringAsFixed(2);
              final itemText = (i.isService || i.mode.trim().isEmpty)
                  ? i.name
                  : '${i.name} (${i.mode})';
              // final itemText = i.mode.trim().isEmpty
              //     ? i.name
              //     : '${i.name} (${i.mode})';
              return [
                itemText,
                qtyText,
                i.price.toStringAsFixed(2),
                (i.qty * i.price).toStringAsFixed(2),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(font: ttfBold, fontSize: 9),
            cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.3),
              3: const pw.FlexColumnWidth(1.4),
            },
            border: pw.TableBorder(
              top: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.3),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Column(
              children: [
                _pdfSummaryRow('Sub total', data.subTotal, ttfRegular, ttfBold),
                _pdfSummaryRow('Discount', data.discount, ttfRegular, ttfBold),
                //_pdfSummaryRow('VAT (${data.vatPercent}%)', data.vatAmount, ttfRegular, ttfBold),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                _pdfSummaryRow('Payable', data.payable, ttfRegular, ttfBold, bold: true),
                _pdfSummaryRow('Paid', data.amountPaid, ttfRegular, ttfBold),
                _pdfSummaryRow('Change', data.change < 0 ? 0.0 : data.change, ttfRegular, ttfBold, bold: true),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 2),
          pw.Text(
            isChristmas
                ? 'Thank you for choosing $companyName. Happy Christmas!'
                : 'Thank you for choosing $companyName!',
            style: pw.TextStyle(font: ttfRegular, fontSize: 9),
            textAlign: pw.TextAlign.left,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Exchanges accepted within 7 days. No cash refund.',
            style: pw.TextStyle(font: ttfBold, fontSize: 8, color: PdfColors.red),
            textAlign: pw.TextAlign.left,
          ),

          pw.Text(
            'POWERED BY KOLOGSOFT',
            style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: PdfColors.grey700),
            textAlign: pw.TextAlign.left,
          ),

          pw.Align(
            alignment: pw.Alignment.bottomCenter,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: barcodeText,
                  width: qrSize,
                  height: qrSize,
                ),


              ],
            ),
          ),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.symmetric(vertical: pageMargin, horizontal: pageMargin),
        build: (pw.Context context) {
          return [receiptContent];
        },
      ),
    );

    return doc;
  }

  pw.Widget _pdfSummaryRow(String title, double amount, pw.Font fontRegular, pw.Font fontBold,
      {bool bold = false}) {
    final font = bold ? fontBold : fontRegular;
    final weight = bold ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(title, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: weight)),
      pw.Text(amount.toStringAsFixed(2),
          style: pw.TextStyle(font: font, fontSize: 10, fontWeight: weight)),
    ]);
  }

  String _formatPdfDate(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}.${date.millisecond.toString().padLeft(3, '0')} $ampm';
  }
}