import 'package:flutter/foundation.dart';
import '../models/itemregmodel.dart';
import '../models/cart_item_model.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  int get totalQuantity {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    return _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void addItem(ItemModel product, int quantity, String priceMode) {
    final key = '${product.id}_$priceMode';

    if (_items.containsKey(key)) {
      _items.update(
        key,
        (existingItem) => CartItem(
          product: existingItem.product,
          quantity: existingItem.quantity + quantity,
          priceMode: existingItem.priceMode,
        ),
      );
    } else {
      _items.putIfAbsent(
        key,
        () => CartItem(
          product: product,
          quantity: quantity,
          priceMode: priceMode,
        ),
      );
    }
    notifyListeners();
  }

  void removeItem(String key) {
    _items.remove(key);
    notifyListeners();
  }

  void updateQuantity(String key, int quantity) {
    if (_items.containsKey(key)) {
      if (quantity <= 0) {
        _items.remove(key);
      } else {
        _items[key]!.quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  bool isInCart(String productId, String priceMode) {
    final key = '${productId}_$priceMode';
    return _items.containsKey(key);
  }

  int getItemQuantity(String productId, String priceMode) {
    final key = '${productId}_$priceMode';
    return _items[key]?.quantity ?? 0;
  }
}
