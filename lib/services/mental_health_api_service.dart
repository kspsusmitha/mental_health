import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MentalHealthApiService {
  static const String _baseUrl = 'http://localhost:8000/api/v1';
  String? _apiKey;

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_apiKey != null) {
      headers['X-API-KEY'] = _apiKey!;
    }
    return headers;
  }

  Future<Map<String, dynamic>> onboard(
    String username,
    int age,
    String background,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/onboard/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'age': age,
          'background': background,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data['Data'] ?? data;
      } else {
        throw Exception(data['message'] ?? 'Onboarding failed');
      }
    } catch (e) {
      debugPrint('Error in onboard API: $e');
      rethrow;
    }
  }

  Future<String> chat(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/'),
        headers: _getHeaders(),
        body: jsonEncode({'message': message}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['Data']?['response'] ?? data['response'] ?? 'No response';
      } else {
        throw Exception(data['message'] ?? 'Chat failed');
      }
    } catch (e) {
      debugPrint('Error in chat API: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeMood() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analysis/analyze'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['Data'] ?? data;
      } else {
        throw Exception(data['message'] ?? 'Analysis failed');
      }
    } catch (e) {
      debugPrint('Error in analyzeMood API: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRecommendations() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analysis/recommendations'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['Data'] ?? data;
      } else {
        throw Exception(data['message'] ?? 'Recommendations failed');
      }
    } catch (e) {
      debugPrint('Error in getRecommendations API: $e');
      rethrow;
    }
  }
}
