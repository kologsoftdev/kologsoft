
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/StockProvider.dart';

class StockTransferUploadPage extends StatefulWidget {
  const StockTransferUploadPage({super.key});

  @override
  State<StockTransferUploadPage> createState() => _StockTransferUploadPageState();
}

/// One row read straight out of the CSV / Excel file.
class _RawSaleRow {
  final Map<String, String> cells;
  _RawSaleRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// A group of rows sharing the same transactionRef -> becomes ONE sales doc.
class _SaleGroup {
  final String receipt;
  final List<_RawSaleRow> rows;
  _SaleGroup(this.receipt, this.rows);

  _RawSaleRow get first => rows.first;
}

/// Result of matching a row's `mode` text against an item's `modes` map.
class _ModePricing {
  final double modeQty;
  final double unitPrice;
  final String resolvedMode;
  const _ModePricing({
    required this.modeQty,
    required this.unitPrice,
    required this.resolvedMode,
  });
}

class _StockTransferUploadPageState extends State<StockTransferUploadPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;


  static const List<String> requiredHeaders = [
    'tid',
    'transMode',
    'pieces',
  ];


  // All columns we understand (used for header normalization / preview)
  static const List<String> knownHeaders = [
    'tid',
    'customerName',
    'transMode',
    'payments',
    'date',
    'branchId',
    'item',
    'barcode',
    'itemid',
    'quantity',
    'price',
    'mode',
    'modeqty',
    'pcategory',
    'producttype',
    'cp',
    'itemDiscount',
    'boxpiece',
    'pricemode',
    // SQL schema friendly names

    'sid',
    'selling_price',
    'cost_price',
    'total',
    'total_selling_price',
    'vat',
    'discount',
    'time',
    'staff',
    'transtype',
    'tname',
    'transmode',
    'payaccount',
    'product_category',
    'year',
    'month',
    'week',
    'day',
    'branchname',
    'revenue_type',
    'product_type',
    'modes',
    'pieces',
    'waybill',
    'invoiceno',
    'supplybranch',
    'stocktype',
    'companyid',
  ];
  // ---- File limits (same policy as ItemUploadPage) -----------------------
  static const int _maxFileSizeMB = 3000;
  static const int _maxRows = 3000;
  static const int _maxFieldLength = 600;

  static const List<int> _xlsxMagic = [0x50, 0x4B, 0x03, 0x04];
  static const List<int> _xlsMagic = [0xD0, 0xCF, 0x11, 0xE0];

  List<String> headers = [];
  List<_RawSaleRow> previewRows = [];
  List<_SaleGroup> groups = [];
  List<String> groupStatus = []; // 'pending' | 'processing' | 'success' | 'error: ...'

  // Branch the upload is going to. Defaults to the staff's own branch the
  // first time the dropdown is built, but the user can change it.
  String? selectedBranchId;

  bool loading = false;
  bool validating = false;
  int currentIndex = 0;
  String fileInfo = '';

  // ---------------------------------------------------------------------
  // FILE VALIDATION (mirrors ItemUploadPage._validateFile)
  // ---------------------------------------------------------------------
  String? _validateFile(String filename, Uint8List bytes) {
    final sizeMB = bytes.lengthInBytes / (1024 * 1024);
    if (sizeMB > _maxFileSizeMB) {
      return 'File exceeds ${_maxFileSizeMB}MB limit.';
    }

    final ext = filename.split('.').last.toLowerCase();
    if (!['csv', 'xlsx', 'xls'].contains(ext)) {
      return 'Unsupported file type: .$ext';
    }

    if (ext == 'xlsx') {
      if (bytes.length < 4 || !_matchesMagic(bytes, _xlsxMagic)) {
        return 'File "$filename" is not a valid Excel (.xlsx) file.';
      }
    } else if (ext == 'xls') {
      if (bytes.length < 4 || !_matchesMagic(bytes, _xlsMagic)) {
        return 'File "$filename" is not a valid Excel (.xls) file.';
      }
    } else if (ext == 'csv') {
      if (bytes.length >= 4) {
        final looksLikeBinary = _matchesMagic(bytes, [0x4D, 0x5A]) ||
            _matchesMagic(bytes, [0x7F, 0x45, 0x4C, 0x46]) ||
            _matchesMagic(bytes, _xlsxMagic) ||
            _matchesMagic(bytes, _xlsMagic);
        if (looksLikeBinary) {
          return 'File "$filename" does not appear to be a valid CSV.';
        }
        try {
          utf8.decode(bytes);
        } catch (_) {
          return 'File "$filename" contains invalid text encoding (not UTF-8).';
        }
      }
    }
    return null;
  }

