class CashDenomination {
  final double value;
  int count;

  CashDenomination({
    required this.value,
    this.count = 0,
  });

  double get total => value * count;
}