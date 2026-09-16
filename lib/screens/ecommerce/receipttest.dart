/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptTest extends StatelessWidget {
  const ReceiptTest({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final receiptData = ReceiptData.defaultReceipt();
    return Scaffold(
      backgroundColor: Color(0xFFF4F8FF),
      appBar: AppBar(
        title: Text('Receipt Preview'),
        backgroundColor: Color(0xFF1D4ED8),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            tooltip: 'Save as PDF',
            onPressed: () async {
              final generator = _PdfGenerator();
              final doc = await generator.buildPdf(
                receiptData,
                pageFormat: PdfPageFormat.a4,
              );
              final bytes = await doc.save();
              await Printing.sharePdf(bytes: bytes, filename: 'kologsoft_receipt.pdf');
            },
          ),
          IconButton(
            icon: Icon(Icons.print),
            tooltip: 'Print Receipt',
            onPressed: () async {
              final generator = _PdfGenerator();
              final doc = await generator.buildPdf(
                receiptData,
                pageFormat: PdfPageFormat.a4,
              );
              await Printing.layoutPdf(onLayout: (format) async => doc.save());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // official receipt heading + company logo and name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'OFFICIAL RECEIPT',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          size: 30,
                          color: Colors.blueAccent,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receiptData.companyName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent[700],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            receiptData.companyTagline,
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Text(
                    receiptData.address,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  Text(
                    'Phone: ${receiptData.phone} | Email: ${receiptData.email}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),

                  SizedBox(height: 20),
                  Divider(thickness: 1.2, color: Colors.grey[300]),
                  SizedBox(height: 10),

                  // receipt metadata
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metaLabel('Receipt #', receiptData.receiptNumber),
                      _metaLabel('Date', _formatDate(receiptData.date)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metaLabel('Cashier', receiptData.cashier),
                      _metaLabel('Payment', receiptData.paymentMethod),
                    ],
                  ),

                  SizedBox(height: 16),
                  Text(
                    'Items Purchased',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),

                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _itemRow('Item', 'Qty', 'Unit', 'Total', isHeader: true),
                        ...receiptData.items
                            .map((item) => _itemRow(
                                  item.name,
                                  item.qty.toString(),
                                  '\$${item.unitPrice.toStringAsFixed(2)}',
                                  '\$${(item.unitPrice * item.qty).toStringAsFixed(2)}',
                                ))
                            .toList(),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // summary rows from user request (VAT inclusive label only)
                  _sumRow('Amount (VAT Inclusive)', receiptData.vatInclusiveAmount),
                  _sumRow('Discount', receiptData.discount),
                  _sumRow('Sub Total', receiptData.subTotal),
                  _sumRow('VAT (${receiptData.vatPercent}%)', receiptData.vatAmount),
                  _sumRow('Payable', receiptData.payable, bold: true),
                  _sumRow('Paid', receiptData.amountPaid),
                  _sumRow('Change', receiptData.change < 0 ? 0.0 : receiptData.change, bold: true),

                  SizedBox(height: 18),
                  Divider(thickness: 1.4, color: Colors.grey[300]),
                  SizedBox(height: 10),

                  // Barcode + QR code section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Barcode',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 8),
                            Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Row(
                                children: List.generate(28, (index) {
                                  final width = index % 7 == 0 ? 8.0 : 4.0;
                                  final isDark = index % 2 == 0;
                                  return Container(
                                    width: width,
                                    margin: EdgeInsets.symmetric(horizontal: 1),
                                    color: isDark ? Colors.black : Colors.white,
                                    height: 60,
                                  );
                                }),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              receiptData.receiptNumber,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        children: [
                          Text(
                            'Scan QR',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black87, width: 2),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _fakeQrGrid(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 18),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Thank you for choosing ${receiptData.companyName}!',
                          style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Visit again for more value and innovation.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemRow(String title, String qty, String unit, String total,
      {bool isHeader = false}) {
    final style = TextStyle(
      fontSize: isHeader ? 13 : 14,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.w500,
      color: isHeader ? Colors.black87 : Colors.black54,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(title, style: style)),
          Expanded(flex: 1, child: Text(qty, style: style, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text(unit, style: style, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text(total, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _sumRow(String label, double value, {bool bold = false}) {
    final textStyle = TextStyle(
      fontSize: bold ? 16 : 15,
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      color: bold ? Colors.black87 : Colors.black54,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textStyle),
          Text('\$${value.toStringAsFixed(2)}', style: textStyle),
        ],
      ),
    );
  }

  Widget _metaLabel(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _fakeQrGrid() {
    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        final x = index % 8;
        final y = index ~/ 8;
        final bool isFinder = (x < 2 && y < 2) || (x > 5 && y < 2) || (x < 2 && y > 5);
        final bool isDark = isFinder || ((x + y) % 2 == 0);
        return Container(color: isDark ? Colors.black : Colors.white);
      },
    );
  }
}


class _PdfGenerator {
  static PdfPageFormat getFormat(String size) {
    switch (size.toLowerCase()) {
      case 'a3':
        return PdfPageFormat.a3;
      case 'a4':
        return PdfPageFormat.a4;
      case 'a5':
        return PdfPageFormat.a5;
      case 'a6':
        return PdfPageFormat.a6;
      case '80mm':
        return PdfPageFormat(72.1 * PdfPageFormat.mm, 297 * PdfPageFormat.mm);
      case '80x210':
        return PdfPageFormat(72.1 * PdfPageFormat.mm, 210 * PdfPageFormat.mm);
      case '80x297':
        return PdfPageFormat(72.1 * PdfPageFormat.mm, 297 * PdfPageFormat.mm);
      case '58mm':
        return PdfPageFormat(58 * PdfPageFormat.mm, 210 * PdfPageFormat.mm);
      default:
        return PdfPageFormat.a4;
    }
  }
  Future<pw.Document> buildPdf(
    ReceiptData data, {
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final ttfRegular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final ttfBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final doc = pw.Document();
    final pageMargin = pageFormat.width <= 80 * PdfPageFormat.mm ? 6.0 : 20.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(pageMargin),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
                boxShadow: [pw.BoxShadow(color: PdfColors.grey300, blurRadius: 8)],
              ),
              child: pw.Column(children: [
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      gradient:
                          pw.LinearGradient(colors: [PdfColors.blue900, PdfColors.blue500]),
                      borderRadius: pw.BorderRadius.circular(30),
                    ),
                    child: pw.Text(
                      'OFFICIAL RECEIPT',
                      style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 16,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ]),
                pw.SizedBox(height: 12),
                pw.Row(children: [
                  pw.Container(
                      width: 28,
                      height: 28,
                      decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                          borderRadius: pw.BorderRadius.circular(14))),
                  pw.SizedBox(width: 10),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(data.companyName,
                        style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800)),
                    pw.Text(data.companyTagline,
                        style: pw.TextStyle(font: ttfRegular, fontSize: 10, color: PdfColors.grey800)),
                  ])
                ]),
                pw.SizedBox(height: 10),
                pw.Text(data.address,
                    style: pw.TextStyle(font: ttfRegular, fontSize: 10, color: PdfColors.grey700)),
                pw.Text('Phone: ${data.phone} | Email: ${data.email}',
                    style: pw.TextStyle(font: ttfRegular, fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 10),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  _pdfMeta('Receipt #', data.receiptNumber, ttfRegular, ttfBold),
                  _pdfMeta('Date', _formatPdfDate(data.date), ttfRegular, ttfBold),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  _pdfMeta('Cashier', data.cashier, ttfRegular, ttfBold),
                  _pdfMeta('Payment', data.paymentMethod, ttfRegular, ttfBold),
                ]),
                pw.SizedBox(height: 14),
                pw.Text('Items Purchased',
                    style: pw.TextStyle(
                        font: ttfBold, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table.fromTextArray(
                  headers: ['Item', 'Qty', 'Unit', 'Total'],
                  data: data.items
                      .map((i) => [
                            i.name,
                            '${i.qty}',
                            '\$${i.unitPrice.toStringAsFixed(2)}',
                            '\$${(i.qty * i.unitPrice).toStringAsFixed(2)}'
                          ])
                      .toList(),
                  headerStyle:
                      pw.TextStyle(font: ttfBold, fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 12),
                pw.Column(children: [
                  _pdfSummaryRow('Amount (VAT Inclusive)', data.vatInclusiveAmount, ttfRegular,
                      ttfBold),
                  _pdfSummaryRow('Discount', data.discount, ttfRegular, ttfBold),
                  _pdfSummaryRow('Sub Total', data.subTotal, ttfRegular, ttfBold),
                  _pdfSummaryRow('VAT (${data.vatPercent}%)', data.vatAmount, ttfRegular, ttfBold),
                  _pdfSummaryRow('Payable', data.payable, ttfRegular, ttfBold, bold: true),
                  _pdfSummaryRow('Paid', data.amountPaid, ttfRegular, ttfBold),
                  _pdfSummaryRow('Change', data.change < 0 ? 0.0 : data.change, ttfRegular, ttfBold,
                      bold: true),
                ]),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _barcode(data, ttfRegular),
                    _buildQrcode(data, ttfRegular),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Center(
                    child: pw.Text('Thank you for choosing ${data.companyName}!',
                        style: pw.TextStyle(
                            font: ttfRegular, fontSize: 10, color: PdfColors.grey700))),
              ]),
            )
          ];
        },
      ),
    );

    return doc;
  }

  pw.Widget _pdfMeta(String title, String value, pw.Font fontRegular, pw.Font fontBold) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title,
          style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700)),
      pw.Text(value,
          style: pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold)),
    ]);
  }

  pw.Widget _pdfSummaryRow(String title, double amount, pw.Font fontRegular, pw.Font fontBold,
      {bool bold = false}) {
    final font = bold ? fontBold : fontRegular;
    final weight = bold ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(title, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: weight)),
      pw.Text('\$${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(font: font, fontSize: 10, fontWeight: weight)),
    ]);
  }

  pw.Widget _barcode(ReceiptData data, pw.Font fontRegular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: data.barcode,
          width: 120,
          height: 40,
          drawText: false,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          data.barcode,
          style: pw.TextStyle(font: fontRegular, fontSize: 7, letterSpacing: 0.9),
        ),
      ],
    );
  }

  pw.Widget _buildQrcode(ReceiptData data, pw.Font fontRegular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: data.barcode,
          width: 75,
          height: 75,
        ),
        pw.SizedBox(height: 4),
        pw.Text('QR for ${data.receiptNumber}',
            style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }

  String _formatPdfDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class ReceiptItem {
  final String name;
  final int qty;
  final double unitPrice;

  ReceiptItem({required this.name, required this.qty, required this.unitPrice});

}

