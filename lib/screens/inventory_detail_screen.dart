import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import 'item_details_screen.dart';

/// Displays the list of items within a specific storage location.
class InventoryDetailScreen extends StatefulWidget {
  final String? storageId;
  final String storageName;

  const InventoryDetailScreen({
    super.key,
    required this.storageId,
    required this.storageName,
  });

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storageName),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'In diesem Lager suchen...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getInventoryStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!.docs;
                if (items.isEmpty) {
                  return const Center(child: Text('Keine Gegenstände in diesem Lager.'));
                }

                // Filter the items based on the search query
                final filteredItems = items.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final itemName = data['itemName']?.toString().toLowerCase() ?? '';
                  return itemName.contains(_searchQuery);
                }).toList();

                if (filteredItems.isEmpty) {
                  return const Center(child: Text('Keine passenden Gegenstände gefunden.'));
                }

                return ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final doc = filteredItems[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildInventoryItemTile(context, doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the correct Firestore stream based on whether a storageId is provided.
  Stream<QuerySnapshot> _getInventoryStream() {
    final inventoryRef = FirebaseFirestore.instance.collection('inventory');
    if (widget.storageId == null) {
      return inventoryRef.where('storage', isNull: true).snapshots();
    } else {
      return inventoryRef
          .where('storage', isEqualTo: FirebaseFirestore.instance.collection('storages').doc(widget.storageId))
          .snapshots();
    }
  }

  /// Builds a ListTile for an individual inventory item.
  Widget _buildInventoryItemTile(BuildContext context, String itemId, Map<String, dynamic> data) {
    final categoryRef = data['category'] as DocumentReference?;
    
    return FutureBuilder<DocumentSnapshot>(
      future: categoryRef?.get(),
      builder: (context, categorySnapshot) {
        final categoryData = categorySnapshot.data?.data() as Map<String, dynamic>?;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: parseColor(categoryData?['color'] ?? '#CCCCCC'),
            child: Icon(
              IconData(categoryData?['icon'] ?? Icons.error.codePoint, fontFamily: 'MaterialIcons'),
              color: Colors.black,
            ),
          ),
          title: Text(data['itemName'] ?? 'Unbekannter Gegenstand'),
          subtitle: Text('Menge: ${data['quantity'] ?? 0}'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemDetailsScreen(itemId: itemId),
              ),
            );
          },
        );
      },
    );
  }
}
