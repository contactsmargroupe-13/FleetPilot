import 'package:flutter/material.dart';
import 'design_constants.dart';

/// Affiche un dialog d'aide pour expliquer une page
void showPageHelp(BuildContext context, String title, String description) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.help_outline_rounded, color: DC.primary, size: 22),
          const SizedBox(width: 10),
          Text(title, style: DC.title(18)),
        ],
      ),
      content: Text(
        description,
        style: DC.body(14, color: DC.textSecondary),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Compris'),
        ),
      ],
    ),
  );
}

/// Bouton ? pour l'AppBar
Widget helpButton(BuildContext context, String title, String description) {
  return IconButton(
    icon: const Icon(Icons.help_outline_rounded, size: 20),
    tooltip: title,
    onPressed: () => showPageHelp(context, title, description),
  );
}
