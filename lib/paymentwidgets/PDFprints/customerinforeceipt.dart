import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

pw.Widget buildReceiptLayout({
  required String companyName,
  required String receiptNumber,
  required String cashierName,
  required DateTime now,
  required List salesItems,
  required double total,
  required double totalDiscount,
  required String customerName,
  required String phone,
  required String paymentLabel,
  required String bankName,
  required String reference,
}) {
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
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 3),

            pw.Text(
              'SALES RECEIPT',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 5),
          ],
        ),
      ),

      /// RECEIPT NUMBER
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Receipt #:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            receiptNumber,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),

      /// DATE
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

      /// CASHIER
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Cashier:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(cashierName, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),

      /// CUSTOMER
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Customer:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(customerName, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),

      /// PHONE
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Phone:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(phone, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),

      /// PAYMENT METHOD
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Payment:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            paymentLabel,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),

      /// BANK
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Bank:', style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(
            child: pw.Text(
              bankName,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),

      /// REFERENCE
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Reference:', style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(
            child: pw.Text(
              reference,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 8),
      pw.Divider(),

      /// ITEMS
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
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${item['quantity']} x GHS ${item['price']}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'GHS ${item['totalamount']}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
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

      /// DISCOUNT
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

      if (totalDiscount > 0) pw.SizedBox(height: 3),

      /// TOTAL
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TOTAL',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'GHS ${total.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
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
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Powered by KologSoft',
              style: pw.TextStyle(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}