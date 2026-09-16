/*
import 'package:flutter/foundation.dart';

/// One row read straight out of the uploaded CSV / Excel file.
///
/// Every known column always exists as a key (filled with '' when the file
/// didn't include it), so `cells[key]` is never actually null — an omitted
/// column reads back as an empty string, not a missing one. Treat blank the
/// same as missing so `fallback` (item lookups, mode defaults, etc.)
/// actually gets used.
@immutable
class RawSaleRow {
  final Map<String, String> cells;
  const RawSaleRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// A group of rows sharing the same receipt/transactionRef -> becomes ONE
/// sales document.
@immutable
class SaleGroup {
  final String receipt;
  final List<RawSaleRow> rows;
  const SaleGroup(this.receipt, this.rows);

  RawSaleRow get first => rows.first;
}

/// Result of matching a row's `mode` text against an item's `modes` map.
@immutable
class ModePricing {
  final double modeQty;
  final double unitPrice;
  final String resolvedMode;
  const ModePricing({
    required this.modeQty,
    required this.unitPrice,
    required this.resolvedMode,
  });
}*/
//
// import 'package:flutter/foundation.dart';
//
// /// One row read straight out of the uploaded CSV / Excel file.
// ///
// /// Every known column always exists as a key (filled with '' when the file
// /// didn't include it), so `cells[key]` is never actually null — an omitted
// /// column reads back as an empty string, not a missing one. Treat blank the
// /// same as missing so `fallback` (item lookups, mode defaults, etc.)
// /// actually gets used.
// @immutable
// class RawSaleRow {
//   final Map<String, String> cells;
//   const RawSaleRow(this.cells);
//
//   String get(String key, [String fallback = '']) {
//     final value = (cells[key] ?? '').trim();
//     return value.isEmpty ? fallback : value;
//   }
// }
//
// /// A group of rows sharing the same receipt/transactionRef -> becomes ONE
// /// sales document.
// @immutable
// class SaleGroup {
//   final String receipt;
//   final List<RawSaleRow> rows;
//   const SaleGroup(this.receipt, this.rows);
//
//   RawSaleRow get first => rows.first;
// }
//
// /// Result of matching a row's `mode` text against an item's `modes` map.
// @immutable
// class ModePricing {
//   final double modeQty;
//   final double unitPrice;
//   final String resolvedMode;
//   const ModePricing({
//     required this.modeQty,
//     required this.unitPrice,
//     required this.resolvedMode,
//   });
// }
//
// /// One distinct branch name found while scanning an uploaded file's
// /// `branchId`-equivalent column (branchId / branchName / branch / warehouse).
// ///
// /// [key] is the case/whitespace-insensitive dedupe key ("KASOA WAREHOUSE"
// /// and "Kasoa Warehouse" both fold to the same key) — that's how
// /// [SalesImportService.applyBranchIds] matches a raw file value back to the
// /// branch the user reviewed. [name] and [type] are pre-filled with sane
// /// guesses but are meant to be user-editable before
// /// [SalesImportService.ensureBranchesExist] is called.
// @immutable
// class ExtractedBranch {
//   final String key;
//   final List<String> rawNames;
//   final String name;
//   final String type;
//
//   const ExtractedBranch({
//     required this.key,
//     required this.rawNames,
//     required this.name,
//     required this.type,
//   });
//
//   ExtractedBranch copyWith({String? name, String? type}) => ExtractedBranch(
//     key: key,
//     rawNames: rawNames,
//     name: name ?? this.name,
//     type: type ?? this.type,
//   );
// }
// /// A single row from a stock-movement (supply) legacy export — columns
// /// like cost_price, total, transtype, tname, transmode, barcode, staff,
// /// date, time, paid, payaccount. Same contract as RawSaleRow.
// class RawStockRow {
//   final Map<String, String> cells;
//   const RawStockRow(this.cells);
//
//   String get(String key, [String fallback = '']) {
//     final value = (cells[key] ?? '').trim();
//     return value.isEmpty ? fallback : value;
//   }
// }
//
// /// One reconstructed transaction — the file has no transaction id column,
// /// so rows are grouped by `date|time|staff|tname|transmode` instead.
// class StockGroup {
//   final String key;
//   final List<RawStockRow> rows;
//   const StockGroup(this.key, this.rows);
//
//   RawStockRow get first => rows.first;
// }
//
// /// Result of [SalesImportService.parseStockFile]. `supply` + `opening
// /// balance` rows go to [openingBalanceGroups] (-> stock_transactions),
// /// `supply` + `transfer` rows go to [transferGroups] (-> stock_transfer).
// /// Everything else lands in [unsupportedGroups] and is never written.
//
// // class StockFileParseResult {
// //   final List<StockGroup> openingBalanceGroups;
// //   final List<StockGroup> transferGroups;
// //   final List<StockGroup> unsupportedGroups;
// //   final List<String> missingHeaders;
// //
// //   const StockFileParseResult({
// //     required this.openingBalanceGroups,
// //     required this.transferGroups,
// //     required this.unsupportedGroups,
// //   }) : missingHeaders = const [];
// //
// //   const StockFileParseResult.missingColumns(this.missingHeaders)
// //       : openingBalanceGroups = const [],
// //         transferGroups = const [],
// //         unsupportedGroups = const [];
// //
// //   bool get hasMissingColumns => missingHeaders.isNotEmpty;
// // }
//
//
// class StockFileParseResult {
//   final List<SaleGroup> salesGroups;
//   final List<StockGroup> openingBalanceGroups;
//   final List<StockGroup> transferGroups;
//   final List<StockGroup> unsupportedGroups;
//   final List<String> missingHeaders;
//
//   const StockFileParseResult({
//     required this.salesGroups,
//     required this.openingBalanceGroups,
//     required this.transferGroups,
//     required this.unsupportedGroups,
//   }) : missingHeaders = const [];
//
//   const StockFileParseResult.missingColumns(this.missingHeaders)
//       : salesGroups = const [],
//         openingBalanceGroups = const [],
//         transferGroups = const [],
//         unsupportedGroups = const [];
//
//   bool get hasMissingColumns => missingHeaders.isNotEmpty;
// }


