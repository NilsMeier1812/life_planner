import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDebugScreen extends StatelessWidget {
  const FirebaseDebugScreen({super.key});

  Future<Map<String, dynamic>> _getAllCollections() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final result = <String, dynamic>{};

    final collections = ['categories', 'items', 'inventory', 'shopping_list'];

    for (final collectionName in collections) {
      final snapshot = await firestore.collection(collectionName).get();
      result[collectionName] = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'data': doc.data(),
        };
      }).toList();
    }

    return result;
  }

  Future<void> _createTestData() async {
    final firestore = FirebaseFirestore.instance;

    // Kategorie anlegen
    await firestore.collection('categories').doc('Backware').set({
      'color': Colors.orange.value,
      'icon': Icons.bakery_dining.codePoint,
    });

    // Item anlegen
    final itemRef = firestore.collection('items').doc('Brot');
    await itemRef.set({
      'name': 'Brot',
      'category': 'Backware',
      'standardQuantity': 1,
    });

    // Shopping List mit gültiger Referenz anlegen
    await firestore.collection('shopping_list').add({
      'itemRef': itemRef,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Debug')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () async {
                await _createTestData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Testdaten wurden erstellt')),
                );
              },
              child: const Text('Testdaten erstellen'),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getAllCollections(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }

                final data = snapshot.data!;
                return ListView(
                  children: data.entries.map((entry) {
                    final collectionName = entry.key;
                    final documents = entry.value as List;

                    return ExpansionTile(
                      title: Text('$collectionName (${documents.length})'),
                      children: documents.map<Widget>((doc) {
                        return ListTile(
                          title: Text(doc['id']),
                          subtitle: Text(doc['data'].toString()),
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
