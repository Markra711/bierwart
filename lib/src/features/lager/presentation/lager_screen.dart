import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/cents.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/tab_seite.dart';
import '../application/sorten.dart';
import '../domain/sorte.dart';
import 'sorte_anlegen_sheet.dart';

/// Tab 03: Sorten mit Bestand und Balken (BES-03), „Einkauf“ (BES-04) und
/// „+ Sorte“ (BES-01). Ausgeblendete Sorten stehen am Ende.
class LagerScreen extends ConsumerWidget {
  const LagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorten = ref.watch(alleSortenProvider);
    final alle = sorten.value ?? const <Sorte>[];
    final aktive = alle.where((s) => s.aktiv).toList();
    final ausgeblendet = alle.where((s) => !s.aktiv).toList();
    final summe = lagerSumme(aktive);

    return BwTabSeite(
      nummer: '03',
      titel: 'Lager',
      kassenName: sorten.hasValue
          ? '${summe.sorten} ${summe.sorten == 1 ? 'Sorte' : 'Sorten'} · '
                '${summe.flaschen} Flaschen'
          : null,
      einstellungen: () => context.push(Routen.einstellungen),
      kinder: [
        Row(
          children: [
            Expanded(
              child: BwKnopf(
                text: 'Einkauf',
                icon: const Icon(Icons.add_rounded),
                onPressed: aktive.isEmpty
                    ? null
                    : () => context.push(Routen.einkauf),
              ),
            ),
            const SizedBox(width: BwSpacing.space4),
            Expanded(
              child: BwKnopf(
                text: 'Sorte',
                art: BwKnopfArt.outline,
                icon: const Icon(Icons.add_rounded),
                onPressed: () => zeigeSorteAnlegen(context),
              ),
            ),
          ],
        ),
        switch (sorten) {
          AsyncData() when alle.isEmpty => const BwErklaerung(
            'Noch keine Sorte. Leg die erste an, dann kannst du einkaufen '
            'und buchen.',
          ),
          AsyncData() => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, s) in aktive.indexed) ...[
                if (i > 0) const SizedBox(height: BwSpacing.space4),
                _SortenZeile(sorte: s, anteil: balkenAnteil(s, aktive)),
              ],
              if (ausgeblendet.isNotEmpty) ...[
                const SizedBox(height: BwSpacing.space6),
                const BwLabel('Ausgeblendet'),
                const SizedBox(height: BwSpacing.space3),
                for (final (i, s) in ausgeblendet.indexed) ...[
                  if (i > 0) const SizedBox(height: BwSpacing.space3),
                  _SortenZeile(sorte: s, anteil: 0),
                ],
              ],
            ],
          ),
          AsyncError() => const BwFehler('Die Sorten ließen sich nicht laden.'),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// Eine Sorte mit Preis, Flaschen und Bestandsbalken; leer gestrichelt in
/// `negative` mit Schraffur (styleguide.md, Card).
class _SortenZeile extends StatelessWidget {
  const _SortenZeile({required this.sorte, required this.anteil});

  final Sorte sorte;
  final double anteil;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final leer = sorte.aktiv && sorte.leer;
    final kopf = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            sorte.name,
            style: text.name.copyWith(
              color: sorte.aktiv ? null : BwColors.inkMuted,
            ),
          ),
        ),
        Text(formatEuro(sorte.preisCents), style: text.caption),
        const SizedBox(width: BwSpacing.space2),
        Text(
          sorte.bestand == 0 && sorte.aktiv
              ? 'Leer'
              : flaschenText(sorte.bestand),
          style: text.amountL.copyWith(
            color: leer
                ? BwColors.negative
                : sorte.aktiv
                ? null
                : BwColors.inkMuted,
          ),
        ),
      ],
    );
    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BwSpacing.space4,
        vertical: BwSpacing.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kopf,
          const SizedBox(height: BwSpacing.space2),
          if (leer)
            Text(
              'Buchen bleibt möglich · Nachkauf nötig',
              style: text.caption.copyWith(color: BwColors.negative),
            )
          else if (sorte.aktiv)
            _Balken(anteil: anteil),
        ],
      ),
    );

    return Semantics(
      button: true,
      label:
          '${sorte.name}, ${formatEuro(sorte.preisCents)}, '
          '${leer ? 'leer' : flaschenText(sorte.bestand)}'
          '${sorte.aktiv ? '' : ', ausgeblendet'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(Routen.sorteBearbeiten(sorte.id)),
        child: leer
            ? CustomPaint(
                painter: const GestricheltPainter(
                  radius: BwRadius.lg,
                  farbe: BwColors.negative,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BwRadius.lg),
                  child: Stack(
                    children: [
                      const Positioned(
                        right: -BwSpacing.space4,
                        top: -BwSpacing.space4,
                        child: BwSchraffur(
                          durchmesser: 72,
                          farbe: BwColors.negative,
                        ),
                      ),
                      inhalt,
                    ],
                  ),
                ),
              )
            : BwErhaben(child: inhalt),
      ),
    );
  }
}

/// Bestandsbalken: Rinne `track`, Füllung im Verlauf (styleguide.md, Card).
class _Balken extends StatelessWidget {
  const _Balken({required this.anteil});

  final double anteil;

  static const hoehe = 8.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hoehe,
      child: BwEingedrueckt(
        radius: hoehe / 2,
        schatten: BwShadows.track,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: anteil.clamp(0, 1),
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: BwGradients.accent,
                borderRadius: BorderRadius.all(Radius.circular(hoehe / 2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
