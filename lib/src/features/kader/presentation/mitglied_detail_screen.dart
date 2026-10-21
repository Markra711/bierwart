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
import '../../../core/widgets/sheet.dart';
import '../../geld/presentation/zahlung_sheet.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../application/kader_daten.dart';
import '../application/mitglieder.dart';
import '../domain/eintrag.dart';
import '../domain/mitglied.dart';
import 'umbenennen_sheet.dart';

/// Mitglied-Detail (KAD-06): offener Betrag, „Zahlung erfassen“ (GEL-02),
/// alle Striche und Zahlungen mit Storno (STR-06), Umbenennen und Entfernen
/// im Menü (KAD-01, KAD-04).
class MitgliedDetailScreen extends ConsumerWidget {
  const MitgliedDetailScreen({super.key, required this.mitgliedId});

  final String mitgliedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final mitglieder = ref.watch(mitgliederProvider);
    final mitglied = mitglieder.value
        ?.where((m) => m.id == mitgliedId)
        .firstOrNull;
    // Hält Stempel-Namen und Rollen geladen, damit Aktionen sofort gehen.
    ref.watch(sitzungProvider);
    ref.watch(aktiveBierwarteProvider);

    void zurueck() =>
        context.canPop() ? context.pop() : context.go(Routen.kader);

    if (mitglied == null) {
      return BwSeite(
        zurueck: zurueck,
        inhalt: [
          if (mitglieder.isLoading)
            const _Laden()
          else
            const BwErklaerung('Dieses Mitglied gibt es hier nicht mehr.'),
        ],
      );
    }

    final verlauf = ref.watch(verlaufProvider(mitgliedId));
    final saldo = mitglied.saldoCents;
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
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      mitglied.name.toUpperCase(),
                      style: text.pageTitle,
                    ),
                  ),
                ),
                if (!mitglied.istGast) ...[
                  const SizedBox(width: BwSpacing.space3),
                  BwIconKnopf(
                    icon: Icons.more_horiz_rounded,
                    label: 'Umbenennen oder entfernen',
                    onPressed: () => _menue(context, ref, mitglied),
                  ),
                ],
              ],
            ),
            const SizedBox(height: BwSpacing.space5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BwSpacing.space1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hauptkarte(saldo: saldo, istGast: mitglied.istGast),
                  if (!mitglied.istGast) ...[
                    const SizedBox(height: BwSpacing.space5),
                    BwKnopf(
                      text: 'Zahlung erfassen',
                      gross: true,
                      onPressed: () => zeigeZahlung(context, mitglied),
                    ),
                  ],
                  const SizedBox(height: BwSpacing.space5),
                  const _Abschnitt('Striche und Zahlungen'),
                  const SizedBox(height: BwSpacing.space3),
                  switch (verlauf) {
                    AsyncData(:final value) when value.eintraege.isEmpty =>
                      const BwErklaerung('Noch nichts gebucht.'),
                    AsyncData(:final value) => _Verlaufsliste(
                      mitglied: mitglied,
                      eintraege: value.eintraege,
                    ),
                    AsyncError() => const BwFehler(
                      'Der Verlauf ließ sich nicht laden.',
                    ),
                    _ => const _Laden(),
                  },
                  if (verlauf.value?.mehr ?? false) ...[
                    const SizedBox(height: BwSpacing.space2),
                    Center(
                      child: TextButton(
                        onPressed: () => ref
                            .read(verlaufAnzahlProvider(mitgliedId).notifier)
                            .mehr(),
                        child: Text(
                          'Ältere laden',
                          style: text.caption.copyWith(color: BwColors.gradEnd),
                        ),
                      ),
                    ),
                  ],
                  if (saldo != 0 && !mitglied.istGast) ...[
                    const SizedBox(height: BwSpacing.space5),
                    const _Hinweis(
                      'Entfernen geht erst, wenn nichts mehr offen ist.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menü hinter „…“: Umbenennen und Entfernen (KAD-01, KAD-04, UI-04).
  void _menue(BuildContext context, WidgetRef ref, Mitglied m) {
    final aktionen = ref.read(kaderAktionenProvider);
    final grund = aktionen.entfernenGeht(m);
    zeigeSheet<void>(
      context,
      titel: m.name,
      inhalt: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BwKnopf(
            text: 'Umbenennen',
            art: BwKnopfArt.outline,
            onPressed: () {
              Navigator.of(sheet).pop();
              zeigeUmbenennen(context, m);
            },
          ),
          const SizedBox(height: BwSpacing.space4),
          BwKnopf(
            text: 'Entfernen',
            art: BwKnopfArt.destruktiv,
            onPressed: grund != null
                ? null
                : () async {
                    Navigator.of(sheet).pop();
                    if (await _entfernenBestaetigt(context, m)) {
                      aktionen.entfernen(m);
                      if (context.mounted) context.go(Routen.kader);
                    }
                  },
          ),
          if (grund != null) ...[
            const SizedBox(height: BwSpacing.space2),
            Text(
              grund,
              style: Theme.of(sheet).extension<BwTextStyles>()!.caption,
            ),
          ],
        ],
      ),
    );
  }

  /// Bestätigung nur bei Unumkehrbarem (UI-04).
  Future<bool> _entfernenBestaetigt(BuildContext context, Mitglied m) async {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final ja = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: BwColors.surfaceFloat,
        title: Text('„${m.name}“ entfernen?', style: text.name),
        content: Text(
          'Der Name bleibt reserviert, der Verlauf bleibt erhalten. Wer den '
          'Namen neu anlegt, kann das Mitglied wieder aufnehmen.',
          style: text.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('ABBRECHEN'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              'ENTFERNEN',
              style: text.button.copyWith(color: BwColors.negative),
            ),
          ),
        ],
      ),
    );
    return ja ?? false;
  }
}

