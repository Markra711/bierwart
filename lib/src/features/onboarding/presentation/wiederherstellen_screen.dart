import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/karten.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/wahl.dart';
import '../application/wiederherstellung.dart';
import '../domain/wiederherstellung.dart';
import 'wiederherstellungscode_screen.dart';

/// Mit dem Wiederherstellungscode zurück in die Kasse (ADM-06, UC-03, UC-04,
/// ADR-0010): Code eingeben, sagen, wer man ist, Admin werden und den neuen
/// Code einmal sehen.
class WiederherstellenScreen extends ConsumerWidget {
  const WiederherstellenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(wiederherstellungProvider);
    final notifier = ref.read(wiederherstellungProvider.notifier);
    return switch (w.schritt) {
      WiederherstellungsSchritt.code => _CodeEingeben(w: w),
      WiederherstellungsSchritt.auswahl => _Auswahl(w: w),
      WiederherstellungsSchritt.neuerCode => CodeEinmalZeigen(
        code: w.neuerCode!,
        kassenName: w.stand?.kassenName ?? '',
        titel: 'Dein neuer',
        weiter: notifier.abschliessen,
      ),
    };
  }
}

class _CodeEingeben extends ConsumerStatefulWidget {
  const _CodeEingeben({required this.w});

  final Wiederherstellung w;

  @override
  ConsumerState<_CodeEingeben> createState() => _CodeEingebenState();
}

class _CodeEingebenState extends ConsumerState<_CodeEingeben> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _pruefen() {
    if (!widget.w.laeuft) {
      ref.read(wiederherstellungProvider.notifier).codePruefen(_code.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BwSeite(
      zurueck: () => context.go(Routen.willkommen),
      inhalt: [
        const BwTitel(voll: 'Mit Code', kontur: 'zurück'),
        const BwErklaerung(
          'Mit dem Wiederherstellungscode kommst du in deine Kasse zurück und '
          'wirst Admin. Den Code hat bekommen, wer die Kasse erstellt hat.',
        ),
        BwFeld(
          label: 'Wiederherstellungscode',
          controller: _code,
          autofocus: true,
          platzhalter: 'K7QM-3XRA-9DWF-T2HC',
          schreibweise: TextCapitalization.characters,
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _pruefen(),
          fehler: widget.w.fehler,
        ),
      ],
      aktionen: [
        BwKnopf(
          text: 'Weiter',
          gross: true,
          laedt: widget.w.laeuft,
          onPressed: _pruefen,
        ),
      ],
    );
  }
}

class _Auswahl extends ConsumerStatefulWidget {
  const _Auswahl({required this.w});

  final Wiederherstellung w;

  @override
  ConsumerState<_Auswahl> createState() => _AuswahlState();
}

class _AuswahlState extends ConsumerState<_Auswahl> {
  final _name = TextEditingController();
  Kandidat? _kandidat;
  bool _neu = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _eintreten() {
    if (widget.w.laeuft) return;
    ref
        .read(wiederherstellungProvider.notifier)
        .eintreten(
          kandidat: _neu ? null : _kandidat,
          neuerName: _neu ? _name.text : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final stand = widget.w.stand!;
    final gewaehlt = _neu || _kandidat != null;
    return BwSeite(
      zurueck: ref.read(wiederherstellungProvider.notifier).zurueck,
      inhalt: [
        BwLabel(stand.kassenName),
        const BwTitel(voll: 'Wer', kontur: 'bist du?'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final k in stand.sortiert) ...[
              BwWahlKarte(
                text: k.name,
                unterzeile: stand.beschreibung(k),
                gewaehlt: !_neu && _kandidat?.mitgliedId == k.mitgliedId,
                onTap: () => setState(() {
                  _kandidat = k;
                  _neu = false;
                }),
              ),
              const SizedBox(height: BwSpacing.space3),
            ],
            BwWahlKarte(
              text: 'Ich bin neu dabei',
              gewaehlt: _neu,
              onTap: () => setState(() => _neu = true),
            ),
          ],
        ),
        if (_neu)
          BwFeld(
            label: 'Wie heißt du?',
            controller: _name,
            autofocus: true,
            eingabeAktion: TextInputAction.done,
            onSubmitted: (_) => _eintreten(),
            fehler: widget.w.fehler,
          )
        else if (widget.w.fehler != null)
          BwFehler(widget.w.fehler!),
        const BwHinweis(
          'Ein altes Portemonnaie bleibt als „ehemalig“ stehen, bis der '
          'Kassenwart es per Übergabe ausgleicht.',
        ),
      ],
      aktionen: [
        BwKnopf(
          text: 'Admin werden',
          gross: true,
          laedt: widget.w.laeuft,
          onPressed: gewaehlt ? _eintreten : null,
        ),
      ],
    );
  }
}
