
import 'package:cloud_firestore/cloud_firestore.dart';
import 'itemmodel.dart';

class BranchPricingModel {
  final String id;
  final String name;
  final List<Mode> modes;
  final String? cp;
  final String? sminqty;
  final String? wminqty;
  final String? createdby;
  final DateTime? createdat;
  final String? updatedby;
  final DateTime? updatedat;
  final String? deletedby;
  final DateTime? deletedat;

  BranchPricingModel({
    required this.id,
    required this.name,
    required this.modes,
    this.cp,
    this.sminqty,
    this.wminqty,
    this.createdby,
    this.createdat,
    this.updatedby,
    this.updatedat,
    this.deletedby,
    this.deletedat,
  });

  /// Convert Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pricing': { for (var mode in modes) mode.id: mode.toMap() },
      'cp': cp,
      'sminqty': sminqty,
      'wminqty': wminqty,
      'createdby': createdby,
      'createdat': createdat,
      'updatedby': updatedby,
      'updatedat': updatedat,
      'deletedby': deletedby,
      'deletedat': deletedat,
    };
  }

  /// Firestore → Model
  factory BranchPricingModel.fromMap(String id, Map<String, dynamic> map) {
    final Map<String, dynamic> modesRaw = Map<String, dynamic>.from(map['pricing'] ?? {});

    final List<Mode> modes = modesRaw.entries.map((e) {
      return Mode.fromMap(e.key, Map<String, dynamic>.from(e.value));
    }).toList();

    return BranchPricingModel(
      id: id,
      name: map['name'] ?? '',
      modes: modes,
      cp: map['cp'],
      sminqty: map['sminqty'],
      wminqty: map['wminqty'],
      createdby: map['createdby'],
      createdat: map['createdat'] != null ? (map['createdat'] as Timestamp).toDate() : null,
      updatedby: map['updatedby'],
      updatedat: map['updatedat'] != null ? (map['updatedat'] as Timestamp).toDate() : null,
      deletedby: map['deletedby'],
      deletedat: map['deletedat'] != null ? (map['deletedat'] as Timestamp).toDate() : null,
    );
  }
}