import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/helpers.dart';


/// Displays the details for a single item.
///
/// It uses streams to listen for real-time updates on the item itself,
/// its inventory status, and its shopping list status.
class ItemDetailsScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  late final Stream<DocumentSnapshot> _itemStream;
  late final Stream<DocumentSnapshot> _inventoryStream;
  late final Stream<DocumentSnapshot> _shoppingListStream;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _itemStream = _firestore.collection('items').doc(widget.itemId).snapshots();
    _inventoryStream = _firestore.collection('inventory').doc(widget.itemId).snapshots();
    _shoppingListStream = _firestore.collection('shopping_list').doc(widget.itemId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _itemStream,
      builder: (context, itemSnapshot) {
        if (itemSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!itemSnapshot.hasData || !itemSnapshot.data!.exists) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Gegenstand nicht gefunden.')));
        }

        final itemData = itemSnapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          appBar: AppBar(title: Text(itemData['name'] ?? 'Detailansicht')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildItemHeader(itemData),
                const SizedBox(height: 24),
                _buildInventoryStatus(),
                const SizedBox(height: 24),
                _buildShoppingListStatus(itemData),
                const SizedBox(height: 24),
                _buildActions(itemData),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the header section with item name and category.
  Widget _buildItemHeader(Map<String, dynamic> itemData) {
    final categoryRef = itemData['category'] as DocumentReference?;
    return FutureBuilder<DocumentSnapshot>(
      future: categoryRef?.get(),
      builder: (context, categorySnapshot) {
        final categoryData = categorySnapshot.data?.data() as Map<String, dynamic>?;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: parseColor(categoryData?['color'] ?? '#CCCCCC'),
                  child: Icon(
                    IconData(categoryData?['icon'] ?? Icons.error.codePoint, fontFamily: 'MaterialIcons'),
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(itemData['name'] ?? 'Unbekannt', style: Theme.of(context).textTheme.headlineSmall),
                      Text(categoryData?['name'] ?? 'Keine Kategorie', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the inventory status section.
  Widget _buildInventoryStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _inventoryStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final quantity = data?['quantity'] ?? 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Im Inventar', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Menge: $quantity'),
                // Here you can add storage location and expiration date display
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the shopping list status section.
  Widget _buildShoppingListStatus(Map<String, dynamic> itemData) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _shoppingListStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final quantity = data?['quantity'] ?? 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auf der Einkaufsliste', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Menge: $quantity'),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the actions section.
  Widget _buildActions(Map<String, dynamic> itemData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Aktionen', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Auf Liste'),
              onPressed: () => _updateShoppingList(1, itemData),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.remove_shopping_cart),
              label: const Text('Von Liste'),
              onPressed: () => _updateShoppingList(-1, itemData),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Einlagern'),
              onPressed: () => _updateInventory(1, itemData),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.remove),
              label: const Text('Verbrauchen'),
              onPressed: () => _updateInventory(-1, itemData),
            ),
            // You can add more buttons for edit, delete, etc.
          ],
        ),
      ],
    );
  }

  /// Helper to update the shopping list quantity.
  Future<void> _updateShoppingList(int delta, Map<String, dynamic> itemData) async {
    final docRef = _firestore.collection('shopping_list').doc(widget.itemId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        if (delta > 0) {
          // This part is incomplete. Adding to shopping list from here needs denormalized category data.
          // For now, we only focus on the inventory part. A full implementation would be needed here.
          // For simplicity, let's assume this logic is handled elsewhere or needs more work.
          // The main point is to show how to pass itemData.
          transaction.set(docRef, {'quantity': delta, 'itemId': _firestore.collection('items').doc(widget.itemId)});
        }
      } else {
        final currentQuantity = (snapshot.data() as Map<String, dynamic>)['quantity'] ?? 0;
        final newQuantity = currentQuantity + delta;
        if (newQuantity > 0) {
          transaction.update(docRef, {'quantity': newQuantity});
        } else {
          transaction.delete(docRef);
        }
      }
    });
  }

  /// Helper to update the inventory quantity.
  Future<void> _updateInventory(int delta, Map<String, dynamic> itemData) async {
    final docRef = _firestore.collection('inventory').doc(widget.itemId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        if (delta > 0) {
          transaction.set(docRef, {
            'quantity': delta, 
            'itemId': _firestore.collection('items').doc(widget.itemId),
            'itemName': itemData['name'] // Add the denormalized name
          });
        }
      } else {
        final currentQuantity = (snapshot.data() as Map<String, dynamic>)['quantity'] ?? 0;
        final newQuantity = currentQuantity + delta;
        if (newQuantity > 0) {
          transaction.update(docRef, {'quantity': newQuantity});
        } else {
          transaction.delete(docRef);
        }
      }
    });
  }
}
