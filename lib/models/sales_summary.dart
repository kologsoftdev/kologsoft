class SalesSummary {
   double total=0.00;
   double totalToday=0.00;
   double cash=0.00;
   double credit=0.00;
   double momo=0.00;
  final Map<String, double> branchTotals;

  SalesSummary({
    required this.total,
    required this.totalToday,
    required this.cash,
    required this.credit,
    required this.momo,
    required this.branchTotals,
  });
}
