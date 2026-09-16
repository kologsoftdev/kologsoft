import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import 'itemmodel.dart';

@HiveType(typeId: 0)
class ItemModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String barcode;
  @HiveField(3)
  final String cp;
  @HiveField(4)
  final String retailmarkup;
  @HiveField(5)
  final String wholesalemarkup;
  @HiveField(6)
  final String retailprice;
  @HiveField(7)
  final String wholesaleprice;
  @HiveField(8)
  final String producttype;
  @HiveField(9)
  final bool pricingmode;
  @HiveField(10)
  final String pcategory;
  @HiveField(11)
  final String warehouse;
  @HiveField(12)
  final String openingstock;
  @HiveField(13)
  final String company;
  @HiveField(14)
  final String companyid;
  @HiveField(15)
  final DateTime createdat;
  @HiveField(16)
  final DateTime? updatedat;
  @HiveField(17)
  final String? updatedby;
  @HiveField(18)
  final String imageurl;
  @HiveField(19)
  final List<Mode>? modes;
  @HiveField(20)
  final String wminqty;
  @HiveField(21)
  final String sminqty;
  @HiveField(22)
  final String staff;
  @HiveField(23)
  final bool modemore;
  @HiveField(24)
  final DateTime? deletedat;
  @HiveField(25)
  final String? deletedby;
  @HiveField(26)
  Map<String, dynamic>? branchprices;
  @HiveField(27)
  final Map<String, dynamic>? branchbalance;
  @HiveField(28)
  final List<Map<String, dynamic>>? items;
  @HiveField(29)
  final bool isActive;
  @HiveField(30)
  final bool isHamper;
  @HiveField(31)
  final Map<String, dynamic>? dailytransactions;
  @HiveField(32)
  String? day;
  @HiveField(33)
  String? week;
  @HiveField(34)
  String? month;
  @HiveField(35)
  String? year;

  @HiveField(36)
  String? shelfnumber;
  ItemModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.cp,
    required this.retailmarkup,
    required this.wholesalemarkup,
    required this.retailprice,
    required this.wholesaleprice,
    required this.producttype,
    this.pricingmode =false,
    this.isActive =true,
    this.isHamper =false,
    required this.pcategory,
    required this.warehouse,
    required this.openingstock,
    required this.company,
    required this.companyid,
    required this.createdat,
     this.updatedby,
    required this.imageurl,
    required this.modes,
     this.updatedat,
    required this.wminqty,
    required this.sminqty,
    required this.staff,
    required this.modemore,
     this.deletedat,
     this.deletedby,
     this.branchprices,
     this.branchbalance,
     this.items,
     this.dailytransactions,
     this.day,
     this.week,
     this.month,
     this.year,
    this.shelfnumber,

  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'cp': cp,
      'retailmarkup': retailmarkup,
      'wholesalemarkup': wholesalemarkup,
      'retailprice': retailprice,
      'wholesaleprice': wholesaleprice,
      'producttype': producttype,
      'pricingmode': pricingmode,
      'isActive':    isActive,
      'isHamper':    isHamper,
      'pcategory': pcategory,
      'warehouse': warehouse,
      'openingstock': openingstock,
      'company': company,
      'companyid': companyid,
      'createdat': createdat,
      'updatedat': updatedat,
      'updatedby': updatedby,
      'imageurl': imageurl,
      'modes': modes != null ? { for (var m in modes!) m.id : m.toMap() }:{},
      'branchprices': branchprices,
      'dailytransactions': dailytransactions,
      'branchbalance': branchbalance,
      'sminqty':sminqty,
      'wminqty':wminqty,
      'staff':staff,
      'modemore':modemore,
      'deletedat':deletedat,
      'deletedby': deletedby,
      'items'    :items,
      'day': day,
      'week': week,
      'month': month,
      'year': year,
      'shellnumber':shelfnumber,

    };
  }

  factory ItemModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    return ItemModel(
      id: doc.id,
      name: d['name']?.toString() ?? '',
      barcode: d['barcode']?.toString() ?? '',
      cp: d['cp']?.toString() ?? '0',
      retailmarkup: d['retailmarkup']?.toString() ?? '0',
      wholesalemarkup: d['wholesalemarkup']?.toString() ?? '0',
      retailprice: d['retailprice']?.toString() ?? '0',
      wholesaleprice: d['wholesaleprice']?.toString() ?? '0',
      producttype: d['producttype']?.toString() ?? 'product',
      pricingmode: d['pricingmode'] is bool ? d['pricingmode'] : false,
      isActive: d['isActive'] is bool ? d['isActive'] : true,
      isHamper: d['isHamper'] is bool ? d['isHamper'] : false,
      pcategory: d['pcategory']?.toString() ?? '',
      warehouse: d['warehouse']?.toString() ?? '',
      openingstock: d['openingstock']?.toString() ?? '0',
      company: d['company']?.toString() ?? '',
      companyid: d['companyid']?.toString() ?? '',
      imageurl: d['imageurl']?.toString() ?? '',
      createdat: d['createdat'] is Timestamp ? (d['createdat'] as Timestamp).toDate()
           : d['createdat'] is DateTime  ? d['createdat'] : DateTime.now(),
      updatedat: d['updatedat'] is Timestamp
          ? (d['updatedat'] as Timestamp).toDate()
          : d['updatedat'] is DateTime
          ? d['updatedat']
          : null,
      updatedby: d['updatedby']?.toString(),
      modes: (d['modes'] as Map<String, dynamic>? ?? {}).entries
          .map((e) => Mode.fromMap(e.key, Map<String, dynamic>.from(e.value))).toList(),
      branchprices: d['branchprices'] is Map ? Map<String, dynamic>.from(d['branchprices']) : {},
      branchbalance: d['branchbalance'] is Map ? Map<String, dynamic>.from(d['branchbalance']) : {},
      dailytransactions: d['dailytransactions'] is Map ? Map<String, dynamic>.from(d['dailytransactions']) : {},
      wminqty: d['wminqty']?.toString() ?? '',
      sminqty: d['sminqty']?.toString() ?? '',
      staff: d['staff']?.toString() ?? '',
      modemore: d['modemore'] == true,
      deletedat: d['deletedat'] is Timestamp
          ? (d['deletedat'] as Timestamp).toDate()
          : d['deletedat'] is DateTime
          ? d['deletedat']
          : null,
      deletedby: d['deletedby']?.toString(),
      items: d['items'] is List ? List<Map<String, dynamic>>.from(d['items']) : [],
      day: d['day'] ?? '',
      week: d['week'] ?? '',
      month: d['month'] ?? '',
      year: d['year'] ?? '',
      shelfnumber: d['shellnumber']?.toString() ?? '',
    );
  }

  factory ItemModel.fromMap(Map<String, dynamic> d) {
    return ItemModel(
      id: d['id']?.toString() ?? '',
      name: d['name']?.toString() ?? '',
      barcode: d['barcode']?.toString() ?? '',
      cp: d['cp']?.toString() ?? '0',
      retailmarkup: d['retailmarkup']?.toString() ?? '0',
      wholesalemarkup: d['wholesalemarkup']?.toString() ?? '0',
      retailprice: d['retailprice']?.toString() ?? '0',
      wholesaleprice: d['wholesaleprice']?.toString() ?? '0',
      producttype: d['producttype']?.toString() ?? 'product',
      pricingmode: d['pricingmode'] is bool ? d['pricingmode'] : false,
      isActive: d['isActive'] is bool ? d['isActive'] : true,
      isHamper: d['isHamper'] is bool ? d['isHamper'] : false,
      pcategory: d['pcategory']?.toString() ?? '',
      warehouse: d['warehouse']?.toString() ?? '',
      openingstock: d['openingstock']?.toString() ?? '0',
      company: d['company']?.toString() ?? '',
      companyid: d['companyid']?.toString() ?? '',
      imageurl: d['imageurl']?.toString() ?? '',
      createdat: d['createdat'] is Timestamp
          ? (d['createdat'] as Timestamp).toDate()
          : d['createdat'] is DateTime
          ? d['createdat']
          : DateTime.now(),
      updatedat: d['updatedat'] is Timestamp
          ? (d['updatedat'] as Timestamp).toDate()
          : d['updatedat'] is DateTime
          ? d['updatedat']
          : null,
      updatedby: d['updatedby']?.toString(),
      modes: (d['modes'] as Map<String, dynamic>? ?? {}).entries
          .map((e) => Mode.fromMap(e.key, Map<String, dynamic>.from(e.value))).toList(),
      branchprices: d['branchprices'] is Map ? Map<String, dynamic>.from(d['branchprices']) : {},
      branchbalance: d['branchbalance'] is Map ? Map<String, dynamic>.from(d['branchbalance']) : {},
      dailytransactions: d['dailytransactions'] is Map ? Map<String, dynamic>.from(d['dailytransactions']) : {},
      wminqty: d['wminqty']?.toString() ?? '',
      sminqty: d['sminqty']?.toString() ?? '',
      staff: d['staff']?.toString() ?? '',
      modemore: d['modemore'] == true,
      deletedat: d['deletedat'] is Timestamp
          ? (d['deletedat'] as Timestamp).toDate()
          : d['deletedat'] is DateTime
          ? d['deletedat']
          : null,
      deletedby: d['deletedby']?.toString(),
      items: d['items'] is List
          ? List<Map<String, dynamic>>.from(d['items'])
          : [],
      day: d['day'] ?? '',
      week: d['week'] ?? '',
      month: d['month'] ?? '',
      year: d['year'] ?? '',
      shelfnumber: d['shellnumber']?.toString() ?? '',
    );
  }

  ItemModel copyWith({
    String? id,
    String? no,
    String? name,
    String? barcode,
    String? cp,
    String? retailmarkup,
    String? wholesalemarkup,
    String? retailprice,
    String? wholesaleprice,
    String? producttype,
    bool? pricingmode,
    bool? isActive,
    bool? isHamper,
    String? pcategory,
    String? warehouse,
    String? openingstock,
    String? company,
    String? companyid,
    DateTime? createdat,
    DateTime? updatedat,
    String? updatedby,
    String? imageurl,
    List<Mode>? modes,
    String? wminqty,
    String? sminqty,
    String? staff,
    bool? modemore,
    DateTime? deletedat,
    String? deletedby,
    Map<String, dynamic>? branchprices,
    Map<String, dynamic>? branchbalance,
    Map<String, dynamic>? dailytransactions,
    List<Map<String, dynamic>>? items,
    String? day,
    String? week,
    String? month,
    String? year,
    String? shellnumber,
  }) {
    return ItemModel(
      id: id ?? this.id,

      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      cp: cp ?? this.cp,
      retailmarkup: retailmarkup ?? this.retailmarkup,
      wholesalemarkup: wholesalemarkup ?? this.wholesalemarkup,
      retailprice: retailprice ?? this.retailprice,
      wholesaleprice: wholesaleprice ?? this.wholesaleprice,
      producttype: producttype ?? this.producttype,
      pricingmode: pricingmode ?? this.pricingmode,
      isActive: isActive ?? this.isActive,
      isHamper: isHamper ?? this.isHamper,
      pcategory: pcategory ?? this.pcategory,
      warehouse: warehouse ?? this.warehouse,
      openingstock: openingstock ?? this.openingstock,
      company: company ?? this.company,
      companyid: companyid ?? this.companyid,
      createdat: createdat ?? this.createdat,
      updatedat: updatedat ?? this.updatedat,
      updatedby: updatedby ?? this.updatedby,
      imageurl: imageurl ?? this.imageurl,
      modes: modes ?? this.modes,
      wminqty: wminqty ?? this.wminqty,
      sminqty: sminqty ?? this.sminqty,
      staff: staff ?? this.staff,
      modemore: modemore ?? this.modemore,
      deletedat: deletedat ?? this.deletedat,
      deletedby: deletedby ?? this.deletedby,
      branchprices: branchprices ?? this.branchprices,
      branchbalance: branchbalance ?? this.branchbalance,
      dailytransactions: dailytransactions ?? this.dailytransactions,
      items: items ?? this.items,
      day:day?? this.day,
      week:week?? this.week,
      month:month?? this.month,
      year:year??this.year,
      shelfnumber: shelfnumber ?? this.shelfnumber,

    );
  }
}
