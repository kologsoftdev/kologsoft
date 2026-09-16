import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseReturnItem {
  final String barcode;
  final int discount;
  final String item;
  final String itemid;
  final int modeqty;
  final int pieces;
  final int price;
  final int quantity;
  String returnStatus;
  final DateTime returndate;
  final int returnpieces;
  final int returnquantity;
  final String returnreason;
  final String stockingmode;
  final int taxamount;
  final String taxtype;
  final int taxvalue;
  final int total;
  final String returnid;
  final int returnvalue;

  PurchaseReturnItem({
    required this.barcode,
    required this.discount,
    required this.item,
    required this.itemid,
    required this.modeqty,
    required this.pieces,
    required this.price,
    required this.quantity,
    required this.returnStatus,
    required this.returndate,
    required this.returnpieces,
    required this.returnquantity,
    required this.returnreason,
    required this.stockingmode,
    required this.taxamount,
    required this.taxtype,
    required this.taxvalue,
    required this.total,
    required this.returnid,
    required this.returnvalue,
  });

  factory PurchaseReturnItem.fromJson(Map<String, dynamic> json) {
    return PurchaseReturnItem(
      barcode: json['barcode'] ?? '',
      discount: json['discount'] ?? 0,
      item: json['item'] ?? '',
      itemid: json['itemid'] ?? '',
      modeqty: json['modeqty'] ?? 0,
      pieces: json['pieces'] ?? 0,
      price: json['price'] ?? 0,
      quantity: json['quantity'] ?? 0,
      returnStatus: json['returnStatus'] ?? '',
      returndate: json['returndate'] is Timestamp ? (json['returndate'] as Timestamp).toDate() : DateTime.parse(json['returndate']),
      returnpieces: json['returnpieces'] ?? 0,
      returnquantity: json['returnquantity'] ?? 0,
      returnreason: json['returnreason'] ?? '',
      stockingmode: json['stockingmode'] ?? '',
      taxamount: json['taxamount'] ?? 0,
      taxtype: json['taxtype'] ?? '',
      taxvalue: json['taxvalue'] ?? 0,
      total: json['total'] ?? 0,
      returnid: json['returnid'] ?? '',
      returnvalue: (json['returnvalue'] is num)
          ? (json['returnvalue'] as num).toInt()
          : int.tryParse(json['returnvalue']?.toString() ?? '0') ?? 10,
    );
  }
}

class PurchaseReturnView {
  final String companyid;
  final String companyname;
  final String createdby;
  final String invoice;
  final List<PurchaseReturnItem> items;
  final DateTime submittedat;
  final String supplierid;
  final String suppliername;
  final String waybill;
  String id;
  final int value;

  PurchaseReturnView({
    required this.companyid,
    required this.companyname,
    required this.createdby,
    required this.invoice,
    required this.items,
    required this.submittedat,
    required this.supplierid,
    required this.suppliername,
    required this.waybill,
    required this.id,
    required this.value,
  });

  int get totalReturnValue => items.fold(0, (sum, item) => sum + this.value);

  factory PurchaseReturnView.fromJson(Map<String, dynamic> json, {String? customId}) {
    var itemsList = json['items'] as List;
    List<PurchaseReturnItem> items = itemsList.map((i) => PurchaseReturnItem.fromJson(i)).toList();

    return PurchaseReturnView(
      companyid: json['companyid'] ?? '',
      companyname: json['companyname'] ?? '',
      createdby: json['createdby'] ?? '',
      invoice: json['invoice'] ?? '',
      items: items,
      submittedat: json['submittedat'] is Timestamp
          ? (json['submittedat'] as Timestamp).toDate()
          : DateTime.now(),
      supplierid: json['supplierid'] ?? '',
      suppliername: json['suppliername'] ?? '',
      waybill: json['waybill'] ?? '',
      id: customId ?? json['invoice'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      value: (json['returnvalue'] is num)
          ? (json['returnvalue'] as num).toInt()
          : int.tryParse(json['returnvalue']?.toString() ?? '0') ?? 10,
    );
  }
}
