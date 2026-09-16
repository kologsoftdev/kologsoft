// salesreturnpdf.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class SalesReturnPdf {
  static Future<void> generate({
    required Map<String, dynamic> header,
    required Map<String, dynamic> itemsMap,
  }) async {
    final pdf = pw.Document(
      title: 'Sales Return - ${header['receiptid'] ?? ''}',
      author: header['createdby'] ?? '',
    );

    final ttfRegular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final ttfBold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final timestamp = header['createdat'];
    final DateTime date = timestamp is Timestamp
        ? timestamp.toDate()
        : timestamp is DateTime
        ? timestamp
        : DateTime.now();

    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    // All items as list, already remapped (plain keys)
    final List<Map<String, dynamic>> items =
    itemsMap.values.whereType<Map<String, dynamic>>().toList();

    // Grand total from returned_totalamount (already remapped → totalamount)
    final double grandTotal = items.fold(0.0, (sum, item) {
      return sum +
          (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
    });

    // ── Colors ──
    const headerBg = PdfColor.fromInt(0xFF1B263B);
    const accentColor = PdfColor.fromInt(0xFFFFCA28); // amber
    const dividerColor = PdfColor.fromInt(0xFFDDDDDD);
    const lightGrey = PdfColor.fromInt(0xFFF5F5F5);
    const darkText = PdfColor.fromInt(0xFF1A1A2E);
    const mutedText = PdfColor.fromInt(0xFF666666);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        build: (context) => [
          //HEADER
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          (header['company'] ?? '').toString().toUpperCase(),
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 20,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          header['branchname']?.toString() ?? '',
                          style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 12,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: accentColor,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            'SALES RETURN',
                            style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 11,
                              color: darkText,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          dateFormat.format(date),
                          style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 11,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          timeFormat.format(date),
                          style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.white, thickness: 0.5),
                pw.SizedBox(height: 12),

                // Receipt + Staff row
                pw.Row(
                  children: [
                    _infoChip(
                      ttfRegular: ttfRegular,
                      ttfBold: ttfBold,
                      label: 'RECEIPT',
                      value:
                      '#${header['receiptid']?.toString() ?? ''}',
                    ),
                    pw.SizedBox(width: 16),
                    _infoChip(
                      ttfRegular: ttfRegular,
                      ttfBold: ttfBold,
                      label: 'STAFF',
                      value: header['createdby']?.toString() ?? '',
                    ),
                    pw.SizedBox(width: 16),
                    _infoChip(
                      ttfRegular: ttfRegular,
                      ttfBold: ttfBold,
                      label: 'TRANS MODE',
                      value: (header['transmode'] ?? '').toString().toUpperCase(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ── ITEMS TABLE ──────────────────────────────────────
          pw.Text(
            'RETURNED ITEMS',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 11,
              color: mutedText,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder(
              bottom: pw.BorderSide(color: dividerColor, width: 0.5),
              horizontalInside:
              pw.BorderSide(color: dividerColor, width: 0.3),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.4),  // #
              1: pw.FlexColumnWidth(2.8),  // Item
              2: pw.FlexColumnWidth(0.8),  // Qty
              3: pw.FlexColumnWidth(0.9),  // Mode
              4: pw.FlexColumnWidth(0.9),  // Price
              5: pw.FlexColumnWidth(0.9),  // Total
              6: pw.FlexColumnWidth(1.2),  // Condition
            },
            children: [
              // Table header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: lightGrey),
                children: [
                  _th('#', ttfBold),
                  _th('ITEM', ttfBold),
                  _th('QTY', ttfBold),
                  _th('MODE', ttfBold),
                  _th('PRICE', ttfBold),
                  _th('TOTAL', ttfBold),
                  _th('CONDITION', ttfBold),
                ],
              ),
              // Data rows
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isEven = i % 2 == 0;

                final qty = item['quantity']?.toString() ?? '0';
                final mode = item['mode']?.toString() ?? '';
                final price = item['price']?.toString() ?? '0';
                final total = item['totalamount']?.toString() ?? '0';
                final condition = item['condition']?.toString() ?? '';
                final itemName = item['item']?.toString() ?? '';

                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : lightGrey,
                  ),
                  children: [
                    _td('${i + 1}', ttfRegular, center: true),
                    _td(itemName, ttfBold),
                    _td(qty, ttfRegular, center: true),
                    _td(mode, ttfRegular),
                    _td('GHC $price', ttfRegular),
                    _td('GHC $total', ttfBold),
                    _tdCondition(condition, ttfRegular),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          // ── TOTAL SECTION ────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: headerBg,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Items Returned:',
                        style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 11,
                            color: PdfColors.white),
                      ),
                      pw.Text(
                        '${items.length}',
                        style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 11,
                            color: PdfColors.white),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.white, thickness: 0.5),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL RETURN:',
                        style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 13,
                            color: accentColor),
                      ),
                      pw.Text(
                        'GHC ${grandTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 14,
                            color: PdfColors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 24),

          // ── FOOTER
          pw.Divider(color: dividerColor, thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'This is a computer-generated sales return document.',
              style: pw.TextStyle(
                  font: ttfRegular, fontSize: 9, color: mutedText),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  // ── Helpers

  static pw.Widget _infoChip({
    required pw.Font ttfRegular,
    required pw.Font ttfBold,
    required String label,
    required String value,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
              font: ttfRegular, fontSize: 8, color: PdfColors.white),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
              font: ttfBold, fontSize: 11, color: PdfColors.white),
        ),
      ],
    );
  }

  static pw.Widget _th(String text, pw.Font ttfBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: ttfBold,
          fontSize: 9,
          color: const PdfColor.fromInt(0xFF333333),
        ),
      ),
    );
  }

  static pw.Widget _td(String text, pw.Font font,
      {bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: const PdfColor.fromInt(0xFF222222),
        ),
      ),
    );
  }

  static pw.Widget _tdCondition(String condition, pw.Font font) {
    // Color-code condition
    PdfColor bg = const PdfColor.fromInt(0xFFE8F5E9);
    PdfColor fg = const PdfColor.fromInt(0xFF2E7D32);

    if (condition.toLowerCase().contains('damage')) {
      bg = const PdfColor.fromInt(0xFFFFEBEE);
      fg = const PdfColor.fromInt(0xFFC62828);
    } else if (condition.toLowerCase().contains('expir')) {
      bg = const PdfColor.fromInt(0xFFFFF3E0);
      fg = const PdfColor.fromInt(0xFFE65100);
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Container(
        padding:
        const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          condition,
          style: pw.TextStyle(font: font, fontSize: 8, color: fg),
        ),
      ),
    );
  }
}