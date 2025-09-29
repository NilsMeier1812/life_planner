import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryAdminScreen extends StatefulWidget {
  const CategoryAdminScreen({super.key});

  @override
  State<CategoryAdminScreen> createState() => _CategoryAdminScreenState();
}

class _CategoryAdminScreenState extends State<CategoryAdminScreen> {
  List<QueryDocumentSnapshot> categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final snap = await FirebaseFirestore.instance
        .collection('categories')
        .orderBy('order')
        .get();
    setState(() => categories = snap.docs);
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);

    for (int i = 0; i < categories.length; i++) {
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(categories[i].id)
          .update({'order': i});
    }

    _loadCategories();
  }

  void _editCategory(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = doc.id;
    final nameController = TextEditingController(text: name);
    int selectedIcon = data['icon'];
    String selectedColor = data['color'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kategorie bearbeiten"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            TextField(
              decoration: const InputDecoration(labelText: "Icon (CodePoint)"),
              keyboardType: TextInputType.number,
              onChanged: (val) => selectedIcon = int.tryParse(val) ?? selectedIcon,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Farbe (0xff...)"),
              onChanged: (val) => selectedColor = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbrechen")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('categories').doc(nameController.text).set({
                'icon': selectedIcon,
                'color': selectedColor,
                'order': data['order']
              });
              if (nameController.text != name) {
                await FirebaseFirestore.instance.collection('categories').doc(name).delete();
              }
              Navigator.pop(ctx);
              _loadCategories();
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  void _addCategory() {
    final nameController = TextEditingController();
    int selectedIcon = Icons.star.codePoint;
    String selectedColor = "0xff000000";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Neue Kategorie"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            TextField(
              decoration: const InputDecoration(labelText: "Icon (CodePoint)"),
              keyboardType: TextInputType.number,
              onChanged: (val) => selectedIcon = int.tryParse(val) ?? selectedIcon,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Farbe (0xff...)"),
              onChanged: (val) => selectedColor = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbrechen")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('categories').doc(nameController.text).set({
                'icon': selectedIcon,
                'color': selectedColor,
                'order': categories.length,
              });
              Navigator.pop(ctx);
              _loadCategories();
            },
            child: const Text("Hinzufügen"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kategorien verwalten"),
        actions: [
          IconButton(onPressed: _addCategory, icon: const Icon(Icons.add)),
        ],
      ),
      body: ReorderableListView(
        onReorder: _onReorder,
        children: [
          for (final doc in categories)
            ListTile(
              key: ValueKey(doc.id),
              leading: CircleAvatar(
                backgroundColor: Color(int.parse(doc['color'])),
                child: Icon(IconData(doc['icon'], fontFamily: 'MaterialIcons'), color: Colors.white),
              ),
              title: Text(doc.id),
              trailing: const Icon(Icons.drag_handle),
              onTap: () => _editCategory(doc),
            )
        ],
      ),
    );
  }
}
