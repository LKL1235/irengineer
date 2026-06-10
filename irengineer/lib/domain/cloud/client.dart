import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../coach/report.dart';
import 'validate.dart';

const _systemPrompt = '''You are a racing coach. Explain the CoachReport in 2-3 short sentences.
Do NOT change any numeric values (lap deltas, corner deltas, lap times). Use only numbers from the JSON.''';

class CloudClient {
  CloudClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 8),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String model;
  final Duration timeout;
  final http.Client _http;

  Future<String> explain(CoachReport report) async {
    final bodyJson = report.toJsonString();
    final reqBody = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': bodyJson},
      ],
    };
    final data = utf8.encode(jsonEncode(reqBody));

    final uri = Uri.parse('$baseUrl/chat/completions');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..bodyBytes = data;

    final streamed = await _http.send(request).timeout(timeout);
    final raw = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 400) {
      throw Exception('cloud API ${streamed.statusCode}: $raw');
    }

    final out = jsonDecode(raw) as Map<String, dynamic>;
    final choices = out['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('empty LLM response');
    }
    final message = choices.first['message'] as Map<String, dynamic>;
    final text = message['content'] as String? ?? '';
    validateExplanation(text, report);
    return text;
  }

  void close() => _http.close();
}
