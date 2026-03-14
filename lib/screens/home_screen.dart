import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../navigation_config.dart'; // Annahme: Pfad muss ggf. angepasst werden
import '../../custom_drawer.dart'; // Annahme: Pfad muss ggf. angepasst werden

/// The main screen of the app, which acts as a host for other pages.
/// It remembers the last visited page and displays it on startup.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Use a nullable type to handle the initial loading state gracefully.
  AppSubPage? _currentPage;

  @override
  void initState() {
    super.initState();
    _loadLastPage();
  }

  /// Loads the ID of the last visited page from SharedPreferences and sets the state.
  Future<void> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPageId = prefs.getString('last_page_id');

    // Flatten the navigation structure to find the page by its ID.
    final allPages = appNavigationStructure.expand((category) => category.pages).toList();
    final defaultPage = allPages.first;

    setState(() {
      _currentPage = allPages.firstWhere(
        (page) => page.id == lastPageId,
        orElse: () => defaultPage, // Fallback to the first page if not found
      );
    });
  }

  /// Updates the current page and saves its ID to SharedPreferences.
  void _navigateTo(AppSubPage page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_page_id', page.id);

    setState(() {
      _currentPage = page;
    });
    Navigator.pop(context); // Close the drawer after selection
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator until the current page has been determined.
    if (_currentPage == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Once loaded, build the main scaffold with the current page.
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPage!.title),
      ),
      drawer: CustomDrawer(onPageSelected: _navigateTo),
      body: _currentPage!.screen,
    );
  }
}

