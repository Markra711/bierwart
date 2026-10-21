import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/money/cents.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/tab_seite.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../application/kader_daten.dart';
import '../domain/kader.dart';
import '../domain/mitglied.dart';
import 'mitglied_anlegen_sheet.dart';

/// Tab 02: alle Mitglieder nach Schulden (KAD-05), Summen offen und
/// Guthaben, „Liste teilen“ (KAD-07) und „+ Mitglied“ (KAD-01).
class KaderScreen extends ConsumerWidget {
  const KaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mitglieder = ref.watch(mitgliederProvider);
    final kasse = ref.watch(kasseInfoProvider).value;
    final aktiv = ref.watch(aktiveBierwarteProvider).value ?? const {};
    final kader = kaderNachSchulden(mitglieder.value ?? const []);
    final summen = kaderSummen(kader);

    return BwTabSeite(
      nummer: '02',
      titel: 'Kader',
      kassenName: mitglieder.hasValue
          ? '${kader.length} ${kader.length == 1 ? 'Mitglied' : 'Mitglieder'} '
                '+ Gäste'
          : null,
      einstellungen: () => context.push(Routen.einstellungen),
      kinder: [
        Row(
          children: [
            Expanded(
              child: _Summenkarte(
                label: 'Offen gesamt',
                cents: summen.offenCents,
                verlauf: true,
              ),
            ),
            const SizedBox(width: BwSpacing.space4),
            Expanded(
              child: _Summenkarte(
                label: 'Guthaben',
                cents: summen.guthabenCents,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: BwKnopf(
                text: 'Liste teilen',
                art: BwKnopfArt.outline,
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: werSchuldetWas(kasse?.name ?? 'Kasse', kader),
                  ),
                ),
              ),
            ),
            const SizedBox(width: BwSpacing.space4),
            Expanded(
              child: BwKnopf(
                text: 'Mitglied',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => zeigeMitgliedAnlegen(context),
              ),
            ),
          ],
        ),
        switch (mitglieder) {
          AsyncData() => Column(
            children: [
              for (final (i, m) in kader.indexed) ...[
                if (i > 0) const SizedBox(height: BwSpacing.space3),
                _KaderZeile(
                  mitglied: m,
                  rolle: rolleVon(
                    m,
                    aktiveBierwarte: aktiv,
                    adminUid: kasse?.adminUid,
                    kassenwartUid: kasse?.kassenwartUid,
                  ),
                ),
              ],
            ],
          ),
          AsyncError() => const BwFehler(
            'Die Mitglieder ließen sich nicht laden.',
          ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// Summenkarte: reine Anzeige, eingedrückt (styleguide.md, Card).
class _Summenkarte extends StatelessWidget {
  const _Summenkarte({
    required this.label,
    required this.cents,
    this.verlauf = false,
  });

  final String label;
  final int cents;
  final bool verlauf;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final betrag = formatEuro(cents);
    return BwEingedrueckt(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BwRadius.lg),
        child: Stack(
          children: [
            const Positioned(
              right: -BwSpacing.space3,
              top: -BwSpacing.space3,
              child: BwSchraffur(durchmesser: 56, farbe: BwColors.lineStrong),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BwSpacing.space4,
                vertical: BwSpacing.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BwLabel(label),
                  const SizedBox(height: BwSpacing.space1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: verlauf
                        ? BwVerlaufText(betrag, style: text.amountL)
                        : Text(
                            betrag,
                            style: text.amountL.copyWith(
                              color: cents > 0
                                  ? BwColors.positive
                                  : BwColors.ink,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listenzeile: Name mit Rolle, Betrag rechts; antippbar (styleguide.md,
/// Card).
class _KaderZeile extends StatelessWidget {
  const _KaderZeile({required this.mitglied, required this.rolle});

  final Mitglied mitglied;
  final Rolle? rolle;

  static const mindestHoehe = 60.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final saldo = mitglied.saldoCents;
    final betrag = saldo == 0
        ? '—'
        : saldo < 0
        ? '+${formatEuro(-saldo)}'
        : formatEuro(saldo);
    return Semantics(
      button: true,
      label:
          '${mitglied.name}${rolle == null ? '' : ', ${_rollenText(rolle!)}'}, '
          '${saldo == 0
              ? 'nichts offen'
              : saldo < 0
              ? '${formatEuro(-saldo)} Guthaben'
              : '${formatEuro(saldo)} offen'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(Routen.mitgliedDetail(mitglied.id)),
        child: BwErhaben(
          padding: const EdgeInsets.symmetric(
            horizontal: BwSpacing.space4,
            vertical: BwSpacing.space3,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: mindestHoehe - BwSpacing.space3 * 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        spacing: BwSpacing.space2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(mitglied.name, style: text.name),
                          if (rolle != null) _Badge(_rollenText(rolle!)),
                        ],
                      ),
                      if (saldo < 0) ...[
                        const SizedBox(height: BwSpacing.space1),
                        Text('Hat im Voraus bezahlt', style: text.caption),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: BwSpacing.space3),
                Text(
                  betrag,
                  style: text.amountL.copyWith(
                    color: saldo == 0
                        ? BwColors.inkFaint
                        : saldo < 0
                        ? BwColors.positive
                        : BwColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _rollenText(Rolle r) => switch (r) {
    Rolle.admin => 'Admin',
    Rolle.kassenwart => 'Kassenwart',
    Rolle.bierwart => 'Bierwart',
  };
}

/// Rollen-Badge: Rahmen in `line-strong`, `radius-sm`.
class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BwSpacing.space1),
      decoration: BoxDecoration(
        border: Border.all(color: BwColors.lineStrong),
        borderRadius: BorderRadius.circular(BwRadius.sm),
      ),
      child: Text(text.toUpperCase(), style: stil),
    );
  }
}
