

class SalesFormValidators {
  SalesFormValidators._(); // static-only helper

  //Field validators

  // Barcode / search field – must not be blank.
  static String? barcode(String? value) {
    if (value == null || value.isEmpty) return 'Barcode required';
    return null;
  }

  // Item name field –
  static String? item(String? value) {
    if (value == null || value.isEmpty) return 'Item required';
    return null;
  }

  /// Sales mode dropdown
  static String? salesMode(String? value) {
    if (value == null) return 'Please select sales mode';
    return null;
  }

  /// Price mode dropdown (Retail / Wholesale / …)
  static String? priceMode(String? value) {
    if (value == null) return 'Please select price mode';
    return null;
  }

  /// Price field – must be a number > 0.
  static String? price(String? value) {
    if (value == null || value.isEmpty) return 'Enter amount';
    final amount = double.tryParse(value);
    if (amount == null || amount < 1) return 'Amount must be greater than zero';
    return null;
  }

  /// Quantity field – positive number, no leading zeros on integers.
  static String? quantity(String? value) {
    if (value == null || value.isEmpty) return 'Enter quantity';
    final qty = double.tryParse(value);
    if (qty == null || qty <= 0) return 'Quantity must be greater than zero';
    final validFormat = RegExp(r'^(0|[1-9]\d*)(\.\d+)?$').hasMatch(value);
    if (!validFormat) return 'Use decimals without leading zeros';
    return null;
  }

  /// Warehouse dropdown – must have a selection.
  static String? warehouse(String? value) {
    if (value == null || value.isEmpty) return 'Select warehouse to sell from';
    return null;
  }
}