  bool _matchesMagic(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (int i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  String _sanitizeCell(String value) {
    var v = value.trim();
    const dangerous = ['=', '+', '-', '@', '\t', '\r', '\n'];
    if (v.isNotEmpty && dangerous.contains(v[0])) {
      v = "'$v";
    }
    if (v.length > _maxFieldLength) {
      v = v.substring(0, _maxFieldLength);
    }
    return v;
  }

  // ---------------------------------------------------------------------
  // PICK + PARSE FILE
  // ---------------------------------------------------------------------
  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null) return;

    final file = result.files.first;

    final validationError = _validateFile(file.name, file.bytes!);
    if (validationError != null) {
      _snack(validationError, Colors.red);
      return;
    }

    final ext = file.name.split('.').last.toLowerCase();

    List<String> tempHeaders = [];
    List<Map<String, String>> tempRows = [];

    try {
      if (ext == 'csv') {
        final csv = utf8.decode(file.bytes!);
        final lines = const LineSplitter().convert(csv);
        if (lines.isEmpty) throw 'CSV file is empty';

        tempHeaders =
            lines.first.split(',').map((h) => _sanitizeCell(h)).toList();

        for (int i = 1; i < lines.length; i++) {
          if (lines[i].trim().isEmpty) continue;
          if (tempRows.length >= _maxRows) {
            _snack(
              'File exceeds $_maxRows row limit. Only the first $_maxRows rows were loaded.',
              Colors.orange,
            );
            break;
          }
          final cols = lines[i].split(',');
          final rowMap = <String, String>{};
          for (int j = 0; j < tempHeaders.length; j++) {
            rowMap[tempHeaders[j]] =
                _sanitizeCell(j < cols.length ? cols[j] : '');
          }
          tempRows.add(rowMap);
        }
      } else {
        final excelFile = excel_lib.Excel.decodeBytes(file.bytes!);
        if (excelFile.tables.isEmpty) throw 'Excel file has no sheets';
        final sheet = excelFile.tables.values.first;
        if (sheet.maxRows < 2) throw 'Excel file has no data rows';

        tempHeaders = sheet.rows.first
            .map((cell) => _sanitizeCell(cell?.value?.toString() ?? ''))
            .where((h) => h.isNotEmpty)
            .toList();

        for (int r = 1; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          if (row.every(
                  (cell) => (cell?.value?.toString().trim() ?? '').isEmpty)) {
            continue;
          }
          if (tempRows.length >= _maxRows) {
            _snack(
              'File exceeds $_maxRows row limit. Only the first $_maxRows rows were loaded.',
              Colors.orange,
            );
            break;
          }
          final rowMap = <String, String>{};
          for (int c = 0; c < tempHeaders.length; c++) {
            final cell = c < row.length ? row[c] : null;
            rowMap[tempHeaders[c]] =
                _sanitizeCell(cell?.value?.toString() ?? '');
          }
          tempRows.add(rowMap);
        }
      }

      // normalize header casing so lookups are case-insensitive
      String normalize(String want) => tempHeaders.firstWhere(
            (h) => h.toLowerCase() == want.toLowerCase(),
        orElse: () => want,
      );

      final missing = requiredHeaders
          .where((h) => !tempHeaders.any(
            (th) => th.toLowerCase() == h.toLowerCase(),
      ))
          .toList();

      if (missing.isNotEmpty) {
        _snack('Missing required columns: ${missing.join(', ')}', Colors.red);
        return;
      }

      if (tempRows.isEmpty) throw 'No data rows found.';

      // Re-key every row using the canonical header names in knownHeaders
      final rawRows = tempRows.map((r) {
        final normalized = <String, String>{};
        for (final key in knownHeaders) {
          final actualKey = normalize(key);
          normalized[key] = r[actualKey] ?? '';
        }
        return _RawSaleRow(normalized);
      }).toList();

      // group by transactionRef
      final Map<String, List<_RawSaleRow>> grouped = {};
      for (final row in rawRows) {
        final receipt = row.get('tid');
        if (receipt.isEmpty) continue;
        grouped.putIfAbsent(receipt, () => []).add(row);
      }

      final builtGroups =
      grouped.entries.map((e) => _SaleGroup(e.key, e.value)).toList();

      if (mounted) {
        setState(() {
          headers = tempHeaders;
          previewRows = rawRows;
          groups = builtGroups;
          groupStatus = List.filled(groups.length, 'pending', growable: true);
          fileInfo =
          '${file.name} • ${previewRows.length} rows • ${groups.length} transactions';
        });
      }
    } catch (e) {
      _snack('Import failed: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ---------------------------------------------------------------------
  // HELPERS: date parts, payments parsing, item lookup
  // ---------------------------------------------------------------------
  Map<String, String> _dateParts(String dateymd) {
    DateTime dt;
    try {
      if (dateymd.isEmpty) {
        dt = DateTime.now();
      } else if (dateymd.contains('/')) {
        final parts = dateymd.split('/');
        if (parts.length != 3) throw 'bad date';
        dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } else {
        dt = DateTime.parse(dateymd); // still accepts yyyy-MM-dd if someone uses that
      }
    } catch (_) {
      dt = DateTime.now();
    }
    final day = DateFormat('EEEE').format(dt);
    final year = dt.year.toString();
    final month = '${dt.year}.${dt.month}';
    final weekNumber = ((dt.difference(DateTime(dt.year, 1, 1)).inDays) / 7).floor() + 1;
    final week = '${dt.year}.$weekNumber';
    final ymd = DateFormat('yyyy-MM-dd').format(dt);
    return {'dateymd': ymd, 'day': day, 'year': year, 'month': month, 'week': week};
  }

  String _makeItemId(String companyId, String itemName) {
    final s = itemName.trim().toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), '_');
    return '${companyId.toLowerCase()}_$s';
  }
  /// Parses the `payments` column:
  ///   method:amount:accountName:accountNumber:reference|method2:amount2...
  List<Map<String, dynamic>> _parsePayments(
      String raw, {
        required double fallbackTotal,
        required String transMode,
      }) {
    if (transMode.toLowerCase().trim() == 'credit') {
      // Credit sales carry no payments at creation time.
      return [];
    }

    if (raw.trim().isEmpty) {
      // Default: single cash payment for the whole total.
      return [
        {
          'amount': fallbackTotal,
          'accountName': 'cash',
          'accountNumber': 'cash',
          'status': true,
          'reference': 'cash',
          'method': 'cash',
        }
      ];
    }

    final entries = raw.split('|');
    final payments = <Map<String, dynamic>>[];

    for (final entry in entries) {
      if (entry.trim().isEmpty) continue;
      final parts = entry.split(':');
      final method =  'cash';
      final amount =
      parts.length > 1 ? (double.tryParse(parts[1].trim()) ?? 0) : 0.0;
      final accountName =
      parts.length > 2 ? parts[2].trim() : (method == 'cash' ? 'cash' : method);
      final accountNumber = parts.length > 3 ? parts[3].trim() : method;
      final reference = parts.length > 4 ? parts[4].trim() : method;

      payments.add({
        'amount': amount,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'status': true,
        'reference': reference,
        'method': method,
      });
    }

    if (payments.isEmpty) {
      payments.add({
        'amount': fallbackTotal,
        'accountName': 'cash',
        'accountNumber': 'cash',
        'status': true,
        'reference': 'cash',
        'method': 'cash',
      });
    }
    return payments;
  }

  /// don't repeat lookups between validation and upload.
  final Map<String, Map<String, dynamic>?> _itemLookupCache = {};

  Future<Map<String, dynamic>?> _lookupItem(String companyId, String barcode, String itemName, String itemid,) async {
    final normalizedBarcode = barcode.trim().toLowerCase();
    final trimmedName = itemName.trim();
    final normalizedName = trimmedName.toLowerCase();
    if (normalizedBarcode.isEmpty && normalizedName.isEmpty) return null;

    final cacheKey = itemid.isNotEmpty ? itemid : '$companyId::$normalizedBarcode::$normalizedName';
    if (_itemLookupCache.containsKey(cacheKey)) {
      return _itemLookupCache[cacheKey];
    }

    try {
      if (itemid.isNotEmpty) {
        final snap = await db.collection('itemsreg').doc(itemid).get();
        if (snap.exists) {
          final data = snap.data();
          if (data != null && (data['companyid'] ?? '').toString() == companyId) {
            _itemLookupCache[cacheKey] = data;
            return data;
          }
        }
      }

      if (trimmedName.isNotEmpty) {
        final nameSnap = await db
            .collection('itemsreg')
            .where('companyid', isEqualTo: companyId)
            .where('name', isEqualTo: trimmedName)
            .limit(1)
            .get();

        if (nameSnap.docs.isNotEmpty) {
          final data = nameSnap.docs.first.data();
          if ((data['companyid'] ?? '').toString() == companyId) {
            _itemLookupCache[cacheKey] = data;
            return data;
          }
        }
      }

      if (normalizedBarcode.isNotEmpty) {
        final barcodeSnap = await db
            .collection('itemsreg')
            .where('companyid', isEqualTo: companyId)
            .where('barcode', isEqualTo: normalizedBarcode)
            .limit(1)
            .get();

        if (barcodeSnap.docs.isNotEmpty) {
          final data = barcodeSnap.docs.first.data();
          if ((data['companyid'] ?? '').toString() == companyId) {
            _itemLookupCache[cacheKey] = data;
            return data;
          }
        }
      }

      _itemLookupCache[cacheKey] = null;
      return null;
    } catch (e) {
      debugPrint(
        'Item lookup failed for "$itemName :$itemid": $e',
      );
      _itemLookupCache[cacheKey] = null;
      return null;
    }
  }


  String sanitize(String input) {
    return input.trim().toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }
  /// against an itemsreg document's `modes` map and resolving a unit price.
  final _emptyModePricing = _ModePricing(modeQty: 1, unitPrice: 0, resolvedMode: 'Single');


  _ModePricing _resolveModePricing({
    required Map<String, dynamic> item,
    required String modeText,
    required String pricemode,
  }) {
    final modes = item['modes'];
    final wantedRaw = modeText.trim().isEmpty ? 'single' : modeText.trim().toLowerCase();

    if (modes is! Map || modes.isEmpty) {
      return _ModePricing(modeQty: 1, unitPrice: 0, resolvedMode: modeText.isEmpty ? 'Single' : modeText);
    }

    Map<String, dynamic>? match;
    String resolvedKey = wantedRaw;

    if (modes[wantedRaw] is Map) {
      match = Map<String, dynamic>.from(modes[wantedRaw] as Map);
      resolvedKey = wantedRaw;
    } else {
      for (final entry in modes.entries) {
        final data = entry.value;
        if (data is! Map) continue;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final id = (data['id'] ?? entry.key).toString().toLowerCase();
        if (id == wantedRaw ||
            name == wantedRaw ||
            name.contains(wantedRaw) ||
            (wantedRaw.isNotEmpty && wantedRaw.contains(id))) {
          match = Map<String, dynamic>.from(data);
          resolvedKey = entry.key.toString();
          break;
        }
      }
    }

    if (match == null) {
      return _ModePricing(modeQty: 1, unitPrice: 0, resolvedMode: modeText.isEmpty ? 'Single' : modeText);
    }

    final qty = double.tryParse(match['qty']?.toString() ?? '1') ?? 1;
    final bool wholesale = pricemode.toLowerCase().trim() == 'wholesale';

    double price = double.tryParse((wholesale ? match['wp'] : match['rp'])?.toString() ?? '') ?? 0;
    if (price <= 0) {
      price = double.tryParse(match['sp']?.toString() ?? '') ?? 0;
    }
    if (price <= 0) {
      price = double.tryParse((wholesale ? match['rp'] : match['wp'])?.toString() ?? '') ?? 0;
    }
    if (price <= 0) {
      price = double.tryParse(match['cp']?.toString() ?? '') ?? 0;
    }

    final resolvedName = (match['name'] ?? resolvedKey).toString();
    return _ModePricing(
      modeQty: qty <= 0 ? 1 : qty,
      unitPrice: price,
      resolvedMode: resolvedName,
    );
  }

  String? _validatePaymentsColumn(String raw) {
    if (raw.trim().isEmpty) return null;
    final problems = <String>[];
    for (final entry in raw.split('|')) {
      if (entry.trim().isEmpty) continue;
      final parts = entry.split(':');
      //final method = parts.isNotEmpty ? parts[0].trim().toLowerCase() : '';
      final method = 'transfer';

    }
    return problems.isEmpty ? null : problems.join('; ');
  }
  /// Looks up an existing customer by phone (`contact`) within the current
  /// Cached per phone number.
  final Map<String, Map<String, dynamic>?> _customerLookupCache = {};

  Future<Map<String, dynamic>?> _lookupCustomerByPhone(
      String companyId,
      String phone,
      ) async {
    if (phone.isEmpty) return null;
    final cacheKey = '$companyId::$phone';
    if (_customerLookupCache.containsKey(cacheKey)) {
      return _customerLookupCache[cacheKey];
    }
    try {
      final snap = await db
          .collection('customers')
          .where('companyid', isEqualTo: companyId)
          .where('contact', isEqualTo: phone)
          .limit(1)
          .get();
      final data = snap.docs.isNotEmpty ? snap.docs.first.data() : null;
      _customerLookupCache[cacheKey] = data;
      return data;
    } catch (_) {
      _customerLookupCache[cacheKey] = null;
      return null;
    }
  }

  /// Resolves a branch id (row override, else the selected/default branch)
  /// against `datafeed.branches`. Throws a readable String on failure.
  dynamic _resolveBranch(Datafeed datafeed, String branchIdRaw, String defaultBranchId) {
    return datafeed.branches.firstWhere(
          (b) => b.id == branchIdRaw,
      orElse: () => datafeed.branches.firstWhere(
            (b) => b.id == defaultBranchId,
        orElse: () => throw 'Branch "$branchIdRaw" not found',
      ),
    );
  }


  Future<Map<int, String>> _validateAllGroups({required Datafeed datafeed, required String companyId, required String defaultBranchId,
  }) async {
    final errors = <int, String>{};

    // 'itemid|branchId' -> total pieces requested across the whole file
    final Map<String, double> neededPieces = {};
    final Map<String, Map<String, dynamic>> resolvedItems = {};
    final Map<String, String> branchLabelByKey = {};
    final Map<String, String> supplyBranchIdByKey = {};

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      final first = group.first;

      // A single receipt can't be part cash, part credit.
      final transModes = group.rows
          .map((r) => r.get('mode', 'single',).toLowerCase().trim())
          .toSet();

      final transMode = transModes.first;
      if (transMode.isEmpty) {
        errors[g] =
        'transfer Mode must be "single","carton" or "box", (got "${first.get('transMode')}")';
        continue;
      }

      final bool isSuperAdmin =
          datafeed.accesslevel.toLowerCase() == 'superadmin';
      final branchIdRaw = isSuperAdmin
          ? first.get('branchId', defaultBranchId)
          : defaultBranchId;
      String resolvedBranchId;
      String resolvedBranchLabel;
      try {
        final branch = _resolveBranch(datafeed, branchIdRaw, defaultBranchId);
        resolvedBranchId = branch.id.isNotEmpty ? branch.id : defaultBranchId;
        resolvedBranchLabel =
        branch.branchname.isNotEmpty ? branch.branchname : resolvedBranchId;
      } catch (e) {
        errors[g] = e.toString();
        continue;
      }

      final rowErrors = <String>[];

      for (int i = 0; i < group.rows.length; i++) {
        final row = group.rows[i];
        final itemName = row.get('item');
        final barcode = row.get('barcode');
        final quantity = double.tryParse(row.get('quantity')) ?? 0;
        final pieces = double.tryParse(row.get('pieces')) ?? 0;
        final supplybranch = row.get('supplybranch');
        final supplybranchid = '${companyId.trim().toLowerCase()}${supplybranch.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
        final recievebranch = row.get('branchname') ;
        final recievebranchid = '${companyId.trim().toLowerCase()}${recievebranch.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
        final itemid='${sanitize(companyId)}_${sanitize(itemName)}';

        if (itemName.isEmpty && barcode.isEmpty) {
          rowErrors.add('Row ${i + 1}: needs an item name or a barcode');
          continue;
        }
        if (quantity <= 0) {
          rowErrors.add('Row ${i + 1} ("${itemName.isEmpty ? barcode : itemName}"): invalid quantity');
          continue;
        }

        Map<String, dynamic>? looked = await _lookupItem(companyId, barcode, itemName,itemid);
        if (looked == null) {
          // If the import row provides pricing info we can proceed and create
          // the item later during upload. Require at least a price or cost.
          final priceText = row.get('price');
          final cpText = row.get('cost_price', row.get('cp', ''));
          if (priceText.isEmpty && cpText.isEmpty) {
            rowErrors.add(
                'Row ${i + 1}: item "${itemName.isEmpty ? barcode : itemName}" not found in inventory and no price/cost provided to create it');
            continue;
          }

          // Create an in-memory placeholder item so downstream logic can
          // validate quantities and pricing without hitting the DB yet.
          looked = {
            'id': itemid,
            'name': itemName,
            'barcode': barcode,
            'companyid': companyId,
            'cp': cpText.isEmpty ? 0 : double.tryParse(cpText) ?? 0,
            'modes': {},
          };
        }

        final pricemode = row.get('pricemode', 'retail');
        final modePricing = _resolveModePricing(
          item: looked,
          modeText: row.get('mode', 'Single'),
          pricemode: pricemode,
        );
        final priceOverrideText = row.get('cost_price');
        final unitPrice = priceOverrideText.isNotEmpty
            ? (double.tryParse(priceOverrideText) ?? 0)
            : modePricing.unitPrice;

        if (priceOverrideText.isNotEmpty && double.tryParse(priceOverrideText) == null) {
          rowErrors.add('Row ${i + 1} ("$itemName"): "price" column has an invalid number');
          continue;
        }
        if (unitPrice <= 0) {
          rowErrors.add(
              'Row ${i + 1} ("$itemName"): could not resolve a price for mode "${row.get('mode', 'Single')}" — add a "price" column value to override');
          continue;
        }


        final key = '$itemid|$supplybranchid';
        final totalPieces = pieces;

        //neededPieces[key] = (neededPieces[key] ?? 0) + totalPieces;
        resolvedItems[key] = looked;
        branchLabelByKey[key] = supplybranch;

        supplyBranchIdByKey[key] = supplybranchid;
        print(
          'ROW ${i + 1}: '
              'item=${looked['id']} '
              'supplyBranch=$supplybranch '
              'supplyBranchId=$supplybranchid '
              'receiveBranch=$recievebranch '
              'receiveBranchId=$recievebranchid '
              'pieces=$pieces',
        );
      }

      if (rowErrors.isNotEmpty) {
        errors[g] = errors.containsKey(g) ? '${errors[g]}; ${rowErrors.join('; ')}' : rowErrors.join('; ');
      }
    }

    // Stock check across the whole batch: an item sold in several
    // transactions in this file must have enough combined stock.
    final provider = Provider.of<Datafeed>(context, listen: false);

    final stockErrors = <String>[];
    for (final entry in neededPieces.entries) {
      final looked = resolvedItems[entry.key];
      if (looked == null) continue;

      // ============================================================
      // GET OVERALL ITEM BALANCE
      // ============================================================
      final supplyBranchId = supplyBranchIdByKey[entry.key] ?? '';

      final supplyBranchName = branchLabelByKey[entry.key] ?? supplyBranchId;
      final double available = (await provider.fetchItemCurrentBalance(itemId: looked['id'],selectedBranch:supplyBranchId ,)).toDouble();
      print('Available stock for item ${looked['id']} in $supplyBranchName => $available');

    }

    if (stockErrors.isNotEmpty) {
      final summary =
          'Insufficient supply branch stock — '
          '${stockErrors.join('; ')}';

      for (int g = 0; g < groups.length; g++) {
        errors[g] = errors.containsKey(g)
            ? '${errors[g]}; $summary'
            : summary;
      }
    }

    return errors;
  }
  // ---------------------------------------------------------------------
  // UPLOAD
  // ---------------------------------------------------------------------

