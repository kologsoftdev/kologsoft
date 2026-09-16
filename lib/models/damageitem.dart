import 'package:cloud_firestore/cloud_firestore.dart';

class damageitemmodel {
  final String id;
  final String companyid;
  final String company;

  final String itemcount;
  final Map<String, dynamic> item;
  final String branchid;
  final String branchname;

  final String description;

  final String createdby;
  final DateTime createdat;

  final String? updatedby;
  final DateTime? updatedat;

  final String? deletedby;
  final DateTime? deletedat;
  final String? staffposition;
  final String? dateymd;
  final String? grandtotal;
  final String? trxid;

  damageitemmodel({
    required this.id,
    required this.itemcount,
    required this.item,
    required this.branchid,
    required this.branchname,
    required this.description,
    required this.createdby,
    required this.createdat,
    this.updatedby,
    this.updatedat,
    this.deletedby,
    this.deletedat,
    this.staffposition,
    this.dateymd,
    this.grandtotal,
    required this.companyid,
    required this.company,
    this.trxid,
  });

  /// Convert to Firestore Map (store DateTime as Timestamp)
  Map<String, dynamic> tomap() {
    return {
      'itemcount': itemcount,
      'item': item,
      'id':id,
      'branchid': branchid,
      'branchname': branchname,
      'companyid': companyid,
      'company': company,
      'description': description,
      'createdby': createdby,
      'createdat': Timestamp.fromDate(createdat),
      'updatedby': updatedby,
      'updatedat': updatedat != null ? Timestamp.fromDate(updatedat!) : null,
      'deletedby': deletedby,
      'deletedat': deletedat != null ? Timestamp.fromDate(deletedat!) : null,
      'staffposition': staffposition,
      'dateymd': dateymd,
      'grandtotal': grandtotal,
      'trxid': trxid,
    };
  }

  /// Create model from Firestore (convert Timestamp to DateTime)
  factory damageitemmodel.fromfirestore(
      Map<String, dynamic> map, String docid) {
    return damageitemmodel(
      id: docid,
      trxid: map['trxid'] ?? '',
      itemcount: map['itemcount'] ?? '',
      item: Map<String, dynamic>.from(map['item'] ?? {}),
      branchid: map['branchid'] ?? '',
      branchname: map['branchname'] ?? '',
      description: map['description'] ?? '',
      createdby: map['createdby'] ?? '',
      createdat: map['createdat'] != null
          ? (map['createdat'] as Timestamp).toDate()
          : DateTime.now(),
      updatedby: map['updatedby'],
      updatedat: map['updatedat'] != null
          ? (map['updatedat'] as Timestamp).toDate()
          : null,
      deletedby: map['deletedby'],
      deletedat: map['deletedat'] != null
          ? (map['deletedat'] as Timestamp).toDate()
          : null,
      staffposition: map['staffposition'] ?? '',
      companyid: map['companyid'] ?? '',
      company: map['company'] ?? '',
      dateymd: map['dateymd'] ?? '',
      grandtotal: map['grandtotal'] ?? '',
    );
  }
}