import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/heatmap_point.dart';
import '../theme/app_theme.dart';

class DensityHistoryChart extends StatelessWidget {
  final List<HistoryPoint> history;
  final bool isDark;

  const DensityHistoryChart({
    super.key,
    required this.history,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Yeterli geçmiş veri yok',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
      );
    }

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white38 : Colors.black38;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 100,
          child: CustomPaint(
            painter: _BarChartPainter(history: history, isDark: isDark),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 6),
        _buildXLabels(subColor),
        const SizedBox(height: 8),
        _buildLegend(textColor, subColor),
      ],
    );
  }

  Widget _buildXLabels(Color subColor) {
    final visibleItems = history.length > 8
        ? history.where((h) => history.indexOf(h) % 2 == 0).toList()
        : history;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: visibleItems.map((h) {
        return Text(
          '${h.hour.hour.toString().padLeft(2, '0')}:00',
          style: GoogleFonts.inter(fontSize: 9, color: subColor),
        );
      }).toList(),
    );
  }

  Widget _buildLegend(Color textColor, Color subColor) {
    if (history.isEmpty) return const SizedBox();
    final avg = history.fold(0, (s, h) => s + h.avgIntensity) ~/ history.length;
    final maxH = history.reduce((a, b) => a.avgIntensity > b.avgIntensity ? a : b);

    return Row(
      children: [
        _legendChip('Ort.', '$avg', AppColors.primary, textColor),
        const SizedBox(width: 8),
        _legendChip('Zirve', '${maxH.avgIntensity}', AppColors.densityHigh, textColor),
        const SizedBox(width: 8),
        _legendChip('Saat', '${maxH.hour.hour}:00', AppColors.densityMedium, textColor),
      ],
    );
  }

  Widget _legendChip(String label, String value, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: GoogleFonts.inter(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<HistoryPoint> history;
  final bool isDark;

  _BarChartPainter({required this.history, required this.isDark});

  Color _colorFor(String level) {
    switch (level) {
      case 'high':
        return AppColors.densityHigh;
      case 'medium':
        return AppColors.densityMedium;
      default:
        return AppColors.densityLow;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final barWidth = (size.width / history.length) * 0.65;
    final gap = (size.width / history.length) * 0.35;

    for (int i = 0; i < history.length; i++) {
      final h = history[i];
      final barHeight = (h.avgIntensity / 100) * size.height;
      final x = (size.width / history.length) * i + gap / 2;
      final y = size.height - barHeight;

      final color = _colorFor(h.densityLevel);

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, y),
          Offset(x, size.height),
          [color, color.withOpacity(0.5)],
        );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.history != history || old.isDark != isDark;
}
