import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../agenda/agenda_repository.dart';
import '../diet/diet_repository.dart';
import '../finance/finance_repository.dart';
import '../health/health_repository.dart';

/// Outils exposés à Claude pour agir dans l'app (tool use).
const assistantTools = <Map<String, dynamic>>[
  {
    'name': 'add_transaction',
    'description':
        'Enregistre une dépense ou un revenu dans le suivi financier.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'amount': {'type': 'number', 'description': 'Montant en euros, positif.'},
        'kind': {
          'type': 'string',
          'enum': ['expense', 'income'],
          'description': 'Dépense ou revenu.'
        },
        'category': {
          'type': 'string',
          'description': 'Nom de catégorie (ex. Alimentation), optionnel.'
        },
        'note': {'type': 'string', 'description': 'Note libre, optionnelle.'},
      },
      'required': ['amount', 'kind'],
    },
  },
  {
    'name': 'add_reminder',
    'description': 'Crée un rappel dans l\'agenda avec notification.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'datetime': {
          'type': 'string',
          'description': 'Date-heure ISO 8601 (ex. 2026-08-26T09:00).'
        },
        'note': {'type': 'string'},
        'repeat': {
          'type': 'string',
          'enum': ['none', 'daily', 'weekly', 'monthly'],
        },
      },
      'required': ['title', 'datetime'],
    },
  },
  {
    'name': 'log_meal',
    'description': 'Ajoute un aliment/repas au journal alimentaire du jour.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'label': {'type': 'string'},
        'kcal': {'type': 'number'},
        'meal_type': {
          'type': 'string',
          'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
        },
        'protein': {'type': 'number'},
        'carbs': {'type': 'number'},
        'fat': {'type': 'number'},
      },
      'required': ['label', 'kcal'],
    },
  },
  {
    'name': 'add_weight',
    'description': 'Enregistre une mesure de poids (kg).',
    'input_schema': {
      'type': 'object',
      'properties': {
        'weight_kg': {'type': 'number'},
      },
      'required': ['weight_kg'],
    },
  },
  {
    'name': 'log_medication',
    'description': 'Enregistre la prise d\'un médicament existant, par son nom.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
      },
      'required': ['name'],
    },
  },
  {
    'name': 'log_sleep',
    'description': 'Enregistre une nuit de sommeil (heures de coucher/réveil).',
    'input_schema': {
      'type': 'object',
      'properties': {
        'bedtime': {'type': 'string', 'description': 'Heure de coucher HH:mm.'},
        'waketime': {'type': 'string', 'description': 'Heure de réveil HH:mm.'},
        'quality': {
          'type': 'integer',
          'description': 'Qualité ressentie 1 à 5.'
        },
        'note': {'type': 'string'},
      },
      'required': ['bedtime', 'waketime'],
    },
  },
  {
    'name': 'log_pain',
    'description': 'Enregistre une douleur (localisation + intensité 0-10).',
    'input_schema': {
      'type': 'object',
      'properties': {
        'location': {'type': 'string'},
        'intensity': {'type': 'integer', 'description': '0 à 10.'},
        'note': {'type': 'string'},
      },
      'required': ['intensity'],
    },
  },
];

/// Exécute un outil demandé par Claude et renvoie un message de résultat.
Future<String> executeTool(
    ProviderContainer container, String name, Map<String, dynamic> input) async {
  try {
    switch (name) {
      case 'add_transaction':
        return _addTransaction(container, input);
      case 'add_reminder':
        return _addReminder(container, input);
      case 'log_meal':
        return _logMeal(container, input);
      case 'add_weight':
        return _addWeight(container, input);
      case 'log_medication':
        return _logMedication(container, input);
      case 'log_sleep':
        return _logSleep(container, input);
      case 'log_pain':
        return _logPain(container, input);
      default:
        return 'Outil inconnu : $name';
    }
  } catch (e) {
    return 'Erreur lors de l\'exécution de $name : $e';
  }
}

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

