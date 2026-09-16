import 'package:cloud_firestore/cloud_firestore.dart';

class SMSRecord {
  final String? id;
  final String companyId;
  final String branchId;
  final String staff;
  final String message;
  final List<String> recipients;
  final int recipientCount;
  final String type; // 'single', 'bulk', 'birthday', 'seasonal'
  final String? season; // For seasonal greetings
  final String? customerId; // For birthday/single SMS
  final String status; // 'pending', 'sent', 'failed', 'scheduled'
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  SMSRecord({
    this.id,
    required this.companyId,
    required this.branchId,
    required this.staff,
    required this.message,
    required this.recipients,
    required this.recipientCount,
    required this.type,
    this.season,
    this.customerId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyid': companyId,
      'branchid': branchId,
      'staff': staff,
      'message': message,
      'recipients': recipients,
      'recipientCount': recipientCount,
      'type': type,
      'season': season,
      'customerId': customerId,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory SMSRecord.fromMap(Map<String, dynamic> map, String docId) {
    return SMSRecord(
      id: docId,
      companyId: map['companyid'] ?? '',
      branchId: map['branchid'] ?? '',
      staff: map['staff'] ?? '',
      message: map['message'] ?? '',
      recipients: List<String>.from(map['recipients'] ?? []),
      recipientCount: map['recipientCount'] ?? 0,
      type: map['type'] ?? 'single',
      season: map['season'],
      customerId: map['customerId'],
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'],
    );
  }
}

class SMSTemplate {
  final String? id;
  final String companyId;
  final String name;
  final String message;
  final String category; // 'birthday', 'seasonal', 'general'
  final bool isActive;
  final Timestamp createdAt;

  SMSTemplate({
    this.id,
    required this.companyId,
    required this.name,
    required this.message,
    required this.category,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyid': companyId,
      'name': name,
      'message': message,
      'category': category,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  factory SMSTemplate.fromMap(Map<String, dynamic> map, String docId) {
    return SMSTemplate(
      id: docId,
      companyId: map['companyid'] ?? '',
      name: map['name'] ?? '',
      message: map['message'] ?? '',
      category: map['category'] ?? 'general',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }
}

class BirthdayReminder {
  final String? id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String companyId;
  final String branchId;
  final DateTime birthDate;
  final bool reminderSent;
  final Timestamp? sentDate;
  final Timestamp createdAt;

  BirthdayReminder({
    this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.companyId,
    required this.branchId,
    required this.birthDate,
    required this.reminderSent,
    this.sentDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'companyid': companyId,
      'branchid': branchId,
      'birthDate': birthDate,
      'reminderSent': reminderSent,
      'sentDate': sentDate,
      'createdAt': createdAt,
    };
  }

  factory BirthdayReminder.fromMap(Map<String, dynamic> map, String docId) {
    return BirthdayReminder(
      id: docId,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      companyId: map['companyid'] ?? '',
      branchId: map['branchid'] ?? '',
      birthDate: DateTime.parse(map['birthDate'].toString()),
      reminderSent: map['reminderSent'] ?? false,
      sentDate: map['sentDate'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }
}
