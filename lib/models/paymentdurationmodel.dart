class PaymentDurationModel {
  String id = '';
  String paymentname;
  String duration;
  String companyid;
  String companyemail;
  String updatedby;
  String deletedby;
  DateTime? date;
  DateTime? updatedat;
  DateTime? deletedat;
  String staff;


  PaymentDurationModel({
    this.id = '',
    this.paymentname = '',
    this.duration = '',
    this.updatedby = '',
    this.deletedby = '',
    this.staff = '',
    this.companyid = '',
    this.companyemail = '',
    this.date,
    this.updatedat,
    this.deletedat
  });

  Map<String, dynamic> toMap (){
    return {
      'id': id,
      'paymentname': paymentname,
      'duration': duration,
      'updatedBy': updatedby,
      'deletedby': deletedby,
      'staff': staff,
      'companyId': companyid,
      'companyEmail': companyemail,
      'date': date?.toIso8601String(),
      'updatedAt': updatedat?.toIso8601String(),
      'deletedat': deletedat?.toIso8601String(),
    };
  }
  factory PaymentDurationModel.fromJson(Map<String, dynamic> json) {
    return PaymentDurationModel(
      id: json['id'] ?? '',
      paymentname: json['paymentname'] ?? '',
      duration: json['duration'] ?? '',
      updatedby: json['updatedBy'] ?? '',
      deletedby: json['deletedby'] ?? '',
      staff: json['staff'] ?? '',
      companyid: json['companyId'] ?? '',
      companyemail: json['companyEmail'] ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : null,
      updatedat: json['updatedat'] != null ? DateTime.parse(json['updatedat']) : null,
      deletedat: json['deletedat'] != null ? DateTime.parse(json['deletedat']) : null,
    );
  }
}