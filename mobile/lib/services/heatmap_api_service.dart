import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/heatmap_point.dart';

class HeatmapApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  Future<List<HeatmapPoint>> fetchHeatmapData() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/heatmap-data'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => HeatmapPoint.fromJson(item)).toList();
    } else {
      throw Exception('Heatmap verisi alınamadı');
    }
  }

  Future<List<HistoryPoint>> fetchBuildingHistory(int buildingId, {int hours = 24}) async {
    final uri = Uri.parse('$baseUrl/api/v1/buildings/$buildingId/history?hours=$hours');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final List history = json['history'] as List? ?? [];
      return history.map((item) => HistoryPoint.fromJson(item)).toList();
    }
    return [];
  }
}
