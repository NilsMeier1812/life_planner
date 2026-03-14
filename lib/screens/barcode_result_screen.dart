import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'item_details_screen.dart';
import '../utils/helpers.dart';
import 'categories_management_screen.dart';

/// A screen to handle the result of a barcode scan when the barcode is not found.
///
/// It allows the user to either create a new item for this barcode
/// or assign the barcode to an existing item.
/// This screen replaces the need for separate ItemSearchScreen and ItemEditScreen.
class BarcodeResultScreen extends StatefulWidget {
  final String barcode;

  const BarcodeResultScreen({super.key, required this.barcode});

  @override
  State<BarcodeResultScreen> createState() => _BarcodeResultScreenState();
}

class _BarcodeResultScreenState extends State<BarcodeResultScreen> {
  // State for creating a new item
  final _nameController = TextEditingController();
  Map<String, dynamic>? _selectedCategory;
  bool _isCreatingNew = true; // Toggle between creating and assigning

  // State for assigning to an existing item
  List<DocumentSnapshot> _suggestions = [];
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _updateSuggestions(_searchController.text);
    });
  }

  /// Updates the search suggestions based on user input.
  Future<void> _updateSuggestions(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      // Server-side search using prefix matching
      // Note: This is case-sensitive based on how items are stored.
      final snapshot = await firestore
          .collection('items')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _suggestions = snapshot.docs;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Fehler bei der Suche: $e');
    }
  }

  /// Handles creating a new item and associating the barcode with it.
  Future<void> _handleCreateNewItem() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showErrorSnackBar('Bitte gib einen Namen ein.');
      return;
    }
    if (_selectedCategory == null) {
      _showErrorSnackBar('Bitte wähle eine Kategorie aus.');
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final itemRef = firestore.collection('items').doc(); // Use auto-ID

    try {
      final newItemData = {
        'name': name,
        'category': firestore.collection('categories').doc(_selectedCategory!['id']),
        'barcodes': [widget.barcode],
      };

      await itemRef.set(newItemData);

      // Navigate to details screen with the newly created data, avoiding a refetch.
      _navigateToDetails(itemRef.id);
    } catch (e) {
      _showErrorSnackBar('Fehler beim Erstellen: $e');
    }
  }

  /// Handles assigning the new barcode to an existing item.
  Future<void> _handleAssignToExisting(DocumentSnapshot itemDoc) async {
    try {
      await itemDoc.reference.update({
        'barcodes': FieldValue.arrayUnion([widget.barcode])
      });
      _navigateToDetails(itemDoc.id);
    } catch (e) {
      _showErrorSnackBar('Fehler beim Zuweisen: $e');
    }
  }

  /// Navigates to the ItemDetailsScreen, replacing the current screen stack.
  void _navigateToDetails(String itemId) {
    if (!mounted) return;
    // We pop the scanner and this screen, then push the details screen.
    Navigator.pop(context); // Pop this screen
    Navigator.pop(context); // Pop scanner screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailsScreen(itemId: itemId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unbekannter Barcode'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Barcode: ${widget.barcode}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Neuer Artikel')),
                ButtonSegment(value: false, label: Text('Zuweisen')),
              ],
              selected: {_isCreatingNew},
              onSelectionChanged: (selection) {
                setState(() => _isCreatingNew = selection.first);
              },
            ),
            const SizedBox(height: 24),
            _isCreatingNew ? _buildCreateNewItemUI() : _buildAssignItemUI(),
          ],
        ),
      ),
    );
  }

  /// UI for creating a new item.
  Widget _buildCreateNewItemUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name des Artikels', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        _buildCategorySelector(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _handleCreateNewItem,
          child: const Text('Speichern und zur Einkaufsliste'),
        ),
      ],
    );
  }

  /// UI for assigning the barcode to an existing item.
  Widget _buildAssignItemUI() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Vorhandenen Artikel suchen...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        if (_suggestions.isNotEmpty)
          SizedBox(
            height: 250,
            child: ListView.builder(
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final doc = _suggestions[index];
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(data['name'] ?? 'Unbenannt'),
                  onTap: () => _handleAssignToExisting(doc),
                );
              },
            ),
          ),
      ],
    );
  }

  /// A reusable widget for category selection.
  Widget _buildCategorySelector() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (context) => const CategoriesManagementScreen()),
        );
        if (result != null) {
          setState(() => _selectedCategory = result);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (_selectedCategory != null)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: parseColor(_selectedCategory!['color']),
                ),
                child: Icon(
                  IconData(_selectedCategory!['icon'], fontFamily: 'MaterialIcons'),
                  color: Colors.black,
                ),
              )
            else
              const Icon(Icons.category_outlined, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCategory?['name'] ?? 'Kategorie wählen',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
