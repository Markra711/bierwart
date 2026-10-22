import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/geld/data/zahlung_batch.dart';
import 'package:bier_wart/src/features/kader/data/mitglied_batches.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

// Fortsetzung der Kette aus strich_batches_test.dart auf Kasse k2:
// Gründerin „Lena Koch“ (UID gruender, Mitglied m1, Admin und Kassenwart),
// Tim Richter (m3) mit einem Strich zu 1,50 €.
const uid = 'gruender';
const bierwart = 'Lena Koch';
final zeit = DateTime(2026, 10, 21);

List<Schreibvorgang> zahlung(String id, String ortId) => zahlungBatch(
  uid: uid,
  bierwartName: bierwart,
  kasseId: 'k2',
  buchungId: id,
  mitgliedId: 'm3',
  betragCents: 150,
  ortId: ortId,
  geraetZeit: zeit,
);

List<Schreibvorgang> entfernen(String id, {required bool entfernen}) =>
    mitgliedEntfernenBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      mitgliedId: 'm3',
      buchungId: id,
      entfernen: entfernen,
      geraetZeit: zeit,
    );

void main() {
  group('Vertrag mit den Rules', () {
    test('Zahlung ins eigene Portemonnaie (GEL-02, GEL-03)', () {
      vertragPruefen('zahlung.json', batchAlsJson(uid, zahlung('z1', uid)));
    });

    test('Zahlung stornieren (offene Frage 24)', () {
      vertragPruefen(
        'zahlung-storno.json',
        batchAlsJson(
          uid,
          zahlungStornoBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            zahlungId: 'z1',
            mitgliedId: 'm3',
            betragCents: 150,
            ortId: uid,
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('Zahlung in die Kasse als Kassenwart (GEL-03)', () {
      vertragPruefen(
        'zahlung-kasse.json',
        batchAlsJson(uid, zahlung('z2', 'kasse')),
      );
    });

    test('Mitglied entfernen (KAD-04)', () {
      vertragPruefen(
        'mitglied-entfernen.json',
        batchAlsJson(uid, entfernen('l5', entfernen: true)),
      );
    });

    test('Mitglied wieder aufnehmen (KAD-08)', () {
      vertragPruefen(
        'mitglied-wiederaufnehmen.json',
        batchAlsJson(uid, entfernen('l6', entfernen: false)),
      );
    });

    test('Mitglied ohne App umbenennen (KAD-01, UI-09)', () {
      vertragPruefen(
        'mitglied-umbenennen.json',
        batchAlsJson(
          uid,
          mitgliedUmbenennenBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            mitgliedId: 'm3',
            buchungId: 'l7',
            nameAlt: 'Tim Richter',
            nameNeu: ' Tim  Richter-Berg',
            bierwartUid: null,
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('Bierwart umbenennen: Stempel-Name zieht mit (UI-09)', () {
      vertragPruefen(
        'bierwart-umbenennen.json',
        batchAlsJson(
          uid,
          mitgliedUmbenennenBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            mitgliedId: 'm1',
            buchungId: 'l8',
            nameAlt: 'Lena Koch',
            nameNeu: 'Lena Koch-Meier',
            bierwartUid: uid,
            geraetZeit: zeit,
          ),
        ),
      );
    });
  });

  test('Zahlung senkt den Saldo und füllt den Ort', () {
    final b = zahlung('z1', uid);
    final saldo = b.firstWhere((s) => s.pfad.endsWith('/m3')).daten;
    final ort = b.firstWhere((s) => s.pfad.endsWith('/orte/$uid')).daten;
    expect((saldo['saldoCents']! as Erhoehen).um, -150);
    expect((ort['standCents']! as Erhoehen).um, 150);
  });

  test('Umbenennen gibt den alten Namen frei', () {
    final b = mitgliedUmbenennenBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      mitgliedId: 'm3',
      buchungId: 'l7',
      nameAlt: 'Tim Richter',
      nameNeu: 'Tim Berg',
      bierwartUid: null,
      geraetZeit: zeit,
    );
    final loeschen = b.where((s) => s.art == Art.delete).single;
    expect(loeschen.pfad, 'kassen/k2/namen/tim richter');
  });
}
