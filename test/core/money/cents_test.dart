import 'package:bier_wart/src/core/money/cents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatEuro (NFA-11)', () {
    // Zwischen Betrag und € steht ein geschütztes Leerzeichen.
    test('Grundformat', () {
      expect(formatEuro(150), '1,50 €');
      expect(formatEuro(0), '0,00 €');
      expect(formatEuro(5), '0,05 €');
    });

    test('Tausenderpunkt', () {
      expect(formatEuro(148190), '1.481,90 €');
      expect(formatEuro(123456789), '1.234.567,89 €');
      expect(formatEuro(99999), '999,99 €');
    });

    test('echtes Minuszeichen', () {
      expect(formatEuro(-450), '−4,50 €');
    });
  });

  test('1.000 Striche à 1,50 € ergeben exakt 1.500,00 € (NFA-04)', () {
    var summe = 0;
    for (var i = 0; i < 1000; i++) {
      summe += 150;
    }
    expect(summe, 150000);
    expect(formatEuro(summe), '1.500,00 €');
  });

  group('parseEuro (ADR-0002)', () {
    test('ganze Euro und Komma', () {
      expect(parseEuro('50'), 5000);
      expect(parseEuro('50,5'), 5050);
      expect(parseEuro('50,05'), 5005);
      expect(parseEuro('0'), 0);
    });

    test('Tausenderpunkt, Eurozeichen und Leerzeichen', () {
      expect(parseEuro('1.234,56'), 123456);
      expect(parseEuro('1.234'), 123400);
      expect(parseEuro('12,00\u00a0€'), 1200);
      expect(parseEuro(' 7 € '), 700);
    });

    test('Punkt als Dezimaltrenner nur vor ein oder zwei Ziffern', () {
      expect(parseEuro('12.5'), 1250);
      expect(parseEuro('12.50'), 1250);
    });

    test('unlesbar oder negativ', () {
      for (final s in ['', 'abc', '-5', '1,234', '1.2.3', '12,']) {
        expect(parseEuro(s), isNull, reason: s);
      }
    });
  });
}
