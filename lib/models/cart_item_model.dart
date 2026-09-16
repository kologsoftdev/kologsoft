import '../../models/itemregmodel.dart';

class CartItem {
  final ItemModel product;
  int quantity;
  final String priceMode; // 'retail' or 'wholesale'

  CartItem({
    required this.product,
    required this.quantity,
    required this.priceMode,
  });

  double get price {
    return double.parse(
      priceMode == 'retail' ? product.retailprice : product.wholesaleprice,
    );
  }

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'productName': product.name,
      'quantity': quantity,
      'priceMode': priceMode,
      'price': price,
      'totalPrice': totalPrice,
    };
  }
}
