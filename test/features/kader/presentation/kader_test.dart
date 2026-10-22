import 'package:bier_wart/src/core/money/cents.dart';
import 'package:bier_wart/src/features/geld/data/zahlung_batch.dart';
import 'package:bier_wart/src/features/strichliste/application/strichliste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';

/// Kasse k1: Jonas 12,00 € offen, Paul 7,50 €, Felix mit Guthaben, Ben
/// ausgeglichen, Paul Alt entfernt; Bier zu 1,50 €.
FakeDatenbank kader() => testDatenbank()
  ..sorte('k1', 'bier', 'Bier 0,5', 150)
  ..mitglied('k1', 'jonas', 'Jonas Weber', saldo: 1200)
  ..mitglied('k1', 'paul', 'Paul Hoffmann', saldo: 750)
  ..mitglied('k1', 'felix', 'Felix Wagner', saldo: -500)
  ..mitglied('k1', 'ben', 'Ben Wolf')
  ..mitglied('k1', 'alt', 'Paul Alt', entfernt: true);

Future<FakeDatenbank> starten(WidgetTester tester, {FakeDatenbank? db}) async {
  telefon(tester);
  final daten = db ?? kader();
  await appStarten(tester, kasseId: 'k1', db: daten);
  await tester.tap(find.text('KADER'));
  await tester.pumpAndSettle();
  return daten;
}

Map<String, Object?> letzteBuchung(FakeDatenbank db) =>
    db.batches.last.firstWhere((s) => s.pfad.contains('/buchungen/')).daten;

