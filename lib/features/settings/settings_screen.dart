import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/secure_store.dart';
import '../../core/widgets/section_header.dart';
import '../assistant/weekly_report.dart';
import 'security_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keyController = TextEditingController();
  bool _obscure = true;
  bool _hasKey = false;
  bool _weeklyReport = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await SecureStore.claudeApiKey();
    final weekly = await WeeklyReport.isEnabled();
    setState(() {
      _hasKey = key != null && key.isNotEmpty;
      if (_hasKey) _keyController.text = key!;
      _weeklyReport = weekly;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _keyController.text.trim();
    if (v.isEmpty) return;
    await SecureStore.setClaudeApiKey(v);
    setState(() => _hasKey = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clé API enregistrée en sécurité.')),
      );
    }
  }

  Future<void> _delete() async {
    await SecureStore.clearClaudeApiKey();
    _keyController.clear();
    setState(() => _hasKey = false);
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
                const SectionHeader(
                    icon: Icons.auto_awesome, title: 'Assistant Claude'),
                const SizedBox(height: 8),
                const Text(
                  'Colle ta clé API Anthropic (commence par « sk-ant- »). '
                  'Elle est stockée chiffrée dans le coffre du téléphone et '
                  'n\'est jamais partagée.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Clé API Claude',
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Enregistrer'),
                      ),
                    ),
                    if (_hasKey) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ],
                ),
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