  Future<void> upload() async {
    if (groups.isEmpty) {
      _snack('No transactions to upload', Colors.orange);
      return;
    }

    final datafeed = context.read<Datafeed>();
    await datafeed.getdata();

    final companyId = datafeed.companyid;
    final companyName = datafeed.company;
    final staffPosition = datafeed.staffPosition;
    final staffName = datafeed.staff;
    final staffEmail = datafeed.staffemail;

    if (companyId.isEmpty) {
      _snack('No company context found. Please log in again.', Colors.red);
      return;
    }

    final defaultBranchId = selectedBranchId ?? datafeed.branchid;

    if (defaultBranchId.isEmpty) {
      _snack('Please select a branch before uploading.', Colors.red);
      return;
    }

    setState(() {
      loading = true;
      validating = true;
      currentIndex = 0;
      groupStatus = List.filled(
        groups.length,
        'pending',
        growable: true,
      );
    });

    final validationErrors = await _validateAllGroups(
      datafeed: datafeed,
      companyId: companyId,
      defaultBranchId: defaultBranchId,
    );

    if (!mounted) return;

    if (validationErrors.isNotEmpty) {
      setState(() {
        for (final entry in validationErrors.entries) {
          groupStatus[entry.key] = 'error: ${entry.value}';
        }

        validating = false;
        loading = false;
      });

      _snack(
        'Validation failed for ${validationErrors.length} '
            'of ${groups.length} transaction(s). Nothing was uploaded.',
        Colors.red,
      );

      _showErrorsDialog();
      return;
    }

    setState(() => validating = false);

    final provider = Provider.of<Datafeed>(
      context,
      listen: false,
    );

    for (int g = 0; g < groups.length; g++) {
      if (!mounted) break;

      setState(() {
        currentIndex = g;
        groupStatus[g] = 'processing';
      });

      final group = groups[g];

      try {
        // ============================================================
        // STEP 1
        // Aggregate duplicate Excel items
        // ============================================================

        final Map<String, Map<String, dynamic>> aggregatedIncoming = {};

        for (final row in group.rows) {
          final itemNameRaw = row.get('item').trim();
          final barcode = row.get('barcode').trim();
          final pieces = double.tryParse(row.get('pieces', '0')) ?? 0;
          final quantity = double.tryParse(row.get('quantity', '0')) ?? 0;
          final costPrice = double.tryParse(row.get('cost_price',row.get('cp', '0'), ),) ?? 0;
          if (itemNameRaw.isEmpty && barcode.isEmpty) {
            throw 'Item name or barcode is required.';
          }

          if (pieces <= 0) {
            throw 'Invalid pieces for '
                '"${itemNameRaw.isEmpty ? barcode : itemNameRaw}".';
          }

          if (costPrice < 0) {
            throw 'Invalid cost price for '
                '"${itemNameRaw.isEmpty ? barcode : itemNameRaw}".';
          }

          final itemid = '${sanitize(companyId)}_${sanitize(itemNameRaw)}';

          final rowStockValue = costPrice * pieces;

          final existing = aggregatedIncoming[itemid];

          if (existing == null) {
            aggregatedIncoming[itemid] = {
              'itemid': itemid,
              'item': itemNameRaw,
              'barcode': barcode,
              'pieces': pieces,
              'quantity': quantity,
              'value': rowStockValue,
              'costPrice': costPrice,
            };
          } else {
            existing['pieces'] = (existing['pieces'] ?? 0) + pieces;
            existing['value'] = (existing['value'] ?? 0) + rowStockValue;
          }
        }

        // ============================================================
        // STEP 2
        // Resolve items and calculate weighted average CP
        // ============================================================

        final Map<String, Map<String, dynamic>> resolvedItems = {};

        final Map<String, Map<String, dynamic>> newItems = {};

        for (final entry in aggregatedIncoming.entries) {
          final fallbackItemId = entry.key;
          final incoming = entry.value;

          final double newStockPieces = (incoming['pieces'] ?? 0).toDouble();

          final double newStockValue = (incoming['value'] ?? 0).toDouble();

          if (newStockPieces <= 0) {
            throw 'Invalid total pieces for '
                '"${incoming['item']}".';
          }

          Map<String, dynamic>? looked = await _lookupItem(
            companyId,
            incoming['barcode'] ?? '',
            incoming['item'] ?? '',
            fallbackItemId,
          );

          final String actualItemId = (looked != null
              ? (looked['id'] ?? looked['itemid'] ?? fallbackItemId).toString()
              : fallbackItemId)
              .trim();

          double averageCp;
          double oldCp = 0;
          double oldPieces = 0;
          double oldStockValue = 0;

          if (looked == null) {

            averageCp = newStockValue / newStockPieces;

            final itemDoc = <String, dynamic>{
              'id': actualItemId,
              'itemid': actualItemId,
              'name': incoming['item'],
              'barcode': incoming['barcode'] ?? '',
              'company': companyName,
              'companyid': companyId,
              'cp': averageCp,
              'originalcp': averageCp,
              'stock_value': double.parse(newStockValue.toStringAsFixed(2)),
              'stockin_pieces': newStockPieces.toInt(),
              'currentbalance': newStockPieces,
              'createdat': Timestamp.now(),
              'isActive': true,
              'modemore':true,
              'modes': {
                'single': {
                  'id': 'single',
                  'name': 'Single',
                  'qty': 1,
                  'cp': averageCp,
                  'sp': averageCp,
                  'rp': averageCp,
                  'wp': averageCp,
                }
              },
            };

            newItems[actualItemId] = itemDoc;
            looked = Map<String, dynamic>.from(itemDoc);
          } else {

            oldPieces = (await provider.fetchItemCurrentBalance(
              itemId: actualItemId,
            ) ?? 0).toDouble();

            oldCp = double.tryParse(looked['cp']?.toString() ?? '0') ?? 0;
            oldStockValue = oldCp * oldPieces;

            final totalPieces = oldPieces + newStockPieces;
            final totalStockValue = oldStockValue + newStockValue;

            averageCp = totalPieces > 0 ? totalStockValue / totalPieces : oldCp;

            looked['cp'] = averageCp;
            looked['itemid'] = actualItemId;
            looked['id'] = actualItemId;
          }

          resolvedItems[actualItemId] = {
            'itemid': actualItemId,
            'item': incoming['item'] ?? '',
            'barcode': incoming['barcode'] ?? '',
            'pieces': newStockPieces,
            'total': double.parse(newStockValue.toStringAsFixed(2)),
            'cp': averageCp,
            'originalcp': looked == null ? averageCp : oldCp,
            'producttype': looked['producttype'] ?? 'product',
            'pcategory': looked['pcategory'] ?? '',
            'branchid': defaultBranchId,
            'branchname': datafeed.branch,
            'stockin_pieces': newStockPieces,
            'stock_value': double.parse(newStockValue.toStringAsFixed(2)),
          };
        }

        // ============================================================
        // STEP 3: Build stock_transactions items map
        // ============================================================

        final List<Map<String, dynamic>> transactionItems = [];
        double calculatedGross = 0.0;


        for (final entry in aggregatedIncoming.entries) {
          final itemid = entry.key;
          final incoming = entry.value;

          final looked = resolvedItems[itemid];

          if (looked == null) {
            throw 'Unable to resolve item "$itemid".';
          }

          final double pieces = (incoming['pieces'] ?? 0).toDouble();

          final double aggregatedValue = (incoming['value'] ?? 0).toDouble();
          final double aggregatedqty = (incoming['quantity'] ?? 0).toDouble();

          final double averageCp = double.tryParse(looked['cp']?.toString() ?? '0',) ?? 0;

          final String itemName = (incoming['item'] ?? looked['name'] ?? '').toString();

          final String barcode = (incoming['barcode'] ?? looked['barcode'] ?? '').toString();

          // Find the first row belonging to this item.

          final matchingRows = group.rows.where((row) {
            final rowItem =
            row.get('item').trim();

            final rowItemId = '${sanitize(companyId)}_${sanitize(rowItem)}';

            return rowItemId == itemid;
          }).toList();

          if (matchingRows.isEmpty) {
            throw 'Could not find source row for item "$itemName".';
          }

          final firstItemRow = matchingRows.first;

          final String mode =
          firstItemRow.get('mode', 'Single');

          final String modeQty =
          firstItemRow.get('modeqty', '1');

          final String boxPieces =
          firstItemRow.get(
            'boxpiece',
            modeQty,
          );

          final double discount = double.tryParse(firstItemRow.get('itemDiscount', '0',),) ??0;
          final double grossTotal = aggregatedValue;


          transactionItems.add({
            'itemid': itemid,
            'item': itemName,
            'barcode': barcode,
            'pieces': pieces,
            'quantity': aggregatedqty,
            'price': looked['originalcp'] ?? averageCp,
            'total': double.parse(grossTotal.toStringAsFixed(2),),
            'transfermode': mode,
            'modeqty': modeQty,
            'boxpiece': boxPieces,
            'receivedpieces': 0,
            'receivedquantity': 0,
            'syncstatus': false,
          });

          calculatedGross += grossTotal;

        }

        // STEP 3B
        // Build stock transaction document
        // ============================================================

        final first = group.first;

        final transMode = group.rows.map((row) => row.get('transMode', 'opening balance').toLowerCase().trim()).toSet().firstWhere((value) => value.isNotEmpty, orElse: () => 'opening balance');
        final branchId = defaultBranchId;
        final branchName = datafeed.branch.isNotEmpty ? datafeed.branch : defaultBranchId;
        final branchType = datafeed.branchtype.isNotEmpty ? datafeed.branchtype : 'Warehouse';
        final now = Timestamp.now();
        final dateParts = _dateParts(first.get('date', DateFormat('yyyy-MM-dd').format(DateTime.now())));
        final invoice = first.get('invoice', first.get('invoiceno', group.receipt));
        final rawDate = first.get('date',DateFormat('yyyy-MM-dd').format(DateTime.now()));
        String invoicedate;
        if (rawDate is DateTime) {
          invoicedate = DateFormat('yyyy-MM-dd').format(rawDate as DateTime);
        } else {
          invoicedate = rawDate.toString().substring(0, 10);
        }
        final supplybranch = first.get('supplybranch');
        final supplybranchid = '${companyId.trim().toLowerCase()}${supplybranch.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
        final recievebranch = first.get('branchname') ;
        final recievebranchid = '${companyId.trim().toLowerCase()}${recievebranch.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
        final docId = '${companyId.trim().toLowerCase()}${DateTime.now().millisecondsSinceEpoch}${staffPosition}_${group.receipt}';
        final staff = first.get('staff',staffName);
        final grandTotal = calculatedGross;
        final timestamp = now.millisecondsSinceEpoch;
        final String dateString = invoicedate;
        final parts = dateString.split('-');

        final totimestamp = Timestamp.fromDate(
          DateTime.utc(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          ),
        );
        final saleDoc = <String, dynamic>{

          'docid': docId,
          'companyid': companyId,
          'company': companyName,
          'staffbranch': branchName,
          'staffbranchid': branchId,
          'recievebranchid': recievebranchid,
          'recievebranchname': recievebranch,
          'supplywarehouseid': supplybranchid,
          'supplywarehousename': supplybranch,
          'createdat': now,
          'createdby': staff,
          'uploadedby': staffName,
          'staffemail': staffEmail,
          'date': invoicedate,
          'day': dateParts['day'],
          'month': dateParts['month'],
          'week': dateParts['week'],
          'year': dateParts['year'],
          'transferdate': totimestamp,
          'transferid': invoice,
          'transactionid': docId,
          'itemCount': transactionItems.length,
          'gross': grandTotal,
          'items': transactionItems,
          'timestamp': timestamp,
          'syncstatus': false,
        };


        final List<WriteBatch> batches = [];

        WriteBatch currentBatch = db.batch();

        int opCount = 0;

        void addOperation() {
          opCount++;

          if (opCount >= 490) {
            batches.add(currentBatch);

            currentBatch = db.batch();

            opCount = 0;
          }
        }

        // Add newly created items to itemsreg

        for (final entry in newItems.entries) {
          final String itemid = entry.key;

          final Map<String, dynamic> itemDoc =
              entry.value;

          currentBatch.set(
            db.collection('itemsreg').doc(itemid),
            itemDoc,
          );

          addOperation();
        }

        // Update existing items

        // for (final entry in resolvedItems.entries) {
        //   final String itemid = entry.key;
        //
        //   // New items were already written above.
        //   if (newItems.containsKey(itemid)) {
        //     continue;
        //   }
        //
        //   final docRef =
        //   db.collection('itemsreg').doc(itemid);
        //
        //   currentBatch.update(
        //     docRef,
        //     {
        //       'cp': double.parse((entry.value['cp'] ?? 0).toStringAsFixed(2),),
        //       'cpUpdatedAt':
        //       FieldValue.serverTimestamp(),
        //     },
        //   );
        //
        //   addOperation();
        // }

        // ============================================================
        // Add stock transaction
        // ============================================================

        final saleDocRef = db.collection('stock_transfer').doc(docId);

        currentBatch.set(
          saleDocRef,
          saleDoc,
        );

        addOperation();

        if (opCount > 0) {
          batches.add(currentBatch);
        }

        for (final batch in batches) {
          await batch.commit();
        }

        // ============================================================
        // SUCCESS
        // ============================================================

        groupStatus[g] = 'success';
      } catch (e, stackTrace) {
        debugPrint(
          'Upload error for group $g: $e',
        );

        debugPrint(
          stackTrace.toString(),
        );

        if (mounted) {
          setState(() {
            groupStatus[g] = 'error: $e';
            currentIndex = g + 1;
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        loading = false;
        validating = false;
      });
    }
  }
  int get successCount => groupStatus.where((s) => s == 'success').length;
  int get errorCount => groupStatus.where((s) => s.startsWith('error')).length;
  int get pendingCount => groupStatus.where((s) => s == 'pending').length;
  double get progress =>
      groups.isEmpty ? 0 : currentIndex / groups.length;

  void _showErrorsDialog() {
    final errors = <String>[];
    for (int i = 0; i < groupStatus.length; i++) {
      if (groupStatus[i].startsWith('error')) {
        errors.add(
            'Receipt  "${groups[i].receipt}": ${groupStatus[i].replaceFirst('error: ', '')}');
      }
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF182232),
        title: Text('Upload Errors (${errors.length})',
            style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Text(
              errors.isEmpty ? 'No errors.' : errors.join('\n\n'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchItems();
      context.read<Datafeed>().fetchBranches();
    });
  }

  void _showFormatHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF182232),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Stock Transfer Import Format',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'One row per item. Rows with the same "receipt" become one stock transaction. '
                      'Before anything uploads, every item must be matched in inventory '
                      '(by barcode or name), priced, and have enough stock at the selected '
                      'branch across the whole file — if any transaction fails, nothing is written.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              const Text('Required columns:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                requiredHeaders.join(', '),
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              const Text('Optional columns:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                knownHeaders
                    .where((h) => !requiredHeaders.contains(h))
                    .join(', '),
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              const Text('Item matching & pricing:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              const SizedBox(height: 6),
              const Text(
                  'Each row is matched to an inventory item by barcode first, then by exact '
                      '(case-insensitive) item name — give either one, or both. Unit price is '
                      'pulled from that item\'s mode pricing (Single/Carton/Quarter/Half…) based '
                      'on the "mode" column and "pricemode" (retail = rp, wholesale = wp), '
                      'falling back through sp/cp if a tier is blank. Add a "price" column value '
                      'on a row to override the resolved price instead.',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 12),
              const Text('branchId defaults to the branch selected above the file picker.',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 12),
              const Text(
                  'Cash: leave customerName/Phone blank for "cash customer", or give both to '
                      'auto-create/reuse a real customer. Credit: must match an EXISTING customer '
                      '(by customerId or customerPhone) — it is never auto-created.',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 12),
              const Text('Payments column format:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              const SizedBox(height: 6),
              const Text(
                'method:amount:accountName:accountNumber:reference\n'
                    'method is one of: cash, momo, card, bank_transfer, cheque.\n'
                    'Separate multiple payments with "|", e.g.\n'
                    'cash:50|momo:20:MTN:0244000000:TX123\n'
                    'bank_transfer:365:GCB:012345:REF001\n\n'
                    'If left blank on a cash sale, one cash payment for the full\n'
                    'total is created automatically. Credit sales ignore this\n'
                    'column (paymentStatus is set to "pending").',
                style: TextStyle(
                    color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final datafeed = context.watch<Datafeed>();

    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: const Text('Bulk Transfer Upload',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          if (!loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.lightBlue),
                onPressed: _showFormatHelp,
                tooltip: 'View format help',
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                try {
                  final provider= Provider.of<StockProvider>(context, listen: false);

                  provider.downloadstocktemplate(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to download file: $e')),
                  );
                }
              },
              tooltip: 'Download sample template',
            ),
          ),

        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBranchSelector(datafeed),
                  const SizedBox(height: 24),
                  _buildFilePickerSection(),
                  const SizedBox(height: 24),
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(
                              'Select a CSV or Excel fileto begin',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _buildFileInfoCard(),
                    const SizedBox(height: 24),
                    _buildStatusSummary(),
                    const SizedBox(height: 24),
                    _buildProgressSection(),
                    const SizedBox(height: 24),
                    _buildGroupsTable(isMobile),
                    const SizedBox(height: 24),
                    _buildActionButtons(isMobile),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchSelector(Datafeed datafeed) {
    final currentId = selectedBranchId ?? datafeed.branchid;
    final hasCurrent = datafeed.branches.any((b) => b.id == currentId);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF22304A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.store_outlined, color: Colors.lightBlue, size: 24),
              SizedBox(width: 12),
              Text('Upload To Branch',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 36),
            child: Text(
              'Used for any row that leaves branchId blank, and for checking stock before upload.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: hasCurrent ? currentId : null,
            dropdownColor: const Color(0xFF22304A),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF101624),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            hint: const Text('Select branch',
                style: TextStyle(color: Colors.white54)),
            items: datafeed.branches
                .map((b) => DropdownMenuItem<String>(
              value: b.id,
              child:
              Text(b.branchname.isNotEmpty ? b.branchname : b.id),
            ))
                .toList(),
            onChanged: loading
                ? null
                : (val) => setState(() => selectedBranchId = val),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF22304A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open,
                  color: groups.isNotEmpty ? Colors.green : Colors.lightBlue,
                  size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select File',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Supported formats: CSV, XLSX, XLS (Max ${_maxFileSizeMB}MB)',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: loading ? null : pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick File',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.teal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('File Details',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(fileInfo,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary() {
    return Row(
      children: [
        _buildStatusCard('Success', successCount,
            Colors.green.withOpacity(0.2), Colors.green),
        const SizedBox(width: 12),
        _buildStatusCard(
            'Errors', errorCount, Colors.red.withOpacity(0.2), Colors.red),
        const SizedBox(width: 12),
        _buildStatusCard('Pending', pendingCount,
            Colors.orange.withOpacity(0.2), Colors.orange),
      ],
    );
  }

  Widget _buildStatusCard(
      String label, int count, Color bgColor, Color accentColor) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(count.toString(),
                style: TextStyle(
                    color: accentColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final label = validating
        ? 'Validating items & stock…'
        : 'Transaction $currentIndex of ${groups.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(validating ? 'Validating' : 'Upload Progress',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            if (!validating)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.lightBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: validating
              ? const LinearProgressIndicator(
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          )
              : LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Colors.lightBlue),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildGroupsTable(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: DataTable(
              headingRowColor:
              WidgetStateColor.resolveWith((_) => const Color(0xFF22304A)),
              headingTextStyle: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
              columns: const [
                DataColumn(label: Text('Ref')),
                DataColumn(label: Text('Mode')),
                DataColumn(label: Text('Items')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Status')),
              ],
              rows: List.generate(groups.length, (i) {
                final group = groups[i];
                final status = groupStatus[i];
                final isError = status.startsWith('error');
                final isSuccess = status == 'success';

                return DataRow(
                  color: WidgetStateColor.resolveWith(
                        (_) => isError
                        ? Colors.red.withOpacity(0.12)
                        : isSuccess
                        ? Colors.green.withOpacity(0.06)
                        : Colors.white.withOpacity(0.02),
                  ),
                  cells: [
                    DataCell(Text(group.receipt,
                        style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    DataCell(Text(group.first.get('transMode', 'cash'),
                        style: const TextStyle(color: Colors.white54, fontSize: 12))),
                    DataCell(Text('${group.rows.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12))),
                    DataCell(Text(group.first.get('customerName', '-'),
                        style: const TextStyle(color: Colors.white54, fontSize: 12))),
                    DataCell(
                      Tooltip(
                        message: status,
                        child: isSuccess
                            ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 16)
                            : isError
                            ? const Icon(Icons.error, color: Colors.red, size: 16)
                            : status == 'processing'
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.lightBlue),
                          ),
                        )
                            : const Icon(Icons.schedule,
                            color: Colors.orange, size: 16),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        if (groups.isNotEmpty && !loading)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {
              setState(() {
                previewRows.clear();
                groups.clear();
                groupStatus.clear();
                headers.clear();
                fileInfo = '';
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
        if (errorCount > 0)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: _showErrorsDialog,
            icon: const Icon(Icons.error_outline),
            label: Text('View Errors ($errorCount)'),
          ),
        SizedBox(
          width: isMobile ? double.infinity : null,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: loading ? Colors.grey : Colors.lightBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24, vertical: 12),
            ),
            onPressed: (loading || groups.isEmpty) ? null : upload,
            icon: loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            )
                : const Icon(Icons.cloud_upload),
            label: Text(
              validating
                  ? 'Validating...'
                  : loading
                  ? 'Uploading...'
                  : 'Start Upload',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}