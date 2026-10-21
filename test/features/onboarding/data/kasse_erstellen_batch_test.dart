import 'dart:convert';
import 'dart:io';

import 'package:bier_wart/src/features/onboarding/data/kasse_erstellen_batch.dart';
import 'package:bier_wart/src/features/onboarding/data/schreibvorgang.dart';
import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
import 'package:flutter_test/flutter_test.dart';

// Vertrag mit den Rules: Der Batch muss rules-tests/fixtures/ entsprechen,
// und rules-tests/vertrag.test.js spielt genau diese Datei gegen den
// Emulator ab. Neu schreiben mit:
//   FIXTURES_AKTUALISIEREN=1 flutter test test/features/onboarding/data
const fixture = 'rules-tests/fixtures/kasse-erstellen.json';

Object? alsJson(Object? wert) => switch (wert) {
  Serverzeit() => {r'$serverzeit': true},
  Bytes(:final wert) => {r'$bytes': hexVon(wert)},
  DateTime() => {r'$geraetzeit': true},
  Map() => {for (final e in wert.entries) e.key as String: alsJson(e.value)},
  _ => wert,
};

void main() {
  final batch = kasseErstellenBatch(
    uid: 'gruender',
    kasseId: 'k2',
    mitgliedId: 'm1',
    buchungId: 'l1',
    kassenName: '  SV Neu ',
    eigenerName: 'Lena   Koch',
    startCents: 5000,
    einladungscode: 'K7Q2MXA93DWFT2HC8RNP',
    wiederherstellungsHash: hashVon('ABCD1234EFGH5678'),
    geraetZeit: DateTime(2026, 10, 21),
  );
  final json = const JsonEncoder.withIndent('  ').convert({
    'uid': 'gruender',
    'schreibvorgaenge': [
      for (final s in batch) {'pfad': s.pfad, 'daten': alsJson(s.daten)},
    ],
  });

  test('entspricht dem Vertrag mit den Rules', () {
    final datei = File(fixture);
    if (Platform.environment['FIXTURES_AKTUALISIEREN'] == '1') {
      datei.writeAsStringSync('$json\n');
    }
    expect(json, datei.readAsStringSync().trim());
  });

  test('Namen werden bereinigt gespeichert', () {
    final kasse = batch.first.daten;
    expect(kasse['name'], 'SV Neu');
    final mitglied = batch.firstWhere((s) => s.pfad.endsWith('/m1')).daten;
    expect(mitglied['name'], 'Lena Koch');
    expect(batch.any((s) => s.pfad == 'kassen/k2/namen/lena koch'), isTrue);
  });

  test('„Gäste“ entsteht mit der Kasse (KAD-03)', () {
    final gaeste = batch.firstWhere((s) => s.pfad.endsWith('/$gaesteId')).daten;
    expect(gaeste['istGast'], isTrue);
    expect(gaeste['bierwartUid'], isNull);
  });
}
