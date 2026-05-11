import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/heatmap_point.dart';
import '../services/heatmap_api_service.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() =>
      _CampusMapScreenState();
}

class _CampusMapScreenState
    extends State<CampusMapScreen> {

  final HeatmapApiService apiService =
      HeatmapApiService();

  late WebSocketChannel channel;

  List<HeatmapPoint> points = [];

  bool isLoading = true;

  bool showBottomPanel = true;

  String currentLocation =
      'Konum alınamadı';

  @override
  void initState() {
    super.initState();

    loadHeatmapData();

    loadCurrentLocation();

    connectWebSocket();
  }

  void connectWebSocket() {

    channel = WebSocketChannel.connect(

      Uri.parse(
        'ws://192.168.1.110:8000/ws',
      ),
    );

    // TEST MESAJI
    channel.sink.add(
      'flutter connected',
    );

    channel.stream.listen(

      (message) {

        debugPrint(
          'WEBSOCKET MESAJI: $message',
        );

        // GELECEKTE:
        // final data = jsonDecode(message);
        // setState(() {});
      },

      onError: (error) {

        debugPrint(
          'WEBSOCKET HATASI: $error',
        );
      },

      onDone: () {

        debugPrint(
          'WEBSOCKET BAĞLANTISI KAPANDI',
        );
      },
    );
  }

  Future<void> loadCurrentLocation() async {

    try {

      Position position =
          await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.high,
      );

      setState(() {

        currentLocation =
            '${position.latitude}, '
            '${position.longitude}';
      });

    } catch (e) {

      setState(() {

        currentLocation =
            'Konum alınamadı';
      });
    }
  }

  Future<void> loadHeatmapData() async {

    try {

      final data =
          await apiService.fetchHeatmapData();

      setState(() {

        points = data;

        isLoading = false;
      });

    } catch (e) {

      setState(() {

        isLoading = false;
      });

      debugPrint('Hata: $e');
    }
  }

  Color getDensityColor(int intensity) {

    if (intensity >= 70) {
      return Colors.red;
    }

    else if (intensity >= 30) {
      return Colors.orange;
    }

    else {
      return Colors.green;
    }
  }

  double getRadius(int intensity) {

    if (intensity >= 70) {
      return 90;
    }

    else if (intensity >= 30) {
      return 65;
    }

    else {
      return 40;
    }
  }

  @override
  void dispose() {

    channel.sink.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final sortedPoints = [...points]

      ..sort(
        (a, b) =>
            b.intensity.compareTo(
              a.intensity,
            ),
      );

    return Scaffold(

      body: isLoading

          ? const Center(
              child:
                  CircularProgressIndicator(),
            )

          : Stack(

              children: [

                FlutterMap(

                  options: const MapOptions(

                    initialCenter:
                        LatLng(
                      38.3334,
                      38.4393,
                    ),

                    initialZoom: 15.5,

                    minZoom: 14,

                    maxZoom: 18,
                  ),

                  children: [

                    TileLayer(

                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                      userAgentPackageName:
                          'com.example.mobile',
                    ),

                    // HEATMAP GLOW
                    CircleLayer(

                      circles: points.map((point) {

                        return CircleMarker(

                          point: LatLng(
                            point.lat,
                            point.lng,
                          ),

                          radius: getRadius(
                            point.intensity,
                          ),

                          useRadiusInMeter: true,

                          color:
                              getDensityColor(
                            point.intensity,
                          ).withOpacity(0.35),

                          borderStrokeWidth: 0,
                        );

                      }).toList(),
                    ),

                    // BİNA İSİMLERİ
                    MarkerLayer(

                      markers: points.map((point) {

                        return Marker(

                          point: LatLng(
                            point.lat,
                            point.lng,
                          ),

                          width: 120,

                          height: 60,

                          child: Column(

                            children: [

                              Text(

                                point.name,

                                textAlign:
                                    TextAlign.center,

                                style:
                                    const TextStyle(

                                  color: Colors.white,

                                  fontSize: 13,

                                  fontWeight:
                                      FontWeight.bold,

                                  shadows: [

                                    Shadow(
                                      blurRadius: 6,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                height: 4,
                              ),

                              Container(

                                width: 12,

                                height: 12,

                                decoration: BoxDecoration(

                                  color:
                                      getDensityColor(
                                    point.intensity,
                                  ),

                                  shape:
                                      BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        );

                      }).toList(),
                    ),
                  ],
                ),

                SafeArea(

                  child: Padding(

                    padding:
                        const EdgeInsets.all(
                      16,
                    ),

                    child: Column(

                      children: [

                        // ÜST BİLGİ KARTI
                        Container(

                          width:
                              double.infinity,

                          padding:
                              const EdgeInsets.all(
                            16,
                          ),

                          decoration:
                              BoxDecoration(

                            color: Colors.white
                                .withOpacity(
                              0.92,
                            ),

                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),

                            boxShadow: const [

                              BoxShadow(
                                color:
                                    Colors.black12,
                                blurRadius:
                                    12,
                              ),
                            ],
                          ),

                          child: Column(

                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [

                              const Text(

                                'Kampüs Yoğunluk Analizi',

                                style:
                                    TextStyle(

                                  fontSize:
                                      22,

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              Text(
                                'Konum: '
                                '$currentLocation',
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              Text(
                                'Aktif Bölge Sayısı: '
                                '${points.length}',
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // ALT PANEL
                        AnimatedContainer(

                          duration:
                              const Duration(
                            milliseconds:
                                300,
                          ),

                          width:
                              double.infinity,

                          height:
                              showBottomPanel
                                  ? 320
                                  : 70,

                          decoration:
                              BoxDecoration(

                            color:
                                Colors.white,

                            borderRadius:
                                BorderRadius.circular(
                              24,
                            ),

                            boxShadow: const [

                              BoxShadow(
                                blurRadius:
                                    12,
                                color:
                                    Colors.black12,
                              ),
                            ],
                          ),

                          child: Column(

                            children: [

                              InkWell(

                                onTap: () {

                                  setState(() {

                                    showBottomPanel =
                                        !showBottomPanel;
                                  });
                                },

                                child: Padding(

                                  padding:
                                      const EdgeInsets.all(
                                    16,
                                  ),

                                  child: Row(

                                    children: [

                                      const Icon(
                                        Icons
                                            .local_fire_department,
                                        color:
                                            Colors.red,
                                      ),

                                      const SizedBox(
                                        width: 10,
                                      ),

                                      const Expanded(

                                        child:
                                            Text(

                                          'En Yoğun Bölgeler',

                                          style:
                                              TextStyle(

                                            fontSize:
                                                18,

                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      Icon(

                                        showBottomPanel

                                            ? Icons
                                                .keyboard_arrow_down

                                            : Icons
                                                .keyboard_arrow_up,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              if (showBottomPanel)

                                Expanded(

                                  child:
                                      ListView.builder(

                                    itemCount:
                                        sortedPoints
                                            .length,

                                    itemBuilder:
                                        (
                                      context,
                                      index,
                                    ) {

                                      final point =
                                          sortedPoints[
                                              index];

                                      return Container(

                                        margin:
                                            const EdgeInsets.symmetric(
                                          horizontal:
                                              12,
                                          vertical:
                                              6,
                                        ),

                                        padding:
                                            const EdgeInsets.all(
                                          14,
                                        ),

                                        decoration:
                                            BoxDecoration(

                                          color: Colors
                                              .grey
                                              .shade100,

                                          borderRadius:
                                              BorderRadius.circular(
                                            18,
                                          ),
                                        ),

                                        child: Row(

                                          children: [

                                            Container(

                                              width:
                                                  16,

                                              height:
                                                  16,

                                              decoration:
                                                  BoxDecoration(

                                                color:
                                                    getDensityColor(
                                                  point
                                                      .intensity,
                                                ),

                                                shape:
                                                    BoxShape.circle,
                                              ),
                                            ),

                                            const SizedBox(
                                              width:
                                                  14,
                                            ),

                                            Expanded(

                                              child:
                                                  Text(

                                                point.name,

                                                style:
                                                    const TextStyle(

                                                  fontSize:
                                                      16,

                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            Text(

                                              '${point.intensity}',

                                              style:
                                                  const TextStyle(

                                                fontSize:
                                                    18,

                                                fontWeight:
                                                    FontWeight.bold,
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}