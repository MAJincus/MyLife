import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/section_header.dart';
import 'providers.dart';

/// Section Réglages : choix du fournisseur LLM + clé + options.
class LlmSettingsSection extends StatefulWidget {
  const LlmSettingsSection({super.key});

  @override
  State<LlmSettingsSection> createState() => _LlmSettingsSectionState();
}

class _LlmSettingsSectionState extends State<LlmSettingsSection> {
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _baseUrl = TextEditingController();
  bool _obscure = true;
  bool _loading = true;
  String _providerId = 'gemini';

  LlmProvider get _provider => providerById(_providerId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await LlmConfigStore.selectedProviderId();
    await _loadProvider(id);
    setState(() => _loading = false);
  }

  Future<void> _loadProvider(String id) async {
    _providerId = id;
    _key.text = await LlmConfigStore.keyFor(id) ?? '';
    _model.text = await LlmConfigStore.modelOverride(id) ?? '';
    if (id == 'custom') {
      _baseUrl.text = await LlmConfigStore.customBaseUrl() ?? '';
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _selectProvider(String id) async {
    await LlmConfigStore.setProvider(id);
    await _loadProvider(id);
    setState(() {});
  }

  Future<void> _save() async {
    await LlmConfigStore.setProvider(_providerId);
    if (_key.text.trim().isNotEmpty) {
      await LlmConfigStore.setKey(_providerId, _key.text);
    }
    if (_model.text.trim().isNotEmpty) {
      await LlmConfigStore.setModelOverride(_providerId, _model.text);
    }
    if (_providerId == 'custom') {
      await LlmConfigStore.setCustomBaseUrl(_baseUrl.text);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_provider.name} configuré.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final p = _provider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(icon: Icons.smart_toy_outlined, title: 'Assistant IA'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _providerId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Fournisseur',
            prefixIcon: Icon(Icons.hub_outlined),
          ),
          items: [
            for (final prov in kProviders)
              DropdownMenuItem(
                value: prov.id,
                child: Row(
                  children: [
                    Text(prov.name),
                    if (prov.free) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('gratuit',
                            style: TextStyle(
                                fontSize: 11, color: Colors.green)),
                      ),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) _selectProvider(v);
          },
        ),
        const SizedBox(height: 8),
        if (p.getKeyUrl.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Text('Obtenir une clé : ${p.getKeyUrl}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copier le lien',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: p.getKeyUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lien copié')),
                  );
                },
              ),
            ],
          ),
        if (_providerId == 'custom') ...[
          const SizedBox(height: 4),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Point de terminaison (base OpenAI)',
              hintText: 'https://…/v1',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _key,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: p.keyLabel,
            hintText: p.keyHint,
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _model,
          decoration: InputDecoration(
            labelText: 'Modèle (optionnel)',
            hintText: p.defaultModel.isEmpty
                ? 'ex. gpt-4o-mini'
                : 'défaut : ${p.defaultModel}',
            prefixIcon: const Icon(Icons.memory),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
          ),
        ),
      ],
    );
  }
}
