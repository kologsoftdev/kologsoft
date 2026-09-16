// All item registration validators in one place.
// Each method matches the fieldName key used in the old _validateField switch.

class ItemRegValidators {
  ItemRegValidators._();

  // Required text — used by _buildField default when no custom validator is passed.
  static String? required(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    return null;
  }

  // Retail price — must be > 0 and consistent with cost / box / supplier prices.
  static String? retailPrice({
    required String? value,
    required String costText,
    required String boxPriceText,
    required String supplierPriceText,
    required String boxQtyText,
  }) {
    if (value == null || value.isEmpty) return 'Required';

    final retailPrice = double.tryParse(value) ?? 0;
    final unitCost = double.tryParse(costText) ?? 0;
    final boxPrice = double.tryParse(boxPriceText) ?? 0;
    final supplierPrice = double.tryParse(supplierPriceText) ?? 0;
    final boxQty = double.tryParse(boxQtyText) ?? 1;
    final boxUnitPrice = boxQty > 0 ? boxPrice / boxQty : 0;

    if (retailPrice <= 0) return 'Enter a valid retail price';

    if (boxQty == 1 && unitCost > 0 && retailPrice < unitCost) {
      return 'Retail price GHS$retailPrice must be greater than\n Unit Cost which is GHS${boxPrice / boxQty}';
    }

    if (boxQty > 1) {
      if (retailPrice < boxUnitPrice) {
        return 'Retail price GHS$retailPrice must be equal to \n or greater than Box unit Price GHS${boxPrice / boxQty}';
      }
      if (supplierPrice > 0 && retailPrice < (supplierPrice / boxQty)) {
        return 'Unit retail price GHS$retailPrice must be equal \n to or greater than Supplier Price ${supplierPrice / boxQty}';
      }
      if (retailPrice < unitCost) {
        return 'Retail price GHS$retailPrice must be greater than\n or equal to Unit Cost GHS$unitCost';
      }
    }
    return null;
  }

  // Unit cost price — must not exceed retail price.
  static String? costPrice({
    required String? value,
    required String retailPriceText,
  }) {
    if (value == null || value.isEmpty) return 'Required';
    final costPrice = double.tryParse(value) ?? 0;
    final retailPrice = double.tryParse(retailPriceText) ?? 0;

    if (retailPrice > 0 && costPrice > retailPrice) {
      return 'Unit Cost Price GHS$costPrice must be less than Retail Price GHS$retailPrice';
    }
    return null;
  }

  // Box quantity — must be at least 1.
  static String? boxQty(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final qty = int.tryParse(value) ?? 0;
    if (qty < 1) return 'Box quantity must be at least 1';
    return null;
  }

  // Box (wholesale) price — unit price must sit between cost and retail.
  static String? boxPrice({
    required String? value,
    required String boxQtyText,
    required String retailPriceText,
    required String costPriceText,
  }) {
    if (value == null || value.isEmpty) return 'Required';

    final boxQty = double.tryParse(boxQtyText) ?? 0;
    final boxPrice = double.tryParse(value) ?? 0;
    final retailPrice = double.tryParse(retailPriceText) ?? 0;
    final costPrice = double.tryParse(costPriceText) ?? 0;
    final pricePerUnit = boxQty > 0 ? boxPrice / boxQty : 0;

    if (boxQty == 1) {
      if (costPrice > boxPrice) {
        return 'Cost price  GHS$costPrice \n is more than Box Price GHS$boxPrice';
      }
      if (boxPrice > retailPrice) {
        return 'Box price  GHS$boxPrice \n can more than Retail Price GHS$retailPrice';
      }
      return null;
    }

    if (pricePerUnit > retailPrice) {
      return 'Price per unit which is GHS${boxPrice / boxQty} \n Qty cannot be less than Retail Price';
    }
    if (pricePerUnit < costPrice) {
      return 'Price per unit which is GHS${boxPrice / boxQty} \n Qty cannot be less than Unit Cost Price';
    }
    return null;
  }

