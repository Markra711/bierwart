import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../application/onboarding.dart';
import '../data/kasse_repository.dart';
import '../domain/codes.dart';
import '../domain/einladung.dart';

/// „Kasse beitreten?“ mit Kassenname und Anzahl der Bierwarte (AUTH-05).
/// Abgelaufene, ersetzte und unbekannte Links lehnt die Seite mit klarer
/// Meldung ab (AUTH-08).
class BeitretenScreen extends ConsumerWidget {
  const BeitretenScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final gueltigerCode = einladungscodeAus(code);
    final einladung = gueltigerCode == null
        ? const AsyncData<Einladung?>(null)
        : ref.watch(einladungProvider(gueltigerCode));

    Widget andererLink(BwKnopfArt art) => BwKnopf(
      text: 'Anderer Link',
      art: art,
      gross: true,
      onPressed: () => context.go(Routen.linkEinfuegen),
    );

    final kopf = [
      BwVerlaufText('EINLADUNG', style: text.label),
      const BwTitel(voll: 'Kasse', kontur: 'beitreten?'),
    ];

    return switch (einladung) {
      AsyncData(value: final e?)
          when e.zustand(DateTime.now()).meldung == null =>
        BwSeite(
          inhalt: [
            ...kopf,
            _Kassenkarte(einladung: e),
            const BwErklaerung(
              'Als Bierwart darfst du buchen, einkaufen und kassieren. Alles, '
              'was du tust, steht mit deinem Namen im Verlauf.',
            ),
          ],
          aktionen: [
            BwKnopf(
              text: 'Ja, beitreten',
              gross: true,
              onPressed: () =>
                  context.go(Routen.mitCode(Routen.nameWaehlen, e.code)),
            ),
            BwKnopf(
              text: 'Nein',
              art: BwKnopfArt.outline,
              gross: true,
              onPressed: () => context.go(Routen.willkommen),
            ),
          ],
        ),
      AsyncData(:final value) => BwSeite(
        inhalt: [
          ...kopf,
          BwFehler(
            value?.zustand(DateTime.now()).meldung ??
                'Diese Einladung gibt es nicht. Prüf, ob der Link vollständig '
                    'ist.',
          ),
        ],
        aktionen: [andererLink(BwKnopfArt.primaer)],
      ),
      AsyncError(:final error) => BwSeite(
        inhalt: [
          ...kopf,
          BwFehler(
            error is VerwaltungsFehler
                ? error.meldung
                : 'Die Einladung ließ sich nicht laden.',
          ),
        ],
        aktionen: [
          BwKnopf(
            text: 'Nochmal versuchen',
            gross: true,
            onPressed: () => ref.invalidate(einladungProvider(gueltigerCode!)),
          ),
          andererLink(BwKnopfArt.outline),
        ],
      ),
      _ => BwSeite(
        inhalt: [
          ...kopf,
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox.square(
              dimension: BwSpacing.space6,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BwColors.gradEnd,
              ),
            ),
          ),
        ],
      ),
    };
  }
}

/// Erhabene Karte mit Kassenname und „3 Bierwarte“.
class _Kassenkarte extends StatelessWidget {
  const _Kassenkarte({required this.einladung});

  final Einladung einladung;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return BwErhaben(
      radius: BwRadius.xl,
      schatten: BwShadows.raisedLg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BwRadius.xl),
        child: Stack(
          children: [
            const Positioned(
              right: -BwSpacing.space5,
              top: -BwSpacing.space5,
              child: BwSchraffur(durchmesser: 80),
            ),
            Padding(
              padding: const EdgeInsets.all(BwSpacing.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    einladung.kassenName.toUpperCase(),
                    style: text.pageTitle,
                  ),
                  const SizedBox(height: BwSpacing.space1),
                  Text(einladung.bierwarteText, style: text.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
