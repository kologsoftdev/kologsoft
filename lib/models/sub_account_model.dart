class SubAccountModel {
  String id;
  String name;
  String accountClass;
  String accountClassType;
  String staff;
  String companyid;
  String companyemail;
  String updatedby;
  String deletedby;
  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;
  bool canReceivePayment;
  bool canMakePayment;

  SubAccountModel({
    this.id = '',
    this.name = '',
    this.accountClass = '',
    this.accountClassType = '',
    this.staff = '',
    this.companyid = '',
    this.companyemail = '',
    this.updatedby = '',
    this.deletedby = '',
    this.date,
    this.updatedat,
    this.deletedat,
    this.canReceivePayment = false,
    this.canMakePayment = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'accountClass': accountClass,
      'accountClassType': accountClassType,
      'staff': staff,
      'companyId': companyid,
      'companyEmail': companyemail,
      'updatedBy': updatedby,
      'deletedby': deletedby,
      'date': date?.toIso8601String(),
      'updatedAt': updatedat?.toIso8601String(),
      'deletedat': deletedat?.toIso8601String(),
      'canReceivePayment': canReceivePayment,
      'canMakePayment': canMakePayment,
    };
  }

  factory SubAccountModel.fromJson(Map<String, dynamic> json) {
    return SubAccountModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      accountClass: json['accountClass'] ?? '',
      accountClassType: json['accountClassType'] ?? '',
      staff: json['staff'] ?? '',
      companyid: json['companyId'] ?? '',
      companyemail: json['companyEmail'] ?? '',
      updatedby: json['updatedBy'] ?? '',
      deletedby: json['deletedby'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      updatedat: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      deletedat: json['deletedat'] != null
          ? DateTime.parse(json['deletedat'])
          : null,
      canReceivePayment: json['canReceivePayment'] ?? false,
      canMakePayment: json['canMakePayment'] ?? false,
    );
  }
}
