// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    setState(() => _isProcessing = true);

    final itemsRef = FirebaseFirestore.instance.collection('items');
    final inventoryRef = FirebaseFirestore.instance.collection('inventory');
    final shoppingListRef = FirebaseFirestore.instance.collection('shopping_list');

    final itemSnap = await itemsRef.where('code', isEqualTo: code).get();

    Map<String, dynamic>? itemData;
    String? itemId;
    if (itemSnap.docs.isNotEmpty) {
      itemData = itemSnap.docs.first.data();
      itemId = itemSnap.docs.first.id;
    }

    final inventorySnap = itemId != null
        ? await inventoryRef.where('itemId', isEqualTo: itemId).get()
        : null;

    final shoppingSnap = itemId != null
        ? await shoppingListRef.where('itemId', isEqualTo: itemId).get()
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: itemData != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${itemData['name']}", style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 10),
                  if (inventorySnap!.docs.isNotEmpty) ...[
                    Text("Im Inventar: ${inventorySnap.docs.first['quantity']}"),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final qty = (inventorySnap.docs.first['quantity'] as int) - 1;
                            await inventoryRef.doc(inventorySnap.docs.first.id).update({
                              'quantity': qty > 0 ? qty : 0,
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('1 Entfernen'),
                        ),
                      ],
                    ),
                  ] else
                    const Text("Nicht im Inventar"),
                  const SizedBox(height: 10),
                  if (shoppingSnap!.docs.isEmpty)
                    ElevatedButton(
                      onPressed: () async {
                        await shoppingListRef.add({
                          'itemId': itemId,
                          'quantity': '1',
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Zur Einkaufsliste hinzufügen'),
                    ),
                ],
              )
            : _NewItemForm(barcode: code),
      ),
    ).whenComplete(() => setState(() => _isProcessing = false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Scanner')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}

class _NewItemForm extends StatefulWidget {
  final String barcode;
  const _NewItemForm({required this.barcode});

  @override
  State<_NewItemForm> createState() => _NewItemFormState();
}

class _NewItemFormState extends State<_NewItemForm> {
  final _nameController = TextEditingController();
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFirestore.instance.collection('categories').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final categories = snapshot.data!.docs;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Neuer Gegenstand (Barcode: ${widget.barcode})", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text("Kategorie wählen"),
              items: categories.map((cat) {
                return DropdownMenuItem(
                  value: cat.id,
                  child: Text(cat.id),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty || _selectedCategory == null) return;
                    await FirebaseFirestore.instance.collection('items').doc(name).set({
                      'name': name,
                      'category': _selectedCategory,
                      'code': widget.barcode,
                      'standardQuantity': '1',
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Gegenstand anlegen'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty || _selectedCategory == null) return;
                    await FirebaseFirestore.instance.collection('items').doc(name).set({
                      'name': name,
                      'category': _selectedCategory,
                      'code': widget.barcode,
                      'standardQuantity': '1',
                    });
                    await FirebaseFirestore.instance.collection('shopping_list').add({
                      'itemId': name,
                      'quantity': '1',
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Anlegen und zur Liste'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