/*
import 'package:flutter/foundation.dart';

/// One row read straight out of the uploaded CSV / Excel file.
///
/// Every known column always exists as a key (filled with '' when the file
/// didn't include it), so `cells[key]` is never actually null — an omitted
/// column reads back as an empty string, not a missing one. Treat blank the
/// same as missing so `fallback` (item lookups, mode defaults, etc.)
/// actually gets used.
@immutable
class RawSaleRow {
  final Map<String, String> cells;
  const RawSaleRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// A group of rows sharing the same receipt/transactionRef -> becomes ONE
/// sales document.
@immutable
class SaleGroup {
  final String receipt;
  final List<RawSaleRow> rows;
  const SaleGroup(this.receipt, this.rows);

  RawSaleRow get first => rows.first;
}

/// Result of matching a row's `mode` text against an item's `modes` map.
@immutable
class ModePricing {
  final double modeQty;
  final double unitPrice;
  final String resolvedMode;
  const ModePricing({
    required this.modeQty,
    required this.unitPrice,
    required this.resolvedMode,
  });
}

/// One distinct branch name found while scanning an uploaded file's
/// `branchId`-equivalent column (branchId / branchName / branch / warehouse).
///
/// [key] is the case/whitespace-insensitive dedupe key ("KASOA WAREHOUSE"
/// and "Kasoa Warehouse" both fold to the same key) — that's how
/// [SalesImportService.applyBranchIds] matches a raw file value back to the
/// branch the user reviewed. [name] and [type] are pre-filled with sane
/// guesses but are meant to be user-editable before
/// [SalesImportService.ensureBranchesExist] is called.
@immutable
class ExtractedBranch {
  final String key;
  final List<String> rawNames;
  final String name;
  final String type;

  const ExtractedBranch({
    required this.key,
    required this.rawNames,
    required this.name,
    required this.type,
  });

  ExtractedBranch copyWith({String? name, String? type}) => ExtractedBranch(
    key: key,
    rawNames: rawNames,
    name: name ?? this.name,
    type: type ?? this.type,
  );
}

/// A single row from a stock-movement / legacy transactions export — columns
/// like cost_price, total, transtype, tname, transmode, branchname, item,
/// quantity, selling_price, barcode, staff, date, time, invoice, tid, paid,
/// payaccount. Same contract as RawSaleRow.
class RawStockRow {
  final Map<String, String> cells;
  const RawStockRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// One reconstructed transaction. Grouped by `tid` when the file has one
/// (the real per-transaction id in this export — multiple line items share
/// the same tid); falls back to `date|time|staff|transmode` for files
/// without a tid column.
class StockGroup {
  final String key;
  final List<RawStockRow> rows;
  const StockGroup(this.key, this.rows);

  RawStockRow get first => rows.first;
}

/// Result of [SalesImportService.parseStockFile].
/// - `transtype == sales` rows -> [salesGroups] (mapped onto SaleGroup and
///   run through the normal sales upload pipeline).
/// - `transtype == supply` + `transmode == opening balance` -> [openingBalanceGroups]
///   (-> stock_transactions).
/// - `transtype == supply` + `transmode == transfer` -> [transferGroups]
///   (-> stock_transfer).
/// - Everything else -> [unsupportedGroups], never written.
/// [extractedBranches] comes from the file's real branch column
/// (`branchname`/`branchid`/`branch`/`warehouse`) across the sales rows —
/// nothing is invented, only what's already in the file.


class StockFileParseResult {
  final List<SaleGroup> salesGroups;
  final List<ExtractedBranch> extractedBranches;
  final List<String> missingHeaders;

  const StockFileParseResult({
    required this.salesGroups,
    this.extractedBranches = const [],
  }) : missingHeaders = const [];

  const StockFileParseResult.missingColumns(this.missingHeaders)
      : salesGroups = const [],
        extractedBranches = const [];

  bool get hasMissingColumns => missingHeaders.isNotEmpty;
}
*/


