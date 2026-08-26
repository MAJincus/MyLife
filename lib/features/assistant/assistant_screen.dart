import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'assistant_context.dart';
import 'assistant_tools.dart';
import 'llm/llm.dart';
import 'llm/llm_factory.dart';
import 'voice_service.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _ChatItem {
  _ChatItem(this.role, this.text);
  final String role; // 'user' | 'assistant' | 'tool'
  String text;
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatItem>[]; // affichage
  final _history = <LlmMessage>[]; // conversation unifiée pour le LLM
  final _voice = VoiceService();
  bool _sending = false;
  bool _listening = false;
  bool _voiceReply = false; // lire la réponse à voix haute (déclenché par la voix)

  static const _system =
      'Tu es le coach personnel intégré à MyLife, une app de suivi de vie '
      '(finances, santé, sommeil, douleurs, médicaments, diète, agenda). '
      'Réponds en français, de façon concise, concrète et bienveillante, avec '
      'des conseils actionnables. Les données récentes de l\'utilisateur te '
      'sont fournies plus bas : appuie-toi dessus pour personnaliser tes '
      'réponses. Tu peux AGIR via les outils fournis (ajouter une dépense/'
      'revenu, créer un rappel, logger un repas, un poids, une nuit de '
      'sommeil, une douleur, ou une prise de médicament) : utilise-les dès '
      'que l\'utilisateur le demande, y compris à l\'oral (enregistre toutes '
      'les infos dictées d\'un coup), puis confirme brièvement. '
      'Tu n\'es pas médecin : pour un problème de '
      'santé sérieux, oriente vers un professionnel.';

  static const _suggestions = [
    ('Analyse mon mois financier', '💰'),
    ('Fais le point sur ma semaine', '📊'),
    ('Analyse mon sommeil', '😴'),
    ('Propose-moi un menu pour aujourd\'hui', '🥗'),
    ('Ajoute 12 € de courses', '🛒'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _voice.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _voice.stopListening();
      setState(() => _listening = false);
      return;
    }
    await _voice.stopSpeaking();
    final ok = await _voice.listen(
      onPartial: (t) => setState(() => _controller.text = t),
      onFinal: (t) {
        setState(() {
          _controller.text = t;
          _listening = false;
        });
        if (t.trim().isNotEmpty) _send(viaVoice: true);
      },
    );
    if (ok) {
      setState(() => _listening = true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reconnaissance vocale indisponible sur cet appareil.'),
      ));
    }
  }

  Future<void> _send({String? preset, bool viaVoice = false}) async {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _voiceReply = viaVoice;
    // Capturé avant tout await (le container ne change pas).
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _messages.add(_ChatItem('user', text));
      _history.add(LlmMessage.user(text));
      _controller.clear();
      _sending = true;
    });
    _scrollToEnd();

    try {
      final client = await LlmFactory.current();
      final personal = await buildPersonalContext(ref);
      final system = '$_system\n\n$personal';

      // Boucle d'agent : on rejoue tant que le modèle demande des outils.
      var guard = 0;
      while (guard++ < 6) {
        final res = await client.complete(
          _history,
          system: system,
          tools: assistantTools,
        );
        _history.add(LlmMessage.assistant(res.text, res.toolCalls));

        if (res.text.isNotEmpty) {
          setState(() => _messages.add(_ChatItem('assistant', res.text)));
          if (_voiceReply) _voice.speak(res.text);
          _scrollToEnd();
        }

        if (!res.wantsTools) break;

        for (final tc in res.toolCalls) {
          final result = await executeTool(container, tc.name, tc.args);
          setState(() => _messages.add(_ChatItem('tool', '✅ $result')));
          _history.add(LlmMessage.tool(tc.id, result));
        }
        _scrollToEnd();
      }
    } on LlmException catch (e) {
      setState(() => _messages.add(_ChatItem('assistant', '⚠️ ${e.message}')));
    } finally {
      setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Clé API',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _Bubble(item: _messages[i]),
                  ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text('${s.$2} ${s.$1}'),
                      onPressed: _sending ? null : () => _send(preset: s.$1),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _listening
                            ? 'Parle…'
                            : 'Pose ta question ou demande une action…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _sending ? null : _toggleMic,
                    tooltip: 'Dicter',
                    isSelected: _listening,
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                    color: _listening
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  FloatingActionButton.small(
                    onPressed: _sending ? null : () => _send(),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.item});
  final _ChatItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Message d'action exécutée : bandeau discret centré.
    if (item.role == 'tool') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(item.text,
            style: TextStyle(fontSize: 12, color: scheme.onTertiaryContainer)),
      );
    }

    final isUser = item.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(item.text),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: outline),
            const SizedBox(height: 16),
            Text(
              'Ton coach MyLife',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Je lis tes données (finances, sommeil, diète, rappels) et je '
              'peux agir pour toi : « ajoute 12 € de courses », « rappelle-moi '
              'd\'appeler le médecin demain 9 h », « note 78 kg ». Ajoute '
              'd\'abord ta clé API dans Réglages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: outline),
            ),
          ],
        ),
      ),
    );
  }
}
