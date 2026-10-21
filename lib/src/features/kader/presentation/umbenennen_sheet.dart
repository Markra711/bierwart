import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/sheet.dart';
import '../application/mitglieder.dart';
import '../domain/mitglied.dart';

/// Mitglied umbenennen (KAD-01, UI-09), Name nur einmal pro Kasse.
Future<void> zeigeUmbenennen(BuildContext context, Mitglied m) => zeigeSheet(
  context,
  titel: 'Umbenennen',
  inhalt: (_) => _Umbenennen(mitglied: m),
);

class _Umbenennen extends ConsumerStatefulWidget {
  const _Umbenennen({required this.mitglied});

  final Mitglied mitglied;

  @override
  ConsumerState<_Umbenennen> createState() => _UmbenennenState();
}

class _UmbenennenState extends ConsumerState<_Umbenennen> {
  late final _name = TextEditingController(text: widget.mitglied.name);
  Eingabefehler _fehler = const Eingabefehler();
  bool _prueft = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _umbenennen() async {
    setState(() => _prueft = true);
    final fehler = await ref
        .read(kaderAktionenProvider)
        .umbenennen(widget.mitglied, _name.text);
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
          hinweis: 'Der neue Name steht ab jetzt im Kader und im Verlauf.',
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _umbenennen(),
          fehler: _fehler.name ?? _fehler.allgemein,
        ),
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(text: 'Umbenennen', laedt: _prueft, onPressed: _umbenennen),
      ],
    );
  }
}
