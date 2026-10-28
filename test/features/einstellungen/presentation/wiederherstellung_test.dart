import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/datenbank.dart';
import 'einstellungen_test.dart' show kasse, oeffnen, tippen;

const code = 'ABCD1234EFGH5678';

/// Kasse mit Wiederherstellungscode [code]; ohne Angabe ist Jonas Admin und
/// Kassenwart, Tobias (du) normaler Bierwart.
FakeDatenbank mitCode({String admin = 'jonas'}) =>
    kasse(admin: admin, kassenwart: 'jonas')
      ..docs['kassen/k1']!['wiederherstellungHash'] = Bytes(hashVon(code))
      ..docs['wiederherstellung/${hexVon(hashVon(code))}'] = {'kasseId': 'k1'};

String hashHex(FakeDatenbank db) =>
    hexVon((db.docs['kassen/k1']!['wiederherstellungHash']! as Bytes).wert);

Future<void> eingeben(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tippen(tester, 'ADMIN WERDEN');
}

void main() {
  testWidgets('mit dem Code Admin werden, der neue wird einmal gezeigt '
      '(ADM-06)', (tester) async {
    final db = await oeffnen(tester, db: mitCode());
    expect(find.textContaining('Neuer Wiederherstellungs'), findsNothing);
    await tippen(tester, 'Wiederherstellungs­code eingeben');

    await eingeben(tester, 'K7QM');
    expect(
      find.text('Der Code hat 16 Zeichen, z. B. K7QM-3XRA-9DWF-T2HC.'),
      findsOneWidget,
    );
    await eingeben(tester, 'AAAA-BBBB-CCCC-DDDD');
    expect(find.text('Der Code passt nicht zu dieser Kasse.'), findsOneWidget);
    expect(db.batches, isEmpty);

    await eingeben(tester, 'abcd-1234-efgh-5678');
    final kasse = db.docs['kassen/k1']!;
    expect(kasse['adminUid'], 'uid');
    expect(kasse['kassenwartUid'], 'jonas');
    expect(hashHex(db), isNot(hexVon(hashVon(code))));
    expect(
      db.docs.containsKey('wiederherstellung/${hexVon(hashVon(code))}'),
      isFalse,
    );
    expect(db.batches.last.last.daten['nachweis'], code);

    expect(find.text('NUR JETZT SICHTBAR'), findsOneWidget);
    await tippen(tester, 'Ich habe den Code sicher gespeichert');
    await tippen(tester, 'WEITER');
    expect(find.text('EINSTELLUNGEN'), findsOneWidget);
    expect(find.text('ERNEUERN'), findsOneWidget);
  });

  testWidgets('Admin erzeugt einen neuen Code (ADM-08)', (tester) async {
    final db = await oeffnen(tester, db: mitCode(admin: 'uid'));
    await tippen(tester, 'Neuer Wiederherstellungs­code');
    expect(find.text('Neuen Code erzeugen?'), findsOneWidget);
    await tippen(tester, 'ERZEUGEN');

    expect(db.batches.last.last.daten['typ'], 'wiederherstellungscodeErneuert');
    expect(hashHex(db), isNot(hexVon(hashVon(code))));
    expect(find.text('NUR JETZT SICHTBAR'), findsOneWidget);
    // Weiter erst nach dem Haken.
    await tippen(tester, 'WEITER');
    expect(find.text('NUR JETZT SICHTBAR'), findsOneWidget);
  });

  testWidgets('Datenschutz erklärt, wo die Daten liegen (NFA-09)', (
    tester,
  ) async {
    await oeffnen(tester);
    await tippen(tester, 'Datenschutz');
    expect(find.text('DATENSCHUTZ'), findsOneWidget);
    expect(find.textContaining('europe-west10'), findsOneWidget);
    expect(find.textContaining('Keine E-Mail-Adresse'), findsOneWidget);
    expect(
      find.textContaining('bier-wart.web.app/datenschutz'),
      findsOneWidget,
    );
  });
}
