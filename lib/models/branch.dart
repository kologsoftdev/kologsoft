// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class BranchModel {
//   String id = '';
//   String branchname;
//   String branchtype;
//   String branchcontact;
//   String companyid;
//   String companyemail;
//   String updatedby;
//   String deletedby;
//   DateTime? date;
//   DateTime? updatedat;
//   DateTime? deletedat;
//   String staff;
//
//
//   BranchModel({
//     this.id = '',
//     this.branchname = '',
//     this.branchtype = '',
//     this.branchcontact = '',
//     this.updatedby = '',
//     this.deletedby = '',
//     this.staff = '',
//     this.companyid = '',
//     this.companyemail = '',
//     this.date,
//     this.updatedat,
//     this.deletedat
// });
//
//   Map<String, dynamic> toMap (){
//     return {
//       'id': id,
//       'branchname': branchname,
//       'branchtype': branchtype,
//       'branchcontact': branchcontact,
//       'updatedby': updatedby,
//       'deletedby': deletedby,
//       'staff': staff,
//       'companyid': companyid,
//       'companyemail': companyemail,
//       'date': date,
//       'updatedat': updatedat?.toIso8601String(),
//       'deletedat': deletedat?.toIso8601String(),
//     };
//   }
//   factory BranchModel.fromJson(Map<String, dynamic> json) {
//     return BranchModel(
//       id: json['id'] ?? '',
//       branchname: json['branchname'] ?? '',
//       branchtype: json['branchtype'] ?? '',
//       updatedby: json['updatedby'] ?? '',
//       deletedby: json['deletedby'] ?? '',
//       branchcontact: json['branchcontact'] ?? '',
//       staff: json['staff'] ?? '',
//       companyid: json['companyid'] ?? '',
//       companyemail: json['companyemail'] ?? '',
//       date: json['date'] != null  ? (json['date'] as Timestamp).toDate() : null,
//       updatedat: json['updatedat'] != null ? DateTime.parse(json['updatedat']) : null,
//       deletedat: json['deletedat'] != null ? DateTime.parse(json['deletedat']) : null,
//     );
//   }
//
// }
import 'package:cloud_firestore/cloud_firestore.dart';

class BranchModel {
  String id;
  String branchname;
  String branchtype;
  String address;
  String branchcontact;
  String companyid;
  String companyemail;
  String updatedby;
  String deletedby;
  String staff;

  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;

  BranchModel({
    this.id = '',
    this.branchname = '',
    this.branchtype = '',
    this.branchcontact = '',
    this.address = '',
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
      'branchname': branchname,
      'branchtype': branchtype,
      'branchcontact': branchcontact,
      'address': address,
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

  /// Convert JSON → Model
  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] ?? '',
      branchname: json['branchname'] ?? '',
      branchtype: json['branchtype'] ?? '',
      branchcontact: json['branchcontact'] ?? '',
      address: json['address'] ?? '',
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

  /// Firestore Document → Model
  factory BranchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BranchModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}