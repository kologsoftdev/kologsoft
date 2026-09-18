import 'package:cloud_firestore/cloud_firestore.dart';

class StockModel {
  final String branchId;
  final String branchName;
  final String company;
  final String companyId;
  final DateTime createdAt;
  final String createdBy;
  final double discount;
  final String docId;
  final double gross;
  final String invoice;
  final DateTime invoiceDate;
  final List<InvoiceItem> items;
  final double netVal;
  final String purchaseType;
  final String staffBranch;
  final String staffBranchId;
  final String supplierId;
  final String supplierName;
  final double tax;
  final String transactionId;
  final String waybill;
  final bool purchasereturn;

  StockModel({
    required this.branchId,
    required this.branchName,
    required this.company,
    required this.companyId,
    required this.createdAt,
    required this.createdBy,
    required this.discount,
    required this.docId,
    required this.gross,
    required this.invoice,
    required this.invoiceDate,
    required this.items,
    required this.netVal,
    required this.purchaseType,
    required this.staffBranch,
    required this.staffBranchId,
    required this.supplierId,
    required this.supplierName,
    required this.tax,
    required this.transactionId,
    required this.waybill,
    required this.purchasereturn,
  });

  StockModel copyWith({
    bool? purchasereturn,
  }) {
    return StockModel(
      branchId: branchId,
      branchName: branchName,
      company: company,
      companyId: companyId,
      createdAt: createdAt,
      createdBy: createdBy,
      discount: discount,
      docId: docId,
      gross: gross,
      invoice: invoice,
      invoiceDate: invoiceDate,
      items: items,
      netVal: netVal,
      purchaseType: purchaseType,
      staffBranch: staffBranch,
      staffBranchId: staffBranchId,
      supplierId: supplierId,
      supplierName: supplierName,
      tax: tax,
      transactionId: transactionId,
      waybill: waybill,
      purchasereturn: purchasereturn ?? this.purchasereturn,
    );
  }
  factory StockModel.fromMap(Map<String, dynamic> map, String id) {
    return StockModel(
      branchId: map['branchid'] ?? '',
      branchName: map['branchname'] ?? '',
      company: map['company'] ?? '',
      companyId: map['companyid'] ?? '',
      createdAt: (map['createdat'] as Timestamp).toDate(),
      createdBy: map['createdby'] ?? '',
      discount: map['discount'] ?? 0,
      docId: map['docid'] ?? '',
      gross: map['gross'] ?? 0,
      invoice: map['invoice'] ?? '',
      invoiceDate: map['invoicedate'] != null
          ? (map['invoicedate'] as Timestamp).toDate()
          : DateTime.now(),
      items: (map['items'] as List<dynamic>)
          .map((item) => InvoiceItem.fromMap(item))
          .toList(),
      netVal: map['netval'] ?? 0,
      purchaseType: map['purchasetype'] ?? '',
      staffBranch: map['staffbranch'] ?? '',
      staffBranchId: map['staffbranchid'] ?? '',
      supplierId: map['supplierid'] ?? '',
      supplierName: map['suppliername'] ?? '',
      tax: map['tax'] ?? 0,
      transactionId: map['transactionid'] ?? '',
      waybill: map['waybill'] ?? '',
      purchasereturn: map['purchasereturn'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchid': branchId,
      'branchname': branchName,
      'company': company,
      'companyid': companyId,
      'createdat': createdAt,
      'createdby': createdBy,
      'discount': discount,
      'docid': docId,
      'gross': gross,
      'invoice': invoice,
      'invoicedate': invoiceDate,
      'items': items.map((e) => e.toMap()).toList(),
      'netval': netVal,
      'purchasetype': purchaseType,
      'staffbranch': staffBranch,
      'staffbranchid': staffBranchId,
      'supplierid': supplierId,
      'suppliername': supplierName,
      'tax': tax,
      'transactionid': transactionId,
      'waybill': waybill,
      'purchasereturn': purchasereturn,
    };
  }
}

class InvoiceItem {
  final String returnStatus;
  final String barcode;
  final double discount;
  final String item;
  final String itemId;
  final double modeQty;
  final double pieces;
  final double price;
  final double quantity;
  final String stockingMode;
  final double taxAmount;
  final String taxType;
  final double taxValue;
  final double total;
  final double boxpieces;

  InvoiceItem({
    required this.returnStatus,
    required this.barcode,
    required this.discount,
    required this.item,
    required this.itemId,
    required this.modeQty,
    required this.pieces,
    required this.price,
    required this.quantity,
    required this.stockingMode,
    required this.taxAmount,
    required this.taxType,
    required this.taxValue,
    required this.total,
    required this.boxpieces,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      returnStatus: map['returnStatus'] ?? '',
      barcode: map['barcode'] ?? '',
      discount: map['discount'] ?? 0,
      item: map['item'] ?? '',
      itemId: map['itemid'] ?? 'N/A',
      modeQty: map['modeqty'] ?? 0,
      pieces: map['pieces'] ?? 0,
      price: map['price'] ?? 0,
      quantity: map['quantity'] ?? 0,
      stockingMode: map['stockingmode'] ?? '',
      taxAmount: map['taxamount'] ?? 0,
      taxType: map['taxtype'] ?? '',
      taxValue: map['taxvalue'] ?? 0,
      total: map['total'] ?? 0,
      boxpieces: map['boxpieces'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'returnStatus': returnStatus,
      'barcode': barcode,
      'discount': discount,
      'item': item,
      'itemid': itemId,
      'modeqty': modeQty,
      'pieces': pieces,
      'price': price,
      'quantity': quantity,
      'stockingmode': stockingMode,
      'taxamount': taxAmount,
      'taxtype': taxType,
      'taxvalue': taxValue,
      'total':total,
      'boxpieces':boxpieces,
    };
  }
}
