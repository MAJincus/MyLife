import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Un fournisseur LLM (preset).
class LlmProvider {
  const LlmProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    required this.isAnthropic,
    required this.keyLabel,
    required this.keyHint,
    required this.getKeyUrl,
    this.free = false,
  });

  final String id;
  final String name;
  final String baseUrl; // base OpenAI (…/v1) ou Anthropic (…/v1)
  final String defaultModel;
  final bool isAnthropic;
  final String keyLabel;
  final String keyHint;
  final String getKeyUrl;
  final bool free;
}

const kProviders = <LlmProvider>[
  LlmProvider(
    id: 'gemini',
    name: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    defaultModel: 'gemini-2.0-flash',
    isAnthropic: false,
    free: true,
    keyLabel: 'Clé API Google AI',
    keyHint: 'Commence par « AIza… »',
    getKeyUrl: 'https://aistudio.google.com/apikey',
  ),
  LlmProvider(
    id: 'groq',
    name: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'llama-3.3-70b-versatile',
    isAnthropic: false,
    free: true,
    keyLabel: 'Clé API Groq',
    keyHint: 'Commence par « gsk_… »',
    getKeyUrl: 'https://console.groq.com/keys',
  ),
  LlmProvider(
    id: 'github',
    name: 'GitHub Models',
    baseUrl: 'https://models.github.ai/inference',
    defaultModel: 'openai/gpt-4o-mini',
    isAnthropic: false,
    free: true,
    keyLabel: 'Token GitHub (PAT)',
    keyHint: 'Token « ghp_… » avec le scope models',
    getKeyUrl: 'https://github.com/settings/tokens',
  ),
  LlmProvider(
    id: 'claude',
    name: 'Claude (Anthropic)',
    baseUrl: 'https://api.anthropic.com/v1',
    defaultModel: 'claude-haiku-4-5-20251001',
    isAnthropic: true,
    free: false,
    keyLabel: 'Clé API Anthropic',
    keyHint: 'Commence par « sk-ant-… »',
    getKeyUrl: 'https://console.anthropic.com/settings/keys',
  ),
  LlmProvider(
    id: 'custom',
    name: 'OpenAI-compatible (perso)',
    baseUrl: '',
    defaultModel: '',
    isAnthropic: false,
    free: false,
    keyLabel: 'Clé API',
    keyHint: 'Point de terminaison + modèle à définir',
    getKeyUrl: '',
  ),
];

LlmProvider providerById(String id) =>
    kProviders.firstWhere((p) => p.id == id, orElse: () => kProviders.first);

/// Stockage de la config LLM (fournisseur choisi, clés, réglages perso).
class LlmConfigStore {
  LlmConfigStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _selectedKey = 'llm_provider';
  static const _defaultProvider = 'gemini';

  static Future<String> selectedProviderId() async =>
      (await _storage.read(key: _selectedKey)) ?? _defaultProvider;

  static Future<void> setProvider(String id) =>
      _storage.write(key: _selectedKey, value: id);

  static Future<String?> keyFor(String providerId) =>
      _storage.read(key: 'llm_key_$providerId');

  static Future<void> setKey(String providerId, String key) =>
      _storage.write(key: 'llm_key_$providerId', value: key.trim());

  static Future<void> clearKey(String providerId) =>
      _storage.delete(key: 'llm_key_$providerId');

  // Réglages du fournisseur « custom ».
  static Future<String?> customBaseUrl() =>
      _storage.read(key: 'llm_custom_baseurl');
  static Future<void> setCustomBaseUrl(String v) =>
      _storage.write(key: 'llm_custom_baseurl', value: v.trim());

  static Future<String?> modelOverride(String providerId) =>
      _storage.read(key: 'llm_model_$providerId');
  static Future<void> setModelOverride(String providerId, String v) =>
      _storage.write(key: 'llm_model_$providerId', value: v.trim());
}
