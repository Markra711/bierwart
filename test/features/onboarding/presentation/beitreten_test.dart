import 'package:bier_wart/src/core/fehler/verwaltung.dart';

import 'dart:async';

import 'package:bier_wart/src/core/routing/router.dart';
import 'package:bier_wart/src/features/onboarding/domain/einladung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/app.dart';

const code = 'K7Q2MXA93DWFT2HC8RNP';

Einladung einladung({
  bool ersetzt = false,
  Duration alter = const Duration(days: 1),
}) => Einladung(
  code: code,
  kasseId: 'k1',
  kassenName: 'SV Eichwald · 1. Herren',
  anzahlBierwarte: 3,
  erstelltAm: DateTime.now().subtract(alter),
  ersetzt: ersetzt,
);

Future<void> tippen(WidgetTester tester, String text) async {
  final ziel = find.text(text.toUpperCase()).last;
  await tester.ensureVisible(ziel);
  await tester.tap(ziel);
  await tester.pumpAndSettle();
}

Future<FakeKasseRepository> starten(
  WidgetTester tester, {
  Einladung? mit,
}) async {
  telefon(tester);
  final repo = await appStarten(tester);
  if (mit != null) repo.einladungen[code] = mit;
  return repo;
}

/// Öffnet „Kasse beitreten?“ wie ein Link mit Code.
Future<void> mitCode(WidgetTester tester, String pfad) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .go(Routen.mitCode(pfad, code));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Link einfügen erkennt den Code beim Tippen', (tester) async {
    await starten(tester, mit: einladung());
    await tippen(tester, 'Ich habe einen Einladungslink');

    final feld = find.byType(TextField);
    await tester.enterText(feld, 'K7Q2MX');
    await tester.pump();
    expect(find.text('Kein Code erkannt. Er hat 20 Zeichen.'), findsOneWidget);

    await tester.enterText(feld, 'Komm dazu: bier-wart.web.app/j/$code');
    await tester.pump();
    expect(
      find.textContaining('K7Q2-MXA9-3DWF-T2HC-8RNP', findRichText: true),
      findsOneWidget,
    );
    await tippen(tester, 'Weiter');
    expect(find.text('SV EICHWALD · 1. HERREN'), findsOneWidget);
    expect(find.text('3 Bierwarte'), findsOneWidget);
  });

  testWidgets('Beitreten bis zur Strichliste (UC-02)', (tester) async {
    final repo = await starten(tester, mit: einladung());
    await mitCode(tester, Routen.beitreten);
    await tippen(tester, 'Ja, beitreten');

    await tester.enterText(find.byType(TextField), '  Jonas Weber ');
    await tippen(tester, 'Beitreten');
    expect(repo.beitritte, ['  Jonas Weber ']);
    expect(find.text('STRICHLISTE'), findsOneWidget);
  });

  testWidgets('vergebener Name: Hinweis, anderen Namen wählen (AUTH-07)', (
    tester,
  ) async {
    final repo = await starten(tester, mit: einladung());
    repo.vergebeneNamen.add('jonas weber');
    await mitCode(tester, Routen.nameWaehlen);

    await tester.enterText(find.byType(TextField), 'jonas  WEBER');
    await tippen(tester, 'Beitreten');
    expect(
      find.textContaining(
        '„jonas WEBER“ gibt es hier schon.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(repo.beitritte, isEmpty);

    await tippen(tester, 'Anderen Namen wählen');
    await tester.enterText(find.byType(TextField), 'Jonas Becker');
    await tester.pump();
    expect(
      find.textContaining('gibt es hier schon', findRichText: true),
      findsNothing,
    );
    await tippen(tester, 'Beitreten');
    expect(repo.beitritte, ['Jonas Becker']);
  });

  testWidgets('abgelaufener Link wird abgelehnt (AUTH-08)', (tester) async {
    await starten(tester, mit: einladung(alter: const Duration(days: 8)));
    await mitCode(tester, Routen.beitreten);
    expect(find.textContaining('abgelaufen'), findsOneWidget);
    expect(find.text('JA, BEITRETEN'), findsNothing);
    await tippen(tester, 'Anderer Link');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('ersetzter Link wird abgelehnt (AUTH-08, ADM-01)', (
    tester,
  ) async {
    await starten(tester, mit: einladung(ersetzt: true));
    await mitCode(tester, Routen.beitreten);
    expect(find.textContaining('ersetzt'), findsOneWidget);
  });

  testWidgets('unbekannter Code: klare Meldung', (tester) async {
    await starten(tester);
    await mitCode(tester, Routen.beitreten);
    expect(find.textContaining('gibt es nicht'), findsOneWidget);
  });

  testWidgets('ohne Netz: Meldung und Nochmal versuchen (NFA-10)', (
    tester,
  ) async {
    final repo = await starten(tester, mit: einladung());
    repo.ladeFehler = const VerwaltungsFehler('Dafür brauchst du Netz.');
    await mitCode(tester, Routen.beitreten);
    expect(find.text('Dafür brauchst du Netz.'), findsOneWidget);

    repo.ladeFehler = null;
    await tippen(tester, 'Nochmal versuchen');
    expect(find.text('3 Bierwarte'), findsOneWidget);
  });

  testWidgets('Server lehnt ab: man bleibt bei der Namenswahl (NFA-10)', (
    tester,
  ) async {
    final repo = await starten(tester, mit: einladung());
    repo.fehler = const VerwaltungsFehler(
      'Der Server hat abgelehnt (permission-denied).',
    );
    await mitCode(tester, Routen.nameWaehlen);
    await tester.enterText(find.byType(TextField), 'Jonas Weber');
    await tippen(tester, 'Beitreten');
    expect(
      find.text('Der Server hat abgelehnt (permission-denied).'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('während des Beitritts bleibt man auf der Seite', (tester) async {
    final repo = await starten(tester, mit: einladung());
    repo.halten = Completer();
    await mitCode(tester, Routen.nameWaehlen);
    await tester.enterText(find.byType(TextField), 'Jonas Weber');
    final knopf = find.text('BEITRETEN').last;
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.halten!.complete();
    await tester.pumpAndSettle();
    expect(find.text('STRICHLISTE'), findsOneWidget);
  });
}
