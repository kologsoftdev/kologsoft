import 'package:cloud_firestore/cloud_firestore.dart';

class CreditorBalance {
  final String id;
  final String creditorId;
  final String creditorName;
  final String paymentMode;
  final String transactionRef;

  final double amount;
  final String type;
  final String? naration;
  final String? paymentaccount;
  final String? phone;
  final String? yearr;
  final String? month;
  final String? day;
  final String? dateymd;

  String? week;

  String? year;
  final String? networktype;

  DateTime? date;
  final Timestamp? datecreated;
  String companyid;
  String? company;
  String? branchid;
  String? branchname;
  String companyemail;
  String updatedby;
  String deletedby;
  String staff;

  DateTime? updatedat;
  DateTime? deletedat;


  CreditorBalance({
    this.id = '',
    required this.creditorId,
    required this.creditorName,
    required this.amount,
    required this.type,
    required this.paymentMode,
    required this.transactionRef,
    this.date,
    this.datecreated,
    this.companyid = '',
    this.companyemail = '',
    this.branchid = '',
    this.branchname = '',
    this.updatedby = '',
    this.deletedby = '',
    this.staff = '',
    this.updatedat,
    this.deletedat,
    this.company,

    this.networktype,

    this.naration,
    this.paymentaccount,
    this.phone,
    this.yearr,
    this.month,
    this.day,

    this.week,

    this.year,
    this.dateymd,
  });

  Map<String, dynamic> toMap() {
    return {
      'creditorId': creditorId,
      'id': id,
      'year': yearr,
      'month': month,
      'day': day,
      'week': week,
      'dateymd': dateymd,
      'creditorName': creditorName,
      'paymentMode': paymentMode,
      'transactionRef': transactionRef,
      'amount': amount,
      'account': paymentaccount,
      'activityType': type,
      'naration': naration,
      'branchid': branchid,
      'branchname': branchid,
      'datecreated': datecreated,

      'date': date != null ? Timestamp.fromDate(date!) : null,
      'updatedat': updatedat != null ? Timestamp.fromDate(updatedat!) : null,
      'deletedat': deletedat != null ? Timestamp.fromDate(deletedat!) : null,

      'companyid': companyid,
      'company': company,
      'companyemail': companyemail,
      'updatedby': updatedby,
      'deletedby': deletedby,
      'staff': staff,
      'networktype':networktype,
      'phone':phone,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  factory CreditorBalance.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return CreditorBalance(
      id: id,
      creditorId: map['creditorId'] ?? '',
      yearr: map['year'] ?? '',
      month: map['month'] ?? '',
      day: map['day'] ?? '',
      dateymd: map['dateymd'] ?? '',
      branchname: map['branchname'] ?? '',
      creditorName: map['creditorName'] ?? '',
      amount: double.tryParse(map['amount'].toString()) ?? 0,
      type: map['activityType'] ?? '',
      branchid: map['branchid'] ?? '',
      companyid: map['companyid'] ?? '',
      company: map['company'] ?? '',
      companyemail: map['companyemail'] ?? '',
      updatedby: map['updatedby'] ?? '',
      deletedby: map['deletedby'] ?? '',
      staff: map['staff'] ?? '',

      date: _parseDate(map['date']),
      datecreated: map['datecreated'] ?? Timestamp.now(),
      updatedat: _parseDate(map['updatedat']),
      deletedat: _parseDate(map['deletedat']),
      paymentMode: map['paymentMode'] ?? '',
      transactionRef: map['transactionRef'] ?? '',
      naration: map['naration'] ?? '',
      paymentaccount: map['account'] ?? '',
      networktype: map['networktype'] ?? '',
      phone: map['phone'] ?? '',

      week: map['week'] ?? '',

      year: map['year'] ?? '',
    );
  }

  factory CreditorBalance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CreditorBalance.fromMap(data, id: doc.id);
  }
}

