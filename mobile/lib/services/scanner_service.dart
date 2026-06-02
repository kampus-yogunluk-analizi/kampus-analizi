import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import '../models/heatmap_point.dart';

class ScannerService {
  Timer? _timer;
  bool _isScanning = false;

  void startScanning(List<HeatmapPoint> buildings) {
    if (_isScanning) return;
    _isScanning = true;
    
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _scanAndReport(buildings);
    });
    
    _scanAndReport(buildings);
  }

  void stopScanning() {
    _timer?.cancel();
    _isScanning = false;
  }

  Future<void> _scanAndReport(List<HeatmapPoint> buildings) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      HeatmapPoint? nearestBuilding = _findNearestBuilding(position, buildings);

      if (nearestBuilding == null || nearestBuilding.buildingId == null) return;

      int deviceCount = 0;
      double bestRssi = -95.0;

      var subscription = FlutterBluePlus.onScanResults.listen((results) {
        deviceCount = results.length;
        for (ScanResult r in results) {
          if (r.rssi > bestRssi) bestRssi = r.rssi.toDouble();
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
      await subscription.cancel();

      await _sendDataToBackend(
        nearestBuilding.buildingId!,
        deviceCount,
        bestRssi,
      );
    } catch (e) {
      debugPrint("Tarama veya Gönderme Hatası: $e");
    }
  }

  HeatmapPoint? _findNearestBuilding(Position userPos, List<HeatmapPoint> buildings) {
    HeatmapPoint? closest;
    double minDistance = double.infinity;

    for (var b in buildings) {
      double distance = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, b.lat, b.lng);
      if (distance < minDistance && distance < 100) { 
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
          "wifi_count": 0, 
          "bluetooth_count": count,
          "signal_strength": rssi
        }),
      );
      debugPrint("Veri gönderildi: Bina $buildingId, Cihaz: $count");
    } catch (e) {
      debugPrint("Backend Gönderim Hatası: $e");
    }
  }
}