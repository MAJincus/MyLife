import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/format.dart';
import 'health_repository.dart';

/// Construit le PDF de synthèse santé sur la période [start]..[end].
Future<Uint8List> buildHealthReportPdf({
  required HealthRepository repo,
  required DateTime start,
  required DateTime end,
}) async {
  final sleep = await repo.sleepBetween(start, end);
  final pain = await repo.painBetween(start, end);
  final meds = await repo.allMedications();
  final logs = await repo.medLogsBetween(start, end);

  final doc = pw.Document();
  final period =
      'du ${Fmt.dayMonth(start)} au ${Fmt.dayMonth(end)} ${end.year}';

  // Agrégats sommeil
  final avgSleep = sleep.isEmpty
      ? 0
      : sleep.fold<int>(0, (s, e) => s + e.durationMinutes) ~/ sleep.length;
  final avgQuality = sleep.isEmpty
      ? 0.0
      : sleep.fold<int>(0, (s, e) => s + e.quality) / sleep.length;

  // Agrégats douleurs
  final avgPain = pain.isEmpty
      ? 0.0
      : pain.fold<int>(0, (s, e) => s + e.intensity) / pain.length;

  // Prises par médicament
  final intakeByMed = <int, int>{};
  for (final l in logs) {
    intakeByMed[l.medicationId] = (intakeByMed[l.medicationId] ?? 0) + 1;
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Rapport de santé',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text('MyLife - synthèse $period',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // ---- Sommeil ----
        _section('Sommeil'),
        pw.Text(
          sleep.isEmpty
              ? 'Aucune donnée de sommeil sur la période.'
              : 'Moyenne : ${Fmt.duration(avgSleep)} par nuit · '
                  'qualité moyenne ${avgQuality.toStringAsFixed(1)}/5 · '
                  '${sleep.length} nuit(s).',
        ),
        if (sleep.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _table(
            ['Date', 'Coucher', 'Réveil', 'Durée', 'Qualité'],
            [
              for (final s in sleep)
                [
                  Fmt.dayMonth(s.date),
                  Fmt.time(s.bedTime),
                  Fmt.time(s.wakeTime),
                  Fmt.duration(s.durationMinutes),
                  '${s.quality}/5',
                ],
            ],
          ),
        ],
        pw.SizedBox(height: 16),

        // ---- Douleurs ----
        _section('Douleurs'),
        pw.Text(
          pain.isEmpty
              ? 'Aucune douleur notée sur la période.'
              : '${pain.length} épisode(s) · intensité moyenne '
                  '${avgPain.toStringAsFixed(1)}/10.',
        ),
        if (pain.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _table(
            ['Date', 'Heure', 'Localisation', 'Intensité', 'Note'],
            [
              for (final p in pain)
                [
                  Fmt.dayMonth(p.at),
                  Fmt.time(p.at),
                  p.location.isEmpty ? '-' : p.location,
                  '${p.intensity}/10',
                  p.note,
                ],
            ],
          ),
        ],
        pw.SizedBox(height: 16),

        // ---- Médicaments ----
        _section('Médicaments'),
        if (meds.isEmpty)
          pw.Text('Aucun médicament enregistré.')
        else
          _table(
            ['Médicament', 'Dosage', 'Horaires', 'Prises (période)'],
            [
              for (final m in meds)
                [
                  m.name,
                  m.dosage.isEmpty ? '-' : m.dosage,
                  m.scheduleTimes.isEmpty ? '-' : m.scheduleTimes,
                  '${intakeByMed[m.id] ?? 0}',
                ],
            ],
          ),
      ],
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Généré par MyLife · page ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
    ),
  );

  return doc.save();
}

pw.Widget _section(String title) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800)),
    );

pw.Widget _table(List<String> headers, List<List<String>> rows) {
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    cellStyle: const pw.TextStyle(fontSize: 9),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
    cellAlignment: pw.Alignment.centerLeft,
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
  );
}

/// Propose une période puis génère et partage le PDF.
Future<void> showExportHealthPdf(BuildContext context, WidgetRef ref) async {
  final days = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Période du rapport'),
      children: [
        for (final d in const [7, 30, 90])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, d),
            child: Text('$d derniers jours'),
          ),
      ],
    ),
  );
  if (days == null) return;

  final end = DateTime.now();
  final start = DateTime(end.year, end.month, end.day)
      .subtract(Duration(days: days - 1));
  final repo = ref.read(healthRepositoryProvider);

  try {
    final bytes =
        await buildHealthReportPdf(repo: repo, start: start, end: end);
    await Printing.sharePdf(
        bytes: bytes,
        filename: 'sante-mylife-${end.year}-${end.month}-${end.day}.pdf');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Échec de l\'export : $e')));
    }
  }
}
