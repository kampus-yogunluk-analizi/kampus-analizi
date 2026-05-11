import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/heatmap_point.dart';

class HeatmapApiService {
  static const String baseUrl =
    'http://192.168.1.110:8000';
    
  Future<List<HeatmapPoint>> fetchHeatmapData() async {

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/heatmap-data'),
    );

    if (response.statusCode == 200) {

      final List data = jsonDecode(response.body);

      return data
          .map((item) => HeatmapPoint.fromJson(item))
          .toList();

    } else {

      throw Exception('Heatmap verisi alınamadı');
    }
  }
}