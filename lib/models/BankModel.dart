class BankPaymentModel {
  String id;

  double amount;

  String branchId;
  String branchName;
  String companyId;
  String staff;

  String status; // pending, success, failed

  String? bankName;
  String? reference;
  String? paymentMethod;

  String? receiptNumber;
  String? salesId;

  DateTime createdAt;
  DateTime? updatedAt;

  BankPaymentModel({
    required this.id,
    required this.amount,
    required this.branchId,
    required this.branchName,
    required this.companyId,
    required this.staff,
    required this.status,
    this.bankName,
    this.reference,
    this.paymentMethod,
    this.receiptNumber,
    this.salesId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'branchId': branchId,
      'branchName': branchName,
      'companyId': companyId,
      'staff': staff,
      'status': status,
      'bankName': bankName,
      'reference': reference,
      'paymentMethod': paymentMethod,
      'salesId': salesId,
      'receiptNumber': receiptNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory BankPaymentModel.fromMap(Map<String, dynamic> map) {
    return BankPaymentModel(
      id: map['id'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      companyId: map['companyId'] ?? '',
      staff: map['staff'] ?? '',
      status: map['status'] ?? 'pending',
      bankName: map['bankName'],
      reference: map['reference'],
      paymentMethod: map['paymentMethod'],
      salesId: map['salesId'],
      receiptNumber: map['receiptNumber'],
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null && map['updatedAt'] is String
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }
}