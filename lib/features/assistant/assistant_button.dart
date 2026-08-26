import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// Bouton d'accès rapide à l'assistant, à placer dans l'AppBar de tout écran.
class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Assistant',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/assistant'),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: AppGradients.assistant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
