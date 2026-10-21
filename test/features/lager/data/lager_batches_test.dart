import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/lager/data/lager_batches.dart';
import 'package:bier_wart/src/features/lager/domain/sorte.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

// Fortsetzung der Kette auf Kasse k2 (kasse-erstellen.json): Gründerin
// „Lena Koch“ (UID gruender, Admin und Kassenwart), Sorte s1 „Bier 0,5“ zu
// 1,50 € mit Bestand 0 (sorte-anlegen.json).
const uid = 'gruender';
const bierwart = 'Lena Koch';
final zeit = DateTime(2026, 10, 21);
const bier = Sorte(
  id: 's1',
  name: 'Bier 0,5',
  preisCents: 150,
  bestand: 0,
  reihenfolge: 0,
);

List<Schreibvorgang> einkauf(String id, String ortId) => einkaufBatch(
  uid: uid,
  bierwartName: bierwart,
  kasseId: 'k2',
  buchungId: id,
  zeilen: const {'s1': 24},
  betragCents: 1890,
  ortId: ortId,
  geraetZeit: zeit,
);

List<Schreibvorgang> aendern(String id, {int preis = 150, bool aktiv = true}) =>
    sorteAendernBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      buchungId: id,
      sorte: bier,
      name: 'Bier 0,5',
      preisCents: preis,
      aktiv: aktiv,
      geraetZeit: zeit,
    );

List<Schreibvorgang> korrektur(String id, {required int differenz}) =>
    bestandKorrekturBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      buchungId: id,
      sorteId: 's1',
      gezaehlt: 24,
      differenz: differenz,
      geraetZeit: zeit,
    );

void main() {
  group('Vertrag mit den Rules', () {
    test('Einkauf aus dem eigenen Portemonnaie (BES-04, BES-05)', () {
      vertragPruefen('einkauf.json', batchAlsJson(uid, einkauf('e1', uid)));
    });

    test('Einkauf aus der Kasse als Kassenwart (BES-05)', () {
      vertragPruefen(
        'einkauf-kasse.json',
        batchAlsJson(uid, einkauf('e2', 'kasse')),
      );
    });

    test('Preis ändern (BES-01, BES-02)', () {
      vertragPruefen(
        'sorte-aendern.json',
        batchAlsJson(uid, aendern('l9', preis: 170)),
      );
    });

    test('Sorte ausblenden (BES-01)', () {
      vertragPruefen(
        'sorte-ausblenden.json',
        batchAlsJson(uid, aendern('l10', aktiv: false)),
      );
    });

    test('Bestand korrigieren (BES-06)', () {
      vertragPruefen(
        'bestand-korrektur.json',
        batchAlsJson(uid, korrektur('k1', differenz: 24)),
      );
    });
  });

  test('neuer Preis schiebt den alten nach vorherigerPreisCents (BES-02)', () {
    final sorte = aendern('l9', preis: 170).first.daten;
    expect(sorte['vorherigerPreisCents'], 150);
    final gleich = aendern('l9').first.daten;
    expect(gleich['vorherigerPreisCents'], isNull);
  });

  test('Korrektur setzt den Bestand absolut, ohne increment', () {
    final sorte = korrektur('k1', differenz: 24).last.daten;
    expect(sorte['bestand'], 24);
  });
}
