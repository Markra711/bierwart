import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Liefert die Schriften für `display` (Barlow Condensed) und `body` (Barlow).
/// Tests nutzen [BwFonts.plain], damit nichts aus dem Netz geladen wird.
class BwFonts {
  const BwFonts({required this.display, required this.body});

  final TextStyle Function(TextStyle) display;
  final TextStyle Function(TextStyle) body;

  static const google = BwFonts(display: _barlowCondensed, body: _barlow);
  static const plain = BwFonts(display: _unchanged, body: _unchanged);

  static TextStyle _barlowCondensed(TextStyle s) =>
      GoogleFonts.barlowCondensed(textStyle: s);
  static TextStyle _barlow(TextStyle s) => GoogleFonts.barlow(textStyle: s);
  static TextStyle _unchanged(TextStyle s) => s;
}

/// Die Textstile aus tokens.json, über `Theme.of(context).extension<BwTextStyles>()`.
@immutable
class BwTextStyles extends ThemeExtension<BwTextStyles> {
  const BwTextStyles({
    required this.outlineNumeral,
    required this.screenTitle,
    required this.pageTitle,
    required this.amountXl,
    required this.amountL,
    required this.amountM,
    required this.label,
    required this.button,
    required this.name,
    required this.body,
    required this.caption,
  });

  factory BwTextStyles.from(BwFonts fonts) {
    TextStyle style(
      BwTextToken t, {
      Color color = BwColors.ink,
      bool tabular = false,
    }) {
      final base = TextStyle(
        fontSize: t.fontSize,
        height: t.lineHeight / t.fontSize,
        fontWeight: FontWeight.values.firstWhere(
          (w) => w.value == t.fontWeight,
        ),
        letterSpacing: t.letterSpacingEm * t.fontSize,
        color: color,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );
      return t.family == BwFamily.display
          ? fonts.display(base)
          : fonts.body(base);
    }

    return BwTextStyles(
      outlineNumeral: style(BwType.outlineNumeral, color: BwColors.line),
      screenTitle: style(BwType.screenTitle),
      pageTitle: style(BwType.pageTitle),
      amountXl: style(BwType.amountXl, tabular: true),
      amountL: style(BwType.amountL, tabular: true),
      amountM: style(BwType.amountM, tabular: true),
      label: style(BwType.label, color: BwColors.inkMuted),
      button: style(BwType.button),
      name: style(BwType.name),
      body: style(BwType.body),
      caption: style(BwType.caption, color: BwColors.inkMuted),
    );
  }

  final TextStyle outlineNumeral;
  final TextStyle screenTitle;
  final TextStyle pageTitle;
  final TextStyle amountXl;
  final TextStyle amountL;
  final TextStyle amountM;
  final TextStyle label;
  final TextStyle button;
  final TextStyle name;
  final TextStyle body;
  final TextStyle caption;

  @override
  BwTextStyles copyWith() => this;

  @override
  BwTextStyles lerp(BwTextStyles? other, double t) => this;
}

/// Das dunkle Theme (Release 1 kennt nur dunkel, ADR-0005).
ThemeData buildBierwartTheme({BwFonts fonts = BwFonts.google}) {
  final text = BwTextStyles.from(fonts);
  const scheme = ColorScheme.dark(
    primary: BwColors.gradEnd,
    onPrimary: BwColors.onAccent,
    secondary: BwColors.gradStart,
    onSecondary: BwColors.onAccent,
    surface: BwColors.bg,
    onSurface: BwColors.ink,
    onSurfaceVariant: BwColors.inkMuted,
    error: BwColors.negative,
    onError: BwColors.onAccent,
    outline: BwColors.lineStrong,
    outlineVariant: BwColors.line,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: BwColors.bg,
    textTheme: TextTheme(
      headlineLarge: text.screenTitle,
      headlineMedium: text.pageTitle,
      titleMedium: text.name,
      bodyMedium: text.body,
      bodySmall: text.caption,
      labelLarge: text.button,
      labelSmall: text.label,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BwColors.surfaceFloat,
      contentTextStyle: text.body,
      actionTextColor: BwColors.gradEnd,
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: BwColors.surfaceFloat,
      modalBarrierColor: Color(0x99000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BwRadius.xl)),
      ),
    ),
    dividerColor: BwColors.line,
    extensions: [text],
  );
}
