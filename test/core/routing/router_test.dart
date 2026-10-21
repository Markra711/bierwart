import 'package:bier_wart/src/core/routing/router.dart';
import 'package:bier_wart/src/features/onboarding/application/onboarding.dart';
import 'package:bier_wart/src/features/onboarding/domain/erstellte_kasse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app.dart';

void main() {
  group('Weiterleitung', () {
    const neu = ErstellteKasse(
      kasseId: 'k1',
      mitgliedId: 'm1',
      buchungId: 'l1',
      kassenName: 'SV Test',
      eigenerName: 'Lena Koch',
      startCents: 0,
      wiederherstellungscode: 'K7QM3XRA9DWFT2HC',
      einladungscode: 'K7Q2MXA93DWFT2HC8RNP',
    );

    test('ohne Anmeldung auf den Ladebildschirm (AUTH-01)', () {
      expect(weiterleitung(const StartLaedt(), null, '/'), Routen.laden);
      expect(weiterleitung(const StartFehler('x'), null, '/'), Routen.laden);
      expect(weiterleitung(const StartLaedt(), null, Routen.laden), isNull);
    });

    test('ohne Kasse ins Onboarding', () {
      expect(weiterleitung(const OhneKasse(), null, '/'), Routen.willkommen);
      expect(
        weiterleitung(const OhneKasse(), null, Routen.kasseErstellen),
        isNull,
      );
      expect(
        weiterleitung(const OhneKasse(), null, Routen.einladen),
        Routen.willkommen,
      );
    });

    test('ohne Kasse auch die Seiten zum Beitreten (UC-02)', () {
      for (final ort in [
        Routen.linkEinfuegen,
        Routen.beitreten,
        Routen.nameWaehlen,
      ]) {
        expect(weiterleitung(const OhneKasse(), null, ort), isNull);
        expect(
          weiterleitung(const InKasse('k1'), null, ort),
          Routen.strichliste,
        );
      }
    });

    test('während des Beitritts auf der Namenswahl bleiben', () {
      expect(
        weiterleitung(
          const InKasse('k1'),
          null,
          Routen.nameWaehlen,
          beitrittLaeuft: true,
        ),
        isNull,
      );
    });

    test('mit Kasse auf die Strichliste (UI-01)', () {
      expect(weiterleitung(const InKasse('k1'), null, '/'), isNull);
      expect(
        weiterleitung(const InKasse('k1'), null, Routen.willkommen),
        Routen.strichliste,
      );
    });

    test('beim Erstellen auf der Seite bleiben, auch wenn die Kasse schon '
        'lokal sichtbar ist', () {
      expect(
        weiterleitung(const InKasse('k1'), neu, Routen.kasseErstellen),
        isNull,
      );
      expect(
        weiterleitung(const InKasse('k1'), neu, '/'),
        Routen.kasseErstellen,
      );
    });

    test('nach dem Speichern erst Code und Einladung (AUTH-03)', () {
      final gespeichert = neu.alsGespeichert();
      expect(
        weiterleitung(const InKasse('k1'), gespeichert, Routen.kasseErstellen),
        Routen.wiederherstellungscode,
      );
      expect(
        weiterleitung(const InKasse('k1'), gespeichert, Routen.einladen),
        isNull,
      );
      expect(
        weiterleitung(const InKasse('k1'), gespeichert, '/'),
        Routen.wiederherstellungscode,
      );
    });
  });

  testWidgets('startet mit Kasse auf der Strichliste (UI-01)', (tester) async {
    await appStarten(tester, kasseId: 'k1');
    expect(find.text('BIERWART'), findsOneWidget);
  });

  testWidgets(
    'unbekannter Pfad zeigt eine Meldung statt leerer Seite (NFA-10)',
    (tester) async {
      await appStarten(tester, kasseId: 'k1');
      GoRouter.of(tester.element(find.text('BIERWART'))).go('/gibt-es-nicht');
      await tester.pumpAndSettle();
      expect(find.text('NICHT GEFUNDEN'), findsOneWidget);

      await tester.tap(find.text('ZUR STRICHLISTE'));
      await tester.pumpAndSettle();
      expect(find.text('BIERWART'), findsOneWidget);
    },
  );
}
