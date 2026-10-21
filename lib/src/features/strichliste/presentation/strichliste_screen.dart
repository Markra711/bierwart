import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/cents.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/tab_seite.dart';
import '../../kader/domain/mitglied.dart';
import '../../lager/domain/sorte.dart';
import '../../lager/presentation/sorte_anlegen_sheet.dart';
import '../application/kasse_daten.dart';
import '../application/strichliste.dart';
import '../domain/strich.dart';

/// Die Strichliste, Tab 01 und Startseite (STR-01, UI-01): oben die Sorten,
/// darunter alle Mitglieder. Tippen bucht offen, Halten bar (STR-02,
/// STR-03), in höchstens zwei Tipps (NFA-06).
class StrichlisteScreen extends ConsumerWidget {
  const StrichlisteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorten = ref.watch(sortenProvider);
    final mitglieder = ref.watch(mitgliederProvider);
    final aktuelle = ref.watch(aktuelleSorteProvider);
    final letzter = ref.watch(strichlisteProvider);
    // Hält Kasse, UID und Stempel-Namen geladen, damit der erste Tipp bucht.
    ref.watch(sitzungProvider);

    void buchen(Mitglied m, {required bool gehalten}) {
      if (aktuelle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leg zuerst eine Sorte an.')),
        );
        return;
      }
      if (ref
          .read(strichlisteProvider.notifier)
          .buchen(m, gehalten: gehalten)) {
        HapticFeedback.selectionClick();
      }
    }

    return BwTabSeite(
      nummer: '01',
      titel: 'Strichliste',
      kassenName: ref.watch(kassenNameProvider).value,
      einstellungen: () => context.push(Routen.einstellungen),
      kinder: [
        switch (sorten) {
          AsyncData(value: final liste) when liste.isEmpty =>
            const _OhneSorte(),
          AsyncData(value: final liste) => _SortenAuswahl(
            sorten: liste,
            gewaehlt: aktuelle,
          ),
          AsyncError() => const BwFehler('Die Sorten ließen sich nicht laden.'),
          _ => const _Laden(),
        },
        const _Gestenhinweis(),
        switch (mitglieder) {
          AsyncData(value: final liste) => _MitgliederRaster(
            mitglieder: liste,
            sorte: aktuelle,
            letzter: letzter,
            buchen: buchen,
          ),
          AsyncError() => const BwFehler(
            'Die Mitglieder ließen sich nicht laden.',
          ),
          _ => const _Laden(),
        },
      ],
      unten: letzter == null ? null : _Rueckgaengig(strich: letzter),
    );
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

/// Ohne Sorte lässt sich nicht buchen; dann zeigt die Seite, was zu tun ist.
class _OhneSorte extends StatelessWidget {
  const _OhneSorte();

  @override
  Widget build(BuildContext context) {
    return BwErhaben(
      radius: BwRadius.xl,
      schatten: BwShadows.raisedLg,
      padding: const EdgeInsets.all(BwSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BwErklaerung(
            'Noch keine Sorte. Leg die erste an, dann kannst du buchen.',
          ),
          const SizedBox(height: BwSpacing.space4),
          BwKnopf(
            text: 'Sorte anlegen',
            onPressed: () => zeigeSorteAnlegen(context),
          ),
        ],
      ),
    );
  }
}

/// Raster mit drei Spalten, ab 10 Sorten eine Liste (UI-05). Die Auswahl
/// bleibt über App-Neustarts (UI-07).
class _SortenAuswahl extends ConsumerWidget {
  const _SortenAuswahl({required this.sorten, required this.gewaehlt});

  final List<Sorte> sorten;
  final Sorte? gewaehlt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spalten = sorten.length >= sortenAlsListeAb ? 1 : 3;
    return Semantics(
      label: 'Getränkesorte',
      container: true,
      child: _Raster(
        spalten: spalten,
        kinder: [
          for (final s in sorten)
            _SortenKachel(
              sorte: s,
              gewaehlt: s.id == gewaehlt?.id,
              waehlen: () =>
                  ref.read(gewaehlteSorteProvider.notifier).waehlen(s.id),
            ),
        ],
      ),
    );
  }
}

