import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/money/cents.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/sheet.dart';
import '../application/sorten.dart';

/// „Sorte anlegen“ als Sheet (BES-01, UI-03): Name und Preis. Der Bestand
/// startet bei 0 und kommt mit dem Einkauf.
Future<void> zeigeSorteAnlegen(BuildContext context) => zeigeSheet(
  context,
  titel: 'Sorte anlegen',
  inhalt: (_) => const _SorteAnlegen(),
);

class _SorteAnlegen extends ConsumerStatefulWidget {
  const _SorteAnlegen();

  @override
  ConsumerState<_SorteAnlegen> createState() => _SorteAnlegenState();
}

class _SorteAnlegenState extends ConsumerState<_SorteAnlegen> {
  final _name = TextEditingController();
  final _preis = TextEditingController();
  Eingabefehler _fehler = const Eingabefehler();

  @override
  void dispose() {
    _name.dispose();
    _preis.dispose();
    super.dispose();
  }

  void _anlegen() {
    final fehler = ref.read(sorteAnlegenProvider)(_name.text, _preis.text);
    if (fehler.keine) {
      Navigator.of(context).pop();
    } else {
      setState(() => _fehler = fehler);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwFeld(
          label: 'Name',
          controller: _name,
          autofocus: true,
          aufSheet: true,
          platzhalter: 'Bier 0,5',
          fehler: _fehler.name,
        ),
        const SizedBox(height: BwSpacing.space5),
        BwFeld(
          label: 'Verkaufspreis',
          controller: _preis,
          aufSheet: true,
          betrag: true,
          platzhalter: formatEuro(150),
          tastatur: const TextInputType.numberWithOptions(decimal: true),
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _anlegen(),
          fehler: _fehler.preis,
        ),
        if (_fehler.allgemein != null) ...[
          const SizedBox(height: BwSpacing.space4),
          BwFehler(_fehler.allgemein!),
        ],
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(text: 'Sorte anlegen', onPressed: _anlegen),
      ],
    );
  }
}
