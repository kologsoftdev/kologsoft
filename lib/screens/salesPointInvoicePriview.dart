import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/salesmodel.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/Receiptdatamodel.dart';
import '../paymentwidgets/invoice1.dart';

class PrintPreviewWidget extends StatefulWidget {
  final SalesModel invoiceData;
  final bool showPrintButton;

  const PrintPreviewWidget({
    super.key,
    required this.invoiceData,
    this.showPrintButton = true,
  });

  @override
  State<PrintPreviewWidget> createState() => _PrintPreviewWidgetState();
}

class _PrintPreviewWidgetState extends State<PrintPreviewWidget> {
  bool _isGeneratingPdf = false;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  Future<void> _generateAndPrint() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final generator = ReceiptPrinter();
     final doc= await generator.buildPdf(
        ReceiptData(
          cashier: widget.invoiceData.printedby!,
          barcode: widget.invoiceData.receiptNumber,
          items: widget.invoiceData.items.entries.map((entry) {
            final e=entry.value;
            return ReceiptItem(
              name: e['item'] ?? '',
              qty: double.tryParse(e['quantity'].toString()) ?? 0,
              price: double.tryParse(e['price'].toString()) ?? 0,
              mode: e['mode'].toString(),
            );
          }).toList(),
          companyName: widget.invoiceData.companyname,
          contact: widget.invoiceData.customerPhone!.toString(),
          customername: widget.invoiceData.customerName!,
          datetime: DateTime.now(),
          receiptNumber: widget.invoiceData.receiptNumber,
          paymentMethod: widget.invoiceData.transMode,
          payable: widget.invoiceData.totalamount,
          amountPaid: widget.invoiceData.amountPaid,
          discount: 0.0,
          subTotal: widget.invoiceData.totalamount,
          change: widget.invoiceData.change,
          receiptName:  'OFFICIAL RECEIPT',
          email: '',
          vatPercent: 0,
          vatInclusiveAmount: 0,
          vatAmount: 0,
          Customertin: '',
          Suppliertin: '',
        ),
      );
      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Invoice sent to printer')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to print: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }


  List<Map<String, dynamic>> _parseItems(dynamic itemsData) {
    List<Map<String, dynamic>> items = [];

    if (itemsData == null) return items;

    if (itemsData is Map) {
      itemsData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          items.add(value);
        }
      });
    } else if (itemsData is List) {
      items = List<Map<String, dynamic>>.from(itemsData);
    }

    // Sort items by key to maintain consistent order
    items.sort((a, b) {
      final aKey = a['itemkey'] ?? '';
      final bKey = b['itemkey'] ?? '';
      return aKey.compareTo(bKey);
    });

    return items;
  }

  int _calculateTotalPieces(List<Map<String, dynamic>> items) {
    int total = 0;
    for (var item in items) {
      total += int.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.invoiceData;
    final items = _parseItems(data.items);
    final createdAt = (data.createdAt as Timestamp?)?.toDate() ?? DateTime.now();
    final totalAmount = (data.totalamount as num?)?.toDouble() ?? 0;
    final change = (data.change as num?)?.toDouble() ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF0D2A3C),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Print Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to Home',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade800.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.branchName ?? 'Business Name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          data.branchType ?? 'Sales Point',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.showPrintButton)
                  ElevatedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _generateAndPrint,
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.print),
                    label: Text(_isGeneratingPdf ? 'Generating...' : 'Print Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Invoice Title
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'SALES INVOICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Invoice Info Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPreviewInfoRow('Receipt No:', data.receiptNumber ?? 'N/A'),
                        _buildPreviewInfoRow('Date:', _dateFormat.format(createdAt)),
                        _buildPreviewInfoRow('Time:', _timeFormat.format(createdAt)),
                        _buildPreviewInfoRow('Payment Mode:', (data.transMode ?? 'N/A').toUpperCase()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildPreviewInfoRow('Customer:', data.customerName ?? 'Walk-in Customer', alignRight: true),
                        if (data.customerPhone != null && data.customerPhone.toString().isNotEmpty)
                          _buildPreviewInfoRow('Phone:', data.customerPhone!, alignRight: true),
                        _buildPreviewInfoRow('Cashier:', data.createdBy ?? 'System', alignRight: true),
                        _buildPreviewInfoRow(
                          'Status:',
                          (data.paymentStatus ?? 'pending').toUpperCase(),
                          alignRight: true,
                          status: true,
                          statusColor: data.paymentStatus == 'paid' ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Items Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5A),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _TablePreviewHeaderCell('Item')),
                  Expanded(flex: 1, child: _TablePreviewHeaderCell('Qty', align: TextAlign.center)),
                  Expanded(flex: 1, child: _TablePreviewHeaderCell('Mode', align: TextAlign.center)),
                  Expanded(flex: 1, child: _TablePreviewHeaderCell('Price', align: TextAlign.right)),
                  Expanded(flex: 1, child: _TablePreviewHeaderCell('Total', align: TextAlign.right)),
                ],
              ),
            ),

            // Items List
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D2A3C),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.1),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemTotal = double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['item'] ?? 'Unknown Item',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              if (item['barcode'] != null)
                                Text(
                                  'Barcode: ${item['barcode']}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            item['quantity']?.toString() ?? '0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade900.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item['mode'] ?? 'unit',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'GHS ${double.tryParse(item['price']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'GHS ${itemTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Summary Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5A).withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'Total Items: ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${data.itemCount ?? items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Text(
                          'Total Pieces: ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${_calculateTotalPieces(items)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          color: Colors.green,
                          size: 16,
                        ),
                        Text(
                          'GHS ${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payment Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade700.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Status: ',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (data.paymentStatus  == 'paid' ? Colors.green : Colors.orange).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (data.paymentStatus  ?? 'pending').toUpperCase(),
                              style: TextStyle(
                                color: data.paymentStatus == 'paid' ? Colors.green : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Change:',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'GHS ${change.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: change > 0 ? Colors.green : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Footer
            Center(
              child: Column(
                children: [
                  const Text(
                    'Thank you for your business!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generated: ${_dateTimeFormat.format(DateTime.now())}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewInfoRow(String label, String value, {bool alignRight = false, bool status = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          if (status)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: statusColor?.withOpacity(0.2) ?? Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: statusColor ?? Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// Helper widget for table headers in preview
class _TablePreviewHeaderCell extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _TablePreviewHeaderCell(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      textAlign: align,
    );
  }
}

// Extension for date formatting
extension DateTimeFormatting on DateTime {
  String get ddMMMyyyy => DateFormat('dd MMM yyyy').format(this);
  String get hhmmA => DateFormat('hh:mm a').format(this);
  String get ddMMMyyyyHHmm => DateFormat('dd MMM yyyy, hh:mm a').format(this);
}