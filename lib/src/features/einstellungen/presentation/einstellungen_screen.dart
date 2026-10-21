import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/widgets/seite.dart';

/// Einstellungen, erreichbar über das Zahnrad auf jedem Tab (UI-02). Bis zum
/// eigenen Ausbau ein Platzhalter.
class EinstellungenScreen extends StatelessWidget {
  const EinstellungenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BwSeite(
      zurueck: () =>
          context.canPop() ? context.pop() : context.go(Routen.strichliste),
      inhalt: const [
        BwTitel(voll: 'Einstellungen'),
        BwErklaerung(
          'Hier entstehen Einladungslink, Bierwarte und Rollen, dein Name und '
          'der Wiederherstellungscode.',
        ),
      ],
    );
  }
}
