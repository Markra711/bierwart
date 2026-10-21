import 'package:bier_wart/src/core/theme/app_theme.dart';
import 'package:bier_wart/src/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app.dart';

void main() {
  testWidgets('App startet im dunklen Bierwart-Theme', (tester) async {
    await appStarten(tester, kasseId: 'k1');

    expect(find.text('BIERWART'), findsOneWidget);
    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, BwColors.bg);
    expect(theme.extension<BwTextStyles>(), isNotNull);
  });

  test('Beträge nutzen Tabellenziffern', () {
    final text = BwTextStyles.from(BwFonts.plain);
    for (final s in [text.amountXl, text.amountL, text.amountM]) {
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });
}
