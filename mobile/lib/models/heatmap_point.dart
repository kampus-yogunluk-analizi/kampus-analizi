class HeatmapPoint {
  final String name;
  final double lat;
  final double lng;
  final int intensity;

  HeatmapPoint({
    required this.name,
    required this.lat,
    required this.lng,
    required this.intensity,
  });

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      name: json['name'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      intensity: json['intensity'] ?? 0,
    );
  }
}
