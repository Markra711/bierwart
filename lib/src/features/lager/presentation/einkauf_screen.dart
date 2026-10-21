import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/money/cents.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/sheet.dart';
import '../../kader/application/kader_daten.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../application/sorten.dart';
import '../domain/sorte.dart';

/// Einkauf als eigene Seite (BES-04, BES-05, UI-03): Zeilen aus Sorte und
/// Anzahl, ein Gesamtpreis, bezahlt aus dem eigenen Portemonnaie oder für
/// den Kassenwart aus der Kasse.
class EinkaufScreen extends ConsumerStatefulWidget {
  const EinkaufScreen({super.key});

  @override
  ConsumerState<EinkaufScreen> createState() => _EinkaufScreenState();
}

class _Zeile {
  String? sorteId;
  int anzahl = 0;
}

class _EinkaufScreenState extends ConsumerState<EinkaufScreen> {
  final _zeilen = [_Zeile()];
  final _preis = TextEditingController();
  Eingabefehler _fehler = const Eingabefehler();
  bool _ausDerKasse = false;

  @override
  void initState() {
    super.initState();
    _preis.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _preis.dispose();
    super.dispose();
  }

  void _zurueck() =>
      context.canPop() ? context.pop() : context.go(Routen.lager);

  void _einbuchen(Map<String, int> zeilen) {
    final fehler = ref
        .read(lagerAktionenProvider)
        .einkaufen(zeilen, _preis.text, ausDerKasse: _ausDerKasse);
    if (fehler.keine) {
      _zurueck();
    } else {
      setState(() => _fehler = fehler);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final sorten = (ref.watch(sortenProvider).value ?? const <Sorte>[]);
    final kassenwart = ref.watch(istKassenwartProvider);
    ref.watch(sitzungProvider);
    final zeilen = einkaufZeilen([
      for (final z in _zeilen) (z.sorteId, z.anzahl),
    ]);
    final flaschen = zeilen.values.fold(0, (a, b) => a + b);
    final preis = parseEuro(_preis.text);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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
                      BwZurueck(onPressed: _zurueck),
                      const SizedBox(width: BwSpacing.space3),
                      Semantics(
                        header: true,
                        child: Text('EINKAUF', style: text.pageTitle),
                      ),
                    ],
                  ),
                  const SizedBox(height: BwSpacing.space5),
                  for (final (i, z) in _zeilen.indexed) ...[
                    _ZeilenKarte(
                      zeile: z,
                      sorten: sorten,
                      geaendert: () => setState(() {}),
                      entfernen: _zeilen.length > 1
                          ? () => setState(() => _zeilen.removeAt(i))
                          : null,
                    ),
                    const SizedBox(height: BwSpacing.space4),
                  ],
                  if (_zeilen.length < einkaufMaxSorten)
                    _NeueZeile(
                      onTap: () => setState(() => _zeilen.add(_Zeile())),
                    ),
                  const SizedBox(height: BwSpacing.space5),
                  BwFeld(
                    label: 'Gesamtpreis',
                    controller: _preis,
                    betrag: true,
                    platzhalter: formatEuro(0),
                    tastatur: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    eingabeAktion: TextInputAction.done,
                    fehler: _fehler.preis,
                  ),
                  if (kassenwart) ...[
                    const SizedBox(height: BwSpacing.space5),
                    const BwLabel('Bezahlt aus'),
                    const SizedBox(height: BwSpacing.space2),
                    Row(
                      children: [
                        Expanded(
                          child: _Wahl(
                            text: 'Mein Portemonnaie',
                            gewaehlt: !_ausDerKasse,
                            onTap: () => setState(() => _ausDerKasse = false),
                          ),
                        ),
                        const SizedBox(width: BwSpacing.space4),
                        Expanded(
                          child: _Wahl(
                            text: 'Kasse',
                            gewaehlt: _ausDerKasse,
                            onTap: () => setState(() => _ausDerKasse = true),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: BwSpacing.space3),
                    Text(
                      'Bezahlt aus deinem Portemonnaie.',
                      style: text.caption,
                    ),
                  ],
                  if (_fehler.allgemein != null) ...[
                    const SizedBox(height: BwSpacing.space4),
                    BwFehler(_fehler.allgemein!),
                  ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: BwColors.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BwSpacing.space5,
                  BwSpacing.space3,
                  BwSpacing.space5,
                  BwSpacing.space5,
                ),
                child: BwKnopf(
                  text: flaschen == 0
                      ? 'Einbuchen'
                      : '$flaschen ${flaschen == 1 ? 'Flasche' : 'Flaschen'} '
                            'einbuchen${preis == null ? '' : ' · ${formatEuro(preis)}'}',
                  gross: true,
                  onPressed: () => _einbuchen(zeilen),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Zeile: Sorte wählen, Anzahl, Schnellknöpfe +1, +6, +20, +24.
class _ZeilenKarte extends StatelessWidget {
  const _ZeilenKarte({
    required this.zeile,
    required this.sorten,
    required this.geaendert,
    required this.entfernen,
  });

  final _Zeile zeile;
  final List<Sorte> sorten;
  final VoidCallback geaendert;
  final VoidCallback? entfernen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final sorte = sorten.where((s) => s.id == zeile.sorteId).firstOrNull;
    return BwErhaben(
      padding: const EdgeInsets.all(BwSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Sorte wählen, ${sorte?.name ?? 'keine gewählt'}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final id = await _sorteWaehlen(context, sorten);
                      if (id != null) {
                        zeile.sorteId = id;
                        geaendert();
                      }
                    },
                    child: BwEingedrueckt(
                      radius: BwRadius.md,
                      schatten: BwShadows.insetSm,
                      padding: const EdgeInsets.symmetric(
                        horizontal: BwSpacing.space4,
                        vertical: BwSpacing.space3,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              sorte?.name ?? 'Sorte wählen',
                              style: text.name.copyWith(
                                color: sorte == null ? BwColors.inkMuted : null,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.expand_more_rounded,
                            color: BwColors.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: BwSpacing.space3),
              SizedBox(
                width: BwSpacing.space6 * 2,
                child: Text(
                  '${zeile.anzahl}',
                  textAlign: TextAlign.right,
                  style: text.amountL,
                ),
              ),
              if (entfernen != null)
                IconButton(
                  tooltip: 'Zeile entfernen',
                  onPressed: entfernen,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: BwColors.inkMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: BwSpacing.space3),
          Row(
            children: [
              for (final (i, n) in einkaufSchnell.indexed) ...[
                if (i > 0) const SizedBox(width: BwSpacing.space2),
                Expanded(
                  child: BwKnopf(
                    text: '+$n',
                    art: BwKnopfArt.sekundaer,
                    onPressed: () {
                      zeile.anzahl += n;
                      geaendert();
                    },
                  ),
                ),
              ],
              const SizedBox(width: BwSpacing.space2),
              IconButton(
                tooltip: 'Anzahl auf 0',
                onPressed: zeile.anzahl == 0
                    ? null
                    : () {
                        zeile.anzahl = 0;
                        geaendert();
                      },
                icon: const Icon(Icons.restart_alt_rounded, size: 20),
                color: BwColors.inkMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<String?> _sorteWaehlen(
    BuildContext context,
    List<Sorte> sorten,
  ) => zeigeSheet<String>(
    context,
    titel: 'Sorte wählen',
    inhalt: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in sorten) ...[
          BwKnopf(
            text: s.name,
            art: BwKnopfArt.outline,
            onPressed: () => Navigator.of(sheet).pop(s.id),
          ),
          const SizedBox(height: BwSpacing.space3),
        ],
      ],
    ),
  );
}

/// „+ Zeile“: gestrichelt, wie ein noch leerer Platz.
class _NeueZeile extends StatelessWidget {
  const _NeueZeile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.button;
    return Semantics(
      button: true,
      label: 'Zeile hinzufügen',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: BwKnopf.hoehe,
          child: CustomPaint(
            painter: const GestricheltPainter(radius: BwRadius.pill),
            child: Center(child: Text('+ ZEILE', style: stil)),
          ),
        ),
      ),
    );
  }
}

/// Wahl der Quelle: erhaben, gewählt eingedrückt mit Verlaufsrahmen.
class _Wahl extends StatelessWidget {
  const _Wahl({
    required this.text,
    required this.gewaehlt,
    required this.onTap,
  });

  final String text;
  final bool gewaehlt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.name;
    final inhalt = Center(child: Text(text, style: stil));
    return Semantics(
      button: true,
      selected: gewaehlt,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: BwKnopf.hoehe,
          child: gewaehlt
              ? BwEingedrueckt(
                  radius: BwRadius.md,
                  schatten: BwShadows.insetSm,
                  rahmen: BwGradients.accent,
                  child: inhalt,
                )
              : BwErhaben(
                  radius: BwRadius.md,
                  schatten: BwShadows.raisedSm,
                  child: inhalt,
                ),
        ),
      ),
    );
  }
}
