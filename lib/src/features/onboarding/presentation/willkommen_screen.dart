import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';

/// Erster Bildschirm ohne Kasse (Design-Canvas „Willkommen“).
class WillkommenScreen extends StatelessWidget {
  const WillkommenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return BwSeite(
      deko: const [
        Positioned(
          right: -BwSpacing.space6 * 2,
          top: BwSpacing.space6 * 4,
          child: BwSchraffur(
            durchmesser: 180,
            farbe: BwColors.lineStrong,
            winkel: 0,
          ),
        ),
      ],
      inhalt: [
        const _Wortmarke(),
        const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: BwSpacing.space6 + BwSpacing.space1,
            height: 2,
            child: ColoredBox(color: BwColors.ink),
          ),
        ),
        const BwErklaerung(
          'Die Strichliste für eure Mannschaft. Gemeinsam buchen, sehen wer '
          'was schuldet, und wissen, wo das Geld liegt. Kein Konto, keine '
          'E-Mail.',
        ),
      ],
      aktionen: [
        BwKnopf(
          text: 'Kasse erstellen',
          gross: true,
          onPressed: () => context.go(Routen.kasseErstellen),
        ),
        BwKnopf(
          text: 'Ich habe einen Einladungslink',
          art: BwKnopfArt.outline,
          gross: true,
          onPressed: () => context.go(Routen.linkEinfuegen),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routen.wiederherstellen),
            style: TextButton.styleFrom(
              foregroundColor: BwColors.ink,
              minimumSize: const Size(0, BwKnopf.hoehe),
            ),
            child: Text(
              'Ich habe einen Wiederherstellungscode',
              style: text.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Text(
          'Anonyme Anmeldung über Firebase. Das Gerät bleibt angemeldet.',
          textAlign: TextAlign.center,
          style: text.caption,
        ),
      ],
    );
  }
}

/// „BIER“ in Kontur, „WART“ im Verlauf. Größen wie im Canvas; die Wortmarke
/// ist das einzige Element außerhalb der Textstil-Tokens.
class _Wortmarke extends StatelessWidget {
  const _Wortmarke();

  @override
  Widget build(BuildContext context) {
    final basis = Theme.of(context).extension<BwTextStyles>()!.outlineNumeral;
    return Semantics(
      label: 'Bierwart',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BIER',
            style: alsKontur(
              basis.copyWith(
                fontSize: 88,
                height: 80 / 88,
                letterSpacing: 0.04 * 88,
              ),
              breite: 1.5,
            ),
          ),
          BwVerlaufText(
            'WART',
            style: basis.copyWith(
              fontSize: 104,
              height: 92 / 104,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02 * 104,
            ),
          ),
        ],
      ),
    );
  }
}
