import 'package:bier_wart/src/core/money/cents.dart';
import 'package:bier_wart/src/features/einstellungen/domain/bierwart.dart';
import 'package:bier_wart/src/features/einstellungen/presentation/einstellungen_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const tobias = Bierwart(
  uid: 'uid',
  name: 'Tobias Meier',
  mitgliedId: 'm1',
  istAdmin: true,
  istKassenwart: true,
  portemonnaieCents: 4100,
);
const jonas = Bierwart(
  uid: 'jonas',
  name: 'Jonas Weber',
  mitgliedId: 'm2',
  portemonnaieCents: 3200,
);
const max = Bierwart(
  uid: 'max',
  name: 'Max Becker',
  mitgliedId: 'm3',
  istKassenwart: true,
  portemonnaieCents: -650,
);

void main() {
  test('Unterzeile wie im Design-Canvas', () {
    expect(bierwartZeile(tobias, ich: true), 'du · Admin · Kassenwart');
    expect(
      bierwartZeile(jonas, ich: false),
      'Bierwart · Portemonnaie ${formatEuro(3200)}',
    );
    expect(
      bierwartZeile(max, ich: false),
      'Kassenwart · Portemonnaie ${formatEuro(-650)}',
    );
  });

  test('eigener zuerst, dann alphabetisch', () {
    expect(bierwarteSortiert([max, jonas, tobias], 'uid').map((b) => b.uid), [
      'uid',
      'jonas',
      'max',
    ]);
  });

  test('Admin und Kassenwart lassen sich nicht entfernen (ADM-02)', () {
    expect(entfernenGeht(jonas), isNull);
    expect(entfernenGeht(max), 'Bestimm erst einen anderen Kassenwart.');
    expect(entfernenGeht(tobias), isNotNull);
  });

  test('Gültig bis', () {
    expect(gueltigBisText(DateTime(2026, 10, 26)), 'Mo, 26.10.');
  });
}
