import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/heatmap_point.dart';

class HeatmapApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  Future<List<HeatmapPoint>> fetchHeatmapData() async {
    final uri = Uri.parse('$baseUrl/api/v1/heatmap-data');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! List) {
        throw const FormatException('Heatmap cevabı liste formatında değil.');
      }

      return decoded
          .map(
            (item) => HeatmapPoint.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    throw Exception(
      'Heatmap verisi alınamadı: ${response.statusCode} ${response.reasonPhrase}',
    );
  }
}
