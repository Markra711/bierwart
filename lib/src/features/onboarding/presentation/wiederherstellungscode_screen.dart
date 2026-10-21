import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../application/onboarding.dart';
import '../domain/codes.dart';

/// Der Wiederherstellungscode, genau einmal angezeigt (AUTH-03). Weiter erst,
/// wenn der Nutzer bestätigt, dass er ihn gespeichert hat.
class WiederherstellungscodeScreen extends ConsumerStatefulWidget {
  const WiederherstellungscodeScreen({super.key});

  @override
  ConsumerState<WiederherstellungscodeScreen> createState() =>
      _WiederherstellungscodeScreenState();
}

class _WiederherstellungscodeScreenState
    extends ConsumerState<WiederherstellungscodeScreen> {
  bool _gespeichert = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final kasse = ref.watch(ersteKasseProvider);
    if (kasse == null) return const SizedBox.shrink();
    final code = inGruppen(kasse.wiederherstellungscode);

    return BwSeite(
      inhalt: [
        BwVerlaufText('NUR JETZT SICHTBAR', style: text.label),
        const BwTitel(voll: 'Dein', kontur: 'Wiederher­stellungs­code'),
        const BwErklaerung(
          'Damit wirst du wieder Admin, falls dein Handy verloren geht. Wer '
          'den Code hat, kann die Kasse übernehmen. Speicher ihn sicher, z. B. '
          'im Passwort-Manager.',
        ),
        _Auswahlbox(
          child: BwEingedrueckt(
            radius: BwRadius.lg,
            padding: const EdgeInsets.symmetric(
              horizontal: BwSpacing.space3,
              vertical: BwSpacing.space5,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                code,
                semanticsLabel: code.split('').join(' '),
                style: text.amountL.copyWith(letterSpacing: 3),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: BwKnopf(
                text: 'Kopieren',
                art: BwKnopfArt.sekundaer,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code kopiert.')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: BwSpacing.space4),
            Expanded(
              child: BwKnopf(
                text: 'Teilen',
                art: BwKnopfArt.sekundaer,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Wiederherstellungscode für „${kasse.kassenName}“ '
                        '(Bierwart): $code',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      aktionen: [
        BwErhaben(
          schatten: BwShadows.raisedSm,
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: _gespeichert,
              onChanged: (v) => setState(() => _gespeichert = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: BwColors.gradEnd,
              checkColor: BwColors.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BwRadius.lg),
              ),
              title: Text(
                'Ich habe den Code sicher gespeichert',
                style: text.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        BwKnopf(
          text: 'Weiter',
          gross: true,
          onPressed: _gespeichert ? () => context.go(Routen.einladen) : null,
        ),
      ],
    );
  }
}

/// Rahmen in `line-strong` mit vier Anfassern in `handle` an den Ecken
/// (styleguide.md, Auswahlbox).
class _Auswahlbox extends StatelessWidget {
  const _Auswahlbox({required this.child});

  final Widget child;

  static const _abstand = 6.0;
  static const _anfasser = 6.0;

  @override
  Widget build(BuildContext context) {
    Widget ecke({double? l, double? t, double? r, double? b}) => Positioned(
      left: l,
      top: t,
      right: r,
      bottom: b,
      child: const SizedBox.square(
        dimension: _anfasser,
        child: ColoredBox(color: BwColors.handle),
      ),
    );
    const aussen = -_abstand - _anfasser / 2;
    return Padding(
      padding: const EdgeInsets.all(_abstand),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: -_abstand,
            top: -_abstand,
            right: -_abstand,
            bottom: -_abstand,
            child: const ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(color: BwColors.lineStrong),
                  ),
                ),
              ),
            ),
          ),
          child,
          ecke(l: aussen, t: aussen),
          ecke(r: aussen, t: aussen),
          ecke(l: aussen, b: aussen),
          ecke(r: aussen, b: aussen),
        ],
      ),
    );
  }
}
