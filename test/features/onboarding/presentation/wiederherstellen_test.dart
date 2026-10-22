import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';

const code = 'ABCD1234EFGH5678';

/// Kasse k2: Lena (UID alt, Admin und Kassenwart, 12,50 € im Portemonnaie)
/// und Jonas. Der Testnutzer `uid` ist in keiner Kasse, kennt aber den Code.
FakeDatenbank kasse() => FakeDatenbank()
  ..neueKasse('k2', name: 'SV Alt', admin: 'alt', kassenwart: 'alt')
  ..ort('k2', 'kasse', 'Kasse')
  ..bierwart('k2', 'alt', 'Lena Koch', stand: 1250)
  ..bierwart('k2', 'jonas', 'Jonas Weber')
  ..mitglied('k2', 'gaeste', 'Gäste', gast: true)
  ..docs['kassen/k2']!['wiederherstellungHash'] = Bytes(hashVon(code))
  ..docs['wiederherstellung/${hexVon(hashVon(code))}'] = {'kasseId': 'k2'};

Future<FakeDatenbank> starten(WidgetTester tester, {FakeDatenbank? db}) async {
  telefon(tester);
  final daten = db ?? kasse();
  await appStarten(tester, db: daten);
  await tippen(tester, 'Ich habe einen Wiederherstellungscode');
  return daten;
}

Future<void> tippen(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  final ziel = find.text(text).last;
  await tester.ensureVisible(ziel);
  await tester.pumpAndSettle();
  await tester.tap(ziel);
  await tester.pumpAndSettle();
}

Future<void> codeEingeben(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tippen(tester, 'WEITER');
}

void main() {
  testWidgets('als Lena zurück, Admin werden, neuen Code sehen (UC-03)', (
    tester,
  ) async {
    final db = await starten(tester);
    await codeEingeben(tester, 'AAAA-BBBB-CCCC-DDDD');
    expect(find.text('Zu diesem Code gibt es keine Kasse.'), findsOneWidget);

    await codeEingeben(tester, 'abcd-1234-efgh-5678');
    expect(db.docs['kassen/k2/wiederherstellungen/uid']!['nachweis'], code);
    expect(find.text('SV ALT'), findsOneWidget);
    expect(find.text('Admin · Kassenwart · Bierwart'), findsOneWidget);
    expect(find.text('Gäste'), findsNothing);

    await tippen(tester, 'Lena Koch');
    await tippen(tester, 'ADMIN WERDEN');

    final k = db.docs['kassen/k2']!;
    expect([k['adminUid'], k['kassenwartUid']], ['uid', 'uid']);
    expect(db.docs.containsKey('kassen/k2/bierwarte/alt'), isFalse);
    expect(db.docs['kassen/k2/orte/alt']!['ehemalig'], isTrue);
    expect(db.docs['kassen/k2/mitglieder/alt']!['bierwartUid'], 'uid');
    expect(db.docs.containsKey('kassen/k2/wiederherstellungen/uid'), isFalse);

    // Erst der neue Code, dann die Kasse.
    expect(find.text('NUR JETZT SICHTBAR'), findsOneWidget);
    await tippen(tester, 'Ich habe den Code sicher gespeichert');
    await tippen(tester, 'WEITER');
    expect(find.text('STRICHLISTE'), findsOneWidget);
  });

  testWidgets('als neues Mitglied, vergebener Name abgelehnt (UC-04)', (
    tester,
  ) async {
    final db = await starten(tester);
    await codeEingeben(tester, code);
    await tippen(tester, 'Ich bin neu dabei');
    await tester.enterText(find.byType(TextField), 'jonas  weber');
    await tippen(tester, 'ADMIN WERDEN');
    expect(
      find.text(
        'Den Namen gibt es in der Kasse schon. Bist du das, wähl ihn oben aus.',
      ),
      findsOneWidget,
    );
    expect(db.docs['kassen/k2']!['adminUid'], 'alt');

    await tester.enterText(find.byType(TextField), 'Paula Neu');
    await tippen(tester, 'ADMIN WERDEN');
    final k = db.docs['kassen/k2']!;
    expect([k['adminUid'], k['kassenwartUid']], ['uid', 'alt']);
    expect(k['anzahlBierwarte'], 3);
    expect(db.docs.containsKey('kassen/k2/bierwarte/alt'), isTrue);
    expect(find.text('NUR JETZT SICHTBAR'), findsOneWidget);
  });

  testWidgets('ohne Netz meldet sich die Wiederherstellung (NFA-10)', (
    tester,
  ) async {
    final db = kasse()
      ..serverFehler = FirebaseException(plugin: 'test', code: 'unavailable');
    await starten(tester, db: db);
    await codeEingeben(tester, code);
    expect(find.text('Dafür brauchst du Netz.'), findsOneWidget);
    expect(db.batches, isEmpty);
  });

  testWidgets('falsches Format sagt, wie der Code aussieht', (tester) async {
    await starten(tester);
    await codeEingeben(tester, 'K7QM');
    expect(
      find.text('Der Code hat 16 Zeichen, z. B. K7QM-3XRA-9DWF-T2HC.'),
      findsOneWidget,
    );
  });
}
