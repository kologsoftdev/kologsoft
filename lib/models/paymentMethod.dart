
class PaymentMethodModel {
  String id;
  double amount;
  double totalamount;
  String paymentmethod;
  String accountName;
  String accountNumber;
  String reference;
  bool status;
  double change;
  double balance;
  Map<String, dynamic>? transactionIds;

  PaymentMethodModel({
    this.id = '',
    required this.amount,
    this.totalamount=0.0,
    required this.paymentmethod,
    required this.accountName,
    required this.accountNumber,
    this.reference = '',
    required this.status,
    this.transactionIds,
     this.change = 0.0,
     this.balance = 0.0,

  });

  Map<String, dynamic> toMap() {
    final map = {
      "amount": amount,
      "method": paymentmethod,
      "accountName": accountName,
      "accountNumber": accountNumber,
      "reference": reference,
      "status": status,
    };

    if (transactionIds != null && transactionIds!.isNotEmpty) {
      map["transactionIds"] = transactionIds!;
    }

    return map;
  }

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      amount: (map['amount'] ?? 0).toDouble(),
      totalamount: (map['totalamount'] ?? 0).toDouble(),
      paymentmethod: map['method'] ?? '',
      accountName: map['accountName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      reference: map['reference'] ?? '',
      status: map['status'] ?? false,
      transactionIds: map['transactionIds'] != null
          ? Map<String, dynamic>.from(map['transactionIds'] as Map)
          : null,

    );
  }
}