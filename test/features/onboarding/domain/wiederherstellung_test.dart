import 'package:bier_wart/src/features/onboarding/domain/wiederherstellung.dart';
import 'package:flutter_test/flutter_test.dart';

const admin = Kandidat(mitgliedId: 'm1', name: 'Lena Koch', bierwartUid: 'a');
const kw = Kandidat(mitgliedId: 'm2', name: 'Jonas Weber', bierwartUid: 'k');
const frueher = Kandidat(mitgliedId: 'm3', name: 'Anna Alt', bierwartUid: 'x');
const ohneApp = Kandidat(mitgliedId: 'm4', name: 'Ben Ohne');
const weg = Kandidat(mitgliedId: 'm5', name: 'Carl Weg', entfernt: true);

WiederherstellungsStand stand({Set<String> aktiv = const {'a', 'k'}}) =>
    WiederherstellungsStand(
      kasseId: 'k1',
      kassenName: 'SV',
      adminUid: 'a',
      kassenwartUid: 'k',
      einladungCode: 'c',
      kandidaten: const [weg, ohneApp, kw, frueher, admin],
      aktiveBierwarte: aktiv,
      orte: const {},
    );

void main() {
  test('Admin zuerst, entfernte zuletzt', () {
    expect(stand().sortiert.map((k) => k.name), [
      'Lena Koch',
      'Anna Alt',
      'Ben Ohne',
      'Jonas Weber',
      'Carl Weg',
    ]);
  });

  test('Beschreibung nach Rolle und Lage', () {
    final s = stand();
    expect(s.beschreibung(admin), 'Admin · Bierwart');
    expect(s.beschreibung(kw), 'Kassenwart · Bierwart');
    expect(s.beschreibung(frueher), 'früher Bierwart');
    expect(s.beschreibung(ohneApp), 'ohne App');
    expect(s.beschreibung(weg), 'entfernt');
  });

  test('Kassenwart geht mit, wenn er zurückkommt oder verwaist ist', () {
    expect(stand().kassenwartDanach(alteUid: 'k', uid: 'neu'), 'neu');
    expect(stand().kassenwartDanach(alteUid: 'a', uid: 'neu'), 'k');
    expect(
      stand(aktiv: {'a'}).kassenwartDanach(alteUid: null, uid: 'neu'),
      'neu',
    );
  });
}
