import 'package:cloud_firestore/cloud_firestore.dart';

class BankTransferModel {
  String id;
  String amount;

  String branchId;
  String branchName;
  String companyId;
  String staff;

  String? transferAccount;
  String? transferAccountid;
  String? receivingAccount;
  String? receivingAccountid;
  String? narration;
  String? dateymd;

  String? updatedBy;
  String? deletedBy;

  DateTime? date;
  DateTime createdAt;
  DateTime? updatedAt;
  DateTime? deletedAt;

  String? day;
  String? week;
  String? month;
  String? year;

  BankTransferModel({
    required this.id,
    required this.amount,
    required this.branchId,
    required this.branchName,
    required this.companyId,
    required this.staff,
    this.transferAccount,
    this.transferAccountid,
    this.receivingAccount,
    this.receivingAccountid,
    this.narration,
    this.updatedBy,
    this.deletedBy,
    this.date,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.dateymd,

    this.day,
    this.week,
    this.month,
    this.year,
  });

  /// Convert Firestore → Model
  factory BankTransferModel.fromMap(Map<String, dynamic> map) {
    return BankTransferModel(
      id: map['id'] ?? '',
      amount: map['amount']?.toString() ?? '',
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      companyId: map['companyId'] ?? '',
      staff: map['staff'] ?? '',
      transferAccount: map['transferAccount']?? '',
      transferAccountid: map['transferAccountid']?? '',
      receivingAccount: map['receivingAccount']?? '',
      receivingAccountid: map['receivingAccountid']?? '',
      narration: map['narration']?? '',
      dateymd: map['dateymd']?? '',
      updatedBy: map['updatedBy']?? '',
      deletedBy: map['deletedBy']?? '',

      //SAFE DATE CONVERSION
      date: _parseDate(map['date']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']),
      deletedAt: _parseDate(map['deletedAt']),

      day: map['day'] ?? '',
      week: map['week'] ?? '',
      month: map['month'] ?? '',
      year: map['year'] ?? '',
    );
  }

  /// Convert Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'branchId': branchId,
      'branchName': branchName,
      'companyId': companyId,
      'staff': staff,
      'transferAccount': transferAccount,
      'transferAccountid': transferAccountid,
      'receivingAccount': receivingAccount,
      'receivingAccountid': receivingAccountid,
      'narration': narration,
      'dateymd': dateymd,
      'updatedBy': updatedBy,
      'deletedBy': deletedBy,

      // Store as Timestamp automatically
      'date': date,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      'day': day,
      'week': week,
      'month': month,
      'year': year,
    };
  }

  /// handles Timestamp & DateTime safely
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  ///
  BankTransferModel copyWith({
    String? id,
    String? amount,
    String? branchId,
    String? branchName,
    String? companyId,
    String? staff,
    String? transferAccount,
    String? transferAccountid,
    String? receivingAccount,
    String? receivingAccountid,
    String? narration,
    String? dateymd,
    String? updatedBy,
    String? deletedBy,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return BankTransferModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      companyId: companyId ?? this.companyId,
      staff: staff ?? this.staff,
      transferAccount: transferAccount ?? this.transferAccount,
      transferAccountid: transferAccountid ?? this.transferAccountid,
      receivingAccount: receivingAccount ?? this.receivingAccount,
      receivingAccountid: receivingAccountid ?? this.receivingAccountid,
      narration: narration ?? this.narration,
      dateymd: dateymd ?? this.dateymd,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedBy: deletedBy ?? this.deletedBy,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}