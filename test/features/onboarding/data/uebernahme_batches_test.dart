import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/onboarding/data/uebernahme_batches.dart';
import 'package:bier_wart/src/features/onboarding/domain/uebernahme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

// Die Kette in vertrag.test.js: kasse-erstellen (Lena Koch, Admin und
// Kassenwart), sorte-anlegen, mitglied-anlegen (Tim Richter), strich,
// zahlung (1,50 € in Lenas Portemonnaie), beitreten (Jonas Weber, UID „neu“).
const _code = 'K7Q2MXA93DWFT2HC8RNP';
final _zeit = DateTime(2026, 11, 5, 20);

Uebernahme _anfrage(String id, String mitgliedId, String neueUid) => Uebernahme(
  id: id,
  kasseId: 'k2',
  mitgliedId: mitgliedId,
  neueUid: neueUid,
  einladungCode: _code,
  status: UebernahmeStatus.offen,
  angefragtAm: _zeit,
);

/// Lena kommt mit einem neuen Handy („handy2“) zurück.
final _lena = UebernahmeStand(
  anfrage: _anfrage('a1', 'm1', 'handy2'),
  mitgliedName: 'Lena Koch',
  alteUid: 'gruender',
  alteAktiv: true,
  altesPortemonnaieCents: 150,
  adminUid: 'gruender',
  kassenwartUid: 'gruender',
  einladungCode: _code,
);

/// Tim hatte noch keine App und steigt mit „handy3“ ein.
final _tim = UebernahmeStand(
  anfrage: _anfrage('a2', 'm3', 'handy3'),
  mitgliedName: 'Tim Richter',
  alteUid: null,
  alteAktiv: false,
  altesPortemonnaieCents: null,
  adminUid: 'gruender',
  kassenwartUid: 'gruender',
  einladungCode: _code,
);

List<Schreibvorgang> _bestaetigen(
  UebernahmeStand stand, {
  String uid = 'neu',
  String name = 'Jonas Weber',
  String buchungId = 'u2',
}) => uebernahmeBestaetigenBatch(
  uid: uid,
  bierwartName: name,
  kasseId: 'k2',
  stand: stand,
  buchungId: buchungId,
  geraetZeit: _zeit,
);

Map<String, Object?> _daten(List<Schreibvorgang> batch, String pfad) =>
    batch.firstWhere((s) => s.pfad == pfad).daten;

