import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dashboard_data.dart';

class DemandApi {
  DemandApi({http.Client? client})
      : _client = client ?? http.Client(),
        _baseUrl = const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8000/api',
        );

  final http.Client _client;
  final String _baseUrl;

  Future<(Overview, List<Product>, List<InventoryRisk>)> loadDashboard() async {
    final responses = await Future.wait([
      _get('/overview/'),
      _get('/products/'),
      _get('/inventory/risks/'),
    ]);
    final overviewJson = jsonDecode(responses[0].body) as Map<String, dynamic>;
    final productsJson = jsonDecode(responses[1].body) as List<dynamic>;
    final risksJson = jsonDecode(responses[2].body) as List<dynamic>;
    return (
      Overview.fromJson(overviewJson),
      productsJson
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      risksJson
          .map((item) => InventoryRisk.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> adjustInventory({
    required int productId,
    required int quantityChange,
    String note = '',
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/inventory/movements/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'product_id': productId,
            'quantity_change': quantityChange,
            'note': note,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic>
          ? body.values.expand((value) => value is List ? value : [value]).join(' ')
          : 'Request failed.';
      throw Exception(detail);
    }
  }

  Future<http.Response> _get(String path) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl$path'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('The API returned ${response.statusCode}.');
    }
    return response;
  }
}