/*
import 'package:flutter/foundation.dart';

/// One row read straight out of the uploaded CSV / Excel file.
@immutable
class RawSaleRow {
  final Map<String, String> cells;
  const RawSaleRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// A group of rows sharing the same receipt/tid -> becomes ONE sales doc.
@immutable
class SaleGroup {
  final String receipt;
  final List<RawSaleRow> rows;
  const SaleGroup(this.receipt, this.rows);

  RawSaleRow get first => rows.first;
}

/// Result of matching a row's `mode` text against an item's `modes` map.
@immutable
class ModePricing {
  final double modeQty;
  final double unitPrice;
  final String resolvedMode;
  const ModePricing({
    required this.modeQty,
    required this.unitPrice,
    required this.resolvedMode,
  });
}

/// One distinct branch name found while scanning an uploaded file's
/// branch-equivalent column (branchId / branchName / branch / warehouse).
@immutable
class ExtractedBranch {
  final String key;
  final List<String> rawNames;
  final String name;
  final String type;

  const ExtractedBranch({
    required this.key,
    required this.rawNames,
    required this.name,
    required this.type,
  });

  ExtractedBranch copyWith({String? name, String? type}) => ExtractedBranch(
    key: key,
    rawNames: rawNames,
    name: name ?? this.name,
    type: type ?? this.type,
  );
}

/// A single row from a stock/legacy transactions export — columns like
/// cost_price, total, transtype, tname, transmode, branchname, item,
/// quantity, selling_price, barcode, staff, date, time, invoice, tid, paid,
/// payaccount. Same contract as RawSaleRow.
class RawStockRow {
  final Map<String, String> cells;
  const RawStockRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// One reconstructed transaction. Grouped by `tid` when the file has one
/// (multiple line items share it); falls back to
/// `date|time|staff|transmode` for files without a tid column.
class StockGroup {
  final String key;
  final List<RawStockRow> rows;
  const StockGroup(this.key, this.rows);

  RawStockRow get first => rows.first;
}

/// Result of [SalesImportService.parseStockFile]. This page only ever
/// handles sales now: a row is kept if `transtype == "sales"`.
/// [extractedBranches] comes straight from the file's real branch column
/// across the kept rows — nothing invented.
class StockFileParseResult {
  final List<SaleGroup> salesGroups;
  final List<ExtractedBranch> extractedBranches;
  final List<String> missingHeaders;

  const StockFileParseResult({
    required this.salesGroups,
    this.extractedBranches = const [],
  }) : missingHeaders = const [];

  const StockFileParseResult.missingColumns(this.missingHeaders)
      : salesGroups = const [],
        extractedBranches = const [];

  bool get hasMissingColumns => missingHeaders.isNotEmpty;
}

/// Result of [SalesImportService.parseSalesFile] (plain sales CSV/XLSX,
/// not the stock-export layout).
class SalesFileParseResult {
  final List<String> headers;
  final List<RawSaleRow> previewRows;
  final List<SaleGroup> groups;
  final bool autoMapped;
  final List<String> missingHeaders;
  final List<ExtractedBranch> extractedBranches;

  const SalesFileParseResult({
    required this.headers,
    required this.previewRows,
    required this.groups,
    required this.autoMapped,
    this.extractedBranches = const [],
  }) : missingHeaders = const [];

  const SalesFileParseResult.missingColumns(this.missingHeaders)
      : headers = const [],
        previewRows = const [],
        groups = const [],
        autoMapped = false,
        extractedBranches = const [];

  bool get hasMissingColumns => missingHeaders.isNotEmpty;

}
class PickedFileParseResult {
  final SalesFileParseResult? salesResult;
  final StockFileParseResult? stockResult;
  const PickedFileParseResult.sales(this.salesResult) : stockResult = null;
  const PickedFileParseResult.stock(this.stockResult) : salesResult = null;
}
*/

