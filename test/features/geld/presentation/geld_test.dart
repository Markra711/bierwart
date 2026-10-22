import 'package:bier_wart/src/core/money/cents.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';

/// Kasse k1 mit 245,90 €; Tobias (du, Kassenwart) 41,00 €, Jonas 32,00 €,
/// Max −6,50 €; ehemalig Anna 3,00 € und Ben 0 €.
FakeDatenbank geld({String kassenwart = 'uid'}) => testDatenbank()
  ..neueKasse('k1', name: 'SV Test', kassenwart: kassenwart)
  ..ort('k1', 'kasse', 'Kasse', stand: 24590)
  ..ort('k1', 'uid', 'Tobias Meier', stand: 4100)
  ..bierwart('k1', 'jonas', 'Jonas Weber', stand: 3200)
  ..bierwart('k1', 'max', 'Max Becker', stand: -650)
  ..ort('k1', 'anna', 'Anna Alt', stand: 300, ehemalig: true)
  ..ort('k1', 'ben', 'Ben Leer', ehemalig: true);

Future<FakeDatenbank> starten(WidgetTester tester, {FakeDatenbank? db}) async {
  telefon(tester);
  final daten = db ?? geld();
  await appStarten(tester, kasseId: 'k1', db: daten);
  await tester.tap(find.text('GELD'));
  await tester.pumpAndSettle();
  return daten;
}

Map<String, Object?> letzteBuchung(FakeDatenbank db) =>
    db.batches.last.firstWhere((s) => s.pfad.contains('/buchungen/')).daten;

int stand(FakeDatenbank db, String ort) =>
    db.docs['kassen/k1/orte/$ort']!['standCents']! as int;

Future<void> tippen(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  final ziel = find.text(text).last;
  await tester.ensureVisible(ziel);
  await tester.pumpAndSettle();
  await tester.tap(ziel);
  await tester.pumpAndSettle();
}

Finder feld(String label) => find.descendant(
  of: find
      .ancestor(
        of: find.text(label.toUpperCase()),
        matching: find.byType(Column),
      )
      .first,
  matching: find.byType(TextField),
);

