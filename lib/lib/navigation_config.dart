import 'package:flutter/material.dart';
import '../screens/shopping_list_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/firebase_debug_screen.dart';
import '../screens/barcode_scanner_screen.dart'; // Importiere BarcodeScannerScreen
import '../screens/testscreen.dart'; // Importiere TestRefsScreen
// weitere imports...

class AppSubPage {
  final String id;
  final String title;
  final IconData icon;
  final Widget screen;

  const AppSubPage({
    required this.id,
    required this.title,
    required this.icon,
    required this.screen,
  });
}

class AppNavigationCategory {
  final String title;
  final List<AppSubPage> pages;

  const AppNavigationCategory({
    required this.title,
    required this.pages,
  });
}

final List<AppNavigationCategory> appNavigationStructure = [
  AppNavigationCategory(
    title: 'Essen',
    
    pages: [
      AppSubPage(
        id: 'scanner',
        title: 'Scanner',
        icon: Icons.barcode_reader,
        screen: BarcodeScannerScreen(),
      ),
      AppSubPage(
        id: 'shopping_list',
        title: 'Einkaufsliste',
        icon: Icons.shopping_cart,
        screen: ShoppingListScreen(),
      ),
      AppSubPage(
        id: 'inventory',
        title: 'Inventar',
        icon: Icons.kitchen,
        screen: InventoryScreen(),
      ),
    ],
  ),
  AppNavigationCategory(
    title: 'To Do',
    pages: [
      AppSubPage(
        id: 'todo_today',
        title: 'Heute',
        icon: Icons.today,
        screen: FirebaseDebugScreen(), // Später ToDoTodayScreen()
      ),
      AppSubPage(
        id: 'todo_week',
        title: 'Diese Woche',
        icon: Icons.date_range,
        screen: TestRefsScreen(), // Später ToDoWeekScreen()
      ),
    ],
  ),
];

