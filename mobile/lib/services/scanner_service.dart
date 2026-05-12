import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import '../models/heatmap_point.dart';

class ScannerService {
  Timer? _timer;
  bool _isScanning = false;

  // Taramayı başlat (Harita ekranı açıldığında çağrılacak)
  void startScanning(List<HeatmapPoint> buildings) {
    if (_isScanning) return;
    _isScanning = true;
    
    // Her 30 saniyede bir tara ve gönder
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _scanAndReport(buildings);
    });
    
    // İlk çalışmayı hemen yap
    _scanAndReport(buildings);
  }

  void stopScanning() {
    _timer?.cancel();
    _isScanning = false;
  }

  Future<void> _scanAndReport(List<HeatmapPoint> buildings) async {
    try {
      // 1. Konum al ve en yakın binayı bul
      Position position = await Geolocator.getCurrentPosition();
      HeatmapPoint? nearestBuilding = _findNearestBuilding(position, buildings);

      if (nearestBuilding == null || nearestBuilding.buildingId == null) return;

      // 2. Bluetooth cihazlarını tara (4 saniye boyunca)
      int deviceCount = 0;
      double bestRssi = -95.0;

      // Tarama bittiğinde sonuçları al
      var subscription = FlutterBluePlus.onScanResults.listen((results) {
        deviceCount = results.length;
        for (ScanResult r in results) {
          if (r.rssi > bestRssi) bestRssi = r.rssi.toDouble();
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
      await subscription.cancel();

      // 3. Backend'e gönder
      await _sendDataToBackend(
        nearestBuilding.buildingId!,
        deviceCount,
        bestRssi,
      );
    } catch (e) {
      print("Tarama veya Gönderme Hatası: $e");
    }
  }

  HeatmapPoint? _findNearestBuilding(Position userPos, List<HeatmapPoint> buildings) {
    HeatmapPoint? closest;
    double minDistance = double.infinity;

    for (var b in buildings) {
      double distance = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, b.lat, b.lng);
      if (distance < minDistance && distance < 100) { // 100 metre içindeyse o binadadır
        minDistance = distance;
        closest = b;
      }
    }
    return closest;
  }

  Future<void> _sendDataToBackend(int buildingId, int count, double rssi) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/update-density');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "building_id": buildingId,
          "wifi_count": 0, // Wi-Fi şimdilik 0
          "bluetooth_count": count,
          "signal_strength": rssi
        }),
      );
      print("Veri gönderildi: Bina $buildingId, Cihaz: $count");
    } catch (e) {
      print("Backend Gönderim Hatası: $e");
    }
  }
}