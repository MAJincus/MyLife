import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/security/app_lock.dart';
import '../../core/security/crypto_box.dart';
import '../../core/widgets/section_header.dart';
import '../backup/backup_service.dart';

// ======================= SAUVEGARDE =======================

class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  Future<String?> _askPassphrase(BuildContext context,
      {required String title, bool confirm = false}) async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: p1,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            if (confirm)
              TextField(
                controller: p2,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirmer'),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (p1.text.length < 4) return;
              if (confirm && p1.text != p2.text) return;
              Navigator.pop(ctx, p1.text);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final pass = await _askPassphrase(context,
        title: 'Passphrase de chiffrement', confirm: true);
    if (pass == null) return;
    try {
      final bytes = await ref.read(backupServiceProvider).export(pass);
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/mylife-$stamp.mlb');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Sauvegarde MyLife (chiffrée)');
    } catch (e) {
      if (context.mounted) _snack(context, 'Échec de la sauvegarde : $e');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer une sauvegarde'),
        content: const Text(
            'Toutes les données actuelles seront remplacées par celles de '
            'la sauvegarde. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurer')),
        ],
      ),
    );
    if (confirmed != true) return;

    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.single.path == null) return;
    final bytes = await File(picked.files.single.path!).readAsBytes();

    if (!context.mounted) return;
    final pass =
        await _askPassphrase(context, title: 'Passphrase de la sauvegarde');
    if (pass == null) return;

    try {
      await ref.read(backupServiceProvider).import(bytes, pass);
      if (context.mounted) {
        _snack(context, 'Sauvegarde restaurée. Redémarre l\'app.');
      }
    } on CryptoException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, 'Échec de la restauration : $e');
    }
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(icon: Icons.backup, title: 'Sauvegarde'),
        const SizedBox(height: 4),
        const Text(
          'Exporte toutes tes données dans un fichier chiffré par passphrase. '
          'À conserver dans un endroit sûr (Drive, clé USB…).',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _backup(context, ref),
                icon: const Icon(Icons.backup),
                label: const Text('Sauvegarder'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _restore(context, ref),
                icon: const Icon(Icons.restore),
                label: const Text('Restaurer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ======================= VERROUILLAGE =======================

class LockSection extends StatefulWidget {
  const LockSection({super.key});
  @override
  State<LockSection> createState() => _LockSectionState();
}

class _LockSectionState extends State<LockSection> {
  bool _enabled = false;
  bool _biometric = false;
  bool _canBiometric = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AppLock.isEnabled();
    final bio = await AppLock.biometricEnabled();
    final canBio = await AppLock.canUseBiometrics();
    setState(() {
      _enabled = enabled;
      _biometric = bio;
      _canBiometric = canBio;
      _loading = false;
    });
  }

  Future<String?> _askPin() {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choisir un code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: p1,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Code (4+ chiffres)'),
            ),
            TextField(
              controller: p2,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Confirmer'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (p1.text.length < 4 || p1.text != p2.text) return;
              Navigator.pop(ctx, p1.text);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLock(bool on) async {
    if (on) {
      final pin = await _askPin();
      if (pin == null) return;
      await AppLock.setPin(pin);
      setState(() => _enabled = true);
    } else {
      await AppLock.disable();
      setState(() {
        _enabled = false;
        _biometric = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(icon: Icons.shield_outlined, title: 'Sécurité'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.lock_outline),
          title: const Text('Verrouiller l\'app'),
          subtitle: const Text('Code à l\'ouverture et au réveil'),
          value: _enabled,
          onChanged: _toggleLock,
        ),
        if (_enabled)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Déverrouillage biométrique'),
            subtitle: Text(_canBiometric
                ? 'Empreinte / visage'
                : 'Aucune biométrie configurée sur l\'appareil'),
            value: _biometric,
            onChanged: _canBiometric
                ? (v) async {
                    await AppLock.setBiometricEnabled(v);
                    setState(() => _biometric = v);
                  }
                : null,
          ),
      ],
    );
  }
}
