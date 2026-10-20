// Design-Tokens aus docs/design/tokens.json (Bierwart Design System).
// Bei Änderungen beide Dateien anpassen; test/core/theme/tokens_test.dart
// prüft, dass sie übereinstimmen.
import 'package:flutter/painting.dart';

abstract final class BwColors {
  static const bg = Color(0xFF25272C);
  static const shadowDark = Color(0xFF18191D);
  static const shadowLight = Color(0xFF32353B);
  static const surfaceFloat = Color(0xFF2C2F35);
  static const ink = Color(0xFFF1EEE9);
  static const inkMuted = Color(0xFFA3A09B);
  static const inkFaint = Color(0xFF6E7179);
  static const line = Color(0xFF3A3D44);
  static const lineStrong = Color(0xFF5A5D64);
  static const gradStart = Color(0xFFFF4D86);
  static const gradEnd = Color(0xFFFFA24A);
  static const onAccent = Color(0xFF1E1F23);
  static const positive = Color(0xFF7CD39A);
  static const negative = Color(0xFFFF6F8F);
  static const handle = Color(0xFFF1EEE9);
}

abstract final class BwSpacing {
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
}

abstract final class BwRadius {
  static const sm = 6.0;
  static const md = 16.0;
  static const lg = 18.0;
  static const xl = 26.0;
  static const pill = 999.0;
}

/// Ein Schatten aus tokens.json. Flutter kann `inset` nicht nativ zeichnen,
/// deshalb bleiben eingedrückte Schatten Daten, bis es einen Painter gibt.
class NeuShadow {
  const NeuShadow(
    this.dx,
    this.dy,
    this.blur,
    this.color, {
    this.inset = false,
  });

  final double dx;
  final double dy;
  final double blur;
  final Color color;
  final bool inset;

  BoxShadow toBoxShadow() {
    assert(!inset, 'Innere Schatten lassen sich nicht als BoxShadow zeichnen.');
    return BoxShadow(offset: Offset(dx, dy), blurRadius: blur, color: color);
  }
}

abstract final class BwShadows {
  static const raised = [
    NeuShadow(5, 5, 12, BwColors.shadowDark),
    NeuShadow(-5, -5, 12, BwColors.shadowLight),
  ];
  static const raisedSm = [
    NeuShadow(4, 4, 10, BwColors.shadowDark),
    NeuShadow(-4, -4, 10, BwColors.shadowLight),
  ];
  static const raisedLg = [
    NeuShadow(7, 7, 16, BwColors.shadowDark),
    NeuShadow(-7, -7, 16, BwColors.shadowLight),
  ];
  static const inset = [
    NeuShadow(4, 4, 9, BwColors.shadowDark, inset: true),
    NeuShadow(-4, -4, 9, BwColors.shadowLight, inset: true),
  ];
  static const insetSm = [
    NeuShadow(3, 3, 7, BwColors.shadowDark, inset: true),
    NeuShadow(-3, -3, 7, BwColors.shadowLight, inset: true),
  ];
  static const track = [
    NeuShadow(2, 2, 4, BwColors.shadowDark, inset: true),
    NeuShadow(-2, -2, 4, BwColors.shadowLight, inset: true),
  ];
  static const float = [
    NeuShadow(6, 6, 14, BwColors.shadowDark),
    NeuShadow(-4, -4, 10, BwColors.shadowLight),
  ];

  static List<BoxShadow> boxShadows(List<NeuShadow> shadows) => [
    for (final s in shadows) s.toBoxShadow(),
  ];
}

abstract final class BwGradients {
  /// `linear-gradient(100deg, …)`: CSS-Winkel 100° zeigt nach rechts und
  /// leicht nach unten (sin 100° ≈ 0,985, −cos 100° ≈ 0,174).
  static const accent = LinearGradient(
    begin: Alignment(-0.985, -0.174),
    end: Alignment(0.985, 0.174),
    colors: [BwColors.gradStart, BwColors.gradEnd],
  );
}

enum BwFamily { display, body }

/// Ein Textstil aus tokens.json, noch ohne konkrete Schrift.
class BwTextToken {
  const BwTextToken({
    required this.family,
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    this.letterSpacingEm = 0,
  });

  final BwFamily family;
  final double fontSize;
  final double lineHeight;
  final int fontWeight;
  final double letterSpacingEm;
}

abstract final class BwType {
  static const outlineNumeral = BwTextToken(
    family: BwFamily.display,
    fontSize: 132,
    lineHeight: 132,
    fontWeight: 300,
  );
  static const screenTitle = BwTextToken(
    family: BwFamily.display,
    fontSize: 42,
    lineHeight: 42,
    fontWeight: 700,
    letterSpacingEm: 0.02,
  );
  static const pageTitle = BwTextToken(
    family: BwFamily.display,
    fontSize: 28,
    lineHeight: 32,
    fontWeight: 700,
    letterSpacingEm: 0.02,
  );
  static const amountXl = BwTextToken(
    family: BwFamily.display,
    fontSize: 52,
    lineHeight: 54,
    fontWeight: 700,
  );
  static const amountL = BwTextToken(
    family: BwFamily.display,
    fontSize: 24,
    lineHeight: 28,
    fontWeight: 600,
  );
  static const amountM = BwTextToken(
    family: BwFamily.display,
    fontSize: 20,
    lineHeight: 24,
    fontWeight: 600,
  );
  static const label = BwTextToken(
    family: BwFamily.body,
    fontSize: 11,
    lineHeight: 14,
    fontWeight: 700,
    letterSpacingEm: 0.14,
  );
  static const button = BwTextToken(
    family: BwFamily.body,
    fontSize: 12,
    lineHeight: 16,
    fontWeight: 800,
    letterSpacingEm: 0.1,
  );
  static const name = BwTextToken(
    family: BwFamily.body,
    fontSize: 14,
    lineHeight: 18,
    fontWeight: 800,
  );
  static const body = BwTextToken(
    family: BwFamily.body,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: 500,
  );
  static const caption = BwTextToken(
    family: BwFamily.body,
    fontSize: 12,
    lineHeight: 17,
    fontWeight: 600,
  );
}
