import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/verwaltung.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/karten.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/sheet.dart';
import '../../kader/domain/eintrag.dart';
import '../../onboarding/application/uebernahme.dart';
import '../../onboarding/domain/einladung.dart';

/// Offene „Das bin ich“-Anfragen (UC-03, ADR-0008). Steht oben auf der
/// Strichliste und in den Einstellungen (offene Frage 23); ohne Anfrage
/// nimmt es keinen Platz weg.
class AnfragenHinweis extends ConsumerWidget {
  const AnfragenHinweis({super.key, this.mitLabel = false});

  /// In den Einstellungen mit Abschnittslabel, auf der Strichliste ohne.
  final bool mitLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(offeneAnfragenProvider);
    if (liste.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mitLabel) ...[
          const BwLabel('Anfragen'),
          const SizedBox(height: BwSpacing.space3),
        ],
        for (final (i, a) in liste.indexed) ...[
          if (i > 0) const SizedBox(height: BwSpacing.space4),
          _AnfrageKarte(anfrage: a),
        ],
      ],
    );
  }
}

class _AnfrageKarte extends StatelessWidget {
  const _AnfrageKarte({required this.anfrage});

  final OffeneAnfrage anfrage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return BwErhaben(
      radius: BwRadius.lg,
      padding: const EdgeInsets.all(BwSpacing.space4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: anfrage.binIch ? 'Du' : anfrage.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: anfrage.binIch
                            ? ' auf einem neuen Handy?'
                            : ' will mit neuem Handy rein.',
                        style: const TextStyle(color: BwColors.inkMuted),
                      ),
                    ],
                  ),
                  style: text.body,
                ),
                Text(anfrage.anfrage.angefragtText, style: text.caption),
              ],
            ),
          ),
          const SizedBox(width: BwSpacing.space3),
          BwKnopf(
            text: 'Ansehen',
            art: BwKnopfArt.outline,
            schmal: true,
            onPressed: () => zeigeAnfrage(context, anfrage),
          ),
        ],
      ),
    );
  }
}

/// Bestätigen oder ablehnen (UC-03, ADR-0008).
Future<void> zeigeAnfrage(BuildContext context, OffeneAnfrage anfrage) =>
    zeigeSheet<void>(
      context,
      titel: '${anfrage.name}?',
      inhalt: (_) => _Entscheiden(anfrage: anfrage),
    );

class _Entscheiden extends ConsumerStatefulWidget {
  const _Entscheiden({required this.anfrage});

  final OffeneAnfrage anfrage;

  @override
  ConsumerState<_Entscheiden> createState() => _EntscheidenState();
}

class _EntscheidenState extends ConsumerState<_Entscheiden> {
  bool _laedt = false;
  String? _fehler;

  Future<void> _ausfuehren(
    Future<void> Function(UebernahmeAktionen a) aktion,
    String? erfolg,
  ) async {
    final navigator = Navigator.of(context);
    final boten = ScaffoldMessenger.of(context);
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      await aktion(ref.read(uebernahmeAktionenProvider));
      navigator.pop();
      if (erfolg != null) boten.showSnackBar(SnackBar(content: Text(erfolg)));
    } on VerwaltungsFehler catch (e) {
      if (mounted) setState(() => _fehler = e.meldung);
    } finally {
      if (mounted) setState(() => _laedt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.anfrage;
    final wer = vorname(a.name);
    final bis = a.anfrage.gueltigBis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwErklaerung(
          a.binIch
              ? 'Jemand will mit einem neuen Handy als du in die Kasse. Bist '
                    'du das selbst, bestätige. Dieses Handy verliert dann den '
                    'Zugang, Portemonnaie und Rollen gehen aufs neue.'
              : 'Jemand will mit einem neuen Handy als ${a.name} in die '
                    'Kasse. Bestätige nur, wenn du sicher bist, dass es $wer '
                    'ist. Frag im Zweifel kurz nach. Das alte Handy verliert '
                    'dann den Zugang, Portemonnaie und Rollen gehen mit.',
        ),
        const SizedBox(height: BwSpacing.space4),
        BwHinweis(
          [
            a.anfrage.angefragtText,
            if (bis != null) 'gilt bis ${gueltigBisText(bis)}',
          ].join(' · '),
        ),
        const SizedBox(height: BwSpacing.space5),
        if (_fehler != null) ...[
          BwFehler(_fehler!),
          const SizedBox(height: BwSpacing.space3),
        ],
        BwKnopf(
          text: a.binIch ? 'Ja, das bin ich' : 'Das ist $wer',
          laedt: _laedt,
          onPressed: () => _ausfuehren(
            (x) => x.bestaetigen(a.anfrage),
            a.binIch ? null : '$wer ist wieder drin.',
          ),
        ),
        const SizedBox(height: BwSpacing.space3),
        BwKnopf(
          text: 'Ablehnen',
          art: BwKnopfArt.outline,
          onPressed: _laedt
              ? null
              : () => _ausfuehren(
                  (x) => x.ablehnen(a.anfrage),
                  'Anfrage abgelehnt.',
                ),
        ),
      ],
    );
  }
}
