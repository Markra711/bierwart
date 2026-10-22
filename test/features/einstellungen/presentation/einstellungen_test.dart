import 'package:bier_wart/src/core/money/cents.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';

const alterCode = 'K7Q2MXA93DWFT2HC8RNP';

/// Kasse k1: Tobias (du), Jonas mit 32,00 € und Max mit −6,50 €. Ohne
/// Angabe ist Tobias Admin und Kassenwart.
FakeDatenbank kasse({String admin = 'uid', String kassenwart = 'uid'}) =>
    FakeDatenbank()
      ..neueKasse('k1', name: 'SV Test', admin: admin, kassenwart: kassenwart)
      ..ort('k1', 'kasse', 'Kasse')
      ..bierwart('k1', 'uid', 'Tobias Meier', stand: 4100)
      ..bierwart('k1', 'jonas', 'Jonas Weber', stand: 3200)
      ..bierwart('k1', 'max', 'Max Becker', stand: -650)
      ..mitglied('k1', 'gaeste', 'Gäste', gast: true);

Future<FakeDatenbank> oeffnen(WidgetTester tester, {FakeDatenbank? db}) async {
  telefon(tester);
  final daten = db ?? kasse();
  await appStarten(tester, kasseId: 'k1', db: daten);
  await tester.tap(find.byIcon(Icons.tune_rounded).hitTestable());
  await tester.pumpAndSettle();
  return daten;
}

Future<void> tippen(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  final ziel = find.text(text).last;
  await tester.ensureVisible(ziel);
  await tester.pumpAndSettle();
  await tester.tap(ziel);
  await tester.pumpAndSettle();
}

Future<void> menue(WidgetTester tester, String name) async {
  final knopf = find.byTooltip('Aktionen für $name');
  await tester.ensureVisible(knopf);
  await tester.pumpAndSettle();
  await tester.tap(knopf);
  await tester.pumpAndSettle();
}

Map<String, Object?> letzteBuchung(FakeDatenbank db) =>
    db.batches.last.firstWhere((s) => s.pfad.contains('/buchungen/')).daten;

