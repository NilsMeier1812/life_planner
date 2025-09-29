import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> storagePlaces = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStoragePlaces();
  }

  Future<void> _fetchStoragePlaces() async {
    final snapshot = await FirebaseFirestore.instance.collection('storage').get();
    final List<Map<String, dynamic>> loadedPlaces = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': doc.id,
        'color': Color(int.parse(data['color'].toString())),
        'icon': IconData(int.parse(data['icon'].toString()), fontFamily: 'MaterialIcons'),
      };
    }).toList();

    setState(() {
      storagePlaces = loadedPlaces;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Suche...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StorageDetailScreen(title: 'Unsortiert'),
                  ),
                );
              },
              child: const Text('Unsortiert'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.builder(
                    itemCount: storagePlaces.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder: (context, index) {
                      final place = storagePlaces[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StorageDetailScreen(title: place['title']),
                            ),
                          );
                        },
                        child: Card(
                          color: place['color'].withOpacity(0.2),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(place['icon'], size: 40, color: place['color']),
                              const SizedBox(height: 12),
                              Text(
                                place['title'],
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