/// Raster mit gleich breiten Spalten und `space-4` Abstand (styleguide.md,
/// Tile).
class _Raster extends StatelessWidget {
  const _Raster({required this.spalten, required this.kinder});

  final int spalten;
  final List<Widget> kinder;

  @override
  Widget build(BuildContext context) {
    const abstand = BwSpacing.space4;
    return LayoutBuilder(
      builder: (context, raum) {
        final breite = (raum.maxWidth - abstand * (spalten - 1)) / spalten;
        return Wrap(
          spacing: abstand,
          runSpacing: abstand,
          children: [for (final k in kinder) SizedBox(width: breite, child: k)],
        );
      },
    );
  }
}

class _SortenKachel extends StatelessWidget {
  const _SortenKachel({
    required this.sorte,
    required this.gewaehlt,
    required this.waehlen,
  });

  final Sorte sorte;
  final bool gewaehlt;
  final VoidCallback waehlen;

  static const hoehe = 56.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final preis = sorte.leer
        ? Text(
            'leer',
            style: text.caption.copyWith(
              color: BwColors.negative,
              fontWeight: FontWeight.w700,
            ),
          )
        : gewaehlt
        ? BwVerlaufText(
            formatEuro(sorte.preisCents),
            style: text.caption.copyWith(fontWeight: FontWeight.w700),
          )
        : Text(formatEuro(sorte.preisCents), style: text.caption);
    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BwSpacing.space3,
        vertical: BwSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            sorte.name,
            style: text.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          preis,
        ],
      ),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: gewaehlt,
      button: true,
      label:
          '${sorte.name}, ${formatEuro(sorte.preisCents)}'
          '${sorte.leer ? ', leer' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: waehlen,
        child: SizedBox(
          height: hoehe,
          child: gewaehlt
              ? _Anfasser(
                  child: BwEingedrueckt(
                    radius: BwRadius.md,
                    schatten: BwShadows.insetSm,
                    rahmen: BwGradients.accent,
                    child: SizedBox.expand(child: inhalt),
                  ),
                )
              : BwErhaben(
                  radius: BwRadius.md,
                  schatten: BwShadows.raisedSm,
                  child: SizedBox.expand(child: inhalt),
                ),
        ),
      ),
    );
  }
}

/// Die vier Anfasser der Auswahlbox an den Ecken (styleguide.md,
/// Wireframe-Details).
class _Anfasser extends StatelessWidget {
  const _Anfasser({required this.child});

  final Widget child;

  static const _groesse = 6.0;

  @override
  Widget build(BuildContext context) {
    Widget ecke({double? l, double? t, double? r, double? b}) => Positioned(
      left: l,
      top: t,
      right: r,
      bottom: b,
      child: const SizedBox.square(
        dimension: _groesse,
        child: ColoredBox(color: BwColors.handle),
      ),
    );
    const aussen = -_groesse;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: child),
        ecke(l: aussen, t: aussen),
        ecke(r: aussen, t: aussen),
        ecke(l: aussen, b: aussen),
        ecke(r: aussen, b: aussen),
      ],
    );
  }
}

class _Gestenhinweis extends StatelessWidget {
  const _Gestenhinweis();

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.caption;
    return ExcludeSemantics(
      child: Row(
        children: [
          Text('Tippen = offen', style: stil),
          const SizedBox(width: BwSpacing.space2),
          const Expanded(
            child: SizedBox(
              height: 1,
              child: CustomPaint(painter: _Strichlinie()),
            ),
          ),
          const SizedBox(width: BwSpacing.space2),
          Text('Halten = bar', style: stil),
        ],
      ),
    );
  }
}

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

class _MitgliederRaster extends StatelessWidget {
  const _MitgliederRaster({
    required this.mitglieder,
    required this.sorte,
    required this.letzter,
    required this.buchen,
  });

  final List<Mitglied> mitglieder;
  final Sorte? sorte;
  final Strich? letzter;
  final void Function(Mitglied, {required bool gehalten}) buchen;

