import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm.dart';

/// Client pour l'API Messages d'Anthropic (format natif tool_use).
class AnthropicClient implements LlmClient {
  AnthropicClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  static const _version = '2023-06-01';

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

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': _buildMessages(messages),
      'system': ?system,
      if (tools.isNotEmpty)
        'tools': [
          for (final t in tools)
            {
              'name': t.name,
              'description': t.description,
              'input_schema': t.parameters,
            },
        ],
    };

    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/messages');
    late http.Response res;
    try {
      res = await http.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _version,
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      throw LlmException('Réseau indisponible : $e');
    }

    if (res.statusCode == 401) {
      throw LlmException('Clé refusée (401). Vérifie-la dans Réglages.');
    }
    if (res.statusCode >= 400) {
      String detail = res.body;
      try {
        detail =
            (jsonDecode(res.body)['error']?['message'] ?? detail).toString();
      } catch (_) {}
      throw LlmException('Erreur ${res.statusCode} : $detail');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? const [];
    final buffer = StringBuffer();
    final toolCalls = <LlmToolCall>[];
    for (final block in content) {
      if (block is! Map) continue;
      if (block['type'] == 'text') {
        buffer.write(block['text']);
      } else if (block['type'] == 'tool_use') {
        toolCalls.add(LlmToolCall(
          id: block['id'].toString(),
          name: block['name'].toString(),
          args: (block['input'] as Map?)?.cast<String, dynamic>() ?? {},
        ));
      }
    }
    return LlmResult(text: buffer.toString().trim(), toolCalls: toolCalls);
  }

  /// Construit les messages Anthropic ; regroupe les messages 'tool'
  /// consécutifs en un seul message user avec plusieurs tool_result.
  List<Map<String, dynamic>> _buildMessages(List<LlmMessage> messages) {
    final out = <Map<String, dynamic>>[];
    var i = 0;
    while (i < messages.length) {
      final m = messages[i];
      if (m.role == 'tool') {
        final results = <Map<String, dynamic>>[];
        while (i < messages.length && messages[i].role == 'tool') {
          results.add({
            'type': 'tool_result',
            'tool_use_id': messages[i].toolCallId,
            'content': messages[i].text ?? '',
          });
          i++;
        }
        out.add({'role': 'user', 'content': results});
        continue;
      }
      if (m.role == 'assistant') {
        final blocks = <Map<String, dynamic>>[
          if (m.text != null && m.text!.isNotEmpty)
            {'type': 'text', 'text': m.text},
          for (final tc in m.toolCalls ?? const <LlmToolCall>[])
            {'type': 'tool_use', 'id': tc.id, 'name': tc.name, 'input': tc.args},
        ];
        out.add({'role': 'assistant', 'content': blocks});
      } else {
        out.add({'role': 'user', 'content': m.text ?? ''});
      }
      i++;
    }
    return out;
  }
}
