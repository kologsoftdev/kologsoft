class MomoPaymentModel {
  String id;
  String phoneNumber;
  double amount;
  String branchId;
  String branchName;
  String companyId;
  String staff;
  String status; // pending, success, failed
  String? transactionId;
  DateTime createdAt;
  DateTime? updatedAt;

  MomoPaymentModel({
    required this.id,
    required this.phoneNumber,
    required this.amount,
    required this.branchId,
    required this.branchName,
    required this.companyId,
    required this.staff,
    required this.status,
    this.transactionId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'amount': amount,
      'branchId': branchId,
      'branchName': branchName,
      'companyId': companyId,
      'staff': staff,
      'status': status,
      'transactionId': transactionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MomoPaymentModel.fromMap(Map<String, dynamic> map) {
    return MomoPaymentModel(
      id: map['id'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      companyId: map['companyId'] ?? '',
      staff: map['staff'] ?? '',
      status: map['status'] ?? 'pending',
      transactionId: map['transactionId'],
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null && map['updatedAt'] is String
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }
}
