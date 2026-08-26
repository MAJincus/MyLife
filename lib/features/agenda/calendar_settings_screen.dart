import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_service.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState
    extends ConsumerState<CalendarSettingsScreen> {
  bool _loading = true;
  bool _granted = false;
  List<DeviceCal> _calendars = [];
  Set<String> _selected = {};
  String? _writeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(calendarServiceProvider);
    final granted = await svc.hasPermission();
    if (!granted) {
      setState(() {
        _granted = false;
        _loading = false;
      });
      return;
    }
    final cals = await svc.listCalendars();
    final selected = await svc.selectedCalendarIds();
    final writeId = await svc.writeCalendarId();
    setState(() {
      _granted = true;
      _calendars = cals;
      _selected = selected.toSet();
      _writeId = writeId;
      _loading = false;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _loading = true);
    await ref.read(calendarServiceProvider).requestPermission();
    await _load();
  }

  Future<void> _persist() async {
    final svc = ref.read(calendarServiceProvider);
    await svc.setSelectedCalendarIds(_selected.toList());
    await svc.setWriteCalendarId(_writeId);
    ref.invalidate(externalEventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendas connectés')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_granted
              ? _PermissionPrompt(onGrant: _requestPermission)
              : _calendars.isEmpty
                  ? const _NoCalendars()
                  : _buildList(),
    );
  }

  Widget _buildList() {
    // Groupé par fournisseur (Google / Outlook / …).
    final byProvider = <String, List<DeviceCal>>{};
    for (final c in _calendars) {
      byProvider.putIfAbsent(c.provider, () => []).add(c);
    }
    final writable = _calendars.where((c) => !c.isReadOnly).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Choisis les agendas à afficher dans MyLife.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (final entry in byProvider.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              children: [
                Icon(_providerIcon(entry.key), size: 18),
                const SizedBox(width: 6),
                Text(entry.key,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          for (final c in entry.value)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              secondary: CircleAvatar(
                radius: 10,
                backgroundColor:
                    c.color != null ? Color(c.color!) : Colors.grey,
              ),
              title: Text(c.name),
              subtitle: Text(
                  '${c.account}${c.isReadOnly ? ' · lecture seule' : ''}'),
              value: _selected.contains(c.id),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(c.id);
                  } else {
                    _selected.remove(c.id);
                  }
                });
                _persist();
              },
            ),
        ],
        const Divider(height: 32),
        Text('Ajouter mes rappels MyLife à',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        DropdownButtonFormField<String?>(
          initialValue: writable.any((c) => c.id == _writeId) ? _writeId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.edit_calendar),
          ),
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('Ne pas synchroniser (MyLife seul)')),
            for (final c in writable)
              DropdownMenuItem(
                value: c.id,
                child: Text('${c.provider} · ${c.name}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            setState(() => _writeId = v);
            _persist();
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Quand tu crées un rappel, tu pourras l\'ajouter aussi à cet agenda.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }

  IconData _providerIcon(String provider) => switch (provider) {
        'Google' => Icons.g_mobiledata,
        'Outlook' => Icons.mail_outline,
        'Local' => Icons.phone_android,
        _ => Icons.calendar_month,
      };
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.onGrant});
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Connecter tes agendas',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'MyLife lit les agendas Google et Outlook déjà synchronisés sur '
              'ton téléphone. Autorise l\'accès au calendrier pour les afficher '
              'ici. Rien n\'est envoyé ailleurs.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGrant,
              icon: const Icon(Icons.lock_open),
              label: const Text('Autoriser l\'accès'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCalendars extends StatelessWidget {
  const _NoCalendars();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Aucun agenda trouvé sur cet appareil.\n\n'
          'Ajoute ton compte Google ou Outlook dans Réglages ▸ Comptes du '
          'téléphone, active la synchro du calendrier, puis reviens ici.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}
