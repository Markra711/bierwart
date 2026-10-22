import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/geld/data/geld_batches.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

// Fortsetzung der Kette auf Kasse k2 (kasse-erstellen.json, beitreten.json):
// Gründerin „Lena Koch“ (UID gruender, Admin und Kassenwart), Kasse mit
// 50,00 €, „Jonas Weber“ (UID neu) mit leerem Portemonnaie.
const uid = 'gruender';
const bierwart = 'Lena Koch';
final zeit = DateTime(2026, 10, 22);

List<Schreibvorgang> uebergabe(String id, String von, String nach) =>
    uebergabeBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      buchungId: id,
      vonOrtId: von,
      nachOrtId: nach,
      betragCents: 1200,
      geraetZeit: zeit,
    );

List<Schreibvorgang> bewegung(
  String id, {
  required bool einzahlung,
  required String ortId,
}) => einAuszahlungBatch(
  uid: uid,
  bierwartName: bierwart,
  kasseId: 'k2',
  buchungId: id,
  einzahlung: einzahlung,
  ortId: ortId,
  betragCents: 2500,
  grund: einzahlung ? 'Spende' : 'Schiri bezahlt',
  geraetZeit: zeit,
);

List<Schreibvorgang> kassensturz(String id, {required int differenz}) =>
    kassensturzBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      buchungId: id,
      gezaehltCents: 4950,
      differenzCents: differenz,
      geraetZeit: zeit,
    );

void main() {
  group('Vertrag mit den Rules', () {
    test('Übergabe vom Portemonnaie in die Kasse (GEL-04)', () {
      vertragPruefen(
        'uebergabe.json',
        batchAlsJson(uid, uebergabe('g1', 'neu', 'kasse')),
      );
    });

    test('Übergabe aus der Kasse in ein Portemonnaie (GEL-04)', () {
      vertragPruefen(
        'uebergabe-aus-kasse.json',
        batchAlsJson(uid, uebergabe('g2', 'kasse', 'neu')),
      );
    });

    test('Auszahlung aus der Kasse (GEL-05)', () {
      vertragPruefen(
        'auszahlung-kasse.json',
        batchAlsJson(uid, bewegung('g3', einzahlung: false, ortId: 'kasse')),
      );
    });

    test('Einzahlung ins eigene Portemonnaie (GEL-05)', () {
      vertragPruefen(
        'einzahlung.json',
        batchAlsJson(uid, bewegung('g4', einzahlung: true, ortId: uid)),
      );
    });

    test('Kassensturz (GEL-06)', () {
      vertragPruefen(
        'kassensturz.json',
        batchAlsJson(uid, kassensturz('g5', differenz: -50)),
      );
    });
  });

  test('Übergabe: von minus, nach plus', () {
    final b = uebergabe('g1', 'neu', 'kasse');
    expect((b[1].daten['standCents']! as Erhoehen).um, -1200);
    expect((b[2].daten['standCents']! as Erhoehen).um, 1200);
  });

  test('Auszahlung senkt, Einzahlung erhöht den Ort', () {
    final aus = bewegung('g3', einzahlung: false, ortId: 'kasse');
    final ein = bewegung('g4', einzahlung: true, ortId: uid);
    expect(aus.first.daten['typ'], 'auszahlung');
    expect((aus.last.daten['standCents']! as Erhoehen).um, -2500);
    expect(ein.first.daten['typ'], 'einzahlung');
    expect((ein.last.daten['standCents']! as Erhoehen).um, 2500);
  });

  test('Kassensturz setzt die Kasse absolut, ohne increment', () {
    expect(kassensturz('g5', differenz: -50).last.daten['standCents'], 4950);
  });
}
