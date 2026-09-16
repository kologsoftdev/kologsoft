import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/appModuls.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../providers/Datafeed.dart';
import '../providers/StockProvider.dart';

class PurchaseReturnTableScreen extends StatefulWidget {
  const PurchaseReturnTableScreen({super.key});

  @override
  State<PurchaseReturnTableScreen> createState() => _PurchaseReturnTableScreenState();
}

class _PurchaseReturnTableScreenState extends State<PurchaseReturnTableScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = "";
  String _selectedFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeActive = false;
  bool _isLoading = false;
  bool _isDeleting = false;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  final List<String> _filterOptions = [
    'All',
    'Opening Stock',
    'Credit',
    'Cash',
  ];

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _showDateRangePicker() async {
    final DateTime? start = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF22304A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (start != null) {
      final DateTime? end = await showDatePicker(
        context: context,
        initialDate: _endDate ?? start,
        firstDate: start,
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Color(0xFF22304A),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (end != null) {
        setState(() {
          _startDate = DateTime(start.year, start.month, start.day);
          _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
          _isDateRangeActive = true;
        });
      }
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeActive = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<Datafeed>(context, listen: false);
      await provider.getdata();
    });
  }

  bool _filterReturnItem(Map<String, dynamic> data, Map<String, dynamic> item) {
    final searchLower = _searchQuery.toLowerCase();

    // Search filter
    if (_searchQuery.isNotEmpty) {
      bool matches = false;

      // Search in main fields
      final searchableFields = [
        data['invoice']?.toString(),
        data['suppliername']?.toString(),
        data['branchname']?.toString(),
        data['createdby']?.toString(),
        data['purchasetype']?.toString(),
        data['waybill']?.toString(),
        item['item']?.toString(),
        item['barcode']?.toString(),
        item['returnreason']?.toString(),
        item['returnvalue']?.toString(),
      ];

      for (var field in searchableFields) {
        if (field != null && field.toLowerCase().contains(searchLower)) {
          matches = true;
          break;
        }
      }

      if (!matches) return false;
    }

    // Filter by purchase type or supplier
    if (_selectedFilter != 'All') {
      final filterLower = _selectedFilter.toLowerCase();
      final purchaseType = data['purchasetype']?.toString().toLowerCase() ?? '';
      final supplier = data['suppliername']?.toString().toLowerCase() ?? '';
      final returnReason = item['returnreason']?.toString().toLowerCase() ?? '';

      bool fieldMatches = purchaseType.contains(filterLower) ||
          supplier.contains(filterLower) ||
          returnReason.contains(filterLower);

      if (!fieldMatches) return false;
    }

    // Date range filter
    if (_isDateRangeActive && _startDate != null && _endDate != null) {
      final submittedAt = data['submittedat'] as Timestamp?;
      if (submittedAt != null) {
        final date = submittedAt.toDate();
        if (date.isBefore(_startDate!) || date.isAfter(_endDate!)) {
          return false;
        }
      }
    }

    return true;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
  }

  String _formatDateOnly(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      symbol: 'GHS ',
      decimalDigits: 2,
    ).format(value);
  }

  Widget _buildStatusChip(String status) {
    final statusLower = status.toLowerCase();
    Color color;
    String displayStatus = status.isEmpty ? 'Pending' : status;

    if (statusLower.contains('approved')) {
      color = Colors.green;
    } else if (statusLower.contains('completed')) {
      color = Colors.blue;
    } else if (statusLower.contains('rejected')) {
      color = Colors.red;
    } else if (statusLower.contains('processing')) {
      color = Colors.orange;
    } else {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildPurchaseTypeChip(String type) {
    Color color;
    switch (type.toLowerCase()) {
      case 'credit':
        color = Colors.orange;
        break;
      case 'cash':
        color = Colors.green;
        break;
      case 'opening stock':
        color = Colors.purple;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Print functions
  Future<void> _printReturnItems(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      // Group items by invoice for better organization
      final Map<String, List<Map<String, dynamic>>> groupedByInvoice = {};
      for (var item in items) {
        final invoice = item['invoice']?.toString() ?? 'N/A';
        if (!groupedByInvoice.containsKey(invoice)) {
          groupedByInvoice[invoice] = [];
        }
        groupedByInvoice[invoice]!.add(item);
      }
      final provider = Provider.of<StockProvider>(context, listen: false);

      final companyName = provider.company ?? 'Company Name';
      final companyAddress = provider.companyemail ?? 'Address';

      // Create a page for each invoice
      for (var entry in groupedByInvoice.entries) {
        final invoice = entry.key;
        final invoiceItems = entry.value;

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            orientation: pw.PageOrientation.portrait,
            margin: pw.EdgeInsets.all(16),
            build: (pw.Context context) {
              return [
                // Header
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              companyName,
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              companyAddress,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'PURCHASE RETURN INVOICE',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'Invoice #: $invoice',
                              style: pw.TextStyle(fontSize: 12),
                            ),
                            pw.Text(
                              'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 16),

                    // Supplier and Branch Info
                    if (invoiceItems.isNotEmpty) ...[
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Supplier: ${invoiceItems.first['suppliername'] ?? 'N/A'}',
                                  style: pw.TextStyle(fontSize: 11),
                                ),
                                pw.Text(
                                  'Branch: ${invoiceItems.first['branchname'] ?? 'N/A'}',
                                  style: pw.TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  'Type: ${invoiceItems.first['purchasetype'] ?? 'N/A'}',
                                  style: pw.TextStyle(fontSize: 11),
                                ),
                                pw.Text(
                                  'Waybill: ${invoiceItems.first['waybill'] ?? 'N/A'}',
                                  style: pw.TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 16),
                    ],

                    // Items Table
                    pw.Table(
                      border: pw.TableBorder.all(width: 0.5),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(30),
                        1: const pw.FlexColumnWidth(3),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FixedColumnWidth(60),
                        4: const pw.FixedColumnWidth(70),
                        5: const pw.FixedColumnWidth(50),
                      },
                      children: [
                        // Header Row
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey300,
                          ),
                          children: [
                            _buildTableHeader('S/N'),
                            _buildTableHeader('Item'),
                            _buildTableHeader('Barcode'),
                            _buildTableHeader('Qty'),
                            _buildTableHeader('Unit Price'),
                            _buildTableHeader('Total'),
                          ],
                        ),
                        // Data Rows
                        ...invoiceItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final isEven = idx % 2 == 0;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: isEven ? PdfColors.white : PdfColors.grey100,
                            ),
                            children: [
                              _buildTableCell('${idx + 1}'),
                              _buildTableCell(item['item']?.toString() ?? 'N/A'),
                              _buildTableCell(item['barcode']?.toString() ?? 'N/A'),
                              _buildTableCell(item['returnquantity']?.toString() ?? '0', alignment: pw.Alignment.centerRight),
                              _buildTableCell(
                                _formatCurrency(item['unitprice'] ?? 0),
                                alignment: pw.Alignment.centerRight,
                              ),
                              _buildTableCell(
                                _formatCurrency('${invoiceItems.first['net_returnvalue'] ?? 0.00}' as num),
                                alignment: pw.Alignment.centerRight,
                                isBold: true,
                              ),
                            ],
                          );
                        }).toList(),
                        // Total Row
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: [
                            _buildTableCell('', colspan: 5),
                            _buildTableCell(
                              _formatCurrency(
                                invoiceItems.fold<double>(
                                  0,
                                      (sum, item) => sum + (item['net_returnvalue'] as num? ?? 0).toDouble(),
                                ),
                              ),
                              alignment: pw.Alignment.centerRight,
                              isBold: true,
                              fontSize: 12,
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 16),

                    // Return Reason Summary
                    pw.Text(
                      'Return Reasons:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    ...invoiceItems.map((item) {
                      final reason = item['returnreason']?.toString() ?? 'N/A';
                      final itemName = item['item']?.toString() ?? 'N/A';
                      return pw.Text(
                        '• $itemName: $reason',
                        style: pw.TextStyle(fontSize: 10),
                      );
                    }).toList(),

                    pw.SizedBox(height: 16),

                    // Footer
                    pw.Divider(thickness: 0.5),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          'Page ${context.pageNumber ?? 1} of ${context.pagesCount ?? 1}',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
              ];
            },
          ),
        );
      }

      // Show print preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'purchase_returns_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _printSingleInvoice(Map<String, dynamic> document) async {
    // Extract items array
    final List<Map<String, dynamic>> items =
    (document['itemz'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items found to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      final provider = Provider.of<StockProvider>(context, listen: false);

      final companyName = provider.company ?? 'Company Name';
      final companyAddress = provider.companyemail ?? 'Address';

      final invoice = document['invoice']?.toString() ?? 'N/A';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            return [
              /// ===========================
              /// HEADER
              /// ===========================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        companyAddress,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PURCHASE RETURN',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Invoice #: $invoice'),
                      pw.Text(
                        'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),

              /// ===========================
              /// SUPPLIER DETAILS
              /// ===========================
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Supplier: ${document['suppliername'] ?? 'N/A'}',
                        ),
                        pw.Text(
                          'Branch: ${document['branchname'] ?? 'N/A'}',
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Type: ${document['purchasetype'] ?? 'N/A'}',
                        ),
                        pw.Text(
                          'Waybill: ${document['waybill'] ?? 'N/A'}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 15),

              /// ===========================
              /// ITEMS TABLE
              /// ===========================
              pw.Table(
                border: pw.TableBorder.all(width: .5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(35),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(55),
                  3: const pw.FixedColumnWidth(70),
                  4: const pw.FixedColumnWidth(75),
                },
                children: [
                  /// Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _buildTableHeader('S/N'),
                      _buildTableHeader('Item'),
                      _buildTableHeader('Reason'),
                      _buildTableHeader('Qty'),
                      _buildTableHeader('Unit Price'),
                      _buildTableHeader('Total'),
                    ],
                  ),

                  /// Item Rows
                  ...List.generate(items.length, (index) {
                    final row = items[index];

                    return pw.TableRow(
                      children: [
                        _buildTableCell('${index + 1}'),
                        _buildTableCell(row['item']?.toString() ?? ''),
                        _buildTableCell(row['returnreason']?.toString() ?? ''),
                        _buildTableCell(
                          row['returnquantity']?.toString() ?? '0',
                          alignment: pw.Alignment.centerRight,
                        ),
                        _buildTableCell(
                          _formatCurrency(row['price'] ?? 0),
                          alignment: pw.Alignment.centerRight,
                        ),
                        _buildTableCell(
                          _formatCurrency(row['net_returnvalue'] ?? 0),
                          alignment: pw.Alignment.centerRight,
                          isBold: true,
                        ),
                      ],
                    );
                  }),

                  /// Grand Total
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildTableCell(''),
                      _buildTableCell(''),
                      _buildTableCell(''),
                      _buildTableCell(''),
                      _buildTableCell(
                        'Grand Total',
                        alignment: pw.Alignment.centerRight,
                        isBold: true,
                      ),
                      _buildTableCell(
                        _formatCurrency(document['returnvalue'] ?? 0),
                        alignment: pw.Alignment.centerRight,
                        isBold: true,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 15),

              /// ===========================
              /// RETURN REASONS
              /// ===========================
              pw.SizedBox(height: 5),

              pw.Divider(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'purchase_return_$invoice.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // Print single invoice
//   Future<void> _printSingleInvoice(List<Map<String, dynamic>> item) async {
//     if (item.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No item to print'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }
//
// try {
//       final pdf = pw.Document();
//       final provider = Provider.of<StockProvider>(context, listen: false);
//       final companyName = provider.company ?? 'Company Name';
//       final companyAddress = provider.companyemail ?? 'Address';
//
//       final invoice = item['invoice']?.toString() ?? 'N/A';
//
//       pdf.addPage(
//         pw.MultiPage(
//           pageFormat: PdfPageFormat.a4,
//           orientation: pw.PageOrientation.portrait,
//           margin: pw.EdgeInsets.all(16),
//           build: (pw.Context context) {
//             return [
//               // Header
//               pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Row(
//                     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                     children: [
//                       pw.Column(
//                         crossAxisAlignment: pw.CrossAxisAlignment.start,
//                         children: [
//                           pw.Text(
//                             companyName,
//                             style: pw.TextStyle(
//                               fontSize: 18,
//                               fontWeight: pw.FontWeight.bold,
//                             ),
//                           ),
//                           pw.Text(
//                             companyAddress,
//                             style: pw.TextStyle(fontSize: 10),
//                           ),
//                         ],
//                       ),
//                       pw.Column(
//                         crossAxisAlignment: pw.CrossAxisAlignment.end,
//                         children: [
//                           pw.Text(
//                             'PURCHASE RETURN INVOICE',
//                             style: pw.TextStyle(
//                               fontSize: 16,
//                               fontWeight: pw.FontWeight.bold,
//                             ),
//                           ),
//                           pw.Text(
//                             'Invoice #: $invoice',
//                             style: pw.TextStyle(fontSize: 12),
//                           ),
//                           pw.Text(
//                             'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
//                             style: pw.TextStyle(fontSize: 10),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                   pw.SizedBox(height: 16),
//                   pw.Divider(thickness: 1),
//                   pw.SizedBox(height: 16),
//
//                   // Supplier and Branch Info
//                   pw.Row(
//                     children: [
//                       pw.Expanded(
//                         child: pw.Column(
//                           crossAxisAlignment: pw.CrossAxisAlignment.start,
//                           children: [
//                             pw.Text(
//                               'Supplier: ${item['suppliername'] ?? 'N/A'}',
//                               style: pw.TextStyle(fontSize: 11),
//                             ),
//                             pw.Text(
//                               'Branch: ${item['branchname'] ?? 'N/A'}',
//                               style: pw.TextStyle(fontSize: 11),
//                             ),
//                           ],
//                         ),
//                       ),
//                       pw.Expanded(
//                         child: pw.Column(
//                           crossAxisAlignment: pw.CrossAxisAlignment.end,
//                           children: [
//                             pw.Text(
//                               'Type: ${item['purchasetype'] ?? 'N/A'}',
//                               style: pw.TextStyle(fontSize: 11),
//                             ),
//                             pw.Text(
//                               'Waybill: ${item['waybill'] ?? 'N/A'}',
//                               style: pw.TextStyle(fontSize: 11),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   pw.SizedBox(height: 16),
//
//                   // Return Details
//                   pw.Table(
//                     border: pw.TableBorder.all(width: 0.5),
//                     columnWidths: {
//                       0: const pw.FixedColumnWidth(30),
//                       1: const pw.FlexColumnWidth(3),
//                       2: const pw.FlexColumnWidth(2),
//                       3: const pw.FixedColumnWidth(60),
//                       4: const pw.FixedColumnWidth(70),
//                       5: const pw.FixedColumnWidth(50),
//                     },
//                     children: [
//                       // Header Row
//                       pw.TableRow(
//                         decoration: const pw.BoxDecoration(
//                           color: PdfColors.grey300,
//                         ),
//                         children: [
//                           _buildTableHeader('S/N'),
//                           _buildTableHeader('Item'),
//                           //_buildTableHeader('Barcode'),
//                           _buildTableHeader('Qty'),
//                           _buildTableHeader('Unit Price'),
//                           _buildTableHeader('Total'),
//                         ],
//                       ),
//                       // Data Row
//                       pw.TableRow(
//                         children: [
//                           _buildTableCell('1'),
//                           _buildTableCell(item['item']?.toString() ?? 'N/A'),
//                          // _buildTableCell(item['barcode']?.toString() ?? 'N/A'),
//                           _buildTableCell(
//                             item['returnquantity']?.toString() ?? '0',
//                             alignment: pw.Alignment.centerRight,
//                           ),
//                           _buildTableCell(
//                             _formatCurrency(item['price'] ?? 0),
//                             alignment: pw.Alignment.centerRight,
//                           ),
//                           _buildTableCell(
//                             _formatCurrency(item['net_returnvalue'] ?? 0),
//                             alignment: pw.Alignment.centerRight,
//                             isBold: true,
//                           ),
//                         ],
//                       ),
//                       // Total Row
//                       pw.TableRow(
//                         decoration: const pw.BoxDecoration(
//                           color: PdfColors.grey200,
//                         ),
//                         children: [
//                           _buildTableCell('', colspan: 5),
//                           _buildTableCell('', colspan: 5),
//                           _buildTableCell('', colspan: 5),
//                           _buildTableCell('', colspan: 5),
//                           _buildTableCell(
//                             _formatCurrency(item['returnvalue'] ?? 0),
//                             alignment: pw.Alignment.centerRight,
//                             isBold: true,
//                             fontSize: 12,
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//
//                   pw.SizedBox(height: 16),
//
//                   // Return Reason
//                   pw.Text(
//                     'Return Reason:',
//                     style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
//                   ),
//                   pw.SizedBox(height: 4),
//                   pw.Text(
//                     item['returnreason']?.toString() ?? 'N/A',
//                     style: pw.TextStyle(fontSize: 10),
//                   ),
//
//                   pw.SizedBox(height: 16),
//
//                   // Footer
//                   pw.Divider(thickness: 0.5),
//                   pw.SizedBox(height: 8),
//                   pw.Row(
//                     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                     children: [
//                       pw.Text(
//                         'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
//                         style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
//                       ),
//                       // pw.Text(
//                       //   'Page ${context.pageNumber ?? 1} of ${context.pagesCount ?? 1}',
//                       //   style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
//                       // ),
//                     ],
//                   ),
//                 ],
//               ),
//             ];
//           },
//         ),
//       );
//
//       await Printing.layoutPdf(
//         onLayout: (PdfPageFormat format) async => pdf.save(),
//         name: 'purchase_return_$invoice.pdf',
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error generating PDF: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(
      String text, {
        pw.Alignment alignment = pw.Alignment.centerLeft,
        bool isBold = false,
        int colspan = 1,
        double fontSize = 10,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: fontSize,
        ),
        textAlign: alignment == pw.Alignment.centerRight
            ? pw.TextAlign.right
            : alignment == pw.Alignment.center
            ? pw.TextAlign.center
            : pw.TextAlign.left,
      ),
    );
  }

  // Print summary with all items
  Future<void> _printSummary(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      final companyName = context.read<Datafeed>().company ?? 'Company Name';
      final companyAddress = context.read<Datafeed>().companyemail ?? 'Address';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          orientation: pw.PageOrientation.landscape,
          margin: pw.EdgeInsets.all(16),
          build: (pw.Context context) {
            // Calculate totals
            final totalReturns = items.length;
            final totalValue = items.fold<double>(
              0,
                  (sum, item) => sum + (item['returnvalue'] as num? ?? 0).toDouble(),
            );
            final totalQuantity = items.fold<int>(
              0,
                  (sum, item) => sum + (item['returnquantity'] as num? ?? 0).toInt(),
            );

            // Group by supplier
            final Map<String, int> supplierCounts = {};
            final Map<String, double> supplierValues = {};
            for (var item in items) {
              final supplier = item['suppliername']?.toString() ?? 'Unknown';
              supplierCounts[supplier] = (supplierCounts[supplier] ?? 0) + 1;
              supplierValues[supplier] = (supplierValues[supplier] ?? 0) +
                  (item['returnvalue'] as num? ?? 0).toDouble();
            }

            return [
              // Header
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            companyName,
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            companyAddress,
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'PURCHASE RETURNS SUMMARY',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                          if (_isDateRangeActive && _startDate != null && _endDate != null)
                            pw.Text(
                              'Period: ${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                            ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 16),

                  // Summary Cards
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryCard('Total Returns', totalReturns.toString()),
                      _buildSummaryCard('Total Items', totalQuantity.toString()),
                      _buildSummaryCard('Total Value', _formatCurrency(totalValue)),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // Supplier Summary Table
                  pw.Text(
                    'Supplier Summary',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FixedColumnWidth(80),
                      2: const pw.FixedColumnWidth(100),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        children: [
                          _buildTableHeader('Supplier'),
                          _buildTableHeader('Returns Count'),
                          _buildTableHeader('Total Value'),
                        ],
                      ),
                      ...supplierCounts.keys.map((supplier) {
                        return pw.TableRow(
                          children: [
                            _buildTableCell(supplier),
                            _buildTableCell(
                              supplierCounts[supplier]?.toString() ?? '0',
                              alignment: pw.Alignment.centerRight,
                            ),
                            _buildTableCell(
                              _formatCurrency(supplierValues[supplier] ?? 0),
                              alignment: pw.Alignment.centerRight,
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // All Items Table
                  pw.Text(
                    'All Return Items',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FixedColumnWidth(60),
                      4: const pw.FixedColumnWidth(70),
                      5: const pw.FixedColumnWidth(50),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        children: [
                          _buildTableHeader('S/N'),
                          _buildTableHeader('Invoice'),
                          _buildTableHeader('Item'),
                          _buildTableHeader('Qty'),
                          _buildTableHeader('Unit Price'),
                          _buildTableHeader('Total'),
                        ],
                      ),
                      ...items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isEven = idx % 2 == 0;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: isEven ? PdfColors.white : PdfColors.grey100,
                          ),
                          children: [
                            _buildTableCell('${idx + 1}'),
                            _buildTableCell(item['invoice']?.toString() ?? 'N/A'),
                            _buildTableCell(item['item']?.toString() ?? 'N/A'),
                            _buildTableCell(
                              item['returnquantity']?.toString() ?? '0',
                              alignment: pw.Alignment.centerRight,
                            ),
                            _buildTableCell(
                              _formatCurrency(item['unitprice'] ?? 0),
                              alignment: pw.Alignment.centerRight,
                            ),
                            _buildTableCell(
                              _formatCurrency(item['returnvalue'] ?? 0),
                              alignment: pw.Alignment.centerRight,
                              isBold: true,
                            ),
                          ],
                        );
                      }).toList(),
                      // Grand Total Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                        ),
                        children: [
                          _buildTableCell('', colspan: 5),
                          _buildTableCell(
                            _formatCurrency(totalValue),
                            alignment: pw.Alignment.centerRight,
                            isBold: true,
                            fontSize: 12,
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 16),

                  // Footer
                  pw.Divider(thickness: 0.5),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Page ${context.pageNumber ?? 1} of ${context.pagesCount} ?? 1',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'purchase_returns_summary_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildSummaryCard(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // Delete confirmation dialog
  Future<void> _showDeleteConfirmation(BuildContext context, Map<String, dynamic> item) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400),
              const SizedBox(width: 8),
              const Text(
                'Delete Return Item',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this return item?',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2A4A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade900.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeleteInfoRow('Item', item['item'] ?? 'N/A'),
                    _buildDeleteInfoRow('Invoice', item['invoice'] ?? 'N/A'),
                    _buildDeleteInfoRow('Supplier', item['suppliername'] ?? 'N/A'),
                    _buildDeleteInfoRow('Quantity', item['returnquantity'].toString()),
                    _buildDeleteInfoRow('Value', _formatCurrency(item['returnvalue'] ?? 0)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                style: TextStyle(color: Colors.red.shade300, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        await _deleteReturnItem(item);
      }
    });
  }

  Widget _buildDeleteInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Delete function
  _deleteReturnItem(Map<String, dynamic> item) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final docId = item['docid'];

      if (docId == null) {
        throw Exception('Document ID not found');
      }

      final docRef = _firestore.collection('purchase_returns').doc(docId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        throw Exception('Document does not exist');
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];
      final archiveRef = _firestore
          .collection('deletedstock')
          .doc('${docId}_${DateTime.now().millisecondsSinceEpoch}');

      final archiveData = Map<String, dynamic>.from(data);

      archiveData.addAll({
        'deletedat': FieldValue.serverTimestamp(),
        'deletedby': context.read<Datafeed>().staff,
        'deletetype': 'purchasereturn',
        'originaldocid': docId,
      });
      final batch = _firestore.batch();

      batch.set(archiveRef, archiveData);

      final updatedItems = items.where((i) {
        if (i is Map) {
          final itemMap = Map<String, dynamic>.from(i);
          return itemMap['returnid'] != item['returnid'];
        }
        return true;
      }).toList();

      if (updatedItems.isEmpty) {
        batch.delete(docRef);
      } else {
        batch.update(docRef, {
          'items': updatedItems,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Return item "${item['item']}" deleted successfully',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {});

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting item: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final value = context.watch<Datafeed>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      appBar: AppBar(
        title: const Text(
          'Purchase Returns',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D2A4A),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isDateRangeActive
                    ? Colors.blue.shade800.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_month,
                color: _isDateRangeActive ? Colors.blue.shade300 : Colors.white70,
              ),
            ),
            onPressed: _showDateRangePicker,
            tooltip: 'Filter by date range',
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh, color: Colors.white70),
            ),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          // Print button
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.print, color: Colors.white70),
            ),
            onSelected: (value) async {
              // Get current filtered items
              final snapshot = await _firestore
                  .collection('purchase_returns')
                  .where('companyid', isEqualTo: context.read<Datafeed>().companyid)
                  .orderBy('submittedat', descending: true)
                  .get();

              final allItems = <Map<String, dynamic>>[];
              for (var doc in snapshot.docs) {
                final data = doc.data();
                final items = data['items'] as List? ?? [];
                for (var item in items) {
                  if (item is Map) {
                    final itemMap = Map<String, dynamic>.from(item);
                    final mergedItem = {
                      ...itemMap,
                      'invoice': data['invoice'] ?? 'N/A',
                      'suppliername': data['suppliername'] ?? 'N/A',
                      'branchname': data['branchname'] ?? 'N/A',
                      'createdby': data['createdby'] ?? 'N/A',
                      'purchasetype': data['purchasetype'] ?? 'N/A',
                      'waybill': data['waybill'] ?? 'N/A',
                      'submittedat': data['submittedat'],
                      'docid': doc.id,
                      'returnvalue': data['returnvalue']??0
                    };
                    if (_filterReturnItem(data, mergedItem)) {
                      allItems.add(mergedItem);
                    }
                  }
                }
              }

              if (value == 'Print Detailed') {
                await _printReturnItems(allItems);
              } else if (value == 'Print Summary') {
                await _printSummary(allItems);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Print Detailed',
                child: Row(
                  children: [
                    Icon(Icons.receipt, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Print Detailed Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Print Summary',
                child: Row(
                  children: [
                    Icon(Icons.summarize, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Print Summary'),
                  ],
                ),
              ),
            ],
            color: const Color(0xFF1E3A5F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
      body: _isLoading || _isDeleting
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      )
          : Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextFormField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    fillColor: const Color(0xFF22304A),
                    hintText: 'Search by invoice, supplier, item, barcode...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        setState(() {
                          _searchQuery = "";
                        });
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._filterOptions.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = selected ? filter : 'All';
                              });
                            },
                            backgroundColor: const Color(0xFF22304A),
                            selectedColor: Colors.blue.shade800,
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.blue.shade300
                                  : Colors.white24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }),
                      if (_isDateRangeActive)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade700.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range, size: 14, color: Colors.blue),
                              const SizedBox(width: 6),
                              Text(
                                '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _clearDateRange,
                                child: const Icon(Icons.close, size: 14, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table/List View
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('purchase_returns')
                  .where('companyid', isEqualTo: value.companyid)
                  .orderBy('submittedat', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          color: Colors.white38,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No purchase returns found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }

                // Flatten all items from all transactions with proper type casting
                final allItems = <Map<String, dynamic>>[];
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final items = data['items'] as List? ?? [];

                  for (var item in items) {
                    if (item is Map) {
                      final itemMap = Map<String, dynamic>.from(item);
                      final mergedItem = {
                        ...itemMap,
                        'invoice': data['invoice'] ?? 'N/A',
                        'suppliername': data['suppliername'] ?? 'N/A',
                        'branchname': data['branchname'] ?? 'N/A',
                        'createdby': data['createdby'] ?? 'N/A',
                        'purchasetype': data['purchasetype'] ?? 'N/A',
                        'waybill': data['waybill'] ?? 'N/A',
                        'submittedat': data['submittedat'],
                        'docid': doc.id,
                        'returnvalue': data['returnvalue'] ??0,
                        'itemz': data['items'] ?? [],
                      };

                      if (_filterReturnItem(data, mergedItem)) {
                        allItems.add(mergedItem);
                      }
                    }
                  }
                }

                if (allItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No returns found for "$_searchQuery"'
                              : 'No matching returns found',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                        ),
                        if (_searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                            child: const Text('Clear search'),
                          ),
                      ],
                    ),
                  );
                }

                if (isMobile) {
                  return _buildMobileList(allItems, value);
                } else {
                  return _buildDesktopTable(allItems);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> items, Datafeed value) {
    return ListView.builder(
      controller: _verticalController,
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final canDelete = value.canDelete(AppModules.stock);

        return Dismissible(
          key: Key(item['returnid'] ?? '${index}_${DateTime.now().millisecondsSinceEpoch}'),
          direction: canDelete ? DismissDirection.endToStart : DismissDirection.none,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade800,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white, size: 30),
          ),
          onDismissed: (direction) {
            if (canDelete) {
              _showDeleteConfirmation(context, item);
            }
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: const Color(0xFF1E3A5F),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blue.shade900.withOpacity(0.3),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INV: ${item['invoice']}',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              item['item'] ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildPurchaseTypeChip(item['purchasetype'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Details Grid
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Supplier', item['suppliername']),
                            _buildInfoRow('Barcode', item['barcode']),
                            _buildInfoRow('Date', _formatDateOnly(item['submittedat'])),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildInfoRow('Qty', item['returnquantity'].toString()),
                            _buildInfoRow(
                              'Value',
                              _formatCurrency(item['net_returnvalue'] ?? 0),
                            ),
                            _buildInfoRow('Waybill', item['waybill']),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Reason, Status and Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D2A4A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Reason: ${item['returnreason'] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(item['returnStatus'] ?? ''),
                      const SizedBox(width: 4),
                      // Print icon (always visible, before delete)
                      IconButton(
                        icon: const Icon(
                          Icons.print,
                          color: Colors.blueGrey,
                          size: 20,
                        ),
                        onPressed: () => _printSingleInvoice(item),
                        tooltip: 'Print this return',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      if (canDelete) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _showDeleteConfirmation(context, item),
                          tooltip: 'Delete',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> items) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF0D2A4A),
                ),
                columnSpacing: 12,
                headingTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                dataTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Invoice')),
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Barcode')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Value')),
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Waybill')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: List.generate(items.length, (index) {
                  final item = items[index];
                  final value = context.read<Datafeed>();
                  final canDelete = value.canDelete(AppModules.stock);

                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>(
                          (Set<WidgetState> states) {
                        return index.isEven
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFF162D4A);
                      },
                    ),
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(
                        Text(
                          item['invoice'] ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['item'] ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['barcode'] ?? 'N/A',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['suppliername'] ?? 'N/A',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(
                        Text(_formatDateOnly(item['submittedat'])),
                      ),
                      DataCell(
                        Text(
                          item['returnquantity'].toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatCurrency(item['net_returnvalue'] ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            item['returnreason'] ?? 'N/A',
                            style: TextStyle(color: Colors.grey.shade300),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          item['waybill'] ?? 'N/A',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                      DataCell(
                        _buildPurchaseTypeChip(item['purchasetype'] ?? 'N/A'),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Print icon (always visible, before delete)
                            IconButton(
                              icon: const Icon(
                                Icons.print,
                                color: Colors.blueGrey,
                                size: 20,
                              ),
                              onPressed: () => _printSingleInvoice(item),
                              tooltip: 'Print this return',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            if (canDelete)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () => _showDeleteConfirmation(context, item),
                                tooltip: 'Delete',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}