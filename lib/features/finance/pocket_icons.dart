import 'package:flutter/material.dart';

/// Icône d'une poche d'épargne d'après son nom stocké.
IconData pocketIcon(String name) {
  switch (name) {
    case 'flight':
      return Icons.flight;
    case 'school':
      return Icons.school;
    case 'directions_car':
      return Icons.directions_car;
    case 'forest':
      return Icons.forest;
    case 'shield':
      return Icons.shield;
    case 'celebration':
      return Icons.celebration;
    case 'home':
      return Icons.home;
    case 'favorite':
      return Icons.favorite;
    case 'savings':
    default:
      return Icons.savings;
  }
}

/// Liste d'icônes proposées à la création d'une poche.
const pocketIconChoices = <String>[
  'savings',
  'flight',
  'school',
  'directions_car',
  'forest',
  'shield',
  'celebration',
  'home',
  'favorite',
];
