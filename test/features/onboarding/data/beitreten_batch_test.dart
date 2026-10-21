import 'package:bier_wart/src/features/onboarding/data/beitreten_batch.dart';
import 'package:bier_wart/src/features/onboarding/data/schreibvorgang.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

void main() {
  // Tritt der Kasse aus kasse-erstellen.json bei (gleiche Kasse, gleicher
  // Code), damit vertrag.test.js beide nacheinander abspielen kann.
  final batch = beitretenBatch(
    uid: 'neu',
    kasseId: 'k2',
    einladungscode: 'K7Q2MXA93DWFT2HC8RNP',
    mitgliedId: 'm2',
    buchungId: 'l2',
    eigenerName: ' Jonas  Weber',
    geraetZeit: DateTime(2026, 10, 21),
  );

  test('entspricht dem Vertrag mit den Rules', () {
    vertragPruefen('beitreten.json', batchAlsJson('neu', batch));
  });

  test(
    'Anzahl zählt auf dem Server hoch, in Kasse und Einladung (AUTH-05)',
    () {
      final updates = batch.where((s) => s.art == Art.update).toList();
      expect(updates.map((s) => s.pfad), [
        'kassen/k2',
        'einladungen/K7Q2MXA93DWFT2HC8RNP',
      ]);
      for (final s in updates) {
        expect((s.daten['anzahlBierwarte']! as Erhoehen).um, 1);
      }
    },
  );

  test('Name bereinigt, Index mit Schlüssel (AUTH-07)', () {
    final mitglied = batch.firstWhere((s) => s.pfad.endsWith('/m2')).daten;
    expect(mitglied['name'], 'Jonas Weber');
    expect(batch.any((s) => s.pfad == 'kassen/k2/namen/jonas weber'), isTrue);
  });
}
