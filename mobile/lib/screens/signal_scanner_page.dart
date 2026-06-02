import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SignalScannerPage extends StatefulWidget {
  const SignalScannerPage({super.key});

  @override
  State<SignalScannerPage> createState() => _SignalScannerPageState();
}

class _SignalScannerPageState extends State<SignalScannerPage>
    with TickerProviderStateMixin {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanSubscription;
  late AnimationController _radarController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _startScan();
  }

  void _startScan() async {
    setState(() {
      isScanning = true;
      scanResults = [];
    });

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) setState(() => scanResults = results);
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    if (mounted) setState(() => isScanning = false);
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    FlutterBluePlus.stopScan();
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _rssiColor(int rssi) {
    if (rssi > -60) return AppColors.densityLow;
    if (rssi > -80) return AppColors.densityMedium;
    return AppColors.densityHigh;
  }

  String _rssiLabel(int rssi) {
    if (rssi > -60) return 'Güçlü';
    if (rssi > -80) return 'Orta';
    return 'Zayıf';
  }

  double _rssiToProgress(int rssi) => ((rssi + 100) / 60).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildScannerVisualization(isDark, textColor),
          _buildStatsRow(textColor, subColor, cardBg, borderColor),
          const SizedBox(height: 8),
          Expanded(
            child: scanResults.isEmpty
                ? _buildEmptyState(isScanning, textColor, subColor)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: scanResults.length,
                    itemBuilder: (ctx, i) => _buildDeviceCard(
                      scanResults[i],
                      isDark,
                      textColor,
                      subColor,
                      cardBg,
                      borderColor,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sinyal Tarayıcı',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Bluetooth LE cihazları',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: isScanning ? null : _startScan,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isScanning ? 0.08 : 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isScanning)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        isScanning ? 'Tarıyor...' : 'Tara',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerVisualization(bool isDark, Color textColor) {
    return Container(
      height: 160,
      color: isDark ? AppColors.cardDark : Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _radarController,
            builder: (_, __) => CustomPaint(
              size: const Size(160, 160),
              painter: _RadarPainter(_radarController.value, isScanning),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Icon(
                  Icons.radar_rounded,
                  size: 32 + _pulseController.value * 4,
                  color: AppColors.primary
                      .withOpacity(0.6 + _pulseController.value * 0.4),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${scanResults.length} cihaz',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color textColor, Color subColor, Color cardBg,
      Color borderColor) {
    final strongCount = scanResults.where((r) => r.rssi > -60).length;
    final mediumCount =
        scanResults.where((r) => r.rssi > -80 && r.rssi <= -60).length;
    final weakCount = scanResults.where((r) => r.rssi <= -80).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
              child: _statChip('Güçlü', strongCount, AppColors.densityLow,
                  cardBg, borderColor, textColor, subColor)),
          const SizedBox(width: 8),
          Expanded(
              child: _statChip('Orta', mediumCount, AppColors.densityMedium,
                  cardBg, borderColor, textColor, subColor)),
          const SizedBox(width: 8),
          Expanded(
              child: _statChip('Zayıf', weakCount, AppColors.densityHigh,
                  cardBg, borderColor, textColor, subColor)),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color, Color cardBg,
      Color borderColor, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      bool scanning, Color textColor, Color subColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scanning ? Icons.radar_rounded : Icons.bluetooth_disabled_rounded,
            size: 56,
            color: subColor,
          ),
          const SizedBox(height: 16),
          Text(
            scanning ? 'Cihazlar aranıyor...' : 'Cihaz bulunamadı',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scanning
                ? 'Lütfen bekleyin'
                : 'Yeniden taramak için butona basın',
            style: GoogleFonts.inter(fontSize: 13, color: subColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ScanResult result, bool isDark, Color textColor,
      Color subColor, Color cardBg, Color borderColor) {
    final name = result.device.platformName.isEmpty
        ? 'Anonim Cihaz'
        : result.device.platformName;
    final rssi = result.rssi;
    final color = _rssiColor(rssi);
    final progress = _rssiToProgress(rssi);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bluetooth_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.device.remoteId.toString(),
                  style: GoogleFonts.inter(fontSize: 11, color: subColor),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: color.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$rssi dBm',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _rssiLabel(rssi),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final bool isScanning;
  _RadarPainter(this.progress, this.isScanning);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final circlePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * i / 3, circlePaint);
    }

    if (!isScanning) return;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          AppColors.primary.withOpacity(0),
          AppColors.primary.withOpacity(0.2),
        ],
        startAngle: 0,
        endAngle: pi / 2,
        transform: GradientRotation(progress * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);

    final linePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.5)
      ..strokeWidth = 2;

    final angle = progress * 2 * pi;
    canvas.drawLine(
      center,
      Offset(center.dx + maxRadius * cos(angle),
          center.dy + maxRadius * sin(angle)),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.progress != progress || old.isScanning != isScanning;
}
