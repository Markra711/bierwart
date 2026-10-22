import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/karten.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/sheet.dart';
import '../../../core/widgets/wahl.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../application/verlauf.dart';
import '../domain/logbuchung.dart';

/// Verlauf (LOG-03): das ganze Log nach Tagen, neueste zuerst, filterbar
/// nach Bierwart und Mitglied. Lädt seitenweise.
class VerlaufScreen extends ConsumerWidget {
  const VerlaufScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final filter = ref.watch(logFilterProvider);
    final log = ref.watch(logProvider);
    final namen = ref.watch(logNamenProvider);
    final mitglieder = ref.watch(mitgliederProvider).value ?? const [];
    final gefiltert = filter.bierwartUid != null || filter.mitgliedId != null;

    void zurueck() =>
        context.canPop() ? context.pop() : context.go(Routen.geld);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BwSpacing.space4,
            BwSpacing.space4,
            BwSpacing.space4,
            BwSpacing.space6,
          ),
          children: [
            Row(
              children: [
                BwZurueck(onPressed: zurueck),
                const SizedBox(width: BwSpacing.space3),
                Semantics(
                  header: true,
                  container: true,
                  child: Text('VERLAUF', style: text.pageTitle),
                ),
              ],
            ),
            const SizedBox(height: BwSpacing.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BwSpacing.space1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: BwSpacing.space4,
                    runSpacing: BwSpacing.space3,
                    children: [
                      _FilterKnopf(
                        text: filter.bierwartUid == null
                            ? 'Alle Bierwarte'
                            : namen.bierwart(filter.bierwartUid),
                        onTap: () => _waehlen(
                          context,
                          titel: 'Bierwart',
                          alle: 'Alle Bierwarte',
                          optionen: namen.bierwarte,
                          gewaehlt: filter.bierwartUid,
                          setzen: ref.read(logFilterProvider.notifier).bierwart,
                        ),
                      ),
                      _FilterKnopf(
                        text: filter.mitgliedId == null
                            ? 'Alle Mitglieder'
                            : namen.mitglied(filter.mitgliedId),
                        onTap: () => _waehlen(
                          context,
                          titel: 'Mitglied',
                          alle: 'Alle Mitglieder',
                          optionen: {for (final m in mitglieder) m.id: m.name},
                          gewaehlt: filter.mitgliedId,
                          setzen: ref.read(logFilterProvider.notifier).mitglied,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BwSpacing.space4),
                  ...switch (log) {
                    AsyncData(:final value) when value.buchungen.isEmpty => [
                      BwErklaerung(
                        gefiltert
                            ? 'Dazu steht noch nichts im Verlauf.'
                            : 'Noch nichts gebucht.',
                      ),
                    ],
                    AsyncData(:final value) => [
                      for (final (tag, buchungen) in nachTagen(
                        value.buchungen,
                      )) ...[
                        BwAbschnitt(tagText(tag)),
                        const SizedBox(height: BwSpacing.space3),
                        _Tag(buchungen: buchungen, namen: namen),
                        const SizedBox(height: BwSpacing.space4),
                      ],
                      if (value.mehr)
                        BwKnopf(
                          text: 'Ältere laden',
                          art: BwKnopfArt.outline,
                          onPressed: ref.read(logFilterProvider.notifier).mehr,
                        ),
                    ],
                    AsyncError() => const [
                      BwFehler('Der Verlauf ließ sich nicht laden.'),
                    ],
                    _ => const [
                      Align(
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
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Auswahl im Sheet: „Alle …“ oder ein Name.
  void _waehlen(
    BuildContext context, {
    required String titel,
    required String alle,
    required Map<String, String> optionen,
    required String? gewaehlt,
    required void Function(String?) setzen,
  }) {
    final sortiert = optionen.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    zeigeSheet<void>(
      context,
      titel: titel,
      inhalt: (sheet) {
        void nehmen(String? id) {
          setzen(id);
          Navigator.of(sheet).pop();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BwWahlKarte(
              text: alle,
              aufSheet: true,
              gewaehlt: gewaehlt == null,
              onTap: () => nehmen(null),
            ),
            for (final e in sortiert) ...[
              const SizedBox(height: BwSpacing.space3),
              BwWahlKarte(
                text: e.value,
                aufSheet: true,
                gewaehlt: gewaehlt == e.key,
                onTap: () => nehmen(e.key),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Filter als erhabene Pille mit Pfeil, wie im Design-Canvas.
class _FilterKnopf extends StatelessWidget {
  const _FilterKnopf({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.name;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: BwErhaben(
          radius: BwRadius.pill,
          schatten: BwShadows.raisedSm,
          padding: const EdgeInsets.symmetric(
            horizontal: BwSpacing.space4,
            vertical: BwSpacing.space3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: stil),
              const SizedBox(width: BwSpacing.space1),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: BwColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Die Buchungen eines Tages als gruppierte Liste (styleguide.md, Card).
class _Tag extends StatelessWidget {
  const _Tag({required this.buchungen, required this.namen});

  final List<Logbuchung> buchungen;
  final LogNamen namen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return BwEingedrueckt(
      padding: const EdgeInsets.symmetric(vertical: BwSpacing.space1),
      child: Column(
        children: [
          for (final b in buchungen)
            Builder(
              builder: (context) {
                final z = logZeile(b, namen);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BwSpacing.space4,
                    vertical: BwSpacing.space3,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: BwSpacing.space6 + BwSpacing.space4,
                        child: Text(
                          uhrzeit(b.zeit),
                          style: text.caption.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              z.titel,
                              style: text.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(z.unterzeile, style: text.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: BwSpacing.space3),
                      Text(
                        z.betrag,
                        style: text.amountM.copyWith(
                          color: switch (z.tendenz) {
                            Tendenz.plus => BwColors.positive,
                            Tendenz.minus => BwColors.negative,
                            Tendenz.keiner => BwColors.inkFaint,
                            Tendenz.neutral => BwColors.ink,
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
