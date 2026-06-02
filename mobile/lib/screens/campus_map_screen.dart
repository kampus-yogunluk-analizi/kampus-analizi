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
import 'signal_scanner_page.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final HeatmapApiService apiService = HeatmapApiService();
  final ScannerService scannerService = ScannerService();

  WebSocketChannel? channel;
  List<HeatmapPoint> points = [];
  bool isLoading = true;
  bool showBottomPanel = true;
  bool scannerStarted = false;
  String? dataError;
  String? websocketWarning;
  String currentLocation = 'Konum alınıyor...';

  @override
  void initState() {
    super.initState();
    loadHeatmapData();
    loadCurrentLocation();
    connectWebSocket();
  }

  @override
  void dispose() {
    scannerService.stopScanning();
    channel?.sink.close();
    super.dispose();
  }

  void applyPoints(List<HeatmapPoint> nextPoints) {
    points = nextPoints;
    dataError = nextPoints.isEmpty ? 'Backend boş bina listesi döndürdü.' : null;
    isLoading = false;

    if (!scannerStarted && nextPoints.isNotEmpty) {
      scannerStarted = true;
      scannerService.startScanning(nextPoints);
    }
  }

  void connectWebSocket() {
    try {
      channel?.sink.close();
      channel = WebSocketChannel.connect(Uri.parse(AppConfig.websocketUrl));
      channel!.stream.listen(
        (message) {
          debugPrint('WEBSOCKET MESAJI: $message');
          final decoded = jsonDecode(message as String);

          if (decoded is Map<String, dynamic> &&
              decoded['type'] == 'density_snapshot' &&
              decoded['data'] is List) {
            final data = decoded['data'] as List;
            if (mounted) {
              setState(() {
                applyPoints(
                  data
                      .map(
                        (item) => HeatmapPoint.fromJson(
                          Map<String, dynamic>.from(item),
                        ),
                      )
                      .toList(),
                );
                websocketWarning = null;
              });
            }
          }
        },
        onError: (error) {
          debugPrint('WebSocket hatası: $error');
          if (mounted) {
            setState(() {
              websocketWarning =
                  'Canlı bağlantı kurulamadı; liste REST API verisiyle gösteriliyor.';
            });
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) connectWebSocket();
            });
          }
        },
        onDone: () {
          debugPrint('WebSocket bağlantısı kapandı.');
          if (mounted) {
            setState(() {
              websocketWarning =
                  'Canlı bağlantı kapandı; liste REST API verisiyle gösteriliyor.';
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Soket bağlantı hatası: $e');
      if (mounted) {
        setState(() {
          websocketWarning =
              'WebSocket bağlantısı açılamadı; liste REST API verisiyle gösteriliyor.';
        });
      }
    }
  }

  Future<void> loadHeatmapData() async {
    try {
      final data = await apiService.fetchHeatmapData();
      if (mounted) {
        setState(() {
          applyPoints(data);
        });
      }
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
      if (mounted) {
        setState(() {
          dataError =
              'Bina listesi alınamadı. Kontrol edilen adres: ${AppConfig.apiBaseUrl}/api/v1/heatmap-data';
          isLoading = false;
        });
      }
    }
  }

  Future<void> loadCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          currentLocation =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
      if (mounted) {
        setState(() {
          currentLocation = 'Konum izni yok veya konum alınamadı';
        });
      }
    }
  }

  Color getDensityColor(int intensity) {
    if (intensity >= 70) return Colors.red.withOpacity(0.7);
    if (intensity >= 35) return Colors.orange.withOpacity(0.7);
    return Colors.green.withOpacity(0.7);
  }

  @override
  Widget build(BuildContext context) {
    final sortedPoints = [...points]
      ..sort((a, b) => b.intensity.compareTo(a.intensity));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kampüs Yoğunluk Haritası',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Listeyi yenile',
            onPressed: loadHeatmapData,
          ),
          IconButton(
            icon: const Icon(Icons.radar, color: Colors.blue, size: 28),
            tooltip: 'Sinyal tarayıcıyı aç',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SignalScannerPage(),
                ),
              );
            },
          ),
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
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          width: 96,
                          height: 80,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  point.name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.location_on,
                                color: Colors.blue,
                                size: 30,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  bottom: showBottomPanel ? 0 : -300,
                  left: 0,
                  right: 0,
                  height: 350,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        ),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bina Yoğunluk Listesi',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Konum: $currentLocation',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.info_outline, color: Colors.blue),
                            ],
                          ),
                        ),
                        if (websocketWarning != null && sortedPoints.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text(
                              websocketWarning!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Expanded(
                          child: sortedPoints.isEmpty
                              ? _EmptyDensityList(message: dataError)
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: sortedPoints.length,
                                  itemBuilder: (context, index) {
                                    final point = sortedPoints[index];
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: getDensityColor(
                                                point.intensity,
                                              ).withOpacity(1),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  point.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Sinyal: ${point.signalStrength.toStringAsFixed(0)} dBm | Cihaz: ${point.totalDevices}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black54,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${point.intensity}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
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

class _EmptyDensityList extends StatelessWidget {
  const _EmptyDensityList({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Bina listesi görüntülenemiyor',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message ?? 'Backend bağlantısını kontrol edin.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
