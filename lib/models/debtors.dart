import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Payment {
  final String id;
  final double amount;
  final String account;
  final DateTime createdat;
  final String reference;
  final String paymentMethod;
  final String customerid;
  final String customername;
  final String companyid;
  final String companyname;
  final String createdby;
  final String contact;
  final double runningbalance;
  Payment({
    required this.id,
    required this.amount,
    required this.account,
    required this.createdat,
    required this.reference,
    required this.paymentMethod,
    required this.customerid,
    required this.customername,
    required this.companyid,
    required this.companyname,
    required this.createdby,
    required this.contact,
    required this.runningbalance,
  });

  Payment copyWith({
    String? id,
    double? amount,
    String? account,
    DateTime? createdat,
    String? reference,
    String? paymentMethod,
    String? customerid,
    String? customername,
    String? companyid,
    String? companyname,
    String? createdby,
    String? contact,
    double? runningbalance,
  }) {
    return Payment(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      createdat: createdat ?? this.createdat,
      reference: reference ?? this.reference,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerid: customerid ?? this.customerid,
      customername: customername ?? this.customername,
      companyid: companyid ?? this.companyid,
      companyname: companyname ?? this.companyname,
      createdby: createdby ?? this.createdby,
      contact: contact ?? this.contact,
      runningbalance: runningbalance ?? this.runningbalance,
    );
  }
  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      runningbalance: (json['balance'] is num) ? (json['balance'] as num).toDouble() : double.tryParse(json['balance']?.toString() ?? '0') ?? 0,
      account: json['account'] ?? '',
      createdat: json['createdat'] != null ? (json['createdat'] as Timestamp).toDate() : DateTime.now(),
      reference: json['reference'] ?? '',
      paymentMethod: json['paymentmethod'] ?? '',
      customerid: json['customerid'] ?? '',
      customername: json['customername'] ?? '',
      companyid: json['companyid'] ?? '',
      companyname: json['companyname'] ?? '',
      createdby: json['createdby'] ?? '',
      contact: json['contact'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'account': account,
      'createdat': createdat,
      'reference': reference,
      'paymentmethod': paymentMethod,
      'customerid': customerid,
      'customername': customername,
      'companyid': companyid,
      'companyname': companyname,
      'createdby': createdby,
      'contact': contact,
      'balance': runningbalance,
    };
  }
}

class Debtor {
  final String id;
  final String name;
  final String contact;
  final String branchId;
  final String branchName;
  final String companyId;
  final String companyName;
  final String customerType;
  final String paymentDuration;
  final String staff;
  final double creditBalance;
  final double amountpaid;
  final String creditLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? updatedBy;
  final String? deletedBy;
  final String staffemail;

  List<Payment>? payments;
  Debtor({
    required this.id,
    required this.name,
    required this.contact,
    required this.branchId,
    required this.branchName,
    required this.companyId,
    required this.companyName,
    required this.customerType,
    required this.paymentDuration,
    required this.staff,
    required this.creditBalance,
    required this.creditLimit,
     required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.updatedBy,
    this.deletedBy,
    this.payments,
    required this.amountpaid,
    required this.staffemail,
  });


  double get balance {
    return (creditBalance) - (amountpaid);
  }

  double get paymentProgress {
    if (creditBalance == 0) return 0;
    return (amountpaid! / creditBalance).clamp(0.0, 1.0);
  }

  String get status {
    if (balance <= 0) return 'Paid';
    if (amountpaid == 0) return 'Unpaid';
    return 'Partial';
  }

  Color get statusColor {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Partial':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
  factory Debtor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime? _parseFirestoreDate(dynamic value) {
      if (value == null) return null;

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        return DateTime.tryParse(value);
      }

      return null;
    }
    return Debtor(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      branchId: data['branchid'] ?? '',
      branchName: data['branchname'] ?? '',
      companyId: data['companyid'] ?? '',
      companyName: data['companyname'] ?? '',
      customerType: data['customertype'] ?? '',
      paymentDuration: data['paymentduration'] ?? '',
      staff: data['staff'] ?? '',
      creditBalance: (data['creditBalance'] is num)
          ? (data['creditBalance'] as num).toDouble()
          : double.tryParse(data['creditBalance']?.toString() ?? '0') ?? 0,
      creditLimit: (data['creditlimit'] ?? '').toString(),
      createdAt:_parseFirestoreDate(data['createdat']),
      updatedAt: _parseFirestoreDate(data['updatedat']),
      //updatedAt: data['updatedat'] != null ? (data['updatedat'] as Timestamp).toDate() : null,
      deletedAt: _parseFirestoreDate(data['deletedat']),
      //deletedAt: data['deletedat'] != null ? (data['deletedat'] as Timestamp).toDate() : null,
      updatedBy: data['updatedby'],
      deletedBy: data['deletedby'],
      amountpaid: (data['amountpaid'] is num)
          ? (data['amountpaid'] as num).toDouble()
          : double.tryParse(data['amountpaid']?.toString() ?? '0') ?? 0,
      staffemail:data['staffemail'] ??'system',

    );
  }
  Debtor copyWith({
    double? amountpaid,
    String? creditLimit,
    double? creditBalance,
    List<Payment>? payments,
    DateTime? createdAt,
  }) {
    return Debtor(
      id: id,
      name: name,
      contact: contact,
      paymentDuration: paymentDuration,
      creditBalance: creditBalance ?? this.creditBalance,
      payments: payments ?? this.payments,
      createdAt: createdAt ?? this.createdAt,
      branchId: branchId,
      branchName: branchName,
      companyId: companyId,
      companyName:companyName,
      customerType:customerType,
      staff: staff,
      creditLimit: creditLimit ?? this.creditLimit,
      amountpaid: amountpaid!,
      staffemail: staffemail,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'branchid': branchId,
      'branchname': branchName,
      'companyid': companyId,
      'companyname': companyName,
      'customertype': customerType,
      'paymentduration': paymentDuration,
      'staff': staff,
      'creditBalance': creditBalance,
      'creditlimit': creditLimit.toString(), // keep DB format
      'createdat': createdAt,
      'updatedat': updatedAt,
      'deletedat': deletedAt,
      'updatedby': updatedBy,
      'deletedby': deletedBy,
      'staffemail': staffemail,
    };
  }
}
