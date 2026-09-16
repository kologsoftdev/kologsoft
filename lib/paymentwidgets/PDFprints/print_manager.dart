// ============================================================
//  lib/services/print_manager.dart
//  Kologsoft — Smart Print Manager Mixin
//
//  Mix this into any StatefulWidget State to get:
//    silentPrint(pdf)      auto-detects printer, prints silently
//    changePrinter()       lets user pick a new printer
//    showPrinterPicker()   shows dark-themed picker dialog
//
//  Priority order:
//    1. Saved printer from last session  (SharedPreferences)
//    2. Windows default printer          (Win32 GetDefaultPrinter)
//    3. First printer in the list        (fallback)
//    4. User picker dialog               (last resort)
// ============================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'print_service.dart';

mixin PrintManager<T extends StatefulWidget> on State<T> {

  // ----------------------------------------------------------
  //  silentPrint(pdf)
  //  Main entry point. Call this wherever you currently call
  //  Printing.layoutPdf(). No Windows dialog will appear.
  // ----------------------------------------------------------
  Future<void> silentPrint(pw.Document pdf) async {
    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
      _showSnack('Opened browser print dialog', Colors.green);
      return;
    }

    // Step 1 — try saved printer from last session
    String? printerName = await PrintService.getSavedPrinter();

    if (printerName != null) {
      final result = await PrintService.printPdf(
          printerName: printerName, pdf: pdf);

      if (result.success) {
        _showSnack('Printed to $printerName', Colors.green);
        return;
      }
      // Saved printer failed (unplugged / renamed) — fall through
      _showSnack(
          'Saved printer "$printerName" not available — finding another…',
          Colors.orange);
      await PrintService.clearSavedPrinter();
    }

    // Step 2 — try Windows default printer
    printerName = await PrintService.getDefaultPrinter();

    if (printerName != null) {
      final result = await PrintService.printPdf(
          printerName: printerName, pdf: pdf);

      if (result.success) {
        await PrintService.savePrinter(printerName); // remember it
        _showSnack('Printed to $printerName', Colors.green);
        return;
      }
      // Default printer failed — fall through
    }

    // Step 3 — try first printer in the list
    final printers = await PrintService.getPrinters();

    if (printers.isNotEmpty) {
      printerName = printers.first;
      final result = await PrintService.printPdf(
          printerName: printerName, pdf: pdf);

      if (result.success) {
        await PrintService.savePrinter(printerName);
        _showSnack('Printed to $printerName', Colors.green);
        return;
      }
    }

    // Step 4 — nothing worked automatically; show picker
    if (!mounted) return;
    final chosen = await showPrinterPicker();
    if (chosen == null) return; // user cancelled

    final result =
    await PrintService.printPdf(printerName: chosen, pdf: pdf);

    if (!mounted) return;
    if (result.success) {
      await PrintService.savePrinter(chosen);
      _showSnack('Printed to $chosen', Colors.green);
    } else {
      _showSnack(
          'Print failed: ${result.errorMessage}', Colors.redAccent,
          changePrinterAction: true, pdf: pdf);
    }
  }

  // ----------------------------------------------------------
  //  silentPrintRaw(text)
  //  Sends plain text to the printer instead of rendering a PDF.
  // ----------------------------------------------------------
  Future<void> silentPrintRaw(String text) async {
    if (kIsWeb) {
      _showSnack('Raw printing is not supported on web', Colors.orange);
      return;
    }

    String? printerName = await PrintService.getSavedPrinter();

    if (printerName != null) {
      final result = await PrintService.printRaw(
          printerName: printerName, text: text);
      if (result.success) {
        _showSnack('Printed to $printerName', Colors.green);
        return;
      }
      _showSnack(
          'Saved printer "$printerName" not available — finding another…',
          Colors.orange);
      await PrintService.clearSavedPrinter();
    }

    printerName = await PrintService.getDefaultPrinter();

    if (printerName != null) {
      final result = await PrintService.printRaw(
          printerName: printerName, text: text);
      if (result.success) {
        await PrintService.savePrinter(printerName);
        _showSnack('Printed to $printerName', Colors.green);
        return;
      }
    }

    final printers = await PrintService.getPrinters();
    if (printers.isNotEmpty) {
      printerName = printers.first;
      final result = await PrintService.printRaw(
          printerName: printerName, text: text);
      if (result.success) {
        await PrintService.savePrinter(printerName);
        _showSnack('Printed to $printerName', Colors.green);
        return;
      }
    }

    if (!mounted) return;
    final chosen = await showPrinterPicker();
    if (chosen == null) return;

    final result = await PrintService.printRaw(printerName: chosen, text: text);
    if (!mounted) return;
    if (result.success) {
      await PrintService.savePrinter(chosen);
      _showSnack('Printed to $chosen', Colors.green);
    } else {
      _showSnack(
          'Print failed: ${result.errorMessage}', Colors.redAccent,
          changePrinterAction: true);
    }
  }

  // ----------------------------------------------------------
  //  changePrinter()
  //  Clears the saved printer and lets the user pick a new one.
  //  Wire this to a Settings button or a SnackBar action.
  // ----------------------------------------------------------
  Future<void> changePrinter() async {
    if (kIsWeb) {
      if (mounted) {
        _showSnack('Printer selection is not supported on web', Colors.orange);
      }
      return;
    }

    await PrintService.clearSavedPrinter();
    if (!mounted) return;
    final chosen = await showPrinterPicker();
    if (chosen == null) return;
    await PrintService.savePrinter(chosen);
    if (!mounted) return;
    _showSnack('Printer set to "$chosen"', Colors.green);
  }

  // ----------------------------------------------------------
  //  showPrinterPicker()
  //  Dark-themed dialog listing all Windows printers.
  //  Returns the selected name or null if cancelled.
  // ----------------------------------------------------------
  Future<String?> showPrinterPicker() async {
    if (kIsWeb) {
      if (mounted) {
        _showSnack('Printer selection is not supported on web', Colors.orange);
      }
      return null;
    }

    final printers = await PrintService.getPrinters();

    if (!mounted) return null;

    if (printers.isEmpty) {
      _showSnack('No printers found on this computer', Colors.redAccent);
      return null;
    }

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PrintPickerDialog(printers: printers),
    );
  }

  // ----------------------------------------------------------
  //  Internal helpers
  // ----------------------------------------------------------
  void _showSnack(
      String message,
      Color color, {
        bool changePrinterAction = false,
        pw.Document? pdf,
      }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: changePrinterAction
            ? SnackBarAction(
          label: 'Change Printer',
          textColor: Colors.white,
          onPressed: changePrinter,
        )
            : null,
      ),
    );
  }
}

// ============================================================
//  Private dialog widget
// ============================================================
class _PrintPickerDialog extends StatefulWidget {
  final List<String> printers;
  const _PrintPickerDialog({required this.printers});

  @override
  State<_PrintPickerDialog> createState() => _PrintPickerDialogState();
}

class _PrintPickerDialogState extends State<_PrintPickerDialog> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.printers
        .where((p) => p.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.print, color: Color(0xFFFFC857)),
          SizedBox(width: 10),
          Text('Select Printer',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ],
      ),
      content: SizedBox(
        width: 360,
        height: 320,
        child: Column(
          children: [
            // Search field
            TextField(
              onChanged: (v) => setState(() => _filter = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search printers…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF0D1B2A),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Printer list
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                  child: Text('No printers match',
                      style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white12, height: 1),
                itemBuilder: (context, index) {
                  final name = filtered[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.print_outlined,
                        color: Color(0xFFFFC857), size: 20),
                    title: Text(
                      name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                    hoverColor: Colors.white10,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    onTap: () => Navigator.pop(context, name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}