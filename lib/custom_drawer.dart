import 'package:flutter/material.dart';
import 'package:life_planner/navigation_config.dart';

class CustomDrawer extends StatelessWidget {
  final void Function(AppSubPage page) onPageSelected;

  const CustomDrawer({super.key, required this.onPageSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Menü', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
          ...appNavigationStructure.map((category) => ExpansionTile(
                title: Text(category.title),
                children: category.pages
                    .map((page) => ListTile(
                          leading: Icon(page.icon),
                          title: Text(page.title),
                          onTap: () => onPageSelected(page),
                        ))
                    .toList(),
              )),
        ],
      ),
    );
  }
}
