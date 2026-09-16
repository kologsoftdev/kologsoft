import 'package:cloud_firestore/cloud_firestore.dart';

class addTaxVatModel {
  String id;

  String vattype;
  double vatrate;
  double vatgetfund;
  double nhil;
  double covid19;

  // Company info
  String companyid;
  String companyemail;

  // Audit
  String updatedby;
  String deletedby;
  String staff;

  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;

  addTaxVatModel({
    required this.id,

    required this.vattype,
    required this.vatrate,
    required this.vatgetfund,
    required this.nhil,
    required this.covid19,

    this.companyid = '',
    this.companyemail = '',
    this.updatedby = '',
    this.deletedby = '',
    this.staff = '',
    this.date,
    this.updatedat,
    this.deletedat,
  });

  ///  Convert to Firestore
  Map<String, dynamic> toMap() {
    return {
       'id':id,
      'vattype': vattype,
      'vatrate': vatrate,
      'vatgetfund': vatgetfund,
      'nhil': nhil,
      'covid19': covid19,

      'companyid': companyid,
      'companyemail': companyemail,
      'updatedby': updatedby,
      'deletedby': deletedby,
      'staff': staff,

      'date': date != null ? Timestamp.fromDate(date!) : null,
      'updatedat': updatedat != null ? Timestamp.fromDate(updatedat!) : null,
      'deletedat': deletedat != null ? Timestamp.fromDate(deletedat!) : null,
    };
  }


  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;

    return null;
  }

  /// From JSON / Firestore Map
  factory addTaxVatModel.fromJson(Map<String, dynamic> json) {
    return addTaxVatModel(
      id: json['id'] ?? '',

      vattype: json['vattype'] ?? '',
      vatrate: (json['vatrate'] ?? 0).toDouble(),
      vatgetfund: (json['vatgetfund'] ?? 0).toDouble(),
      nhil: (json['nhil'] ?? 0).toDouble(),
      covid19: (json['covid19'] ?? 0).toDouble(),

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


  factory addTaxVatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return addTaxVatModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}