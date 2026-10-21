import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'flaechen.dart';

enum BwKnopfArt {
  /// Fläche im Verlauf, Text `on-accent`; höchstens einer pro Bildschirm.
  primaer,

  /// Fläche `bg`, Schatten `raised`.
  sekundaer,

  /// 1,5px Rahmen in `ink`.
  outline,

  /// Wie Outline, aber in `negative`: Entfernen, Austreten, Auflösen.
  destruktiv,
}

/// Pillen-Button (styleguide.md, Button). Ohne [onPressed] ist er
/// deaktiviert: gestrichelt in `line-strong`. Während [laedt] zeigt er einen
/// Fortschritt und nimmt keine Tipper an.
class BwKnopf extends StatelessWidget {
  const BwKnopf({
    super.key,
    required this.text,
    required this.onPressed,
    this.art = BwKnopfArt.primaer,
    this.icon,
    this.gross = false,
    this.laedt = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final BwKnopfArt art;
  final Widget? icon;

  /// 56px statt 48px: Hauptaktion der Onboarding-Bildschirme im Canvas.
  final bool gross;
  final bool laedt;

  static const hoehe = 48.0;
  static const hoeheGross = 56.0;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.button;
    final aktiv = onPressed != null && !laedt;
    final deaktiviert = onPressed == null && !laedt;
    final textFarbe = deaktiviert
        ? BwColors.inkMuted
        : switch (art) {
            BwKnopfArt.primaer => BwColors.onAccent,
            BwKnopfArt.destruktiv => BwColors.negative,
            _ => BwColors.ink,
          };
    final radius = BorderRadius.circular(BwRadius.pill);

    final inhalt = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (laedt)
          SizedBox.square(
            dimension: BwSpacing.space4,
            child: CircularProgressIndicator(strokeWidth: 2, color: textFarbe),
          )
        else ...[
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(color: textFarbe, size: 18),
              child: icon!,
            ),
            const SizedBox(width: BwSpacing.space2),
          ],
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: stil.copyWith(color: textFarbe),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ],
    );

    final Decoration? flaeche = deaktiviert
        ? null
        : switch (art) {
            BwKnopfArt.primaer => BoxDecoration(
              gradient: BwGradients.accent,
              borderRadius: radius,
            ),
            BwKnopfArt.sekundaer => BoxDecoration(
              color: BwColors.bg,
              borderRadius: radius,
              boxShadow: BwShadows.boxShadows(BwShadows.raised),
            ),
            BwKnopfArt.outline => BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: BwColors.ink, width: 1.5),
            ),
            BwKnopfArt.destruktiv => BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: BwColors.negative, width: 1.5),
            ),
          };

    return Semantics(
      button: true,
      enabled: aktiv,
      label: laedt ? '$text, läuft' : null,
      excludeSemantics: laedt,
      child: SizedBox(
        height: gross ? hoeheGross : hoehe,
        child: CustomPaint(
          painter: deaktiviert
              ? const GestricheltPainter(radius: BwRadius.pill)
              : null,
          child: DecoratedBox(
            decoration: flaeche ?? const BoxDecoration(),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: aktiv ? onPressed : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BwSpacing.space5,
                  ),
                  // Ohne feste Breite (z. B. in einer Row) so breit wie
                  // der Inhalt, sonst würde Flexible scheitern.
                  child: LayoutBuilder(
                    builder: (context, raum) => raum.hasBoundedWidth
                        ? inhalt
                        : IntrinsicWidth(child: inhalt),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Runder Icon-Button, 46px, `raised-sm` (Zurück, Schließen, Zahnrad).
class BwIconKnopf extends StatelessWidget {
  const BwIconKnopf({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  static const groesse = 46.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BwErhaben(
        radius: BwRadius.pill,
        schatten: BwShadows.raisedSm,
        child: SizedBox.square(
          dimension: groesse,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(icon, color: BwColors.ink, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zurück-Button im Kopf von Unterseiten.
class BwZurueck extends StatelessWidget {
  const BwZurueck({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => BwIconKnopf(
    icon: Icons.chevron_left_rounded,
    label: 'Zurück',
    onPressed: onPressed,
  );
}
