import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/einstellungen/data/verwaltung_batches.dart';
import 'package:bier_wart/src/features/einstellungen/domain/bierwart.dart';
import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
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

/// Wiederherstellungscode aus kasse-erstellen.json und sein Hash.
const alterWCode = 'ABCD1234EFGH5678';
const wiederherstellungHex =
    'be105af532593b07b857dbbb0012fc12a939efb515656aa111fc0120993c0609';
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

  group('Vertrag: Austreten und Auflösen', () {
    test('Jonas tritt aus (UC-05, AUTH-09)', () {
      vertragPruefen(
        'austreten.json',
        batchAlsJson(
          'neu',
          austretenBatch(
            uid: 'neu',
            bierwartName: 'Jonas Weber',
            kasseId: 'k2',
            buchungId: 'v4',
            mitgliedId: 'm2',
            einladungCode: alterCode,
            letzter: false,
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('die Gründerin geht als letzte, mit ihren Rollen (AUTH-10)', () {
      vertragPruefen(
        'austreten-letzter.json',
        batchAlsJson(
          uid,
          austretenBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            buchungId: 'v5',
            mitgliedId: 'm1',
            einladungCode: alterCode,
            letzter: true,
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('Auflösen (ADM-05)', () {
      vertragPruefen(
        'aufloesen.json',
        batchAlsJson(
          uid,
          aufloesenBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            buchungId: 'v6',
            bestaetigung: 'SV Neu',
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('eine volle Portion löschen', () {
      vertragPruefen(
        'loeschen-portion.json',
        batchAlsJson(
          uid,
          loeschBatch([
            for (var i = 0; i < loeschPortion; i++)
              'kassen/k2/buchungen/x${i.toString().padLeft(3, '0')}',
          ]),
        ),
      );
    });

    test('zum Schluss Kasse, Einladung, Wiederherstellung, users', () {
      vertragPruefen(
        'aufloesen-schluss.json',
        batchAlsJson(
          uid,
          aufloesenSchlussBatch(
            uid: uid,
            kasseId: 'k2',
            einladungCode: alterCode,
            wiederherstellungHex: wiederherstellungHex,
          ),
        ),
      );
    });
  });

  group('Vertrag: Wiederherstellungscode', () {
    const neuerWCode = 'N3W7C0DE4X5Y6Z8A';

    test('Code erneuern (ADM-08)', () {
      vertragPruefen(
        'code-erneuern.json',
        batchAlsJson(
          uid,
          codeErneuernBatch(
            uid: uid,
            bierwartName: bierwart,
            kasseId: 'k2',
            buchungId: 'v7',
            neuerHash: hashVon(neuerWCode),
            altHex: wiederherstellungHex,
            geraetZeit: zeit,
          ),
        ),
      );
    });

    test('Jonas wird mit dem Code Admin (ADM-06)', () {
      vertragPruefen(
        'admin-wiederherstellen.json',
        batchAlsJson(
          'neu',
          adminWiederherstellenBatch(
            uid: 'neu',
            bierwartName: 'Jonas Weber',
            kasseId: 'k2',
            buchungId: 'v8',
            nachweis: alterWCode,
            neuerHash: hashVon(neuerWCode),
            kassenwartUid: uid,
            geraetZeit: zeit,
          ),
        ),
      );
    });
  });

  test('der Hash der Fixture gehört zum alten Code', () {
    expect(hexVon(hashVon(alterWCode)), wiederherstellungHex);
  });

  test('nur wer als letzter geht, setzt leerSeit', () {
    List<Schreibvorgang> gehen({required bool letzter}) => austretenBatch(
      uid: 'neu',
      bierwartName: 'Jonas Weber',
      kasseId: 'k2',
      buchungId: 'v4',
      mitgliedId: 'm2',
      einladungCode: alterCode,
      letzter: letzter,
      geraetZeit: zeit,
    );
    Map<String, Object?> kasse(List<Schreibvorgang> b) =>
        b.firstWhere((s) => s.pfad == 'kassen/k2').daten;
    expect(kasse(gehen(letzter: true))['leerSeit'], isA<Serverzeit>());
    expect(kasse(gehen(letzter: false)).containsKey('leerSeit'), isFalse);
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
