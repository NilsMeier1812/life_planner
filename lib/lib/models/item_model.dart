class Item {
  final String id;
  final String name;
  final String categoryId;

  Item({required this.id, required this.name, required this.categoryId});

  factory Item.fromMap(String id, Map<String, dynamic> data) {
    return Item(
      id: id,
      name: data['name'] ?? '',
      categoryId: data['category'] ?? '',
    );
  }
}
