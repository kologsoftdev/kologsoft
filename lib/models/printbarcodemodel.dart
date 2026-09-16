import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String company;
  final String companyid;
  final String barcode;
  final double cp;
  final String category;

  ProductModel({
    required this.id,
    required this.name,
    required this.company,
    required this.companyid,
    required this.barcode,
    required this.cp,
    required this.category,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ProductModel(
      id: doc.id,

      name: (data['name'] ?? '').toString(),

      // ✅ SAFE barcode
      barcode: (data['barcode'] ?? '').toString(),

      // ✅ FIX: handle string OR number
      cp: double.tryParse(data['cp']?.toString() ?? '0') ?? 0,

      // ✅ FIX: correct key
      category: (data['pcategory'] ?? '').toString(),

      company: (data['company'] ?? '').toString(),
      companyid: (data['companyid'] ?? '').toString(),
    );
  }
}