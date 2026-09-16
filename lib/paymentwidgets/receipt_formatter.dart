import 'package:intl/intl.dart';
import '../models/Receiptdatamodel.dart';

String buildRawReceiptText(ReceiptData data, {int width = 42}) {
  final fmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final company = data.companyName.trim().toUpperCase();
  final receiptTitle = data.receiptName.trim().isEmpty
      ? 'RECEIPT'
      : data.receiptName.trim().toUpperCase();
  final branch = data.branch?.trim() ?? '';
  final address = data.address?.trim() ?? '';
  final contact = data.contact.trim();
  final email = data.email.trim();
  final cashier = data.cashier.trim();
  final customer = data.customername.trim().isEmpty
      ? 'CASH CUSTOMER'
      : data.customername.trim();
  final barcode = data.barcode.trim().isNotEmpty
      ? data.barcode.trim()
      : data.receiptNumber.trim();

  final columnWidths = _receiptColumnWidths(width);
  final buffer = StringBuffer();
  final rule = _repeat('-', width);

  buffer.writeln(_centerText(company, width));
  buffer.writeln(_centerText(receiptTitle, width));
  buffer.writeln(rule);

  if (branch.isNotEmpty) {
    buffer.writeln(_wrapText('Branch: $branch', width));
  }
  if (address.isNotEmpty) {
    buffer.writeln(_wrapText('Address: $address', width));
  }
  buffer.writeln(_wrapText('Contact: $contact', width));
  if (email.isNotEmpty) {
    buffer.writeln(_wrapText('Email: $email', width));
  }
  buffer.writeln(_wrapText('Cashier: $cashier', width));
  buffer.writeln(_wrapText('Customer: $customer', width));
  buffer.writeln(_wrapText('Date: ${dateFmt.format(data.datetime)}', width));
  buffer.writeln(_wrapText('Receipt: ${data.receiptNumber}', width));
  // if (data.transactionId != null && data.transactionId!.isNotEmpty) {
  //   buffer.writeln(_wrapText('Txn ID: ${data.transactionId}', width));
  // }
  buffer.writeln(rule);
  buffer.write(_barcode128Command(barcode, moduleWidth: _barcodeModuleWidthForWidth(width)));

  buffer.writeln(rule);

  buffer.writeln(_formatColumns(
    ['Item', 'Qty', 'Price', 'Total'],
    columnWidths,
  ));
  buffer.writeln(rule);

  for (final item in data.items) {
    final itemName = item.name.trim();
    final lineTotal = item.qty * item.price;
    final qtyText = item.qty == item.qty.roundToDouble()
        ? item.qty.toStringAsFixed(0)
        : item.qty.toStringAsFixed(2);
    final priceText = fmt.format(item.price);
    final totalText = fmt.format(lineTotal);

    for (final line in _formatItemLines(
      itemName,
      qtyText,
      priceText,
      totalText,
      columnWidths,
    )) {
      buffer.writeln(line);
    }
  }

  buffer.writeln(rule);
  buffer.writeln(_formatSummary('Sub Total', fmt.format(data.subTotal), width));
  buffer.writeln(_formatSummary('Discount', fmt.format(data.discount), width));
  buffer.writeln(_formatSummary('VAT (${data.vatPercent}%)', fmt.format(data.vatAmount), width));
  buffer.writeln(_formatSummary('Payable', fmt.format(data.payable), width, bold: true));
  buffer.writeln(_formatSummary('Paid', fmt.format(data.amountPaid), width));
  buffer.writeln(_formatSummary('Change', fmt.format(data.change < 0 ? 0.0 : data.change), width, bold: true));
  buffer.writeln(rule);

  final isChristmas = DateTime.now().month == 12;

  buffer.writeln(_leftText(
    isChristmas
        ? 'Thank you for choosing $company. Happy Christmas!'
        : 'Thank you for choosing $company!',
    width,
  ));

  buffer.writeln(_leftText(
    'Exchanges accepted within 7 days. No cash refund.',
    width,
  ));

  buffer.writeln(_centerText('POWERED BY KOLOGSOFT', width));

  buffer.writeln();

  buffer.write(_setAlignCenter());
  buffer.write(_qrCodeCommand(barcode));
  buffer.write(_setAlignLeft());

  buffer.writeln();
  buffer.writeln();
  buffer.write(_paperCutCommand());

  return buffer.toString();
}

int receiptWidthForPrinter(String? printerName) {
  if (printerName == null) return 48;
  final lower = printerName.toLowerCase();
  if (lower.contains('58') || lower.contains('2 inch') || lower.contains('2in') || lower.contains('58mm')) {
    return 32;
  }
  if (lower.contains('80') || lower.contains('3 inch') || lower.contains('3in') || lower.contains('80mm')) {
    return 48;
  }
  return 48;
}

