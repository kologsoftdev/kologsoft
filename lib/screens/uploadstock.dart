import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class StockUploadPage extends StatefulWidget {
  const StockUploadPage({super.key});

  @override
  State<StockUploadPage> createState() => _StockUploadPageState();
}

/// One row normalized from the stock API.
class _RawSaleRow {
  final Map<String, String> cells;

  _RawSaleRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// A group of rows sharing the same source transaction key.
class _SaleGroup {
  final String receipt;
  final List<_RawSaleRow> rows;

  _SaleGroup(this.receipt, this.rows);

  _RawSaleRow get first => rows.first;
}

class _StockUploadPageState extends State<StockUploadPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  static const String _stockApiUrl =
      'https://queenlatifahenterprise.com/pos/firebase/stock';

  static const String _stockCallbackApiUrl =
      'https://queenlatifahenterprise.com/pos/firebase/trans_callback';

  static const int _apiPageSize = 1000;

  /// Number of transaction groups uploaded concurrently.
  static const int _uploadConcurrency = 10;

  /// Number of groups validated concurrently.
  static const int _validationConcurrency = 20;



  static const Map<String, String> _paymentMethodAliases = {
    'banktransfer': 'bank_transfer',
    'bank transfer': 'bank_transfer',
    'bank-transfer': 'bank_transfer',
    'transfer': 'bank_transfer',
    'mobilemoney': 'momo',
    'mobile money': 'momo',
    'mobile_money': 'momo',
  };

  static String _normalizePaymentMethod(String raw) {
    final cleaned = raw.trim().toLowerCase();
    return _paymentMethodAliases[cleaned] ?? cleaned;
  }

  List<_SaleGroup> groups = [];

  /// pending | processing | success | error: ...
  List<String> groupStatus = [];

  int importedRows = 0;
  int totalRows = 0;

  String? selectedBranchId;

  bool loading = false;
  bool apiLoading = false;
  bool validating = false;

  int currentIndex = 0;
  int currentBatchIndex = 0;
  int totalBatches = 0;

  String fileInfo = 'Ready to load stock data from API.';

  Future<void> _syncStockFromApi() async {
    if (apiLoading || loading) return;

    if (mounted) {
      setState(() {
        apiLoading = true;
        importedRows = 0;
        totalRows = 0;
        groups.clear();
        groupStatus.clear();
        fileInfo = 'Loading stock data from API...';
      });
    }

    final savedIds = <String>[];

    var offset = 0;

    final fetchedPageKeys = <String>{};

    try {
      while (true) {
        final uri = Uri.parse(_stockApiUrl).replace(
          queryParameters: {
            'limit': '$_apiPageSize',
            'offset': '$offset',
            'page': '${(offset ~/ _apiPageSize) + 1}',
          },
        );

        final response = await http.get(uri);

        if (response.statusCode < 200 ||
            response.statusCode >= 300) {
          throw 'API returned HTTP ${response.statusCode}.';
        }

        final decoded = jsonDecode(response.body);

        final rawRows = decoded is List ? decoded : decoded is Map ? (decoded['data'] ?? decoded['rows'] ?? decoded['stock'] ?? const []) : const [];

        if (rawRows is! List || rawRows.isEmpty) {
          break;
        }

        final rows = rawRows.whereType<Map>().map((row) => Map<String, dynamic>.from(row),).
        where((row) => (row['id']?.toString().trim() ?? '').isNotEmpty,).toList(growable: false);

        final pageKey = rows.isEmpty ? '' : '${rows.first['id']}:${rows.last['id']}:${rows.length}';

        if (pageKey.isNotEmpty &&
            !fetchedPageKeys.add(pageKey)) {
          break;
        }

        final pageGroups = _buildApiGroups(rows);

        if (pageGroups.isNotEmpty) {
          if (!mounted) return;

          setState(() {
            groups = pageGroups;
            groupStatus = List.filled(
              pageGroups.length,
              'pending',
            );
          });

          await upload();

          for (var index = 0;
          index < pageGroups.length;
          index++) {
            if (groupStatus[index] == 'success') {
              savedIds.addAll(
                pageGroups[index]
                    .rows
                    .map((row) => row.get('id'))
                    .where(
                      (id) => id.isNotEmpty,
                ),
              );
            }
          }
        }

        offset += rawRows.length;

        if (mounted) {
          setState(() {
            importedRows = offset;
            fileInfo = 'Saved $offset stock rows...';
          });
        }

        if (rawRows.length < _apiPageSize) {
          break;
        }
      }

      // ACKNOWLEDGE ONLY SUCCESSFULLY SAVED RECORDS

      if (savedIds.isNotEmpty) {
        await _acknowledgeApiStockIds(
          savedIds
        );
      }

      if (mounted) {
        setState(() {
          totalRows = offset;
          fileInfo =
          'Saved ${savedIds.length} stock rows successfully.';
        });
      }

      _snack(
        'Saved ${savedIds.length} stock rows and acknowledged them.',
        Colors.green,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          fileInfo = 'API sync failed.';
        });
      }

