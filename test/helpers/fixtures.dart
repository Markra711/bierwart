import 'dart:convert';
import 'dart:io';

import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
import 'package:flutter_test/flutter_test.dart';

// Vertrag mit den Rules: Ein Batch muss seiner Datei in rules-tests/fixtures/
// entsprechen, und rules-tests/vertrag.test.js spielt genau diese Datei gegen
// den Emulator ab. Neu schreiben mit:
//   FIXTURES_AKTUALISIEREN=1 flutter test

Object? alsJson(Object? wert) => switch (wert) {
  Serverzeit() => {r'$serverzeit': true},
  Erhoehen(:final um) => {r'$erhoehen': um},
  Bytes(:final wert) => {r'$bytes': hexVon(wert)},
  DateTime() => {r'$geraetzeit': true},
  Map() => {for (final e in wert.entries) e.key as String: alsJson(e.value)},
  _ => wert,
};

String batchAlsJson(String uid, List<Schreibvorgang> batch) =>
    const JsonEncoder.withIndent('  ').convert({
      'uid': uid,
      'schreibvorgaenge': [
        for (final s in batch)
          {'art': s.art.name, 'pfad': s.pfad, 'daten': alsJson(s.daten)},
      ],
    });

/// Vergleicht [json] mit `rules-tests/fixtures/[name]`; schreibt die Datei
/// neu, wenn `FIXTURES_AKTUALISIEREN=1` gesetzt ist.
void vertragPruefen(String name, String json) {
  final datei = File('rules-tests/fixtures/$name');
  if (Platform.environment['FIXTURES_AKTUALISIEREN'] == '1') {
    datei.writeAsStringSync('$json\n');
  }
  expect(json, datei.readAsStringSync().trim());
}
