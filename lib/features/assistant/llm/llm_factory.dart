import 'anthropic_client.dart';
import 'llm.dart';
import 'openai_client.dart';
import 'providers.dart';

/// Construit le client LLM correspondant au fournisseur choisi dans les
/// Réglages, avec sa clé et son modèle (override éventuel).
class LlmFactory {
  LlmFactory._();

  static Future<LlmClient> current() async {
    final id = await LlmConfigStore.selectedProviderId();
    final provider = providerById(id);
    final key = await LlmConfigStore.keyFor(id) ?? '';

    var baseUrl = provider.baseUrl;
    var model = provider.defaultModel;

    if (id == 'custom') {
      baseUrl = await LlmConfigStore.customBaseUrl() ?? '';
      if (baseUrl.isEmpty) {
        throw LlmException(
            'Point de terminaison non configuré (Réglages ▸ Assistant).');
      }
    }
    final override = await LlmConfigStore.modelOverride(id);
    if (override != null && override.isNotEmpty) model = override;

    if (model.isEmpty) {
      throw LlmException('Modèle non configuré (Réglages ▸ Assistant).');
    }

    if (provider.isAnthropic) {
      return AnthropicClient(baseUrl: baseUrl, apiKey: key, model: model);
    }
    return OpenAiCompatClient(baseUrl: baseUrl, apiKey: key, model: model);
  }

  /// Nom lisible du fournisseur actif (pour l'UI).
  static Future<String> currentName() async {
    final id = await LlmConfigStore.selectedProviderId();
    return providerById(id).name;
  }
}
