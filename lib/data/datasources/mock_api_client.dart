import 'dart:convert';
import 'package:http/http.dart' as http;

class MockApiClient {
  final http.Client client;

  final String baseUrl = 'https://jsonplaceholder.typicode.com/posts';

  MockApiClient({http.Client? client}) : client = client ?? http.Client();

  /// Returns true if success (200-299), throws Exception on failure.
  Future<bool> uploadLocation(Map<String, dynamic> payload) async {
    try {
      final response = await client.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      // Rethrow so the repository knows it failed
      rethrow;
    }
  }
}