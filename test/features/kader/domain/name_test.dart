import 'package:bier_wart/src/features/kader/domain/name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Leerraum wird bereinigt, auch geschützte Leerzeichen', () {
    expect(nameBereinigen('  Jonas    Weber '), 'Jonas Weber');
  });

  test('Schlüssel wie in den Rules: klein, bereinigt (AUTH-07)', () {
    expect(nameKey('  Jonas   WEBER '), 'jonas weber');
    expect(nameKey('Gäste'), 'gäste');
  });

  test('Prüfung wie nameGueltig in den Rules', () {
    expect(namePruefen('   '), isNotNull);
    expect(namePruefen('A' * 60), isNull);
    expect(namePruefen('A' * 61), isNotNull);
    expect(namePruefen('Tobias Meier'), isNull);
  });
}
