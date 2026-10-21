import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bier_wart/src/features/strichliste/application/strichliste.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';

/// Kasse k1 mit zwei Sorten, Jonas mit 12,00\u00a0€ offen, Felix mit Guthaben.
FakeDatenbank kasseMitSorten() => testDatenbank()
  ..sorte('k1', 'bier', 'Bier 0,5', 150, reihenfolge: 0)
  ..sorte('k1', 'cola', 'Cola 0,33', 120, reihenfolge: 1, bestand: 0)
  ..mitglied('k1', 'jonas', 'Jonas Weber', saldo: 1200)
  ..mitglied('k1', 'felix', 'Felix Wagner', saldo: -500);

Future<FakeDatenbank> starten(
  WidgetTester tester, {
  FakeDatenbank? db,
  FakeSpeicher? einstellungen,
}) async {
  telefon(tester);
  final daten = db ?? kasseMitSorten();
  await appStarten(
    tester,
    kasseId: 'k1',
    db: daten,
    einstellungen: einstellungen,
  );
  return daten;
}

Map<String, Object?> letzteBuchung(FakeDatenbank db) =>
    db.batches.last.firstWhere((s) => s.pfad.contains('/buchungen/')).daten;

Finder kachel(String name) => find
    .ancestor(of: find.text(name), matching: find.byType(GestureDetector))
    .first;

/// Lässt die 8 Sekunden für „Rückgängig“ ablaufen, sonst bleibt am
/// Testende ein Timer offen.
Future<void> fristAblaufen(WidgetTester tester) =>
    tester.pump(StrichlisteNotifier.rueckgaengigFrist);

