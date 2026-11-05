// Screenshots für den Play-Store-Eintrag (docs/store/screenshots/).
// Läuft nur auf Zuruf, weil Schriften und Bilder je nach Rechner leicht
// anders rendern:
//   SCREENSHOTS_AKTUALISIEREN=1 flutter test test/store

import 'dart:io';

import 'package:bier_wart/src/core/theme/app_theme.dart';
import 'package:bier_wart/src/features/geld/data/zahlung_batch.dart';
import 'package:bier_wart/src/features/strichliste/data/strich_batches.dart';
import 'package:bier_wart/src/features/strichliste/domain/strich.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';
import '../helpers/datenbank.dart';

final _aktualisieren = Platform.environment['SCREENSHOTS_AKTUALISIEREN'] == '1';

/// 1080 × 1920 Pixel. Play nimmt Screenshots nur bis zum Seitenverhältnis 2:1,
/// die 390 × 844 aus dem Canvas wären zu schmal.
void storeTelefon(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

Future<void> _schrift(String familie, List<String> dateien) async {
  final loader = FontLoader(familie);
  for (final datei in dateien) {
    final bytes = File(datei).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Barlow aus assets/fonts und die Material-Icons aus dem Flutter-SDK. Ohne
/// sie zeichnet der Test Ersatzkästchen statt Buchstaben.
Future<void> _schriftenLaden() async {
  await _schrift('Barlow Condensed', [
    for (final s in ['Light', 'SemiBold', 'Bold'])
      'assets/fonts/BarlowCondensed-$s.ttf',
  ]);
  await _schrift('Barlow', [
    for (final s in ['Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Barlow-$s.ttf',
  ]);
  final flutter = Platform.environment['FLUTTER_ROOT']!;
  await _schrift('MaterialIcons', [
    '$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

/// Eine erfundene Mannschaft: Tobias (du) ist Admin und Kassenwart, Max und
/// Jonas sind Bierwarte. Namen frei erfunden.
Future<FakeDatenbank> demoKasse() async {
  final db = FakeDatenbank()
    ..neueKasse('k1', name: 'SV Grünwiese')
    ..ort('k1', 'kasse', 'Kasse', stand: 18640)
    ..bierwart('k1', 'uid', 'Tobias Meier', stand: 2350)
    ..bierwart('k1', 'jonas', 'Jonas Weber', stand: 1200)
    ..bierwart('k1', 'max', 'Max Becker', stand: 450)
    ..sorte('k1', 'bier', 'Pils 0,5', 150, bestand: 38, reihenfolge: 0)
    ..sorte('k1', 'radler', 'Radler 0,5', 150, bestand: 14, reihenfolge: 1)
    ..sorte('k1', 'weizen', 'Weizen 0,5', 200, bestand: 9, reihenfolge: 2)
    ..sorte('k1', 'spezi', 'Spezi 0,5', 120, bestand: 3, reihenfolge: 3)
    ..sorte('k1', 'wasser', 'Wasser 0,5', 100, bestand: 0, reihenfolge: 4)
    ..mitglied('k1', 'lukas', 'Lukas Beck', saldo: 750)
    ..mitglied('k1', 'felix', 'Felix Wagner', saldo: 1500)
    ..mitglied('k1', 'niklas', 'Niklas Hahn', saldo: 1350)
    ..mitglied('k1', 'jan', 'Jan Schröder', saldo: 300)
    ..mitglied('k1', 'david', 'David Krüger')
    ..mitglied('k1', 'simon', 'Simon Wolf', saldo: 450)
    ..mitglied('k1', 'tim', 'Tim Neumann', saldo: 2100)
    ..mitglied('k1', 'paul', 'Paul Horn', saldo: 600)
    ..mitglied('k1', 'gaeste', 'Gäste', gast: true);
  db.docs['kassen/k1/mitglieder/uid']!['saldoCents'] = 450;
  db.docs['kassen/k1/mitglieder/jonas']!['saldoCents'] = -250;
  db.docs['kassen/k1/mitglieder/max']!['saldoCents'] = 900;

  var n = 0;
  Future<void> strich(
    String wer,
    String bierwart,
    String name,
    String sorte,
    int preis,
    DateTime zeit, {
    StrichArt art = StrichArt.offen,
  }) => db.schreiben(
    strichBatch(
      uid: bierwart,
      bierwartName: name,
      kasseId: 'k1',
      buchungId: 'b${++n}',
      art: art,
      mitgliedId: wer,
      sorteId: sorte,
      preisCents: preis,
      geraetZeit: zeit,
    ),
  );

  final samstag = DateTime(2026, 10, 17, 17, 48);
  await strich('niklas', 'jonas', 'Jonas Weber', 'weizen', 200, samstag);
  await strich(
    'niklas',
    'jonas',
    'Jonas Weber',
    'bier',
    150,
    samstag.add(const Duration(minutes: 31)),
  );
  await db.schreiben(
    zahlungBatch(
      uid: 'uid',
      bierwartName: 'Tobias Meier',
      kasseId: 'k1',
      buchungId: 'b${++n}',
      mitgliedId: 'niklas',
      betragCents: 1000,
      ortId: 'kasse',
      geraetZeit: samstag.add(const Duration(minutes: 52)),
    ),
  );
  final dienstag = DateTime(2026, 10, 20, 21, 5);
  await strich('niklas', 'max', 'Max Becker', 'radler', 150, dienstag);
  await strich('niklas', 'uid', 'Tobias Meier', 'bier', 150, dienstag);
  await strich('tim', 'uid', 'Tobias Meier', 'weizen', 200, dienstag);
  await db.schreiben(
    zahlungBatch(
      uid: 'max',
      bierwartName: 'Max Becker',
      kasseId: 'k1',
      buchungId: 'b${++n}',
      mitgliedId: 'felix',
      betragCents: 2000,
      ortId: 'max',
      geraetZeit: DateTime(2026, 10, 20, 21, 40),
    ),
  );
  final heute = DateTime(2026, 10, 22, 21, 12);
  await strich('lukas', 'jonas', 'Jonas Weber', 'radler', 150, heute);
  await strich('paul', 'uid', 'Tobias Meier', 'bier', 150, heute);
  await strich(
    'gaeste',
    'uid',
    'Tobias Meier',
    'bier',
    150,
    heute,
    art: StrichArt.bar,
  );
  await strich(
    'niklas',
    'uid',
    'Tobias Meier',
    'bier',
    150,
    heute.add(const Duration(minutes: 9)),
  );
  db.batches.clear();
  return db;
}

Future<void> starten(WidgetTester tester) async {
  storeTelefon(tester);
  await tester.runAsync(_schriftenLaden);
  await appStarten(
    tester,
    kasseId: 'k1',
    db: await demoKasse(),
    fonts: BwFonts.barlow,
  );
}

Future<void> tippen(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> aufnehmen(String name) async {
  await expectLater(
    find.byType(UncontrolledProviderScope),
    matchesGoldenFile('../../docs/store/screenshots/$name.png'),
  );
}

void main() {
  // Die Bilder sind kein Vergleich, sondern das Ergebnis: immer neu schreiben.
  setUpAll(() => autoUpdateGoldenFiles = _aktualisieren);

  testWidgets('01 Strichliste', (tester) async {
    await starten(tester);
    await aufnehmen('01-strichliste');
  }, skip: !_aktualisieren);

  testWidgets('02 Kader', (tester) async {
    await starten(tester);
    await tippen(tester, 'KADER');
    await aufnehmen('02-kader');
  }, skip: !_aktualisieren);

  testWidgets('03 Lager', (tester) async {
    await starten(tester);
    await tippen(tester, 'LAGER');
    await aufnehmen('03-lager');
  }, skip: !_aktualisieren);

  testWidgets('04 Geld', (tester) async {
    await starten(tester);
    await tippen(tester, 'GELD');
    await aufnehmen('04-geld');
  }, skip: !_aktualisieren);

  testWidgets('05 Mitglied', (tester) async {
    await starten(tester);
    await tippen(tester, 'KADER');
    await tippen(tester, 'Niklas Hahn');
    await aufnehmen('05-mitglied');
  }, skip: !_aktualisieren);

  testWidgets('06 Verlauf', (tester) async {
    await starten(tester);
    await tippen(tester, 'GELD');
    await tester.scrollUntilVisible(
      find.text('VERLAUF ANSEHEN →'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('VERLAUF ANSEHEN →'));
    await tester.pumpAndSettle();
    await tippen(tester, 'VERLAUF ANSEHEN →');
    await aufnehmen('06-verlauf');
  }, skip: !_aktualisieren);
}
