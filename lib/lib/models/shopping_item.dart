class ShoppingItem {
  final String name;
  final String category;
  bool isChecked;

  ShoppingItem({
    required this.name,
    required this.category,
    this.isChecked = false,
  });
}
