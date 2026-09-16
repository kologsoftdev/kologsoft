import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String id;
  final String supplier;
  final String contact;
  final String company;
  final String staff;
  final String companyid;
  final String? branchid;
  final Timestamp datecreated;
  final String?debitaccount;
  final String?creditaccount;

  Supplier({
    required this.id,
    required this.supplier,
    required this.staff,
    required this.contact,
    required this.company,
    required this.companyid,
    required this.datecreated,
    this.creditaccount ='0',
    this.debitaccount ='0',
    this.branchid,
  });

  // Convert
  Map<String, dynamic> toMap() => {
    'id': id,
    'staff': staff,
    'supplier': supplier,
    'contact': contact,
    'company': company,
    'companyid': companyid,
    'datecreated': datecreated,
    'creditaccount': creditaccount,
    'debitaccount': debitaccount,
    'branchid': branchid,
  };

  // Create object from Firestore Map
  factory Supplier.fromMap(
      Map<String, dynamic> map,
      String id) => Supplier(
    id: id,
    staff: map['staff'] ?? '',
    supplier: map['supplier'] ?? '',
    contact: map['contact'] ?? '',
    company: map['company'] ?? '',
    companyid: map['companyid'] ?? '',
    datecreated: map['datecreated'] ?? Timestamp.now(),
    creditaccount: map['creditaccount']?.toString()??'0',
    debitaccount: map['debitaccount']?.toString()??'0',
    branchid: map['branchid']?? '',
  );
}
class SMSCONFIG {
  final String id;
  final String senderid;
  final String key;
  final String company;
  final String staff;
  final String companyid;
  final Timestamp datecreated;
  final String? provider;

  SMSCONFIG({
    required this.id,
    required this.senderid,
    required this.key,
    required this.company,
    required this.staff,
    required this.companyid,
    required this.datecreated,
    required this.provider,
  });

  // Convert
  Map<String, dynamic> toMap() => {
    'id': id,
    'staff': staff,
    'senderid': senderid,
    'key': key,
    'company': company,
    'companyid': companyid,
    'datecreated': datecreated,
    'provider': provider,
  };

  // Create object from Firestore Map
  factory SMSCONFIG.fromMap(
      Map<String, dynamic> map,
      String id) => SMSCONFIG(
    id: id,
    staff: map['staff'] ?? '',
    senderid: map['senderid'] ?? '',
    key: map['key'] ?? '',
    company: map['company'] ?? '',
    companyid: map['companyid'] ?? '',
    datecreated: map['datecreated'] ?? Timestamp.now(),
    provider: map['provider'] ?? 'kologsoft',
  );
}
