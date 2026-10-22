import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/einstellungen/data/verwaltung_batches.dart';
import 'package:bier_wart/src/features/einstellungen/domain/bierwart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

// Fortsetzung der Kette auf Kasse k2 (kasse-erstellen.json, beitreten.json):
// Gründerin „Lena Koch“ (UID gruender, Admin und Kassenwart), Kasse „SV Neu“
// mit Link K7Q2MXA93DWFT2HC8RNP, „Jonas Weber“ (UID neu, Mitglied m2);
// zwei Bierwarte.
const uid = 'gruender';
const bierwart = 'Lena Koch';
const alterCode = 'K7Q2MXA93DWFT2HC8RNP';
const neuerCode = 'N3W7C0DE4X5Y6Z8A9B1C';
final zeit = DateTime(2026, 10, 22);
const jonas = Bierwart(uid: 'neu', name: 'Jonas Weber', mitgliedId: 'm2');

List<Schreibvorgang> rolle(Rolle r) => rolleBatch(
  uid: uid,
  bierwartName: bierwart,
  kasseId: 'k2',
  buchungId: 'v-${r.name}',
  rolle: r,
  vonUid: uid,
  nachUid: 'neu',
  geraetZeit: zeit,
);

void main() {
  group('Vertrag mit den Rules', () {
    test('Link erneuern (ADM-01)', () {
      vertragPruefen(
        'link-erneuern.json',
        batchAlsJson(
          uid,
          linkErneuernBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            buchungId: 'v1',
            alterCode: alterCode,
            neuerCode: neuerCode,
            kassenName: 'SV Neu',
            anzahlBierwarte: 2,
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('Bierwart entfernen (ADM-02)', () {
      vertragPruefen(
        'bierwart-entfernen.json',
        batchAlsJson(
          uid,
          bierwartEntfernenBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            buchungId: 'v2',
            wer: jonas,
            alterCode: alterCode,
            neuerCode: neuerCode,
            kassenName: 'SV Neu',
            anzahlBierwarte: 2,
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('Kassenwart bestimmen (ADM-03)', () {
      vertragPruefen(
        'rolle-kassenwart.json',
        batchAlsJson(uid, rolle(Rolle.kassenwart)),
      );
    });

    test('Admin-Rolle übergeben (ADM-03)', () {
      vertragPruefen('rolle-admin.json', batchAlsJson(uid, rolle(Rolle.admin)));
    });

    test('Kasse umbenennen (ADM-04)', () {
      vertragPruefen(
        'kasse-umbenennen.json',
        batchAlsJson(
          uid,
          kasseUmbenennenBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            buchungId: 'v3',
            nameAlt: 'SV Neu',
            nameNeu: 'SV Umbenannt',
            einladungCode: alterCode,
            geraetZeit: zeit,
          ),
        ),
      );
    });
  });

  test('Entfernen setzt die neue Einladung auf die Anzahl danach', () {
    final b = bierwartEntfernenBatch(
      uid: uid,
      bierwartName: bierwart,
      kasseId: 'k2',
      buchungId: 'v2',
      wer: jonas,
      alterCode: alterCode,
      neuerCode: neuerCode,
      kassenName: 'SV Neu',
      anzahlBierwarte: 2,
      geraetZeit: zeit,
    );
    final einladung = b.firstWhere((s) => s.pfad == 'einladungen/$neuerCode');
    expect(einladung.daten['anzahlBierwarte'], 1);
    expect(b.first.art, Art.delete);
  });

  test('Rolle schreibt das passende Feld der Kasse', () {
    expect(rolle(Rolle.admin).first.daten, containsPair('adminUid', 'neu'));
    expect(
      rolle(Rolle.kassenwart).first.daten,
      containsPair('kassenwartUid', 'neu'),
    );
  });
}
