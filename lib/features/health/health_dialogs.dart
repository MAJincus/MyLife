import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import 'health_repository.dart';

/// Icône illustrant une zone de douleur courante.
IconData _spotIcon(String spot) => switch (spot) {
      'Tête' => Icons.psychology_alt,
      'Dos' => Icons.airline_seat_recline_normal,
      'Nuque' => Icons.accessibility_new,
      'Ventre' => Icons.sick,
      'Jambes' => Icons.airline_seat_legroom_extra,
      'Articulations' => Icons.accessibility,
      _ => Icons.place_outlined,
    };

Future<void> _sheet(BuildContext context, Widget child) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: child,
    ),
  );
}

// ---------------------- SOMMEIL ----------------------

Future<void> showAddSleepSheet(BuildContext context, WidgetRef ref,
        {SleepEntry? entry}) =>
    _sheet(context, _AddSleepForm(ref: ref, entry: entry));

class _AddSleepForm extends StatefulWidget {
  const _AddSleepForm({required this.ref, this.entry});
  final WidgetRef ref;
  final SleepEntry? entry;
  @override
  State<_AddSleepForm> createState() => _AddSleepFormState();
}

class _AddSleepFormState extends State<_AddSleepForm> {
  late TimeOfDay _bed;
  late TimeOfDay _wake;
  late int _quality;
  late final _note = TextEditingController(text: widget.entry?.note ?? '');

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _bed = e != null
        ? TimeOfDay.fromDateTime(e.bedTime)
        : const TimeOfDay(hour: 23, minute: 0);
    _wake = e != null
        ? TimeOfDay.fromDateTime(e.wakeTime)
        : const TimeOfDay(hour: 7, minute: 0);
    _quality = e?.quality ?? 3;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Référence de nuit : date d'origine si édition, sinon aujourd'hui.
    final base = widget.entry?.wakeTime ?? DateTime.now();
    var bed = DateTime(base.year, base.month, base.day, _bed.hour, _bed.minute);
    final wake =
        DateTime(base.year, base.month, base.day, _wake.hour, _wake.minute);
    if (bed.isAfter(wake)) bed = bed.subtract(const Duration(days: 1));
    final repo = widget.ref.read(healthRepositoryProvider);
    if (_editing) {
      await repo.updateSleep(widget.entry!.id,
          bedTime: bed,
          wakeTime: wake,
          quality: _quality,
          note: _note.text.trim());
    } else {
      await repo.addSleep(
          bedTime: bed,
          wakeTime: wake,
          quality: _quality,
          note: _note.text.trim());
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await widget.ref.read(healthRepositoryProvider).deleteSleep(widget.entry!.id);
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
          Row(
            children: [
              Text(_editing ? 'Modifier la nuit' : 'Nuit de sommeil',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (_editing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Supprimer',
                  onPressed: _delete,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _TimeRow(
            label: 'Coucher',
            time: _bed,
            onPick: (t) => setState(() => _bed = t),
          ),
          _TimeRow(
            label: 'Réveil',
            time: _wake,
            onPick: (t) => setState(() => _wake = t),
          ),
          const SizedBox(height: 8),
          Text('Qualité : ${'★' * _quality}${'☆' * (5 - _quality)}'),
          Slider(
            value: _quality.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_quality',
            onChanged: (v) => setState(() => _quality = v.round()),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optionnel)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _submit, child: const Text('Enregistrer')),
          ),
        ],
      ),
    );
  }
}

// ---------------------- DOULEUR ----------------------

Future<void> showAddPainSheet(BuildContext context, WidgetRef ref,
        {PainEntry? entry}) =>
    _sheet(context, _AddPainForm(ref: ref, entry: entry));

class _AddPainForm extends StatefulWidget {
  const _AddPainForm({required this.ref, this.entry});
  final WidgetRef ref;
  final PainEntry? entry;
  @override
  State<_AddPainForm> createState() => _AddPainFormState();
}

class _AddPainFormState extends State<_AddPainForm> {
  late final _location =
      TextEditingController(text: widget.entry?.location ?? '');
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  late int _intensity = widget.entry?.intensity ?? 5;

  bool get _editing => widget.entry != null;

  static const _commonSpots = [
    'Tête', 'Dos', 'Nuque', 'Ventre', 'Jambes', 'Articulations'
  ];

  @override
  void dispose() {
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = widget.ref.read(healthRepositoryProvider);
    if (_editing) {
      await repo.updatePain(widget.entry!.id,
          location: _location.text.trim(),
          intensity: _intensity,
          note: _note.text.trim());
    } else {
      await repo.addPain(
          at: DateTime.now(),
          location: _location.text.trim(),
          intensity: _intensity,
          note: _note.text.trim());
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await widget.ref.read(healthRepositoryProvider).deletePain(widget.entry!.id);
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
          Row(
            children: [
              Text(_editing ? 'Modifier la douleur' : 'Douleur',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (_editing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Supprimer',
                  onPressed: _delete,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Localisation',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final s in _commonSpots)
                ActionChip(
                  avatar: Icon(_spotIcon(s), size: 18),
                  label: Text(s),
                  onPressed: () => setState(() => _location.text = s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Intensité : $_intensity / 10'),
          Slider(
            value: _intensity.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '$_intensity',
            onChanged: (v) => setState(() => _intensity = v.round()),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optionnel)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _submit, child: const Text('Enregistrer')),
          ),
        ],
      ),
    );
  }
}

// ---------------------- MÉDICAMENT ----------------------

Future<void> showAddMedicationSheet(BuildContext context, WidgetRef ref) =>
    _sheet(context, _AddMedForm(ref: ref));

class _AddMedForm extends StatefulWidget {
  const _AddMedForm({required this.ref});
  final WidgetRef ref;
  @override
  State<_AddMedForm> createState() => _AddMedFormState();
}

class _AddMedFormState extends State<_AddMedForm> {
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  final _times = <TimeOfDay>[const TimeOfDay(hour: 8, minute: 0)];
  bool _reminders = true;

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    await widget.ref.read(healthRepositoryProvider).addMedication(
          name: _name.text.trim(),
          dosage: _dosage.text.trim(),
          times: _times.map(_fmt).toList()..sort(),
          remindersOn: _reminders,
        );
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
          Text('Médicament', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.medication),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dosage,
            decoration: const InputDecoration(
              labelText: 'Dosage (ex. 1 comprimé, 500 mg)',
              prefixIcon: Icon(Icons.straighten),
            ),
          ),
          const SizedBox(height: 16),
          Text('Heures de prise',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _times.length; i++)
                InputChip(
                  label: Text(_fmt(_times[i])),
                  onDeleted: _times.length > 1
                      ? () => setState(() => _times.removeAt(i))
                      : null,
                  onPressed: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: _times[i]);
                    if (picked != null) setState(() => _times[i] = picked);
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                onPressed: () async {
                  final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 20, minute: 0));
                  if (picked != null) setState(() => _times.add(picked));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rappels de prise'),
            subtitle: const Text('Notification aux heures indiquées'),
            value: _reminders,
            onChanged: (v) => setState(() => _reminders = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _submit, child: const Text('Enregistrer')),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow(
      {required this.label, required this.time, required this.onPick});
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(label),
      trailing: Text(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPick(picked);
      },
    );
  }
}