  // Supplier price — must be between cost × boxQty and box price.
  static String? supplierPrice({
    required String? value,
    required String boxQtyText,
    required String costPriceText,
    required String boxPriceText,
    required String retailPriceText,
  }) {
    if (value == null || value.isEmpty) return 'Required';

    final boxQty = double.tryParse(boxQtyText) ?? 0;
    if (boxQty <= 0) return null;

    final supplierPrice = double.tryParse(value) ?? 0;
    final unitCost = double.tryParse(costPriceText) ?? 0;
    final boxPrice = double.tryParse(boxPriceText) ?? 0;
    final retailPrice = double.tryParse(retailPriceText) ?? 0;

    if (boxQty == 1) {
      if (unitCost > supplierPrice) {
        return 'Cost price  GHS$unitCost \n is more than Supplier Price GHS$supplierPrice';
      }
      if (supplierPrice > retailPrice) {
        return 'Supplier price  GHS$supplierPrice \n is more than Retail Price GHS$retailPrice';
      }
      return null;
    }

    final minSupplierPrice = unitCost * boxQty;
    if (supplierPrice < minSupplierPrice) {
      return 'Supplier Price GHS$supplierPrice must be more\n or equal to  (${minSupplierPrice.toStringAsFixed(2)})';
    }
    if (supplierPrice > boxPrice) {
      return 'Supplier Price must be less than \n or equal to Box Price';
    }
    return null;
  }

  // Supplier min qty — optional field, always passes.
  static String? supplierMinQty(String? value) => null;

  // Half-box qty — must be between ceil(boxQty/2) and boxQty.
  static String? halfBoxQty({
    required String? value,
    required String boxQtyText,
  }) {
    if (value == null || value.isEmpty) return 'Required';
    final halfBoxQty = int.tryParse(value) ?? 0;
    final boxQty = int.tryParse(boxQtyText) ?? 0;
    if (boxQty == 0) return null;

    final requiredHalfQty = (boxQty / 2).ceil();
    if (halfBoxQty > boxQty) return 'Half Box Qty cannot exceed Box Qty';
    if (halfBoxQty < requiredHalfQty) return 'Half Box Qty must be at least $requiredHalfQty';
    return null;
  }

  // Half-box price — must be between boxPrice/2 and boxPrice.
  static String? halfBoxPrice({
    required String? value,
    required String boxPriceText,
  }) {
    if (value == null || value.isEmpty) return 'Required';
    final halfBoxPrice = double.tryParse(value) ?? 0;
    final boxPrice = double.tryParse(boxPriceText) ?? 0;
    if (boxPrice == 0) return null;

    final requiredHalfPrice = boxPrice / 2;
    if (halfBoxPrice > boxPrice) return 'Half Box Price cannot exceed Box Price';
    if (halfBoxPrice < requiredHalfPrice) {
      return 'Half Box Price must be at least ${requiredHalfPrice.toStringAsFixed(2)}';
    }
    return null;
  }

  // Quarter qty — must be between ceil(boxQty/4) and halfQty, and above packQty.
  static String? quarterQty({
    required String? value,
    required String boxQtyText,
    required String halfQtyText,
    required String packQtyText,
  }) {
    if (value == null || value.isEmpty) return 'Required';
    final quarterQty = int.tryParse(value) ?? 0;
    final boxQty = int.tryParse(boxQtyText) ?? 0;
    final halfQty = int.tryParse(halfQtyText) ?? 0;
    final packQty = int.tryParse(packQtyText) ?? 0;
    if (boxQty == 0) return null;

    final requiredQuarterQty = (boxQty / 4).ceil();
    if (quarterQty > boxQty) return 'Quarter Qty cannot exceed Box Qty';
    if (quarterQty < requiredQuarterQty) return 'Quarter Qty must be at least $requiredQuarterQty';
    if (halfQty > 0 && quarterQty >= halfQty) return 'Quarter Qty must be less than Half Qty';
    if (packQty > 0 && quarterQty <= packQty) return 'Quarter Qty must be greater than Pack Qty';
    return null;
  }

