import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/heatmap_point.dart';
import '../services/heatmap_api_service.dart';
import '../services/scanner_service.dart';
import 'signal_scanner_page.dart'; // Yeni oluşturduğumuz test sayfası

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final HeatmapApiService apiService = HeatmapApiService();
  final ScannerService scannerService = ScannerService();

  late WebSocketChannel channel;
  List<HeatmapPoint> points = [];
  bool isLoading = true;
  bool showBottomPanel = true;
  String currentLocation = 'Konum aliniyor...';

  @override
  void initState() {
    super.initState();
    // Verileri ilk kez çek ve donanım taramasını başlat
    loadHeatmapData().then((_) {
      scannerService.startScanning(points);
    });
    loadCurrentLocation();
    connectWebSocket();
  }

  @override
  void dispose() {
    // Sayfadan çıkarken hem tarayıcıyı hem soketi kapat
    scannerService.stopScanning();
    channel.sink.close();
    super.dispose();
  }

  void connectWebSocket() {
    try {
      channel = WebSocketChannel.connect(Uri.parse(AppConfig.websocketUrl));
      channel.stream.listen(
        (message) {
          debugPrint('WEBSOCKET MESAJI: $message');
          final decoded = jsonDecode(message as String);
          
          if (decoded is Map<String, dynamic> && decoded['type'] == 'density_snapshot') {
            final data = decoded['data'] as List;
            if (mounted) {
              setState(() {
                points = data.map((item) => HeatmapPoint.fromJson(Map<String, dynamic>.from(item))).toList();
                isLoading = false;
              });
            }
          }
        },
        onError: (error) {
          debugPrint('WebSocket Hatası: $error');
          Future.delayed(const Duration(seconds: 5), connectWebSocket);
        },
      );
    } catch (e) {
      debugPrint('Soket bağlantı hatası: $e');
    }
  }

  Future<void> loadHeatmapData() async {
    try {
      final data = await apiService.fetchHeatmapData();
      if (mounted) {
        setState(() {
          points = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loadCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
    }
  }

  Color getDensityColor(int intensity) {
    if (intensity >= 70) return Colors.red.withOpacity(0.7);
    if (intensity >= 35) return Colors.orange.withOpacity(0.7);
    return Colors.green.withOpacity(0.7);
  }

  String getDensityLabel(String level) {
    switch (level) {
      case 'high': return 'Çok Yoğun';
      case 'medium': return 'Orta Yoğun';
      default: return 'Sakin';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listeyi yoğunluğa göre sırala (Arkadaşlarının görsel düzeni için)
    final sortedPoints = [...points]..sort((a, b) => b.intensity.compareTo(a.intensity));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kampüs Yoğunluk Haritası',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // TEST BUTONU: Donanımın çalıştığını çıplak gözle görmek için
          IconButton(
            icon: const Icon(Icons.radar, color: Colors.blue, size: 28),
            tooltip: 'Sinyal Tarayıcıyı Aç',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignalScannerPage()),
              );
            },
          ),
          // Katman/Liste Gizleme Butonu
          IconButton(
            icon: Icon(showBottomPanel ? Icons.layers_clear : Icons.list),
            onPressed: () => setState(() => showBottomPanel = !showBottomPanel),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(38.3335, 38.4350),
                    initialZoom: 15.0,
                    maxZoom: 18.0,
                    minZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mobile',
                    ),
                    CircleLayer(
                      circles: points.map((point) {
                        return CircleMarker(
                          point: LatLng(point.lat, point.lng),
                          color: getDensityColor(point.intensity),
                          borderStrokeWidth: 2,
                          borderColor: Colors.white,
                          useRadiusInMeter: true,
                          radius: 70,
                        );
                      }).toList(),
                    ),
                    MarkerLayer(
                      markers: points.map((point) {
                        return Marker(
                          point: LatLng(point.lat, point.lng),
                          width: 80,
                          height: 80,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  point.name,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const Icon(Icons.location_on, color: Colors.blue, size: 30),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                
                // Alt Panel (Bina Listesi)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  bottom: showBottomPanel ? 0 : -300,
                  left: 0,
                  right: 0,
                  height: 350,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bina Yoğunluk Listesi',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Konum: $currentLocation',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const Icon(Icons.info_outline, color: Colors.blue),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: sortedPoints.length,
                            itemBuilder: (context, index) {
                              final point = sortedPoints[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: getDensityColor(point.intensity).withOpacity(1),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            point.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            'Sinyal: ${point.signalStrength.toStringAsFixed(0)} dBm | Cihaz: ${point.totalDevices}',
                                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${point.intensity}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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