import 'package:cloud_firestore/cloud_firestore.dart';

class Mode {
  final String id;
  final String name;
  final String qty;
  final String cp;
  final String rp;
  final String wp;
  final String sp;

  Mode({
    required this.id,
    required this.name,
    required this.qty,
    required this.cp,
    required this.rp,
    required this.wp,
    required this.sp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'qty': qty,
      'cp': cp,
      'rp': rp,
      'wp': wp,
      'sp': sp,
    };
  }

  factory Mode.fromMap(Map<String, dynamic> map) {
    return Mode(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      qty: map['qty'] ?? '',
      cp: map['cp'] ?? '',
      rp: map['rp'] ?? '',
      wp: map['wp'] ?? '',
      sp: map['sp'] ?? '',
    );
  }
}
