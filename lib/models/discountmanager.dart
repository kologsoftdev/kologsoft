import 'package:cloud_firestore/cloud_firestore.dart';

class DiscountCodeModel {
  String    id;
  String    companyId;
  String    companyName;
  String?    name;
  String    staff;
  String    branch;
  String    code;
  double    amount;
  bool      isUsed;
  bool      isActive;
  String?   createdBy;
  String?   usedBy;
  String?   usedBranch;
  Timestamp? createdAt;
  Timestamp? expiresAt;
  Timestamp? usedAt;
  String? day;
  String? week;
  String? month;
  String? year;
  DiscountCodeModel({
    required this.id,
    required this.companyId,
    required this.companyName,
     this.name,
    required this.staff,
    required this.branch,
    required this.code,
    required this.amount,
    this.isUsed     = false,
    this.isActive   = true,
    this.createdBy,
    this.usedBy,
    this.usedBranch,
    this.createdAt,
    this.expiresAt,
    this.usedAt,
    this.day,
    this.week,
    this.month,
    this.year,
  });

  bool get canBeUsed {
    if (!isActive || isUsed) return false;
    if (expiresAt != null &&
        expiresAt!.toDate().isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  bool get isExpired =>
      expiresAt != null &&
          expiresAt!.toDate().isBefore(DateTime.now()) &&
          !isUsed;

  Map<String, dynamic> toMap() => {
    'id':         id,
    'companyId':  companyId,
    'companyName': companyName,
    'name': name,
    'staff':      staff,
    'branch':     branch,
    'code':       code,
    'amount':     amount,
    'isUsed':     isUsed,
    'isActive':   isActive,
    'createdBy':  createdBy,
    'usedBy':     usedBy,
    'usedBranch': usedBranch,
    'createdAt':  createdAt,
    'expiresAt':  expiresAt,
    'usedAt':     usedAt,
    'day': day,
    'week': week,
    'month': month,
    'year': year,
  };

  factory DiscountCodeModel.fromMap(Map<String, dynamic> m, String docId) =>
      DiscountCodeModel(
        id:         docId,
        companyId:  m['companyId']  ?? '',
        companyName: m['companyName'] ?? '',
        name: m['name'] ?? '',
        staff: m['staff'] ?? '',
        branch: m['branch'] ?? '',
        code: m['code'] ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        isUsed:  m['isUsed']     ?? false,
        isActive: m['isActive']   ?? true,
        createdBy: m['createdBy'],
        usedBy: m['usedBy'],
        usedBranch: m['usedBranch'],
        createdAt: m['createdAt']  as Timestamp?,
        expiresAt: m['expiresAt']  as Timestamp?,
        usedAt: m['usedAt']  as Timestamp?,
        day: m['day'] ?? '',
        week: m['week'] ?? '',
        month: m['month'] ?? '',
        year: m['year'] ?? '',
      );

  factory DiscountCodeModel.fromSnapshot(DocumentSnapshot doc) =>
      DiscountCodeModel.fromMap(
        doc.data() as Map<String, dynamic>, doc.id,
      );
}