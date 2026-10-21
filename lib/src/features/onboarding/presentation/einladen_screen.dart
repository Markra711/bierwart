import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../application/onboarding.dart';
import '../domain/codes.dart';

/// Nach dem Erstellen: Bierwarte einladen (UC-06). Der Link gilt 7 Tage
/// (AUTH-08).
class EinladenScreen extends ConsumerWidget {
  const EinladenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final kasse = ref.watch(ersteKasseProvider);
    if (kasse == null) return const SizedBox.shrink();
    final link = einladungslink(kasse.einladungscode);

    return BwSeite(
      inhalt: [
        BwLabel(kasse.kassenName),
        const BwTitel(voll: 'Hol deine', kontur: 'Bierwarte', danach: 'dazu'),
        const BwErklaerung(
          'Wer den Link antippt und beitritt, ist Bierwart und darf buchen, '
          'einkaufen und kassieren.',
        ),
        BwErhaben(
          radius: BwRadius.xl,
          schatten: BwShadows.raisedLg,
          padding: const EdgeInsets.all(BwSpacing.space2),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned(
                right: -BwSpacing.space6,
                bottom: -BwSpacing.space6,
                child: BwSchraffur(durchmesser: 100, winkel: 0),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: BwGradients.accent,
                  borderRadius: BorderRadius.circular(BwRadius.lg),
                ),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  padding: const EdgeInsets.all(BwSpacing.space4),
                  decoration: BoxDecoration(
                    color: BwColors.bg,
                    borderRadius: BorderRadius.circular(BwRadius.lg - 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('EINLADUNGSCODE', style: text.label),
                      const SizedBox(height: BwSpacing.space1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: BwVerlaufText(
                          inGruppen(kasse.einladungscode),
                          style: text.amountXl,
                        ),
                      ),
                      const SizedBox(height: BwSpacing.space1),
                      Text(
                        '${link.replaceFirst('https://', '')} · 7 Tage gültig',
                        style: text.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        BwKnopf(
          text: 'Link teilen',
          gross: true,
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              text: 'Komm in unsere Kasse „${kasse.kassenName}“: $link',
            ),
          ),
        ),
      ],
      aktionen: [
        Row(
          children: [
            const SizedBox(
              width: BwSpacing.space6,
              height: 1,
              child: CustomPaint(painter: _Strichlinie()),
            ),
            const SizedBox(width: BwSpacing.space2),
            Expanded(
              child: Text(
                'Den Link findest du jederzeit in den Einstellungen.',
                style: text.caption,
              ),
            ),
          ],
        ),
        BwKnopf(
          text: 'Weiter zur Strichliste',
          art: BwKnopfArt.outline,
          gross: true,
          onPressed: () => ref.read(ersteKasseProvider.notifier).abschliessen(),
        ),
      ],
    );
  }
}

/// Gestrichelte Linie, 4px Strich, 4px Lücke in `line-strong`.
class _Strichlinie extends CustomPainter {
  const _Strichlinie();

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
  bool shouldRepaint(_Strichlinie old) => false;
}