void main() {
  group('entspricht dem Vertrag mit den Rules', () {
    test('anfragen mit eingetipptem Namen', () {
      vertragPruefen(
        'uebernahme-anfragen.json',
        batchAlsJson(
          'handy2',
          uebernahmeAnfragenBatch(
            uid: 'handy2',
            kasseId: 'k2',
            anfrageId: 'a1',
            buchungId: 'u1',
            mitgliedId: 'm1',
            einladungscode: _code,
            eingetippterName: ' lena  koch',
            geraetZeit: _zeit,
          ),
        ),
      );
    });

    test('zurückziehen', () {
      vertragPruefen(
        'uebernahme-zurueckziehen.json',
        batchAlsJson(
          'handy2',
          uebernahmeZurueckziehenBatch(
            uid: 'handy2',
            kasseId: 'k2',
            anfrageId: 'a1',
            buchungId: 'u2',
            mitgliedId: 'm1',
            eingetippterName: 'lena koch',
            geraetZeit: _zeit,
          ),
        ),
      );
    });

    test('ablehnen', () {
      vertragPruefen(
        'uebernahme-ablehnen.json',
        batchAlsJson(
          'neu',
          uebernahmeAblehnenBatch(
            uid: 'neu',
            bierwartName: 'Jonas Weber',
            kasseId: 'k2',
            anfrage: _lena.anfrage,
            buchungId: 'u2',
            geraetZeit: _zeit,
          ),
        ),
      );
    });

    test('bestätigen: Bierwart mit Rollen und Geld', () {
      vertragPruefen(
        'uebernahme-bestaetigen.json',
        batchAlsJson('neu', _bestaetigen(_lena)),
      );
    });

    test('abschließen auf dem neuen Gerät', () {
      vertragPruefen(
        'uebernahme-abschliessen.json',
        batchAlsJson(
          'handy2',
          uebernahmeAbschliessenBatch(uid: 'handy2', kasseId: 'k2'),
        ),
      );
    });

    test('Mitglied ohne App: anfragen und bestätigen', () {
      vertragPruefen(
        'uebernahme-mitglied-anfragen.json',
        batchAlsJson(
          'handy3',
          uebernahmeAnfragenBatch(
            uid: 'handy3',
            kasseId: 'k2',
            anfrageId: 'a2',
            buchungId: 'u3',
            mitgliedId: 'm3',
            einladungscode: _code,
            eingetippterName: 'Tim Richter',
            geraetZeit: _zeit,
          ),
        ),
      );
      vertragPruefen(
        'uebernahme-mitglied-bestaetigen.json',
        batchAlsJson(
          'gruender',
          _bestaetigen(
            _tim,
            uid: 'gruender',
            name: 'Lena Koch',
            buchungId: 'u4',
          ),
        ),
      );
    });
  });

  test('Portemonnaie zieht um: neues mit Stand, altes geht auf 0', () {
    final batch = _bestaetigen(_lena);
    expect(_daten(batch, 'kassen/k2/orte/handy2')['standCents'], 150);
    final alt = _daten(batch, 'kassen/k2/orte/gruender')['standCents'];
    expect((alt! as Erhoehen).um, -150);
    expect(_daten(batch, 'kassen/k2/orte/gruender')['ehemalig'], isTrue);
    expect(_daten(batch, 'kassen/k2/buchungen/u2')['standCents'], 150);
  });

  test('Rollen gehen mit, die alte UID verliert den Zugang', () {
    final batch = _bestaetigen(_lena);
    final kasse = _daten(batch, 'kassen/k2');
    expect(kasse['adminUid'], 'handy2');
    expect(kasse['kassenwartUid'], 'handy2');
    expect(kasse.containsKey('anzahlBierwarte'), isFalse);
    expect(
      batch.any(
        (s) => s.art == Art.delete && s.pfad == 'kassen/k2/bierwarte/gruender',
      ),
      isTrue,
    );
  });

  test(
    'ohne Rollen bleibt die Kasse unberührt, Portemonnaie wird ehemalig',
    () {
      final jonas = UebernahmeStand(
        anfrage: _anfrage('a3', 'm2', 'handy4'),
        mitgliedName: 'Jonas Weber',
        alteUid: 'neu',
        alteAktiv: true,
        altesPortemonnaieCents: 0,
        adminUid: 'gruender',
        kassenwartUid: 'gruender',
        einladungCode: _code,
      );
      final batch = _bestaetigen(jonas, uid: 'gruender', name: 'Lena Koch');
      expect(batch.any((s) => s.pfad == 'kassen/k2'), isFalse);
      // Auch bei Stand 0 wird das alte Portemonnaie ehemalig, ohne Betrag.
      expect(_daten(batch, 'kassen/k2/orte/neu'), {
        'ehemalig': true,
        'letzteBuchungId': 'u2',
      });
    },
  );

  test('Mitglied ohne App zählt als neuer Bierwart mit (AUTH-05)', () {
    final batch = _bestaetigen(_tim, uid: 'gruender', name: 'Lena Koch');
    expect((_daten(batch, 'kassen/k2')['anzahlBierwarte']! as Erhoehen).um, 1);
    expect(
      (_daten(batch, 'einladungen/$_code')['anzahlBierwarte']! as Erhoehen).um,
      1,
    );
    expect(_daten(batch, 'kassen/k2/orte/handy3')['standCents'], 0);
    expect(_daten(batch, 'kassen/k2/mitglieder/m3')['entfernt'], isFalse);
  });

  test('Anfrage stempelt den bereinigten, eingetippten Namen', () {
    final batch = uebernahmeAnfragenBatch(
      uid: 'handy2',
      kasseId: 'k2',
      anfrageId: 'a1',
      buchungId: 'u1',
      mitgliedId: 'm1',
      einladungscode: _code,
      eingetippterName: ' lena  koch',
      geraetZeit: _zeit,
    );
    final log = _daten(batch, 'kassen/k2/buchungen/u1');
    expect((log['stempel']! as Map)['name'], 'lena koch');
  });

  group('Uebernahme', () {
    test('gilt 7 Tage', () {
      final a = _anfrage('a1', 'm1', 'handy2');
      expect(a.istOffen(_zeit.add(const Duration(days: 6))), isTrue);
      expect(a.istAbgelaufen(_zeit.add(const Duration(days: 7))), isTrue);
    });

    test('wartende Anfrage übersteht den Gerätespeicher', () {
      const w = WartendeAnfrage(
        kasseId: 'k2',
        anfrageId: 'a1',
        mitgliedId: 'm1',
        name: 'lena koch',
        kassenName: 'SV Test',
      );
      final zurueck = WartendeAnfrage.fromJson(w.toJson())!;
      expect(zurueck.anfrageId, 'a1');
      expect(zurueck.kassenName, 'SV Test');
      expect(WartendeAnfrage.fromJson({'kasseId': 'k2'}), isNull);
    });
  });
}
