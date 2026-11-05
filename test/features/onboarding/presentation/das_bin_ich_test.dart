import 'package:bier_wart/src/core/routing/router.dart';
import 'package:bier_wart/src/features/onboarding/application/uebernahme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';
import 'beitreten_test.dart' show code, einladung, mitCode, tippen;

/// Das neue Gerät: Kasse k1 mit „Jonas Weber“ (Mitglied `jonas`).
Future<(FakeKasseRepository, FakeDatenbank, FakeSpeicher)> starten(
  WidgetTester tester, {
  FakeSpeicher? speicher,
}) async {
  telefon(tester);
  final db = testDatenbank()
    ..mitglied('k1', 'jonas', 'Jonas Weber')
    ..jetzt = DateTime.now();
  final einstellungen = speicher ?? FakeSpeicher();
  final repo = await appStarten(tester, db: db, einstellungen: einstellungen);
  repo.einladungen[code] = einladung();
  repo.vergebeneNamen['jonas weber'] = 'jonas';
  repo.vergebeneNamen['gäste'] = 'gaeste';
  return (repo, db, einstellungen);
}

/// Name eintippen, „Beitreten“, dann „Das bin ich“.
Future<void> anfragen(
  WidgetTester tester, {
  String name = 'jonas weber',
}) async {
  await mitCode(tester, Routen.nameWaehlen);
  await tester.enterText(find.byType(TextField), name);
  await tippen(tester, 'Beitreten');
  await tippen(tester, 'Das bin ich');
}

String anfrageId(FakeDatenbank db) => db.docs.keys
    .firstWhere((p) => p.startsWith('kassen/k1/uebernahmen/'))
    .split('/')
    .last;

void setzeStatus(FakeDatenbank db, String status) => db.uebernahme(
  'k1',
  anfrageId(db),
  mitgliedId: 'jonas',
  neueUid: 'uid',
  status: status,
);

void main() {
  testWidgets('vergebener Name: „Das bin ich“ fragt an und wartet (UC-03)', (
    tester,
  ) async {
    final (_, db, speicher) = await starten(tester);
    await anfragen(tester);

    final anfrage = db.docs['kassen/k1/uebernahmen/${anfrageId(db)}']!;
    expect(anfrage['mitgliedId'], 'jonas');
    expect(anfrage['status'], 'offen');
    final log = db.batches.last
        .firstWhere((s) => s.pfad.contains('/buchungen/'))
        .daten;
    expect(log['typ'], 'uebernahmeAngefragt');
    expect((log['stempel']! as Map)['name'], 'jonas weber');

    expect(
      find.textContaining('Ein Bierwart aus der Kasse muss'),
      findsOneWidget,
    );
    expect(find.text('als jonas weber, mit neuem Handy'), findsOneWidget);
    expect(
      speicher.werte[UebernahmeAnfrageNotifier.schluessel],
      contains(anfrageId(db)),
    );
  });

  testWidgets('„Gäste“ lässt sich nicht übernehmen (KAD-03)', (tester) async {
    await starten(tester);
    await mitCode(tester, Routen.nameWaehlen);
    await tester.enterText(find.byType(TextField), 'Gäste');
    await tippen(tester, 'Beitreten');
    expect(
      find.textContaining('gibt es hier schon', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('DAS BIN ICH'), findsNothing);
  });

  testWidgets('bestätigt: trägt die Kasse ein und landet auf der Strichliste', (
    tester,
  ) async {
    final (_, db, speicher) = await starten(tester);
    await anfragen(tester);

    setzeStatus(db, 'bestaetigt');
    await tester.pumpAndSettle();
    expect(
      db.batches.last.single.pfad,
      'users/uid',
      reason: 'das neue Gerät schreibt users/{uid} selbst',
    );
    expect(find.text('STRICHLISTE'), findsOneWidget);
    expect(speicher.werte[UebernahmeAnfrageNotifier.schluessel], isNull);
  });

  testWidgets('abgelehnt: Hinweis, dann zurück zum Start', (tester) async {
    final (_, db, speicher) = await starten(tester);
    await anfragen(tester);

    setzeStatus(db, 'abgelehnt');
    await tester.pumpAndSettle();
    expect(find.textContaining('Die Anfrage wurde abgelehnt.'), findsOneWidget);
    await tippen(tester, 'Zum Start');
    expect(find.text('ICH HABE EINEN EINLADUNGSLINK'), findsOneWidget);
    expect(speicher.werte[UebernahmeAnfrageNotifier.schluessel], isNull);
  });

  testWidgets('abgelaufen nach 7 Tagen', (tester) async {
    final (_, db, _) = await starten(tester);
    await anfragen(tester);

    db.uebernahme(
      'k1',
      anfrageId(db),
      mitgliedId: 'jonas',
      neueUid: 'uid',
      angefragtAm: DateTime.now().subtract(const Duration(days: 8)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Die Anfrage ist abgelaufen'), findsOneWidget);
  });

  testWidgets('zurückziehen bucht und führt zum Start', (tester) async {
    final (_, db, _) = await starten(tester);
    await anfragen(tester);

    await tippen(tester, 'Anfrage zurückziehen');
    final id = anfrageId(db);
    expect(db.docs['kassen/k1/uebernahmen/$id']!['status'], 'zurueckgezogen');
    final log = db.batches.last
        .firstWhere((s) => s.pfad.contains('/buchungen/'))
        .daten;
    expect(log['typ'], 'uebernahmeZurueckgezogen');
    expect(find.text('ICH HABE EINEN EINLADUNGSLINK'), findsOneWidget);
  });

  testWidgets('mit Wiederherstellungscode: zieht zurück, öffnet die Eingabe', (
    tester,
  ) async {
    final (_, db, _) = await starten(tester);
    await anfragen(tester);

    await tippen(tester, 'Ich habe einen Wiederherstellungscode');
    expect(
      db.docs['kassen/k1/uebernahmen/${anfrageId(db)}']!['status'],
      'zurueckgezogen',
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.textContaining('Ein Bierwart aus der Kasse muss'),
      findsNothing,
    );
  });

  testWidgets(
    'abgelehnte Anfrage meldet sich und bleibt auf der Seite (NFA-10)',
    (tester) async {
      final (_, db, speicher) = await starten(tester);
      await mitCode(tester, Routen.nameWaehlen);
      await tester.enterText(find.byType(TextField), 'jonas weber');
      await tippen(tester, 'Beitreten');
      db.schreibFehler = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await tippen(tester, 'Das bin ich');
      expect(find.textContaining('permission-denied'), findsOneWidget);
      expect(
        find.textContaining('Ein Bierwart aus der Kasse muss'),
        findsNothing,
      );
      expect(speicher.werte, isEmpty);
    },
  );

  testWidgets('nach einem Neustart wartet das Gerät weiter', (tester) async {
    final speicher = FakeSpeicher();
    final (_, db, _) = await starten(tester, speicher: speicher);
    await anfragen(tester);
    final gemerkt = speicher.werte[UebernahmeAnfrageNotifier.schluessel]!;

    // Neue App mit demselben Gerätespeicher.
    await tester.pumpWidget(const SizedBox());
    final neu = FakeSpeicher()
      ..werte[UebernahmeAnfrageNotifier.schluessel] = gemerkt;
    await appStarten(tester, db: db, einstellungen: neu);
    expect(
      find.textContaining('Ein Bierwart aus der Kasse muss'),
      findsOneWidget,
    );
  });
}
