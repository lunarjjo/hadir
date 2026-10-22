/// Layar pindai QR (kamera belakang, deteksi sekali + fallback pengaturan).
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:hadir/state/app_bootstrap.dart';

class ScanPage extends StatefulWidget {
  final String judul;

  const ScanPage({super.key, required this.judul});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _selesai = false;
  bool _lampuNyala = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_selesai) return;
    for (final barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty && raw.startsWith('HADIR|')) {
        _selesai = true;
        Navigator.pop(context, raw);
        return;
      }
    }
  }

  Future<void> _toggleLampu() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _lampuNyala = !_lampuNyala);
    } catch (_) {
      // Perangkat tanpa lampu kilat: abaikan.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.judul),
        actions: [
          IconButton(
            tooltip: 'Lampu kilat',
            onPressed: _toggleLampu,
            icon: Icon(_lampuNyala ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.primary, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Positioned(
                  bottom: 28,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.inverseSurface.withAlpha(220),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Arahkan kamera ke QR Hadir',
                      style: TextStyle(color: cs.onInverseSurface),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  Text(
                    'QR hanya bisa dipindai saat layar admin membuka halaman '
                    'QR Absen.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final bootstrap = context.read<AppBootstrap>();
                      await bootstrap.location.openAppSettings();
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Kamera bermasalah? Buka Pengaturan'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
