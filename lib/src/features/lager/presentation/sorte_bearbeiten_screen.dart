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
import '../../strichliste/application/kasse_daten.dart';
import '../application/sorten.dart';
import '../domain/sorte.dart';

/// Sorte bearbeiten (BES-01, BES-02, BES-06): Name, Preis, Bestand
/// korrigieren, ausblenden.
class SorteBearbeitenScreen extends ConsumerWidget {
  const SorteBearbeitenScreen({super.key, required this.sorteId});

  final String sorteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorten = ref.watch(alleSortenProvider);
    final sorte = sorten.value?.where((s) => s.id == sorteId).firstOrNull;
    // Hält den Stempel-Namen geladen, damit Speichern sofort geht.
    ref.watch(sitzungProvider);
    void zurueck() =>
        context.canPop() ? context.pop() : context.go(Routen.lager);

    if (sorte == null) {
      return BwSeite(
        zurueck: zurueck,
        inhalt: [
          if (sorten.isLoading)
            const SizedBox.shrink()
          else
            const BwErklaerung('Diese Sorte gibt es nicht.'),
        ],
      );
    }
    // Neu aufbauen, wenn ein anderes Gerät Name, Preis oder Sichtbarkeit
    // ändert; ein neuer Bestand lässt die Eingaben stehen.
    return _Formular(
      key: ValueKey((sorte.id, sorte.name, sorte.preisCents, sorte.aktiv)),
      sorte: sorte,
      zurueck: zurueck,
    );
  }
}

class _Formular extends ConsumerStatefulWidget {
  const _Formular({super.key, required this.sorte, required this.zurueck});

  final Sorte sorte;
  final VoidCallback zurueck;

  @override
  ConsumerState<_Formular> createState() => _FormularState();
}

class _FormularState extends ConsumerState<_Formular> {
  late final _name = TextEditingController(text: widget.sorte.name);
  late final _preis = TextEditingController(
    text: formatEuro(widget.sorte.preisCents),
  );
  Eingabefehler _fehler = const Eingabefehler();

  @override
  void dispose() {
    _name.dispose();
    _preis.dispose();
    super.dispose();
  }

  void _speichern() {
    final fehler = ref
        .read(lagerAktionenProvider)
        .aendern(widget.sorte, _name.text, _preis.text);
    if (fehler.keine) {
      widget.zurueck();
    } else {
      setState(() => _fehler = fehler);
    }
  }

  Future<void> _sichtbar(bool aktiv) async {
    final sorte = widget.sorte;
    if (!aktiv && !await _ausblendenBestaetigt(context, sorte)) return;
    ref.read(lagerAktionenProvider).sichtbar(sorte, aktiv: aktiv);
    widget.zurueck();
  }

  @override
  Widget build(BuildContext context) {
    final sorte = widget.sorte;
    return BwSeite(
      zurueck: widget.zurueck,
      inhalt: [
        BwTitel(voll: sorte.name),
        BwFeld(label: 'Name', controller: _name, fehler: _fehler.name),
        BwFeld(
          label: 'Verkaufspreis pro Flasche',
          controller: _preis,
          betrag: true,
          tastatur: const TextInputType.numberWithOptions(decimal: true),
          eingabeAktion: TextInputAction.done,
          hinweis: 'Ein neuer Preis gilt nur für neue Striche.',
          fehler: _fehler.preis,
        ),
        _Bestand(sorte: sorte),
        const _Hinweis(
          '„Korrigieren“ setzt den Bestand auf einen gezählten Wert und '
          'schreibt einen Eintrag ins Log. Nachschub kommt über „Einkauf“.',
        ),
      ],
      aktionen: [
        if (_fehler.allgemein != null) BwFehler(_fehler.allgemein!),
        BwKnopf(text: 'Speichern', gross: true, onPressed: _speichern),
        if (sorte.aktiv)
          BwKnopf(
            text: 'Sorte ausblenden',
            art: BwKnopfArt.destruktiv,
            onPressed: () => _sichtbar(false),
          )
        else
          BwKnopf(
            text: 'Wieder einblenden',
            art: BwKnopfArt.outline,
            onPressed: () => _sichtbar(true),
          ),
      ],
    );
  }