class ReceiptData {
  final String companyName;
  final String companyTagline;
  final String address;
  final String phone;
  final String email;
  final String receiptNumber;
  final String barcode;
  final DateTime date;
  final String cashier;
  final String paymentMethod;
  final List<ReceiptItem> items;
  final double amountPaid;
  final double discount;
  final int vatPercent;
  final double vatInclusiveAmount;
  final double subTotal;
  final double vatAmount;
  final double payable;
  final double change;

  ReceiptData({
    required this.companyName,
    required this.companyTagline,
    required this.address,
    required this.phone,
    required this.email,
    required this.receiptNumber,
    required this.barcode,
    required this.date,
    required this.cashier,
    required this.paymentMethod,
    required this.items,
    required this.amountPaid,
    required this.discount,
    required this.vatPercent,
    required this.vatInclusiveAmount,
    required this.subTotal,
    required this.vatAmount,
    required this.payable,
    required this.change,
  });

  static ReceiptData defaultReceipt() {
    return ReceiptData(
      companyName: 'KologSoft',
      companyTagline: 'Innovation. Trust. Value.',
      address: '123 Tech Street, Kampala, Uganda',
      phone: '+256 700 000 000',
      email: 'info@kologsoft.com',
      receiptNumber: 'KG-2026-0001',
      barcode: 'KG-2026-0001',
      date: DateTime.now(),
      cashier: 'John Doe',
      paymentMethod: 'Mobile Money',
      items: [
        ReceiptItem(name: 'Wireless Mouse', qty: 1, unitPrice: 45.0),
        ReceiptItem(name: 'Keyboard', qty: 1, unitPrice: 75.0),
        ReceiptItem(name: 'USB-C Hub', qty: 2, unitPrice: 35.0),
      ],
      amountPaid: 240.0,
      discount: 10.0,
      vatPercent: 0,
      vatInclusiveAmount: 190.0,
      subTotal: 180.0,
      vatAmount: 0.0,
      payable: 180.0,
      change: 60.0,
    );
  }
}

*/