import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'flaechen.dart';

/// Abschnittslabel: 11px, Großbuchstaben, `ink-muted`.
class BwLabel extends StatelessWidget {
  const BwLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.label;
    return Text(text.toUpperCase(), style: stil);
  }
}

/// Eingabefeld: Label, eingedrücktes Feld (`inset`, `radius-lg`), darunter
/// Hinweis oder Fehler. Mit Fokus bekommt es den Verlaufsrahmen.
class BwFeld extends StatefulWidget {
  const BwFeld({
    super.key,
    required this.label,
    required this.controller,
    this.hinweis,
    this.fehler,
    this.platzhalter,
    this.betrag = false,
    this.tastatur,
    this.eingabeAktion = TextInputAction.next,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hinweis;
  final String? fehler;
  final String? platzhalter;

  /// Betrag: Display-Font mit Tabellenziffern (`amount-l`).
  final bool betrag;
  final TextInputType? tastatur;
  final TextInputAction eingabeAktion;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<BwFeld> createState() => _BwFeldState();
}

class _BwFeldState extends State<BwFeld> {
  final _fokus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fokus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fokus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final stil = widget.betrag ? text.amountL : text.name;
    final unten = widget.fehler ?? widget.hinweis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwLabel(widget.label),
        const SizedBox(height: BwSpacing.space2),
        BwEingedrueckt(
          rahmen: _fokus.hasFocus ? BwGradients.accent : null,
          padding: const EdgeInsets.symmetric(
            horizontal: BwSpacing.space4,
            vertical: BwSpacing.space3,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _fokus,
            autofocus: widget.autofocus,
            style: stil,
            cursorColor: BwColors.gradEnd,
            keyboardType: widget.tastatur,
            textInputAction: widget.eingabeAktion,
            textCapitalization: widget.betrag
                ? TextCapitalization.none
                : TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.platzhalter,
              hintStyle: stil.copyWith(color: BwColors.inkFaint),
            ),
          ),
        ),
        if (unten != null) ...[
          const SizedBox(height: BwSpacing.space2),
          Text(
            unten,
            style: text.caption.copyWith(
              color: widget.fehler != null ? BwColors.negative : null,
            ),
          ),
        ],
      ],
    );
  }
}
