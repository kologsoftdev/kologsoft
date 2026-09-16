import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

Future<void> printRecords(context,List<Map<String, dynamic>> _items,totals) async {
  final provider=Provider.of<Datafeed>(context, listen: false);

  final pdf = pw.Document();
  final transferDate = Timestamp.fromDate(DateTime.now());
  String transferDateStr = 'N/A';
  if (transferDate != null) {
    final dateTime = (transferDate as Timestamp).toDate();
    transferDateStr =
        DateFormat('dd/MM/yyyy').format(dateTime);
  }
  String fmtNum(dynamic v) {
    if (v == null || v.toString().isEmpty) return '-';
    if (v is int) return v.toString();
    if (v is double || v is num) return (v as num).toStringAsFixed(2);
    return v.toString();
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {

        return <pw.Widget>[
          // Company name
          pw.Center(
            child: pw.Text(
              provider.company ?? 'COMPANY NAME',
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),

          // Title
          pw.Center(
            child: pw.Text(
              'STOCK REQUEST INVOICE',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),

          // new thin divider between title and headerdata
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 12),

          // Header section (no border)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [

                    pw.Text('From: ${provider.selectedBranch?.branchname}', style: pw.TextStyle(fontSize: 14)),
                    pw.Text('To: ${provider.branch}', style: pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Staff: ${provider.staff}', style: pw.TextStyle(fontSize: 14)),
                    pw.Text('Date: ${transferDateStr}', style: pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),

          // thin divider between header and table
          pw.SizedBox(height: 12),
          pw.Container(height: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 12),

          // Manual table - borders enabled only here
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),   // #
              1: const pw.FlexColumnWidth(3.0),   // Item
              2: const pw.FlexColumnWidth(1.2),   // Mode
              3: const pw.FlexColumnWidth(0.9),   // Mode Qty (num)
              4: const pw.FlexColumnWidth(0.9),   // Pieces (num)
              5: const pw.FlexColumnWidth(0.9),   // Qty (num)
              8: const pw.FlexColumnWidth(1.4),   // Total (num)
            },
            children: [
              // header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Mode', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Mode Qty', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pieces', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),

              // data rows
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final it = entry.value;
                final bool even = entry.key % 2 == 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: even ? PdfColors.white : PdfColors.grey100),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(idx.toString(), style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it['item']?.toString() ?? '-', style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it['mode']?.toString() ?? it['salesMode']?.toString() ?? '-', style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['modeqty'] ?? it['modeQty'] ?? ''), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['requestedpieces'] ?? ''), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['requestedquantity'] ?? ''), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmtNum(it['total'] ?? ''), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ],
                );
              }).toList(),
            ],
          ),

          pw.SizedBox(height: 20),

          // Totals - right aligned, no border
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 260,
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Gross:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(fmtNum(totals), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                    ]),

                    pw.Divider(),

                  ],
                ),
              ),
            ],
          ),
        ];
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}
