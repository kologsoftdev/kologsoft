// damage_report_pdf.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class DamageReportPdf {
  /// Generates and prints a damage report with numbered rows
  static Future<void> generate({
    required Map<String, dynamic> header,
    required Map<String, dynamic> itemsMap,
  }) async {
    final pdf = pw.Document(title: header['company'],author:header['staff'] );
    final ttfRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final ttfBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final timestamp =  (header['createdat']) ?? DateTime.now();

    // Convert items map (item_0, item_1, ...) to list
    final List<Map<String, dynamic>> items =
    itemsMap.values.whereType<Map<String, dynamic>>().toList();

    // Calculate grand total
    double grandTotal = 0;

    for (final item in items) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;

      final itemCost = cp * qty;

      grandTotal += itemCost;
    }

    final dateFormat = DateFormat('dd MMM yyyy');
    final DateTime date =    timestamp is DateTime ? timestamp : timestamp.toDate();
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  header['company']?.toString() ?? '',
                  style: pw.TextStyle(
                    fontSize: 22,
                    font: ttfBold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'DAMAGE REPORT',
                  style: pw.TextStyle(fontSize: 16,font: ttfRegular),
                ),
              ),
              pw.SizedBox(height: 20),

              // Meta info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Branch: ${header['branchname'] ?? ''}',style: pw.TextStyle(font: ttfRegular)),
                  pw.Text('Date: ${dateFormat.format(date)}', style: pw.TextStyle(font: ttfRegular), )
                ],
              ),
              pw.Text('Staff: ${header['createdby'] ?? ''}',style: pw.TextStyle(font: ttfRegular)),
              pw.SizedBox(height: 20),

              // Table with numbering column
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5), // No.
                  1: const pw.FlexColumnWidth(3),   // Item
                  2: const pw.FlexColumnWidth(1),   // Qty
                  3: const pw.FlexColumnWidth(1),   // Mode
                  4: const pw.FlexColumnWidth(1),   // Price
                  5: const pw.FlexColumnWidth(1.2), // Total
                  6: const pw.FlexColumnWidth(2),   // Reason
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _cellHeader('No.', ttBold: ttfBold),
                      _cellHeader('ITEM', ttBold: ttfBold),
                      _cellHeader('QTY', ttBold: ttfBold),
                      _cellHeader('MODE', ttBold: ttfBold),
                      _cellHeader('MODE QTY', ttBold: ttfBold),
                      _cellHeader('COST', ttBold: ttfBold),
                      _cellHeader('TOTAL', ttBold: ttfBold),
                      _cellHeader('REASON', ttBold: ttfBold),
                    ],
                  ),
                  // Data rows
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
                    final qty = double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
                    final itemCost = cp * qty;
                    return pw.TableRow(
                      children: [
                        _cell((index + 1).toString(),ttfRegular: ttfRegular), // numbering
                        _cell(item['item'],ttfRegular: ttfRegular),
                        _cell(item['quantity'],ttfRegular: ttfRegular),
                        _cell(item['mode'],ttfRegular: ttfRegular),
                        _cell(item['modeqty'],ttfRegular: ttfRegular),
                        _cell(item['cp'],ttfRegular: ttfRegular),
                        _cell(itemCost.toStringAsFixed(2), ttfRegular: ttfRegular),
                        _cell(item['reason'],ttfRegular: ttfRegular),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // Total
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'TOTAL DAMAGE VALUE: GHC ${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    font: ttfBold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Print or preview
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Table cell helper
  static pw.Widget _cell(dynamic value, {pw.Font? ttfRegular}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(value?.toString() ?? '',style: pw.TextStyle(font: ttfRegular)),
    );
  }

  /// Table header cell helper
  static pw.Widget _cellHeader(String text, {pw.Font? ttBold}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,style: pw.TextStyle(font: ttBold),
      ),
    );
  }
}
