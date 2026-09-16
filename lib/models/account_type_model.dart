class AccountTypeModel {
  String id;
  String name;
  String accountClass;
  String accountClassType;
  String subAccount;
  String staff;
  String companyid;
  String companyemail;
  String updatedby;
  String deletedby;
  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;

  AccountTypeModel({
    this.id = '',
    this.name = '',
    this.accountClass = '',
    this.accountClassType = '',
    this.subAccount = '',
    this.staff = '',
    this.companyid = '',
    this.companyemail = '',
    this.updatedby = '',
    this.deletedby = '',
    this.date,
    this.updatedat,
    this.deletedat,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'accountClass': accountClass,
      'accountClassType': accountClassType,
      'subAccount': subAccount,
      'staff': staff,
      'companyId': companyid,
      'companyEmail': companyemail,
      'updatedBy': updatedby,
      'deletedby': deletedby,
      'date': date?.toIso8601String(),
      'updatedAt': updatedat?.toIso8601String(),
      'deletedat': deletedat?.toIso8601String(),
    };
  }

  factory AccountTypeModel.fromJson(Map<String, dynamic> json) {
    return AccountTypeModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      accountClass: json['accountClass'] ?? '',
      accountClassType: json['accountClassType'] ?? '',
      subAccount: json['subAccount'] ?? '',
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
    );
  }
}
