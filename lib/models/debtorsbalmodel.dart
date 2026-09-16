class DebtorsBalModel {
  String id;
  String name;
  String amount;
  String staff;
  String companyid;
  String companyemail;
  String updatedby;
  String deletedby;
  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;
  String branchId;
  String branchName;
  String activityType;

  DebtorsBalModel({
    this.id = '',
    this.name = '',
    this.amount = '',
    this.staff = '',
    this.companyid = '',
    this.companyemail = '',
    this.updatedby = '',
    this.deletedby = '',
    this.date,
    this.updatedat,
    this.deletedat,
    this.branchId = '',
    this.branchName = '',
    this.activityType = '',
});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'staff': staff,
      'companyId': companyid,
      'companyEmail': companyemail,
      'updatedBy': updatedby,
      'deletedby': deletedby,
      'date': date?.toIso8601String(),
      'updatedAt': updatedat?.toIso8601String(),
      'deletedat': deletedat?.toIso8601String(),
      "branchId": branchId,
      "branchName": branchName,
      "activityType": activityType,
    };
  }

  factory DebtorsBalModel.fromJson(Map<String, dynamic> json) {
    return DebtorsBalModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      amount: json['amount'] ?? '',
      staff: json['staff'] ?? '',
      companyid: json['companyId'] ?? '',
      companyemail: json['companyEmail'] ?? '',
      updatedby: json['updatedBy'] ?? '',
      deletedby: json['deletedby'] ?? '',
      branchName: json['branchName'] ?? '',
      activityType: json['activityType'] ?? '',
      branchId: json['branchId'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      updatedat: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      deletedat: json['deletedat'] != null
          ? DateTime.parse(json['deletedat'])
          : null,
    );
  }
}