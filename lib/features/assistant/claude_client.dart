import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/security/secure_store.dart';

class ClaudeException implements Exception {
  ClaudeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Message de conversation envoyé à l'API Claude.
class ClaudeMessage {
  ClaudeMessage(this.role, this.content);
  final String role; // 'user' | 'assistant'
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Client minimal pour l'API Messages d'Anthropic.
class ClaudeClient {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _version = '2023-06-01';
  static const model = 'claude-opus-4-8';

  /// Envoie la conversation et renvoie la réponse texte de l'assistant.
  static Future<String> send({
    required List<ClaudeMessage> messages,
    String? systemPrompt,
    int maxTokens = 1024,
  }) async {
    final data = await createMessage(
      messages: messages.map((m) => m.toJson()).toList(),
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    );
    final content = data['content'] as List<dynamic>?;
    if (content == null || content.isEmpty) {
      throw ClaudeException('Réponse vide de Claude.');
    }
    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text') {
        buffer.write(block['text']);
      }
    }
    return buffer.toString().trim();
  }

  /// Appel bas-niveau : renvoie la réponse décodée (avec blocs `content` et
  /// `stop_reason`), pour gérer les conversations avec outils (tool use).
  /// [messages] contient des maps brutes {role, content}.
  static Future<Map<String, dynamic>> createMessage({
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
    List<Map<String, dynamic>>? tools,
    int maxTokens = 1024,
  }) async {
    final key = await SecureStore.claudeApiKey();
    if (key == null || key.isEmpty) {
      throw ClaudeException(
        'Aucune clé API Claude. Ajoute-la dans Réglages ▸ Clé API.',
      );
    }

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': messages,
      'system': ?systemPrompt,
      'tools': ?tools,
    };

    late http.Response res;
    try {
      res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'content-type': 'application/json',
          'x-api-key': key,
          'anthropic-version': _version,
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      throw ClaudeException('Réseau indisponible : $e');
    }

    if (res.statusCode == 401) {
      throw ClaudeException('Clé API refusée (401). Vérifie-la dans Réglages.');
    }
    if (res.statusCode >= 400) {
      String detail = res.body;
      try {
        detail = (jsonDecode(res.body)['error']?['message'] ?? detail)
            .toString();
      } catch (_) {}
      throw ClaudeException('Erreur ${res.statusCode} : $detail');
    }

    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
