import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageDetailScreen extends StatefulWidget {
  final String title;

  const StorageDetailScreen({super.key, required this.title});

  @override
  State<StorageDetailScreen> createState() => _StorageDetailScreenState();
}

class _StorageDetailScreenState extends State<StorageDetailScreen> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> storagePlaces = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _fetchStoragePlaces();
  }

  Future<void> _fetchItems() async {
    final snapshot = await FirebaseFirestore.instance.collection('inventory').get();

    List<Map<String, dynamic>> fetchedItems = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      String? storage = data['storage'];
      final itemId = data['itemId'];
      if (itemId == null) continue;

      final itemSnap = await FirebaseFirestore.instance.collection('items').doc(itemId).get();
      if (!itemSnap.exists) continue;
      final itemData = itemSnap.data()!;

      // Automatisch Standardlager setzen, falls nicht gesetzt
      if (storage == null || storage.toString().isEmpty) {
        storage = itemData['standardStorage'];
        if (storage != null) {
          await FirebaseFirestore.instance.collection('inventory').doc(doc.id).update({
            'storage': storage,
          });
        }
      }

      if ((widget.title == 'Unsortiert' && (storage == null || storage.toString().isEmpty)) ||
          (widget.title != 'Unsortiert' && storage == widget.title)) {

        final categoryId = itemData['category'];
        final categorySnap = await FirebaseFirestore.instance.collection('categories').doc(categoryId).get();
        if (!categorySnap.exists) continue;
        final categoryData = categorySnap.data()!;

        fetchedItems.add({
          'id': doc.id,
          'itemId': itemId,
          'name': itemData['name'] ?? 'Unbenannt',
          'quantity': data['quantity'] ?? 1,
          'icon': categoryData['icon'] != null ? IconData(int.parse(categoryData['icon'].toString()), fontFamily: 'MaterialIcons') : Icons.inventory,
          'color': categoryData['color'] != null ? Color(int.parse(categoryData['color'].toString())) : Colors.grey,
          'order': categoryData['order'] ?? 9999,
        });
      }
    }

    fetchedItems.sort((a, b) {
      final orderCompare = (a['order'] as int).compareTo(b['order'] as int);
      if (orderCompare != 0) return orderCompare;
      return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
    });

    setState(() {
      items = fetchedItems;
      isLoading = false;
    });
  }

  Future<void> _fetchStoragePlaces() async {
    final snapshot = await FirebaseFirestore.instance.collection('storage').get();
    final places = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': doc.id,
        'color': Color(int.parse(data['color'].toString())),
        'icon': IconData(int.parse(data['icon'].toString()), fontFamily: 'MaterialIcons'),
      };
    }).toList();

    setState(() {
      storagePlaces = places;
    });
  }

  Future<void> _deleteItem(String id) async {
    await FirebaseFirestore.instance.collection('inventory').doc(id).delete();
    _fetchItems();
  }

  Future<void> _moveItem(String inventoryId) async {
    final itemEntry = items.firstWhere((element) => element['id'] == inventoryId);
    final String itemId = itemEntry['itemId'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ort wählen'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: storagePlaces.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final place = storagePlaces[index];
                return GestureDetector(
                  onTap: () async {
                    await FirebaseFirestore.instance.collection('inventory').doc(inventoryId).update({
                      'storage': place['title'],
                    });
                    await FirebaseFirestore.instance.collection('items').doc(itemId).update({
                      'standardStorage': place['title'],
                    });
                    Navigator.pop(context);
                    _fetchItems();
                  },
                  child: Card(
                    color: place['color'].withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(place['icon'], color: place['color'], size: 36),
                        const SizedBox(height: 8),
                        Text(place['title']),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Suche in ${widget.title}',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Dismissible(
                        key: Key(item['id']),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteItem(item['id']),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item['color'].withOpacity(0.2),
                            child: Icon(item['icon'], color: item['color']),
                          ),
                          title: Text(item['name']),
                          subtitle: Text('Menge: ${item['quantity']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.compare_arrows),
                            onPressed: () => _moveItem(item['id']),
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}