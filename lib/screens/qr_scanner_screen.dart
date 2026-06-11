import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/score_service.dart';

class QRScannerScreen extends StatefulWidget {
  final String eventId;
  final String correctSecret;
  const QRScannerScreen({super.key, required this.eventId, required this.correctSecret});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    final String trimmedCode = code.trim();
    final String trimmedSecret = widget.correctSecret.trim();

    debugPrint('Scanned QR Code: $trimmedCode');
    debugPrint('Expected Secret: $trimmedSecret');

    if (trimmedCode == trimmedSecret || trimmedCode == widget.eventId) {
      setState(() => _isProcessing = true);
      
      try {
        final String uid = FirebaseAuth.instance.currentUser!.uid;
        final docRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
        
        // 1. Check if already marked
        final doc = await docRef.get();
        final List attended = doc.data()?['attendanceYes'] ?? [];
        
        if (attended.contains(uid)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaten katılımınız onaylanmış.')));
            Navigator.pop(context);
          }
          return;
        }

        // 2. Mark attendance
        await docRef.update({
          'attendanceYes': FieldValue.arrayUnion([uid]),
          'attendanceNo': FieldValue.arrayRemove([uid]),
        });

        // 3. Award points
        await ScoreService.instance.processAttendanceScores(widget.eventId, uid, 'attendanceYes');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yoklamanız başarıyla alındı! Puan kazandınız. 🎉'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
          setState(() => _isProcessing = false);
        }
      }
    } else {
      // Don't show snackbar every time, it might be annoying if it's scanning fast
      // Just log it
      debugPrint('Wrong QR Code: $trimmedCode, expected: $trimmedSecret or ${widget.eventId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Yoklama Okut'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto, color: Colors.blue);
                  case TorchState.unavailable:
                    return const Icon(Icons.flash_off, color: Colors.red);
                }
              },
            ),
            iconSize: 32.0,
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            iconSize: 32.0,
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay UI
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
            ),
          const Positioned(
            bottom: 80,
            left: 0, right: 0,
            child: Text(
              'QR Kodu karenin içine hizalayın\nIşık yetersizse feneri açın',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
            ),
          ),
        ],
      ),
    );
  }
}
