import 'package:flutter/material.dart';

IconData getIcon(String name) {
  switch (name) {
    case 'local_drink':
      return Icons.local_drink;
    case 'lunch_dining':
      return Icons.lunch_dining;
    case 'shopping_cart':
      return Icons.shopping_cart;
    // Weitere Icons hier ergänzen
    default:
      return Icons.help_outline;
  }
}
