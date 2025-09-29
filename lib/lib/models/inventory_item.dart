import 'product.dart';

class InventoryItem {
  final Product product;
  int amount;

  InventoryItem({
    required this.product,
    required this.amount,
  });
}
