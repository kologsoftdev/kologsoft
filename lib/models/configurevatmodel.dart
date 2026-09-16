
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigureVatModel {
  String id;
  String producttype;
  String vatrate;
  String computationalmethod;
  String companyid;
  String companyemail;
  String updatedby;
  String deletedby;
  String staff;
  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;

  ConfigureVatModel({
    required this.id ,
    required this.producttype ,
    required this.vatrate ,
    required this.computationalmethod ,
    this.companyid = '',
    this.companyemail = '',
    this.updatedby = '',
    this.deletedby = '',
    this.staff = '',
    this.date,
    this.updatedat,
    this.deletedat,
  });

  /// Convert to Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producttype': producttype,
      'vatrate': vatrate,
      'computationalmethod': computationalmethod,
      'companyid': companyid,
      'companyemail': companyemail,
      'updatedby': updatedby,
      'deletedby': deletedby,
      'staff': staff,
      'date': date,
      'updatedat': updatedat,
      'deletedat': deletedat,
    };
  }


  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  /// Convert JSON  Model
  factory ConfigureVatModel.fromJson(Map<String, dynamic> json) {
    return ConfigureVatModel(
      id: json['id'] ?? '',
      producttype: json['producttype'] ?? '',
      vatrate: json['vatrate'] ?? '',
      computationalmethod: json['computationalmethod'] ?? '',
      companyid: json['companyid'] ?? '',
      companyemail: json['companyemail'] ?? '',
      updatedby: json['updatedby'] ?? '',
      deletedby: json['deletedby'] ?? '',
      staff: json['staff'] ?? '',

      date: _parseDate(json['date']),
      updatedat: _parseDate(json['updatedat']),
      deletedat: _parseDate(json['deletedat']),

    );
  }

  /// Firestore Document  Model
  factory ConfigureVatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConfigureVatModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}