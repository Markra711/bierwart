import 'package:bier_wart/src/features/onboarding/domain/einladung.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final erstellt = DateTime(2026, 10, 21, 12);
  Einladung einladung({bool ersetzt = false, int anzahl = 3}) => Einladung(
    code: 'K7Q2MXA93DWFT2HC8RNP',
    kasseId: 'k1',
    kassenName: 'SV Eichwald',
    anzahlBierwarte: anzahl,
    erstelltAm: erstellt,
    ersetzt: ersetzt,
  );

  test('gilt 7 Tage (AUTH-08)', () {
    final e = einladung();
    expect(
      e.zustand(erstellt.add(const Duration(days: 6, hours: 23))),
      EinladungsZustand.gueltig,
    );
    expect(
      e.zustand(erstellt.add(const Duration(days: 7))),
      EinladungsZustand.abgelaufen,
    );
  });

  test('ersetzt geht vor abgelaufen (ADM-01)', () {
    expect(
      einladung(ersetzt: true).zustand(erstellt),
      EinladungsZustand.ersetzt,
    );
  });

  test('klare Meldung nur für ungültige Links', () {
    expect(EinladungsZustand.gueltig.meldung, isNull);
    expect(EinladungsZustand.ersetzt.meldung, contains('ersetzt'));
    expect(EinladungsZustand.abgelaufen.meldung, contains('abgelaufen'));
  });

  test('Anzahl in Einzahl und Mehrzahl (AUTH-05)', () {
    expect(einladung(anzahl: 1).bierwarteText, '1 Bierwart');
    expect(einladung(anzahl: 3).bierwarteText, '3 Bierwarte');
  });
}
