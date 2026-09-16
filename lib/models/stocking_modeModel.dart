import 'package:cloud_firestore/cloud_firestore.dart';

class cropModel {
  final String name;
  final String staff;
  final String id;
  final DateTime date;
  final String companyid;
  final String company;

  cropModel({
    required this.name,
    required this.staff,
    required this.id,
    required this.date,
    required this.companyid,
    required this.company,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'id': id,
      'staff': staff,
      'date': Timestamp.fromDate(date), // Firestore safe
      'companyid': companyid,
      'company': company,
    };
  }

  factory cropModel.fromJson(Map<String, dynamic> map) {
    return cropModel(
      name: map['name']?.toString() ?? '',
      staff: map['staff']?.toString() ?? '',
      id: map['id']?.toString() ?? '',
      date: _parseDate(map['date']),
      companyid: map['companyid']?.toString() ?? '',
      company: map['company']?.toString() ?? '',
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }
}
