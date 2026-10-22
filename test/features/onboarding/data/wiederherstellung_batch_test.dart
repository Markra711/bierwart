import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/onboarding/data/wiederherstellung_batches.dart';
import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
import 'package:bier_wart/src/features/onboarding/domain/wiederherstellung.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

// Fortsetzung der Kette auf Kasse k2 (kasse-erstellen.json, beitreten.json):
// Lena Koch (UID gruender, Mitglied m1) ist Admin und Kassenwart, Jonas
// Weber (UID neu, Mitglied m2) Bierwart. Ein neues Gerät „zurueck“ kennt
// nur den Wiederherstellungscode.
const uid = 'zurueck';
const code = 'ABCD1234EFGH5678';
const neuerCode = 'N3W7C0DE4X5Y6Z8A';
final zeit = DateTime(2026, 10, 22);

const lena = Kandidat(
  mitgliedId: 'm1',
  name: 'Lena Koch',
  bierwartUid: 'gruender',
);
const jonas = Kandidat(
  mitgliedId: 'm2',
  name: 'Jonas Weber',
  bierwartUid: 'neu',
);

const stand = WiederherstellungsStand(
  kasseId: 'k2',
  kassenName: 'SV Neu',
  adminUid: 'gruender',
  kassenwartUid: 'gruender',
  einladungCode: 'K7Q2MXA93DWFT2HC8RNP',
  kandidaten: [lena, jonas],
  aktiveBierwarte: {'gruender', 'neu'},
  orte: {'kasse', 'gruender', 'neu'},
  namenKeys: {'lena koch', 'jonas weber', 'gäste'},
);

List<Schreibvorgang> wiederherstellen({Kandidat? als, String? name}) =>
    wiederherstellenBatch(
      uid: uid,
      stand: stand,
      buchungId: 'w1',
      nachweis: code,
      neuerHash: hashVon(neuerCode),
      neueMitgliedId: 'm9',
      kandidat: als,
      neuerName: name,
      geraetZeit: zeit,
    );

Map<String, Object?> kasse(List<Schreibvorgang> b) =>
    b.firstWhere((s) => s.pfad == 'kassen/k2').daten;

void main() {
  group('Vertrag mit den Rules', () {
    test('Nachweis (ADR-0010)', () {
      vertragPruefen(
        'nachweis.json',
        batchAlsJson(
          uid,
          nachweisBatch(uid: uid, kasseId: 'k2', nachweis: code),
        ),
      );
    });

    test('als Lena zurück: Rollen und Mitgliedschaft gehen über (UC-03)', () {
      vertragPruefen(
        'wiederherstellen-mitglied.json',
        batchAlsJson(uid, wiederherstellen(als: lena)),
      );
    });

    test('als neues Mitglied: Admin, Kassenwart bleibt (UC-04)', () {
      vertragPruefen(
        'wiederherstellen-neu.json',
        batchAlsJson(uid, wiederherstellen(name: 'Paula Neu')),
      );
    });
  });

  test(
    'übernimmt Lena: Kassenwart geht mit, alter Zugang weg, Anzahl gleich',
    () {
      final b = wiederherstellen(als: lena);
      expect(kasse(b)['kassenwartUid'], uid);
      expect(kasse(b).containsKey('anzahlBierwarte'), isFalse);
      expect(
        b.any(
          (s) =>
              s.pfad == 'kassen/k2/bierwarte/gruender' && s.art == Art.delete,
        ),
        isTrue,
      );
      expect(
        b
            .firstWhere((s) => s.pfad == 'kassen/k2/orte/gruender')
            .daten['ehemalig'],
        isTrue,
      );
      expect(b.any((s) => s.pfad.startsWith('einladungen/')), isFalse);
    },
  );

  test('neues Mitglied: Kassenwart bleibt, Anzahl und Einladung steigen', () {
    final b = wiederherstellen(name: '  Paula  Neu ');
    expect(kasse(b)['kassenwartUid'], 'gruender');
    expect((kasse(b)['anzahlBierwarte']! as Erhoehen).um, 1);
    expect(
      b.firstWhere((s) => s.pfad == 'kassen/k2/mitglieder/m9').daten['name'],
      'Paula Neu',
    );
    expect(b.any((s) => s.pfad == 'kassen/k2/namen/paula neu'), isTrue);
  });

  test('der Code wechselt, der Nachweis geht', () {
    final b = wiederherstellen(als: jonas);
    final pfade = {for (final s in b) s.pfad: s.art};
    expect(pfade['wiederherstellung/${hexVon(hashVon(code))}'], Art.delete);
    expect(pfade['wiederherstellung/${hexVon(hashVon(neuerCode))}'], Art.set);
    expect(pfade['kassen/k2/wiederherstellungen/$uid'], Art.delete);
  });
}
