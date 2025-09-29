import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<Map<String, dynamic>> shoppingItems = [];
  List<Map<String, dynamic>> searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('shopping_list').get();

    List<Map<String, dynamic>> result = [];

    for (var doc in snapshot.docs) {
      final itemId = doc['itemId'] as String;
      final quantity = doc.data().containsKey('quantity')
          ? doc['quantity'].toString()
          : "";

      final itemSnap =
          await FirebaseFirestore.instance.collection('items').doc(itemId).get();
      if (!itemSnap.exists) continue;

      final itemData = itemSnap.data()!;
      final categoryId = itemData['category'];

      final categorySnap = await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .get();
      if (!categorySnap.exists) continue;

      final categoryData = categorySnap.data()!;

      result.add({
        'docId': doc.id,
        'itemId': itemId,
        'name': itemData['name'],
        'quantity': quantity,
        'icon': categoryData['icon'],
        'color': Color(int.parse(categoryData['color'])),
        'category': categoryId,
        'categoryOrder': categoryData['order'] ?? 999,
      });
    }

    result.sort((a, b) {
      final orderCompare = (a['categoryOrder'] as int).compareTo(b['categoryOrder'] as int);
      if (orderCompare != 0) return orderCompare;
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    setState(() {
      shoppingItems = result;
    });
  }

  Future<void> _deleteItem(String docId) async {
    await FirebaseFirestore.instance.collection('shopping_list').doc(docId).delete();
    _loadItems();
  }

  Future<void> _markAsBought(Map<String, dynamic> item) async {
    await FirebaseFirestore.instance.collection('inventory').add({
      'itemId': item['itemId'],
      'quantity': int.tryParse(item['quantity']) ?? 1,
    });
    await _deleteItem(item['docId']);
  }

  Future<void> _updateQuantity(String docId, String value) async {
    await FirebaseFirestore.instance.collection('shopping_list').doc(docId).update({
      'quantity': value,
    });
  }

  Future<void> _addNewItem(String name) async {
    final categoriesSnap = await FirebaseFirestore.instance.collection('categories').get();
    if (categoriesSnap.docs.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Kategorie für "$name" auswählen'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categoriesSnap.docs.map((doc) {
              final data = doc.data();
              return ElevatedButton.icon(
                onPressed: () async {
                  final newItemRef = FirebaseFirestore.instance.collection('items').doc(name);
                  await newItemRef.set({
                    'name': name,
                    'category': doc.id,
                    'standardQuantity': '1'
                  });
                  Navigator.of(ctx).pop();
                  await _addItemToShoppingList(name);
                  _searchController.clear();
                  setState(() {
                    isSearching = false;
                    searchResults = [];
                  });
                },
                icon: Icon(
                  IconData(data['icon'], fontFamily: 'MaterialIcons'),
                  color: Colors.white,
                ),
                label: Text(doc.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(int.parse(data['color'])),
                  foregroundColor: Colors.white,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _addItemToShoppingList(String itemId) async {
    final already = shoppingItems.firstWhere(
      (el) => el['itemId'] == itemId,
      orElse: () => {},
    );

    if (already.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${already['name']} ist bereits auf der Liste'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final newQty = (int.tryParse(already['quantity']) ?? 1) + 1;
                await _updateQuantity(already['docId'], newQty.toString());
                _loadItems();
              },
              child: const Text('+1'),
            ),
          ],
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('shopping_list').add({
      'itemId': itemId,
      'quantity': '1',
    });
    _loadItems();
  }

  Future<List<Map<String, dynamic>>> _searchItems(String query) async {
    final snapshot = await FirebaseFirestore.instance.collection('items').get();
    List<Map<String, dynamic>> result = [];
    for (var doc in snapshot.docs) {
      final name = doc['name'].toString();
      if (!name.toLowerCase().contains(query.toLowerCase())) continue;

      final categoryId = doc['category'];
      final categorySnap = await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .get();
      final categoryData = categorySnap.data();
      if (categoryData == null) continue;

      result.add({
        'itemId': doc.id,
        'name': name,
        'icon': categoryData['icon'],
        'color': Color(int.parse(categoryData['color'])),
      });
    }
    return result;
  }

  void _onSearchChanged(String value) async {
    setState(() => isSearching = value.isNotEmpty);
    if (value.isEmpty) {
      setState(() => searchResults = []);
      return;
    }
    final results = await _searchItems(value);
    setState(() => searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Einkaufsliste"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CategoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: "Suche hinzufügen",
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (isSearching)
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: Text('„${_searchController.text}“ hinzufügen'),
                    leading: const Icon(Icons.add),
                    onTap: () => _addNewItem(_searchController.text),
                  ),
                  ...searchResults.map((item) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item['color'],
                          child: Icon(
                            IconData(item['icon'], fontFamily: 'MaterialIcons'),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(item['name']),
                        onTap: () {
                          _addItemToShoppingList(item['itemId']);
                          _searchController.clear();
                          setState(() {
                            searchResults = [];
                            isSearching = false;
                          });
                        },
                      )),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: shoppingItems.length,
                itemBuilder: (context, index) {
                  final item = shoppingItems[index];

                  return Dismissible(
                    key: ValueKey(item['docId']),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _deleteItem(item['docId']),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item['color'],
                        child: Icon(
                          IconData(item['icon'], fontFamily: 'MaterialIcons'),
                          color: Colors.white,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(item['name'])),
                          SizedBox(
                            width: 30,
                            child: TextFormField(
                              initialValue: item['quantity'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.all(6),
                              ),
                              onChanged: (value) =>
                                  _updateQuantity(item['docId'], value),
                            ),
                          ),
                          Checkbox(
                            value: false,
                            onChanged: (_) => _markAsBought(item),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Neue Admin-Ansicht wird gleich aktualisiert...

// Neue Admin-Ansicht für Kategorien
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
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
    Color selectedColor = Colors.black;
    Map<String, dynamic>? selectedIcon;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Neue Kategorie"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Name"),
                  ),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerLeft, child: Text("Farbe auswählen")),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Colors.red,
                      Colors.green,
                      Colors.blue,
                      Colors.orange,
                      Colors.purple,
                      Colors.yellow,
                      Colors.cyan,
                      Colors.teal,
                      Colors.brown,
                      Colors.grey,
                      Colors.black,
                    ].map((color) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerLeft, child: Text("Icon auswählen")),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('icons').get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text("Keine Icons gefunden.");
                      }

                      final docs = snapshot.data!.docs;

                      return SizedBox(
                        height: 200,
                        child: GridView.count(
                          crossAxisCount: 6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          children: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final iconData = IconData(
                              data['codePoint'],
                              fontFamily: data['fontFamily'],
                            );

                            final isSelected = selectedIcon != null &&
                                selectedIcon!['codePoint'] == data['codePoint'] &&
                                selectedIcon!['fontFamily'] == data['fontFamily'];

                            return GestureDetector(
                              onTap: () => setState(() => selectedIcon = data),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.grey.shade300 : null,
                                  borderRadius: BorderRadius.circular(6),
                                  border: isSelected
                                      ? Border.all(color: Colors.black, width: 2)
                                      : null,
                                ),
                                child: Center(
                                  child: Icon(iconData, size: 28),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbrechen")),
              TextButton(
                onPressed: () async {
                  if (selectedIcon == null || nameController.text.trim().isEmpty) return;

                  await FirebaseFirestore.instance
                      .collection('categories')
                      .doc(nameController.text.trim())
                      .set({
                    'codePoint': selectedIcon!['codePoint'],
                    'fontFamily': selectedIcon!['fontFamily'],
                    'color': selectedColor.value.toRadixString(16),
                    'order': categories.length,
                  });

                  Navigator.pop(ctx);
                  _loadCategories();
                },
                child: const Text("Hinzufügen"),
              ),
            ],
          );
        });
      },
    );
  }



  void _confirmCategory(String name, Color color, String iconName, IconData iconData) async {
    await FirebaseFirestore.instance.collection('categories').doc(name).set({
      'icon': iconName,
      'color': color.value.toRadixString(16),
      'order': categories.length,
    });
    _loadCategories();
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