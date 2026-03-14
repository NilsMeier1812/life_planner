import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'inventory_detail_screen.dart';
import 'storages_management_screen.dart';
import '../utils/helpers.dart';

class InventoryMainScreen extends StatelessWidget {
  const InventoryMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventar'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StoragesManagementScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const _InventoryGlobalSearch(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('storages').orderBy('order').snapshots(),
              builder: (context, storageSnapshot) {
                if (storageSnapshot.hasError) {
                  return Center(child: Text('Fehler: ${storageSnapshot.error}'));
                }
                if (!storageSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final storages = storageSnapshot.data!.docs;

                // This second stream checks if there are any items with no assigned storage.
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('inventory')
                      .where('storage', isNull: true)
                      .limit(1) // We only need to know if at least one exists.
                      .snapshots(),
                  builder: (context, unsortedSnapshot) {
                    final bool showUnsorted = unsortedSnapshot.hasData && unsortedSnapshot.data!.docs.isNotEmpty;

                    return ListView.builder(
                      itemCount: storages.length + (showUnsorted ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Build the special "Unsorted" item at the end of the list if needed.
                        if (showUnsorted && index == storages.length) {
                          return _buildUnsortedStorageTile(context);
                        }
                        
                        // Build a regular storage location tile.
                        final storage = storages[index];
                        return _buildStorageTile(context, storage);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageTile(BuildContext context, DocumentSnapshot storageDoc) {
    final data = storageDoc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? storageDoc.id;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: parseColor(data['color'] as String? ?? '#CCCCCC'),
        ),
        child: Icon(IconData(data['icon'] as int? ?? Icons.error.codePoint, fontFamily: 'MaterialIcons'), color: Colors.black),
      ),
      title: Text(name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InventoryDetailScreen(
            storageId: storageDoc.id,
            storageName: name,
          ),
        ),
      ),
    );
  }

  Widget _buildUnsortedStorageTile(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceVariant,
        ),
        child: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      title: const Text('Unsortiert'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const InventoryDetailScreen(
            storageId: null, // Pass null to signify "unsorted"
            storageName: 'Unsortiert',
          ),
        ),
      ),
    );
  }
}

// --- Global Search Widget for Inventory ---

class _InventoryGlobalSearch extends StatefulWidget {
  const _InventoryGlobalSearch();
  @override
  State<_InventoryGlobalSearch> createState() => _InventoryGlobalSearchState();
}

class _InventoryGlobalSearchState extends State<_InventoryGlobalSearch> {
  final _controller = TextEditingController();
  List<DocumentSnapshot> _suggestions = [];
  bool _isLoading = false;

  void _updateSuggestions(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }
    
    setState(() => _isLoading = true);
    
    // Scalable prefix search on the 'itemName' field (requires denormalization).
    final snapshot = await FirebaseFirestore.instance
        .collection('inventory')
        .where('itemName', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('itemName', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
        .limit(10)
        .get();
        
    if (mounted) {
      setState(() {
        _suggestions = snapshot.docs;
        _isLoading = false;
      });
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
            decoration: InputDecoration(
              hintText: 'Gesamtes Inventar durchsuchen...',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isLoading ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)) : null,
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
                    
                    final storageRef = data['storage'] as DocumentReference?;
                    final storageName = data['storageName'] as String? ?? 'Unsortiert';

                    return ListTile(
                      title: Text(data['itemName']),
                      subtitle: Text('Lagerort: $storageName'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                         _controller.clear();
                         _suggestions = [];
                         Navigator.push(context, MaterialPageRoute(
                           builder: (context) => InventoryDetailScreen(
                            storageId: storageRef?.id,
                            storageName: storageName,
                           ),
                         ));
                      },
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
