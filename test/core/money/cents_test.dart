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
}
