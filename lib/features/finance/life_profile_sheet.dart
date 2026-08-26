import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import 'finance_repository.dart';

/// Feuille d'édition du « profil de vie » (contexte pour l'analyse IA).
Future<void> showLifeProfileSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _LifeProfileForm(ref: ref),
    ),
  );
}

class _LifeProfileForm extends StatefulWidget {
  const _LifeProfileForm({required this.ref});
  final WidgetRef ref;
  @override
  State<_LifeProfileForm> createState() => _LifeProfileFormState();
}

class _LifeProfileFormState extends State<_LifeProfileForm> {
  final _adults = TextEditingController();
  final _children = TextEditingController();
  final _surface = TextEditingController();
  final _vehicles = TextEditingController();
  final _notes = TextEditingController();
  String _housingType = '';
  String _housingStatus = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await widget.ref.read(financeRepositoryProvider).watchProfile().first;
    setState(() {
      if (p.adultsCount != null) _adults.text = '${p.adultsCount}';
      if (p.childrenCount != null) _children.text = '${p.childrenCount}';
      if (p.housingSurfaceM2 != null) _surface.text = '${p.housingSurfaceM2}';
      if (p.vehiclesCount != null) _vehicles.text = '${p.vehiclesCount}';
      _notes.text = p.lifeContext;
      _housingType = p.housingType;
      _housingStatus = p.housingStatus;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_adults, _children, _surface, _vehicles, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.ref.read(financeRepositoryProvider).updateProfile(
          ProfileCompanion(
            adultsCount: Value(int.tryParse(_adults.text)),
            childrenCount: Value(int.tryParse(_children.text)),
            housingType: Value(_housingType),
            housingStatus: Value(_housingStatus),
            housingSurfaceM2: Value(int.tryParse(_surface.text)),
            vehiclesCount: Value(int.tryParse(_vehicles.text)),
            lifeContext: Value(_notes.text.trim()),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mon profil de vie',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Aide l\'IA à comparer tes dépenses à un foyer comme le tien. '
              'Rien n\'est envoyé sans ta demande.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _adults,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Adultes', prefixIcon: Icon(Icons.person)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _children,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Enfants',
                        prefixIcon: Icon(Icons.child_care)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Logement', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'apartment', label: Text('Appart')),
                ButtonSegment(value: 'house', label: Text('Maison')),
              ],
              selected: {_housingType.isEmpty ? 'apartment' : _housingType},
              onSelectionChanged: (s) => setState(() => _housingType = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'owner', label: Text('Propriétaire')),
                ButtonSegment(value: 'renter', label: Text('Locataire')),
              ],
              selected: {_housingStatus.isEmpty ? 'renter' : _housingStatus},
              onSelectionChanged: (s) => setState(() => _housingStatus = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _surface,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Surface (m²)',
                        prefixIcon: Icon(Icons.square_foot)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _vehicles,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Véhicules',
                        prefixIcon: Icon(Icons.directions_car)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Contexte libre',
                hintText: 'Ville, chauffage, animaux, situation pro…',
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
      ),
    );
  }
}
