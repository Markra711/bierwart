import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'flaechen.dart';
import 'knoepfe.dart';

/// Schnellwahl-Chip im Sheet: erhaben, gewählt eingedrückt mit Text in
/// `grad-end` (styleguide.md, Sheet).
class BwChip extends StatelessWidget {
  const BwChip({
    super.key,
    required this.text,
    required this.gewaehlt,
    required this.onTap,
    this.hoehe = 44,
  });

  final String text;
  final bool gewaehlt;
  final VoidCallback onTap;
  final double hoehe;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.name;
    final inhalt = Center(
      widthFactor: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BwSpacing.space4),
        child: Text(
          text,
          style: stil.copyWith(color: gewaehlt ? BwColors.gradEnd : null),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: gewaehlt,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: hoehe,
          child: gewaehlt
              ? BwEingedrueckt(
                  radius: BwRadius.pill,
                  grund: BwColors.surfaceFloat,
                  schatten: BwSheet.insetSm,
                  child: inhalt,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: BwColors.surfaceFloat,
                    borderRadius: BorderRadius.circular(BwRadius.pill),
                    boxShadow: BwShadows.boxShadows(BwSheet.raisedSm),
                  ),
                  child: inhalt,
                ),
        ),
      ),
    );
  }
}

/// Wahl einer Option, z. B. woher das Geld kommt: erhaben, gewählt
/// eingedrückt mit Verlaufsrahmen. [rechts] steht am Ende, etwa ein Betrag.
class BwWahlKarte extends StatelessWidget {
  const BwWahlKarte({
    super.key,
    required this.text,
    required this.gewaehlt,
    required this.onTap,
    this.unterzeile,
    this.rechts,
    this.aufSheet = false,
  });

  final String text;
  final bool gewaehlt;
  final VoidCallback onTap;
  final String? unterzeile;
  final Widget? rechts;

  /// Im Sheet liegt die Karte auf `surface-float` (styleguide.md, Sheet).
  final bool aufSheet;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final grund = aufSheet ? BwColors.surfaceFloat : BwColors.bg;
    final mitte = rechts == null && unterzeile == null;
    final beschriftung = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: mitte
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          this.text,
          style: text.name,
          textAlign: mitte ? TextAlign.center : TextAlign.start,
        ),
        if (unterzeile != null) Text(unterzeile!, style: text.caption),
      ],
    );
    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BwSpacing.space4,
        vertical: BwSpacing.space2,
      ),
      child: mitte
          ? Center(child: beschriftung)
          : Row(
              children: [
                Expanded(child: beschriftung),
                if (rechts != null) ...[
                  const SizedBox(width: BwSpacing.space3),
                  rechts!,
                ],
              ],
            ),
    );
    return Semantics(
      button: true,
      selected: gewaehlt,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BwKnopf.hoehe),
          child: gewaehlt
              ? BwEingedrueckt(
                  radius: BwRadius.md,
                  schatten: aufSheet ? BwSheet.insetSm : BwShadows.insetSm,
                  rahmen: BwGradients.accent,
                  grund: grund,
                  child: inhalt,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: grund,
                    borderRadius: BorderRadius.circular(BwRadius.md),
                    boxShadow: BwShadows.boxShadows(
                      aufSheet ? BwSheet.raisedSm : BwShadows.raisedSm,
                    ),
                  ),
                  child: inhalt,
                ),
        ),
      ),
    );
  }
}

/// Umschalter zwischen zwei Möglichkeiten, z. B. Einzahlung und Auszahlung:
/// eingedrückte Rinne, die gewählte Seite im Verlauf.
class BwUmschalter extends StatelessWidget {
  const BwUmschalter({
    super.key,
    required this.links,
    required this.rechts,
    required this.linksGewaehlt,
    required this.onChanged,
  });

  final String links;
  final String rechts;
  final bool linksGewaehlt;
  final ValueChanged<bool> onChanged;

  static const hoehe = 40.0;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.button;

    Widget seite(String text, bool gewaehlt, bool links) => Expanded(
      child: Semantics(
        button: true,
        selected: gewaehlt,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(links),
          child: Container(
            height: hoehe,
            alignment: Alignment.center,
            decoration: gewaehlt
                ? const BoxDecoration(
                    gradient: BwGradients.accent,
                    borderRadius: BorderRadius.all(
                      Radius.circular(BwRadius.pill),
                    ),
                  )
                : null,
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: stil.copyWith(
                color: gewaehlt ? BwColors.onAccent : BwColors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );

    return BwEingedrueckt(
      radius: BwRadius.pill,
      grund: BwColors.surfaceFloat,
      schatten: BwSheet.insetSm,
      padding: const EdgeInsets.all(BwSpacing.space1),
      child: Row(
        children: [
          seite(links, linksGewaehlt, true),
          const SizedBox(width: BwSpacing.space1),
          seite(rechts, !linksGewaehlt, false),
        ],
      ),
    );
  }
}
