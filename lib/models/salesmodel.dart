import 'package:cloud_firestore/cloud_firestore.dart';

class SalesModel {
  String id;

  String companyId;
  String companyname;
  String branchId;
  String branchName;
  String? branchType;

  String? createdBy;
  String? approvedby;
  String? receiptby;
  String? receiptbyemail;
  String? printedby;
  String? staff;
  String? staffemail;
  String? dateymd ;

  String receiptNumber;
  String transMode;

  String? customerId;
  String? customerName;
  String? customerPhone;

  double totalamount;
  double? discount;
  double amountPaid;
  double change;

  int itemCount;
  int staffPosition;

  bool isreturned;
  bool printed = false;
  bool reciepted = false;
  bool supplystatus =false;
  Timestamp? supplyat;
  String?supplyby;
  String pricingtype;

  Timestamp? createdAt;
  Timestamp? receiptat;
  Timestamp? printedat;
  Timestamp? stockCheckedAt;
  String paymentStatus;
  int timestamp;

  Map<String, dynamic> items;

  /// OPTIONAL PAYMENT FIELDS
  double? customerCreditLimit;

  String? paymentBankName;
  String? paymentReference;

  String? paymentCardHolder;
  String? paymentCardLast4;
  String? paymentCardReference;
  List<dynamic>? payments;
  String? day;
  String? week;
  String? month;
  String? year;

  SalesModel({
    required this.id,
    required this.companyId,
    required this.companyname,
    required this.branchId,
    required this.branchName,
    this.createdBy,
    this.approvedby,
    this.receiptby,
    this.receiptbyemail,
    this.printedby,
    this.payments,
    required this.receiptNumber,
    required this.transMode,
     this.customerId,
     this.customerName,
     this.customerPhone,
     this.day,
     this.week,
     this.month,
     this.year,
     this.paymentStatus = 'pending',
     required this.totalamount,
    required this.amountPaid,
     this.discount,
    required this.change,
    required this.itemCount,
    required this.staffPosition,
    required this.isreturned,
    required this.printed,
    required this.reciepted,

    required this.pricingtype,
    this.createdAt,
    this.receiptat,
    this.printedat,
    this.stockCheckedAt,
    required this.timestamp,
    required this.items,

    this.customerCreditLimit,
    this.paymentBankName,
    this.paymentReference,
    this.paymentCardHolder,
    this.paymentCardLast4,
    this.paymentCardReference,
    this.branchType,
    this.staffemail,
    this.dateymd,
    this.supplyat,
    this.supplyby,
    required this.supplystatus,

  });

  /// WRITE TO FIRESTORE
  Map<String, dynamic> toMap() {
    final map = {
      "id": id,
      "companyId": companyId,
      "companyname": companyname,
      "branchId": branchId,
      "branchName": branchName,
      "createdBy": createdBy,
      "approvedby": approvedby,
      "receiptby": receiptby,
      "receiptbyemail": receiptbyemail,
      "printedby": printedby,
      "receiptNumber": receiptNumber,
      "transMode": transMode,
      "customerId": customerId,
      "customerName": customerName,
      "customerPhone": customerPhone,
      "totalamount": totalamount,
      "amountPaid": amountPaid,
      "discount": discount,
      "change": change,
      "itemCount": itemCount,
      "staffPosition": staffPosition,
      "isreturned": isreturned,
      "printed": printed,
      "reciepted": reciepted,
      "pricingtype": pricingtype,
      "createdAt": createdAt,
      "receiptat": receiptat,
      "printedat": printedat,
      "stockCheckedAt": stockCheckedAt,
      "timestamp": timestamp,
      "items": items,
      "branchType": branchType,
      "payments": payments,
      'paymentStatus': paymentStatus,
      'dateymd': dateymd,
      'staffemail': staffemail,
      'day': day,
      'week': week,
      'month': month,
      'year': year,
      'supplystatus':supplystatus,
      'supplyat':supplyat,
      'supplyby':supplyby,
    };

    if (customerCreditLimit != null) {
      map["customerCreditLimit"] = customerCreditLimit;
    }

    if (paymentBankName != null) {
      map["paymentBankName"] = paymentBankName;
      map["paymentReference"] = paymentReference;
    }

    if (paymentCardHolder != null) {
      map["paymentCardHolder"] = paymentCardHolder;
      map["paymentCardLast4"] = paymentCardLast4;
      map["paymentCardReference"] = paymentCardReference;
    }

    return map;
  }

  /// READ FROM MAP
  factory SalesModel.fromMap(Map<String, dynamic> map, String id) {
    return SalesModel(
      id: id,
      companyId: map['companyId'] ?? '',
      companyname: map['companyname'] ?? '',
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      createdBy: map['createdBy'],
      approvedby: map['approvedby'],
      receiptby: map['receiptby'],
      receiptbyemail: map['receiptbyemail'],
      printedby: map['printedby'],
      receiptNumber: map['receiptNumber'] ?? '',
      transMode: map['transMode'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      totalamount: (map['totalamount'] ?? 0).toDouble(),
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      change: (map['change'] ?? 0).toDouble(),
      itemCount: map['itemCount'] ?? 0,
      staffPosition: map['staffPosition'] ?? 0,
      isreturned: map['isreturned'] ?? false,
      pricingtype: map['pricingtype'] ?? '',
      branchType: map['branchType'] ?? '',
      createdAt: map['createdAt'],
      receiptat: map['receiptat'],
      printedat: map['printedat'],

      day: map['day'] ?? '',
      week: map['week'] ?? '',
      month: map['month'] ?? '',
      year: map['year'] ?? '',

      stockCheckedAt: map['stockCheckedAt'],
      timestamp: map['timestamp'] ?? 0,
      items: Map<String, dynamic>.from(map['items'] ?? {}),

      customerCreditLimit:
      (map['customerCreditLimit'] as num?)?.toDouble(),

      paymentBankName: map['paymentBankName'],
      paymentReference: map['paymentReference'],

      paymentCardHolder: map['paymentCardHolder'],
      paymentCardLast4: map['paymentCardLast4'],
      paymentCardReference: map['paymentCardReference'],
      printed: map['printed'] ?? false,
      reciepted: map['reciepted'] ?? false,
      supplystatus: map['supplystatus']?? false,
      supplyat: map['supplyat'],
      supplyby: map['supplyby'],
      paymentStatus: map['paymentStatus'] ?? 'pending',
      staffemail: map['staffemail'] ?? '',
      dateymd: map['dateymd'] ?? '',
      payments: map['payments'] is List
          ? List<dynamic>.from(map['payments'])
          : null,
    );
  }

  /// READ FROM FIRESTORE SNAPSHOT
  factory SalesModel.fromSnapshot(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return SalesModel.fromMap(map, doc.id);
  }
}