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
import '../../kader/application/mitglieder.dart';
import '../../kader/domain/eintrag.dart';
import '../../kader/domain/mitglied.dart';

/// „Zahlung erfassen“ (GEL-02, GEL-03): Betrag frei, der offene Betrag als
/// Vorschlag, Schnellwahl. Der Knopf nennt den Betrag. Nur der Kassenwart
/// sieht die Wahl, wohin das Geld geht (UI-08).
Future<void> zeigeZahlung(BuildContext context, Mitglied m) => zeigeSheet(
  context,
  titel: 'Zahlung von ${vorname(m.name)}',
  inhalt: (_) => _Zahlung(mitglied: m),
);

class _Zahlung extends ConsumerStatefulWidget {
  const _Zahlung({required this.mitglied});

  final Mitglied mitglied;

  @override
  ConsumerState<_Zahlung> createState() => _ZahlungState();
}

class _ZahlungState extends ConsumerState<_Zahlung> {
  late final _betrag = TextEditingController(
    text: widget.mitglied.saldoCents > 0
        ? formatEuro(widget.mitglied.saldoCents)
        : '',
  );
  Eingabefehler _fehler = const Eingabefehler();
  bool _inDieKasse = true;

  @override
  void initState() {
    super.initState();
    _betrag.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _betrag.dispose();
    super.dispose();
  }

  void _verbuchen() {
    final fehler = ref
        .read(kaderAktionenProvider)
        .zahlen(widget.mitglied, _betrag.text, inDieKasse: _inDieKasse);
    if (fehler.keine) {
      Navigator.of(context).pop();
    } else {
      setState(() => _fehler = fehler);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final offen = widget.mitglied.saldoCents;
    final betrag = parseEuro(_betrag.text);
    final kassenwart = ref.watch(istKassenwartProvider);
    final schnell = [
      (text: '5 €', cents: 500),
      (text: '10 €', cents: 1000),
      (text: '20 €', cents: 2000),
      if (offen > 0) (text: 'Alles', cents: offen),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwFeld(
          label: offen > 0 ? 'Betrag · offen ${formatEuro(offen)}' : 'Betrag',
          controller: _betrag,
          aufSheet: true,
          betrag: true,
          platzhalter: formatEuro(0),
          tastatur: const TextInputType.numberWithOptions(decimal: true),
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _verbuchen(),
          fehler: _fehler.preis ?? _fehler.allgemein,
        ),
        const SizedBox(height: BwSpacing.space4),
        Row(
          children: [
            for (final (i, s) in schnell.indexed) ...[
              if (i > 0) const SizedBox(width: BwSpacing.space3),
              Expanded(
                child: BwChip(
                  text: s.text,
                  gewaehlt: betrag == s.cents,
                  onTap: () => _betrag.text = formatEuro(s.cents),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: BwSpacing.space5),
        if (kassenwart) ...[
          const BwLabel('Geld geht in'),
          const SizedBox(height: BwSpacing.space2),
          Row(
            children: [
              Expanded(
                child: BwChip(
                  text: 'die Kasse',
                  gewaehlt: _inDieKasse,
                  onTap: () => setState(() => _inDieKasse = true),
                ),
              ),
              const SizedBox(width: BwSpacing.space4),
              Expanded(
                child: BwChip(
                  text: 'mein Portemonnaie',
                  gewaehlt: !_inDieKasse,
                  onTap: () => setState(() => _inDieKasse = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: BwSpacing.space4),
        ] else ...[
          Text('Das Geld kommt in dein Portemonnaie.', style: text.caption),
          const SizedBox(height: BwSpacing.space2),
        ],
        Text('Mehr als offen? Der Rest wird Guthaben.', style: text.caption),
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(
          text: betrag != null && betrag > 0
              ? '${formatEuro(betrag)} verbuchen'
              : 'Verbuchen',
          gross: true,
          onPressed: _verbuchen,
        ),
      ],
    );
  }
}
