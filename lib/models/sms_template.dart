import 'package:cloud_firestore/cloud_firestore.dart';

class SmsTemplate {
  final String id;
  final String companyId;
  final String occasion; // e.g. 'birthday', 'seasonal', 'new_customer', 'credit'
  final String name; // human friendly name
  final String message;
  final String? tag; // optional tag like 'christmas', 'newyear'
  final Timestamp createdAt;
  final Timestamp updatedAt;

  SmsTemplate({
    required this.id,
    required this.companyId,
    required this.occasion,
    required this.name,
    required this.message,
    this.tag,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SmsTemplate.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SmsTemplate(
      id: doc.id,
      companyId: data['companyid'] ?? '',
      occasion: data['occasion'] ?? '',
      name: data['name'] ?? '',
      message: data['message'] ?? '',
      tag: data['tag'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyid': companyId,
      'occasion': occasion,
      'name': name,
      'message': message,
      'tag': tag,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
