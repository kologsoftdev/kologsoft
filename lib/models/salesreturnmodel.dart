import 'package:cloud_firestore/cloud_firestore.dart';

class salereturn {
  final String companyid;
  final String receiptid;
  final String id;
  final String branchid;
  final String branchname;
  final int staffposition;
  final Timestamp salesreturn;
  final Map<String, dynamic> items;
  final int itemcount;
  final Timestamp createdat;
  final String createdby;
  final String pricingtype;
  final String approvedby;
  final String? printedby;
  final String? dateymd;
  final Timestamp? printedat;

  salereturn({
    required this.companyid,
    required this.receiptid,
    required this.id,
    required this.branchid,
    required this.branchname,
    required this.staffposition,
    required this.salesreturn,
    required this.items,
    required this.itemcount,
    required this.createdat,
    required this.createdby,
    required this.pricingtype,
    required this.approvedby,
    this.printedby,
    this.printedat,
    this.dateymd,
  });

  Map<String, dynamic> tomap() {
    return {
      'returned_companyid': companyid,
      'returned_receiptid': receiptid,
      'returned_id': id,
      'returned_branchid': branchid,
      'returned_branchname': branchname,
      'returned_staffposition': staffposition,
      'salesreturn': salesreturn,
      'returned_items': items,
      'returned_itemcount': itemcount,
      'returned_createdat': createdat,
      'returned_createdby': createdby,
      'returned_pricingtype': pricingtype,
      'returned_approvedby': approvedby,
      'returned_printedby': printedby,
      'returned_printedat': printedat,
      'returned_dateymd': dateymd,
      'dateymd': dateymd,
    };
  }

  factory salereturn.fromfirestore(
      Map<String, dynamic> map,
      String docid,
      ) {
    return salereturn(
      id: docid,
      companyid: map['returned_companyid']?.toString() ?? '',
      receiptid: map['returned_receiptid']?.toString() ?? '',
      branchid: map['returned_branchid']?.toString() ?? '',
      dateymd: map['dateymd']?.toString(),
      branchname: map['returned_branchname']?.toString() ?? '',
      staffposition: (map['returned_staffposition'] as num?)?.toInt() ?? 0,
      salesreturn: map['returned_salesreturn'] != null
          ? map['returned_salesreturn'] as Timestamp
          : Timestamp.now(),  // fallback if null
      items: Map<String, dynamic>.from(map['returned_items'] ?? {}),
      itemcount: (map['returned_itemcount'] as num?)?.toInt() ?? 0,
      createdat: map['returned_createdat'] != null
          ? map['returned_createdat'] as Timestamp
          : Timestamp.now(),
      createdby: map['returned_createdby']?.toString() ?? '',
      pricingtype: map['returned_pricingtype']?.toString() ?? '',
      approvedby: map['returned_approvedby']?.toString() ?? '',
      printedby: map['returned_printedby']?.toString(),
      printedat: map['returned_printedat'] != null ? map['returned_printedat'] as Timestamp : null,

    );
  }
}