  @override
  Widget build(BuildContext context) {
    return _Raster(
      spalten: 3,
      kinder: [
        for (final m in mitglieder)
          _MitgliedKachel(
            mitglied: m,
            sorte: sorte,
            geradeGebucht: letzter?.mitglied.id == m.id ? letzter : null,
            tippen: () => buchen(m, gehalten: false),
            halten: () => buchen(m, gehalten: true),
          ),
      ],
    );
  }
}

/// Mitgliederkachel in vier Zuständen: normal, Guthaben, gerade gebucht,
/// „Gäste“ (styleguide.md, Tile).
class _MitgliedKachel extends StatelessWidget {
  const _MitgliedKachel({
    required this.mitglied,
    required this.sorte,
    required this.geradeGebucht,
    required this.tippen,
    required this.halten,
  });

  final Mitglied mitglied;
  final Sorte? sorte;
  final Strich? geradeGebucht;
  final VoidCallback tippen;
  final VoidCallback halten;

  static const hoehe = 74.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final saldo = mitglied.saldoCents;
    final gebucht = geradeGebucht;

    final Widget unten;
    if (mitglied.istGast) {
      unten = Text('immer bar', style: text.caption);
    } else if (gebucht != null) {
      unten = BwVerlaufText(
        gebucht.art == StrichArt.offen ? '${formatEuro(saldo)} +1' : '+1 bar',
        style: text.amountM,
      );
    } else {
      unten = Text(
        saldo == 0
            ? '—'
            : saldo < 0
            ? '+${formatEuro(-saldo)}'
            : formatEuro(saldo),
        style: text.amountM.copyWith(
          color: saldo == 0
              ? BwColors.inkFaint
              : saldo < 0
              ? BwColors.positive
              : BwColors.ink,
        ),
      );
    }

    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BwSpacing.space3,
        vertical: BwSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            mitglied.name,
            style: text.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FittedBox(fit: BoxFit.scaleDown, child: unten),
        ],
      ),
    );

    final Widget flaeche;
    if (mitglied.istGast) {
      flaeche = CustomPaint(
        painter: const GestricheltPainter(radius: BwRadius.lg, breite: 1),
        child: SizedBox.expand(child: inhalt),
      );
    } else if (gebucht != null) {
      flaeche = BwEingedrueckt(
        radius: BwRadius.lg,
        schatten: BwShadows.insetSm,
        rahmen: BwGradients.accent,
        child: SizedBox.expand(child: inhalt),
      );
    } else {
      flaeche = BwErhaben(child: SizedBox.expand(child: inhalt));
    }

    final s = sorte?.name ?? 'eine Sorte';
    return Semantics(
      button: true,
      label:
          '${mitglied.name}, '
          '${mitglied.istGast
              ? 'immer bar'
              : saldo == 0
              ? 'nichts offen'
              : saldo < 0
              ? '${formatEuro(-saldo)} Guthaben'
              : '${formatEuro(saldo)} offen'}',
      onTapHint: mitglied.istGast ? '$s bar buchen' : '$s offen buchen',
      onLongPressHint: '$s bar buchen',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tippen,
        onLongPress: halten,
        child: SizedBox(height: hoehe, child: flaeche),
      ),
    );
  }
}

/// Snackbar nach einer Buchung mit „Rückgängig“ (STR-04): bis zur nächsten
/// Buchung, höchstens 8 Sekunden, nur auf diesem Gerät.
class _Rueckgaengig extends ConsumerWidget {
  const _Rueckgaengig({required this.strich});

  final Strich strich;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final art = strich.art == StrichArt.offen ? 'offen' : 'bar';
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          BwSpacing.space5,
          BwSpacing.space2,
          BwSpacing.space2,
          BwSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: BwColors.surfaceFloat,
          borderRadius: BorderRadius.circular(BwRadius.xl),
          boxShadow: BwShadows.boxShadows(BwShadows.float),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${strich.mitglied.name} · ${strich.sorte.name} · '
                '${formatEuro(strich.preisCents)} $art',
                style: text.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: BwSpacing.space2),
            BwKnopf(
              text: 'Rückgängig',
              schmal: true,
              onPressed: () =>
                  ref.read(strichlisteProvider.notifier).rueckgaengig(),
            ),
          ],
        ),
      ),
    );
  }
}
