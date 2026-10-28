import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/seite.dart';

/// Kurzer Hinweis, welche Daten wo liegen (NFA-09). Der Text ist ein Entwurf
/// (architecture.md, offene Frage 18).
class DatenschutzScreen extends StatelessWidget {
  const DatenschutzScreen({super.key});

  static const abschnitte = [
    (
      'Was gespeichert wird',
      'Die Namen, die ihr eintragt (Bierwarte, Mitglieder, Getränke), und '
          'alle Buchungen mit Betrag, Zeit und dem Namen, wer gebucht hat. '
          'Keine E-Mail-Adresse, keine Telefonnummer.',
    ),
    (
      'Anmeldung',
      'Die App meldet dein Gerät anonym bei Firebase Authentication von '
          'Google an. Dafür speichert Firebase eine zufällige Kennung, keine '
          'Angaben zu dir.',
    ),
    (
      'Wo die Daten liegen',
      'In Cloud Firestore von Google Firebase, Region europe-west10 '
          '(Berlin).',
    ),
    (
      'Wer sie sieht',
      'Alle Bierwarte deiner Kasse. Mitglieder ohne App sehen nichts.',
    ),
    (
      'Löschen',
      'Wer austritt, dessen Konto wird gelöscht. Name und Buchungen '
          'bleiben im Verlauf der Kasse, damit die Abrechnung stimmt. Der '
          'Admin kann die Kasse auflösen, dann ist alles gelöscht. Eine Kasse '
          'ohne Bierwarte wird bisher nicht automatisch gelöscht.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BwSeite(
      zurueck: () =>
          context.canPop() ? context.pop() : context.go(Routen.einstellungen),
      inhalt: [
        const BwTitel(voll: 'Datenschutz'),
        for (final (titel, text) in abschnitte)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BwLabel(titel),
              const SizedBox(height: BwSpacing.space2),
              BwErklaerung(text),
            ],
          ),
      ],
    );
  }
}
