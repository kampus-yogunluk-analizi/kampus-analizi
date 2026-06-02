import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/heatmap_point.dart';
import '../screens/rf_analysis_screen.dart';
import '../services/heatmap_api_service.dart';
import '../theme/app_theme.dart';
import 'density_history_chart.dart';

class BuildingDetailSheet extends StatefulWidget {
  final HeatmapPoint point;

  const BuildingDetailSheet({super.key, required this.point});

  static void show(BuildContext context, HeatmapPoint point) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (_, controller) => BuildingDetailSheet(point: point),
      ),
    );
  }

  @override
  State<BuildingDetailSheet> createState() => _BuildingDetailSheetState();
}

class _BuildingDetailSheetState extends State<BuildingDetailSheet> {
  List<HistoryPoint> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    if (widget.point.buildingId != null) {
      HeatmapApiService()
          .fetchBuildingHistory(widget.point.buildingId!)
          .then((h) {
        if (mounted) setState(() { _history = h; _loadingHistory = false; });
      }).catchError((_) {
        if (mounted) setState(() => _loadingHistory = false);
      });
    } else {
      _loadingHistory = false;
    }
  }

  Color get _densityColor {
    if (widget.point.intensity >= 70) return AppColors.densityHigh;
    if (widget.point.intensity >= 35) return AppColors.densityMedium;
    return AppColors.densityLow;
  }

  String get _densityLabel {
    if (widget.point.intensity >= 70) return 'Çok Yoğun';
    if (widget.point.intensity >= 35) return 'Orta Yoğun';
    return 'Sakin';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final divColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildHeader(textColor, subColor),
            const SizedBox(height: 20),
            if (widget.point.isAnomaly) ...[
              _buildAnomalyBanner(),
              const SizedBox(height: 16),
            ],
            _buildStatsRow(textColor, subColor),
            const SizedBox(height: 16),
            Divider(color: divColor, height: 1),
            const SizedBox(height: 16),
            _buildSignalSection(textColor, subColor),
            const SizedBox(height: 16),
            Divider(color: divColor, height: 1),
            const SizedBox(height: 16),
            _buildConfidenceSection(textColor, subColor),
            const SizedBox(height: 16),
            Divider(color: divColor, height: 1),
            const SizedBox(height: 16),
            _buildHistorySection(textColor, subColor, isDark),
            const SizedBox(height: 20),
            if (widget.point.timestamp != null)
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 13, color: subColor),
                  const SizedBox(width: 5),
                  Text(
                    'Son güncelleme: ${_formatTime(widget.point.timestamp!)}',
                    style: GoogleFonts.inter(fontSize: 12, color: subColor),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RfAnalysisScreen(point: widget.point),
                    ),
                  );
                },
                icon: const Icon(Icons.cell_tower_rounded, size: 18),
                label: Text(
                  'RF Analizi Göster',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subColor) {
    return Row(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: _densityColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.apartment_rounded, color: _densityColor, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.point.name,
                style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w700, color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _densityBadge(),
                  const SizedBox(width: 8),
                  _trendBadge(),
                ],
              ),
            ],
          ),
        ),
        _intensityRing(textColor),
      ],
    );
  }

  Widget _densityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _densityColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _densityLabel,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700, color: _densityColor,
        ),
      ),
    );
  }

  Widget _trendBadge() {
    final trend = widget.point.trend;
    final (icon, color, label) = switch (trend) {
      'rising' => (Icons.trending_up_rounded, AppColors.densityHigh, 'Artıyor'),
      'falling' => (Icons.trending_down_rounded, AppColors.densityLow, 'Azalıyor'),
      _ => (Icons.trending_flat_rounded, AppColors.accent, 'Sabit'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _intensityRing(Color textColor) {
    return SizedBox(
      width: 58, height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 54, height: 54,
            child: CircularProgressIndicator(
              value: widget.point.intensity / 100,
              strokeWidth: 5,
              backgroundColor: _densityColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(_densityColor),
            ),
          ),
          Text(
            '${widget.point.intensity}',
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w800, color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Anormal ölçüm tespit edildi — bu değer geçmiş verilerden önemli ölçüde sapıyor.',
              style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.warning, height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color textColor, Color subColor) {
    return Row(
      children: [
        Expanded(child: _statCard(Icons.wifi_rounded, 'Wi-Fi',
            '${widget.point.wifiCount}', AppColors.primary, textColor, subColor)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(Icons.bluetooth_rounded, 'Bluetooth',
            '${widget.point.bluetoothCount}', AppColors.accent, textColor, subColor)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(Icons.devices_rounded, 'Toplam',
            '${widget.point.totalDevices}', _densityColor, textColor, subColor)),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color,
      Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: subColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSignalSection(Color textColor, Color subColor) {
    final progress =
        ((widget.point.signalStrength + 100) / 60).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sinyal Gücü',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: _densityColor.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(_densityColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${widget.point.signalStrength.toStringAsFixed(0)} dBm',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfidenceSection(Color textColor, Color subColor) {
    final confidence = widget.point.confidenceScore;
    final confColor = confidence >= 70
        ? AppColors.densityLow
        : confidence >= 40
            ? AppColors.densityMedium
            : AppColors.densityHigh;
    final confLabel = confidence >= 70
        ? 'Yüksek Güven'
        : confidence >= 40
            ? 'Orta Güven'
            : 'Düşük Güven';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ölçüm Güvenilirliği',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: confColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                confLabel,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: confColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: confidence / 100,
                  minHeight: 8,
                  backgroundColor: confColor.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(confColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '%$confidence',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.point.sampleCount} ölçüm baz alındı · Sinyal + tazelik + örnek sayısı',
          style: GoogleFonts.inter(fontSize: 11, color: subColor),
        ),
      ],
    );
  }

  Widget _buildHistorySection(Color textColor, Color subColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Son 24 Saat',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 12),
        if (_loadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          )
        else
          DensityHistoryChart(history: _history, isDark: isDark),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}