      _snack(
        'Stock API sync failed: $error',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          apiLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // BUILD API GROUPS
  // ---------------------------------------------------------------------

  List<_SaleGroup> _buildApiGroups(List<Map<String, dynamic>> rows) {
    final grouped = <String, List<_RawSaleRow>>{};

    for (final apiRow in rows) {
      final row = <String, String>{};

      apiRow.forEach((key, value) {
        row[key] = value?.toString() ?? '';
      });

      final transMode = (row['transmode'] ?? '').trim().toLowerCase();

      row['transmode'] = switch (transMode) {'credit' || 'credit purchase' => 'credit','cash' || 'cash purchase' => 'cash',_ => 'opening balance',};

      final branchid = (row['branchname'] ?? '').trim().toLowerCase();

      row['branchId'] =(branchid.trim());
      row['price'] =(row['price'] ?? '').trim().isEmpty ? row['cost_price'] ?? '': row['price'] ?? '';
      row['cp'] =(row['cp'] ?? '').trim().isEmpty? row['cost_price'] ?? '': row['cp'] ?? '';
      row['producttype'] =(row['producttype'] ?? '').trim().isEmpty ? row['product_type'] ?? '' : row['producttype'] ?? '';
      row['pcategory'] =(row['pcategory'] ?? '').trim().isEmpty ? row['product_category'] ?? '' : row['pcategory'] ?? '';
      row['invoiceno'] =(row['invoiceno'] ?? '').trim().isEmpty? row['tid'] ?? '': row['invoiceno'] ?? '';
      final sourceId = (row['id'] ?? '').trim();

      if (sourceId.isEmpty) {
        continue;
      }
      //group by tid if available, otherwise by sourceId
      final tid =(row['tid'] ?? '').trim();
      final groupKey =tid.isNotEmpty  ? tid : sourceId;

      grouped.putIfAbsent(groupKey, () => <_RawSaleRow>[],).add(_RawSaleRow(row),);
    }

    return grouped.entries.map((entry) => _SaleGroup(entry.key,entry.value,),).toList(growable: false);
  }

//acknowledge the stock ids that were successfully saved to the API
  Future<void> _acknowledgeApiStockIds(List<String> ids) async {
    try {
      final recordIds = ids.where((id) => id.trim().isNotEmpty).toList();
      if (recordIds.isEmpty) return;
      final payload = {
        'ids': recordIds,
      };

      final response = await http.post(
        Uri.parse(_stockCallbackApiUrl),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint(
        'CALLBACK STATUS: ${response.statusCode}',
      );

      debugPrint(
        'CALLBACK BODY: ${response.body}',
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw 'API acknowledgment returned HTTP '
            '${response.statusCode}.';
      }
    } catch (e, stackTrace) {
      debugPrint(
        'CALLBACK ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      rethrow;
    }
  }

  String _safeBranchName( String branchName, [String fallback = '',]) {
    final value = (branchName.trim().isNotEmpty ? branchName : fallback).trim();
    return value.isEmpty ? 'default' : value;
  }

  String _branchItemKey(String companyId,String itemName,String branchName, [String fallbackBranchName = '',]) {
    final normalizedItem =sanitize(itemName);
    final normalizedBranch =sanitize(_safeBranchName(branchName,fallbackBranchName,),);
    return '${sanitize(companyId)}_''${normalizedItem}_''$normalizedBranch';
  }

  void _snack(
      String msg,
      Color color,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // DATE
  // ---------------------------------------------------------------------

  Map<String, String> _dateParts(
      String dateymd,
      ) {
    DateTime dt;

    try {
      if (dateymd.isEmpty) {
        dt = DateTime.now();
      } else if (dateymd.contains('/')) {
        final parts = dateymd.split('/');

        if (parts.length != 3) {
          throw 'bad date';
        }

        dt = DateTime(int.parse(parts[2]),int.parse(parts[1]),int.parse(parts[0]),);
      } else {
        dt = DateTime.parse(dateymd);
      }
    } catch (_) {
      dt = DateTime.now();
    }

    final day =DateFormat('EEEE').format(dt);

    final year =dt.year.toString();

    final month ='${dt.year}.${dt.month}';

    final weekNumber =((dt.difference( DateTime(dt.year,1,1,),).inDays) /7).floor() +1;

    final week ='${dt.year}.$weekNumber';
    final ymd =DateFormat('yyyy-MM-dd').format(dt);
    return {
      'dateymd': ymd,
      'day': day,
      'year': year,
      'month': month,
      'week': week,
    };
  }


  String sanitize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(r'\s+'),
      '',
    )
        .replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '',
    );
  }

  // ---------------------------------------------------------------------
  // BRANCH
  // ---------------------------------------------------------------------

  dynamic _resolveBranch(Datafeed datafeed,String branchIdRaw,String defaultBranchId,) {
    return datafeed.branches.firstWhere(
          (b) => b.id == branchIdRaw,
      orElse: () =>
          datafeed.branches.firstWhere(
                (b) => b.id == defaultBranchId,
            orElse: () => throw
            'Branch "$branchIdRaw" not found',
          ),
    );
  }

  // ---------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------

  Future<Map<int, String>> _validateAllGroups({
    required Datafeed datafeed,
    required String companyId,
    required String defaultBranchId,
  }) async {
    final errors =
    <int, String>{};

    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final int g =
        nextIndex++;

        if (g >= groups.length) {
          return;
        }

        final error =
        await _validateSingleGroup(
          groupIndex: g,
          datafeed: datafeed,
          companyId: companyId,
          defaultBranchId: defaultBranchId,
        );

        if (error != null &&
            error.isNotEmpty) {
          errors[g] = error;
        }
      }
    }

    final workerCount =
    groups.length <
        _validationConcurrency
        ? groups.length
        : _validationConcurrency;

    if (workerCount == 0) {
      return errors;
    }

    await Future.wait(
      List.generate(
        workerCount,
            (_) => worker(),
      ),
    );

