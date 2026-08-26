import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mylife/data/database.dart';
import 'package:mylife/features/health/health_pdf.dart';
import 'package:mylife/features/health/health_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR', null));

  test('le rapport PDF santé se génère avec des données', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HealthRepository(db);

    await repo.addSleep(
      bedTime: DateTime(2026, 8, 23, 23, 0),
      wakeTime: DateTime(2026, 8, 24, 7, 0),
      quality: 4,
    );
    await repo.addPain(
        at: DateTime(2026, 8, 24, 14, 0), location: 'Dos', intensity: 6);
    await repo.addMedication(
        name: 'Doliprane', dosage: '1g', times: ['08:00'], remindersOn: false);

    final bytes = await buildHealthReportPdf(
      repo: repo,
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );

    expect(bytes.length, greaterThan(1000));
    // Entête de fichier PDF : "%PDF".
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    await db.close();
  });
}
