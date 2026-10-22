import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/core/money/cents.dart';
import 'package:bier_wart/src/features/geld/data/geld_batches.dart';
import 'package:bier_wart/src/features/geld/data/log_repository.dart';
import 'package:bier_wart/src/features/geld/domain/logbuchung.dart';
import 'package:bier_wart/src/features/lager/data/lager_batches.dart';
import 'package:bier_wart/src/features/geld/data/zahlung_batch.dart';
import 'package:flutter_test/flutter_test.dart';

const namen = LogNamen(
  mitglieder: {'jonas': 'Jonas Weber', 'paul': 'Paul Hoffmann'},
  sorten: {'bier': 'Bier 0,5', 'cola': 'Cola 0,33'},
  bierwarte: {'uid': 'Tobias Meier', 'max': 'Max Becker', 'jonas': 'Jonas'},
);
final zeit = DateTime(2026, 10, 17, 20, 41);

/// Die Buchung eines Batches, wie der Verlauf sie liest.
Logbuchung buchung(List<Schreibvorgang> batch) {
  final b = batch.firstWhere((s) => s.pfad.contains('/buchungen/'));
  return logbuchungAus(b.pfad.split('/').last, b.daten);
}

LogZeile zeile(List<Schreibvorgang> batch) => logZeile(buchung(batch), namen);

void main() {
  test('Strich, offen, wie im Design-Canvas (LOG-03)', () {
    final z = logZeile(
      Logbuchung(
        id: 'a',
        typ: LogTyp.strich,
        zeit: zeit,
        von: 'Tobias Meier',
        mitgliedId: 'jonas',
        sorteId: 'bier',
        cents: 150,
      ),
      namen,
    );
    expect(z.titel, 'Strich · Jonas Weber');
    expect(z.unterzeile, 'Bier 0,5 · offen · von Tobias');
    expect(z.betrag, formatEuro(150));
    expect(z.tendenz, Tendenz.neutral);
  });

  test('Zahlung in ein Portemonnaie, als Plus', () {
    final z = zeile(
      zahlungBatch(
        uid: 'max',
        bierwartName: 'Max Becker',
        kasseId: 'k1',
        buchungId: 'z1',
        mitgliedId: 'paul',
        betragCents: 1000,
        ortId: 'max',
        geraetZeit: zeit,
      ),
    );
    expect(z.titel, 'Zahlung · Paul Hoffmann');
    expect(z.unterzeile, 'in Portemonnaie Max · von Max');
    expect(z.betrag, '+${formatEuro(1000)}');
    expect(z.tendenz, Tendenz.plus);
  });

  test('Übergabe in die Kasse', () {
    final z = zeile(
      uebergabeBatch(
        uid: 'uid',
        bierwartName: 'Tobias Meier',
        kasseId: 'k1',
        buchungId: 'u1',
        vonOrtId: 'jonas',
        nachOrtId: 'kasse',
        betragCents: 4000,
        geraetZeit: zeit,
      ),
    );
    expect(z.titel, 'Übergabe · Jonas → Kasse');
    expect(z.unterzeile, 'angenommen von Tobias');
    expect(z.betrag, formatEuro(4000));
  });

  test('Einkauf zählt Flaschen über alle Sorten, als Minus', () {
    final z = zeile(
      einkaufBatch(
        uid: 'max',
        bierwartName: 'Max Becker',
        kasseId: 'k1',
        buchungId: 'e1',
        zeilen: const {'bier': 24, 'cola': 20},
        betragCents: 3890,
        ortId: 'max',
        geraetZeit: zeit,
      ),
    );
    expect(z.titel, 'Einkauf · 44 Flaschen');
    expect(z.unterzeile, 'aus Portemonnaie Max · von Max');
    expect(z.betrag, formatEuro(-3890));
    expect(z.tendenz, Tendenz.minus);
  });

  test('Bestandskorrektur zeigt vorher und nachher, ohne Betrag', () {
    final z = zeile(
      bestandKorrekturBatch(
        uid: 'max',
        bierwartName: 'Max Becker',
        kasseId: 'k1',
        buchungId: 'b1',
        sorteId: 'cola',
        gezaehlt: 9,
        differenz: -2,
        geraetZeit: zeit,
      ),
    );
    expect(z.titel, 'Bestand korrigiert · Cola 0,33');
    expect(z.unterzeile, '11 → 9 Flaschen · von Max');
    expect(z.betrag, '—');
    expect(z.tendenz, Tendenz.keiner);
  });

  test('Auszahlung mit Grund aus der Kasse', () {
    final z = zeile(
      einAuszahlungBatch(
        uid: 'uid',
        bierwartName: 'Tobias Meier',
        kasseId: 'k1',
        buchungId: 'a1',
        einzahlung: false,
        ortId: 'kasse',
        betragCents: 2500,
        grund: 'Schiri bezahlt',
        geraetZeit: zeit,
      ),
    );
    expect(z.titel, 'Auszahlung · Schiri bezahlt');
    expect(z.unterzeile, 'aus der Kasse · von Tobias');
    expect(z.betrag, formatEuro(-2500));
  });

  test('Kassensturz mit Differenz, und ohne', () {
    List<Schreibvorgang> sturz(int d) => kassensturzBatch(
      uid: 'uid',
      bierwartName: 'Tobias Meier',
      kasseId: 'k1',
      buchungId: 'k',
      gezaehltCents: 24540,
      differenzCents: d,
      geraetZeit: zeit,
    );
    final mit = zeile(sturz(-50));
    expect(mit.unterzeile, 'Differenz gebucht · von Tobias');
    expect(mit.betrag, formatEuro(-50));
    expect(mit.tendenz, Tendenz.minus);
    final ohne = zeile(sturz(0));
    expect(ohne.unterzeile, 'stimmt genau · von Tobias');
    expect(ohne.betrag, '—');
  });

  test('unbekannte Namen und Typen zeigen keine IDs', () {
    final z = logZeile(
      Logbuchung(
        id: 'x',
        typ: LogTyp.strich,
        zeit: zeit,
        von: 'Tobias Meier',
        mitgliedId: 'weg',
        sorteId: 'weg',
        cents: 150,
      ),
      namen,
    );
    expect(z.titel, 'Strich · Mitglied');
    expect(z.unterzeile, startsWith('Sorte'));
    expect(
      logbuchungAus('y', {
        'typ': 'gibtsNicht',
        'stempel': {'uid': 'u', 'name': 'N', 'geraetAm': zeit},
      }).typ,
      LogTyp.unbekannt,
    );
  });

  test('Tage auf Deutsch, Buchungen nach Tagen gruppiert', () {
    expect(tagText(DateTime(2026, 10, 17)), 'Samstag, 17. Oktober');
    expect(uhrzeit(DateTime(2026, 10, 17, 9, 5)), '09:05');
    Logbuchung am(DateTime t) =>
        Logbuchung(id: '$t', typ: LogTyp.strich, zeit: t, von: 'T');
    final tage = nachTagen([
      am(DateTime(2026, 10, 17, 20)),
      am(DateTime(2026, 10, 17, 18)),
      am(DateTime(2026, 10, 10, 22)),
    ]);
    expect(tage.map((t) => (t.$1, t.$2.length)), [
      (DateTime(2026, 10, 17), 2),
      (DateTime(2026, 10, 10), 1),
    ]);
  });
}
