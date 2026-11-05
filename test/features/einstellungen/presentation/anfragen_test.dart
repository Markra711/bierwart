import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';

/// Kasse k1: Tobias (du, Admin und Kassenwart), Jonas als Bierwart mit
/// 12,50 € im Portemonnaie. Ein neues Gerät („neu“) will Jonas sein.
FakeDatenbank mitAnfrage({
  String mitgliedId = 'jonas',
  DateTime? angefragtAm,
}) => testDatenbank()
  ..bierwart('k1', 'jonas', 'Jonas Weber', stand: 1250)
  ..jetzt = DateTime.now()
  ..uebernahme(
    'k1',
    'a1',
    mitgliedId: mitgliedId,
    angefragtAm: angefragtAm ?? DateTime(2026, 11, 5, 21, 12),
  );

Future<FakeDatenbank> starten(WidgetTester tester, {FakeDatenbank? db}) async {
  telefon(tester);
  final daten = db ?? mitAnfrage();
  // Die Anfrage gilt 7 Tage; ohne angefragtAm von heute wäre sie abgelaufen.
  final a = daten.docs['kassen/k1/uebernahmen/a1']!;
  if ((a['angefragtAm']! as DateTime).isBefore(DateTime(2026, 11, 6))) {
    a['angefragtAm'] = DateTime.now().subtract(const Duration(hours: 1));
  }
  await appStarten(tester, kasseId: 'k1', db: daten);
  return daten;
}

Future<void> tippen(WidgetTester tester, String text) async {
  final ziel = find.text(text.toUpperCase()).last;
  await tester.ensureVisible(ziel);
  await tester.pumpAndSettle();
  await tester.tap(ziel);
  await tester.pumpAndSettle();
}

Finder hinweis(String text) => find.textContaining(text, findRichText: true);

String status(FakeDatenbank db) =>
    db.docs['kassen/k1/uebernahmen/a1']!['status']! as String;

void main() {
  testWidgets('Hinweis auf der Strichliste, bestätigen zieht alles um '
      '(UC-03, ADR-0008)', (tester) async {
    final db = await starten(tester);
    expect(hinweis('will mit neuem Handy rein.'), findsOneWidget);

    await tippen(tester, 'Ansehen');
    expect(find.text('JONAS WEBER?'), findsOneWidget);
    await tippen(tester, 'Das ist Jonas');

    expect(status(db), 'bestaetigt');
    expect(db.docs['kassen/k1/bierwarte/neu']!['mitgliedId'], 'jonas');
    expect(db.docs.containsKey('kassen/k1/bierwarte/jonas'), isFalse);
    expect(db.docs['kassen/k1/mitglieder/jonas']!['bierwartUid'], 'neu');
    expect(db.docs['kassen/k1/orte/neu']!['standCents'], 1250);
    expect(db.docs['kassen/k1/orte/jonas']!['standCents'], 0);
    expect(find.text('Jonas ist wieder drin.'), findsOneWidget);
    expect(hinweis('will mit neuem Handy rein.'), findsNothing);
  });

  testWidgets('ablehnen bucht und nimmt den Hinweis weg', (tester) async {
    final db = await starten(tester);
    await tippen(tester, 'Ansehen');
    await tippen(tester, 'Ablehnen');

    expect(status(db), 'abgelehnt');
    final log = db.batches.last
        .firstWhere((s) => s.pfad.contains('/buchungen/'))
        .daten;
    expect(log['typ'], 'uebernahmeAbgelehnt');
    expect((log['stempel']! as Map)['name'], 'Tobias Meier');
    expect(find.text('Anfrage abgelehnt.'), findsOneWidget);
    expect(hinweis('will mit neuem Handy rein.'), findsNothing);
  });

  testWidgets('abgelaufene Anfragen zeigt die App nicht mehr', (tester) async {
    final db = mitAnfrage();
    await starten(tester, db: db);
    db.uebernahme(
      'k1',
      'a1',
      mitgliedId: 'jonas',
      angefragtAm: DateTime.now().subtract(const Duration(days: 8)),
    );
    await tester.pumpAndSettle();
    expect(hinweis('will mit neuem Handy rein.'), findsNothing);
  });

  testWidgets('ohne Anfrage kein Hinweis und kein Abschnitt', (tester) async {
    final db = mitAnfrage()..docs.remove('kassen/k1/uebernahmen/a1');
    telefon(tester);
    await appStarten(tester, kasseId: 'k1', db: db);
    expect(hinweis('mit neuem Handy'), findsNothing);
    await tester.tap(find.byIcon(Icons.tune_rounded).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('ANFRAGEN'), findsNothing);
  });

  testWidgets('auch in den Einstellungen (offene Frage 23)', (tester) async {
    await starten(tester);
    await tester.tap(find.byIcon(Icons.tune_rounded).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('ANFRAGEN'), findsOneWidget);
    await tippen(tester, 'Ansehen');
    expect(find.text('JONAS WEBER?'), findsOneWidget);
  });

  testWidgets('das alte Gerät sieht die Anfrage für sich selbst', (
    tester,
  ) async {
    await starten(tester, db: mitAnfrage(mitgliedId: 'uid'));
    expect(hinweis('Du auf einem neuen Handy?'), findsOneWidget);
    await tippen(tester, 'Ansehen');
    expect(find.text('JA, DAS BIN ICH'), findsOneWidget);
  });

  testWidgets('schon entschieden: Meldung statt Ablehnung der Rules (NFA-10)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tippen(tester, 'Ansehen');
    // Ein anderer Bierwart war schneller; das Sheet ist noch offen.
    db.docs['kassen/k1/uebernahmen/a1']!['status'] = 'abgelehnt';
    await tippen(tester, 'Das ist Jonas');
    expect(
      find.text('Die Anfrage ist schon entschieden oder zurückgezogen.'),
      findsOneWidget,
    );
    expect(db.docs.containsKey('kassen/k1/bierwarte/neu'), isFalse);
  });
}
