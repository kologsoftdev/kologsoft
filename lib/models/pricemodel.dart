class PricingRuleModel {
  final String type;
  final int minQty;
  final int maxQty;
  final double price;

  PricingRuleModel({
    required this.type,
    required this.minQty,
    required this.maxQty,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'minQty': minQty,
      'maxQty': maxQty,
      'price': price,
    };
  }

  factory PricingRuleModel.fromMap(Map<String, dynamic> map) {
    return PricingRuleModel(
      type: map['type'],
      minQty: (map['minQty'] ?? 0).toDouble(),
      maxQty: (map['maxQty'] ?? 0).toDouble(),
      price: (map['price'] ?? 0).toDouble(),
    );
  }
}
