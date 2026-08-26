import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

/// Produit renvoyé par OpenFoodFacts (valeurs pour 100 g).
class OffProduct {
  OffProduct({
    required this.name,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
  });
  final String name;
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
}

/// Ouvre la caméra et renvoie le code-barres scanné (ou null si annulé).
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _ScannerPage()),
  );
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner un produit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Torche',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const Positioned(
            bottom: 60,
            child: Text(
              'Vise le code-barres du produit',
              style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interroge OpenFoodFacts pour un code-barres. Renvoie null si introuvable.
Future<OffProduct?> lookupOpenFoodFacts(String barcode) async {
  final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
      '?fields=product_name,product_name_fr,nutriments');
  try {
    final res = await http.get(uri, headers: {
      'User-Agent': 'MyLife/1.0 (app de suivi personnel)',
    });
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (data['status'] != 1) return null;
    final product = data['product'] as Map<String, dynamic>;
    final nut = (product['nutriments'] as Map<String, dynamic>?) ?? {};

    double num100(String key) {
      final v = nut[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    final name =
        (product['product_name_fr'] ?? product['product_name'] ?? 'Produit')
            .toString();

    // OFF fournit l'énergie en kcal via 'energy-kcal_100g'.
    var kcal = num100('energy-kcal_100g');
    if (kcal == 0) {
      // Repli : convertir depuis les kJ si besoin.
      final kj = num100('energy_100g');
      if (kj > 0) kcal = kj / 4.184;
    }

    return OffProduct(
      name: name,
      kcalPer100: kcal,
      proteinPer100: num100('proteins_100g'),
      carbsPer100: num100('carbohydrates_100g'),
      fatPer100: num100('fat_100g'),
    );
  } catch (_) {
    return null;
  }
}
