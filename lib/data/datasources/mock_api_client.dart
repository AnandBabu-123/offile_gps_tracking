import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;


class MockApiClient {
  final http.Client client;
  final String baseUrl = 'https://jsonplaceholder.typicode.com/posts';

  // FAKE SERVER DATABASE: Tracks IDs the server has already seen
  static final Set<String> _serverDatabase = {};

  MockApiClient({http.Client? client}) : client = client ?? http.Client();

  Future<bool> uploadLocation(Map<String, dynamic> payload) async {
    // Simulate random failure 30% of the time
    if (Random().nextDouble() < 0.3) {
      throw Exception('Simulated API Failure');
    }

    final recordId = payload['id'] as String;

    // DUPLICATE PREVENTION LOGIC
    if (_serverDatabase.contains(recordId)) {

      debugPrint('Server: Duplicate ID $recordId received. Ignoring, returning 200.');

      return true; // Return success so the phone stops retrying
    }

    try {
      final response = await client.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _serverDatabase.add(recordId); // Save ID to fake server DB
        debugPrint('Server: Saved new record $recordId');
        return true;
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}