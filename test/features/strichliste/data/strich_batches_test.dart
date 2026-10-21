import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/kader/data/mitglied_batches.dart';
import 'package:bier_wart/src/features/kader/domain/mitglied.dart';
import 'package:bier_wart/src/features/lager/data/sorte_batches.dart';
import 'package:bier_wart/src/features/lager/domain/sorte.dart';
import 'package:bier_wart/src/features/strichliste/data/strich_batches.dart';
import 'package:bier_wart/src/features/strichliste/domain/strich.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

// Eine Kette auf der Kasse aus kasse-erstellen.json (Gründerin „Lena Koch“,
// UID gruender), die vertrag.test.js in dieser Reihenfolge abspielt.
const uid = 'gruender';
const bierwart = 'Lena Koch';
final zeit = DateTime(2026, 10, 21);

const sorte = Sorte(
  id: 's1',
  name: 'Bier 0,5',
  preisCents: 150,
  bestand: 0,
  reihenfolge: 0,
);
const tim = Mitglied(id: 'm3', name: 'Tim Richter', saldoCents: 0);
const gaeste = Mitglied(
  id: 'gaeste',
  name: 'Gäste',
  saldoCents: 0,
  istGast: true,
);

List<Schreibvorgang> strich(String id, StrichArt art, Mitglied m) =>
    strichBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      buchungId: id,
      art: art,
      mitgliedId: m.id,
      sorteId: sorte.id,
      preisCents: sorte.preisCents,
      geraetZeit: zeit,
    );

List<Schreibvorgang> storno(String id, StrichArt art, Mitglied m) =>
    stornoBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      strich: Strich(
        buchungId: id,
        art: art,
        mitglied: m,
        sorte: sorte,
        preisCents: sorte.preisCents,
      ),
      geraetZeit: zeit,
    );

void main() {
  group('Vertrag mit den Rules', () {
    test('Sorte anlegen (BES-01)', () {
      vertragPruefen(
        'sorte-anlegen.json',
        batchAlsJson(
          uid,
          sorteAnlegenBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            sorteId: 's1',
            buchungId: 'l3',
            name: ' Bier  0,5',
            preisCents: 150,
            reihenfolge: 0,
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('Mitglied anlegen (KAD-01)', () {
      vertragPruefen(
        'mitglied-anlegen.json',
        batchAlsJson(
          uid,
          mitgliedAnlegenBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            mitgliedId: 'm3',
            buchungId: 'l4',
            name: 'Tim  Richter ',
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('Strich offen (STR-02)', () {
      vertragPruefen(
        'strich.json',
        batchAlsJson(uid, strich('b1', StrichArt.offen, tim)),
      );
    });

    test('Storno eines offenen Strichs (STR-04)', () {
      vertragPruefen(
        'storno-strich.json',
        batchAlsJson(uid, storno('b1', StrichArt.offen, tim)),
      );
    });

    test('Strich bar auf „Gäste“ (STR-03, KAD-03)', () {
      vertragPruefen(
        'strich-bar.json',
        batchAlsJson(uid, strich('b2', StrichArt.bar, gaeste)),
      );
    });

    test('Storno eines Bar-Strichs (STR-04)', () {
      vertragPruefen(
        'storno-bar.json',
        batchAlsJson(uid, storno('b2', StrichArt.bar, gaeste)),
      );
    });
  });

  test('offen ändert den Saldo, bar das eigene Portemonnaie', () {
    final offen = strich('b1', StrichArt.offen, tim).map((s) => s.pfad);
    final bar = strich('b2', StrichArt.bar, gaeste).map((s) => s.pfad);
    expect(offen, contains('kassen/k2/mitglieder/m3'));
    expect(offen, isNot(contains('kassen/k2/orte/$uid')));
    expect(bar, contains('kassen/k2/orte/$uid'));
    expect(bar, isNot(contains('kassen/k2/mitglieder/gaeste')));
  });

  test('Storno hat die feste ID storno-{bezugId} (STR-06)', () {
    expect(
      storno('b1', StrichArt.offen, tim).first.pfad,
      'kassen/k2/buchungen/storno-b1',
    );
  });

  test('Storno hebt die Wirkung genau auf', () {
    int summe(List<Schreibvorgang> b, String feld) => b
        .map((s) => s.daten[feld])
        .whereType<Erhoehen>()
        .fold(0, (a, e) => a + e.um);
    final hin = strich('b1', StrichArt.offen, tim);
    final zurueck = storno('b1', StrichArt.offen, tim);
    expect(summe(hin, 'saldoCents') + summe(zurueck, 'saldoCents'), 0);
    expect(summe(hin, 'bestand') + summe(zurueck, 'bestand'), 0);
  });
}
