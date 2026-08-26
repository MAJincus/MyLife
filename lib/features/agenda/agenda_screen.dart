import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/database.dart';
import 'agenda_dialogs.dart';
import 'agenda_repository.dart';
import 'calendar_service.dart';
import 'calendar_settings_screen.dart';

class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(agendaRepositoryProvider);
    final externalAsync = ref.watch(externalEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_available_outlined),
            tooltip: 'Agendas connectés',
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(
                    builder: (_) => const CalendarSettingsScreen(),
                  ))
                  .then((_) => ref.invalidate(externalEventsProvider));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddReminderSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Rappel'),
      ),
      body: StreamBuilder<List<Reminder>>(
        stream: repo.watchUpcoming(),
        builder: (context, snap) {
          final upcoming = snap.data ?? const [];
          final external = externalAsync.valueOrNull ?? const [];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(externalEventsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (externalAsync.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (upcoming.isEmpty && external.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucun rappel à venir.\nAjoute-en un avec « + », ou '
                        'connecte tes agendas Google/Outlook (icône en haut).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                  )
                else
                  ..._buildGroups(context, repo, upcoming, external),
                const SizedBox(height: 16),
                _DoneSection(repo: repo),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    AgendaRepository repo,
    List<Reminder> reminders,
    List<CalEvent> events,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final entries = <_Entry>[
      for (final r in reminders) _Entry(r.dueAt, reminder: r),
      for (final e in events)
        if (!DateTime(e.start.year, e.start.month, e.start.day)
            .isBefore(today))
          _Entry(e.start, event: e),
    ]..sort((a, b) => a.when.compareTo(b.when));

    String labelFor(_Entry e) {
      final day = DateTime(e.when.year, e.when.month, e.when.day);
      final diff = day.difference(today).inDays;
      if (e.reminder != null && e.when.isBefore(now) && diff <= 0) {
        return 'En retard';
      }
      if (diff == 0) return 'Aujourd\'hui';
      if (diff == 1) return 'Demain';
      return Fmt.fullDate(e.when);
    }

    final widgets = <Widget>[];
    String? currentLabel;
    for (final e in entries) {
      final label = labelFor(e);
      if (label != currentLabel) {
        currentLabel = label;
        final overdue = label == 'En retard';
        final headColor = overdue
            ? Theme.of(context).colorScheme.error
            : const Color(0xFF3B82F6);
        final headIcon = overdue
            ? Icons.error_outline
            : label == 'Aujourd\'hui'
                ? Icons.today
                : label == 'Demain'
                    ? Icons.upcoming
                    : Icons.calendar_month;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Icon(headIcon, size: 16, color: headColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: overdue ? headColor : null,
                    ),
              ),
            ],
          ),
        ));
      }
      widgets.add(e.reminder != null
          ? _ReminderTile(reminder: e.reminder!, repo: repo)
          : _EventTile(event: e.event!));
    }
    return widgets;
  }
}

class _Entry {
  _Entry(this.when, {this.reminder, this.event});
  final DateTime when;
  final Reminder? reminder;
  final CalEvent? event;
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, required this.repo});
  final Reminder reminder;
  final AgendaRepository repo;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    return Dismissible(
      key: ValueKey('rem_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => repo.deleteReminder(r),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ListTile(
          leading: Checkbox(
            value: r.done,
            onChanged: (v) => repo.setDone(r, v ?? false),
          ),
          title: Text(r.title),
          subtitle: Text(_subtitle(r)),
          trailing: r.repeatRule == 'none'
              ? null
              : Icon(Icons.repeat,
                  size: 18, color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }

  String _subtitle(Reminder r) {
    final time = '${Fmt.dayMonth(r.dueAt)} · ${Fmt.time(r.dueAt)}';
    final rep = switch (r.repeatRule) {
      'daily' => ' · tous les jours',
      'weekly' => ' · chaque semaine',
      'monthly' => ' · chaque mois',
      _ => '',
    };
    final note = r.note.isEmpty ? '' : '\n${r.note}';
    return '$time$rep$note';
  }
}

/// Événement lu depuis un agenda Google/Outlook (lecture seule).
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final CalEvent event;

  @override
  Widget build(BuildContext context) {
    final color =
        event.color != null ? Color(event.color!) : Theme.of(context).colorScheme.primary;
    final time = event.allDay
        ? 'Journée'
        : '${Fmt.time(event.start)}–${Fmt.time(event.end)}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Container(
          width: 6,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        title: Text(event.title),
        subtitle: Text('$time · ${event.calendarName}'),
        trailing: Icon(Icons.event, size: 18, color: color),
      ),
    );
  }
}

class _DoneSection extends StatelessWidget {
  const _DoneSection({required this.repo});
  final AgendaRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reminder>>(
      stream: repo.watchDone(),
      builder: (context, snap) {
        final done = snap.data ?? const [];
        if (done.isEmpty) return const SizedBox.shrink();
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Terminés (${done.length})',
                style: Theme.of(context).textTheme.titleSmall),
            children: [
              for (final r in done)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: true,
                    onChanged: (_) => repo.setDone(r, false),
                  ),
                  title: Text(
                    r.title,
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough),
                  ),
                  subtitle:
                      Text('${Fmt.dayMonth(r.dueAt)} · ${Fmt.time(r.dueAt)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => repo.deleteReminder(r),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