String _repeat(String char, int count) => List.filled(count, char).join();

String _centerText(String text, int width) {
  final trimmed = text.trim();
  if (trimmed.length >= width) {
    return trimmed;
  }
  final pad = width - trimmed.length;
  final left = pad ~/ 2;
  final right = pad - left;
  return '${' ' * left}$trimmed${' ' * right}';
}
String _leftText(String text, int width) {
  final trimmed = text.trim();
  if (trimmed.length >= width) {
    return trimmed;
  }
  return trimmed.padRight(width);
}
String _wrapText(String text, int width) {
  final words = text.split(' ');
  final buffer = StringBuffer();
  var line = StringBuffer();

  for (final word in words) {
    if (line.isEmpty) {
      line.write(word);
      continue;
    }
    if (line.length + 1 + word.length > width) {
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

List<int> _receiptColumnWidths(int width) {
  if (width <= 32) {
    return [10, 4, 6, 8];
  }
  if (width <= 42) {
    return [15, 4, 9, 10];
  }
  return [18, 4, 10, 12];
}

Iterable<String> _formatItemLines(
  String itemName,
  String qtyText,
  String priceText,
  String totalText,
  List<int> widths,
) {
  final lines = <String>[];
  final itemLines = _wrapLine(itemName, widths[0]);

  for (var index = 0; index < itemLines.length; index++) {
    final nameValue = itemLines[index];
    if (index == 0) {
      lines.add(_formatColumns(
        [nameValue, qtyText, priceText, totalText],
        widths,
      ));
    } else {
      lines.add(_formatColumns([
        nameValue,
        '',
        '',
        '',
      ], widths));
    }
  }

  return lines;
}

List<String> _wrapLine(String text, int width) {
  final words = text.split(' ');
  final result = <String>[];
  var line = StringBuffer();

  for (final word in words) {
    final nextLength = line.isEmpty ? word.length : line.length + 1 + word.length;
    if (nextLength > width) {
      if (line.isNotEmpty) {
        result.add(line.toString());
      }
      if (word.length > width) {
        var remaining = word;
        while (remaining.length > width) {
          result.add(remaining.substring(0, width));
          remaining = remaining.substring(width);
        }
        line = StringBuffer(remaining);
      } else {
        line = StringBuffer(word);
      }
    } else {
      if (line.isEmpty) {
        line.write(word);
      } else {
        line.write(' $word');
      }
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
    var value = columns[i].trim();
    final width = widths[i];
    if (value.length > width) {
      value = value.substring(0, width);
    }
    final part = i == 0 ? value.padRight(width) : value.padLeft(width);
    if (i > 0) {
      buffer.write(' ');
    }
    buffer.write(part);
  }
  return buffer.toString();
}


String _qrCodeCommand(String data, {int moduleSize = 6, int errorCorrection = 49}) {
  final bytes = <int>[];

  bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
  bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize]);
  bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, errorCorrection]);

  final dataBytes = data.codeUnits;
  final storeLen = dataBytes.length + 3;
  bytes.addAll([0x1D, 0x28, 0x6B, storeLen & 0xFF, (storeLen >> 8) & 0xFF, 0x31, 0x50, 0x30]);
  bytes.addAll(dataBytes);

  bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

  return String.fromCharCodes(bytes);
}

String _barcode128Command(String data, {int moduleWidth = 2, int height = 80, int hriPosition = 2}) {
  final bytes = <int>[];

  bytes.addAll([0x1D, 0x77, moduleWidth]);
  bytes.addAll([0x1D, 0x68, height]);
  bytes.addAll([0x1D, 0x48, hriPosition]);
  bytes.addAll([0x1D, 0x66, 0x00]);

  final codeData = data;
  final dataBytes = codeData.codeUnits;
  bytes.addAll([0x1D, 0x6B, 73, dataBytes.length]);
  bytes.addAll(dataBytes);

  return String.fromCharCodes(bytes);
}
String _setAlignCenter() => String.fromCharCodes([0x1B, 0x61, 0x01]);

String _setAlignLeft() => String.fromCharCodes([0x1B, 0x61, 0x00]);
int _barcodeModuleWidthForWidth(int width) {
  if (width <= 32) return 2;
  if (width <= 42) return 2;
  return 3;
}
// String _paperCutCommand() {
//   return String.fromCharCodes([0x1D, 0x56, 0x42, 0x00]);
// }

String _paperCutCommand({int feedLines = 4}) {
  final bytes = <int>[];
  bytes.addAll([0x1B, 0x64, feedLines]);
  bytes.addAll([0x1D, 0x56, 0x00]);
  return String.fromCharCodes(bytes);
}
String _formatSummary(String label, String value, int width, {bool bold = false}) {
  final labelText = label.padRight(width - value.length - 1);
  return '$labelText $value';

}
