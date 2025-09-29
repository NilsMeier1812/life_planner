class Product {
  final String name;
  final String category;
  final String storageLocation; // z. B. "Kühlschrank"
  final int defaultAmount;
  final String barcode;

  Product({
    required this.name,
    required this.category,
    required this.storageLocation,
    required this.defaultAmount,
    required this.barcode,
  });
}