Future<void> detailOeffnen(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> tippen(WidgetTester tester, String text) async {
  final ziel = find.text(text.toUpperCase()).last;
  await tester.ensureVisible(ziel);
  await tester.tap(ziel);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Kader nach Schulden, Summen, Rollen (KAD-05)', (tester) async {
    await starten(tester);
    expect(find.text('5 MITGLIEDER + GÄSTE'), findsOneWidget);
    expect(find.text(formatEuro(1950)), findsOneWidget);
    expect(find.text(formatEuro(500)), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Hat im Voraus bezahlt'), findsOneWidget);
    expect(find.text('Paul Alt'), findsNothing);
    expect(find.text('Gäste'), findsNothing);

    final reihe = [
      'Jonas Weber',
      'Paul Hoffmann',
      'Ben Wolf',
      'Tobias Meier',
      'Felix Wagner',
    ];
    final y = [for (final n in reihe) tester.getTopLeft(find.text(n)).dy];
    for (var i = 1; i < y.length; i++) {
      expect(y[i], greaterThan(y[i - 1]), reason: reihe[i]);
    }
  });

  testWidgets(
    'Detail zeigt Striche, Storno bucht Gegenbuchung (KAD-06, STR-06)',
    (tester) async {
      final db = await starten(tester);
      // Erst auf der Strichliste buchen, dann im Kader ansehen.
      await tester.tap(find.text('STRICHE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jonas Weber'));
      await tester.pump(StrichlisteNotifier.rueckgaengigFrist);
      await tester.tap(find.text('KADER'));
      await tester.pumpAndSettle();

      await detailOeffnen(tester, 'Jonas Weber');
      expect(find.text('JONAS WEBER'), findsOneWidget);
      expect(find.text('OFFEN'), findsOneWidget);
      expect(find.text(formatEuro(1350)), findsOneWidget);
      expect(find.text('Bier 0,5'), findsOneWidget);
      expect(find.textContaining('von Tobias'), findsOneWidget);

      await tester.tap(find.byTooltip('Strich stornieren'));
      await tester.pumpAndSettle();
      expect(letzteBuchung(db)['typ'], 'storno');
      expect(find.textContaining('storniert'), findsWidgets);
      expect(find.byTooltip('Strich stornieren'), findsNothing);
      expect(find.text(formatEuro(1200)), findsOneWidget);
    },
  );

  testWidgets(
    'Zahlung erfassen: offener Betrag als Vorschlag (GEL-02, GEL-03)',
    (tester) async {
      final db = await starten(tester);
      await detailOeffnen(tester, 'Jonas Weber');
      await tippen(tester, 'Zahlung erfassen');

      expect(find.text('ZAHLUNG VON JONAS'), findsOneWidget);
      expect(
        find.text('${formatEuro(1200)} verbuchen'.toUpperCase()),
        findsOneWidget,
      );
      // Tobias ist Kassenwart und darf die Kasse wählen (UI-08).
      expect(find.text('die Kasse'), findsOneWidget);
      await tester.tap(find.text('20 €'));
      await tester.pump();
      await tippen(tester, '${formatEuro(2000)} verbuchen');

      expect(letzteBuchung(db)['typ'], 'zahlung');
      expect(letzteBuchung(db)['betragCents'], 2000);
      expect(letzteBuchung(db)['ortId'], 'kasse');
      // Überzahlung wird Guthaben.
      expect(find.text('GUTHABEN'), findsOneWidget);
      expect(find.text('+${formatEuro(800)}'), findsOneWidget);
    },
  );

  testWidgets('ohne Kassenwart-Rolle geht das Geld ins eigene Portemonnaie', (
    tester,
  ) async {
    final db = kader()..neueKasse('k1', name: 'SV Test', kassenwart: 'jemand');
    await starten(tester, db: db);
    await detailOeffnen(tester, 'Paul Hoffmann');
    await tippen(tester, 'Zahlung erfassen');
    expect(find.text('die Kasse'), findsNothing);
    expect(find.text('Das Geld kommt in dein Portemonnaie.'), findsOneWidget);
    await tippen(tester, '${formatEuro(750)} verbuchen');
    expect(letzteBuchung(db)['ortId'], 'uid');
  });

  testWidgets('Zahlung ohne gültigen Betrag wird abgelehnt', (tester) async {
    final db = await starten(tester);
    await detailOeffnen(tester, 'Ben Wolf');
    await tippen(tester, 'Zahlung erfassen');
    await tippen(tester, 'Verbuchen');
    expect(find.text('Betrag wie 12,00 eingeben.'), findsOneWidget);
    expect(db.batches, isEmpty);
  });

  testWidgets('Umbenennen, Name nur einmal (KAD-01, UI-09)', (tester) async {
    final db = await starten(tester);
    await detailOeffnen(tester, 'Ben Wolf');
    await tester.tap(find.bySemanticsLabel('Umbenennen oder entfernen'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Umbenennen');

    await tester.enterText(find.byType(TextField), 'Jonas Weber');
    await tippen(tester, 'Umbenennen');
    expect(
      find.text('„Jonas Weber“ gibt es in der Kasse schon.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Benjamin Wolf');
    await tippen(tester, 'Umbenennen');
    expect(letzteBuchung(db)['typ'], 'mitgliedUmbenannt');
    expect(find.text('BENJAMIN WOLF'), findsOneWidget);
  });

  testWidgets('Entfernen nur bei 0 und mit Bestätigung (KAD-04, UI-04)', (
    tester,
  ) async {
    final db = await starten(tester);
    await detailOeffnen(tester, 'Jonas Weber');
    expect(
      find.text('Entfernen geht erst, wenn nichts mehr offen ist.'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Umbenennen oder entfernen'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Entfernen');
    expect(db.batches, isEmpty, reason: 'Knopf ist gesperrt');
    Navigator.of(tester.element(find.text('UMBENENNEN'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Zurück'));
    await tester.pumpAndSettle();
    await detailOeffnen(tester, 'Ben Wolf');
    await tester.tap(find.bySemanticsLabel('Umbenennen oder entfernen'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Entfernen');
    expect(find.text('„Ben Wolf“ entfernen?'), findsOneWidget);
    await tester.tap(find.text('ENTFERNEN').last);
    await tester.pumpAndSettle();
    expect(letzteBuchung(db)['typ'], 'mitgliedEntfernt');
    expect(find.text('Ben Wolf'), findsNothing);
    expect(find.text('OFFEN GESAMT'), findsOneWidget);
  });

  testWidgets('aktive Bierwarte lassen sich nicht entfernen (KAD-02)', (
    tester,
  ) async {
    await starten(tester);
    await detailOeffnen(tester, 'Tobias Meier');
    await tester.tap(find.bySemanticsLabel('Umbenennen oder entfernen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bierwarte bleiben Mitglied, solange sie dabei sind.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Mitglied anlegen; entfernte lassen sich zurückholen (KAD-01, KAD-08)',
    (tester) async {
      final db = await starten(tester);
      await tippen(tester, 'Mitglied');
      await tester.enterText(find.byType(TextField), 'jonas weber');
      await tippen(tester, 'Mitglied anlegen');
      expect(
        find.text('„jonas weber“ gibt es in der Kasse schon.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Paul Alt');
      await tippen(tester, 'Mitglied anlegen');
      expect(find.text('„Paul Alt“ war schon Mitglied.'), findsOneWidget);
      await tippen(tester, 'Wieder aufnehmen');
      expect(letzteBuchung(db)['typ'], 'mitgliedWiederaufgenommen');
      expect(find.text('Paul Alt'), findsOneWidget);

      await tippen(tester, 'Mitglied');
      await tester.enterText(find.byType(TextField), 'Tim Richter');
      await tippen(tester, 'Mitglied anlegen');
      expect(letzteBuchung(db)['typ'], 'mitgliedAngelegt');
      expect(find.text('Tim Richter'), findsOneWidget);
    },
  );

  testWidgets('Zahlung stornieren mit Bestätigung (offene Frage 24)', (
    tester,
  ) async {
    final db = await starten(tester);
    await detailOeffnen(tester, 'Jonas Weber');
    await tippen(tester, 'Zahlung erfassen');
    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();
    await tippen(tester, '${formatEuro(500)} verbuchen');
    expect(db.docs['kassen/k1/mitglieder/jonas']!['saldoCents'], 700);

    await tester.tap(find.byTooltip('Zahlung stornieren'));
    await tester.pumpAndSettle();
    expect(find.text('Zahlung über ${formatEuro(500)} stornieren?'), findsOne);
    await tippen(tester, 'Stornieren');

    expect(letzteBuchung(db), containsPair('bezugTyp', 'zahlung'));
    expect(letzteBuchung(db), containsPair('ortId', 'kasse'));
    expect(db.docs['kassen/k1/mitglieder/jonas']!['saldoCents'], 1200);
    expect(find.byTooltip('Zahlung stornieren'), findsNothing);
    expect(find.text('Zahlung storniert.'), findsOneWidget);
  });

  testWidgets('Zahlung aus fremdem Portemonnaie: Hinweis statt Storno', (
    tester,
  ) async {
    final db = kader()..bierwart('k1', 'max', 'Max Becker', stand: 500);
    await db.schreiben(
      zahlungBatch(
        uid: 'max',
        bierwartName: 'Max Becker',
        kasseId: 'k1',
        buchungId: 'z9',
        mitgliedId: 'jonas',
        betragCents: 500,
        ortId: 'max',
        geraetZeit: DateTime(2026, 10, 22, 19),
      ),
    );
    db.batches.clear();
    await starten(tester, db: db);
    await detailOeffnen(tester, 'Jonas Weber');
    await tester.tap(find.byTooltip('Zahlung stornieren'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Das Geld liegt im Portemonnaie von Max. Stornieren kann nur, wer es '
        'hat.',
      ),
      findsOneWidget,
    );
    expect(db.batches, isEmpty);
  });
}
