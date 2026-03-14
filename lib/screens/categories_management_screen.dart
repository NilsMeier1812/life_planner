import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import '../utils/icon_categories_collection.dart';
import '../widgets/generic_management_screen.dart';
import '../widgets/generic_edit_screen.dart';

/// A screen to manage all 'Category' documents.
///
/// It uses the reusable [GenericManagementScreen] for the list view and
/// navigates to the [GenericEditScreen] for creating or editing categories.
class CategoriesManagementScreen extends StatelessWidget {
  const CategoriesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const collectionPath = 'categories';

    return GenericManagementScreen(
      collectionPath: collectionPath,
      itemTitle: 'Kategorie',
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

  /// Navigates to the edit screen, providing the necessary callbacks for data manipulation.
  void _navigateToEditScreen(BuildContext context, {DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => GenericEditScreen(
          title: doc == null ? 'Neue Kategorie' : 'Kategorie bearbeiten',
          documentId: doc?.id,
          initialName: data?['name'] as String?,
          initialColor: data?['color'] != null ? parseColor(data!['color']) : null,
          initialIcon: data?['icon'] as int?,
          availableIcons: materialIcons,
          onSave: (name, color, icon) async {
            final hexColor = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
            final firestore = FirebaseFirestore.instance;
            final collection = firestore.collection('categories');

            final saveData = {
              'name': name,
              'color': hexColor,
              'icon': icon,
            };

            if (doc == null) {
              final countSnapshot = await collection.count().get();
              saveData['order'] = countSnapshot.count ?? 0;
              await collection.add(saveData);
            } else {
              await collection.doc(doc.id).update(saveData);
            }
          },
          onDelete: (doc == null) ? null : () async {
            // Optional: Implement logic to handle items that reference this category upon deletion.
            await FirebaseFirestore.instance.collection('categories').doc(doc.id).delete();
          },
        ),
      ),
    );
  }
}

