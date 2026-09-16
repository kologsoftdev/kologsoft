import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  String id;
  String company;
  String companyid;
  String name;
  String phone;
  String email;
  String address;
  String branch;
  String type;
  String logo;
  List<String> customDomains;
  String subscriptionTier;

  DateTime createdAt;
  DateTime updatedAt;
  String updatedBy;

  CompanyModel({
    required this.id,
    required this.company,
    required this.companyid,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.branch,
    required this.logo,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
    required this.type,
    this.customDomains = const [],
    this.subscriptionTier = 'starter',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'companyid': companyid,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'branch': branch,
      'logo': logo,
      'customDomains': customDomains,
      'subscriptionTier': subscriptionTier,
      'createdat': Timestamp.fromDate(createdAt),
      'updatedat': Timestamp.fromDate(updatedAt),
      'updatedby': updatedBy,
      'type': type,
    };
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    final rawDomains = map['customDomains'];
    final List<String> domains = rawDomains is List
        ? rawDomains.map((e) => e.toString()).toList()
        : rawDomains is String
        ? rawDomains
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    return CompanyModel(
      id: map['id'],
      company: map['company'],
      companyid: map['companyid'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      branch: map['branch'],
      type: map['type'],
      logo: map['logo'] ?? '',
      createdAt: (map['createdat'] as Timestamp).toDate(),
      updatedAt: (map['updatedat'] as Timestamp).toDate(),
      updatedBy: map['updatedby'] ?? '',
      customDomains: domains,
      subscriptionTier: map['subscriptionTier'] ?? 'starter',
    );
  }
}
