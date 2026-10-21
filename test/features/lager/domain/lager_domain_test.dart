import 'package:bier_wart/src/features/lager/domain/sorte.dart';
import 'package:flutter_test/flutter_test.dart';

Sorte sorte(String id, int bestand) =>
    Sorte(id: id, name: id, preisCents: 150, bestand: bestand, reihenfolge: 0);

void main() {
  test('Kopfzeile zählt Sorten und Flaschen ohne Fehlbestand', () {
    final s = lagerSumme([sorte('a', 38), sorte('b', 0), sorte('c', -3)]);
    expect(s.sorten, 3);
    expect(s.flaschen, 38);
  });

  test('Balken am größten Bestand gemessen (BES-03)', () {
    final alle = [sorte('a', 40), sorte('b', 10), sorte('c', -2)];
    expect(balkenAnteil(alle[0], alle), 1);
    expect(balkenAnteil(alle[1], alle), 0.25);
    expect(balkenAnteil(alle[2], alle), 0);
  });

  test('Flaschen mit echtem Minus', () {
    expect(flaschenText(38), '38 Fl.');
    expect(flaschenText(-3), '−3 Fl.');
  });

  test('Einkaufszeilen: leere fallen weg, doppelte zählen zusammen', () {
    expect(einkaufZeilen([('bier', 20), (null, 6), ('cola', 0), ('bier', 4)]), {
      'bier': 24,
    });
  });
}
