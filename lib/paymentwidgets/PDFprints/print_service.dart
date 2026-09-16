// ============================================================
//  lib/services/print_service.dart
//  Kologsoft — Silent Windows Printing Service
//
//  Talks to the native Win32 channel registered in
//  print_channel.cpp via the MethodChannel
//  "com.kologsoft/printing".
//
//  Public API:
//    getPrinters()         → Future<List<String>>
//    getDefaultPrinter()   → Future<String?>
//    getSavedPrinter()     → Future<String?>
//    savePrinter(name)     → Future<void>
//    clearSavedPrinter()   → Future<void>
//    printPdf(name, pdf)   → Future<PrintResult>
// ============================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

// ---- Result wrapper so callers know what went wrong --------
class PrintResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  final String? printerUsed;

  const PrintResult.ok(this.printerUsed)
      : success = true,
        errorCode = null,
        errorMessage = null;

  const PrintResult.fail(this.errorCode, this.errorMessage)
      : success = false,
        printerUsed = null;

  @override
  String toString() => success
      ? 'PrintResult.ok(printer: $printerUsed)'
      : 'PrintResult.fail($errorCode: $errorMessage)';
}

// ---- Main service class ------------------------------------
class PrintService {
  PrintService._(); // not instantiable

  // Channel name — must match print_channel.cpp exactly
  static const _channel = MethodChannel('com.kologsoft/printing');

  // SharedPreferences key for remembered printer
  static const _prefKey = 'kologsoft_last_printer';

  // ----------------------------------------------------------
  //  getPrinters()
  //  Returns the name of every printer Windows knows about.
  //  Returns [] if the channel fails.
  // ----------------------------------------------------------
  static Future<List<String>> getPrinters() async {
    if (kIsWeb) {
      debugLog('getPrinters called on web; returning []');
      return [];
    }
    try {
      final List<dynamic> raw =
          await _channel.invokeMethod<List<dynamic>>('getPrinters') ?? [];
      return raw.cast<String>();
    } on PlatformException catch (e) {
      debugLog('getPrinters error: ${e.code} — ${e.message}');
      return [];
    }
  }

  // ----------------------------------------------------------
  //  getDefaultPrinter()
  //  Returns the name Windows has set as the default printer,
  //  or null if none is configured.
  // ----------------------------------------------------------
  static Future<String?> getDefaultPrinter() async {
    if (kIsWeb) {
      debugLog('getDefaultPrinter called on web; returning null');
      return null;
    }
    try {
      final String? name =
      await _channel.invokeMethod<String>('getDefaultPrinter');
      return (name != null && name.isNotEmpty) ? name : null;
    } on PlatformException catch (e) {
      debugLog('getDefaultPrinter error: ${e.code} — ${e.message}');
      return null;
    }
  }

  // ----------------------------------------------------------
  //  getSavedPrinter()
  //  Returns the printer name saved from a previous session,
  //  or null if none has been saved yet.
  // ----------------------------------------------------------
  static Future<String?> getSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      return (saved != null && saved.isNotEmpty) ? saved : null;
    } catch (e) {
      debugLog('getSavedPrinter error: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  //  savePrinter(name)
  //  Persists a printer name for future sessions.
  // ----------------------------------------------------------
  static Future<void> savePrinter(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, name);
    } catch (e) {
      debugLog('savePrinter error: $e');
    }
  }

  // ----------------------------------------------------------
  //  clearSavedPrinter()
  //  Removes the saved printer so the picker shows next time.
  // ----------------------------------------------------------
  static Future<void> clearSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugLog('clearSavedPrinter error: $e');
    }
  }

  // ----------------------------------------------------------
  //  printRaw(printerName, text)
  //  Sends plain text directly to the named printer.
  //  This avoids PDF rendering and is the preferred path
  //  for text-only receipts and simple printer output.
  // ----------------------------------------------------------
  static Future<PrintResult> printRaw({
    required String printerName,
    required String text,
  }) async {
    if (kIsWeb) {
      return const PrintResult.fail(
          'UNSUPPORTED_PLATFORM', 'Silent raw printing is not supported on web');
    }

    if (text.isEmpty) {
      return const PrintResult.fail('EMPTY_TEXT', 'No text to print');
    }

    try {
      final bool ok = await _channel.invokeMethod<bool>('printText', {
        'printer': printerName,
        'text': text,
      }) ??
          false;

      if (ok) {
        return PrintResult.ok(printerName);
      } else {
        return const PrintResult.fail(
            'PRINT_FAILED', 'Native layer returned false');
      }
    } on PlatformException catch (e) {
      return PrintResult.fail(e.code, e.message);
    } catch (e) {
      return PrintResult.fail('UNKNOWN', e.toString());
    }
  }

  // ----------------------------------------------------------
  //  printPdf(printerName, pdf)
  //  Sends the pw.Document to the named printer silently.
  //  Returns a PrintResult with success/failure detail.
  // ----------------------------------------------------------
  static Future<PrintResult> printPdf({
    required String printerName,
    required pw.Document pdf,
  }) async {
    if (kIsWeb) {
      return const PrintResult.fail(
          'UNSUPPORTED_PLATFORM', 'Silent printing is not supported on web');
    }
    try {
      // Render the PDF document to raw bytes
      final Uint8List bytes = await pdf.save();

      if (bytes.isEmpty) {
        return const PrintResult.fail(
            'EMPTY_PDF', 'pdf.save() returned 0 bytes');
      }

      final bool ok = await _channel.invokeMethod<bool>('printPdf', {
        'printer': printerName,
        'bytes': bytes,
      }) ??
          false;

      if (ok) {
        return PrintResult.ok(printerName);
      } else {
        return const PrintResult.fail(
            'PRINT_FAILED', 'Native layer returned false');
      }
    } on PlatformException catch (e) {
      return PrintResult.fail(e.code, e.message);
    } catch (e) {
      return PrintResult.fail('UNKNOWN', e.toString());
    }
  }

  // ----------------------------------------------------------
  //  Internal debug logger — remove in production if desired
  // ----------------------------------------------------------
  static void debugLog(String msg) {
    // ignore: avoid_print
    print('[PrintService] $msg');
  }
}