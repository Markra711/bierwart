import 'package:bier_wart/src/app.dart';
import 'package:bier_wart/src/core/routing/router.dart';
import 'package:bier_wart/src/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> starten(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BierwartApp(fonts: BwFonts.plain),
      ),
    );
    return container;
  }

  testWidgets('startet auf der Strichliste (UI-01)', (tester) async {
    await starten(tester);
    expect(find.text('BIERWART'), findsOneWidget);
  });

  testWidgets(
    'unbekannter Pfad zeigt eine Meldung statt leerer Seite (NFA-10)',
    (tester) async {
      final container = await starten(tester);
      container.read(routerProvider).go('/gibt-es-nicht');
      await tester.pumpAndSettle();
      expect(find.text('NICHT GEFUNDEN'), findsOneWidget);

      await tester.tap(find.text('ZUR STRICHLISTE'));
      await tester.pumpAndSettle();
      expect(find.text('BIERWART'), findsOneWidget);
    },
  );
}
