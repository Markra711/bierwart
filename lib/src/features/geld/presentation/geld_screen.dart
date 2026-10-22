import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/cents.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/karten.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/tab_seite.dart';
import '../../kader/application/kader_daten.dart';
import '../../kader/domain/eintrag.dart';
import '../../onboarding/data/anmeldung_repository.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../application/geld.dart';
import '../domain/ort.dart';
import 'ein_auszahlung_sheet.dart';
import 'kassensturz_sheet.dart';
import 'uebergabe_sheet.dart';

/// Tab 04 (GEL-07): Vermögen der Mannschaft im Kopf, die Kasse als
/// Hauptkarte, alle Portemonnaies, auch ehemalige mit Restbetrag (GEL-08).
/// Ein- und Auszahlung für alle; Übergabe und Kassensturz sieht nur der
/// Kassenwart (UI-08). Darunter geht es zum Verlauf (LOG-03).
class GeldScreen extends ConsumerWidget {
  const GeldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(geldstandProvider);
    final kassenwart = ref.watch(istKassenwartProvider);
    // Hält den Stempel-Namen geladen, damit Buchungen sofort gehen.
    ref.watch(sitzungProvider);

    return BwTabSeite(
      nummer: '04',
      titel: switch (stand) {
        AsyncData(:final value) => formatEuro(value.vermoegenCents),
        _ => 'Geld',
      },
      kassenName: 'Vermögen der Mannschaft',
      einstellungen: () => context.push(Routen.einstellungen),
      kinder: switch (stand) {
        AsyncData(:final value) => [
          _Kassenkarte(stand: value),
          const SizedBox(height: BwSpacing.space1),
          const BwAbschnitt('Portemonnaies'),
          if (value.portemonnaies.isEmpty)
            const BwErklaerung('Noch kein Portemonnaie.')
          else
            _Portemonnaies(value.portemonnaies),
          const SizedBox(height: BwSpacing.space1),
          BwKnopf(
            text: 'Ein- oder Auszahlung',
            onPressed: () => zeigeEinAuszahlung(context),
          ),
          if (kassenwart)
            Row(
              children: [
                Expanded(
                  child: BwKnopf(
                    text: 'Übergabe',
                    art: BwKnopfArt.outline,
                    onPressed: value.portemonnaies.isEmpty
                        ? null
                        : () => zeigeUebergabe(context),
                  ),
                ),
                const SizedBox(width: BwSpacing.space4),
                Expanded(
                  child: BwKnopf(
                    text: 'Kassensturz',
                    art: BwKnopfArt.outline,
                    onPressed: () => zeigeKassensturz(context),
                  ),
                ),
              ],
            ),
          const _VerlaufLink(),
        ],
        AsyncError() => const [
          BwFehler('Kasse und Portemonnaies ließen sich nicht laden.'),
        ],
        _ => const [],
      },
    );
  }
}

/// „Verlauf ansehen →“ als ruhiger Textknopf (LOG-03).
class _VerlaufLink extends StatelessWidget {
  const _VerlaufLink();

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.button;
    return Center(
      child: TextButton(
        onPressed: () => context.push(Routen.verlauf),
        style: TextButton.styleFrom(
          foregroundColor: BwColors.ink,
          minimumSize: const Size(0, BwKnopf.hoehe),
          textStyle: stil,
        ),
        child: const Text('VERLAUF ANSEHEN →'),
      ),
    );
  }
}

/// Die Kasse als Hauptkarte, darunter wer die Kassette hat und wann zuletzt
/// gezählt wurde.
class _Kassenkarte extends ConsumerWidget {
  const _Kassenkarte({required this.stand});

  final Geldstand stand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final uid = ref.watch(anmeldungProvider).value;
    final kassenwartUid = ref.watch(kasseInfoProvider).value?.kassenwartUid;
    final sturz = ref.watch(letzterKassensturzProvider).value;
    final kassenwart = stand.portemonnaies
        .where((o) => o.id == kassenwartUid)
        .firstOrNull;
    final cents = stand.kasse?.standCents ?? 0;
    final unterzeile = [
      if (kassenwart != null)
        'Kassette bei ${kassenwart.name} '
            '(${kassenwart.id == uid ? 'du, ' : ''}Kassenwart)',
      if (sturz != null) 'Kassensturz am ${datumKurz(sturz)}',
    ].join(' · ');
    return BwHauptkarte(
      label: 'Kasse',
      betrag: cents < 0
          ? Text(
              formatEuro(cents),
              style: text.amountXl.copyWith(color: BwColors.negative),
            )
          : BwVerlaufText(formatEuro(cents), style: text.amountXl),
      unterzeile: unterzeile.isEmpty ? null : unterzeile,
    );
  }
}

/// Gruppierte Liste, eingedrückt, Zeilen ohne eigenen Schatten
/// (styleguide.md, Card). Im Minus in `negative` mit Wort (GEL-01).
class _Portemonnaies extends ConsumerWidget {
  const _Portemonnaies(this.portemonnaies);

  final List<Ort> portemonnaies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final uid = ref.watch(anmeldungProvider).value;
    return BwEingedrueckt(
      padding: const EdgeInsets.symmetric(vertical: BwSpacing.space1),
      child: Column(
        children: [
          for (final o in portemonnaies)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BwSpacing.space4,
                vertical: BwSpacing.space3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: o.name,
                            children: [
                              if (o.id == uid)
                                TextSpan(
                                  text: ' (du)',
                                  style: text.name.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: BwColors.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                          style: text.name,
                        ),
                        if (portemonnaieZusatz(o) case final zusatz?)
                          Text(zusatz, style: text.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: BwSpacing.space3),
                  Text(
                    formatEuro(o.standCents),
                    style: text.amountL.copyWith(
                      color: o.standCents < 0 ? BwColors.negative : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Unterzeile eines Portemonnaies: Auslage und „ehemalig“ (GEL-01, GEL-08).
String? portemonnaieZusatz(Ort o) {
  final teile = [
    if (o.ehemalig) 'ehemalig',
    if (o.standCents < 0)
      'Kasse schuldet ${vorname(o.name)} ${formatEuro(-o.standCents)}',
  ];
  return teile.isEmpty ? null : teile.join(' · ');
}

String _zwei(int n) => n.toString().padLeft(2, '0');

/// „10.10.“ wie im Design-Canvas.
String datumKurz(DateTime t) => '${_zwei(t.day)}.${_zwei(t.month)}.';
