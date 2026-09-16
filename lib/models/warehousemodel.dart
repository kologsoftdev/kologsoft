class WarehouseModel {
  String name;
  String staff;
  String id;
  DateTime date;
  String companyid;
  String company;

  WarehouseModel({
    required this.name,
    required this.staff,
    required this.id,
    required this.date,
    required this.companyid,
    required this.company,
  });

  factory WarehouseModel.fromMap(Map<String, dynamic> map) {
    return WarehouseModel(
      name: map['name'] ?? '',
      staff: map['staff'] ?? '',
      id: map['id'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      companyid: map['companyid'] ?? '',
      company: map['company'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'id': id,
      'staff': staff,
      'date': date.toIso8601String(),
      'created_at': DateTime.now(),
      'companyid': companyid,
      'company': company,
    };
  }
}
