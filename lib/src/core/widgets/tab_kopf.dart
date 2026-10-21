import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'eingaben.dart';
import 'flaechen.dart';
import 'knoepfe.dart';

/// Kopf eines Tabs: Outline-Ziffer dahinter (01–04), darüber der Kassenname,
/// der Titel und rechts das Zahnrad zu den Einstellungen (UI-02).
class BwTabKopf extends StatelessWidget {
  const BwTabKopf({
    super.key,
    required this.nummer,
    required this.titel,
    required this.kassenName,
    required this.einstellungen,
  });

  final String nummer;
  final String titel;
  final String? kassenName;
  final VoidCallback einstellungen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -BwSpacing.space2,
          top: -BwSpacing.space6 - BwSpacing.space4,
          child: ExcludeSemantics(
            child: Text(
              nummer,
              style: alsKontur(
                text.outlineNumeral,
                breite: 1,
                farbe: BwColors.line,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: BwSpacing.space6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BwLabel(kassenName ?? ''),
                    const SizedBox(height: BwSpacing.space1),
                    Semantics(
                      header: true,
                      child: Text(titel.toUpperCase(), style: text.screenTitle),
                    ),
                  ],
                ),
              ),
              BwIconKnopf(
                icon: Icons.tune_rounded,
                label: 'Einstellungen',
                onPressed: einstellungen,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