  // Quarter price — must be between boxPrice/4 and halfBoxPrice.
  static String? quarterPrice({
    required String? value,
    required String boxPriceText,
    required String halfBoxPriceText,
  }) {
    if (value == null || value.isEmpty) return 'Required';
    final quarterPrice = double.tryParse(value) ?? 0;
    final boxPrice = double.tryParse(boxPriceText) ?? 0;
    final halfBoxPrice = double.tryParse(halfBoxPriceText) ?? 0;
    if (boxPrice == 0) return null;

    final requiredQuarterPrice = boxPrice / 4;
    if (quarterPrice > boxPrice) return 'Quarter Price cannot exceed Box Price';
    if (quarterPrice < requiredQuarterPrice) {
      return 'Quarter Price must be at least ${requiredQuarterPrice.toStringAsFixed(2)}';
    }
    if (halfBoxPrice > 0 && quarterPrice >= halfBoxPrice) {
      return 'Quarter Price must be less than Half Box Price';
    }
    return null;
  }

  // Pack qty — must divide evenly into boxQty and be less than half/quarter qty.
  static String? packQty({
    required String? value,
    required bool enableBoxPricing,
    required String boxQtyText,
    required String halfQtyText,
    required String quarterQtyText,
    required String packPriceText,
    required String costPriceText,
  }) {
    if (!enableBoxPricing) return null;
    if (value == null || value.isEmpty) return 'Required';

    final packQty = int.tryParse(value) ?? 0;
    final boxQty = int.tryParse(boxQtyText) ?? 0;
    final halfQty = int.tryParse(halfQtyText) ?? 0;
    final quarterQty = int.tryParse(quarterQtyText) ?? 0;

    if (boxQty > 0 && packQty > 0 && boxQty % packQty != 0) {
      return 'Box Qty must be divisible by Pack Qty';
    }
    if (boxQty > 0 && packQty > boxQty) return 'Pack Qty cannot exceed Box Qty';
    if (halfQty > 0 && packQty >= halfQty) return 'Pack Qty must be less than Half Qty';
    if (quarterQty > 0 && packQty >= quarterQty) return 'Pack Qty must be less than Quarter Qty';

    final packUnitPrice = double.tryParse(packPriceText) ?? 0;
    final unitCost = double.tryParse(costPriceText) ?? 0;
    final totalPackPrice = packUnitPrice * boxQty;
    final totalUnitCost = unitCost * boxQty;

    if (totalPackPrice < totalUnitCost) {
      return 'Pack unit price × Box Qty must be ≥ Unit Cost × Box Qty';
    }
    return null;
  }

  // Pack price — unit price must sit between cost and retail, not exceed box unit price.
  static String? packPrice({
    required String? value,
    required String boxPriceText,
    required String boxQtyText,
    required String packQtyText,
    required String retailPriceText,
    required String costPriceText,
  }) {
    if (value == null || value.isEmpty) return 'Required';

    final packPrice = double.tryParse(value) ?? 0;
    final boxPrice = double.tryParse(boxPriceText) ?? 0;
    final boxQty = double.tryParse(boxQtyText) ?? 0;
    final packQty = double.tryParse(packQtyText) ?? 0;
    final retailPrice = double.tryParse(retailPriceText) ?? 0;
    final unitCostPrice = double.tryParse(costPriceText) ?? 0;

    if (boxQty == 0 || packQty == 0 || boxPrice == 0) return null;

    final unitBoxPrice = boxPrice / boxQty;
    final packUnitPrice = packPrice / packQty;

    if (packUnitPrice > retailPrice ||
        packUnitPrice < unitCostPrice ||
        packUnitPrice < unitBoxPrice) {
      return 'Please check Unit(box/cost/retail) price';
    }
    return null;
  }
}