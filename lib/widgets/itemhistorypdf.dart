
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> printItemHistory(
    BuildContext context, { required List<dynamic> entries, required String itemName, required String dateLabel,    String companyName = '',    }) async {
  final pdf = pw.Document(title: 'Stock History - $itemName', author: companyName);
  final ttfRegular =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final ttfBold =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  const ink      = PdfColor.fromInt(0xFF0D1B2A);
  const slate    = PdfColor.fromInt(0xFF415A77);
  const accent   = PdfColor.fromInt(0xFF00B4D8);
  const positive = PdfColor.fromInt(0xFF27AE60);
  const negative = PdfColor.fromInt(0xFFE74C3C);
  const rowEven  = PdfColor.fromInt(0xFFF4F7FB);
  const rowOdd   = PdfColors.white;
  const muted    = PdfColor.fromInt(0xFF778899);

  String fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = ts as DateTime;
      return DateFormat('dd MMM yyyy  hh:mm a').format(dt);
    } catch (_) {
      return '-';
    }
  }


  final Map<String, _TypeTotal> typeTotals = {
    'Sale':  _TypeTotal(label: 'Sale', sign: '-'),
    'Damage': _TypeTotal(label: 'Damage', sign: '-'),
    'Opening Stock': _TypeTotal(label: 'Opening Stock', sign: '+'),
    'Credit':  _TypeTotal(label: 'Credit',        sign: '+'),
    'Sales Return':_TypeTotal(label: 'Sales Return',sign: '+'),
    'Cash': _TypeTotal(label: 'Cash',sign: '+'),
    'Transfer': _TypeTotal(label: 'Transfer', sign: '-'),
  };

  double totalIn = 0, totalOut = 0, totalValue = 0;

  for (final e in entries) {
    final sign  = e.sign as String;
    final qty   = e.qty   as double;
    final total = e.total as double;
    final type  = (e.type as String).trim();

   String? key;
    if (type == 'Sale') {
      key = 'Sale';
    }
    else if (type == 'Damage'){
      key = 'Damage';
    }
    else if (type == 'Opening Stock'){
      key = 'Opening Stock';
    }
    else if (type == 'Credit'){
      key = 'Credit';
    }
    else if (type == 'Sales Return'){
      key = 'Sales Return';
    }
    else if (type == 'Cash'){
      key = 'Cash';
    }
    else if (type.toLowerCase().startsWith('transfer')){
      key = 'Transfer';
    }

    if (key != null) {
      typeTotals[key]!.qty   += qty;
      typeTotals[key]!.value += total;
      typeTotals[key]!.count += 1;
    }

    if (sign == '+') {
      totalIn += qty;
    } else {
      totalOut   += qty;
      totalValue += total;
    }
  }


  final activeTypes = typeTotals.values.where((t) => t.count > 0).toList();

  // Column widths
  final cols = [20.0, 105.0, 75.0, 46.0, 46.0, 56.0, 46.0, 65.0, 72.0, 85.0];

  pw.Widget cell(
      String text, {
        pw.TextStyle? style,
        pw.Alignment alignment = pw.Alignment.centerLeft,
        double pad = 4,
      }) =>
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(horizontal: pad, vertical: 5),
        child: pw.Align(
          alignment: alignment,
          child: pw.Text(
            text,
            style: style ?? pw.TextStyle(fontSize: 7, color: ink,font: ttfRegular),
          ),
        ),
      );

  pw.Widget headerCell(String text,
      {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: pw.Align(
          alignment: align,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              font: ttfBold,
            ),
          ),
        ),
      );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),

      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            color: slate,
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 9,
                          color: accent,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        itemName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          font: ttfBold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'STOCK HISTORY REPORT',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                          letterSpacing: 1.5,
                          font: ttfBold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(dateLabel,
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.white, font: ttfRegular)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Printed: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.white, font: ttfRegular),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                      style: pw.TextStyle(fontSize: 7, color: PdfColors.white, font: ttfRegular),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.Container(height: 3, color: accent),
          pw.SizedBox(height: 8),

         if (ctx.pageNumber == 1) ...[

            //overall totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _pill('Total Records', '${entries.length}',ttfBold,ttfRegular, isHeader: true),
                pw.SizedBox(width: 10),
                _pill('Stock In',  '+${totalIn.toStringAsFixed(0)} pcs',ttfBold,ttfRegular,  isIn: true),
                pw.SizedBox(width: 10),
                _pill('Stock Out', '-${totalOut.toStringAsFixed(0)} pcs',ttfBold,ttfRegular, isIn: false),
                pw.SizedBox(width: 10),
                _pill('Total Value', 'GHS ${totalValue.toStringAsFixed(2)}',ttfBold,ttfRegular, isHeader: true),
              ],
            ),

            pw.SizedBox(height: 8),

            // Row 2: per-type breakdown
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFCDD5DF),
                  width: 0.6,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                children: [
                  // Header label column
                  pw.Container(
                    width: 70,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF4F7FB),
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(4),
                        bottomLeft: pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TYPE',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'BREAKDOWN',
                          style: pw.TextStyle(
                            fontSize: 5.5,
                            color: muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // One cell per active type
                  ...activeTypes.map((t) => _typeCell(t,ttfBold,ttfRegular)),
                ],
              ),
            ),

            pw.SizedBox(height: 10),
          ],

          // Column header row
          pw.Container(
            color: const PdfColor.fromInt(0xFF1E2A3D),
            child: pw.Row(
              children: [
                pw.SizedBox(width: cols[0], child: headerCell('#', align: pw.Alignment.center)),
                pw.SizedBox(width: cols[1], child: headerCell('Date')),
                pw.SizedBox(width: cols[2], child: headerCell('Type')),
                pw.SizedBox(width: cols[3], child: headerCell('±Qty', align: pw.Alignment.center)),
                pw.SizedBox(width: cols[4], child: headerCell('Price', align: pw.Alignment.centerRight)),
                pw.SizedBox(width: cols[5], child: headerCell('Total', align: pw.Alignment.centerRight)),
                pw.SizedBox(width: cols[6], child: headerCell('Mode')),
                pw.SizedBox(width: cols[7], child: headerCell('Branch')),
                pw.SizedBox(width: cols[8], child: headerCell('Staff')),
                pw.SizedBox(width: cols[9], child: headerCell('TrnxID')),
              ],
            ),
          ),
        ],
      ),

      footer: (ctx) => pw.Column(
        children: [
          pw.Container(height: 1, color: accent),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '$companyName · Stock History · $itemName',
                style: pw.TextStyle(fontSize: 7, color: muted),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7, color: muted),
              ),
            ],
          ),
        ],
      ),

      build: (ctx) => [
        ...entries.asMap().entries.map((e) {
          final i      = e.key;
          final t      = e.value;
          final isEven = i % 2 == 0;
          final sign   = t.sign as String;
          final qtyStr = '$sign${(t.qty as double).toStringAsFixed(0)}';

          return pw.Container(
            color: isEven ? rowEven : rowOdd,
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: cols[0],
                  child: cell('${i + 1}',
                      alignment: pw.Alignment.center,
                      style: pw.TextStyle(fontSize: 7, color: muted)),
                ),
                pw.SizedBox(
                  width: cols[1],
                  child: cell(fmtDate(t.date),
                      style: pw.TextStyle(fontSize: 6.5, color: ink)),
                ),
                pw.SizedBox(
                  width: cols[2],
                  child: cell(t.type as String,
                      style: pw.TextStyle(fontSize: 7, color: ink)),
                ),
                pw.SizedBox(
                  width: cols[3],
                  child: cell(qtyStr,
                      alignment: pw.Alignment.center,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: sign == '+' ? positive : negative,
                      )),
                ),
                pw.SizedBox(
                  width: cols[4],
                  child: cell((t.price as double).toStringAsFixed(2),
                      alignment: pw.Alignment.centerRight,
                      style: pw.TextStyle(fontSize: 7, color: muted)),
                ),
                pw.SizedBox(
                  width: cols[5],
                  child: cell((t.total as double).toStringAsFixed(2),
                      alignment: pw.Alignment.centerRight,
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: ink)),
                ),
                pw.SizedBox(
                  width: cols[6],
                  child: cell(t.mode as String,
                      style: pw.TextStyle(fontSize: 7, color: muted)),
                ),
                pw.SizedBox(
                  width: cols[7],
                  child: cell(t.branch as String,
                      style: pw.TextStyle(fontSize: 7, color: ink)),
                ),
                pw.SizedBox(
                  width: cols[8],
                  child: cell(t.staff as String,
                      style: pw.TextStyle(fontSize: 7, color: ink)),
                ),
                pw.SizedBox(
                  width: cols[9],
                  child: cell(t.transactionid as String,
                      style: pw.TextStyle(fontSize: 6.5, color: muted)),
                ),
              ],
            ),
          );
        }),

        pw.SizedBox(height: 16),

       pw.Container(
          color: slate,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Overall line
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'TOTAL RECORDS: ${entries.length}   |   '
                        'STOCK IN: +${totalIn.toStringAsFixed(0)} pcs   |   '
                        'STOCK OUT: -${totalOut.toStringAsFixed(0)} pcs   |   '
                        'TOTAL VALUE: GHS ${totalValue.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              // Divider
              pw.Container(height: 0.5, color: const PdfColor.fromInt(0x44FFFFFF)),
              pw.SizedBox(height: 6),
              // Per-type breakdown line
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  ...activeTypes.asMap().entries.map((e) {
                    final t = e.value;
                    final isLast = e.key == activeTypes.length - 1;
                    return pw.Row(
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              t.label.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 5.5,
                                color: const PdfColor.fromInt(0xAAFFFFFF),
                                letterSpacing: 0.6,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              '${t.sign}${t.qty.toStringAsFixed(0)} pcs',
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'GHS ${t.value.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                color: const PdfColor.fromInt(0xCCFFFFFF),
                              ),
                            ),
                          ],
                        ),
                        if (!isLast) ...[
                          pw.SizedBox(width: 12),
                          pw.Container(
                            width: 0.5,
                            height: 30,
                            color: const PdfColor.fromInt(0x33FFFFFF),
                          ),
                          pw.SizedBox(width: 12),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  await Printing.layoutPdf(
    onLayout: (_) async => pdf.save(),
    name: 'KologSoft_${itemName.replaceAll(' ', '_')}_$ts',
  );
}


