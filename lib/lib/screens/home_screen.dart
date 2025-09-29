import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation_config.dart';
import '../custom_drawer.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late AppSubPage currentPage;

  @override
  void initState() {
    super.initState();
    _loadLastPage();
  }

  Future<void> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPageId = prefs.getString('last_page_id');

    final allPages = appNavigationStructure.expand((cat) => cat.pages).toList();
    final defaultPage = allPages.first;

    setState(() {
      currentPage = allPages.firstWhere(
        (page) => page.id == lastPageId,
        orElse: () => defaultPage,
      );
    });
  }

  void _navigateTo(AppSubPage page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_page_id', page.id);

    setState(() {
      currentPage = page;
    });
    Navigator.pop(context); // Drawer schließen
  }

  @override
  Widget build(BuildContext context) {
    if (currentPage == null) return const CircularProgressIndicator(); // für initial load

    return Scaffold(
      appBar: AppBar(title: Text(currentPage.title)),
      drawer: CustomDrawer(onPageSelected: _navigateTo),
      body: currentPage.screen,
    );
  }
}
