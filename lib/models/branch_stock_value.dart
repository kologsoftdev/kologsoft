
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboardStats.dart';

class BranchStockItem {
  final String branchName;
  final double stockValue;

  BranchStockItem({
    required this.branchName,
    required this.stockValue,
  });

  factory BranchStockItem.fromMap(Map<String, dynamic> map) {
    return BranchStockItem(
      branchName: map['branchname'] ?? '',
      stockValue: (map['stock_value'] as num?)?.toDouble() ?? 0.00 );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchname': branchName,
      'stock_value': stockValue,
    };
  }
}

class BranchStock {
  final String companyId;
  final double stockInTotal;
  final DateTime updatedAt;
  final Map<String, BranchStockItem> branches;

  BranchStock({
    required this.companyId,
    required this.stockInTotal,
    required this.updatedAt,
    required this.branches,
  });

  factory BranchStock.fromMap(Map<String, dynamic> map) {
    final branchesMap = <String, BranchStockItem>{};

    final branchData = map['branchstock'] as Map<String, dynamic>?;

    if (branchData != null) {
      branchData.forEach((key, value) {
        branchesMap[key] = BranchStockItem.fromMap(value);
      });
    }

    return BranchStock(
      companyId: map['companyId'] ?? '',
      stockInTotal: (map['stock_in_total'] as num?)?.toDouble() ?? 0.0,
      updatedAt: (map['updatedAt'] is Timestamp)
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      branches: branchesMap,
    );
  }
  /// Convert to list of maps like your feedback example
  List<Map<String, dynamic>> toListFormat() {
    return branches.entries.map((entry) {
      final item = entry.value;
      return {
        'branch': item.branchName,
        'stock': item.stockValue,
        'companyId': companyId,
        'stock_in_total': stockInTotal,
        'updatedAt': updatedAt.toIso8601String(),
      };
    }).toList();
  }
}

class DashboardDocument {
  final DashboardStats stats;
  final BranchStock stock;
  final Map<String, dynamic> raw;

  DashboardDocument({
    required this.stats,
    required this.stock,
    required this.raw,
  });

  factory DashboardDocument.fromFirestore(
      Map<String, dynamic> data,
      String branchId,
      ) {
    return DashboardDocument(
      stats: DashboardStats(
        companySalesValue:
        (data['companysales_value'] as num?)?.toDouble() ?? 0,
        companyExpenseValue:
        (data['expense_total'] as num?)?.toDouble() ?? 0,
        branchSalesValue:
        (Map<String, dynamic>.from(data['branchSummary'] ?? {})[branchId]
        ?['branchsales_value'] as num?)
            ?.toDouble() ??
            0,
        branchExpenseValue:
        (Map<String, dynamic>.from(data['branchexpense'] ?? {})[branchId]
        ?['expense_value'] as num?)
            ?.toDouble() ??
            0, companyCash: 0, companyCard: 0, companyCredit: 0, companyMomo: 0, companyBankTransfer: 0, branchCash: 0, branchCard: 0, branchCredit: 0, branchMomo: 0, branchBankTransfer: 0, companyStockValue: 0, branchStockValue: 0, companyopening_credit_bal: 0, branchopening_credit_bal: 0, smsBalance: 0, companyDiscount: 0, branchDiscount: 0, companydebtpay_momo: 0, branchdebtpay_momo: 0,
      ),
      stock: BranchStock.fromMap(data),
      raw: data,
    );
  }
}
