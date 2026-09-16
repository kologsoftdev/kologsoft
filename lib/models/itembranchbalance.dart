import 'package:cloud_firestore/cloud_firestore.dart';

class ItemBranchBalance {
  final String branchId;
  final String name;
  final int netpieces;
  final int quantity;
  final int stockValue;
  final int salesValue;
  final int stockinPieces;
  final int stockoutPieces;
  final int stockoutQty;
  final int receivedPieces;
  final int receivedQuantity;
  final String updatedBy;
  final DateTime? lastUpdate;

  ItemBranchBalance({
    required this.branchId,
    required this.name,
    required this.netpieces,
    required this.quantity,
    required this.stockValue,
    required this.salesValue,
    required this.stockinPieces,
    required this.stockoutPieces,
    required this.stockoutQty,
    required this.receivedPieces,
    required this.receivedQuantity,
    required this.updatedBy,
    required this.lastUpdate,
  });

  factory ItemBranchBalance.fromMap(String branchId, Map<String, dynamic> map) {
    return ItemBranchBalance(
      branchId: branchId,
      name: map['name']?.toString() ?? '',
      netpieces: map['netpieces'] ?? 0,
      quantity: map['quantity'] ?? 0,
      stockValue: map['stock_value'] ?? 0,
      salesValue: map['sales_value'] ?? 0,
      stockinPieces: map['stockin_pieces'] ?? 0,
      stockoutPieces: map['stockout_pieces'] ?? 0,
      stockoutQty: map['stockout_qty'] ?? 0,
      receivedPieces: map['receivedpieces'] ?? 0,
      receivedQuantity: map['receivedquantity'] ?? 0,
      updatedBy: map['updatedby']?.toString() ?? '',
      lastUpdate: map['lastupdate'] is Timestamp
          ? (map['lastupdate'] as Timestamp).toDate()
          : map['lastupdate'] is DateTime ? map['lastupdate'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'netpieces': netpieces,
      'quantity': quantity,
      'stock_value': stockValue,
      'sales_value': salesValue,
      'stockin_pieces': stockinPieces,
      'stockout_pieces': stockoutPieces,
      'stockout_qty': stockoutQty,
      'receivedpieces': receivedPieces,
      'receivedquantity': receivedQuantity,
      'updatedby': updatedBy,
      'lastupdate': lastUpdate != null ? Timestamp.fromDate(lastUpdate!) : null,
    };
  }
}