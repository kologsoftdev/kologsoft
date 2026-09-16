class JournalEntryModel {
  String id;
  String journalType;
  double amount;
  String staff;
  String creditAccount;
  String debitAccount;
  String companyid;
  String companyemail;
  String updatedby;
  String deletedby;
  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;
  String branchId;
  String branchName;
  String narration;
  String dateymd;
  String year;
  String month;
  String day;
  String week;

  JournalEntryModel({
    this.id = '',
    this.journalType = '',
    this.amount = 0.0,
    this.staff = '',
    this.creditAccount = '',
    this.debitAccount = '',
    this.companyid = '',
    this.companyemail = '',
    this.updatedby = '',
    this.deletedby = '',
    this.date,
    this.updatedat,
    this.deletedat,
    this.branchId = '',
    this.branchName = '',
    this.narration = '',
    this.dateymd = '',
    this.month = '',
    this.year = '',
    this.day = '',
    this.week = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'journalType': journalType,
      'amount': amount,
      'staff': staff,
      'creditAccount': creditAccount,
      'debitAccount': debitAccount,
      'companyId': companyid,
      'companyEmail': companyemail,
      'updatedBy': updatedby,
      'deletedby': deletedby,
      'date': date?.toIso8601String(),
      'updatedAt': updatedat?.toIso8601String(),
      'deletedat': deletedat?.toIso8601String(),
      "branchId": branchId,
      "branchName": branchName,
      "dateymd": dateymd,
      "day": day,
      "month": month,
      "year": year,
      "week": week,
    };
  }

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      id: json['id'] ?? '',
      journalType: json['journalType'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      staff: json['staff'] ?? '',
      creditAccount: json['creditAccount'] ?? '',
      debitAccount: json['debitAccount'] ?? '',
      companyid: json['companyId'] ?? '',
      companyemail: json['companyEmail'] ?? '',
      updatedby: json['updatedBy'] ?? '',
      deletedby: json['deletedby'] ?? '',
      branchName: json['branchName'] ?? '',
      narration: json['narration'] ?? '',
      branchId: json['branchId'] ?? '',
      dateymd: json['dateymd'] ?? '',
      day: json['day'] ?? '',
      month: json['month'] ?? '',
      week: json['week'] ?? '',
      year: json['year'] ?? '',
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