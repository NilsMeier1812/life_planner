import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Type definition for the builder function that creates a list item widget.
typedef ItemWidgetBuilder = Widget Function(DocumentSnapshot doc);

/// A generic, reusable screen widget for managing a list of documents
/// from a Firestore collection with reordering capabilities.
class GenericManagementScreen extends StatelessWidget {
  /// The path of the Firestore collection (e.g., 'categories').
  final String collectionPath;

  /// The title to be displayed in the AppBar (e.g., 'Kategorie').
  final String itemTitle;

  /// A function that builds the widget for each document in the list.
  final ItemWidgetBuilder buildItem;

  /// A callback function that is triggered when a user taps on an item.
  /// Typically used to navigate to an edit screen.
  final void Function(DocumentSnapshot doc) onTap;

  /// A callback function that is triggered when the user taps the 'Add New' button.
  final VoidCallback onAddNew;

  const GenericManagementScreen({
    super.key,
    required this.collectionPath,
    required this.itemTitle,
    required this.buildItem,
    required this.onTap,
    required this.onAddNew,
  });

  /// Handles the reordering of items in the list and updates their 'order' field in Firestore.
  Future<void> _onReorder(int oldIndex, int newIndex, List<DocumentSnapshot> docs) async {
    // Adjust indices because the "Add New" button is at index 0.
    int adjustedOldIndex = oldIndex - 1;
    int adjustedNewIndex = newIndex - 1;

    if (adjustedNewIndex >= docs.length) {
      adjustedNewIndex = docs.length - 1;
    }
    
    final movedItem = docs.removeAt(adjustedOldIndex);
    docs.insert(adjustedNewIndex, movedItem);

    // Update the 'order' field for all affected documents in a single batch.
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    for (int i = 0; i < docs.length; i++) {
      batch.update(docs[i].reference, {'order': i});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$itemTitle verwalten'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(collectionPath).orderBy('order').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return ReorderableListView.builder(
            itemCount: docs.length + 1, // +1 for the "Add New" button
            itemBuilder: (context, index) {
              // The first item is always the "Add New" button.
              if (index == 0) {
                return ListTile(
                  key: const ValueKey('add_new_item'),
                  leading: const Icon(Icons.add_circle, size: 40),
                  title: Text('Neue $itemTitle hinzufügen'),
                  onTap: onAddNew,
                );
              }

              // Build the actual list item for a document.
              final doc = docs[index - 1];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(doc.id),
                index: index,
                child: GestureDetector(
                  onTap: () => onTap(doc),
                  child: buildItem(doc),
                ),
              );
            },
            onReorder: (oldIndex, newIndex) {
              // Prevent reordering of the "Add New" button.
              if (oldIndex == 0 || newIndex == 0) return;
              _onReorder(oldIndex, newIndex, docs);
            },
          );
        },
      ),
    );
  }
}

