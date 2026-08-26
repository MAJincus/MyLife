import 'package:flutter/material.dart';

/// Écran provisoire pour les modules en cours de construction.
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.description,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                description ?? 'Module en cours de construction.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
