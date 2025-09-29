import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestRefsScreen extends StatefulWidget {
  const TestRefsScreen({super.key});

  @override
  State<TestRefsScreen> createState() => _TestRefsScreenState();
}

class _TestRefsScreenState extends State<TestRefsScreen> {
  String statusMessage = 'Drücke den Knopf, um zu testen.';
  bool isLoading = false;
  List<Map<String, dynamic>> testShoppingItems = [];

  Future<void> _createTestData() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Erstelle Testdaten...';
    });

    final db = FirebaseFirestore.instance;

    try {
      // Schritt 1: Erstelle eine Test-Category (falls nicht existiert)
      final testCategoryRef = db.collection('categories').doc('TestCategory');
      final categorySnap = await testCategoryRef.get();
      if (!categorySnap.exists) {
        await testCategoryRef.set({
          'name': 'TestCategory', // Optional, falls du 'name' hast
          'color': '0xFF0000FF', // Blau als Beispiel
          'icon': 0xe88e, // Beispiel-Icon (z.B. MaterialIcons check_circle)
          'order': 0,
        });
        statusMessage += '\nTestCategory erstellt.';
      } else {
        statusMessage += '\nTestCategory existiert bereits.';
      }

      // Schritt 2: Erstelle ein Test-Item mit Ref zur Category
      final testItemRef = db.collection('items').doc('TestItem');
      final itemSnap = await testItemRef.get();
      if (!itemSnap.exists) {
        await testItemRef.set({
          'name': 'TestItem',
          'categoryRef': testCategoryRef, // Echte DocumentReference
          'standardQuantity': '1',
        });
        statusMessage += '\nTestItem erstellt mit categoryRef.';
      } else {
        statusMessage += '\nTestItem existiert bereits.';
      }

      // Schritt 3: Füge zur shopping_list mit Ref zum Item hinzu
      final shoppingListRef = await db.collection('shopping_list').add({
        'itemRef': testItemRef, // Echte DocumentReference
        'quantity': '1',
      });
      statusMessage += '\nShoppingList-Eintrag erstellt mit itemRef.';

      // Schritt 4: Überprüfe die Referenz, indem du die Daten lädst
      final shoppingSnap = await shoppingListRef.get();
      final loadedItemRef = shoppingSnap['itemRef'] as DocumentReference;
      final loadedItemSnap = await loadedItemRef.get();
      final loadedCategoryRef = loadedItemSnap['categoryRef'] as DocumentReference;
      final loadedCategorySnap = await loadedCategoryRef.get();

      if (loadedItemSnap.exists && loadedCategorySnap.exists) {
        final itemName = loadedItemSnap['name'];
        final categoryName = loadedCategorySnap.id; // Oder 'name', falls vorhanden
        statusMessage += '\nReferenz erfolgreich: Item "$itemName" in Category "$categoryName".';
        
        setState(() {
          testShoppingItems.add({
            'itemName': itemName,
            'categoryName': categoryName,
            'quantity': shoppingSnap['quantity'],
          });
        });
      } else {
        statusMessage += '\nFehler: Referenz konnte nicht aufgelöst werden.';
      }
    } catch (e) {
      statusMessage += '\nFehler: $e';
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Refs Screen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : _createTestData,
              child: const Text('Testdaten erstellen und Referenzen prüfen'),
            ),
            const SizedBox(height: 20),
            Text(
              statusMessage,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (testShoppingItems.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: testShoppingItems.length,
                  itemBuilder: (context, index) {
                    final item = testShoppingItems[index];
                    return ListTile(
                      title: Text('Item: ${item['itemName']}'),
                      subtitle: Text('Category: ${item['categoryName']}\nQuantity: ${item['quantity']}'),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                    );
                  },
                ),
              ),
            if (isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}