import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'eingaben.dart';
import 'flaechen.dart';

/// Die eine Hauptkarte einer Seite: der große Betrag in einem
/// Verlaufsrahmen, dazu eine schraffierte Kreisecke (styleguide.md, Card).
class BwHauptkarte extends StatelessWidget {
  const BwHauptkarte({
    super.key,
    required this.label,
    required this.betrag,
    this.unterzeile,
  });

  final String label;

  /// Meist `amount-xl` mit Verlauf ([BwVerlaufText]).
  final Widget betrag;
  final String? unterzeile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return BwErhaben(
      radius: BwRadius.xl,
      schatten: BwShadows.raisedLg,
      padding: const EdgeInsets.all(BwSpacing.space2),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            right: -BwSpacing.space6,
            bottom: -BwSpacing.space6,
            child: BwSchraffur(durchmesser: 110, winkel: 0),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: BwGradients.accent,
              borderRadius: BorderRadius.circular(BwRadius.lg),
            ),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(1),
              padding: const EdgeInsets.symmetric(
                horizontal: BwSpacing.space4,
                vertical: BwSpacing.space3,
              ),
              decoration: BoxDecoration(
                color: BwColors.bg,
                borderRadius: BorderRadius.circular(BwRadius.lg - 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BwLabel(label),
                  FittedBox(fit: BoxFit.scaleDown, child: betrag),
                  if (unterzeile != null)
                    Text(
                      unterzeile!,
                      style: text.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Abschnittslabel mit gestrichelter Linie (styleguide.md,
/// Wireframe-Details).
class BwAbschnitt extends StatelessWidget {
  const BwAbschnitt(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BwLabel(text),
        const SizedBox(width: BwSpacing.space2),
        const Expanded(child: BwStrichlinie()),
      ],
    );
  }
}

/// Leiser Hinweis mit kurzem Strich davor.
class BwHinweis extends StatelessWidget {
  const BwHinweis(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.caption;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: BwSpacing.space2),
          child: SizedBox(width: BwSpacing.space6, child: BwStrichlinie()),
        ),
        const SizedBox(width: BwSpacing.space2),
        Expanded(child: Text(text, style: stil)),
      ],
    );
  }
}

/// Gestrichelte Linie, 4px Strich, 4px Lücke, in `line-strong`.
class BwStrichlinie extends StatelessWidget {
  const BwStrichlinie({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: CustomPaint(painter: _Striche()));
}

class _Striche extends CustomPainter {
  const _Striche();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BwColors.lineStrong
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Striche old) => false;
}