    return errors;
  }

  Future<String?> _validateSingleGroup({
    required int groupIndex,
    required Datafeed datafeed,
    required String companyId,
    required String defaultBranchId,
  }) async {
    final group =groups[groupIndex];

    final first =group.first;

    final rowErrors =
    <String>[];

    // ---------------------------------------------------------------
    // TRANSACTION MODE
    // ---------------------------------------------------------------

    final transModes = group.rows.map((r) => r.get('transmode','cash',).toLowerCase().trim(),).where((v) => v.isNotEmpty,).toSet();

    if (transModes.length > 1) {
      return 'Receipt "${group.receipt}" '
          'has conflicting transMode values: '
          '${transModes.join(', ')}';
    }

    final transMode =transModes.isEmpty? 'cash': transModes.first;




    const allowedModes = {
      'cash',
      'credit',
      'opening balance',
    };

    if (!allowedModes.contains(
      transMode,
    )) {
      return 'Receipt "${group.receipt}": '
          'invalid transMode "$transMode". '
          'Allowed values are cash, credit or opening balance.';
    }

    // ---------------------------------------------------------------
    // BRANCH
    // ---------------------------------------------------------------



    final branchIdRaw = first.get('branchname', '');
    String resolvedBranchId;
    String resolvedBranchLabel;

    try {
      final branch =_resolveBranch(datafeed,branchIdRaw,defaultBranchId,);
      resolvedBranchId =branch.id.isNotEmpty? branch.id: defaultBranchId;
      resolvedBranchLabel =branch.branchname.isNotEmpty? branch.branchname: resolvedBranchId;
     } catch (e) {
      return e.toString();
    }

    // ---------------------------------------------------------------
    // AGGREGATE
    // ---------------------------------------------------------------

    final Map<
        String,
        Map<String, dynamic>> aggregatedIncoming =
    {};

    for (int i = 0;
    i < group.rows.length;
    i++) {
      final row =
      group.rows[i];

      final itemName =row.get('item').trim();
      final barcode =row.get('barcode').trim();
      final quantity =double.tryParse(row.get('quantity','0',),) ??0;
      final pieces =double.tryParse(row.get('pieces','0', ),) ??0;
      final priceText =row.get('price').trim();
      final cpText =row.get('cost_price',row.get('cp', '',), ).trim();

      if (itemName.isEmpty &&  barcode.isEmpty)
          {
        rowErrors.add(
          'Row ${i + 1}: needs an item name or a barcode',
        );
        continue;
      }

      if (quantity <= 0) {
        rowErrors.add(
          'Row ${i + 1} '
              '("${itemName.isEmpty ? barcode : itemName}"): '
              'invalid quantity',
        );
        continue;
      }

      if (pieces <= 0) {
        rowErrors.add(
          'Row ${i + 1} '
              '("${itemName.isEmpty ? barcode : itemName}"): '
              'invalid pieces',
        );
        continue;
      }

      if (priceText.isNotEmpty &&
          double.tryParse(
            priceText,
          ) ==
              null) {
        rowErrors.add(
          'Row ${i + 1} '
              '("${itemName.isEmpty ? barcode : itemName}"): '
              'price is not a valid number',
        );
        continue;
      }

      if (cpText.isNotEmpty &&
          double.tryParse(
            cpText,
          ) ==
              null) {
        rowErrors.add(
          'Row ${i + 1} '
              '("${itemName.isEmpty ? barcode : itemName}"): '
              'cost_price is not a valid number',
        );
        continue;
      }

      final branchNameFromRow =
      row.get(
        'branchname',
        resolvedBranchLabel,
      );

      final resolvedBranchName =
      _safeBranchName(
        branchNameFromRow,
        resolvedBranchId,
      );

      final aggregateKey =
      _branchItemKey(
        companyId,
        itemName,
        resolvedBranchName,
        resolvedBranchId,
      );

      final itemid =
          '${sanitize(companyId)}_'
          '${sanitize(itemName)}';

      final existing =
      aggregatedIncoming[
      aggregateKey];

      if (existing == null) {
        aggregatedIncoming[
        aggregateKey] = {
          'itemid': itemid,
          'item': itemName,
          'barcode': barcode,
          'branchid': resolvedBranchId,
          'branchname': resolvedBranchName,
          'quantity': quantity,
          'pieces': pieces,
          'rows': [i + 1],
          'price': priceText,
          'cost_price': cpText,
          'mode': row.get(
            'mode',
            'Single',
          ),
          'pricemode': row.get(
            'pricemode',
            'retail',
          ),
        };
      } else {
        existing['quantity'] =
            (existing['quantity'] ?? 0) +
                quantity;

        existing['pieces'] =
            (existing['pieces'] ?? 0) +
                pieces;

        (existing['rows']
        as List)
            .add(i + 1);

        if ((existing['barcode'] ??
            '')
            .toString()
            .isEmpty &&
            barcode.isNotEmpty) {
          existing['barcode'] =
              barcode;
        }

        if ((existing['price'] ??
            '')
            .toString()
            .isEmpty &&
            priceText.isNotEmpty) {
          existing['price'] =
              priceText;
        }

        if ((existing[
        'cost_price'] ??
            '')
            .toString()
            .isEmpty &&
            cpText.isNotEmpty) {
          existing[
          'cost_price'] = cpText;
        }
      }
    }

    if (rowErrors.isNotEmpty) {
      return rowErrors.join('; ');
    }

    // ---------------------------------------------------------------
    // FINAL AGGREGATED VALIDATION
    // ---------------------------------------------------------------

    for (final incoming
    in aggregatedIncoming.values) {
      final itemName =
      (incoming['item'] ??
          '')
          .toString()
          .trim();

      final totalQuantity =
      (incoming['quantity'] ??
          0)
          .toDouble();

      final totalPieces =
      (incoming['pieces'] ??
          0)
          .toDouble();

      final costPriceText =
      (incoming[
      'cost_price'] ??
          '')
          .toString()
          .trim();

      final rows =
      (incoming['rows']
      as List)
          .join(', ');

      if (totalQuantity <= 0) {
        rowErrors.add(
          'Item "$itemName": '
              'aggregated quantity is invalid '
              '($totalQuantity).',
        );
      }

      if (totalPieces <= 0) {
        rowErrors.add(
          'Item "$itemName": '
              'aggregated pieces are invalid '
              '($totalPieces).',
        );
      }

      if (costPriceText.isEmpty) {
        rowErrors.add(
          'Rows $rows ("$itemName"): '
              'cost_price is required for upload.',
        );
      } else if (double.tryParse(
        costPriceText,
      ) ==
          null) {
        rowErrors.add(
          'Rows $rows ("$itemName"): '
              'cost_price is not a valid number.',
        );
      }
    }

    if (rowErrors.isNotEmpty) {
      return rowErrors.join('; ');
    }

    return null;
  }

  Future<void> upload() async {
    if (groups.isEmpty) {
      _snack(
        'No transactions to upload',
        Colors.orange,
      );
      return;
    }

    final datafeed = context.read<Datafeed>();

    await datafeed.getdata();

    final companyId = datafeed.companyid.trim();
    final companyName = datafeed.company;
    final staffPosition = datafeed.staffPosition;
    final staffName = datafeed.staff;
    final staffEmail = datafeed.staffemail;

    if (companyId.isEmpty) {
      _snack(
        'No company context found. Please log in again.',
        Colors.red,
      );
      return;
    }

    final defaultBranchId =
        selectedBranchId ?? datafeed.branchid;

    if (defaultBranchId.trim().isEmpty) {
      _snack(
        'No branch context found.',
        Colors.red,
      );
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
        validating = false;
        currentIndex = 0;
        currentBatchIndex = 0;
        totalBatches = 1;

        groupStatus = List.filled(
          groups.length,
          'pending',
          growable: true,
        );
      });
    }

    try {

      final payloadGroups = groups.map((group) {
        return {
          'receipt': group.receipt,
          'rows': group.rows.map((row) {
        return {
        'item': row.get('item'),
        'barcode': row.get('barcode'),
        'pieces': row.get('pieces', '0'),
        'quantity': row.get('quantity', '0'),
        'cost_price': row.get('cost_price',row.get('cp', '0'),),
        'cp': row.get('cp', '0'),
        'branchname': row.get('branchname',datafeed.branch, ),
        'mode': row.get('mode', 'Single'),
        'modeqty': row.get('modeqty', '1'),
        'boxpiece': row.get('boxpiece',row.get('modeqty', '1'),),
        'product_category':
        row.get('product_category', ''),
        'producttype':
        row.get('producttype', 'product'),
        'itemDiscount':
        row.get('itemDiscount', '0'),
        'vat':
        row.get('vat', '0'),
        'transmode':
        row.get(
        'transmode',
        'opening balance',
        ),
        'date': row.get('date'),
        'invoice': row.get('invoice'),
        'invoiceno': row.get('invoiceno'),
        'waybill': row.get('waybill'),
        'id': row.get('id'),
        'tid': row.get('tid'),
        'tname': row.get(
        'tname',
        companyName,
        ),
        'staff': row.get(
        'staff',
        staffName,
        ),
        };
        }).toList(),
        };
      }).toList();


      final callable = FirebaseFunctions.instance.httpsCallable('uploadStock');
      final result = await callable.call({
        'companyId': companyId,
        'companyName': companyName,
        'staffPosition': staffPosition,
        'staffName': staffName,
        'staffEmail': staffEmail,
        'defaultBranchId':
        defaultBranchId,
        'defaultBranchName':
        datafeed.branch,
        'defaultBranchType':
        datafeed.branchtype.isNotEmpty
            ? datafeed.branchtype
            : 'Warehouse',

        'groups':
        payloadGroups,

        'concurrency':
        _uploadConcurrency,
      });
      print("result:$result");
      final data = Map<String, dynamic>.from(result.data as Map,);
      final results =List<dynamic>.from(data['results'] ?? [],);

      /**
       * ============================================================
       * UPDATE UI USING SERVER RESULTS
       * ============================================================
       */

      for (final rawResult in results) {
        final item =
        Map<String, dynamic>.from(
          rawResult as Map,
        );

        final index =
        item['groupIndex'];

        if (index is! int ||
            index < 0 ||
            index >= groups.length) {
          continue;
        }

        if (item['success'] == true) {
          groupStatus[index] = 'success';
        } else {
          groupStatus[index] =
          'error: ${item['error'] ?? 'Upload failed'}';
        }
      }

      if (mounted) {
        setState(() {
          loading = false;
          validating = false;
          currentIndex = groups.length;
        });
      }
      final successful =
      (data['successful'] ?? 0) as int;

      final failed =
      (data['failed'] ?? 0) as int;

      if (mounted) {
        setState(() {
          loading = false;
          validating = false;
          currentIndex = groups.length;
        });
      }

      if (failed == 0) {
        _snack(
          '$successful transaction(s) uploaded successfully.',
          Colors.green,
        );
      } else {
        _snack(
          '$successful uploaded, $failed failed.',
          Colors.orange,
        );

        _showErrorsDialog();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          validating = false;
        });
      }
    print(e);
      debugPrint(
        'uploadStock Cloud Function error: '
            '${e.code} - ${e.message}',
      );

      _snack(
        e.message ??
            'Stock upload failed.',
        Colors.red,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'uploadStock error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (mounted) {
        setState(() {
          loading = false;
          validating = false;
        });
      }

      _snack(
        'Stock upload failed: $e',
        Colors.red,
      );
    }
  }


  // Future upload() async {
  //   if (groups.isEmpty) {
  //     _snack(
  //       'No transactions to upload',
  //       Colors.orange,
  //     );
  //     return;
  //   }
  //
  //   final datafeed = context.read<Datafeed>();
  //
  //   await datafeed.getdata();
  //
  //   final companyId = datafeed.companyid;
  //   final companyName =datafeed.company;
  //   final staffPosition =datafeed.staffPosition;
  //
  //   final staffName =datafeed.staff;
  //   final staffEmail =datafeed.staffemail;
  //
  //   if (companyId.isEmpty) {
  //     _snack(
  //       'No company context found. Please log in again.',
  //       Colors.red,
  //     );
  //     return;
  //   }
  //
  //   final defaultBranchId =selectedBranchId ?? datafeed.branchid;
  //
  //   if (mounted) {
  //     setState(() {
  //       loading = true;
  //       validating = true;
  //       currentIndex = 0;
  //       currentBatchIndex = 0;
  //
  //       // API pages are 1,000 groups at most.
  //       totalBatches = 1;
  //
  //       groupStatus = List.filled(
  //         groups.length,
  //         'pending',
  //         growable: true,
  //       );
  //     });
  //   }
  //
  //   final validationErrors =
  //   await _validateAllGroups(
  //     datafeed: datafeed,
  //     companyId: companyId,
  //     defaultBranchId: defaultBranchId,
  //   );
  //
  //   if (!mounted) return;
  //
  //   if (validationErrors.isNotEmpty) {
  //     setState(() {
  //       for (final entry
  //       in validationErrors.entries) {
  //         groupStatus[
  //         entry.key] =
  //         'error: ${entry.value}';
  //       }
  //
  //       validating = false;
  //       loading = false;
  //     });
  //
  //     _snack(
  //       'Validation failed for '
  //           '${validationErrors.length} '
  //           'of ${groups.length} transaction(s). '
  //           'Upload will continue for the remaining transactions.',
  //       Colors.orange,
  //     );
  //
  //     _showErrorsDialog();
  //   }
  //
  //   if (mounted) {
  //     setState(() {
  //       validating = false;
  //     });
  //   }
  //
  //   // ================================================================
  //   // CONCURRENT UPLOAD WORKERS
  //   // ================================================================
  //
  //   int nextGroupIndex = 0;
  //   int completedGroups = 0;
  //
  //   Future<void> processGroup(
  //       int g,
  //       ) async {
  //     if (g < 0 ||
  //         g >= groups.length) {
  //       return;
  //     }
  //
  //     final group =
  //     groups[g];
  //
  //     // A group that already failed validation should not attempt upload.
  //     if (groupStatus[g]
  //         .startsWith('error')) {
  //       completedGroups++;
  //
  //       if (mounted) {
  //         setState(() {
  //           currentIndex =
  //               completedGroups;
  //         });
  //       }
  //
  //       return;
  //     }
  //
  //     if (mounted) {
  //       setState(() {
  //         groupStatus[g] =
  //         'processing';
  //
  //         currentIndex =
  //             completedGroups;
  //       });
  //     }
  //
  //     try {
  //       // ============================================================
  //       // STEP 1
  //       // AGGREGATE DUPLICATE ITEMS
  //       // ============================================================
  //
  //       final Map<
  //           String,
  //           Map<String, dynamic>>
  //       aggregatedIncoming = {};
  //
  //       for (final row
  //       in group.rows) {
  //         final itemNameRaw =
  //         row.get('item').trim();
  //
  //         final barcode =
  //         row.get('barcode').trim();
  //
  //         final pieces =
  //             double.tryParse(
  //               row.get(
  //                 'pieces',
  //                 '0',
  //               ),
  //             ) ??
  //                 0;
  //
  //         final quantity =
  //             double.tryParse(
  //               row.get(
  //                 'quantity',
  //                 '0',
  //               ),
  //             ) ??
  //                 0;
  //
  //         final costPrice =
  //             double.tryParse(
  //               row.get(
  //                 'cost_price',
  //                 row.get(
  //                   'cp',
  //                   '0',
  //                 ),
  //               ),
  //             ) ??
  //                 0;
  //
  //         final branchNameFromRow =
  //         row.get(
  //           'branchname',
  //           datafeed.branch,
  //         );
  //
  //         final resolvedBranchName =
  //         _safeBranchName(
  //           branchNameFromRow,
  //           defaultBranchId,
  //         );
  //
  //         if (itemNameRaw.isEmpty &&
  //             barcode.isEmpty) {
  //           throw 'Item name or barcode is required.';
  //         }
  //
  //         if (pieces <= 0) {
  //           throw 'Invalid pieces for '
  //               '"${itemNameRaw.isEmpty ? barcode : itemNameRaw}".';
  //         }
  //
  //         if (costPrice < 0) {
  //           throw 'Invalid cost price for '
  //               '"${itemNameRaw.isEmpty ? barcode : itemNameRaw}".';
  //         }
  //
  //         final itemid =
  //             '${sanitize(companyId)}_'
  //             '${sanitize(itemNameRaw)}';
  //
  //         final aggregateKey =
  //         _branchItemKey(
  //           companyId,
  //           itemNameRaw,
  //           resolvedBranchName,
  //           defaultBranchId,
  //         );
  //
  //         final rowStockValue =
  //             costPrice * pieces;
  //
  //         final existing =
  //         aggregatedIncoming[
  //         aggregateKey];
  //
  //         if (existing == null) {
  //           aggregatedIncoming[
  //           aggregateKey] = {
  //             'itemid': itemid,
  //             'item': itemNameRaw,
  //             'barcode': barcode,
  //             'branchname':
  //             resolvedBranchName,
  //             'pieces': pieces,
  //             'quantity': quantity,
  //             'value': rowStockValue,
  //             'costPrice': costPrice,
  //           };
  //         } else {
  //           existing['pieces'] =
  //               (existing['pieces'] ??
  //                   0) +
  //                   pieces;
  //
  //           existing['quantity'] =
  //               (existing['quantity'] ??
  //                   0) +
  //                   quantity;
  //
  //           existing['value'] =
  //               (existing['value'] ??
  //                   0) +
  //                   rowStockValue;
  //         }
  //       }
  //
  //       // ============================================================
  //       // STEP 2
  //       // RESOLVE ITEMS / WEIGHTED CP
  //       // ============================================================
  //
  //
  //       final Map< String,Map<String, dynamic>>resolvedItems = {};
  //
  //       for (final entry in aggregatedIncoming.entries) {
  //
  //         final aggregateKey =entry.key;
  //         final incoming =entry.value;
  //         final newStockPieces =(incoming['pieces'] ?? 0).toDouble();
  //         final newStockValue =(incoming['value'] ??0).toDouble();
  //         final actualItemId =(incoming['itemid'] ??aggregateKey).toString().trim();
  //         final cp =(incoming['costPrice'] ??0).toDouble();
  //         if (newStockPieces <= 0) {
  //           throw 'Invalid stock pieces for '
  //               '"${incoming['item']}".';
  //         }
  //
  //
  //         resolvedItems[
  //         aggregateKey] = {
  //           'itemid': actualItemId,
  //           'item':incoming['item'] ?? '',
  //           'barcode':incoming['barcode'] ?? '',
  //           'pieces':newStockPieces,
  //           'total': double.parse(newStockValue.toStringAsFixed(2), ),
  //           'cp':cp,
  //           'originalcp':cp,
  //           'producttype':'product',
  //           'pcategory':'',
  //           'branchid':defaultBranchId,
  //           'branchname': incoming['branchname'] ?? datafeed.branch,
  //           'stockin_pieces':newStockPieces,
  //           'stock_value':double.parse(newStockValue.toStringAsFixed(2), ),
  //
  //         };
  //       }
  //
  //       // ============================================================
  //       // STEP 3
  //       // BUILD TRANSACTION ITEMS
  //       // ============================================================
  //
  //
  //       final List<Map<String, dynamic>>transactionItems = [];
  //       double calculatedGross = 0.0;
  //       double calculatedDiscount = 0.0;
  //
  //       for (final entry in aggregatedIncoming.entries) {
  //
  //         final aggregateKey =entry.key;
  //         final incoming =entry.value;
  //         final looked =resolvedItems[aggregateKey];
  //         if (looked == null) {
  //           throw 'Unable to resolve item '
  //               '"$aggregateKey".';
  //         }
  //
  //         final pieces =(incoming['pieces'] ??0).toDouble();
  //         final aggregatedValue =(incoming['value'] ??0).toDouble();
  //         final aggregatedqty =(incoming['quantity'] ??0).toDouble();
  //         final averageCp =(incoming['costPrice'] ??0).toDouble();
  //         final itemName =(incoming['item'] ?? looked['name'] ??  '').toString();
  //         final barcode =(incoming['barcode'] ?? looked['barcode'] ?? '').toString();
  //         final matchingRows =group.rows.where((row) {final rowItem =row.get('item',).trim();
  //         final rowBranch = _safeBranchName(row.get('branchname',datafeed.branch,),defaultBranchId, );
  //         final rowItemId ='${sanitize(companyId)}_''${sanitize(rowItem)}';
  //         final rowAggregateKey = _branchItemKey(companyId,rowItem,rowBranch,defaultBranchId,);
  //
  //         return rowAggregateKey ==aggregateKey ||rowItemId ==aggregateKey; },).toList();
  //
  //         if (matchingRows.isEmpty) {
  //           throw 'Could not find source row for '
  //               'item "$itemName".';
  //         }
  //
  //         final firstItemRow = matchingRows.first;
  //         final mode =firstItemRow.get('mode','Single', );
  //         final modeQty =firstItemRow.get('modeqty','1', );
  //         final boxPieces =firstItemRow.get('boxpiece',modeQty,);
  //         final pcategory =firstItemRow.get('product_category',looked['pcategory']?.toString() ?? '',);
  //         final producttype =firstItemRow.get('producttype',looked['producttype'] ?.toString() ??'product',);
  //         final discount =   double.tryParse(firstItemRow.get('itemDiscount','0',), ) ??0;
  //         final vat =  double.tryParse(firstItemRow.get('vat','0',),) ?? 0;
  //         final grossTotal =aggregatedValue;
  //
  //
  //         transactionItems.add({
  //           'itemid':(looked['itemid'] ??itemName).toString(),
  //           'item': itemName,
  //           'barcode':barcode,
  //           'pieces':pieces,
  //           'quantity':aggregatedqty,
  //           'price':averageCp,
  //           'originalcp':looked['originalcp'] ??averageCp,
  //           'total':double.parse(grossTotal.toStringAsFixed(2), ),
  //           'gross':double.parse(grossTotal.toStringAsFixed(2),),
  //           'discount':discount,
  //           'vat':vat,
  //           'stockingmode':mode,
  //           'modeqty':modeQty,
  //           'boxpiece':boxPieces,
  //           'pcategory':pcategory,
  //           'producttype':producttype,
  //           'branchname':
  //           incoming['branchname'] ??firstItemRow.get('branchname', datafeed.branch, ),
  //          'stockin_pieces':pieces,
  //
  //           'stock_value':
  //           double.parse(
  //             grossTotal
  //                 .toStringAsFixed(2),
  //           ),
  //           'syncstatus':
  //           false,
  //         });
  //
  //         calculatedGross +=
  //             grossTotal;
  //
  //         calculatedDiscount +=
  //             discount;
  //       }
  //

  //       // ============================================================
  //       // STEP 3B
  //       // BUILD STOCK TRANSACTION DOCUMENT
  //       // ============================================================
  //
  //       final first =
  //           group.first;
  //
  //       final transMode =
  //       group.rows
  //           .map(
  //             (row) => row
  //             .get(
  //           'transmode',
  //           'opening balance',
  //         )
  //             .toLowerCase()
  //             .trim(),
  //       )
  //           .toSet()
  //           .firstWhere(
  //             (value) =>
  //         value.isNotEmpty,
  //         orElse: () =>
  //         'opening balance',
  //       );
  //
  //       final bool iscredit =
  //           transMode ==
  //               'credit';
  //
  //       final branchId =
  //           defaultBranchId;
  //
  //       final branchName =
  //       datafeed.branch
  //           .isNotEmpty
  //           ? datafeed.branch
  //           : defaultBranchId;
  //
  //       final branchType =
  //       datafeed.branchtype
  //           .isNotEmpty
  //           ? datafeed.branchtype
  //           : 'Warehouse';
  //
  //       final now =
  //       Timestamp.now();
  //
  //       final dateParts =
  //       _dateParts(
  //         first.get(
  //           'date',
  //           DateFormat(
  //             'yyyy-MM-dd',
  //           ).format(
  //             DateTime.now(),
  //           ),
  //         ),
  //       );
  //
  //       final invoice =
  //       first.get(
  //         'invoice',
  //         first.get(
  //           'invoiceno',
  //           group.receipt,
  //         ),
  //       );
  //
  //       // ------------------------------------------------------------
  //       // FIX:
  //       // first.get() returns String.
  //       // No need for "rawDate is DateTime".
  //       // ------------------------------------------------------------
  //
  //       final rawDate =
  //       first.get(
  //         'date',
  //         DateFormat(
  //           'yyyy-MM-dd',
  //         ).format(
  //           DateTime.now(),
  //         ),
  //       );
  //
  //       final invoicedate =
  //       _normalizeInvoiceDate(
  //         rawDate,
  //       );
  //
  //       final uploadedbranch =
  //       first.get(
  //         'branchname',
  //         branchName,
  //       );
  //
  //       final uploadedbranchid =
  //           '${companyId.trim().toLowerCase()}'
  //           '${uploadedbranch.trim().toLowerCase().replaceAll(
  //         RegExp(r'[^a-z0-9]+'),
  //         '_',
  //       )}';
  //
  //       final waybill =
  //       first.get(
  //         'waybill',
  //         first.get(
  //           'invoiceno',
  //           group.receipt,
  //         ),
  //       );
  //
  //       final sourceId =first.get('id').trim();
  //
  //
  //       final tid =
  //       first.get(
  //         'tid',
  //         group.receipt,
  //       ).trim();
  //
  //       final transactionKey =
  //       tid.isNotEmpty
  //           ? tid
  //           : sourceId;
  //       final sourcebranch =first.get('branchname').trim();
  //
  //       final docId =
  //       transactionKey.isEmpty
  //           ? '${sanitize(companyId)}'
  //           '_${sanitize(branchId)}'
  //           '_${DateTime.now().millisecondsSinceEpoch}'
  //           '_${sanitize(staffPosition.toString())}'
  //           : '${sanitize(companyId)}'
  //           '_${sanitize(sourcebranch)}'
  //           '_${sanitize(transactionKey)}';
  //
  //
  //       final saleDocRef = db.collection('stock_transactions',).doc(docId);
  //       final isApiUpdate =  sourceId.isNotEmpty && (await saleDocRef.get()).exists;
  //       final supplierid ='${companyId.trim().toLowerCase()}''_${first.get('tname', companyName).trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'',)}';
  //
  //
  //       final supplier =
  //       first.get(
  //         'tname',
  //         companyName,
  //       );
  //
  //       final staff =
  //       first.get(
  //         'staff',
  //         staffName,
  //       );
  //
  //       final totalDiscount =
  //           calculatedDiscount;
  //
  //       final grandTotal =
  //           calculatedGross;
  //
  //       final timestamp =
  //           now.millisecondsSinceEpoch;
  //
  //       final calculatedNet =
  //           calculatedGross -
  //               calculatedDiscount;
  //
  //       final String dateString =
  //           invoicedate;
  //
  //       final parts =
  //       dateString.split('-');
  //
  //       final totimestamp =
  //       Timestamp.fromDate(
  //         DateTime.utc(
  //           int.parse(parts[0]),
  //           int.parse(parts[1]),
  //           int.parse(parts[2]),
  //         ),
  //       );
  //
  //       final saleDoc =
  //       <String, dynamic>{
  //         'docid':
  //         docId,
  //         'tid': tid,
  //         'companyid':
  //         companyId,
  //         'company':
  //         companyName,
  //         'branchid':
  //         uploadedbranchid,
  //         'branchname':
  //         uploadedbranch,
  //         'branchType':
  //         branchType,
  //         'createdat':
  //         now,
  //         'createdby':
  //         staff,
  //         'uploadedby':
  //         staffName,
  //         'staffemail':
  //         staffEmail,
  //         'date':
  //         invoicedate,
  //         'day':
  //         dateParts['day'],
  //         'month':
  //         dateParts['month'],
  //         'week':
  //         dateParts['week'],
  //         'year':
  //         dateParts['year'],
  //         'invoicedate':
  //         totimestamp,
  //         'invoice':
  //         invoice,
  //         'waybill':
  //         waybill,
  //         'transactionid':
  //         docId,
  //         'discount':
  //         totalDiscount,
  //         'itemCount':
  //         transactionItems.length,
  //         'gross':
  //         grandTotal,
  //         'netval':
  //         grandTotal,
  //         'paymentaccount':
  //         transMode,
  //         'purchasetype':
  //         transMode,
  //         'supplierid':
  //         supplierid,
  //         'suppliername':
  //         supplier,
  //         'items':
  //         transactionItems,
  //         'timestamp':
  //         timestamp,
  //         'syncstatus':
  //         false,
  //         'stocktype':
  //         'uploaded',
  //       };
  //
  //       final batch =
  //       db.batch();
  //
  //       batch.set(
  //         saleDocRef,
  //         saleDoc,
  //         SetOptions(
  //           merge: true,
  //         ),
  //       );
  //
  //       await batch.commit();
  //
  //
  //
  //       completedGroups++;
  //
  //       if (mounted) {
  //         setState(() {
  //           groupStatus[g] =
  //           'success';
  //
  //           currentIndex =
  //               completedGroups;
  //         });
  //       }
  //     } catch (e, stackTrace) {
  //       debugPrint(
  //         'Upload error for group $g: $e',
  //       );
  //
  //       debugPrint(
  //         stackTrace.toString(),
  //       );
  //
  //       completedGroups++;
  //
  //       if (mounted) {
  //         setState(() {
  //           groupStatus[g] =
  //           'error: $e';
  //
  //           currentIndex =
  //               completedGroups;
  //         });
  //       }
  //     }
  //   }
  //
  //   // ================================================================
  //   // WORKER
  //   // ================================================================
  //
  //   Future<void> worker() async {
  //     while (true) {
  //       if (nextGroupIndex >=
  //           groups.length) {
  //         return;
  //       }
  //
  //       final index =
  //       nextGroupIndex++;
  //
  //       await processGroup(
  //         index,
  //       );
  //     }
  //   }
  //
  //   final workerCount =
  //   groups.length <
  //       _uploadConcurrency
  //       ? groups.length
  //       : _uploadConcurrency;
  //
  //   if (workerCount > 0) {
  //     await Future.wait(
  //       List.generate(
  //         workerCount,
  //             (_) => worker(),
  //       ),
  //     );
  //   }
  //
  //   // ================================================================
  //   // FINISHED
  //   // ================================================================
  //
  //   if (mounted) {
  //     setState(() {
  //       loading = false;
  //       validating = false;
  //       currentIndex =
  //           groups.length;
  //     });
  //   }
  // }


  String _normalizeInvoiceDate(
      String rawDate,
      ) {
    final value =
    rawDate.trim();

    if (value.isEmpty) {
      return DateFormat(
        'yyyy-MM-dd',
      ).format(
        DateTime.now(),
      );
    }

    try {
      if (value.contains('/')) {
        final parts =
        value.split('/');

        if (parts.length == 3) {
          final dt =
          DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );

          return DateFormat(
            'yyyy-MM-dd',
          ).format(dt);
        }
      }

      final dt =
      DateTime.parse(value);

      return DateFormat(
        'yyyy-MM-dd',
      ).format(dt);
    } catch (_) {
      // Preserve the previous fallback behavior of using the first
      // ten characters where possible.
      if (value.length >= 10) {
        return value.substring(
          0,
          10,
        );
      }

      return DateFormat(
        'yyyy-MM-dd',
      ).format(
        DateTime.now(),
      );
    }
  }

  // ---------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------

  int get successCount =>
      groupStatus.where(
            (s) => s == 'success',
      ).length;

  int get errorCount =>
      groupStatus.where(
            (s) => s.startsWith(
          'error',
        ),
      ).length;

  int get pendingCount =>
      groupStatus.where(
            (s) => s == 'pending',
      ).length;

  double get progress =>
      groups.isEmpty
          ? 0
          : (currentIndex /
          groups.length)
          .clamp(
        0.0,
        1.0,
      );

  // ---------------------------------------------------------------------
  // ERROR DIALOG
  // ---------------------------------------------------------------------

  void _showErrorsDialog() {
    final errors =
    <String>[];

    for (int i = 0;
    i < groupStatus.length;
    i++) {
      if (groupStatus[i]
          .startsWith('error')) {
        errors.add(
          'Receipt "${groups[i].receipt}": '
              '${groupStatus[i].replaceFirst(
            'error: ',
            '',
          )}',
        );
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
        const Color(0xFF182232),
        title: Text(
          'Upload Errors (${errors.length})',
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        content: SizedBox(
          width: 520,
          child:
          SingleChildScrollView(
            child: Text(
              errors.isEmpty
                  ? 'No errors.'
                  : errors.join(
                '\n\n',
              ),
              style:
              const TextStyle(
                color:
                Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
                  context,
                ),
            child:
            const Text(
              'Close',
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final datafeed = context.read<Datafeed>();
      datafeed.fetchBranches();
    });
  }

  // ---------------------------------------------------------------------
  // API INFO
  // ---------------------------------------------------------------------

  void _showApiInfo() {
    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            backgroundColor:
            const Color(0xFF182232),
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),
            title: const Text(
              'API Stock Sync',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                FontWeight.bold,
              ),
            ),
            content:
            const SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Text(
                    'Stock rows are loaded from the API in pages of 1,000 and processed through the stock transaction workflow. Items, supplier balances, and stock_transactions are updated using the existing logic.',
                    style: TextStyle(
                      color:
                      Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(
                    height: 12,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                    ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color:
                    Colors.lightBlue,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // ---------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(
      BuildContext context,
      ) {
    final isMobile =
        MediaQuery.of(context)
            .size
            .width <
            768;

    final datafeed =
    context.watch<Datafeed>();

    return Scaffold(
      backgroundColor:
      const Color(0xFF101624),
      appBar: AppBar(
        backgroundColor:
        const Color(0xFF1B263B),
        title: const Text(
          'Bulk Stock Upload',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
            FontWeight.w600,
          ),
        ),
        elevation: 0,
        actions: [
          if (!loading)
            Padding(
              padding:
              const EdgeInsets.only(
                right: 16,
              ),
              child:
              IconButton(
                icon:
                const Icon(
                  Icons
                      .help_outline,
                  color:
                  Colors.lightBlue,
                ),
                onPressed:
                _showApiInfo,
                tooltip:
                'API sync information',
              ),
            ),
        ],
      ),
      body:
      SingleChildScrollView(
        child: Padding(
          padding:
          EdgeInsets.symmetric(
            horizontal:
            isMobile
                ? 16
                : 24,
            vertical: 20,
          ),
          child: Center(
            child:
            ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 1200,
              ),
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  // _buildBranchSelector(
                  //   datafeed,
                  // ),
                  const SizedBox(
                    height: 24,
                  ),
                  _buildApiSection(),
                  const SizedBox(
                    height: 24,
                  ),
                  if (groups.isEmpty)
                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        top: 24,
                      ),
                      child:
                      Center(
                        child:
                        Column(
                          children: [
                            const Icon(
                              Icons
                                  .receipt_long_outlined,
                              size: 64,
                              color: Colors
                                  .white24,
                            ),
                            const SizedBox(
                              height: 16,
                            ),
                            Text(
                              'Load stock data from the API to begin',
                              style: Theme.of(
                                context,
                              )
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                color: Colors
                                    .white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _buildApiInfoCard(),
                    const SizedBox(
                      height: 24,
                    ),
                    _buildStatusSummary(),
                    const SizedBox(
                      height: 24,
                    ),
                    _buildProgressSection(),
                    const SizedBox(
                      height: 24,
                    ),
                    _buildGroupsTable(
                      isMobile,
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    _buildActionButtons(
                      isMobile,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // BRANCH SELECTOR
  // ---------------------------------------------------------------------

  // Widget _buildBranchSelector(
  //     Datafeed datafeed,
  //     ) {
  //   final currentId =
  //       selectedBranchId ??
  //           datafeed.branchid;
  //
  //   final hasCurrent =
  //   datafeed.branches.any(
  //         (b) => b.id == currentId,
  //   );
  //
  //   return Container(
  //     decoration:
  //     BoxDecoration(
  //       color:
  //       const Color(0xFF22304A),
  //       borderRadius:
  //       BorderRadius.circular(
  //         12,
  //       ),
  //       border: Border.all(
  //         color: Colors.white12,
  //       ),
  //     ),
  //     padding:
  //     const EdgeInsets.all(
  //       20,
  //     ),
  //     child:
  //     Column(
  //       crossAxisAlignment:
  //       CrossAxisAlignment
  //           .start,
  //       children: [
  //         const Row(
  //           children: [
  //             Icon(
  //               Icons
  //                   .store_outlined,
  //               color:
  //               Colors.lightBlue,
  //               size: 24,
  //             ),
  //             SizedBox(
  //               width: 12,
  //             ),
  //             Text(
  //               'Upload To Branch',
  //               style: TextStyle(
  //                 color:
  //                 Colors.white,
  //                 fontWeight:
  //                 FontWeight.w600,
  //                 fontSize: 16,
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(
  //           height: 6,
  //         ),
  //         const Padding(
  //           padding:
  //           EdgeInsets.only(
  //             left: 36,
  //           ),
  //           child: Text(
  //             'Used for any row that leaves branchId blank, and for checking stock before upload.',
  //             style:
  //             TextStyle(
  //               color:
  //               Colors.white54,
  //               fontSize: 12,
  //             ),
  //           ),
  //         ),
  //         const SizedBox(
  //           height: 16,
  //         ),
  //         DropdownButtonFormField<
  //             String>(
  //           value:
  //           hasCurrent
  //               ? currentId
  //               : null,
  //           dropdownColor:
  //           const Color(
  //             0xFF22304A,
  //           ),
  //           style:
  //           const TextStyle(
  //             color:
  //             Colors.white,
  //             fontSize: 14,
  //           ),
  //           decoration:
  //           InputDecoration(
  //             filled: true,
  //             fillColor:
  //             const Color(
  //               0xFF101624,
  //             ),
  //             contentPadding:
  //             const EdgeInsets
  //                 .symmetric(
  //               horizontal: 12,
  //               vertical: 10,
  //             ),
  //             border:
  //             OutlineInputBorder(
  //               borderRadius:
  //               BorderRadius
  //                   .circular(
  //                 8,
  //               ),
  //               borderSide:
  //               BorderSide.none,
  //             ),
  //           ),
  //           hint: const Text(
  //             'Select branch',
  //             style:
  //             TextStyle(
  //               color:
  //               Colors.white54,
  //             ),
  //           ),
  //           items: datafeed
  //               .branches
  //               .map(
  //                 (b) =>
  //                 DropdownMenuItem<
  //                     String>(
  //                   value: b.id,
  //                   child: Text(
  //                     b.branchname
  //                         .isNotEmpty
  //                         ? b.branchname
  //                         : b.id,
  //                   ),
  //                 ),
  //           )
  //               .toList(),
  //           onChanged:
  //           loading
  //               ? null
  //               : (val) {
  //             setState(
  //                   () {
  //                 selectedBranchId =
  //                     val;
  //               },
  //             );
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ---------------------------------------------------------------------
  // API SECTION
  // ---------------------------------------------------------------------

  Widget _buildApiSection() {
    return Container(
      decoration:
      BoxDecoration(
        color:
        const Color(0xFF22304A),
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      padding:
      const EdgeInsets.all(
        20,
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .cloud_download_outlined,
                color: apiLoading
                    ? Colors.orange
                    : Colors.lightBlue,
                size: 24,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      'API Stock Sync',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    const Text(
                      'Load stock records and save them as stock transactions.',
                      style:
                      TextStyle(
                        color:
                        Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          SizedBox(
            width:
            double.infinity,
            height: 48,
            child:
            OutlinedButton.icon(
              style:
              OutlinedButton
                  .styleFrom(
                foregroundColor:
                Colors
                    .tealAccent,
                side:
                const BorderSide(
                  color:
                  Colors
                      .tealAccent,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    8,
                  ),
                ),
              ),
              onPressed:
              loading ||
                  apiLoading
                  ? null
                  : _syncStockFromApi,
              icon: apiLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                ),
              )
                  : const Icon(
                Icons
                    .cloud_download_outlined,
              ),
              label:
              const Text(
                'Load Stock From API',
                style:
                TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight
                      .w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // API INFO CARD
  // ---------------------------------------------------------------------

  Widget _buildApiInfoCard() {
    return Container(
      decoration:
      BoxDecoration(
        color:
        const Color(0xFF1B263B),
        borderRadius:
        BorderRadius.circular(
          8,
        ),
        border: Border.all(
          color: Colors.teal
              .withOpacity(
            0.3,
          ),
        ),
      ),
      padding:
      const EdgeInsets.all(
        16,
      ),
      child:
      Row(
        children: [
          const Icon(
            Icons.info_outline,
            color:
            Colors.teal,
            size: 20,
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'API Sync Details',
                  style:
                  TextStyle(
                    color:
                    Colors.white70,
                    fontWeight:
                    FontWeight
                        .w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  fileInfo,
                  style:
                  const TextStyle(
                    color:
                    Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // STATUS SUMMARY
  // ---------------------------------------------------------------------

  Widget _buildStatusSummary() {
    return Row(
      children: [
        _buildStatusCard(
          'Success',
          successCount,
          Colors.green
              .withOpacity(
            0.2,
          ),
          Colors.green,
        ),
        const SizedBox(
          width: 12,
        ),
        _buildStatusCard(
          'Errors',
          errorCount,
          Colors.red
              .withOpacity(
            0.2,
          ),
          Colors.red,
        ),
        const SizedBox(
          width: 12,
        ),
        _buildStatusCard(
          'Pending',
          pendingCount,
          Colors.orange
              .withOpacity(
            0.2,
          ),
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatusCard(
      String label,
      int count,
      Color bgColor,
      Color accentColor,
      ) {
    return Expanded(
      child:
      Container(
        decoration:
        BoxDecoration(
          color:
          bgColor,
          borderRadius:
          BorderRadius.circular(
            8,
          ),
          border:
          Border.all(
            color:
            accentColor
                .withOpacity(
              0.5,
            ),
          ),
        ),
        padding:
        const EdgeInsets
            .symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        child:
        Column(
          children: [
            Text(
              count.toString(),
              style:
              TextStyle(
                color:
                accentColor,
                fontSize:
                24,
                fontWeight:
                FontWeight
                    .bold,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              label,
              style:
              const TextStyle(
                color:
                Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // PROGRESS
  // ---------------------------------------------------------------------

  Widget _buildProgressSection() {
    final label =
    validating
        ? 'Validating items & stock…'
        : 'Batch $currentBatchIndex of '
        '$totalBatches • '
        '${currentIndex}/${groups.length} processed';

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children: [
        Row(
          mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
          children: [
            Text(
              validating
                  ? 'Validating'
                  : 'Upload Progress',
              style:
              const TextStyle(
                color:
                Colors.white70,
                fontWeight:
                FontWeight
                    .w600,
              ),
            ),
            if (!validating)
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration:
                BoxDecoration(
                  color: Colors
                      .lightBlue
                      .withOpacity(
                    0.2,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    4,
                  ),
                ),
                child:
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style:
                  const TextStyle(
                    color:
                    Colors.lightBlue,
                    fontWeight:
                    FontWeight
                        .w600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(
          height: 12,
        ),
        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            8,
          ),
          child:
          validating
              ? const LinearProgressIndicator(
            minHeight: 8,
            backgroundColor:
            Colors
                .white12,
            valueColor:
            AlwaysStoppedAnimation<
                Color>(
              Colors.orange,
            ),
          )
              : LinearProgressIndicator(
            value:
            progress,
            minHeight: 8,
            backgroundColor:
            Colors
                .white12,
            valueColor:
            AlwaysStoppedAnimation<
                Color>(
              progress ==
                  1.0
                  ? Colors
                  .green
                  : Colors
                  .lightBlue,
            ),
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          label,
          style:
          const TextStyle(
            color:
            Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // GROUP TABLE
  // ---------------------------------------------------------------------

  Widget _buildGroupsTable(
      bool isMobile,
      ) {
    return Container(
      decoration:
      BoxDecoration(
        color:
        const Color(0xFF1B263B),
        borderRadius:
        BorderRadius.circular(
          8,
        ),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child:
      ClipRRect(
        borderRadius:
        BorderRadius.circular(
          8,
        ),
        child:
        SingleChildScrollView(
          scrollDirection:
          Axis.horizontal,
          child:
          ConstrainedBox(
            constraints:
            BoxConstraints(
              minWidth:
              MediaQuery.of(
                context,
              ).size.width -
                  32,
            ),
            child:
            DataTable(
              headingRowColor:
              WidgetStateColor
                  .resolveWith(
                    (_) =>
                const Color(
                  0xFF22304A,
                ),
              ),
              headingTextStyle:
              const TextStyle(
                color:
                Colors.white70,
                fontWeight:
                FontWeight
                    .w600,
                fontSize: 12,
              ),
              columns:
              const [
                DataColumn(
                  label:
                  Text('Ref'),
                ),
                DataColumn(
                  label:
                  Text('Mode'),
                ),
                DataColumn(
                  label:
                  Text('Items'),
                ),
                DataColumn(
                  label:
                  Text('Supplier'),
                ),
                DataColumn(
                  label:
                  Text('Status'),
                ),
              ],
              rows:
              List.generate(
                groups.length,
                    (i) {
                  final group =
                  groups[i];

                  final status =
                  groupStatus[i];

                  final isError =
                  status
                      .startsWith(
                    'error',
                  );

                  final isSuccess =
                      status ==
                          'success';

                  return DataRow(
                    color:
                    WidgetStateColor
                        .resolveWith(
                          (_) =>
                      isError
                          ? Colors
                          .red
                          .withOpacity(
                        0.12,
                      )
                          : isSuccess
                          ? Colors
                          .green
                          .withOpacity(
                        0.06,
                      )
                          : Colors
                          .white
                          .withOpacity(
                        0.02,
                      ),
                    ),
                    cells: [
                      DataCell(
                        Text(
                          group
                              .receipt,
                          style:
                          const TextStyle(
                            color:
                            Colors.white70,
                            fontSize:
                            12,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          group
                              .first
                              .get(
                            'transmode',
                            'cash',
                          ),
                          style:
                          const TextStyle(
                            color:
                            Colors.white54,
                            fontSize:
                            12,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${group.rows.length}',
                          style:
                          const TextStyle(
                            color:
                            Colors.white54,
                            fontSize:
                            12,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          group
                              .first
                              .get(
                            'tname',
                            '-',
                          ),
                          style:
                          const TextStyle(
                            color:
                            Colors.white54,
                            fontSize:
                            12,
                          ),
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message:
                          status,
                          child:
                          isSuccess
                              ? const Icon(
                            Icons
                                .check_circle,
                            color:
                            Colors.green,
                            size:
                            16,
                          )
                              : isError
                              ? const Icon(
                            Icons
                                .error,
                            color:
                            Colors.red,
                            size:
                            16,
                          )
                              : status ==
                              'processing'
                              ? const SizedBox(
                            width:
                            16,
                            height:
                            16,
                            child:
                            CircularProgressIndicator(
                              strokeWidth:
                              2,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                Colors.lightBlue,
                              ),
                            ),
                          )
                              : const Icon(
                            Icons
                                .schedule,
                            color:
                            Colors.orange,
                            size:
                            16,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // ACTION BUTTONS
  // ---------------------------------------------------------------------

  Widget _buildActionButtons(
      bool isMobile,
      ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment:
      WrapAlignment.end,
      children: [
        if (groups.isNotEmpty &&
            !loading)
          ElevatedButton.icon(
            style:
            ElevatedButton
                .styleFrom(
              backgroundColor:
              Colors.grey
                  .shade700,
              foregroundColor:
              Colors.white,
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius
                    .circular(
                  8,
                ),
              ),
              elevation: 0,
            ),
            onPressed: () {
              setState(() {
                groups.clear();
                groupStatus.clear();
                fileInfo =
                'Ready to load stock data from API.';
              });
            },
            icon:
            const Icon(
              Icons.clear,
            ),
            label:
            const Text(
              'Clear',
            ),
          ),
        if (errorCount > 0)
          ElevatedButton.icon(
            style:
            ElevatedButton
                .styleFrom(
              backgroundColor:
              Colors.red
                  .shade700,
              foregroundColor:
              Colors.white,
            ),
            onPressed:
            _showErrorsDialog,
            icon:
            const Icon(
              Icons.error_outline,
            ),
            label: Text(
              'View Errors ($errorCount)',
            ),
          ),
        SizedBox(
          width: isMobile
              ? double.infinity
              : null,
          child:
          ElevatedButton
              .icon(
            style:
            ElevatedButton
                .styleFrom(
              backgroundColor:
              loading
                  ? Colors.grey
                  : Colors.lightBlue,
              foregroundColor:
              Colors.white,
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius
                    .circular(
                  8,
                ),
              ),
              elevation: 0,
              padding:
              EdgeInsets.symmetric(
                horizontal:
                isMobile
                    ? 16
                    : 24,
                vertical: 12,
              ),
            ),
            onPressed:
            (loading ||
                groups.isEmpty)
                ? null
                : upload,
            icon: loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
                valueColor:
                AlwaysStoppedAnimation<
                    Color>(
                  Colors.white,
                ),
              ),
            )
                : const Icon(
              Icons
                  .cloud_upload,
            ),
            label:
            Text(
              validating
                  ? 'Validating...'
                  : loading
                  ? 'Uploading...'
                  : 'Start Upload',
              style:
              const TextStyle(
                fontSize: 14,
                fontWeight:
                FontWeight
                    .w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}