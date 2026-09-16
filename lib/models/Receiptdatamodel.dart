
class ReceiptItem {
  final String name;
  final double qty;
  final double price;
  final String mode;
  final bool isService;
  ReceiptItem(
       {
        required this.name,
        required this.qty,
        required this.price,
        required this.mode,
        this.isService = false,
      }
   );
}

class ReceiptData {
  final String companyName;
  final String receiptName;
  final String contact;
  final String Suppliertin;
  final String? transactionId;
  final String? branch;
  final String? address;
  final String Customertin;
  final String customername;
  final DateTime datetime;
  final String email;
  final String receiptNumber;
  final String barcode;

  final String cashier;
  final String paymentMethod;

  // Items
  final List<ReceiptItem> items;

  // Payment info
  final double amountPaid;
  final double discount;
  final int vatPercent;
  final double vatInclusiveAmount;
  final double subTotal;
  final double vatAmount;
  final double payable;
  final double change;

  ReceiptData({
    required this.companyName,
    required this.contact,
    required this.customername,
    required this.datetime,
    required this.email,
    required this.receiptNumber,
    required this.barcode,

    required this.cashier,
    required this.paymentMethod,
    required this.items,
    required this.amountPaid,
    required this.discount,
    required this.vatPercent,
    required this.vatInclusiveAmount,
    required this.subTotal,
    required this.vatAmount,
    required this.payable,
    required this.change,
    required this.Customertin,
    required this.Suppliertin,
    required this.receiptName,
     this.branch,
    this.address,
    this.transactionId,
  });


}