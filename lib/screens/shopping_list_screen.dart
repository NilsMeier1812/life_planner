import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'categories_management_screen.dart';
import '../utils/helpers.dart';

// Data model for a fully resolved shopping list item to avoid Maps and Futures in the UI.
class ResolvedShoppingItem {
  final String id;
  final DocumentReference itemRef;
  final String itemName;
  final num quantity;
  final String categoryName;
  final Color categoryColor;
  final int categoryIcon;
  final int categoryOrder;
  final Map<String, dynamic> originalData;

  ResolvedShoppingItem({
    required this.id,
    required this.itemRef,
    required this.itemName,
    required this.quantity,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.categoryOrder,
    required this.originalData,
  });

  factory ResolvedShoppingItem.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ResolvedShoppingItem(
      id: doc.id,
      itemRef: data['itemID'] as DocumentReference,
      itemName: doc.id, // The document ID is the item name
      quantity: data['quantity'] as num? ?? 1,
      categoryName: data['categoryName'] as String? ?? 'Unbekannt',
      categoryColor: parseColor(data['categoryColor'] as String? ?? '#CCCCCC'),
      categoryIcon: data['categoryIcon'] as int? ?? Icons.help.codePoint,
      categoryOrder: data['categoryOrder'] as int? ?? 999,
      originalData: data,
    );
  }
}

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  // State to manage which item's category icon is tapped for editing.
  String? _selectedItemIdForCategoryEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufsliste'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoriesManagementScreen()),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        // Deselect icon when tapping anywhere on the body
        onTap: () => setState(() => _selectedItemIdForCategoryEdit = null),
        child: Column(
          children: [
            const _SearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // The stream now directly fetches the denormalized shopping list.
                // No more nested FutureBuilders are needed.
                stream: FirebaseFirestore.instance.collection('shopping_list').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Fehler: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Die Einkaufsliste ist leer'));
                  }

                  // Map snapshots to our strong-typed model and sort them.
                  final items = snapshot.data!.docs
                      .map((doc) => ResolvedShoppingItem.fromSnapshot(doc))
                      .toList()
                    ..sort((a, b) {
                      int orderComp = a.categoryOrder.compareTo(b.categoryOrder);
                      if (orderComp != 0) return orderComp;
                      return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
                    });

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildShoppingListItem(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoppingListItem(ResolvedShoppingItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteShoppingItem(item),
      child: ListTile(
        leading: GestureDetector(
          onTap: () {
            setState(() {
              // Toggle selection for category edit popup
              if (_selectedItemIdForCategoryEdit == item.id) {
                _showCategoryPopup(item);
              } else {
                _selectedItemIdForCategoryEdit = item.id;
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.categoryColor,
              border: _selectedItemIdForCategoryEdit == item.id
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                  : null,
            ),
            child: Icon(IconData(item.categoryIcon, fontFamily: 'MaterialIcons'), color: Colors.black),
          ),
        ),
        title: Text(item.itemName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                setState(() => _selectedItemIdForCategoryEdit = null);
                _showQuantityDialog(item);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Text(
                  '${item.quantity} x',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            Checkbox(
              value: false,
              onChanged: (value) {
                setState(() => _selectedItemIdForCategoryEdit = null);
                if (value == true) {
                  _moveToInventory(item);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Data Modification Methods ---

  Future<void> _deleteShoppingItem(ResolvedShoppingItem item) async {
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection('shopping_list').doc(item.id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${item.itemName}" gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            // Restore with the original data
            await firestore.collection('shopping_list').doc(item.id).set(item.originalData);
          },
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Fehler beim Löschen: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }
  
  Future<void> _moveToInventory(ResolvedShoppingItem item) async {
    final firestore = FirebaseFirestore.instance;
    final inventoryRef = firestore.collection('inventory').doc(item.id);

    try {
      await firestore.runTransaction((transaction) async {
        final inventorySnap = await transaction.get(inventoryRef);

        if (inventorySnap.exists) {
          // If item exists in inventory, just update quantity
          final currentQuantity = inventorySnap.data()?['quantity'] as num? ?? 0;
          transaction.update(inventoryRef, {'quantity': currentQuantity + item.quantity});
        } else {
          // If not, create a new inventory item
          // We assume new items go to 'unsorted' by default (storage: null)
          transaction.set(inventoryRef, {
            'itemId': item.itemRef, // Reference to the 'items' collection
            'itemName': item.itemName, // Denormalized name for searching/display
            'quantity': item.quantity,
            'storage': null, 
            'expiration': null,
          });
        }
        
        // Delete from shopping list
        transaction.delete(firestore.collection('shopping_list').doc(item.id));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artikel ins Inventar verschoben')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }


  // --- Dialogs ---

  Future<void> _showQuantityDialog(ResolvedShoppingItem item) async {
    final controller = TextEditingController(text: item.quantity.toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Menge ändern'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
          decoration: const InputDecoration(labelText: 'Menge'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              final newQuantity = num.tryParse(controller.text);
              if (newQuantity != null && newQuantity > 0) {
                await FirebaseFirestore.instance.collection('shopping_list').doc(item.id).update({'quantity': newQuantity});
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryPopup(ResolvedShoppingItem item) async {
    // Hide the popup when a new one is shown
    setState(() => _selectedItemIdForCategoryEdit = null);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kategorie für "${item.itemName}" ändern'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('categories').orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final categories = snapshot.data!.docs;
              return GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, childAspectRatio: 1.2, mainAxisSpacing: 8, crossAxisSpacing: 8,
                ),
                itemCount: categories.length,
                itemBuilder: (ctx, index) {
                  final cat = categories[index];
                  final catData = cat.data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () async {
                      // Update both the 'items' master document AND the denormalized shopping list item
                      final WriteBatch batch = FirebaseFirestore.instance.batch();
                      
                      // 1. Update master item
                      batch.update(item.itemRef, {'category': cat.reference});

                      // 2. Update denormalized shopping list item
                      batch.update(
                        FirebaseFirestore.instance.collection('shopping_list').doc(item.id),
                        {
                          'categoryName': catData['name'],
                          'categoryColor': catData['color'],
                          'categoryIcon': catData['icon'],
                          'categoryOrder': catData['order'],
                        }
                      );
                      
                      await batch.commit();
                      if (mounted) Navigator.pop(ctx);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: parseColor(catData['color'] as String? ?? '#CCCCCC'),
                          ),
                          child: Icon(
                            IconData(catData['icon'] as int, fontFamily: 'MaterialIcons'),
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(catData['name'], style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- Search Bar Widget ---

class _SearchBar extends StatefulWidget {
  const _SearchBar();
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();
  List<DocumentSnapshot> _suggestions = [];

  void _updateSuggestions(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }
    // Perform a scalable prefix search on Firestore.
    final snapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();
    
    if (mounted) setState(() => _suggestions = snapshot.docs);
  }
  
  Future<void> _addItemToShoppingList(DocumentSnapshot itemDoc) async {
    final firestore = FirebaseFirestore.instance;
    final itemData = itemDoc.data() as Map<String, dynamic>;
    final itemName = itemData['name'] as String;

    // Check if item is already on the list
    final shoppingListDoc = await firestore.collection('shopping_list').doc(itemName).get();
    if (shoppingListDoc.exists) {
        // If it exists, just increase quantity
        final currentQuantity = shoppingListDoc.data()?['quantity'] as num? ?? 1;
        await firestore.collection('shopping_list').doc(itemName).update({'quantity': currentQuantity + 1});
    } else {
        // If not, fetch category and add denormalized data
        final categoryRef = itemData['category'] as DocumentReference?;
        Map<String, dynamic> categoryData = {};
        if(categoryRef != null) {
            final categorySnap = await categoryRef.get();
            if(categorySnap.exists) {
                categoryData = categorySnap.data() as Map<String, dynamic>;
            }
        }

        await firestore.collection('shopping_list').doc(itemName).set({
            'itemID': itemDoc.reference,
            'quantity': 1,
            'categoryName': categoryData['name'] ?? 'Unbekannt',
            'categoryColor': categoryData['color'] ?? '#CCCCCC',
            'categoryIcon': categoryData['icon'] ?? Icons.help.codePoint,
            'categoryOrder': categoryData['order'] ?? 999,
        });
    }

    if (mounted) {
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${itemName}" zur Liste hinzugefügt')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => _updateSuggestions(_controller.text));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Artikel suchen oder hinzufügen...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (_suggestions.isNotEmpty)
            SizedBox(
              height: 200,
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final doc = _suggestions[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name']),
                      onTap: () => _addItemToShoppingList(doc),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