class _Laden extends StatelessWidget {
  const _Laden();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: SizedBox.square(
      dimension: BwSpacing.space6,
      child: CircularProgressIndicator(strokeWidth: 2, color: BwColors.gradEnd),
    ),
  );
}

/// Die eine Hauptkarte der Seite: der offene Betrag im Verlauf
/// (styleguide.md, Card).
class _Hauptkarte extends StatelessWidget {
  const _Hauptkarte({required this.saldo, required this.istGast});

  final int saldo;
  final bool istGast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final label = istGast
        ? 'Immer bar'
        : saldo > 0
        ? 'Offen'
        : saldo < 0
        ? 'Guthaben'
        : 'Ausgeglichen';
    final betrag = formatEuro(saldo.abs());
    return BwErhaben(
      radius: BwRadius.xl,
      schatten: BwShadows.raisedLg,
      padding: const EdgeInsets.all(BwSpacing.space2),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            right: -BwSpacing.space6,
            bottom: -BwSpacing.space6,
            child: BwSchraffur(durchmesser: 110, winkel: 0),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: BwGradients.accent,
              borderRadius: BorderRadius.circular(BwRadius.lg),
            ),
            child: Container(
              margin: const EdgeInsets.all(1),
              padding: const EdgeInsets.symmetric(
                horizontal: BwSpacing.space4,
                vertical: BwSpacing.space3,
              ),
              decoration: BoxDecoration(
                color: BwColors.bg,
                borderRadius: BorderRadius.circular(BwRadius.lg - 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BwLabel(label),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: saldo < 0
                        ? Text(
                            '+$betrag',
                            style: text.amountXl.copyWith(
                              color: BwColors.positive,
                            ),
                          )
                        : BwVerlaufText(betrag, style: text.amountXl),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Abschnittslabel mit gestrichelter Linie (styleguide.md,
/// Wireframe-Details).
class _Abschnitt extends StatelessWidget {
  const _Abschnitt(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BwLabel(text),
        const SizedBox(width: BwSpacing.space2),
        const Expanded(child: _Strichlinie()),
      ],
    );
  }
}

class _Hinweis extends StatelessWidget {
  const _Hinweis(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.caption;
    return Row(
      children: [
        const SizedBox(width: BwSpacing.space6, child: _Strichlinie()),
        const SizedBox(width: BwSpacing.space2),
        Expanded(child: Text(text, style: stil)),
      ],
    );
  }
}

class _Strichlinie extends StatelessWidget {
  const _Strichlinie();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: CustomPaint(painter: _Striche()));
}

class _Striche extends CustomPainter {
  const _Striche();

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
  bool shouldRepaint(_Striche old) => false;
}

/// Gruppierte Liste, eingedrückt, Zeilen ohne eigenen Schatten
/// (styleguide.md, Card).
class _Verlaufsliste extends ConsumerWidget {
  const _Verlaufsliste({required this.mitglied, required this.eintraege});

  final Mitglied mitglied;
  final List<Eintrag> eintraege;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorten = ref.watch(sortenNamenProvider).value ?? const {};
    return BwEingedrueckt(
      padding: const EdgeInsets.symmetric(vertical: BwSpacing.space1),
      child: Column(
        children: [
          for (final e in eintraege)
            _EintragZeile(
              eintrag: e,
              titel: e.istStrich ? sorten[e.sorteId] ?? 'Sorte' : 'Zahlung',
              stornieren: e.istStrich && !e.storniert
                  ? () {
                      ref.read(kaderAktionenProvider).stornieren(mitglied, e);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Strich storniert.')),
                      );
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}

class _EintragZeile extends StatelessWidget {
  const _EintragZeile({
    required this.eintrag,
    required this.titel,
    required this.stornieren,
  });

  final Eintrag eintrag;
  final String titel;
  final VoidCallback? stornieren;

  static const mindestHoehe = 54.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final e = eintrag;
    final zusatz = [
      if (e.art == EintragArt.strichBar) 'bar',
      if (e.art == EintragArt.zahlung && e.ortId == 'kasse') 'in die Kasse',
      if (e.storniert) 'storniert',
    ];
    final unterzeile = [
      zeitText(e.zeit),
      'von ${vorname(e.von)}',
      ...zusatz,
    ].join(' · ');
    final betrag = e.art == EintragArt.zahlung
        ? '−${formatEuro(e.cents)}'
        : formatEuro(e.cents);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: mindestHoehe),
      child: Padding(
        padding: const EdgeInsets.only(
          left: BwSpacing.space4,
          right: BwSpacing.space1,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titel,
                    style: text.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: e.storniert ? BwColors.inkFaint : null,
                    ),
                  ),
                  Text(unterzeile, style: text.caption),
                ],
              ),
            ),
            Text(
              betrag,
              style: text.amountM.copyWith(
                color: e.storniert
                    ? BwColors.inkFaint
                    : e.art == EintragArt.zahlung
                    ? BwColors.positive
                    : BwColors.ink,
                decoration: e.storniert ? TextDecoration.lineThrough : null,
              ),
            ),
            SizedBox.square(
              dimension: BwIconKnopf.groesse,
              child: stornieren == null
                  ? null
                  : IconButton(
                      tooltip: 'Strich stornieren',
                      onPressed: stornieren,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: BwColors.inkMuted,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
