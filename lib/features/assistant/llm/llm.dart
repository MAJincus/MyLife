// Couche d'abstraction LLM : types unifiés indépendants du fournisseur
// (Anthropic, OpenAI-compatible : Gemini, GitHub Models, Groq…).

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Un appel d'outil demandé par le modèle.
class LlmToolCall {
  LlmToolCall({required this.id, required this.name, required this.args});
  final String id;
  final String name;
  final Map<String, dynamic> args;
}

/// Message de conversation, format unifié.
class LlmMessage {
  LlmMessage._({
    required this.role,
    this.text,
    this.toolCalls,
    this.toolCallId,
  });

  /// 'user' | 'assistant' | 'tool'
  final String role;
  final String? text;
  final List<LlmToolCall>? toolCalls;
  final String? toolCallId;

  factory LlmMessage.user(String text) =>
      LlmMessage._(role: 'user', text: text);

  factory LlmMessage.assistant(String? text, List<LlmToolCall> toolCalls) =>
      LlmMessage._(role: 'assistant', text: text, toolCalls: toolCalls);

  /// Résultat d'un outil (renvoyé au modèle).
  factory LlmMessage.tool(String toolCallId, String result) =>
      LlmMessage._(role: 'tool', toolCallId: toolCallId, text: result);
}

/// Définition d'un outil exposé au modèle.
class LlmTool {
  const LlmTool({
    required this.name,
    required this.description,
    required this.parameters,
  });
  final String name;
  final String description;

  /// JSON Schema de l'objet d'entrée.
  final Map<String, dynamic> parameters;
}

/// Réponse du modèle.
class LlmResult {
  LlmResult({required this.text, required this.toolCalls});
  final String text;
  final List<LlmToolCall> toolCalls;
  bool get wantsTools => toolCalls.isNotEmpty;
}

/// Client LLM : les implémentations traduisent l'historique unifié vers
/// le format du fournisseur à chaque appel (clients sans état).
abstract class LlmClient {
  Future<LlmResult> complete(
    List<LlmMessage> messages, {
    String? system,
    List<LlmTool> tools = const [],
    int maxTokens = 1024,
  });
}
