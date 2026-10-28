import 'package:bier_wart/src/core/money/cents.dart';
import 'package:bier_wart/src/features/einstellungen/domain/bierwart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/datenbank.dart';
import 'einstellungen_test.dart' show kasse, oeffnen, tippen;

final willkommen = find.text('Ich habe einen Einladungslink'.toUpperCase());

/// Tobias ohne Rolle und mit leerem Portemonnaie; Jonas ist Admin und
/// Kassenwart.
FakeDatenbank ohneRolle() =>
    kasse(admin: 'jonas', kassenwart: 'jonas')
      ..ort('k1', 'uid', 'Tobias Meier');

void main() {
  testWidgets('mit Geld im Portemonnaie nicht austreten (AUTH-09)', (
    tester,
  ) async {
    final db = await oeffnen(
      tester,
      db: kasse(admin: 'jonas', kassenwart: 'jonas'),
    );
    await tippen(tester, 'AUSTRETEN');
    expect(
      find.text(
        'In deinem Portemonnaie sind noch ${formatEuro(4100)}. Gib sie erst '
        'dem Kassenwart.',
      ),
      findsOneWidget,
    );
    expect(db.batches, isEmpty);
  });

  testWidgets('als Admin erst die Rolle übergeben (AUTH-09)', (tester) async {
    final db = kasse()..ort('k1', 'uid', 'Tobias Meier');
    await oeffnen(tester, db: db);
    await tippen(tester, 'AUSTRETEN');
    expect(find.text('Übergib erst die Admin-Rolle.'), findsOneWidget);
    expect(db.batches, isEmpty);
  });

  testWidgets('austreten, danach ohne Kasse und ohne Konto (UC-05, AUTH-15)', (
    tester,
  ) async {
    final konto = FakeKonto();
    final db = await oeffnen(tester, db: ohneRolle(), konto: konto);
    await tippen(tester, 'AUSTRETEN');
    expect(find.text('Austreten?'), findsOneWidget);
    expect(find.textContaining(austretenLoeschtKonto), findsOneWidget);
    await tippen(tester, 'AUSTRETEN');

    expect(konto.geloescht, 1);
    final log = db.batches.last.last.daten;
    expect(log['typ'], 'ausgetreten');
    expect(db.docs.containsKey('kassen/k1/bierwarte/uid'), isFalse);
    expect(db.docs['kassen/k1']!['anzahlBierwarte'], 2);
    expect(db.docs['kassen/k1/mitglieder/uid'], isNotNull);
    expect(willkommen, findsOneWidget);
  });

  testWidgets('Auflösen nur mit abgetipptem Namen, dann ist alles weg '
      '(ADM-05, UC-10, AUTH-15)', (tester) async {
    final konto = FakeKonto();
    final db = await oeffnen(tester, konto: konto);
    expect(find.text('KASSE AUFLÖSEN'), findsOneWidget);
    await tippen(tester, 'KASSE AUFLÖSEN');
    final feld = find.byType(TextField);
    await tester.enterText(feld, 'SV Tes');
    await tippen(tester, 'KASSE AUFLÖSEN');
    expect(db.batches, isEmpty);

    await tester.enterText(feld, 'SV Test');
    await tippen(tester, 'KASSE AUFLÖSEN');

    expect(db.batches.first.last.daten['typ'], 'kasseAufgeloest');
    expect(db.docs.keys.where((p) => p.startsWith('kassen/k1')), isEmpty);
    expect(db.docs.containsKey('einladungen/K7Q2MXA93DWFT2HC8RNP'), isFalse);
    expect(konto.geloescht, 1);
    expect(willkommen, findsOneWidget);
  });

  testWidgets('ein abgebrochenes Auflösen geht beim Start weiter', (
    tester,
  ) async {
    telefon(tester);
    final db = kasse()..docs['kassen/k1']!['aufgeloest'] = true;
    await appStarten(tester, kasseId: 'k1', db: db);
    expect(db.docs.keys.where((p) => p.startsWith('kassen/k1')), isEmpty);
    expect(willkommen, findsOneWidget);
  });

  testWidgets('ohne Netz bleibt das Auflösen stehen und meldet sich', (
    tester,
  ) async {
    telefon(tester);
    final db = kasse()
      ..docs['kassen/k1']!['aufgeloest'] = true
      ..serverFehler = FirebaseException(plugin: 'test', code: 'unavailable');
    await appStarten(tester, kasseId: 'k1', db: db);
    expect(find.text('Dafür brauchst du Netz.'), findsOneWidget);
    expect(find.text('WEITER LÖSCHEN'), findsOneWidget);

    db.serverFehler = null;
    await tippen(tester, 'WEITER LÖSCHEN');
    expect(willkommen, findsOneWidget);
  });
}
