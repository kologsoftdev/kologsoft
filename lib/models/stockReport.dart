
import 'dart:ui';

class StockItem {
  final String id;
  final String name;
  final String barcode;
  final String? boxqty;
  final Map<String, dynamic>? branchBalance;
  final Map<String, dynamic>? dailybranchbalance;
  final DateTime lastUpdate;
  final int netPieces;
  final double quantity;
  final double? newstock;
  final double salesValue;
  final int stockValue;
  final int stockinPieces;
  final int stockoutPieces;
  final int stockoutQty;
  final String? updatedBy;
  final String company;
  final String companyId;
  final String cp;
  final DateTime createdAt;
  final String? imageUrl;
  final String? lastDamageId;
  final DateTime lastModified;
  final String? lastSaleId;
  final String? lastSalesReturnId;
  final String? lastStockRequestId;
  final String? lastStockTransactionId;
  final String? lastStockTransferId;
  final Map<String, dynamic>? modes;
  final String? openingStock;
  final String pcategory;
  final double? available_balance;
  final double? transfer_qty;
  final double? purchaseReturn_qty;
  final double? salesReturn_qty;
  final double? sales_qty;

  StockItem({
    required this.id,
    required this.name,
    required this.barcode,
    this.boxqty,
    this.branchBalance,
    this.dailybranchbalance,
    required this.lastUpdate,
    required this.netPieces,
    required this.quantity,
     this.newstock,
    required this.salesValue,
    required this.stockValue,
    required this.stockinPieces,
    required this.stockoutPieces,
    required this.stockoutQty,
    this.updatedBy,
    required this.company,
    required this.companyId,
    required this.cp,
    required this.createdAt,
    this.imageUrl,
    this.lastDamageId,
    required this.lastModified,
    this.lastSaleId,
    this.lastSalesReturnId,
    this.lastStockRequestId,
    this.lastStockTransactionId,
    this.lastStockTransferId,
    this.modes,
    this.openingStock,
    required this.pcategory,
    this.available_balance,
    this.transfer_qty,
    this.purchaseReturn_qty,
    this.salesReturn_qty,
    this.sales_qty,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      barcode: json['barcode'] ?? '',
      boxqty: json['boxqty'],
      branchBalance: json['branchbalance'] != null ? Map<String, dynamic>.from(json['branchbalance']) : null,
      dailybranchbalance: json['branchbalance'] != null ? Map<String, dynamic>.from(json['branchbalance']) : null,
      lastUpdate: _parseDateTime(json['lastupdate']),
      netPieces: json['netpieces'] ?? 0,
      quantity: (json['quantity'] ?? 0).toDouble(),
      newstock: (json['newstock'] ?? 0).toDouble(),
      sales_qty: (json['sales_qty'] ?? 0).toDouble(),
      available_balance: (json['available_balance'] ?? 0).toDouble(),
      transfer_qty: (json['transfer_qty'] ?? 0).toDouble(),
      purchaseReturn_qty: (json['purchaseReturn_qty'] ?? 0).toDouble(),
      salesReturn_qty: (json['salesReturn_qty'] ?? 0).toDouble(),
      salesValue: (json['sales_value'] ?? 0).toDouble(),
      stockValue: json['stock_value'] ?? 0,
      stockinPieces: json['stockin_pieces'] ?? 0,
      stockoutPieces: json['stockout_pieces'] ?? 0,
      stockoutQty: json['stockout_qty'] ?? 0,
      updatedBy: json['updatedby'],
      company: json['company'] ?? '',
      companyId: json['companyid'] ?? '',
      cp: json['cp'] ?? '',
      createdAt: _parseDateTime(json['createdat']),
      imageUrl: json['imageurl'],
      lastDamageId: json['lastDamageId'],
      lastModified: _parseDateTime(json['lastModified']),
      lastSaleId: json['lastSaleId'],
      lastSalesReturnId: json['lastSalesReturnId'],
      lastStockRequestId: json['lastStockRequestId'],
      lastStockTransactionId: json['lastStockTransactionId'],
      lastStockTransferId: json['lastStockTransferId'],
      modes: json['modes'] != null ? Map<String, dynamic>.from(json['modes']) : null,
      openingStock: json['openingstock'],
      pcategory: json['pcategory'] ?? 'Uncategorized',
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> getBranchData(String branchid) {

    // FIRST: dailytransactions
    final dailyBranch =
    dailybranchbalance?[branchid];

    if (dailyBranch != null) {
      return dailyBranch;
    }

    final branch = branchBalance?[branchid];
    if (branch != null) {
      return branch;
    }
    return {
      'netpieces': 0,
      'quantity': 0,
      'stock_value': 0,
      'stockin_pieces': 0,
      'stockout_pieces': 0,
      'receivedpieces': 0,
      'newstock':0,
      'available_balance':0,
      'transfer_qty':0,
      'salesReturn_qty':0,
      'sales_qty':0
    };
  }

}

class AppColors {
  static const Color background = Color(0xFF0F172A); // 🔥 slightly richer dark (less flat)
  static const Color surface = Color(0xFF1E293B);    // 🔥 better elevation contrast
  static const Color surfaceLight = Color(0xFF273449);

  static const Color primary = Color(0xFF6366F1);     // 🔥 slightly brighter (better on dark)
  static const Color primaryLight = Color(0xFF818CF8); // softer highlight

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFFF9FAFB); // 🔥 cleaner white
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF64748B);   // 🔥 less dull

  static const Color border = Color(0xFF334155);
  static const Color cardBorder = Color(0xFF2F3A4F);
}