void main() {
  testWidgets('Link, Bierwarte und Rollen wie im Design-Canvas', (
    tester,
  ) async {
    await oeffnen(tester);
    expect(find.text('EINSTELLUNGEN'), findsOneWidget);
    expect(find.text('bier-wart.web.app/j/$alterCode'), findsOneWidget);
    expect(
      find.text('Gültig bis Mo, 26.10. · alle dürfen ihn teilen'),
      findsOneWidget,
    );
    expect(find.text('du · Admin · Kassenwart'), findsOneWidget);
    expect(
      find.text('Bierwart · Portemonnaie ${formatEuro(3200)}'),
      findsOneWidget,
    );
    expect(find.text('ERNEUERN'), findsOneWidget);
    expect(find.byTooltip('Aktionen für Jonas Weber'), findsOneWidget);
    expect(find.byTooltip('Aktionen für Tobias Meier'), findsNothing);
    expect(find.text('Kasse umbenennen'), findsOneWidget);
    expect(find.text('Meinen Namen ändern'), findsOneWidget);
  });

  testWidgets('ohne Admin-Rolle nur Teilen und der eigene Name (UI-08)', (
    tester,
  ) async {
    await oeffnen(
      tester,
      db: kasse(admin: 'jonas', kassenwart: 'jonas'),
    );
    expect(find.text('TEILEN'), findsOneWidget);
    expect(find.text('ERNEUERN'), findsNothing);
    expect(find.byTooltip('Aktionen für Jonas Weber'), findsNothing);
    expect(find.text('Kasse umbenennen'), findsNothing);
    expect(find.text('Meinen Namen ändern'), findsOneWidget);
    expect(find.text('du · Bierwart'), findsOneWidget);
  });

  testWidgets('Link erneuern mit Bestätigung (ADM-01)', (tester) async {
    final db = await oeffnen(tester);
    await tippen(tester, 'ERNEUERN');
    expect(find.text('Neuen Link erstellen?'), findsOneWidget);
    await tippen(tester, 'ERNEUERN');

    expect(letzteBuchung(db)['typ'], 'einladungErneuert');
    final neu = db.docs['kassen/k1']!['einladungCode']! as String;
    expect(neu, isNot(alterCode));
    expect(db.docs['einladungen/$alterCode']!['ersetzt'], isTrue);
    expect(db.docs['einladungen/$neu']!['anzahlBierwarte'], 3);
    expect(find.text('bier-wart.web.app/j/$neu'), findsOneWidget);
    expect(
      find.text('Neuer Link erstellt. Der alte gilt nicht mehr.'),
      findsOne,
    );
  });

  testWidgets('Kassenwart bestimmen (ADM-03)', (tester) async {
    final db = await oeffnen(tester);
    await menue(tester, 'Jonas Weber');
    await tippen(tester, 'ZUM KASSENWART MACHEN');
    await tippen(tester, 'KASSENWART MACHEN');
    expect(letzteBuchung(db), containsPair('rolle', 'kassenwart'));
    expect(db.docs['kassen/k1']!['kassenwartUid'], 'jonas');
    expect(find.text('du · Admin'), findsOneWidget);
    expect(
      find.text('Kassenwart · Portemonnaie ${formatEuro(3200)}'),
      findsOneWidget,
    );
  });

  testWidgets('Admin-Rolle übergeben, danach keine Admin-Funktionen', (
    tester,
  ) async {
    final db = await oeffnen(tester);
    await menue(tester, 'Jonas Weber');
    await tippen(tester, 'ADMIN-ROLLE ÜBERGEBEN');
    await tippen(tester, 'ÜBERGEBEN');
    expect(db.docs['kassen/k1']!['adminUid'], 'jonas');
    expect(find.text('ERNEUERN'), findsNothing);
    expect(find.byTooltip('Aktionen für Max Becker'), findsNothing);
  });

  testWidgets('Bierwart entfernen: Portemonnaie ehemalig, Link neu (ADM-02)', (
    tester,
  ) async {
    final db = await oeffnen(tester);
    await menue(tester, 'Jonas Weber');
    await tippen(tester, 'ENTFERNEN');
    expect(find.text('Jonas Weber entfernen?'), findsOneWidget);
    await tippen(tester, 'ENTFERNEN');

    expect(letzteBuchung(db), containsPair('typ', 'bierwartEntfernt'));
    expect(db.docs.containsKey('kassen/k1/bierwarte/jonas'), isFalse);
    expect(db.docs['kassen/k1/orte/jonas']!['ehemalig'], isTrue);
    expect(db.docs['kassen/k1']!['anzahlBierwarte'], 2);
    expect(db.docs['einladungen/$alterCode']!['ersetzt'], isTrue);
    expect(find.text('Jonas Weber ist nicht mehr Bierwart.'), findsOneWidget);
    expect(find.byTooltip('Aktionen für Jonas Weber'), findsNothing);
  });

  testWidgets('den Kassenwart erst nach Übergabe der Rolle entfernen', (
    tester,
  ) async {
    final db = await oeffnen(tester, db: kasse(kassenwart: 'max'));
    await menue(tester, 'Max Becker');
    expect(find.text('Bestimm erst einen anderen Kassenwart.'), findsOne);
    await tippen(tester, 'ENTFERNEN');
    expect(db.batches, isEmpty);
  });

  testWidgets('Kasse umbenennen, die Einladung zieht mit (ADM-04)', (
    tester,
  ) async {
    final db = await oeffnen(tester);
    await tippen(tester, 'Kasse umbenennen');
    await tester.enterText(find.byType(TextField), '  SV  Neu ');
    await tippen(tester, 'UMBENENNEN');
    expect(db.docs['kassen/k1']!['name'], 'SV Neu');
    expect(db.docs['einladungen/$alterCode']!['kassenName'], 'SV Neu');
    expect(letzteBuchung(db), containsPair('nameAlt', 'SV Test'));
    expect(find.text('Kasse umbenennen'.toUpperCase()), findsNothing);
  });

  testWidgets('ohne Netz meldet sich die Verwaltung (NFA-10)', (tester) async {
    final db = kasse()
      ..serverFehler = FirebaseException(plugin: 'test', code: 'unavailable');
    await oeffnen(tester, db: db);
    await tippen(tester, 'ERNEUERN');
    await tippen(tester, 'ERNEUERN');
    expect(find.text('Dafür brauchst du Netz.'), findsOneWidget);
    expect(db.batches, isEmpty);
  });

  testWidgets('eigenen Namen ändern über den Kader (UI-09)', (tester) async {
    final db = await oeffnen(tester);
    await tippen(tester, 'Meinen Namen ändern');
    await tester.enterText(find.byType(TextField), 'Tobi Meier');
    await tippen(tester, 'UMBENENNEN');
    expect(letzteBuchung(db), containsPair('nameNeu', 'Tobi Meier'));
    expect(db.docs['kassen/k1/bierwarte/uid']!['name'], 'Tobi Meier');
  });

  testWidgets('wer entfernt wurde, landet ohne Kasse im Onboarding', (
    tester,
  ) async {
    telefon(tester);
    final db = kasse()..docs.remove('kassen/k1/bierwarte/uid');
    await appStarten(tester, kasseId: 'k1', db: db);
    expect(
      find.text('Ich habe einen Einladungslink'.toUpperCase()),
      findsOneWidget,
    );
  });
}
