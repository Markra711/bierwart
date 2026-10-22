import 'package:bier_wart/src/core/money/cents.dart';
import 'package:bier_wart/src/features/geld/domain/ort.dart';
import 'package:bier_wart/src/features/geld/presentation/geld_screen.dart';
import 'package:bier_wart/src/features/geld/presentation/uebergabe_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

const kasse = Ort(id: 'kasse', name: 'Kasse', standCents: 24590);
const tobias = Ort(id: 'uid', name: 'Tobias Meier', standCents: 4100);
const jonas = Ort(id: 'jonas', name: 'Jonas Weber', standCents: 3200);
const max = Ort(id: 'max', name: 'Max Becker', standCents: -650);
const alt = Ort(id: 'alt', name: 'Anna Alt', standCents: 300, ehemalig: true);
const leer = Ort(id: 'leer', name: 'Ben Leer', standCents: 0, ehemalig: true);

void main() {
  test('Vermögen ist Kasse plus alle Portemonnaies (GEL-07)', () {
    final g = geldstand([max, kasse, tobias, jonas, alt], eigeneUid: 'uid');
    expect(g.kasse, kasse);
    expect(g.vermoegenCents, 24590 + 4100 + 3200 - 650 + 300);
  });

  test('eigenes zuerst, dann alphabetisch, ehemalige zuletzt', () {
    final g = geldstand([alt, max, kasse, jonas, tobias], eigeneUid: 'uid');
    expect(g.portemonnaies.map((o) => o.id), ['uid', 'jonas', 'max', 'alt']);
  });

  test('ehemalig auf 0 verschwindet (GEL-08)', () {
    final g = geldstand([kasse, tobias, leer, alt], eigeneUid: 'uid');
    expect(g.portemonnaies.map((o) => o.id), ['uid', 'alt']);
  });

  test('aktuelle Namen aus dem Kader ersetzen den alten am Ort', () {
    final g = geldstand(
      [kasse, jonas],
      eigeneUid: 'uid',
      namen: {'jonas': 'Jonas Schmidt'},
    );
    expect(g.portemonnaies.single.name, 'Jonas Schmidt');
  });

  test('Auslage und ehemalig als Unterzeile (GEL-01, GEL-08)', () {
    expect(portemonnaieZusatz(jonas), isNull);
    expect(portemonnaieZusatz(max), 'Kasse schuldet Max ${formatEuro(650)}');
    expect(portemonnaieZusatz(alt), 'ehemalig');
  });

  test('Übergabe schlägt vor, was sich ausgleichen lässt', () {
    expect(uebergabeVorschlag(jonas, inDieKasse: true), 3200);
    expect(uebergabeVorschlag(jonas, inDieKasse: false), isNull);
    expect(uebergabeVorschlag(max, inDieKasse: false), 650);
    expect(uebergabeVorschlag(max, inDieKasse: true), isNull);
  });
}
