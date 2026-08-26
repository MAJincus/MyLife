import 'package:flutter/material.dart';

/// Icône selon le moment du repas.
IconData mealTypeIcon(String type) => switch (type) {
      'breakfast' => Icons.bakery_dining,
      'lunch' => Icons.lunch_dining,
      'dinner' => Icons.dinner_dining,
      _ => Icons.cookie,
    };

/// Couleur d'accent par moment du repas.
Color mealTypeColor(String type) => switch (type) {
      'breakfast' => const Color(0xFFF6A821),
      'lunch' => const Color(0xFFEF6C00),
      'dinner' => const Color(0xFF6A4CFF),
      _ => const Color(0xFF00897B),
    };

/// Icône selon le type d'activité physique (libellés FR).
IconData activityIcon(String type) {
  final t = type.toLowerCase();
  if (t.contains('marche')) return Icons.directions_walk;
  if (t.contains('course') || t.contains('run')) return Icons.directions_run;
  if (t.contains('vélo') || t.contains('velo')) return Icons.directions_bike;
  if (t.contains('muscu')) return Icons.fitness_center;
  if (t.contains('natation') || t.contains('nage')) return Icons.pool;
  return Icons.sports_gymnastics;
}
