class ActivityModel {
  String id;
  String activityName;
  String subclass;
  String subtype;
  String debitSubclass;
  String debitSubtype;
  String creditSubclass;
  String creditSubtype;
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

  ActivityModel({
    this.id = '',
    this.activityName = '',
    this.subclass = '',
    this.subtype = '',
    this.debitSubclass = '',
    this.debitSubtype = '',
    this.creditSubclass = '',
    this.creditSubtype = '',
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
      'subclass': subclass,
      'subtype': subtype,
      'debitSubclass': debitSubclass,
      'debitSubtype': debitSubtype,
      'creditSubclass': creditSubclass,
      'creditSubtype': creditSubtype,
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

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] ?? '',
      activityName: json['activityName'] ?? '',
      subclass: json['subclass'] ?? '',
      subtype: json['subtype'] ?? '',
      debitSubclass: json['debitSubclass'] ?? '',
      debitSubtype: json['debitSubtype'] ?? '',
      creditSubclass: json['creditSubclass'] ?? '',
      creditSubtype: json['creditSubtype'] ?? '',
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
