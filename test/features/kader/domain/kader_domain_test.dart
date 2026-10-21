import 'package:bier_wart/src/core/money/cents.dart';
import 'package:bier_wart/src/features/kader/domain/eintrag.dart';
import 'package:bier_wart/src/features/kader/domain/kader.dart';
import 'package:bier_wart/src/features/kader/domain/mitglied.dart';
import 'package:flutter_test/flutter_test.dart';

const jonas = Mitglied(id: 'j', name: 'Jonas Weber', saldoCents: 1200);
const paul = Mitglied(id: 'p', name: 'Paul Hoffmann', saldoCents: 750);
const ben = Mitglied(id: 'b', name: 'Ben Wolf', saldoCents: 0);
const felix = Mitglied(id: 'f', name: 'Felix Wagner', saldoCents: -500);
const gaeste = Mitglied(id: 'g', name: 'Gäste', saldoCents: 0, istGast: true);

void main() {
  test('Kader nach Schulden, Guthaben zuletzt, ohne „Gäste“ (KAD-05)', () {
    expect(
      kaderNachSchulden([felix, ben, gaeste, paul, jonas]).map((m) => m.id),
      ['j', 'p', 'b', 'f'],
    );
  });

  test('Summen offen und Guthaben', () {
    final s = kaderSummen([jonas, paul, ben, felix]);
    expect(s.offenCents, 1950);
    expect(s.guthabenCents, 500);
  });

  test('„Wer schuldet was“ zum Teilen (KAD-07)', () {
    expect(
      werSchuldetWas('SV Test', [felix, ben, paul, jonas]),
      'Wer schuldet was – SV Test\n\n'
      'Jonas Weber: ${formatEuro(1200)}\n'
      'Paul Hoffmann: ${formatEuro(750)}\n\n'
      'Guthaben:\n'
      'Felix Wagner: ${formatEuro(500)}',
    );
    expect(werSchuldetWas('SV Test', [ben]), contains('Niemand schuldet'));
  });

  test('Rolle nur für aktive Bierwarte, Admin vor Kassenwart', () {
    const tobias = Mitglied(
      id: 't',
      name: 'Tobias Meier',
      saldoCents: 0,
      bierwartUid: 'u1',
    );
    Rolle? rolle(Set<String> aktiv, {String? admin, String? kw}) => rolleVon(
      tobias,
      aktiveBierwarte: aktiv,
      adminUid: admin,
      kassenwartUid: kw,
    );
    expect(rolle({'u1'}, admin: 'u1', kw: 'u1'), Rolle.admin);
    expect(rolle({'u1'}, admin: 'x', kw: 'u1'), Rolle.kassenwart);
    expect(rolle({'u1'}, admin: 'x', kw: 'x'), Rolle.bierwart);
    expect(rolle({}, admin: 'u1'), isNull, reason: 'ausgetreten');
    expect(
      rolleVon(
        jonas,
        aktiveBierwarte: {'u1'},
        adminUid: 'u1',
        kassenwartUid: 'u1',
      ),
      isNull,
    );
  });

  test('Zeit und Vorname wie im Canvas', () {
    expect(zeitText(DateTime(2026, 10, 17, 20, 41)), 'Sa 17.10., 20:41');
    expect(vorname('  Tobias  Meier'), 'Tobias');
  });
}
