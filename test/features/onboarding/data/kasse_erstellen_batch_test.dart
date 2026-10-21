import 'package:bier_wart/src/features/onboarding/data/kasse_erstellen_batch.dart';
import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

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

  test('entspricht dem Vertrag mit den Rules', () {
    vertragPruefen('kasse-erstellen.json', batchAlsJson('gruender', batch));
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
