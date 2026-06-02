import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/heatmap_point.dart';
import '../theme/app_theme.dart';

class RfAnalysisScreen extends StatefulWidget {
  final HeatmapPoint point;

  const RfAnalysisScreen({super.key, required this.point});

  @override
  State<RfAnalysisScreen> createState() => _RfAnalysisScreenState();
}

class _RfAnalysisScreenState extends State<RfAnalysisScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _rfData;
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchRfAnalysis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRfAnalysis() async {
    final id = widget.point.buildingId;
    if (id == null) {
      setState(() { _loading = false; _error = 'Bina ID yok'; });
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/v1/buildings/$id/rf-analysis'),
      );
      if (res.statusCode == 200) {
        setState(() { _rfData = jsonDecode(res.body); _loading = false; });
      } else {
        setState(() { _loading = false; _error = 'Veri alınamadı'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Bağlantı hatası: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildHeader(textColor),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_error != null)
            Expanded(child: _buildError(textColor))
          else ...[
            _buildTabBar(isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPathLossTab(isDark, textColor),
                  _buildShannonTab(isDark, textColor),
                  _buildBerTab(isDark, textColor),
                  _buildInterferenceTab(isDark, textColor),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F3B8C), Color(0xFF1A56DB)],
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
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RF Analizi',
                      style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.point.name,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.7), fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                onPressed: () { setState(() { _loading = true; _rfData = null; }); _fetchRfAnalysis(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? AppColors.cardDark : Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        tabs: const [
          Tab(text: 'Path Loss'),
          Tab(text: 'Shannon'),
          Tab(text: 'BER'),
          Tab(text: 'Girişim'),
        ],
      ),
    );
  }

  // ── TAB 1: Path Loss ──────────────────────────────────────────────────────

  Widget _buildPathLossTab(bool isDark, Color textColor) {
    final pl = _rfData?['path_loss'] as Map<String, dynamic>?;
    final m = _rfData?['measurement'] as Map<String, dynamic>?;
    if (pl == null) return const SizedBox();

    final distance = pl['estimated_distance_m'] as num? ?? 0;
    final rssi = (m?['rssi_dbm'] as num?)?.toDouble() ?? -95;
    final txPower = (pl['parameters']?['tx_power_dbm'] as num?)?.toDouble() ?? -59;
    final n = (pl['parameters']?['path_loss_exponent_n'] as num?)?.toDouble() ?? 2.7;

    return _tabScroll(isDark, [
      _sectionHeader('Log-Distance Path Loss Modeli', Icons.radar_rounded, AppColors.primary, textColor),
      _formulaCard(
        'Mesafe Tahmini',
        'd = 10^((TX_Power − RSSI) / (10 × n))',
        {
          'TX_Power (1m ref)': '$txPower dBm',
          'RSSI (ölçülen)': '${rssi.toStringAsFixed(1)} dBm',
          'n (ortam faktörü)': '$n (iç mekan)',
        },
        isDark, textColor,
      ),
      _resultCard(
        Icons.straighten_rounded,
        'Tahmini Mesafe',
        '${distance.toStringAsFixed(1)} m',
        _distanceColor(distance.toDouble()),
        _distanceLabel(distance.toDouble()),
        textColor,
        isDark,
      ),
      _infoCard(
        'n Değeri Tablosu',
        {
          '2.0': 'Serbest alan (açık hava)',
          '2.5': 'Hafif engel (koridor)',
          '2.7': 'Tipik iç mekan ✓',
          '3.5': 'Yoğun iç mekan (beton)',
          '4.0+': 'Çok katlı bina',
        },
        isDark, textColor,
      ),
    ]);
  }

  // ── TAB 2: Shannon ────────────────────────────────────────────────────────

  Widget _buildShannonTab(bool isDark, Color textColor) {
    final sh = _rfData?['shannon'] as Map<String, dynamic>?;
    final snrData = _rfData?['snr'] as Map<String, dynamic>?;
    if (sh == null) return const SizedBox();

    final snr = (snrData?['snr_db'] as num?)?.toDouble() ?? 0;
    final bw = (sh['bandwidth_mhz'] as num?)?.toDouble() ?? 20;
    final cap = (sh['theoretical_capacity_mbps'] as num?)?.toDouble() ?? 0;
    final quality = sh['channel_quality'] as String? ?? 'fair';

    return _tabScroll(isDark, [
      _sectionHeader('SNR & Shannon-Hartley Teoremi', Icons.cell_tower_rounded, AppColors.accent, textColor),
      _formulaCard(
        'Sinyal/Gürültü Oranı',
        'SNR = RSSI − NoiseFloor',
        {
          'RSSI': '${_rfData?['measurement']?['rssi_dbm']} dBm',
          'Gürültü Katı': '−95 dBm (2.4 GHz iç mekan)',
          'SNR': '${snr.toStringAsFixed(1)} dB',
        },
        isDark, textColor,
      ),
      _formulaCard(
        'Kanal Kapasitesi (Shannon)',
        'C = B × log₂(1 + SNR_lin)',
        {
          'B (bant genişliği)': '${bw.toStringAsFixed(0)} MHz (Wi-Fi 2.4G)',
          'SNR_lin': '10^(${snr.toStringAsFixed(1)}/10) = ${(10 * (snr / 10)).toStringAsFixed(1)}',
          'C (teorik max)': '${cap.toStringAsFixed(2)} Mbps',
        },
        isDark, textColor,
      ),
      _resultCard(
        Icons.speed_rounded,
        'Teorik Kanal Kapasitesi',
        '${cap.toStringAsFixed(1)} Mbps',
        _qualityColor(quality),
        _qualityLabel(quality),
        textColor,
        isDark,
      ),
      _infoCard(
        'SNR → Kanal Kalitesi (IEEE 802.11)',
        {
          '≥ 25 dB': 'Mükemmel — HD video akış',
          '15–25 dB': 'İyi — VoIP, web tarama',
          '10–15 dB': 'Orta — temel internet',
          '< 10 dB': 'Zayıf — bağlantı riski',
        },
        isDark, textColor,
      ),
    ]);
  }

  // ── TAB 3: BER ────────────────────────────────────────────────────────────

  Widget _buildBerTab(bool isDark, Color textColor) {
    final ber = _rfData?['ber'] as Map<String, dynamic>?;
    if (ber == null) return const SizedBox();

    final berVal = ber['ber_value'];
    final quality = ber['quality'] as String? ?? 'poor';
    final snr = (_rfData?['snr']?['snr_db'] as num?)?.toDouble() ?? 0;

    return _tabScroll(isDark, [
      _sectionHeader('Bit Hata Oranı (BER)', Icons.error_outline_rounded, AppColors.densityHigh, textColor),
      _formulaCard(
        'BPSK Modülasyon — AWGN Kanal',
        'BER = ½ · erfc(√(SNR_lin))',
        {
          'Modülasyon': 'BPSK (Binary Phase Shift Keying)',
          'Kanal Modeli': 'AWGN (Additive White Gaussian Noise)',
          'SNR_lin': '10^(${snr.toStringAsFixed(1)}/10)',
          'BER': '$berVal',
        },
        isDark, textColor,
      ),
      _resultCard(
        Icons.bug_report_rounded,
        'Bit Hata Oranı',
        '$berVal',
        _qualityColor(quality),
        _qualityLabel(quality),
        textColor,
        isDark,
      ),
      _infoCard(
        'BER Yorumu',
        {
          '< 10⁻⁶': 'Mükemmel — fiber kalite',
          '10⁻⁶–10⁻⁴': 'İyi — kablosuz için kabul edilebilir',
          '10⁻⁴–10⁻²': 'Orta — yeniden iletim gerekebilir',
          '> 10⁻²': 'Zayıf — yüksek paket kaybı',
        },
        isDark, textColor,
      ),
      _infoCard(
        'Notlar',
        {
          'AWGN Varsayımı': 'Gerçek ortamda çok-yollu solma BER\'i artırır',
          'QPSK': 'Aynı Eb/N₀ için BPSK ≈ QPSK BER değeri',
          'FEC': 'İleri Hata Düzeltme ile gerçek BER daha düşük',
        },
        isDark, textColor,
      ),
    ]);
  }

  // ── TAB 4: Girişim ────────────────────────────────────────────────────────

  Widget _buildInterferenceTab(bool isDark, Color textColor) {
    final inter = _rfData?['interference'] as Map<String, dynamic>?;
    final m = _rfData?['measurement'] as Map<String, dynamic>?;
    if (inter == null) return const SizedBox();

    final score = (inter['interference_score'] as num?)?.toInt() ?? 0;
    final rec = inter['recommended_channel'] as String? ?? '2.4 GHz';
    final exp = inter['explanation'] as String? ?? '';
    final deviceCount = (m?['device_count'] as num?)?.toInt() ?? 0;

    final scoreColor = score >= 60
        ? AppColors.densityHigh
        : score >= 30
            ? AppColors.densityMedium
            : AppColors.densityLow;

    return _tabScroll(isDark, [
      _sectionHeader('Kanal Girişim Analizi', Icons.wifi_tethering_rounded, AppColors.warning, textColor),
      _formulaCard(
        'Girişim Skoru Modeli',
        'IS = (load · 0.6 + signal_degraded · 0.4) × 100',
        {
          'load': '$deviceCount cihaz / 25 (doyum)',
          'signal_degraded': '1 − sinyal kalitesi',
          'Girişim Skoru': '$score / 100',
        },
        isDark, textColor,
      ),
      _resultCard(
        Icons.warning_amber_rounded,
        'Kanal Girişim Skoru',
        '$score / 100',
        scoreColor,
        score >= 60 ? 'Yüksek Girişim' : score >= 30 ? 'Orta Girişim' : 'Düşük Girişim',
        textColor,
        isDark,
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_rounded, color: AppColors.primary, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Önerilen Frekans Bandı',
                    style: GoogleFonts.inter(fontSize: 12, color: textColor.withOpacity(0.6)),
                  ),
                  Text(
                    rec,
                    style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (exp.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            exp,
            style: GoogleFonts.inter(fontSize: 12, color: textColor.withOpacity(0.6)),
          ),
        ),
      const SizedBox(height: 8),
      _infoCard(
        'Frekans Bandı Karşılaştırması',
        {
          '2.4 GHz': 'Uzun menzil, daha fazla girişim, max ~54 Mbps (802.11g)',
          '5 GHz': 'Kısa menzil, az girişim, max ~3.5 Gbps (802.11ac)',
          '6 GHz': 'Wi-Fi 6E, minimum girişim, max ~9.6 Gbps (802.11ax)',
        },
        isDark, textColor,
      ),
    ]);
  }

  // ── Yardımcı Widget'lar ───────────────────────────────────────────────────

  Widget _tabScroll(bool isDark, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: children,
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulaCard(String title, String formula, Map<String, String> params,
      bool isDark, Color textColor) {
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
          ),
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: formula));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Formül kopyalandı'), duration: Duration(seconds: 1)),
              );
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Text(
                formula,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...params.entries.map((e) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key, style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                const SizedBox(width: 6),
                const Text('=', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(e.value,
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                ),
              ],
            ),
          )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _resultCard(IconData icon, String label, String value, Color color,
      String badge, Color textColor, bool isDark) {
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: textColor.withOpacity(0.6))),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(badge,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String title, Map<String, String> rows, bool isDark, Color textColor) {
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: subColor,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...rows.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(e.key,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                Expanded(
                  child: Text(e.value,
                      style: GoogleFonts.inter(fontSize: 11, color: textColor)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildError(Color textColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.signal_wifi_bad, size: 48, color: AppColors.densityHigh),
          const SizedBox(height: 12),
          Text(_error!, style: GoogleFonts.inter(color: textColor)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () { setState(() { _loading = true; _rfData = null; }); _fetchRfAnalysis(); },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  // ── Renk yardımcıları ─────────────────────────────────────────────────────

  Color _qualityColor(String q) {
    switch (q) {
      case 'excellent': return AppColors.densityLow;
      case 'good': return AppColors.accent;
      case 'fair': return AppColors.densityMedium;
      default: return AppColors.densityHigh;
    }
  }

  String _qualityLabel(String q) {
    switch (q) {
      case 'excellent': return 'Mükemmel';
      case 'good': return 'İyi';
      case 'fair': return 'Orta';
      default: return 'Zayıf';
    }
  }

  Color _distanceColor(double d) {
    if (d < 5) return AppColors.densityLow;
    if (d < 20) return AppColors.densityMedium;
    return AppColors.densityHigh;
  }

  String _distanceLabel(double d) {
    if (d < 5) return 'Çok Yakın';
    if (d < 20) return 'Yakın';
    return 'Uzak';
  }
}