import 'package:flutter/foundation.dart';

/// One row read straight out of the uploaded CSV / Excel file.
@immutable
class RawSaleRow {
  final Map<String, String> cells;
  const RawSaleRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// A group of rows sharing the same receipt/tid -> becomes ONE sales doc.
@immutable
class SaleGroup {
  final String receipt;
  final List<RawSaleRow> rows;
  const SaleGroup(this.receipt, this.rows);

  RawSaleRow get first => rows.first;
}

/// Result of matching a row's `mode` text against an item's `modes` map.
@immutable
class ModePricing {
  final double modeQty;
  final double unitPrice;
  final String resolvedMode;
  const ModePricing({
    required this.modeQty,
    required this.unitPrice,
    required this.resolvedMode,
  });
}

/// One distinct branch name found while scanning an uploaded file's
/// branch-equivalent column (branchId / branchName / branch / warehouse).
@immutable
class ExtractedBranch {
  final String key;
  final List<String> rawNames;
  final String name;
  final String type;

  const ExtractedBranch({
    required this.key,
    required this.rawNames,
    required this.name,
    required this.type,
  });

  ExtractedBranch copyWith({String? name, String? type}) => ExtractedBranch(
    key: key,
    rawNames: rawNames,
    name: name ?? this.name,
    type: type ?? this.type,
  );
}

/// A single row from a stock/legacy transactions export — columns like
/// cost_price, total, transtype, tname, transmode, branchname, item,
/// quantity, selling_price, barcode, staff, date, time, invoice, tid, id,
/// paid, payaccount, sync_status, companyid. Same contract as RawSaleRow.
class RawStockRow {
  final Map<String, String> cells;
  const RawStockRow(this.cells);

  String get(String key, [String fallback = '']) {
    final value = (cells[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}

/// One reconstructed transaction. Grouped by `tid` when the file has one
/// (multiple line items share it); falls back to
/// `date|time|staff|transmode` for files without a tid column.
class StockGroup {
  final String key;
  final List<RawStockRow> rows;
  const StockGroup(this.key, this.rows);

  RawStockRow get first => rows.first;
}

/// Result of [SalesImportService.parseStockFile]. This page only ever
/// handles sales now: a row is kept if `transtype == "sales"`.
/// [extractedBranches] comes straight from the file's real branch column
/// across the kept rows — nothing invented.
class StockFileParseResult {
  final List<SaleGroup> salesGroups;
  final List<ExtractedBranch> extractedBranches;
  final List<String> missingHeaders;

  const StockFileParseResult({
    required this.salesGroups,
    this.extractedBranches = const [],
  }) : missingHeaders = const [];

  const StockFileParseResult.missingColumns(this.missingHeaders)
      : salesGroups = const [],
        extractedBranches = const [];

  bool get hasMissingColumns => missingHeaders.isNotEmpty;
}

/// Result of [SalesImportService.parseSalesFile] (plain sales CSV/XLSX,
/// not the stock-export layout).
class SalesFileParseResult {
  final List<String> headers;
  final List<RawSaleRow> previewRows;
  final List<SaleGroup> groups;
  final bool autoMapped;
  final List<String> missingHeaders;
  final List<ExtractedBranch> extractedBranches;

  const SalesFileParseResult({
    required this.headers,
    required this.previewRows,
    required this.groups,
    required this.autoMapped,
    this.extractedBranches = const [],
  }) : missingHeaders = const [];

  const SalesFileParseResult.missingColumns(this.missingHeaders)
      : headers = const [],
        previewRows = const [],
        groups = const [],
        autoMapped = false,
        extractedBranches = const [];

  bool get hasMissingColumns => missingHeaders.isNotEmpty;
}

class PickedFileParseResult {
  final SalesFileParseResult? salesResult;
  final StockFileParseResult? stockResult;
  const PickedFileParseResult.sales(this.salesResult) : stockResult = null;
  const PickedFileParseResult.stock(this.stockResult) : salesResult = null;
}