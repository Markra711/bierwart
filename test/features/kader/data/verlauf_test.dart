import 'package:bier_wart/src/features/kader/data/verlauf_repository.dart';
import 'package:bier_wart/src/features/kader/domain/eintrag.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> buchung(
  String typ, {
  int? preis,
  int? betrag,
  Object? am,
  DateTime? geraet,
  String? bezugId,
}) => {
  'typ': typ,
  'mitgliedId': 'j',
  'sorteId': ?preis == null ? null : 's1',
  'preisCents': ?preis,
  'betragCents': ?betrag,
  'bezugId': ?bezugId,
  'stempel': {
    'uid': 'u',
    'name': 'Tobias Meier',
    'am': am,
    'geraetAm': geraet ?? DateTime(2026, 10, 1),
  },
};

void main() {
  test('Striche und Zahlungen, neueste zuerst, Logs fallen weg (KAD-06)', () {
    final e = eintraegeAus([
      (
        'a',
        buchung(
          'strich',
          preis: 150,
          am: Timestamp.fromDate(DateTime(2026, 10, 17, 20)),
        ),
      ),
      (
        'b',
        buchung(
          'zahlung',
          betrag: 500,
          am: Timestamp.fromDate(DateTime(2026, 10, 18)),
        ),
      ),
      (
        'c',
        buchung(
          'mitgliedAngelegt',
          am: Timestamp.fromDate(DateTime(2026, 10, 1)),
        ),
      ),
    ]);
    expect(e.map((x) => x.buchungId), ['b', 'a']);
    expect(e.first.art, EintragArt.zahlung);
    expect(e.first.cents, 500);
    expect(e.last.von, 'Tobias Meier');
  });

  test('Storno markiert seinen Strich und erscheint nicht selbst (STR-06)', () {
    final e = eintraegeAus([
      (
        'a',
        buchung(
          'strich',
          preis: 150,
          am: Timestamp.fromDate(DateTime(2026, 10, 17)),
        ),
      ),
      (
        'storno-a',
        buchung(
          'storno',
          preis: 150,
          bezugId: 'a',
          am: Timestamp.fromDate(DateTime(2026, 10, 18)),
        ),
      ),
    ]);
    expect(e.single.storniert, isTrue);
  });

  test('ohne Serverzeit gilt die Gerätezeit (offline gebucht)', () {
    final e = eintraegeAus([
      (
        'a',
        buchung('strichBar', preis: 150, geraet: DateTime(2026, 10, 21, 9)),
      ),
    ]);
    expect(e.single.zeit, DateTime(2026, 10, 21, 9));
    expect(e.single.art, EintragArt.strichBar);
  });
}
