import 'dart:typed_data';
import 'package:flutter/services.dart';

class SilentPrinter {
  static const MethodChannel _channel = MethodChannel('printer_channel');

  static Future<void> printPdf(Uint8List bytes) async {
    try {
      await _channel.invokeMethod('printPdf', {
        'bytes': bytes,
      });
    } catch (e) {
      print("Print error: $e");
    }
  }



}