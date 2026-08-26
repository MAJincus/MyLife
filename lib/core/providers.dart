import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';

/// La base de données, injectée à la racine via [ProviderScope.overrides].
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider doit être surchargé au démarrage');
});

/// Profil unique (id=1). Se met à jour en temps réel.
final profileProvider = StreamProvider<ProfileData>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.profile)..where((p) => p.id.equals(1))).watchSingle();
});
