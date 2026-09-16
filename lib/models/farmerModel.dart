import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerRegModel {
  String id;
  String branchname;
  String branchid;
  String? amountpaid;
  String name;
  String contact;
  String customertype;
  String? iscashcustoma;
  String? creditlimit;
  String? paymentduration;
  String companyid;
  String companyname;
  DateTime date;
  String? updatedby;
  DateTime? updatedat;
  String? deletedby;
  DateTime? deletedat;
  String? creditBalance;
  String staff;
  String region;
  String district;
  String community;
  String majorcrop;
  List<dynamic> minorcrop;
  String? businessname;
  String? businessaddress;
  String? fulltimestaff;
  String? parttimestaff;
  String? registered;
  String dateofbirth;
  String ghanacard;
  List<dynamic> languagespokens;
  String popularname;
  String household;
  String homeaddress;
  String gender;
  String educationlevel;
  String farmerid;
  String? businessgps;
  String? homegps;



  FarmerRegModel({
    required this.id,
    required this.branchname,
    required this.branchid,
    required this.name,
    required this.contact,
    required this.customertype,
    this.iscashcustoma,
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
    required this.community,
    required this.region,
    required this.district,
    required this.majorcrop,
    required this.minorcrop,
    this.businessname,
    this.businessaddress,
    this.fulltimestaff,
    this.parttimestaff,
    this.registered,
    required this.dateofbirth,
    required this.ghanacard,
    required this.languagespokens,
    required this.popularname,
    required this.household,
    required this.homeaddress,
    required this.gender,
    required this.educationlevel,
    required this.farmerid,
    this.businessgps,
    this.homegps,


  });

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'branchname': branchname,
      'branchid': branchid,
      'id': id,
      'name': name,
      'contact': contact,
      'iscashcustoma': iscashcustoma,
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
      'community': community,
      'district': district,
      'region': region,
      'majorcrop': majorcrop,
      'minorcrop': minorcrop,
      'businessname': businessname,
      'businessaddress': businessaddress,
      'fulltimestaff': fulltimestaff,
      'parttimestaff': parttimestaff,
    'registered':registered,
    'dateofbirth': dateofbirth,
    'ghanacard': ghanacard,
    'languagespokens': languagespokens,
    'popularname': popularname,
    'household': household,
    'homeaddress': homeaddress,
    'gender': gender,
    'educationlevel': educationlevel,
    'farmerid': farmerid,
    'businessgps': businessgps,
    'homegps': homegps,

    };
  }

  // Factory to safely parse Firestore map
  factory FarmerRegModel.fromMap(Map<String, dynamic> json, String id) {
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

    return FarmerRegModel(
      id: id,
      branchname: parseString(json['branchname']) ?? '',
      branchid: parseString(json['branchid']) ?? '',
      name: parseString(json['name']) ?? '',
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
      community: parseString(json['community']) ?? '',
      region:parseString(json['region']) ?? '',
      district:parseString(json['district']) ?? '',
      majorcrop:parseString(json['majorcrop']) ?? '',
      minorcrop: (json['minorcrop'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      dateofbirth: parseString(json['dateofbirth']) ?? '',
      ghanacard: parseString(json['ghanacard']) ?? '',
      languagespokens: (json['languagespokens'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      businessname: parseString(json['businessname']) ?? '',
      businessaddress: parseString(json['businessaddress']) ?? '',
      fulltimestaff: parseString(json['fulltimestaff']) ?? '',
      parttimestaff: parseString(json['parttimestaff']) ?? '',
      popularname: parseString(json['popularname']) ?? '',
      homeaddress: parseString(json['homeaddress']) ?? '',
      household: parseString(json['household']) ?? '',
      gender: parseString(json['gender']) ?? '',
      educationlevel: parseString(json['educationlevel']) ?? '',
      farmerid: parseString(json['farmerid']) ?? '',
      registered: parseString(json['registered']) ?? '',
      businessgps: parseString(json['businessgps']),
      homegps: parseString(json['homegps']),

    );
  }
}