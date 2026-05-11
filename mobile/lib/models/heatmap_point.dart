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
  });

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    final timestampValue = json['timestamp'] as String?;

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
      timestamp: timestampValue == null ? null : DateTime.tryParse(timestampValue),
    );
  }

  int get totalDevices => wifiCount + bluetoothCount;
}
