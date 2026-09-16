

class ItemHistoryEntry {
  final DateTime? date;
  final String? invoiceDate;
  final String? waybill;
  final String type;
  final String sign;
  final String item;
  final double qty;
  final double price;
  final double total;
  final String mode;
  final String branch;
  final String staff;
  final String transactionid;

  const ItemHistoryEntry({
    required this.date,
     this.invoiceDate,
     this.waybill,
    required this.type,
    required this.sign,
    required this.item,
    required this.qty,
    required this.price,
    required this.total,
    required this.mode,
    required this.branch,
    required this.staff,
    required this.transactionid,
  });
}