class _TypeTotal {
  final String label;
  final String sign;
  double qty   = 0;
  double value = 0;
  int    count = 0;
  _TypeTotal({required this.label, required this.sign});
}


pw.Widget _pill(String label, String value,pw.Font ttbold,pw.Font ttregular,
    {bool isHeader = false, bool? isIn}) {
  const muted = PdfColor.fromInt(0xFF778899);
  const positive = PdfColor.fromInt(0xFF27AE60);
  const negative = PdfColor.fromInt(0xFFE74C3C);
  const ink = PdfColor.fromInt(0xFF0D1B2A);

  final valueColor = isIn == null
      ? ink
      : (isIn ? positive : negative);

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      border: pw.Border.all(
        color: const PdfColor.fromInt(0xFFCDD5DF),
        width: 0.8,
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            font: ttregular,
            fontSize: 6,
            color: muted,
            letterSpacing: 0.8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: ttbold,
            fontSize: 11,
            color: valueColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}


pw.Widget _typeCell(_TypeTotal t,pw.Font ttbold,pw.Font ttregular) {
  const muted = PdfColor.fromInt(0xFF778899);
  const ink   = PdfColor.fromInt(0xFF0D1B2A);
  const positive = PdfColor.fromInt(0xFF27AE60);
  const negative = PdfColor.fromInt(0xFFE74C3C);

  final qtyColor = t.sign == '+' ? positive : negative;

  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(
            color: PdfColor.fromInt(0xFFCDD5DF),
            width: 0.6,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            t.label.toUpperCase(),
            style: pw.TextStyle(
              font: ttbold,
              fontSize: 5.5,
              color: muted,
              letterSpacing: 0.6,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${t.sign}${t.qty.toStringAsFixed(0)} pcs',
            style: pw.TextStyle(
              font: ttbold,
              fontSize: 9,
              color: qtyColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'GHS ${t.value.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 6.5, color: ink,font: ttregular),
          ),
          pw.Text(
            '${t.count} record${t.count == 1 ? '' : 's'}',
            style: pw.TextStyle(fontSize: 5.5, color: muted,font: ttregular),
          ),
        ],
      ),
    ),
  );
}