  /// Bestätigung vor dem Ausblenden (UI-04).
  Future<bool> _ausblendenBestaetigt(BuildContext context, Sorte s) async {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final ja = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: BwColors.surfaceFloat,
        title: Text('„${s.name}“ ausblenden?', style: text.name),
        content: Text(
          'Die Sorte verschwindet von der Strichliste. Bestand und Striche '
          'bleiben, und im Lager lässt sie sich wieder einblenden.',
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
              'AUSBLENDEN',
              style: text.button.copyWith(color: BwColors.negative),
            ),
          ),
        ],
      ),
    );
    return ja ?? false;
  }
}

/// Bestand mit „Korrigieren“; leer gestrichelt in `negative`.
class _Bestand extends StatelessWidget {
  const _Bestand({required this.sorte});

  final Sorte sorte;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final leer = sorte.leer;
    final inhalt = Padding(
      padding: const EdgeInsets.all(BwSpacing.space4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BESTAND',
                  style: text.label.copyWith(
                    color: leer ? BwColors.negative : null,
                  ),
                ),
                Text(
                  sorte.bestand == 0
                      ? 'Leer · 0 Fl.'
                      : flaschenText(sorte.bestand),
                  style: text.amountL.copyWith(
                    color: leer ? BwColors.negative : null,
                  ),
                ),
              ],
            ),
          ),
          BwKnopf(
            text: 'Korrigieren',
            schmal: true,
            art: BwKnopfArt.sekundaer,
            onPressed: () => _zeigeKorrektur(context, sorte),
          ),
        ],
      ),
    );
    return leer
        ? CustomPaint(
            painter: const GestricheltPainter(
              radius: BwRadius.lg,
              farbe: BwColors.negative,
            ),
            child: inhalt,
          )
        : BwEingedrueckt(child: inhalt);
  }
}

/// „Bestand korrigieren“ (BES-06): gezählter Wert, nur mit Netz.
Future<void> _zeigeKorrektur(BuildContext context, Sorte sorte) => zeigeSheet(
  context,
  titel: 'Bestand zählen',
  inhalt: (_) => _Korrektur(sorte: sorte),
);

class _Korrektur extends ConsumerStatefulWidget {
  const _Korrektur({required this.sorte});

  final Sorte sorte;

  @override
  ConsumerState<_Korrektur> createState() => _KorrekturState();
}

class _KorrekturState extends ConsumerState<_Korrektur> {
  final _gezaehlt = TextEditingController();
  Eingabefehler _fehler = const Eingabefehler();
  bool _laedt = false;

  @override
  void dispose() {
    _gezaehlt.dispose();
    super.dispose();
  }

  Future<void> _korrigieren() async {
    setState(() => _laedt = true);
    final fehler = await ref
        .read(lagerAktionenProvider)
        .korrigieren(widget.sorte, _gezaehlt.text);
    if (!mounted) return;
    if (fehler.keine) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _fehler = fehler;
        _laedt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwFeld(
          label: 'Gezählte Flaschen · ${widget.sorte.name}',
          controller: _gezaehlt,
          autofocus: true,
          aufSheet: true,
          betrag: true,
          platzhalter: '${widget.sorte.bestand < 0 ? 0 : widget.sorte.bestand}',
          tastatur: TextInputType.number,
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _korrigieren(),
          hinweis: 'Zählen geht nur mit Netz.',
          fehler: _fehler.anzahl,
        ),
        if (_fehler.allgemein != null) ...[
          const SizedBox(height: BwSpacing.space4),
          BwFehler(_fehler.allgemein!),
        ],
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(text: 'Bestand setzen', laedt: _laedt, onPressed: _korrigieren),
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
    return Text(text, style: stil);
  }
}
