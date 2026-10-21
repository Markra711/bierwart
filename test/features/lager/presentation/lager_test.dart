import 'package:bier_wart/src/core/money/cents.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';

/// Kasse k1: Bier mit 38, Cola mit 9, Fanta leer, Wasser ausgeblendet.
FakeDatenbank lager() => testDatenbank()
  ..sorte('k1', 'bier', 'Bier 0,5', 150, bestand: 38, reihenfolge: 0)
  ..sorte('k1', 'cola', 'Cola 0,33', 120, bestand: 9, reihenfolge: 1)
  ..sorte('k1', 'fanta', 'Fanta 0,5', 150, bestand: 0, reihenfolge: 2)
  ..sorte('k1', 'wasser', 'Wasser 0,5', 100, reihenfolge: 3, aktiv: false);

Future<FakeDatenbank> starten(WidgetTester tester, {FakeDatenbank? db}) async {
  telefon(tester);
  final daten = db ?? lager();
  await appStarten(tester, kasseId: 'k1', db: daten);
  await tester.tap(find.text('LAGER'));
  await tester.pumpAndSettle();
  return daten;
}

Map<String, Object?> letzteBuchung(FakeDatenbank db) =>
    db.batches.last.firstWhere((s) => s.pfad.contains('/buchungen/')).daten;

Future<void> tippen(WidgetTester tester, String text) async {
  final ziel = find.text(text.toUpperCase()).last;
  await tester.ensureVisible(ziel);
  await tester.tap(ziel);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Lager mit Bestand, Leer und Ausgeblendet (BES-03)', (
    tester,
  ) async {
    await starten(tester);
    expect(find.text('3 SORTEN · 47 FLASCHEN'), findsOneWidget);
    expect(find.text('38 Fl.'), findsOneWidget);
    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('Buchen bleibt möglich · Nachkauf nötig'), findsOneWidget);
    expect(find.text('AUSGEBLENDET'), findsOneWidget);
    expect(find.text('Wasser 0,5'), findsOneWidget);
  });

  testWidgets(
    'Preis ändern: alter Preis bleibt als vorheriger (BES-01, BES-02)',
    (tester) async {
      final db = await starten(tester);
      await tester.tap(find.text('Bier 0,5'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ein neuer Preis gilt nur für neue Striche.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(1), '1,70');
      await tippen(tester, 'Speichern');
      expect(letzteBuchung(db)['typ'], 'sorteGeaendert');
      expect(db.docs['kassen/k1/sorten/bier']!['vorherigerPreisCents'], 150);
      expect(find.text(formatEuro(170)), findsOneWidget);
    },
  );

  testWidgets('Speichern ohne Änderung schreibt nichts', (tester) async {
    final db = await starten(tester);
    await tester.tap(find.text('Cola 0,33'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Speichern');
    expect(db.batches, isEmpty);
  });

  testWidgets('Ausblenden mit Bestätigung, wieder einblenden (BES-01, UI-04)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tester.tap(find.text('Cola 0,33'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Sorte ausblenden');
    expect(find.text('„Cola 0,33“ ausblenden?'), findsOneWidget);
    await tester.tap(find.text('AUSBLENDEN'));
    await tester.pumpAndSettle();
    expect(db.docs['kassen/k1/sorten/cola']!['aktiv'], isFalse);

    await tester.tap(find.text('Wasser 0,5'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Wieder einblenden');
    expect(db.docs['kassen/k1/sorten/wasser']!['aktiv'], isTrue);
  });

  testWidgets('Bestand korrigieren mit Differenz zum Server (BES-06)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tester.tap(find.text('Bier 0,5'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Korrigieren');
    await tester.enterText(find.byType(TextField).last, '35');
    await tippen(tester, 'Bestand setzen');

    expect(letzteBuchung(db)['typ'], 'bestandKorrektur');
    expect(letzteBuchung(db)['gezaehlt'], 35);
    expect(letzteBuchung(db)['differenz'], -3);
    expect(find.text('35 Fl.'), findsOneWidget);
  });

  testWidgets('Korrektur ohne Netz meldet sich (BES-06, NFA-10)', (
    tester,
  ) async {
    final db = lager()
      ..serverFehler = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    await starten(tester, db: db);
    await tester.tap(find.text('Bier 0,5'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Korrigieren');
    await tester.enterText(find.byType(TextField).last, '35');
    await tippen(tester, 'Bestand setzen');
    expect(find.text('Zum Zählen brauchst du Netz.'), findsOneWidget);
    expect(db.batches, isEmpty);
  });

  testWidgets('Einkauf mit zwei Sorten aus der Kasse (BES-04, BES-05)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tippen(tester, 'Einkauf');
    expect(find.text('EINKAUF'), findsOneWidget);

    await tester.tap(find.text('Sorte wählen'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Fanta 0,5');
    await tippen(tester, '+20');
    await tippen(tester, '+1');

    await tippen(tester, '+ Zeile');
    await tester.tap(find.text('Sorte wählen'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Cola 0,33');
    await tester.tap(find.text('+24'.toUpperCase()).last);
    await tester.pump();

    await tester.enterText(find.byType(TextField), '38,90');
    await tester.pump();
    await tester.tap(find.text('Kasse'));
    await tester.pump();
    await tippen(tester, '45 Flaschen einbuchen · ${formatEuro(3890)}');

    final b = letzteBuchung(db);
    expect(b['typ'], 'einkauf');
    expect(b['zeilen'], {'fanta': 21, 'cola': 24});
    expect(b['ortId'], 'kasse');
    expect(db.docs['kassen/k1/sorten/fanta']!['bestand'], 21);
    expect(find.text('21 Fl.'), findsOneWidget);
  });

  testWidgets('Einkauf ohne Zeile oder Preis wird abgelehnt', (tester) async {
    final db = await starten(tester);
    await tippen(tester, 'Einkauf');
    await tippen(tester, 'Einbuchen');
    expect(
      find.text('Mindestens eine Sorte mit Anzahl eintragen.'),
      findsOneWidget,
    );
    expect(find.text('Gesamtpreis wie 38,90 eingeben.'), findsOneWidget);
    expect(db.batches, isEmpty);
  });

  testWidgets('ohne Kassenwart-Rolle aus dem eigenen Portemonnaie (UI-08)', (
    tester,
  ) async {
    final db = lager()..neueKasse('k1', name: 'SV Test', kassenwart: 'jemand');
    await starten(tester, db: db);
    await tippen(tester, 'Einkauf');
    expect(find.text('Bezahlt aus deinem Portemonnaie.'), findsOneWidget);
    expect(find.text('Kasse'), findsNothing);
    await tester.tap(find.text('Sorte wählen'));
    await tester.pumpAndSettle();
    await tippen(tester, 'Bier 0,5');
    await tippen(tester, '+6');
    await tester.enterText(find.byType(TextField), '9');
    await tester.pump();
    await tippen(tester, '6 Flaschen einbuchen · ${formatEuro(900)}');
    expect(letzteBuchung(db)['ortId'], 'uid');
  });

  testWidgets('Sorte anlegen im Lager (BES-01)', (tester) async {
    final db = await starten(tester);
    await tippen(tester, 'Sorte');
    await tester.enterText(find.byType(TextField).at(0), 'Radler 0,5');
    await tester.enterText(find.byType(TextField).at(1), '1,50');
    await tippen(tester, 'Sorte anlegen');
    expect(letzteBuchung(db)['typ'], 'sorteAngelegt');
    expect(find.text('Radler 0,5'), findsOneWidget);
  });
}
