import 'package:bier_wart/src/features/kader/domain/mitglied.dart';
import 'package:bier_wart/src/features/lager/domain/sorte.dart';
import 'package:bier_wart/src/features/strichliste/domain/strich.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mitglieder alphabetisch nach Vornamen, „Gäste“ zuletzt (UI-06)', () {
    final raster = mitgliederFuerRaster(const [
      Mitglied(id: 'g', name: 'Gäste', saldoCents: 0, istGast: true),
      Mitglied(id: 't', name: 'Tobias Meier', saldoCents: 0),
      Mitglied(id: 'a', name: 'anna Schulz', saldoCents: 0),
      Mitglied(id: 'z', name: 'Zoe Abel', saldoCents: 0),
    ]);
    expect(raster.map((m) => m.id), ['a', 't', 'z', 'g']);
  });

  test('Sorten nach Reihenfolge, neue ans Ende', () {
    const a = Sorte(
      id: 'a',
      name: 'Cola',
      preisCents: 120,
      bestand: 3,
      reihenfolge: 1,
    );
    const b = Sorte(
      id: 'b',
      name: 'Bier',
      preisCents: 150,
      bestand: 0,
      reihenfolge: 0,
    );
    expect(sortenFuerRaster([a, b]).map((s) => s.id), ['b', 'a']);
    expect(naechsteReihenfolge([a, b]), 2);
    expect(naechsteReihenfolge(const []), 0);
    expect(b.leer, isTrue);
  });

  test('Tippen bucht offen, Halten bar; „Gäste“ immer bar (KAD-03)', () {
    const jonas = Mitglied(id: 'j', name: 'Jonas', saldoCents: 0);
    const gaeste = Mitglied(
      id: 'g',
      name: 'Gäste',
      saldoCents: 0,
      istGast: true,
    );
    expect(strichArtFuer(jonas, gehalten: false), StrichArt.offen);
    expect(strichArtFuer(jonas, gehalten: true), StrichArt.bar);
    expect(strichArtFuer(gaeste, gehalten: false), StrichArt.bar);
  });
}
