import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const String apiHost = String.fromEnvironment(
  'API_HOST',
  defaultValue: '127.0.0.1:8000',
);

void main() {
  runApp(const CampusDensityApp());
}

class CampusDensityApp extends StatelessWidget {
  const CampusDensityApp({super.key, this.enableRealtime = true});

  final bool enableRealtime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kampus Yogunluk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146C94)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F9),
        useMaterial3: true,
      ),
      home: DensityDashboard(enableRealtime: enableRealtime),
    );
  }
}

class DensityDashboard extends StatefulWidget {
  const DensityDashboard({super.key, required this.enableRealtime});

  final bool enableRealtime;

  @override
  State<DensityDashboard> createState() => _DensityDashboardState();
}

class _DensityDashboardState extends State<DensityDashboard> {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  DensitySnapshot _snapshot = DensitySnapshot.demo();
  bool _connected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.enableRealtime) {
      _connect();
    }
  }

  void _connect() {
    final channel = WebSocketChannel.connect(Uri.parse('ws://$apiHost/ws'));
    _channel = channel;
    _subscription = channel.stream.listen(
      (message) {
        final decoded = jsonDecode(message as String) as Map<String, dynamic>;
        setState(() {
          _snapshot = DensitySnapshot.fromJson(decoded);
          _connected = true;
          _error = null;
        });
      },
      onError: (Object error) {
        setState(() {
          _connected = false;
          _error = 'Baglanti hatasi';
        });
      },
      onDone: () {
        if (mounted) {
          setState(() => _connected = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kampus Yogunluk Analizi'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConnectionBadge(connected: _connected),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SummaryHeader(snapshot: _snapshot, error: _error),
            const SizedBox(height: 14),
            CampusMap(snapshot: _snapshot),
            const SizedBox(height: 14),
            ZoneList(zones: _snapshot.zones),
          ],
        ),
      ),
    );
  }
}

class SummaryHeader extends StatelessWidget {
  const SummaryHeader({super.key, required this.snapshot, required this.error});

  final DensitySnapshot snapshot;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final busiest = snapshot.zones.reduce((a, b) => a.density >= b.density ? a : b);
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Toplam cihaz',
            value: snapshot.totalDevices.toString(),
            icon: Icons.wifi,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            label: 'En yogun',
            value: busiest.zoneName,
            icon: Icons.location_on,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            label: 'Durum',
            value: error ?? 'Canli',
            icon: error == null ? Icons.sensors : Icons.warning_amber,
          ),
        ),
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E6EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF146C94)),
          const Spacer(),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: connected ? 'WebSocket bagli' : 'Demo veri veya baglanti bekleniyor',
      child: Icon(
        connected ? Icons.cloud_done : Icons.cloud_off,
        color: connected ? const Color(0xFF238636) : const Color(0xFF8A6D3B),
      ),
    );
  }
}

class CampusMap extends StatelessWidget {
  const CampusMap({super.key, required this.snapshot});

  final DensitySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD8E0E6)),
        ),
        child: CustomPaint(
          painter: CampusHeatMapPainter(snapshot.zones),
          child: Stack(
            children: [
              for (final zone in snapshot.zones)
                Positioned.fill(
                  child: FractionalTranslation(
                    translation: Offset(zone.mapX - 0.5, zone.mapY - 0.5),
                    child: Center(
                      child: ZoneMarker(zone: zone),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ZoneMarker extends StatelessWidget {
  const ZoneMarker({super.key, required this.zone});

  final ZoneDensity zone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _densityColor(zone.density),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                zone.density.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Text(
            zone.zoneName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class CampusHeatMapPainter extends CustomPainter {
  CampusHeatMapPainter(this.zones);

  final List<ZoneDensity> zones;

  @override
  void paint(Canvas canvas, Size size) {
    _drawCampusPlan(canvas, size);
    for (final zone in zones) {
      _drawHeatPoint(canvas, size, zone);
    }
  }

  void _drawCampusPlan(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFE9EEF2)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final buildingPaint = Paint()..color = const Color(0xFFD7E7DE);
    final outlinePaint = Paint()
      ..color = const Color(0xFFB8C7D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(size.width * 0.12, size.height * 0.52), Offset(size.width * 0.88, size.height * 0.52), roadPaint);
    canvas.drawLine(Offset(size.width * 0.45, size.height * 0.15), Offset(size.width * 0.45, size.height * 0.85), roadPaint);

    final buildings = [
      Rect.fromLTWH(size.width * 0.12, size.height * 0.12, size.width * 0.28, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.60, size.height * 0.16, size.width * 0.25, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.50, size.height * 0.62, size.width * 0.30, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.10, size.height * 0.62, size.width * 0.25, size.height * 0.22),
    ];

    for (final rect in buildings) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, buildingPaint);
      canvas.drawRRect(rrect, outlinePaint);
    }
  }

  void _drawHeatPoint(Canvas canvas, Size size, ZoneDensity zone) {
    final center = Offset(size.width * zone.mapX, size.height * zone.mapY);
    final radius = math.max(size.shortestSide * 0.12, 42) * (0.7 + zone.density / 100);
    final color = _densityColor(zone.density);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.58),
          color.withOpacity(0.20),
          color.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(CampusHeatMapPainter oldDelegate) => oldDelegate.zones != zones;
}

class ZoneList extends StatelessWidget {
  const ZoneList({super.key, required this.zones});

  final List<ZoneDensity> zones;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final zone in zones)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ZoneRow(zone: zone),
          ),
      ],
    );
  }
}

