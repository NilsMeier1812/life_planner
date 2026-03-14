import 'package:flutter/material.dart';

// Callback function types for saving and deleting data
typedef OnSaveCallback = Future<void> Function(String name, Color color, int icon);
typedef OnDeleteCallback = Future<void> Function();

/// A generic, reusable screen for creating or editing documents with a name, color, and icon.
///
/// This widget is decoupled from Firestore and uses callbacks (`onSave`, `onDelete`)
/// to delegate the actual data manipulation to the calling screen.
class GenericEditScreen extends StatefulWidget {
  final String title;
  final String? documentId; // Used to determine if it's a new or existing item
  final String? initialName;
  final Color? initialColor;
  final int? initialIcon;
  final List<int> availableIcons;
  final OnSaveCallback onSave;
  final OnDeleteCallback? onDelete; // Deleting is optional

  const GenericEditScreen({
    super.key,
    required this.title,
    this.documentId,
    this.initialName,
    this.initialColor,
    this.initialIcon,
    required this.availableIcons,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<GenericEditScreen> createState() => _GenericEditScreenState();
}

class _GenericEditScreenState extends State<GenericEditScreen> {
  late final TextEditingController _nameController;
  late Color _selectedColor;
  int? _selectedIcon;
  bool get _isNewItem => widget.documentId == null;

  // Predefined list of material colors for the user to choose from.
  final List<MaterialColor> _mainColors = [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
    Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
    Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
  ];
  late MaterialColor _selectedMainColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon;
    _selectedColor = widget.initialColor ?? _mainColors[8].shade400; // Default to a shade of Teal
    _selectedMainColor = _findClosestMainColor(_selectedColor);
  }

  /// Handles the save button press, validates input, and calls the onSave callback.
  void _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showErrorSnackBar('Bitte gib einen Namen ein.');
      return;
    }
    if (_selectedIcon == null) {
      _showErrorSnackBar('Bitte wähle ein Icon aus.');
      return;
    }

    try {
      await widget.onSave(name, _selectedColor, _selectedIcon!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Fehler beim Speichern: $e');
    }
  }

  /// Handles the delete button press and shows a confirmation dialog.
  void _handleDelete() {
    if (widget.onDelete == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wirklich löschen?'),
        content: const Text('Dieser Vorgang kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog first
              try {
                await widget.onDelete!();
                if (mounted) Navigator.pop(context); // Pop edit screen
              } catch (e) {
                _showErrorSnackBar('Fehler beim Löschen: $e');
              }
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!_isNewItem && widget.onDelete != null)
            IconButton(icon: const Icon(Icons.delete), onPressed: _handleDelete, tooltip: 'Löschen'),
          IconButton(icon: const Icon(Icons.save), onPressed: _handleSave, tooltip: 'Speichern'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameField(),
            const SizedBox(height: 24),
            _buildColorPicker(),
            const SizedBox(height: 24),
            _buildIconPicker(),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders for UI sections ---

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Name',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Farbe auswählen', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        // Main Color Palette
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _mainColors.length,
          itemBuilder: (context, index) {
            final color = _mainColors[index];
            return _buildColorCircle(
              color: color,
              isSelected: _selectedMainColor == color,
              onTap: () => setState(() {
                _selectedMainColor = color;
                _selectedColor = _getShadeColors(color)[4]; // Default to middle shade
              }),
            );
          },
        ),
        const SizedBox(height: 16),
        // Shade Palette
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _getShadeColors(_selectedMainColor).length,
          itemBuilder: (context, index) {
            final color = _getShadeColors(_selectedMainColor)[index];
            return _buildColorCircle(
              color: color,
              isSelected: _selectedColor == color,
              onTap: () => setState(() => _selectedColor = color),
            );
          },
        ),
      ],
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Icon auswählen', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: widget.availableIcons.length,
          itemBuilder: (context, index) {
            final iconCode = widget.availableIcons[index];
            final isSelected = _selectedIcon == iconCode;
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = iconCode),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons')),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildColorCircle({required Color color, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
        ),
      ),
    );
  }
  
  // --- Helper Methods ---

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  MaterialColor _findClosestMainColor(Color color) {
    return _mainColors.firstWhere(
      (mainColor) => _getShadeColors(mainColor).any((shade) => shade.value == color.value) || mainColor.value == color.value,
      orElse: () => Colors.teal,
    );
  }

  List<Color> _getShadeColors(MaterialColor mainColor) {
    return [
      mainColor.shade100, mainColor.shade200, mainColor.shade300,
      mainColor.shade400, mainColor.shade500, mainColor.shade700,
      mainColor.shade800, mainColor.shade900,
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