void main() {
  testWidgets('Vermögen, Kasse und Portemonnaies (GEL-07, GEL-08)', (
    tester,
  ) async {
    await starten(tester);
    expect(find.text(formatEuro(24590 + 4100 + 3200 - 650 + 300)), findsOne);
    expect(find.text(formatEuro(24590)), findsOneWidget);
    expect(
      find.text('Kassette bei Tobias Meier (du, Kassenwart)'),
      findsOneWidget,
    );
    expect(find.textContaining('(du)', findRichText: true), findsOneWidget);
    expect(find.text('Kasse schuldet Max ${formatEuro(650)}'), findsOneWidget);
    expect(find.text('Anna Alt'), findsOneWidget);
    expect(find.text('ehemalig'), findsOneWidget);
    expect(find.text('Ben Leer'), findsNothing);
    expect(find.text('ÜBERGABE'), findsOneWidget);
    expect(find.text('KASSENSTURZ'), findsOneWidget);
  });

  testWidgets('ohne Kassenwart-Rolle: Auszahlung aus dem eigenen '
      'Portemonnaie, keine Übergabe (UI-08, GEL-05)', (tester) async {
    final db = await starten(tester, db: geld(kassenwart: 'jonas'));
    expect(find.text('ÜBERGABE'), findsNothing);
    expect(find.text('KASSENSTURZ'), findsNothing);
    expect(find.text('Kassette bei Jonas Weber (Kassenwart)'), findsOneWidget);

    await tippen(tester, 'EIN- ODER AUSZAHLUNG');
    expect(find.text('Das Geld kommt aus deinem Portemonnaie.'), findsOne);
    expect(find.text('der Kasse'), findsNothing);
    await tester.enterText(feld('Betrag'), '25');
    await tippen(tester, 'Schiri bezahlt');
    await tippen(tester, '${formatEuro(2500)} auszahlen'.toUpperCase());

    expect(letzteBuchung(db), containsPair('typ', 'auszahlung'));
    expect(letzteBuchung(db), containsPair('ortId', 'uid'));
    expect(letzteBuchung(db), containsPair('grund', 'Schiri bezahlt'));
    expect(stand(db, 'uid'), 4100 - 2500);
  });

  testWidgets('Einzahlung in die Kasse als Kassenwart (GEL-05)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tippen(tester, 'EIN- ODER AUSZAHLUNG');
    await tippen(tester, 'EINZAHLUNG');
    expect(find.text('Geld geht in'.toUpperCase()), findsOneWidget);
    await tester.enterText(feld('Betrag'), '10');
    await tester.enterText(feld('Grund'), 'Sponsor Bäckerei');
    await tippen(tester, '${formatEuro(1000)} einzahlen'.toUpperCase());

    expect(letzteBuchung(db), containsPair('typ', 'einzahlung'));
    expect(letzteBuchung(db), containsPair('ortId', 'kasse'));
    expect(stand(db, 'kasse'), 24590 + 1000);
  });

  testWidgets('ohne Grund wird nicht gebucht (GEL-05)', (tester) async {
    final db = await starten(tester);
    await tippen(tester, 'EIN- ODER AUSZAHLUNG');
    await tester.enterText(feld('Betrag'), '5');
    await tippen(tester, '${formatEuro(500)} auszahlen'.toUpperCase());
    expect(find.text('Grund angeben, z. B. „Schiri bezahlt“.'), findsOne);
    expect(db.batches, isEmpty);
  });

  testWidgets('Übergabe schlägt den Stand vor und bucht (GEL-04)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tippen(tester, 'ÜBERGABE');
    await tippen(tester, 'Jonas Weber');
    await tippen(
      tester,
      '${formatEuro(3200)} von Jonas erhalten'.toUpperCase(),
    );
    expect(letzteBuchung(db), containsPair('typ', 'uebergabe'));
    expect(letzteBuchung(db), containsPair('vonOrtId', 'jonas'));
    expect(letzteBuchung(db), containsPair('nachOrtId', 'kasse'));
    expect(stand(db, 'jonas'), 0);
    expect(stand(db, 'kasse'), 24590 + 3200);
  });

  testWidgets('Übergabe aus der Kasse gleicht eine Auslage aus (GEL-04)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tippen(tester, 'ÜBERGABE');
    await tippen(tester, 'AUS DER KASSE');
    await tippen(tester, 'Max Becker');
    await tippen(tester, '${formatEuro(650)} an Max geben'.toUpperCase());
    expect(stand(db, 'max'), 0);
    expect(stand(db, 'kasse'), 24590 - 650);
  });

  testWidgets('Kassensturz bucht die Differenz (GEL-06)', (tester) async {
    final db = await starten(tester);
    await tippen(tester, 'KASSENSTURZ');
    await tester.enterText(feld('Gezählt'), '245,40');
    await tester.pumpAndSettle();
    expect(find.text('Kassendifferenz'), findsOneWidget);
    expect(find.text(formatEuro(-50)), findsOneWidget);

    await tippen(tester, 'KASSENSTURZ BUCHEN');
    expect(letzteBuchung(db), containsPair('typ', 'kassensturz'));
    expect(letzteBuchung(db), containsPair('differenzCents', -50));
    expect(stand(db, 'kasse'), 24540);
    expect(find.textContaining('Kassensturz am'), findsOneWidget);
  });

  testWidgets('Kassensturz bucht nicht, wenn sich der Stand geändert hat', (
    tester,
  ) async {
    final db = await starten(tester);
    await tippen(tester, 'KASSENSTURZ');
    await tester.enterText(feld('Gezählt'), '245,40');
    // Ein anderes Gerät hat gebucht, die Anzeige kennt es noch nicht.
    db.docs['kassen/k1/orte/kasse']!['standCents'] = 25000;
    await tippen(tester, 'KASSENSTURZ BUCHEN');
    expect(
      find.text(
        'Der Kassenstand hat sich gerade geändert. Prüf die Differenz '
        'noch einmal.',
      ),
      findsOneWidget,
    );
    expect(db.batches, isEmpty);
  });

  testWidgets('Kassensturz ohne Netz meldet sich (GEL-06, NFA-10)', (
    tester,
  ) async {
    final db = geld()
      ..serverFehler = FirebaseException(plugin: 'test', code: 'unavailable');
    await starten(tester, db: db);
    await tippen(tester, 'KASSENSTURZ');
    await tester.enterText(feld('Gezählt'), '245,90');
    await tester.pumpAndSettle();
    expect(find.text('Stimmt genau'), findsOneWidget);
    await tippen(tester, 'KASSENSTURZ BUCHEN');
    expect(find.text('Für den Kassensturz brauchst du Netz.'), findsOne);
    expect(db.batches, isEmpty);
  });
}
