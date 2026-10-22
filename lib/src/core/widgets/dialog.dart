import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Bestätigung vor Unumkehrbarem (UI-04). [ja] sagt, was passiert, z. B.
/// „Entfernen“; destruktive Aktionen stehen in `negative`. Liefert `true`
/// nur bei Ja.
Future<bool> bestaetigen(
  BuildContext context, {
  required String titel,
  required String text,
  required String ja,
  bool destruktiv = true,
}) async {
  final stil = Theme.of(context).extension<BwTextStyles>()!;
  final antwort = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: BwColors.surfaceFloat,
      title: Text(titel, style: stil.name),
      content: Text(text, style: stil.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('ABBRECHEN'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(
            ja.toUpperCase(),
            style: stil.button.copyWith(
              color: destruktiv ? BwColors.negative : BwColors.gradEnd,
            ),
          ),
        ),
      ],
    ),
  );
  return antwort ?? false;
}
