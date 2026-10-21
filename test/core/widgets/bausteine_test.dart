import 'package:bier_wart/src/core/theme/app_theme.dart';
import 'package:bier_wart/src/core/theme/tokens.dart';
import 'package:bier_wart/src/core/widgets/flaechen.dart';
import 'package:bier_wart/src/core/widgets/knoepfe.dart';
import 'package:bier_wart/src/core/widgets/seite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> zeigen(WidgetTester tester, Widget kind) => tester.pumpWidget(
  MaterialApp(
    theme: buildBierwartTheme(fonts: BwFonts.plain),
    home: Scaffold(body: Center(child: kind)),
  ),
);

void main() {
  group('BwKnopf', () {
    testWidgets('Text in Großbuchstaben, Tippen löst aus', (tester) async {
      var getippt = 0;
      await zeigen(tester, BwKnopf(text: 'Weiter', onPressed: () => getippt++));
      await tester.tap(find.text('WEITER'));
      expect(getippt, 1);
      expect(tester.getSize(find.byType(BwKnopf)).height, BwKnopf.hoehe);
    });

    testWidgets('ohne Aktion deaktiviert und gestrichelt', (tester) async {
      await zeigen(tester, const BwKnopf(text: 'Weiter', onPressed: null));
      expect(
        find.descendant(
          of: find.byType(BwKnopf),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is GestricheltPainter,
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(BwKnopf)),
        isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
      );
    });

    testWidgets('lädt: Fortschritt statt Text, kein zweites Tippen', (
      tester,
    ) async {
      var getippt = 0;
      await zeigen(
        tester,
        BwKnopf(text: 'Weiter', laedt: true, onPressed: () => getippt++),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(BwKnopf));
      expect(getippt, 0);
    });

    testWidgets('groß für die Hauptaktion im Onboarding', (tester) async {
      await zeigen(
        tester,
        BwKnopf(text: 'Weiter', gross: true, onPressed: () {}),
      );
      expect(tester.getSize(find.byType(BwKnopf)).height, BwKnopf.hoeheGross);
    });
  });

  testWidgets('Icon-Button hat ein Label und 46px', (tester) async {
    await zeigen(tester, BwZurueck(onPressed: () {}));
    expect(find.bySemanticsLabel('Zurück'), findsOneWidget);
    expect(tester.getSize(find.byType(BwIconKnopf)), const Size.square(46));
  });

  testWidgets('Eingedrückte Fläche zeichnet innere Schatten aus den Tokens', (
    tester,
  ) async {
    await zeigen(tester, const BwEingedrueckt(child: Text('0,00 €')));
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(BwEingedrueckt),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as InnenschattenPainter;
    expect(painter.schatten, BwShadows.inset);
    expect(painter.schatten.every((s) => s.inset), isTrue);
  });

  testWidgets('Titel: Großbuchstaben, als Überschrift', (tester) async {
    await zeigen(tester, const BwTitel(voll: 'Kasse', kontur: 'erstellen'));
    expect(find.text('KASSE ERSTELLEN'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(BwTitel)),
      isSemantics(isHeader: true),
    );
  });

  test('Kontur hat keine Füllfarbe, sonst scheitert Flutters Assertion', () {
    final stil = alsKontur(const TextStyle(color: BwColors.ink, fontSize: 42));
    expect(stil.color, isNull);
    expect(stil.foreground!.style, PaintingStyle.stroke);
    expect(stil.fontSize, 42);
  });
}
