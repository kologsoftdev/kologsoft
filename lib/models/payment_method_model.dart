class PaymentMethod {
  final String name;
  final List<AssetAccount> linkedAssetAccounts;

  PaymentMethod({required this.name, required this.linkedAssetAccounts});
}

class AssetAccount {
  final String name;

  AssetAccount({required this.name});
}
