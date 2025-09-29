import '../models/product.dart';

final List<Product> sampleProducts = [
  Product(
    name: "Milch",
    category: "Kühlware",
    storageLocation: "Kühlschrank",
    defaultAmount: 1,
    barcode: "1234567890",
  ),
  Product(
    name: "Mais",
    category: "Konserve",
    storageLocation: "Regal",
    defaultAmount: 3,
    barcode: "0987654321",
  ),
  Product(
    name: "Pizza",
    category: "Tiefkühl",
    storageLocation: "Gefrierschrank",
    defaultAmount: 2,
    barcode: "1111111111",
  ),
];