class ZoneRow extends StatelessWidget {
  const ZoneRow({super.key, required this.zone});

  final ZoneDensity zone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E6EB)),
      ),
      child: Row(
        children: [
          Icon(Icons.router, color: _densityColor(zone.density)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.zoneName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${zone.apName} - ${zone.deviceCount} cihaz - ${zone.signalStrength} dBm'),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            child: LinearProgressIndicator(
              minHeight: 8,
              value: zone.density / 100,
              color: _densityColor(zone.density),
              backgroundColor: const Color(0xFFE9EEF2),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            child: Text(
              '%${zone.density}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

Color _densityColor(int density) {
  if (density >= 75) {
    return const Color(0xFFD83A2E);
  }
  if (density >= 45) {
    return const Color(0xFFF2A541);
  }
  return const Color(0xFF2E8B57);
}

class DensitySnapshot {
  DensitySnapshot({
    required this.campus,
    required this.updatedAt,
    required this.totalDevices,
    required this.zones,
  });

  final String campus;
  final DateTime updatedAt;
  final int totalDevices;
  final List<ZoneDensity> zones;

  factory DensitySnapshot.fromJson(Map<String, dynamic> json) {
    final zoneItems = json['zones'] as List<dynamic>? ?? [];
    return DensitySnapshot(
      campus: json['campus'] as String? ?? 'Demo Kampus',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      totalDevices: json['total_devices'] as int? ?? 0,
      zones: zoneItems.map((item) => ZoneDensity.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }

  factory DensitySnapshot.demo() {
    final zones = [
      ZoneDensity(
        zoneId: 'library',
        zoneName: 'Kutuphane',
        apId: 1,
        apName: 'Kutuphane AP',
        deviceCount: 32,
        density: 36,
        signalStrength: -58,
        mapX: 0.28,
        mapY: 0.28,
        status: 'low',
      ),
      ZoneDensity(
        zoneId: 'cafeteria',
        zoneName: 'Kafeterya',
        apId: 2,
        apName: 'Kafeterya AP',
        deviceCount: 78,
        density: 65,
        signalStrength: -49,
        mapX: 0.70,
        mapY: 0.34,
        status: 'medium',
      ),
      ZoneDensity(
        zoneId: 'classrooms',
        zoneName: 'Derslikler',
        apId: 3,
        apName: 'Derslikler AP',
        deviceCount: 118,
        density: 74,
        signalStrength: -53,
        mapX: 0.58,
        mapY: 0.68,
        status: 'medium',
      ),
      ZoneDensity(
        zoneId: 'sports',
        zoneName: 'Spor Salonu',
        apId: 4,
        apName: 'Spor Salonu AP',
        deviceCount: 21,
        density: 30,
        signalStrength: -65,
        mapX: 0.20,
        mapY: 0.70,
        status: 'low',
      ),
    ];
    return DensitySnapshot(
      campus: 'Demo Kampus',
      updatedAt: DateTime.now(),
      totalDevices: zones.fold(0, (sum, zone) => sum + zone.deviceCount),
      zones: zones,
    );
  }
}

class ZoneDensity {
  ZoneDensity({
    required this.zoneId,
    required this.zoneName,
    required this.apId,
    required this.apName,
    required this.deviceCount,
    required this.density,
    required this.signalStrength,
    required this.mapX,
    required this.mapY,
    required this.status,
  });

  final String zoneId;
  final String zoneName;
  final int apId;
  final String apName;
  final int deviceCount;
  final int density;
  final int signalStrength;
  final double mapX;
  final double mapY;
  final String status;

  factory ZoneDensity.fromJson(Map<String, dynamic> json) {
    return ZoneDensity(
      zoneId: json['zone_id'] as String? ?? '',
      zoneName: json['zone_name'] as String? ?? '',
      apId: json['ap_id'] as int? ?? 0,
      apName: json['ap_name'] as String? ?? '',
      deviceCount: json['device_count'] as int? ?? 0,
      density: json['density'] as int? ?? 0,
      signalStrength: json['signal_strength'] as int? ?? 0,
      mapX: (json['map_x'] as num?)?.toDouble() ?? 0.5,
      mapY: (json['map_y'] as num?)?.toDouble() ?? 0.5,
      status: json['status'] as String? ?? 'low',
    );
  }
}