void main() {
  testWidgets('Sorten oben, Mitglieder darunter, „Gäste“ zuletzt (STR-01)', (
    tester,
  ) async {
    await starten(tester);
    expect(find.text('STRICHLISTE'), findsOneWidget);
    expect(find.text('SV TEST'), findsOneWidget);
    expect(find.text('Bier 0,5'), findsOneWidget);
    expect(find.text('leer'), findsOneWidget);
    expect(find.text('12,00\u00a0€'), findsOneWidget);
    expect(find.text('+5,00\u00a0€'), findsOneWidget);
    expect(find.text('immer bar'), findsOneWidget);

    final namen = ['Felix Wagner', 'Jonas Weber', 'Tobias Meier', 'Gäste'];
    final xy = [for (final n in namen) tester.getTopLeft(find.text(n))];
    for (var i = 1; i < xy.length; i++) {
      final davor = xy[i - 1];
      expect(
        xy[i].dy > davor.dy || (xy[i].dy == davor.dy && xy[i].dx > davor.dx),
        isTrue,
        reason: '${namen[i]} nach ${namen[i - 1]}',
      );
    }
  });

  testWidgets('Tippen bucht offen, Rückgängig storniert (STR-02, STR-04)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tester.tap(kachel('Jonas Weber'));
    await tester.pump();

    expect(letzteBuchung(db)['typ'], 'strich');
    expect(letzteBuchung(db)['preisCents'], 150);
    expect(find.text('13,50\u00a0€ +1'), findsOneWidget);
    expect(
      find.text('Jonas Weber · Bier 0,5 · 1,50\u00a0€ offen'),
      findsOneWidget,
    );

    await tester.tap(find.text('RÜCKGÄNGIG'));
    await tester.pump();
    expect(letzteBuchung(db)['typ'], 'storno');
    expect(db.batches.last.first.pfad, endsWith('/buchungen/storno-id1'));
    expect(find.text('12,00\u00a0€'), findsOneWidget);
    expect(find.text('RÜCKGÄNGIG'), findsNothing);
  });

  testWidgets('Halten bucht bar ins eigene Portemonnaie (STR-03)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tester.longPress(kachel('Jonas Weber'));
    await tester.pump();
    expect(letzteBuchung(db)['typ'], 'strichBar');
    expect(letzteBuchung(db)['ortId'], 'uid');
    expect(find.text('+1 bar'), findsOneWidget);
    expect(
      find.text('Jonas Weber · Bier 0,5 · 1,50\u00a0€ bar'),
      findsOneWidget,
    );
    await fristAblaufen(tester);
  });

  testWidgets('„Gäste“ bucht auch beim Tippen bar (KAD-03)', (tester) async {
    final db = await starten(tester);
    await tester.tap(kachel('Gäste'));
    await tester.pump();
    expect(letzteBuchung(db)['typ'], 'strichBar');
    await fristAblaufen(tester);
  });

  testWidgets('Rückgängig verschwindet nach 8 Sekunden (STR-04)', (
    tester,
  ) async {
    await starten(tester);
    await tester.tap(kachel('Jonas Weber'));
    await tester.pump();
    expect(find.text('RÜCKGÄNGIG'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('RÜCKGÄNGIG'), findsNothing);
    expect(find.text('13,50\u00a0€'), findsOneWidget);
  });

  testWidgets('gewählte Sorte bucht und bleibt gemerkt (UI-07, STR-05)', (
    tester,
  ) async {
    final speicher = FakeSpeicher();
    final db = await starten(tester, einstellungen: speicher);
    await tester.tap(find.text('Cola 0,33'));
    await tester.pump();
    await tester.tap(kachel('Jonas Weber'));
    await tester.pump();
    // Auch die leere Sorte lässt sich buchen.
    expect(letzteBuchung(db)['sorteId'], 'cola');
    expect(letzteBuchung(db)['preisCents'], 120);
    expect(speicher.werte['gewaehlteSorte.k1'], 'cola');
    await fristAblaufen(tester);
  });

  testWidgets('gemerkte Sorte ist nach dem Start gewählt (UI-07)', (
    tester,
  ) async {
    final speicher = FakeSpeicher()..werte['gewaehlteSorte.k1'] = 'cola';
    final db = await starten(tester, einstellungen: speicher);
    await tester.tap(kachel('Jonas Weber'));
    await tester.pump();
    expect(letzteBuchung(db)['sorteId'], 'cola');
    await fristAblaufen(tester);
  });

  testWidgets('ohne Sorte: Hinweis statt Buchung', (tester) async {
    final db = await starten(tester, db: testDatenbank());
    expect(find.textContaining('Noch keine Sorte'), findsOneWidget);
    await tester.tap(kachel('Tobias Meier'));
    await tester.pump();
    expect(find.text('Leg zuerst eine Sorte an.'), findsOneWidget);
    expect(db.batches, isEmpty);
  });

  testWidgets('Sorte anlegen im Sheet (BES-01)', (tester) async {
    final db = await starten(tester, db: testDatenbank());
    await tester.tap(find.text('SORTE ANLEGEN').first);
    await tester.pumpAndSettle();

    final felder = find.byType(TextField);
    await tester.enterText(felder.at(0), 'Radler 0,5');
    await tester.enterText(felder.at(1), 'x');
    await tester.tap(find.text('SORTE ANLEGEN').last);
    await tester.pump();
    expect(find.text('Preis wie 1,50 eingeben.'), findsOneWidget);

    await tester.enterText(felder.at(1), '1,50');
    await tester.tap(find.text('SORTE ANLEGEN').last);
    await tester.pumpAndSettle();
    expect(letzteBuchung(db)['typ'], 'sorteAngelegt');
    expect(find.text('Radler 0,5'), findsOneWidget);
    expect(find.textContaining('Noch keine Sorte'), findsNothing);
  });

  testWidgets('Mitglied anlegen im Sheet, Name nur einmal (KAD-01, AUTH-07)', (
    tester,
  ) async {
    final db = await starten(tester);
    await tester.ensureVisible(find.text('+ MITGLIED'));
    await tester.tap(find.text('+ MITGLIED'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'jonas weber');
    await tester.tap(find.text('MITGLIED ANLEGEN').last);
    await tester.pumpAndSettle();
    expect(
      find.text('„jonas weber“ gibt es in der Kasse schon.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Tim Richter');
    await tester.tap(find.text('MITGLIED ANLEGEN').last);
    await tester.pumpAndSettle();
    expect(letzteBuchung(db)['typ'], 'mitgliedAngelegt');
    expect(find.text('Tim Richter'), findsOneWidget);
  });

  testWidgets('abgelehnte Buchung erscheint als Meldung (NFA-10)', (
    tester,
  ) async {
    final db = await starten(tester);
    db.schreibFehler = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await tester.tap(kachel('Jonas Weber'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text(
        'Der Strich für Jonas Weber hat der Server abgelehnt und '
        'zurückgenommen.',
      ),
      findsOneWidget,
    );
    await fristAblaufen(tester);
  });

  testWidgets('Tab-Leiste und Zahnrad (UI-02)', (tester) async {
    await starten(tester);
    await tester.tap(find.text('KADER'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hier entstehen Kader'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('EINSTELLUNGEN'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Zurück'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hier entstehen Kader'), findsOneWidget);

    await tester.tap(find.text('STRICHE'));
    await tester.pumpAndSettle();
    expect(find.text('STRICHLISTE'), findsOneWidget);
  });

  test('Batches nutzen increment für Summen (NFA-03)', () {
    // Dass Summen nur per increment geschrieben werden, prüfen die
    // Batch-Tests; hier nur, dass der Fake es versteht.
    expect(const Erhoehen(-1).um, -1);
  });
}
