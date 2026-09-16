// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:hive/hive.dart';
//
// import 'branchpricingmodel.dart';
// import 'itembranchbalance.dart';
// import 'itemmodel.dart';
//
//
// @HiveType(typeId: 0)
// class ItemModeltry extends HiveObject {
//   @HiveField(0)
//   final String id;
//   @HiveField(1)
//   final String name;
//   @HiveField(2)
//   final String barcode;
//   @HiveField(3)
//   final String cp;
//   @HiveField(4)
//   final String retailmarkup;
//   @HiveField(5)
//   final String wholesalemarkup;
//   @HiveField(6)
//   final String retailprice;
//   @HiveField(7)
//   final String wholesaleprice;
//   @HiveField(8)
//   final String producttype;
//   @HiveField(9)
//   final bool pricingmode;
//   @HiveField(10)
//   final String pcategory;
//   @HiveField(11)
//   final String warehouse;
//   @HiveField(12)
//   final String openingstock;
//   @HiveField(13)
//   final String company;
//   @HiveField(14)
//   final String companyid;
//   @HiveField(15)
//   final DateTime createdat;
//   @HiveField(16)
//   final DateTime? updatedat;
//   @HiveField(17)
//   final String? updatedby;
//   @HiveField(18)
//   final String imageurl;
//   @HiveField(19)
//   final List <Mode>? modes;
//   @HiveField(20)
//   final String wminqty;
//   @HiveField(21)
//   final String sminqty;
//   @HiveField(22)
//   final String staff;
//   @HiveField(23)
//   final bool modemore;
//   @HiveField(24)
//   final DateTime? deletedat;
//   @HiveField(25)
//   final String? deletedby;
//   @HiveField(26)
//   final List <BranchPricingModel>? branchprices;
//   @HiveField(27)
//   final List<ItemBranchBalance>? branchbalance;
//   @HiveField(28)
//   final String? boxqty;
//   ItemModeltry({
//     required this.id,
//     required this.name,
//     required this.barcode,
//     required this.cp,
//     required this.retailmarkup,
//     required this.wholesalemarkup,
//     required this.retailprice,
//     required this.wholesaleprice,
//     required this.producttype,
//     this.pricingmode =false,
//     required this.pcategory,
//     required this.warehouse,
//     required this.openingstock,
//     required this.company,
//     required this.companyid,
//     required this.createdat,
//      this.updatedby,
//     required this.imageurl,
//     required this.modes,
//      this.updatedat,
//     required this.wminqty,
//     required this.sminqty,
//     required this.staff,
//     required this.modemore,
//      this.deletedat,
//      this.deletedby,
//      this.branchprices,
//      this.branchbalance,
//     required this.boxqty,
//
//   });
//
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'barcode': barcode,
//       'cp': cp,
//       'retailmarkup': retailmarkup,
//       'wholesalemarkup': wholesalemarkup,
//       'retailprice': retailprice,
//       'wholesaleprice': wholesaleprice,
//       'producttype': producttype,
//       'pricingmode': pricingmode,
//       'pcategory': pcategory,
//       'warehouse': warehouse,
//       'openingstock': openingstock,
//       'company': company,
//       'companyid': companyid,
//       'createdat': createdat,
//       'updatedat': updatedat,
//       'updatedby': updatedby,
//       'imageurl': imageurl,
//       'modes': modes !=null?{ for (var m in modes!) m.id : m.toMap() }:{},
//       'branchprices': branchprices != null ? { for (var bp in branchprices!) bp.id : bp.toMap() } : {},
//       'branchbalance': branchbalance != null ? { for (var bb in branchbalance!) bb.branchId : bb.toMap() }: {},
//       'boxqty': boxqty,
//     };
//   }
//
//   factory ItemModeltry.fromDoc(DocumentSnapshot doc) {
//     final d = doc.data() as Map<String, dynamic>? ?? {};
//
//     return ItemModeltry(
//       id: doc.id,
//       name: d['name']?.toString() ?? '',
//       barcode: d['barcode']?.toString() ?? '',
//
//       cp: d['cp']?.toString() ?? '0',
//       retailmarkup: d['retailmarkup']?.toString() ?? '0',
//       wholesalemarkup: d['wholesalemarkup']?.toString() ?? '0',
//       retailprice: d['retailprice']?.toString() ?? '0',
//       wholesaleprice: d['wholesaleprice']?.toString() ?? '0',
//       producttype: d['producttype']?.toString() ?? 'product',
//       pricingmode: d['pricingmode'] is bool ? d['pricingmode'] : false,
//       pcategory: d['pcategory']?.toString() ?? '',
//       warehouse: d['warehouse']?.toString() ?? '',
//       openingstock: d['openingstock']?.toString() ?? '0',
//       company: d['company']?.toString() ?? '',
//       companyid: d['companyid']?.toString() ?? '',
//       imageurl: d['imageurl']?.toString() ?? '',
//
//       createdat: d['createdat'] is Timestamp ? (d['createdat'] as Timestamp).toDate()
//                : d['createdat'] is DateTime  ? d['createdat'] : DateTime.now(),
//
//       updatedat: d['updatedat'] is Timestamp  ? (d['updatedat'] as Timestamp).toDate()
//                : d['updatedat'] is DateTime ? d['updatedat']  : null,
//
//       updatedby: d['updatedby']?.toString(),
//
//       modes: (d['modes'] as Map<String, dynamic>? ?? {}).entries
//              .map((e) => Mode.fromMap(e.key, Map<String, dynamic>.from(e.value))).toList(),
//
//
//      branchprices: (d['branchprices'] as Map<String, dynamic>? ?? {}).entries
//                   .map((e) => BranchPricingModel.fromMap(e.key,
//                   Map<String, dynamic>.from(e.value),)).toList(),
//
//       branchbalance: (d['branchbalance'] as Map<String, dynamic>? ?? {}).entries
//                    .map((e) => ItemBranchBalance.fromMap(e.key,Map<String, dynamic>.from(e.value),)).toList(),
//
//       wminqty: d['wminqty']?.toString() ?? '',
//       sminqty: d['sminqty']?.toString() ?? '',
//       staff: d['staff']?.toString() ?? '',
//       modemore: d['modemore'] == true,
//       deletedat: d['deletedat'] != null ? (d['deletedat'] as Timestamp).toDate() : null,
//       deletedby: d['deletedby']?.toString(),
//       boxqty: d['boxqty']?.toString() ?? '',
//     );
//   }
//
//   factory ItemModeltry.fromMap(Map<String, dynamic> d) {
//     return ItemModeltry(
//       id: d['id']?.toString() ?? '',
//       name: d['name']?.toString() ?? '',
//       barcode: d['barcode']?.toString() ?? '',
//       cp: d['cp']?.toString() ?? '0',
//       retailmarkup: d['retailmarkup']?.toString() ?? '0',
//       wholesalemarkup: d['wholesalemarkup']?.toString() ?? '0',
//       retailprice: d['retailprice']?.toString() ?? '0',
//       wholesaleprice: d['wholesaleprice']?.toString() ?? '0',
//       producttype: d['producttype']?.toString() ?? 'product',
//       pricingmode: d['pricingmode'] is bool ? d['pricingmode'] : false,
//       pcategory: d['pcategory']?.toString() ?? '',
//       warehouse: d['warehouse']?.toString() ?? '',
//       openingstock: d['openingstock']?.toString() ?? '0',
//       company: d['company']?.toString() ?? '',
//       companyid: d['companyid']?.toString() ?? '',
//       imageurl: d['imageurl']?.toString() ?? '',
//       createdat: d['createdat'] is Timestamp
//           ? (d['createdat'] as Timestamp).toDate()
//           : d['createdat'] is DateTime
//           ? d['createdat']
//           : DateTime.now(),
//       updatedat: d['updatedat'] is Timestamp
//           ? (d['updatedat'] as Timestamp).toDate()
//           : d['updatedat'] is DateTime
//           ? d['updatedat']
//           : null,
//       updatedby: d['updatedby']?.toString(),
//
//
//       modes: (d['modes'] as Map<String, dynamic>? ?? {}).entries.map((e) => Mode.fromMap(e.key, Map<String, dynamic>.from(e.value))).toList(),
//
//       branchprices: (d['branchprices'] as Map<String, dynamic>? ?? {}).entries
//           .map((e) => BranchPricingModel.fromMap(e.key, Map<String, dynamic>.from(e.value))).toList(),
//
//       branchbalance: (d['branchbalance'] as Map<String, dynamic>? ?? {}).entries.map((e) => ItemBranchBalance.fromMap(e.key, Map<String, dynamic>.from(e.value))).toList(),
//
//       wminqty: d['wminqty']?.toString() ?? '',
//       sminqty: d['sminqty']?.toString() ?? '',
//       staff: d['staff']?.toString() ?? '',
//       modemore: d['modemore'] == true,
//
//       deletedat: d['deletedat'] is Timestamp
//           ? (d['deletedat'] as Timestamp).toDate()
//           : d['deletedat'] is DateTime
//           ? d['deletedat']
//           : null,
//       deletedby: d['deletedby']?.toString(),
//       boxqty: d['boxqty']?.toString() ?? '',
//     );
//   }
// }
