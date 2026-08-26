import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assistant/llm/llm_settings.dart';
import '../assistant/weekly_report.dart';
import 'security_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _weeklyReport = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final weekly = await WeeklyReport.isEnabled();
    setState(() {
      _weeklyReport = weekly;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const LlmSettingsSection(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.insights_outlined),
                  title: const Text('Bilan hebdomadaire'),
                  subtitle: const Text(
                      'Notification le dimanche soir pour faire le point'),
                  value: _weeklyReport,
                  onChanged: (v) async {
                    await WeeklyReport.setEnabled(v);
                    setState(() => _weeklyReport = v);
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const BackupSection(),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                const LockSection(),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Données chiffrées'),
                  subtitle: const Text(
                    'Ta base de données est chiffrée (SQLCipher) et reste '
                    'sur ton téléphone.',
                  ),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline),
                  title: Text('MyLife'),
                  subtitle: Text('Version 1.0.0 — suivi de vie au quotidien'),
                ),
              ],
            ),
    );
  }
}
