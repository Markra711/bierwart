import 'package:bier_wart/src/core/money/cents.dart';
import 'package:bier_wart/src/features/geld/data/geld_batches.dart';
import 'package:bier_wart/src/features/geld/data/zahlung_batch.dart';
import 'package:bier_wart/src/features/strichliste/data/strich_batches.dart';
import 'package:bier_wart/src/features/strichliste/domain/strich.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/datenbank.dart';
import 'geld_test.dart' show geld, starten, tippen;

/// Am Samstag, 17.10.: Tobias bucht einen Strich auf Paul, Max nimmt
/// Pauls Zahlung an. Am Samstag davor: Kassensturz von Tobias.
Future<FakeDatenbank> mitBuchungen() async {
  final db = geld()
    ..mitglied('k1', 'paul', 'Paul Hoffmann')
    ..sorte('k1', 'bier', 'Bier 0,5', 150);
  await db.schreiben(
    kassensturzBatch(
      uid: 'uid',
      bierwartName: 'Tobias Meier',
      kasseId: 'k1',
      buchungId: 'b1',
      gezaehltCents: 24590,
      differenzCents: -50,
      geraetZeit: DateTime(2026, 10, 10, 22, 15),
    ),
  );
  await db.schreiben(
    zahlungBatch(
      uid: 'max',
      bierwartName: 'Max Becker',
      kasseId: 'k1',
      buchungId: 'b2',
      mitgliedId: 'paul',
      betragCents: 1000,
      ortId: 'max',
      geraetZeit: DateTime(2026, 10, 17, 20, 38),
    ),
  );
  await db.schreiben(
    strichBatch(
      uid: 'uid',
      bierwartName: 'Tobias Meier',
      kasseId: 'k1',
      buchungId: 'b3',
      art: StrichArt.offen,
      mitgliedId: 'paul',
      sorteId: 'bier',
      preisCents: 150,
      geraetZeit: DateTime(2026, 10, 17, 20, 41),
    ),
  );
  db.batches.clear();
  return db;
}

Future<void> verlaufOeffnen(WidgetTester tester, FakeDatenbank db) async {
  await starten(tester, db: db);
  await tester.scrollUntilVisible(
    find.text('VERLAUF ANSEHEN →'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tippen(tester, 'VERLAUF ANSEHEN →');
}

void main() {
  testWidgets('Verlauf nach Tagen, neueste zuerst (LOG-03)', (tester) async {
    await verlaufOeffnen(tester, await mitBuchungen());
    expect(find.text('VERLAUF'), findsOneWidget);
    expect(find.text('SAMSTAG, 17. OKTOBER'), findsOneWidget);
    expect(find.text('SAMSTAG, 10. OKTOBER'), findsOneWidget);
    expect(find.text('Strich · Paul Hoffmann'), findsOneWidget);
    expect(find.text('Bier 0,5 · offen · von Tobias'), findsOneWidget);
    expect(find.text('Zahlung · Paul Hoffmann'), findsOneWidget);
    expect(find.text('in Portemonnaie Max · von Max'), findsOneWidget);
    expect(find.text('+${formatEuro(1000)}'), findsOneWidget);
    expect(find.text('Kassensturz'), findsOneWidget);
    expect(find.text('20:41'), findsOneWidget);

    final strich = tester.getTopLeft(find.text('Strich · Paul Hoffmann'));
    final zahlung = tester.getTopLeft(find.text('Zahlung · Paul Hoffmann'));
    expect(strich.dy, lessThan(zahlung.dy));
  });

  testWidgets('nach Bierwart filtern (LOG-03)', (tester) async {
    await verlaufOeffnen(tester, await mitBuchungen());
    await tippen(tester, 'Alle Bierwarte');
    await tippen(tester, 'Max Becker');
    expect(find.text('Zahlung · Paul Hoffmann'), findsOneWidget);
    expect(find.text('Strich · Paul Hoffmann'), findsNothing);
    expect(find.text('Kassensturz'), findsNothing);

    await tippen(tester, 'Max Becker');
    await tippen(tester, 'Alle Bierwarte');
    expect(find.text('Kassensturz'), findsOneWidget);
  });

  testWidgets('nach Mitglied filtern, leer mit Hinweis (LOG-03)', (
    tester,
  ) async {
    await verlaufOeffnen(tester, await mitBuchungen());
    await tippen(tester, 'Alle Mitglieder');
    await tippen(tester, 'Paul Hoffmann');
    expect(find.text('Strich · Paul Hoffmann'), findsOneWidget);
    expect(find.text('Kassensturz'), findsNothing);

    await tippen(tester, 'Paul Hoffmann');
    await tippen(tester, 'Jonas Weber');
    expect(find.text('Dazu steht noch nichts im Verlauf.'), findsOneWidget);
  });

  testWidgets('lädt seitenweise (LOG-03)', (tester) async {
    final db = geld();
    for (var i = 0; i < 55; i++) {
      await db.schreiben(
        einAuszahlungBatch(
          uid: 'uid',
          bierwartName: 'Tobias Meier',
          kasseId: 'k1',
          buchungId: 'e$i',
          einzahlung: true,
          ortId: 'kasse',
          betragCents: 100,
          grund: 'Spende $i',
          geraetZeit: DateTime(2026, 10, 1).add(Duration(hours: i)),
        ),
      );
    }
    await verlaufOeffnen(tester, db);
    expect(find.text('Einzahlung · Spende 54', skipOffstage: false), findsOne);
    expect(
      find.text('Einzahlung · Spende 0', skipOffstage: false),
      findsNothing,
    );
    await tippen(tester, 'ÄLTERE LADEN');
    expect(find.text('Einzahlung · Spende 0', skipOffstage: false), findsOne);
    expect(find.text('ÄLTERE LADEN'), findsNothing);
  });
}
