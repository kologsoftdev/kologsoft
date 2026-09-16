class ExpenseEntryModel {
  String id;
  String expenseName;
  String description;
  double amount;
  String category;
  String subAccountId;
  String subAccountName;
  String paymentMethod;
  String receiptNumber;
  String vendorName;
  String staff;
  String companyid;
  String companyemail;
  String branchId;
  String branchName;
  String companyName;
  String updatedby;
  String deletedby;
  DateTime? expenseDate;
  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;
  int? createdAtTimestamp;

  ExpenseEntryModel({
    this.id = '',
    this.expenseName = '',
    this.description = '',
    this.amount = 0.0,
    this.category = '',
    this.subAccountId = '',
    this.subAccountName = '',
    this.paymentMethod = '',
    this.receiptNumber = '',
    this.vendorName = '',
    this.staff = '',
    this.companyid = '',
    this.companyemail = '',
    this.branchId = '',
    this.branchName = '',
    this.companyName = '',
    this.updatedby = '',
    this.deletedby = '',
    this.expenseDate,
    this.date,
    this.updatedat,
    this.deletedat,
    this.createdAtTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseName': expenseName,
      'description': description,
      'amount': amount,
      'category': category,
      'subAccountId': subAccountId,
      'subAccountName': subAccountName,
      'paymentMethod': paymentMethod,
      'receiptNumber': receiptNumber,
      'vendorName': vendorName,
      'staff': staff,
      'companyId': companyid,
      'companyEmail': companyemail,
      "branchId": branchId,
      "branchName": branchName,
      "companyName": companyName,
      'updatedBy': updatedby,
      'deletedby': deletedby,
      'expenseDate': expenseDate?.toIso8601String(),
      'date': date?.toIso8601String(),
      'updatedAt': updatedat?.toIso8601String(),
      'deletedat': deletedat?.toIso8601String(),
      'createdAtTimestamp': createdAtTimestamp,
    };
  }

  factory ExpenseEntryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseEntryModel(
      id: json['id'] ?? '',
      expenseName: json['expenseName'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      subAccountId: json['subAccountId'] ?? '',
      subAccountName: json['subAccountName'] ?? '',
      paymentMethod: json['paymentMethod'] ?? '',
      receiptNumber: json['receiptNumber'] ?? '',
      vendorName: json['vendorName'] ?? '',
      staff: json['staff'] ?? '',
      companyid: json['companyId'] ?? '',
      companyemail: json['companyEmail'] ?? '',
      branchName: json['branchName'] ?? '',
      companyName: json['companyName'] ?? '',
      branchId: json['branchId'] ?? '',
      updatedby: json['updatedBy'] ?? '',
      deletedby: json['deletedby'] ?? '',
      expenseDate: json['expenseDate'] != null
          ? DateTime.parse(json['expenseDate'])
          : null,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      updatedat: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      deletedat: json['deletedat'] != null
          ? DateTime.parse(json['deletedat'])
          : null,
      createdAtTimestamp: json['createdAtTimestamp'],
    );
  }
}
