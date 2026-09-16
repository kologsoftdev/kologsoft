// ============================================================
//  lib/screens/print_test_screen.dart
//  Kologsoft — Silent Print Test Screen
//
//  Use this screen to verify the full print pipeline works
//  before wiring it into your real stock/sales screens.
//
//  It generates a realistic Kologsoft receipt PDF and sends
//  it to the auto-detected printer with zero dialogs.
// ============================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/paymentwidgets/PDFprints/print_manager.dart';
import 'package:kologsoft/paymentwidgets/PDFprints/print_service.dart';



class PrintTestScreen extends StatefulWidget {
  const PrintTestScreen({super.key});

  @override
  State<PrintTestScreen> createState() => _PrintTestScreenState();
}

// Mix in PrintManager — this gives us silentPrint() and changePrinter()
class _PrintTestScreenState extends State<PrintTestScreen>
    with PrintManager {

  bool _printing = false;
  String _status = 'Ready';
  String? _savedPrinter;
  List<String> _allPrinters = [];

  // ----------------------------------------------------------
  //  Trial data — replace with real Datafeed values later
  // ----------------------------------------------------------
  final _trialHeader = {
    'company':    'KOLOGSOFT ENTERPRISE',
    'branch':     'Main Branch',
    'invoice':    'INV-2026-00142',
    'waybill':    'WB-00088',
    'supplier':   'Accra Wholesale Ltd',
    'staff':      'John Mensah',
    'date':       DateTime(2026, 6, 25),
    'purchasetype': 'Cash',
  };

  final _trialItems = [
    {'item': 'Milo 400g Tin',         'mode': 'Carton', 'qty': 5.0,  'price': 220.00, 'discount': 10.00, 'total': 1090.00},
    {'item': 'Nescafe Classic 200g',  'mode': 'Carton', 'qty': 3.0,  'price': 185.00, 'discount': 0.00,  'total':  555.00},
    {'item': 'Peak Milk Sachet 15g',  'mode': 'Carton', 'qty': 10.0, 'price':  48.50, 'discount': 5.00,  'total':  480.00},
    {'item': 'Indomie Chicken 70g',   'mode': 'Carton', 'qty': 8.0,  'price':  62.00, 'discount': 0.00,  'total':  496.00},
    {'item': 'Sunlight Soap 500g',    'mode': 'Pack',   'qty': 20.0, 'price':  12.50, 'discount': 0.00,  'total':  250.00},
  ];

  @override
  void initState() {
    super.initState();
    _loadPrinterInfo();
  }

  Future<void> _loadPrinterInfo() async {
    final saved   = await PrintService.getSavedPrinter();
    final all     = await PrintService.getPrinters();
    if (mounted) {
      setState(() {
        _savedPrinter = saved;
        _allPrinters  = all;
      });
    }
  }

  // ----------------------------------------------------------
  //  Build the test receipt as raw plain text
  // ----------------------------------------------------------
  String _buildRawReceipt() {
    const width = 42;
    final fmt = NumberFormat.currency(symbol: 'GHC ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy');
    final date = _trialHeader['date'] as DateTime;
    final items = _trialItems;

    double gross = items.fold(0, (s, i) => s + (i['price'] as double) * (i['qty'] as double));
    double discount = items.fold(0, (s, i) => s + (i['discount'] as double));
    double net = items.fold(0, (s, i) => s + (i['total'] as double));

    final lines = StringBuffer();
    lines.writeln(_centerText('KOLOGSOFT ENTERPRISE', width));
    lines.writeln(_centerText('STOCK PURCHASE RECEIPT', width));
    lines.writeln(_repeat('-', width));
    lines.writeln(_wrapText('Invoice : ${_trialHeader['invoice']}', width));
    lines.writeln(_wrapText('Waybill : ${_trialHeader['waybill']}', width));
    lines.writeln(_wrapText('Staff   : ${_trialHeader['staff']}', width));
    lines.writeln(_wrapText('Type    : ${_trialHeader['purchasetype']}', width));
    lines.writeln(_wrapText('Supplier: ${_trialHeader['supplier']}', width));
    lines.writeln(_wrapText('Branch  : ${_trialHeader['branch']}', width));
    lines.writeln(_wrapText('Date    : ${dateFmt.format(date)}', width));
    lines.writeln(_repeat('-', width));
    lines.writeln(_formatColumns(['No', 'Item', 'Qty', 'Price', 'Disc', 'Total'], [2, 18, 3, 8, 7, 8]));
    lines.writeln(_repeat('-', width));

    for (var index = 0; index < items.length; index++) {
      final row = items[index];
      final itemName = row['item'] as String;
      final qty = (row['qty'] as double).toStringAsFixed(0);
      final price = fmt.format(row['price']);
      final disc = fmt.format(row['discount']);
      final total = fmt.format(row['total']);

      for (final line in _formatItemLines(
        (index + 1).toString().padLeft(2),
        itemName,
        qty,
        price,
        disc,
        total,
      )) {
        lines.writeln(line);
      }
    }

    lines.writeln(_repeat('-', width));
    lines.writeln(_alignSummary('Gross Total', fmt.format(gross), width));
    lines.writeln(_alignSummary('Discount', fmt.format(discount), width));
    lines.writeln(_alignSummary('NET PAYABLE', fmt.format(net), width));
    lines.writeln(_repeat('-', width));
    lines.writeln(_centerText('Generated : ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}', width));
    lines.writeln(_centerText('Kologsoft POS — ${_trialHeader['company']}', width));
    lines.writeln(_centerText('Thank you for your purchase!', width));
    lines.writeln();
    lines.write(_paperCutCommand());
    return lines.toString();
  }

  List<String> _formatItemLines(
    String no,
    String itemName,
    String qty,
    String price,
    String disc,
    String total,
  ) {
    final result = <String>[];
    final wrappedItem = _wrapLine(itemName, 18);

    for (var i = 0; i < wrappedItem.length; i++) {
      if (i == 0) {
        result.add(_formatColumns([no, wrappedItem[i], qty, price, disc, total], [2, 18, 3, 8, 7, 8]));
      } else {
        result.add(_formatColumns(['', wrappedItem[i], '', '', '', ''], [2, 18, 3, 8, 7, 8]));
      }
    }
    return result;
  }

  String _centerText(String text, int width) {
    final trimmed = text.trim();
    if (trimmed.length >= width) return trimmed;
    final pad = width - trimmed.length;
    final left = pad ~/ 2;
    final right = pad - left;
    return '${' ' * left}$trimmed${' ' * right}';
  }

  String _repeat(String char, int count) => List.filled(count, char).join();

  String _wrapText(String text, int width) {
    final words = text.split(' ');
    final buffer = StringBuffer();
    var line = StringBuffer();

    for (final word in words) {
      if (line.isEmpty) {
        line.write(word);
      } else if (line.length + 1 + word.length > width) {
        buffer.writeln(line.toString());
        line = StringBuffer(word);
      } else {
        line.write(' $word');
      }
    }

    if (line.isNotEmpty) {
      buffer.write(line.toString());
    }
    return buffer.toString();
  }

  List<String> _wrapLine(String text, int width) {
    final words = text.split(' ');
    final result = <String>[];
    var line = StringBuffer();

    for (final word in words) {
      if (line.isEmpty) {
        line.write(word);
      } else if (line.length + 1 + word.length > width) {
        result.add(line.toString());
        line = StringBuffer(word);
      } else {
        line.write(' $word');
      }
    }

    if (line.isNotEmpty) {
      result.add(line.toString());
    }
    return result;
  }

  String _formatColumns(List<String> columns, List<int> widths) {
    final buffer = StringBuffer();
    for (var i = 0; i < columns.length; i++) {
      final value = columns[i].trim();
      final width = widths[i];
      final part = i == 0 ? value.padRight(width) : value.padLeft(width);
      if (i > 0) buffer.write(' ');
      buffer.write(part.length > width ? part.substring(0, width) : part);
    }
    return buffer.toString();
  }

  String _alignSummary(String label, String value, int width) {
    final labelText = label.padRight(width - value.length - 1);
    return '$labelText $value';
  }

  String _paperCutCommand() {
    return String.fromCharCodes([0x1B, 0x69]) +
        String.fromCharCodes([0x1D, 0x56, 0x41, 0x00]);
  }


  // ----------------------------------------------------------
  //  Print button handler
  // ----------------------------------------------------------
  Future<void> _onPrint() async {
    setState(() {
      _printing = true;
      _status   = 'Building receipt…';
    });

    try {
      final rawReceipt = _buildRawReceipt();
      setState(() => _status = 'Sending to printer…');
      await silentPrintRaw(rawReceipt); // from PrintManager mixin
      setState(() => _status = 'Done');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
      await _loadPrinterInfo();         // refresh printer info display
    }
  }

  // ----------------------------------------------------------
  //  UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        title: const Text('Silent Print Test'),
        actions: [
          IconButton(
            tooltip: 'Change Printer',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await changePrinter();    // from PrintManager mixin
              await _loadPrinterInfo();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ---- Printer status card ----
                _sectionCard(
                  title: 'Printer Status',
                  icon: Icons.print,
                  child: Column(
                    children: [
                      _infoRow('Saved Printer',
                          _savedPrinter ?? '— none saved yet'),
                      const SizedBox(height: 8),
                      _infoRow('Total Printers Found',
                          '${_allPrinters.length}'),
                      if (kIsWeb) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25324D),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Web builds use the browser print dialog. Silent Windows printing is unavailable on web.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      if (_allPrinters.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 4),
                        ..._allPrinters.map((p) => Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            const Icon(Icons.print_outlined,
                                color: Color(0xFFFFC857), size: 14),
                            const SizedBox(width: 8),
                            Text(p,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12)),
                            if (p == _savedPrinter) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color.fromRGBO(76, 175, 80, 0.2),
                                  borderRadius:
                                  BorderRadius.circular(4),
                                ),
                                child: const Text('SAVED',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ]),
                        )),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Trial data preview card ----
                _sectionCard(
                  title: 'Trial Print Data',
                  icon: Icons.receipt_long,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Company',  _trialHeader['company'] as String),
                      _infoRow('Invoice',  _trialHeader['invoice'] as String),
                      _infoRow('Supplier', _trialHeader['supplier'] as String),
                      _infoRow('Items',    '${_trialItems.length} lines'),
                      _infoRow('Net Total',
                          'GHC ${_trialItems.fold(0.0, (s, i) => s + (i['total'] as double)).toStringAsFixed(2)}'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Status ----
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(children: [
                    Icon(
                      _status == 'Done'
                          ? Icons.check_circle
                          : _status.startsWith('Error')
                          ? Icons.error_outline
                          : Icons.info_outline,
                      color: _status == 'Done'
                          ? Colors.green
                          : _status.startsWith('Error')
                          ? Colors.redAccent
                          : const Color(0xFFFFC857),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_status,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ),
                  ]),
                ),

                const SizedBox(height: 28),

                // ---- Action buttons ----
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF415A77),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _printing ? null : _onPrint,
                        icon: _printing
                            ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.print, color: Colors.white),
                        label: Text(
                          _printing ? 'Printing…' : 'TEST PRINT',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await changePrinter();
                        await _loadPrinterInfo();
                      },
                      icon: const Icon(Icons.swap_horiz,
                          color: Colors.white54),
                      label: const Text('CHANGE PRINTER',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFFFFC857), size: 16),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ]),
    );
  }
}