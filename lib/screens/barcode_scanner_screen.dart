import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'barcode_result_screen.dart';
import 'item_details_screen.dart';

/// A screen that displays a camera view to scan barcodes.
///
/// It handles barcode detection, queries Firestore to check if the item exists,
/// and navigates to the appropriate screen ([ItemDetailsScreen] for known barcodes,
/// [BarcodeResultScreen] for unknown ones).
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop the camera when the app goes into the background, start when it comes to the foreground
    if (!_scannerController.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _scannerController.stop();
        break;
      case AppLifecycleState.resumed:
        if (!_isProcessing) {
          _scannerController.start();
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Handles the detected barcode.
  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodeValue = capture.barcodes.first.rawValue;
    if (barcodeValue == null) return;

    setState(() => _isProcessing = true);
    await _scannerController.stop();

    try {
      final firestore = FirebaseFirestore.instance;
      final query = await firestore
          .collection('items')
          .where('barcodes', arrayContains: barcodeValue)
          .limit(1)
          .get();

      if (!mounted) return;

      if (query.docs.isEmpty) {
        // Barcode not found, navigate to the result screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BarcodeResultScreen(barcode: barcodeValue),
          ),
        ).then((_) {
          _resetScanner();
          _scannerController.start();
        });
      } else {
        // Barcode found, navigate directly to the item details
        final itemId = query.docs.first.id;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailsScreen(itemId: itemId),
          ),
        ).then((_) {
          _resetScanner();
          _scannerController.start();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei der Barcode-Verarbeitung: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      _resetScanner();
      _scannerController.start();
    }
  }

  void _resetScanner() {
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildScannerOverlay() {
    return Column(
      children: [
        Expanded(child: Container(color: Colors.black54)),
        Row(
          children: [
            Expanded(child: Container(color: Colors.black54, height: 250)),
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Expanded(child: Container(color: Colors.black54, height: 250)),
          ],
        ),
        Expanded(child: Container(color: Colors.black54)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController.torchState,
              builder: (context, state, child) {
                return Icon(state == TorchState.on ? Icons.flash_on : Icons.flash_off);
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
            tooltip: 'Taschenlampe',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
          ),
          _buildScannerOverlay(),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Verarbeite Barcode...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
