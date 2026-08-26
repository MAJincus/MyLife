import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'agenda_repository.dart';
import 'calendar_service.dart';

Future<void> showAddReminderSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AddReminderForm(ref: ref),
    ),
  );
}

class _AddReminderForm extends StatefulWidget {
  const _AddReminderForm({required this.ref});
  final WidgetRef ref;
  @override
  State<_AddReminderForm> createState() => _AddReminderFormState();
}

class _AddReminderFormState extends State<_AddReminderForm> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _time = TimeOfDay(
    hour: (DateTime.now().hour + 1) % 24,
    minute: 0,
  );
  String _repeat = 'none';

  // Push vers un agenda Google/Outlook si une cible d'écriture est définie.
  String? _writeCalId;
  String _writeCalName = '';
  bool _pushToCal = false;

  @override
  void initState() {
    super.initState();
    _loadWriteTarget();
  }

  Future<void> _loadWriteTarget() async {
    final svc = widget.ref.read(calendarServiceProvider);
    final id = await svc.writeCalendarId();
    if (id == null || !await svc.hasPermission()) return;
    final cals = await svc.listCalendars();
    final cal = cals.where((c) => c.id == id).firstOrNull;
    if (cal == null || !mounted) return;
    setState(() {
      _writeCalId = id;
      _writeCalName = '${cal.provider} · ${cal.name}';
      _pushToCal = true;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime get _dueAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) return;
    await widget.ref.read(agendaRepositoryProvider).addReminder(
          title: _title.text.trim(),
          note: _note.text.trim(),
          dueAt: _dueAt,
          repeatRule: _repeat,
        );
    if (_pushToCal && _writeCalId != null) {
      await widget.ref.read(calendarServiceProvider).createEvent(
            calendarId: _writeCalId!,
            title: _title.text.trim(),
            description: _note.text.trim(),
            start: _dueAt,
            end: _dueAt.add(const Duration(hours: 1)),
          );
      widget.ref.invalidate(externalEventsProvider);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouveau rappel',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Titre',
              prefixIcon: Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optionnel)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(Fmt.dayMonth(_date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: _time);
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Répétition', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final r in const [
                ('none', 'Jamais'),
                ('daily', 'Chaque jour'),
                ('weekly', 'Chaque semaine'),
                ('monthly', 'Chaque mois'),
              ])
                ChoiceChip(
                  label: Text(r.$2),
                  selected: _repeat == r.$1,
                  onSelected: (_) => setState(() => _repeat = r.$1),
                ),
            ],
          ),
          if (_writeCalId != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.event_available),
              title: const Text('Ajouter à mon agenda'),
              subtitle: Text(_writeCalName),
              value: _pushToCal,
              onChanged: (v) => setState(() => _pushToCal = v),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _submit, child: const Text('Créer le rappel')),
          ),
        ],
      ),
    );
  }
}
