class HeatmapPoint {
  final int? buildingId;
  final String name;
  final double lat;
  final double lng;
  final int intensity;
  final int wifiCount;
  final int bluetoothCount;
  final double signalStrength;
  final String densityLevel;
  final DateTime? timestamp;
  final int confidenceScore;
  final String trend;
  final bool isAnomaly;
  final int sampleCount;
  // RF analiz alanları
  final RfMetrics? rf;

  HeatmapPoint({
    required this.buildingId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.intensity,
    required this.wifiCount,
    required this.bluetoothCount,
    required this.signalStrength,
    required this.densityLevel,
    required this.timestamp,
    this.confidenceScore = 0,
    this.trend = 'stable',
    this.isAnomaly = false,
    this.sampleCount = 0,
    this.rf,
  });

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      buildingId: (json['building_id'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      intensity: (json['intensity'] as num?)?.toInt() ?? 0,
      wifiCount: (json['wifi_count'] as num?)?.toInt() ?? 0,
      bluetoothCount: (json['bluetooth_count'] as num?)?.toInt() ?? 0,
      signalStrength: (json['signal_strength'] as num?)?.toDouble() ?? -95,
      densityLevel: json['density_level'] as String? ?? 'low',
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.tryParse(json['timestamp'] as String),
      confidenceScore: (json['confidence_score'] as num?)?.toInt() ?? 0,
      trend: json['trend'] as String? ?? 'stable',
      isAnomaly: json['is_anomaly'] as bool? ?? false,
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
      rf: json['rf'] != null
          ? RfMetrics.fromJson(json['rf'] as Map<String, dynamic>)
          : null,
    );
  }

  int get totalDevices => wifiCount + bluetoothCount;
}

class RfMetrics {
  final double estimatedDistanceM;
  final double snrDb;
  final String channelQuality;
  final double shannonCapacityMbps;
  final double ber;
  final String berQuality;
  final int interferenceScore;
  final String recommendedChannel;
  final Map<String, String> formulas;

  RfMetrics({
    required this.estimatedDistanceM,
    required this.snrDb,
    required this.channelQuality,
    required this.shannonCapacityMbps,
    required this.ber,
    required this.berQuality,
    required this.interferenceScore,
    required this.recommendedChannel,
    required this.formulas,
  });

  factory RfMetrics.fromJson(Map<String, dynamic> json) {
    final formMap = <String, String>{};
    if (json['formulas'] is Map) {
      (json['formulas'] as Map).forEach((k, v) {
        formMap[k.toString()] = v.toString();
      });
    }
    return RfMetrics(
      estimatedDistanceM:
          (json['estimated_distance_m'] as num?)?.toDouble() ?? 0,
      snrDb: (json['snr_db'] as num?)?.toDouble() ?? 0,
      channelQuality: json['channel_quality'] as String? ?? 'fair',
      shannonCapacityMbps:
          (json['shannon_capacity_mbps'] as num?)?.toDouble() ?? 0,
      ber: (json['ber'] as num?)?.toDouble() ?? 1.0,
      berQuality: json['ber_quality'] as String? ?? 'poor',
      interferenceScore:
          (json['interference_score'] as num?)?.toInt() ?? 0,
      recommendedChannel:
          json['recommended_channel'] as String? ?? '2.4 GHz',
      formulas: formMap,
    );
  }
}

class HistoryPoint {
  final DateTime hour;
  final int avgIntensity;
  final String densityLevel;
  final int sampleCount;

  HistoryPoint({
    required this.hour,
    required this.avgIntensity,
    required this.densityLevel,
    required this.sampleCount,
  });

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    return HistoryPoint(
      hour: DateTime.parse(json['hour'] as String),
      avgIntensity: (json['avg_intensity'] as num?)?.toInt() ?? 0,
      densityLevel: json['density_level'] as String? ?? 'low',
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
    );
  }
}
