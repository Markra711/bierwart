import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/sheet.dart';
import '../application/mitglieder.dart';

/// „Mitglied anlegen“ als Sheet (KAD-01, UI-03): nur der Name. Wer die App
/// hat, tritt selbst per Link bei; hier kommen Mitglieder ohne App dazu.
Future<void> zeigeMitgliedAnlegen(BuildContext context) => zeigeSheet(
  context,
  titel: 'Mitglied anlegen',
  inhalt: (_) => const _MitgliedAnlegen(),
);

class _MitgliedAnlegen extends ConsumerStatefulWidget {
  const _MitgliedAnlegen();

  @override
  ConsumerState<_MitgliedAnlegen> createState() => _MitgliedAnlegenState();
}

class _MitgliedAnlegenState extends ConsumerState<_MitgliedAnlegen> {
  final _name = TextEditingController();
  Eingabefehler _fehler = const Eingabefehler();
  bool _prueft = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _anlegen() async {
    setState(() => _prueft = true);
    final fehler = await ref.read(mitgliedAnlegenProvider)(_name.text);
    if (!mounted) return;
    if (fehler.keine) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _fehler = fehler;
        _prueft = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwFeld(
          label: 'Vor- und Nachname',
          controller: _name,
          autofocus: true,
          aufSheet: true,
          hinweis: 'So steht das Mitglied im Kader und auf der Strichliste.',
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _anlegen(),
          fehler: _fehler.name,
        ),
        if (_fehler.allgemein != null) ...[
          const SizedBox(height: BwSpacing.space4),
          BwFehler(_fehler.allgemein!),
        ],
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(text: 'Mitglied anlegen', laedt: _prueft, onPressed: _anlegen),
      ],
    );
  }
}
