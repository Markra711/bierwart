import 'dart:async';

import 'package:bier_wart/src/core/widgets/eingaben.dart';
import 'package:bier_wart/src/features/onboarding/data/kasse_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';

Future<void> ausfuellen(
  WidgetTester tester, {
  String kasse = 'SV Eichwald',
  String name = 'Tobias Meier',
  String start = '50',
}) async {
  final felder = find.descendant(
    of: find.byType(BwFeld),
    matching: find.byType(TextField),
  );
  await tester.enterText(felder.at(0), kasse);
  await tester.enterText(felder.at(1), name);
  await tester.enterText(felder.at(2), start);
}

Future<void> tippen(WidgetTester tester, String text) async {
  final ziel = find.text(text.toUpperCase());
  await tester.ensureVisible(ziel.last);
  await tester.tap(ziel.last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});

  testWidgets('ohne Kasse startet das Onboarding mit Willkommen', (
    tester,
  ) async {
    telefon(tester);
    await appStarten(tester);
    expect(find.bySemanticsLabel('Bierwart'), findsOneWidget);
    expect(find.text('KASSE ERSTELLEN'), findsOneWidget);
    expect(find.text('ICH HABE EINEN EINLADUNGSLINK'), findsOneWidget);
  });

  testWidgets('Kasse erstellen: Code, Einladung, Strichliste (UC-01)', (
    tester,
  ) async {
    telefon(tester);
    final repo = await appStarten(tester);
    await tippen(tester, 'Kasse erstellen');
    expect(find.text('KASSE '), findsNothing);

    await ausfuellen(tester, kasse: '  SV Eichwald ', start: '50,00 €');
    await tippen(tester, 'Kasse erstellen');

    expect(repo.aufrufe.single.startCents, 5000);
    expect(repo.aufrufe.single.kassenName, '  SV Eichwald ');
    // Wiederherstellungscode (AUTH-03)
    expect(find.text('K7QM-3XRA-9DWF-T2HC'), findsOneWidget);
    await tippen(tester, 'Weiter');
    expect(
      find.text('K7QM-3XRA-9DWF-T2HC'),
      findsOneWidget,
      reason: 'erst bestätigen',
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tippen(tester, 'Weiter');

    // Einladen
    expect(find.text('K7Q2-MXA9-3DWF-T2HC-8RNP'), findsOneWidget);
    expect(find.textContaining('7 Tage gültig'), findsOneWidget);
    await tippen(tester, 'Weiter zur Strichliste');
    expect(find.text('STRICHLISTE'), findsOneWidget);
  });

  testWidgets('Pflichtfelder und Betrag werden geprüft', (tester) async {
    telefon(tester);
    final repo = await appStarten(tester);
    await tippen(tester, 'Kasse erstellen');
    await ausfuellen(tester, kasse: ' ', name: '', start: '12,345');
    await tippen(tester, 'Kasse erstellen');

    expect(find.text('Bitte einen Namen eingeben.'), findsNWidgets(2));
    expect(find.text('Betrag wie 50,00 eingeben.'), findsOneWidget);
    expect(repo.aufrufe, isEmpty);
  });

  testWidgets('leerer Startbetrag ist 0,00 €', (tester) async {
    telefon(tester);
    final repo = await appStarten(tester);
    await tippen(tester, 'Kasse erstellen');
    await ausfuellen(tester, start: '');
    await tippen(tester, 'Kasse erstellen');
    expect(repo.aufrufe.single.startCents, 0);
  });

  testWidgets('Fehler wird angezeigt, man bleibt im Formular (NFA-10)', (
    tester,
  ) async {
    telefon(tester);
    final repo = await appStarten(tester);
    repo.fehler = const VerwaltungsFehler('Dafür brauchst du Netz.');
    await tippen(tester, 'Kasse erstellen');
    await ausfuellen(tester);
    await tippen(tester, 'Kasse erstellen');

    expect(find.text('Dafür brauchst du Netz.'), findsOneWidget);
    expect(find.byType(BwFeld), findsNWidgets(3));
  });

  testWidgets('während des Speicherns bleibt man im Formular', (tester) async {
    telefon(tester);
    final repo = await appStarten(tester);
    repo.halten = Completer();
    await tippen(tester, 'Kasse erstellen');
    await ausfuellen(tester);
    final knopf = find.text('KASSE ERSTELLEN').last;
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('K7QM-3XRA-9DWF-T2HC'), findsNothing);

    repo.halten!.complete();
    await tester.pumpAndSettle();
    expect(find.text('K7QM-3XRA-9DWF-T2HC'), findsOneWidget);
  });

  testWidgets('Anmeldung ohne Netz: Meldung und Nochmal (AUTH-01, NFA-10)', (
    tester,
  ) async {
    telefon(tester);
    await appStarten(
      tester,
      anmeldeFehler: FirebaseAuthException(code: 'network-request-failed'),
    );
    expect(find.text('Für den ersten Start brauchst du Netz.'), findsOneWidget);
    expect(find.text('NOCHMAL VERSUCHEN'), findsOneWidget);
  });
}