Future<String> _addTransaction(
    ProviderContainer container, Map<String, dynamic> input) async {
  final repo = container.read(financeRepositoryProvider);
  final amount = _toDouble(input['amount']);
  final kind = (input['kind'] ?? 'expense').toString();
  int? categoryId;
  final catName = input['category']?.toString();
  if (catName != null && catName.isNotEmpty) {
    final cats = await repo.watchCategories().first;
    final match = cats.where(
        (c) => c.name.toLowerCase() == catName.toLowerCase());
    if (match.isNotEmpty) categoryId = match.first.id;
  }
  await repo.addTransaction(TransactionsCompanion.insert(
    amount: amount,
    kind: Value(kind),
    categoryId: Value(categoryId),
    date: DateTime.now(),
    note: Value(input['note']?.toString() ?? ''),
  ));
  final label = kind == 'income' ? 'Revenu' : 'Dépense';
  return '$label de ${amount.toStringAsFixed(2)} € enregistré'
      '${catName != null ? ' (catégorie : $catName)' : ''}.';
}

Future<String> _addReminder(ProviderContainer container, Map<String, dynamic> input) async {
  final repo = container.read(agendaRepositoryProvider);
  DateTime due;
  try {
    due = DateTime.parse(input['datetime'].toString());
  } catch (_) {
    due = DateTime.now().add(const Duration(hours: 1));
  }
  await repo.addReminder(
    title: input['title'].toString(),
    note: input['note']?.toString() ?? '',
    dueAt: due,
    repeatRule: (input['repeat'] ?? 'none').toString(),
  );
  return 'Rappel « ${input['title']} » créé pour le '
      '${due.day}/${due.month} à '
      '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}.';
}

Future<String> _logMeal(ProviderContainer container, Map<String, dynamic> input) async {
  final repo = container.read(dietRepositoryProvider);
  final kcal = _toDouble(input['kcal']);
  await repo.addMeal(
    at: DateTime.now(),
    mealType: (input['meal_type'] ?? 'snack').toString(),
    label: input['label'].toString(),
    quantityGrams: 0,
    kcal: kcal,
    protein: _toDouble(input['protein']),
    carbs: _toDouble(input['carbs']),
    fat: _toDouble(input['fat']),
  );
  return '${input['label']} (${kcal.round()} kcal) ajouté au journal.';
}

Future<String> _addWeight(ProviderContainer container, Map<String, dynamic> input) async {
  final repo = container.read(dietRepositoryProvider);
  final kg = _toDouble(input['weight_kg']);
  await repo.addWeight(kg);
  return 'Poids enregistré : ${kg.toStringAsFixed(1)} kg.';
}

Future<String> _logMedication(
    ProviderContainer container, Map<String, dynamic> input) async {
  final repo = container.read(healthRepositoryProvider);
  final name = input['name'].toString();
  final meds = await repo.watchMedications().first;
  final match =
      meds.where((m) => m.name.toLowerCase() == name.toLowerCase());
  if (match.isEmpty) {
    return 'Aucun médicament nommé « $name ». Ajoute-le d\'abord dans Santé.';
  }
  await repo.logIntake(match.first.id);
  return 'Prise de « ${match.first.name} » enregistrée.';
}

DateTime _todayAt(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, h, m);
}

Future<String> _logSleep(
    ProviderContainer container, Map<String, dynamic> input) async {
  final repo = container.read(healthRepositoryProvider);
  var bed = _todayAt(input['bedtime'].toString());
  final wake = _todayAt(input['waketime'].toString());
  // Coucher la veille si postérieur au réveil.
  if (bed.isAfter(wake)) bed = bed.subtract(const Duration(days: 1));
  final quality = (input['quality'] as num?)?.toInt() ?? 3;
  await repo.addSleep(
    bedTime: bed,
    wakeTime: wake,
    quality: quality.clamp(1, 5),
    note: input['note']?.toString() ?? '',
  );
  final mins = wake.difference(bed).inMinutes;
  return 'Nuit enregistrée : ${mins ~/ 60}h${(mins % 60).toString().padLeft(2, '0')}.';
}

Future<String> _logPain(
    ProviderContainer container, Map<String, dynamic> input) async {
  final repo = container.read(healthRepositoryProvider);
  final intensity = ((input['intensity'] as num?)?.toInt() ?? 0).clamp(0, 10);
  await repo.addPain(
    at: DateTime.now(),
    location: input['location']?.toString() ?? '',
    intensity: intensity,
    note: input['note']?.toString() ?? '',
  );
  return 'Douleur enregistrée ($intensity/10'
      '${input['location'] != null ? ', ${input['location']}' : ''}).';
}
