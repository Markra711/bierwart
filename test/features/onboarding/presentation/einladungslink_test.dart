import 'package:bier_wart/src/features/onboarding/domain/einladung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app.dart';
import '../../../helpers/links.dart';

const code = 'K7Q2MXA93DWFT2HC8RNP';
const link = 'https://bier-wart.web.app/j/$code';

final einladung = Einladung(
  code: code,
  kasseId: 'k1',
  kassenName: 'SV Eichwald',
  anzahlBierwarte: 2,
  erstelltAm: DateTime.now().subtract(const Duration(hours: 1)),
  ersetzt: false,
);

Future<void> tippen(WidgetTester tester, String text) async {
  final ziel = find.text(text.toUpperCase()).last;
  await tester.ensureVisible(ziel);
  await tester.tap(ziel);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Link bei offener App öffnet „Kasse beitreten?“ (AUTH-04)', (
    tester,
  ) async {
    telefon(tester);
    final links = FakeLinkQuelle();
    final repo = await appStarten(tester, links: links);
    repo.einladungen[code] = einladung;
    expect(find.text('KASSE ERSTELLEN'), findsOneWidget);

    links.oeffnen(link);
    await tester.pumpAndSettle();
    expect(find.text('SV EICHWALD'), findsOneWidget);
    expect(find.text('2 Bierwarte'), findsOneWidget);
  });

  testWidgets('gemerkter Code führt nach dem Start dorthin (AUTH-06)', (
    tester,
  ) async {
    telefon(tester);
    final speicher = FakeCodeSpeicher(code: code);
    final links = FakeLinkQuelle();
    await appStarten(tester, links: links, speicher: speicher);
    expect(find.text('EINLADUNG'), findsOneWidget);
  });

  testWidgets('Code aus dem Play Store nach der Installation (AUTH-12)', (
    tester,
  ) async {
    telefon(tester);
    final links = FakeLinkQuelle(referrer: 'code=$code');
    await appStarten(tester, links: links);
    expect(find.text('EINLADUNG'), findsOneWidget);
  });

  testWidgets('„Nein“ verwirft den Code, Willkommen bleibt', (tester) async {
    telefon(tester);
    final speicher = FakeCodeSpeicher();
    final links = FakeLinkQuelle();
    final repo = await appStarten(tester, links: links, speicher: speicher);
    repo.einladungen[code] = einladung;
    links.oeffnen(link);
    await tester.pumpAndSettle();

    await tippen(tester, 'Nein');
    expect(find.text('KASSE ERSTELLEN'), findsOneWidget);
    expect(speicher.code, isNull);
  });

  testWidgets('Beitritt per Link verwirft den Code danach', (tester) async {
    telefon(tester);
    final speicher = FakeCodeSpeicher();
    final links = FakeLinkQuelle();
    final repo = await appStarten(tester, links: links, speicher: speicher);
    repo.einladungen[code] = einladung;
    links.oeffnen(link);
    await tester.pumpAndSettle();

    await tippen(tester, 'Ja, beitreten');
    await tester.enterText(find.byType(TextField), 'Jonas Weber');
    await tippen(tester, 'Beitreten');
    expect(find.text('Hier entsteht die Strichliste.'), findsOneWidget);
    expect(speicher.code, isNull);
  });

  testWidgets('wer schon in einer Kasse ist, bleibt auf der Strichliste', (
    tester,
  ) async {
    telefon(tester);
    final speicher = FakeCodeSpeicher();
    final links = FakeLinkQuelle();
    await appStarten(tester, kasseId: 'k1', links: links, speicher: speicher);

    links.oeffnen(link);
    await tester.pumpAndSettle();
    expect(find.text('Hier entsteht die Strichliste.'), findsOneWidget);
    expect(speicher.code, isNull);
  });
}
