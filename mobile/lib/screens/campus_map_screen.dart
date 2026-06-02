import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../main.dart';
import '../models/heatmap_point.dart';
import '../services/heatmap_api_service.dart';
import '../services/scanner_service.dart';
import '../theme/app_theme.dart';
import '../widgets/building_detail_sheet.dart';
import 'signal_scanner_page.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen>
    with TickerProviderStateMixin {
  final HeatmapApiService apiService = HeatmapApiService();
  final ScannerService scannerService = ScannerService();

  late WebSocketChannel channel;
  List<HeatmapPoint> points = [];
  bool isLoading = true;
  bool showBottomPanel = true;
  bool wsConnected = false;
  String currentLocation = 'Konum alınıyor...';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _wsBlinkController;
  late Animation<double> _wsBlinkAnimation;

  @override
  void initState() {
    super.initState();

    _wsBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _wsBlinkAnimation = Tween<double>(begin: 0.4, end: 1.0)
        .animate(_wsBlinkController);

    loadHeatmapData().then((_) {
      scannerService.startScanning(points);
    });
    loadCurrentLocation();
    connectWebSocket();
  }

  @override
  void dispose() {
    scannerService.stopScanning();
    channel.sink.close();
    _wsBlinkController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void connectWebSocket() {
    try {
      channel = WebSocketChannel.connect(Uri.parse(AppConfig.websocketUrl));
      if (mounted) setState(() => wsConnected = true);

      channel.stream.listen(
        (message) {
          final decoded = jsonDecode(message as String);
          if (decoded is Map<String, dynamic> &&
              decoded['type'] == 'density_snapshot') {
            final data = decoded['data'] as List;
            if (mounted) {
              setState(() {
                points = data
                    .map((item) => HeatmapPoint.fromJson(
                        Map<String, dynamic>.from(item)))
                    .toList();
                isLoading = false;
              });
            }
          }
        },
        onError: (error) {
          if (mounted) setState(() => wsConnected = false);
          Future.delayed(const Duration(seconds: 5), connectWebSocket);
        },
        onDone: () {
          if (mounted) setState(() => wsConnected = false);
        },
      );
    } catch (e) {
      if (mounted) setState(() => wsConnected = false);
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
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          currentLocation =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (_) {}
  }

  Color getDensityColor(int intensity) {
    if (intensity >= 70) return AppColors.densityHigh;
    if (intensity >= 35) return AppColors.densityMedium;
    return AppColors.densityLow;
  }

  List<HeatmapPoint> get _filteredPoints {
    if (_searchQuery.isEmpty) return points;
    return points
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get _totalDevices =>
      points.fold(0, (sum, p) => sum + p.totalDevices);

  int get _highDensityCount =>
      points.where((p) => p.intensity >= 70).length;

  int get _avgIntensity => points.isEmpty
      ? 0
      : (points.fold(0, (s, p) => s + p.intensity) / points.length).round();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedPoints = [..._filteredPoints]
      ..sort((a, b) => b.intensity.compareTo(a.intensity));

    return Scaffold(
      body: isLoading
          ? _buildLoadingState()
          : Stack(
              children: [
                _buildMap(),
                _buildAppBar(isDark),
                _buildLegend(isDark),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  bottom: showBottomPanel ? 0 : -400,
                  left: 0,
                  right: 0,
                  child: _buildBottomPanel(isDark, sortedPoints),
                ),
                if (!showBottomPanel)
                  Positioned(
                    bottom: 20,
                    right: 16,
                    child: _buildShowPanelFab(isDark),
                  ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            const SizedBox(height: 20),
            Text(
              'Kampüs verisi yükleniyor...',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
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
              color: getDensityColor(point.intensity).withOpacity(0.25),
              borderStrokeWidth: 2,
              borderColor: getDensityColor(point.intensity).withOpacity(0.7),
              useRadiusInMeter: true,
              radius: 80,
            );
          }).toList(),
        ),
        MarkerLayer(
          markers: points.map((point) {
            return Marker(
              point: LatLng(point.lat, point.lng),
              width: 100,
              height: 72,
              child: GestureDetector(
                onTap: () => BuildingDetailSheet.show(context, point),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: getDensityColor(point.intensity),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: getDensityColor(point.intensity)
                                .withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        point.name,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    CustomPaint(
                      size: const Size(12, 6),
                      painter: _TrianglePainter(
                          getDensityColor(point.intensity)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark,
              AppColors.primary.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.location_city_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kampüs Yoğunluk',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'İnönü Üniversitesi',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildWsIndicator(),
                const SizedBox(width: 8),
                _buildDarkModeButton(),
                _buildScannerButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWsIndicator() {
    return AnimatedBuilder(
      animation: _wsBlinkAnimation,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (wsConnected ? AppColors.success : AppColors.danger)
              .withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (wsConnected ? AppColors.success : AppColors.danger)
                .withOpacity(wsConnected ? _wsBlinkAnimation.value : 1.0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: wsConnected
                    ? AppColors.success
                        .withOpacity(_wsBlinkAnimation.value)
                    : AppColors.danger,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              wsConnected ? 'Canlı' : 'Offline',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: wsConnected ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeButton() {
    final appState = CampusDensityApp.of(context);
    return IconButton(
      icon: Icon(
        appState?.isDark == true
            ? Icons.light_mode_rounded
            : Icons.dark_mode_rounded,
        color: Colors.white.withOpacity(0.8),
        size: 20,
      ),
      onPressed: () => appState?.toggleTheme(),
      tooltip: 'Tema Değiştir',
    );
  }

  Widget _buildScannerButton() {
    return IconButton(
      icon: const Icon(Icons.radar_rounded, color: Colors.white, size: 22),
      tooltip: 'Sinyal Tarayıcı',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const SignalScannerPage()),
        );
      },
    );
  }

  Widget _buildLegend(bool isDark) {
    final bg = isDark
        ? AppColors.cardDark.withOpacity(0.92)
        : Colors.white.withOpacity(0.92);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Positioned(
      top: kToolbarHeight + MediaQuery.of(context).padding.top + 60,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yoğunluk',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            _legendItem(AppColors.densityLow, 'Sakin', textColor),
            const SizedBox(height: 4),
            _legendItem(AppColors.densityMedium, 'Orta', textColor),
            const SizedBox(height: 4),
            _legendItem(AppColors.densityHigh, 'Yoğun', textColor),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildShowPanelFab(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () => setState(() => showBottomPanel = true),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.list_rounded, size: 20),
      label: Text('Liste', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildBottomPanel(bool isDark, List<HeatmapPoint> sortedPoints) {
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                _buildStatsBar(textColor, subColor),
                const SizedBox(height: 12),
                _buildSearchBar(isDark, textColor),
              ],
            ),
          ),
          Expanded(
            child: sortedPoints.isEmpty
                ? Center(
                    child: Text(
                      'Bina bulunamadı',
                      style: GoogleFonts.inter(color: subColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedPoints.length,
                    itemBuilder: (context, index) =>
                        _buildBuildingCard(sortedPoints[index], isDark, textColor, subColor),
                  ),
          ),
          GestureDetector(
            onTap: () => setState(() => showBottomPanel = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: subColor),
                  Text(
                    'Gizle',
                    style: GoogleFonts.inter(fontSize: 12, color: subColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(Color textColor, Color subColor) {
    return Row(
      children: [
        Expanded(
          child: _miniStat(Icons.people_rounded, '$_totalDevices',
              'Cihaz', AppColors.primary, textColor, subColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniStat(Icons.warning_amber_rounded, '$_highDensityCount',
              'Yoğun Bina', AppColors.densityHigh, textColor, subColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _miniStat(Icons.analytics_rounded, '$_avgIntensity',
              'Ort. Yoğ.', AppColors.accent, textColor, subColor),
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color,
      Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color textColor) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.inter(fontSize: 13, color: textColor),
        decoration: InputDecoration(
          hintText: 'Bina ara...',
          hintStyle: GoogleFonts.inter(
              fontSize: 13, color: textColor.withOpacity(0.4)),
          prefixIcon: Icon(Icons.search_rounded,
              size: 18, color: textColor.withOpacity(0.4)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: textColor.withOpacity(0.4)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildBuildingCard(HeatmapPoint point, bool isDark, Color textColor,
      Color subColor) {
    final color = getDensityColor(point.intensity);
    final (trendIcon, trendColor) = switch (point.trend) {
      'rising' => (Icons.trending_up_rounded, AppColors.densityHigh),
      'falling' => (Icons.trending_down_rounded, AppColors.densityLow),
      _ => (Icons.trending_flat_rounded, AppColors.accent),
    };
    final borderColor = point.isAnomaly
        ? AppColors.warning.withOpacity(0.5)
        : isDark
            ? AppColors.borderDark
            : AppColors.borderLight;

    return GestureDetector(
      onTap: () => BuildingDetailSheet.show(context, point),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.apartment_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          point.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (point.isAnomaly) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.warning_amber_rounded,
                            size: 13, color: AppColors.warning),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${point.totalDevices} cihaz · ${point.signalStrength.toStringAsFixed(0)} dBm · %${point.confidenceScore} güven',
                    style: GoogleFonts.inter(fontSize: 11, color: subColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 14, color: trendColor),
                    const SizedBox(width: 2),
                    Text(
                      '${point.intensity}',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _densityLabel(point.densityLevel),
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _densityLabel(String level) {
    switch (level) {
      case 'high':
        return 'YOĞUN';
      case 'medium':
        return 'ORTA';
      default:
        return 'SAKİN';
    }
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
