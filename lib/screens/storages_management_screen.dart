import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import '../utils/icon_storage_collection.dart';
import '../widgets/generic_management_screen.dart';
import '../widgets/generic_edit_screen.dart';

class StoragesManagementScreen extends StatelessWidget {
  const StoragesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const collectionPath = 'storages';

    return GenericManagementScreen(
      collectionPath: collectionPath,
      itemTitle: 'Lagerort',
      buildItem: (doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: parseColor(data['color'] as String? ?? '#CCCCCC'),
            ),
            child: Icon(
              IconData(data['icon'] as int? ?? Icons.error.codePoint, fontFamily: 'MaterialIcons'),
              color: Colors.black,
            ),
          ),
          title: Text(data['name'] as String? ?? 'Unbenannt'),
        );
      },
      onTap: (doc) => _navigateToEditScreen(context, doc: doc),
      onAddNew: () => _navigateToEditScreen(context),
    );
  }

  void _navigateToEditScreen(BuildContext context, {DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final isNew = doc == null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => GenericEditScreen(
          title: isNew ? 'Neuer Lagerort' : 'Lagerort bearbeiten',
          documentId: doc?.id,
          initialName: data?['name'] as String?,
          initialColor: data?['color'] != null ? parseColor(data!['color']) : null,
          initialIcon: data?['icon'] as int?,
          availableIcons: storageIcons,
          onSave: (name, color, icon) async {
            final hexColor = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
            final firestore = FirebaseFirestore.instance;
            final collection = firestore.collection('storages');

            final saveData = {
              'name': name,
              'color': hexColor,
              'icon': icon,
            };

            if (isNew) {
              // Use a transaction to safely get the new order number
              await firestore.runTransaction((transaction) async {
                final querySnapshot = await collection.orderBy('order', descending: true).limit(1).get();
                final newOrder = querySnapshot.docs.isNotEmpty
                    ? (querySnapshot.docs.first.data()['order'] as int? ?? 0) + 1
                    : 0;
                saveData['order'] = newOrder;
                transaction.set(collection.doc(), saveData);
              });
            } else {
              await collection.doc(doc.id).update(saveData);
            }
          },
          onDelete: isNew ? null : () async {
            final firestore = FirebaseFirestore.instance;
            final storageRef = firestore.collection('storages').doc(doc.id);
            
            // Set storage field to null for all items in this storage location
            final inventoryQuery = await firestore.collection('inventory').where('storage', isEqualTo: storageRef).get();
            WriteBatch batch = firestore.batch();
            for (var itemDoc in inventoryQuery.docs) {
              batch.update(itemDoc.reference, {'storage': null, 'storageName': 'Unsortiert'});
            }
            await batch.commit();
            
            // Delete the storage location itself
            await storageRef.delete();
          },
        ),
      ),
    );
  }
}

