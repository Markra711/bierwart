import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/money/cents.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/sheet.dart';
import '../../../core/widgets/wahl.dart';
import '../../kader/application/kader_daten.dart';
import '../application/geld.dart';

/// „Geld bewegen“ (GEL-05): Ein- oder Auszahlung mit Grund. Aus dem eigenen
/// Portemonnaie; nur der Kassenwart sieht und wählt die Kasse (UI-08).
Future<void> zeigeEinAuszahlung(BuildContext context) => zeigeSheet(
  context,
  titel: 'Geld bewegen',
  inhalt: (_) => const _EinAuszahlung(),
);

/// Häufige Gründe als Schnellwahl. „Sonstiges“ leert das Feld zum Tippen.
const gruendeAuszahlung = ['Schiri bezahlt', 'Auslage erstattet'];
const gruendeEinzahlung = ['Spende', 'Auslage zurück'];
const _sonstiges = 'Sonstiges';

class _EinAuszahlung extends ConsumerStatefulWidget {
  const _EinAuszahlung();

  @override
  ConsumerState<_EinAuszahlung> createState() => _EinAuszahlungState();
}

class _EinAuszahlungState extends ConsumerState<_EinAuszahlung> {
  final _betrag = TextEditingController();
  final _grund = TextEditingController();
  final _grundFokus = FocusNode();
  Eingabefehler _fehler = const Eingabefehler();
  bool _einzahlung = false;
  bool _kasse = true;

  @override
  void initState() {
    super.initState();
    _betrag.addListener(() => setState(() {}));
    _grund.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _betrag.dispose();
    _grund.dispose();
    _grundFokus.dispose();
    super.dispose();
  }

  void _buchen() {
    final fehler = ref
        .read(geldAktionenProvider)
        .bewegen(
          einzahlung: _einzahlung,
          betragText: _betrag.text,
          grund: _grund.text,
          kasse: _kasse,
        );
    if (fehler.keine) {
      Navigator.of(context).pop();
    } else {
      setState(() => _fehler = fehler);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final kassenwart = ref.watch(istKassenwartProvider);
    final betrag = parseEuro(_betrag.text);
    final gruende = _einzahlung ? gruendeEinzahlung : gruendeAuszahlung;
    final grund = _grund.text.trim();
    final sonstiges = grund.isNotEmpty && !gruende.contains(grund);
    final verb = _einzahlung ? 'einzahlen' : 'auszahlen';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwUmschalter(
          links: 'Einzahlung',
          rechts: 'Auszahlung',
          linksGewaehlt: _einzahlung,
          onChanged: (ein) => setState(() {
            _einzahlung = ein;
            if (gruendeEinzahlung.contains(grund) ||
                gruendeAuszahlung.contains(grund)) {
              _grund.clear();
            }
          }),
        ),
        const SizedBox(height: BwSpacing.space5),
        BwFeld(
          label: 'Betrag',
          controller: _betrag,
          aufSheet: true,
          betrag: true,
          platzhalter: formatEuro(0),
          tastatur: const TextInputType.numberWithOptions(decimal: true),
          fehler: _fehler.preis,
        ),
        const SizedBox(height: BwSpacing.space4),
        BwFeld(
          label: 'Grund',
          controller: _grund,
          fokus: _grundFokus,
          aufSheet: true,
          platzhalter: gruende.first,
          schreibweise: TextCapitalization.sentences,
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _buchen(),
          fehler: _fehler.grund,
        ),
        const SizedBox(height: BwSpacing.space3),
        Wrap(
          spacing: BwSpacing.space3,
          runSpacing: BwSpacing.space3,
          children: [
            for (final g in gruende)
              BwChip(
                text: g,
                hoehe: 36,
                gewaehlt: grund == g,
                onTap: () => _grund.text = g,
              ),
            BwChip(
              text: _sonstiges,
              hoehe: 36,
              gewaehlt: sonstiges,
              onTap: () {
                if (!sonstiges) _grund.clear();
                _grundFokus.requestFocus();
              },
            ),
          ],
        ),
        const SizedBox(height: BwSpacing.space5),
        if (kassenwart) ...[
          BwLabel(_einzahlung ? 'Geld geht in' : 'Geld kommt aus'),
          const SizedBox(height: BwSpacing.space2),
          Row(
            children: [
              Expanded(
                child: BwWahlKarte(
                  text: _einzahlung ? 'die Kasse' : 'der Kasse',
                  unterzeile: 'nur Kassenwart',
                  aufSheet: true,
                  gewaehlt: _kasse,
                  onTap: () => setState(() => _kasse = true),
                ),
              ),
              const SizedBox(width: BwSpacing.space4),
              Expanded(
                child: BwWahlKarte(
                  text: _einzahlung
                      ? 'mein Portemonnaie'
                      : 'meinem Portemonnaie',
                  aufSheet: true,
                  gewaehlt: !_kasse,
                  onTap: () => setState(() => _kasse = false),
                ),
              ),
            ],
          ),
        ] else
          Text(
            _einzahlung
                ? 'Das Geld kommt in dein Portemonnaie.'
                : 'Das Geld kommt aus deinem Portemonnaie.',
            style: text.caption,
          ),
        if (_fehler.allgemein != null) ...[
          const SizedBox(height: BwSpacing.space3),
          Text(
            _fehler.allgemein!,
            style: text.caption.copyWith(color: BwColors.negative),
          ),
        ],
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(
          text: betrag != null && betrag > 0
              ? '${formatEuro(betrag)} $verb'
              : verb[0].toUpperCase() + verb.substring(1),
          gross: true,
          onPressed: _buchen,
        ),
      ],
    );
  }
}
