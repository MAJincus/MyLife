import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm.dart';

/// Client pour les API compatibles OpenAI (Gemini via endpoint OpenAI,
/// Groq, GitHub Models, ou tout point de terminaison /chat/completions).
class OpenAiCompatClient implements LlmClient {
  OpenAiCompatClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  @override
  Future<LlmResult> complete(
    List<LlmMessage> messages, {
    String? system,
    List<LlmTool> tools = const [],
    int maxTokens = 1024,
  }) async {
    if (apiKey.isEmpty) {
      throw LlmException('Aucune clé configurée. Va dans Réglages ▸ Assistant.');
    }

    final msgs = <Map<String, dynamic>>[
      if (system != null) {'role': 'system', 'content': system},
      for (final m in messages) ..._translate(m),
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': msgs,
      'max_tokens': maxTokens,
      if (tools.isNotEmpty)
        'tools': [
          for (final t in tools)
            {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameters,
              },
            },
        ],
    };

    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}'
        '/chat/completions');
    late http.Response res;
    try {
      res = await http.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      throw LlmException('Réseau indisponible : $e');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw LlmException('Clé refusée (${res.statusCode}). Vérifie-la dans '
          'Réglages.');
    }
    if (res.statusCode >= 400) {
      throw LlmException('Erreur ${res.statusCode} : ${_errorOf(res.body)}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw LlmException('Réponse vide du modèle.');
    }
    final message = (choices.first as Map)['message'] as Map<String, dynamic>;
    final text = (message['content'] ?? '').toString();

    final toolCalls = <LlmToolCall>[];
    final rawCalls = message['tool_calls'] as List<dynamic>?;
    if (rawCalls != null) {
      for (final c in rawCalls) {
        final fn = (c as Map)['function'] as Map<String, dynamic>;
        Map<String, dynamic> args = {};
        try {
          final raw = fn['arguments'];
          if (raw is String && raw.isNotEmpty) {
            args = (jsonDecode(raw) as Map).cast<String, dynamic>();
          } else if (raw is Map) {
            args = raw.cast<String, dynamic>();
          }
        } catch (_) {}
        toolCalls.add(LlmToolCall(
          id: (c['id'] ?? 'call_${toolCalls.length}').toString(),
          name: fn['name'].toString(),
          args: args,
        ));
      }
    }

    return LlmResult(text: text.trim(), toolCalls: toolCalls);
  }

  List<Map<String, dynamic>> _translate(LlmMessage m) {
    switch (m.role) {
      case 'user':
        return [
          {'role': 'user', 'content': m.text ?? ''}
        ];
      case 'assistant':
        final msg = <String, dynamic>{
          'role': 'assistant',
          'content': (m.text == null || m.text!.isEmpty) ? null : m.text,
        };
        if (m.toolCalls != null && m.toolCalls!.isNotEmpty) {
          msg['tool_calls'] = [
            for (final tc in m.toolCalls!)
              {
                'id': tc.id,
                'type': 'function',
                'function': {
                  'name': tc.name,
                  'arguments': jsonEncode(tc.args),
                },
              },
          ];
        }
        return [msg];
      case 'tool':
        return [
          {
            'role': 'tool',
            'tool_call_id': m.toolCallId,
            'content': m.text ?? '',
          }
        ];
      default:
        return const [];
    }
  }

  String _errorOf(String body) {
    try {
      final e = jsonDecode(body);
      return (e['error']?['message'] ?? e['message'] ?? body).toString();
    } catch (_) {
      return body;
    }
  }
}
