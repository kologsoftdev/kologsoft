import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerRegModel {
  String id;
  String branchname;
  String branchid;
  String? amountpaid;
  String name;
  String? namelower;
  String contact;
  String customertype;
  String? creditlimit;
  String? paymentduration;
  String companyid;
  String companyname;
  DateTime date;
  String? updatedby;
  DateTime? updatedat;
  String? deletedby;
  DateTime? deletedat;
  String staff;
  String? creditBalance;

  CustomerRegModel({
    required this.id,
    required this.branchname,
    required this.branchid,
    required this.name,
     this.namelower,
    required this.contact,
    required this.customertype,
    this.creditlimit,
    this.paymentduration,
    required this.companyid,
    required this.companyname,
    required this.date,
    this.updatedby,
    this.updatedat,
    this.deletedby,
    this.deletedat,
    required this.staff,
    this.creditBalance,
    this.amountpaid='0',
  });

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'branchname': branchname,
      'branchid': branchid,
      'id': id,
      'name': name,
      'namelower': name.toLowerCase(),
      'contact': contact,
      'customertype': customertype,
      'creditlimit': creditlimit,
      'paymentduration': paymentduration,
      'companyid': companyid,
      'companyname': companyname,
      'date': date,
      'updatedby': updatedby,
      'updatedat': updatedat,
      'deletedby': deletedby,
      'deletedat': deletedat,
      'staff': staff,
      'createdat': DateTime.now(),
      'creditBalance': creditBalance,
      'amountpaid': amountpaid,
    };
  }

  // Factory to safely parse Firestore map
  factory CustomerRegModel.fromMap(Map<String, dynamic> json, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    String? parseString(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    return CustomerRegModel(
      id: id,
      branchname: parseString(json['branchname']) ?? '',
      branchid: parseString(json['branchid']) ?? '',
      name: parseString(json['name']) ?? '',
      namelower: parseString(json['namelower']) ?? '',
      contact: parseString(json['contact']) ?? '',
      customertype: parseString(json['customertype']) ?? '',
      creditlimit: parseString(json['creditlimit']),
      paymentduration: parseString(json['paymentduration']),
      companyid: parseString(json['companyid']) ?? '',
      companyname: parseString(json['companyname']) ?? '',
      date: parseDate(json['date']),
      updatedby: parseString(json['updatedby']),
      updatedat: parseDate(json['updatedat']),
      deletedby: parseString(json['deletedby']),
      deletedat: parseDate(json['deletedat']),
      staff: parseString(json['staff']) ?? '',
      creditBalance: parseString(json['creditBalance']),
      amountpaid:  parseString(json['amountpaid']),
    );
  }
}