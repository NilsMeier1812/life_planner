import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final int colorHex;
  final String iconName;

  Category({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
  });

  factory Category.fromMap(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: data['name'] ?? '',
      colorHex: data['color'] ?? 0xFF000000,
      iconName: data['icon'] ?? 'help_outline',
    );
  }

  Color get color => Color(colorHex);
}
