class Productcategorymodel {
  String id = '';
  String productname;
  String companyid;
  String companyemail;
  String updatedby;
  DateTime? date;
  DateTime? updatedat;
  String staff;
  String deletedby;
  DateTime? deletedat;

  Productcategorymodel({
    this.id = '',
    this.productname = '',
    this.updatedby = '',
    this.staff = '',
    this.companyid = '',
    this.companyemail = '',
    this.date,
    this.updatedat,
    this.deletedby = '',
    this.deletedat,
});
  Map<String, dynamic> toMap (){
    return {
      'id': id,
      'productname': productname,
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
  factory Productcategorymodel.fromJson(Map<String, dynamic> json) {
    return Productcategorymodel(
      id: json['id'] ?? '',
      productname: json['productname'] ?? '',
      staff: json['staff'] ?? '',
      companyid: json['companyId'] ?? '',
      companyemail: json['companyEmail'] ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : null,
      updatedat: json['updatedat'] != null ? DateTime.parse(json['updatedat']) : null,
      deletedat: json['deletedat'] != null ? DateTime.parse(json['deletedat']) : null,
      updatedby: json['updatedBy'] ?? '',
      deletedby: json['deletedby'] ?? '',

    );
  }
}