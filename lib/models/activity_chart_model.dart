class ActivityChartModel {
  String id;
  String activityName;
  String debitAccountId;
  String debitAccountName;
  String creditAccountId;
  String creditAccountName;
  String staff;
  String companyid;
  String companyemail;
  String updatedby;
  String deletedby;
  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;

  ActivityChartModel({
    this.id = '',
    this.activityName = '',
    this.debitAccountId = '',
    this.debitAccountName = '',
    this.creditAccountId = '',
    this.creditAccountName = '',
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
      'activityName': activityName,
      'debitAccountId': debitAccountId,
      'debitAccountName': debitAccountName,
      'creditAccountId': creditAccountId,
      'creditAccountName': creditAccountName,
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

  factory ActivityChartModel.fromJson(Map<String, dynamic> json) {
    return ActivityChartModel(
      id: json['id'] ?? '',
      activityName: json['activityName'] ?? '',
      debitAccountId: json['debitAccountId'] ?? '',
      debitAccountName: json['debitAccountName'] ?? '',
      creditAccountId: json['creditAccountId'] ?? '',
      creditAccountName: json['creditAccountName'] ?? '',
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
