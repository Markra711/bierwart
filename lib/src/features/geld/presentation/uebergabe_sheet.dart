import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/money/cents.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/karten.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/sheet.dart';
import '../../../core/widgets/wahl.dart';
import '../../kader/domain/eintrag.dart';
import '../../onboarding/data/anmeldung_repository.dart';
import '../application/geld.dart';
import '../domain/ort.dart';

/// „Übergabe“ (GEL-04), nur für den Kassenwart: Geld aus einem Portemonnaie
/// in die Kasse oder aus der Kasse in ein Portemonnaie. Der Betrag startet
/// mit dem, was sich ausgleichen lässt.
Future<void> zeigeUebergabe(BuildContext context) =>
    zeigeSheet(context, titel: 'Übergabe', inhalt: (_) => const _Uebergabe());

/// Vorschlag für den Betrag: In die Kasse geht, was im Portemonnaie liegt;
/// aus der Kasse, was sie dem Bierwart schuldet.
int? uebergabeVorschlag(Ort o, {required bool inDieKasse}) {
  final cents = inDieKasse ? o.standCents : -o.standCents;
  return cents > 0 ? cents : null;
}

class _Uebergabe extends ConsumerStatefulWidget {
  const _Uebergabe();

  @override
  ConsumerState<_Uebergabe> createState() => _UebergabeState();
}

class _UebergabeState extends ConsumerState<_Uebergabe> {
  final _betrag = TextEditingController();
  Eingabefehler _fehler = const Eingabefehler();
  bool _inDieKasse = true;
  String? _ortId;

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

  void _waehlen(Ort o, bool inDieKasse) {
    setState(() {
      _ortId = o.id;
      _inDieKasse = inDieKasse;
    });
    final vorschlag = uebergabeVorschlag(o, inDieKasse: inDieKasse);
    _betrag.text = vorschlag == null ? '' : formatEuro(vorschlag);
  }

  void _buchen(Ort? o) {
    if (o == null) {
      setState(
        () => _fehler = const Eingabefehler(allgemein: 'Bierwart wählen.'),
      );
      return;
    }
    final fehler = ref
        .read(geldAktionenProvider)
        .uebergeben(o, _betrag.text, inDieKasse: _inDieKasse);
    if (fehler.keine) {
      Navigator.of(context).pop();
    } else {
      setState(() => _fehler = fehler);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final uid = ref.watch(anmeldungProvider).value;
    final portemonnaies =
        ref.watch(geldstandProvider).value?.portemonnaies ?? const <Ort>[];
    // Ohne Wahl das erste Portemonnaie mit etwas zum Ausgleichen.
    if (_ortId == null && portemonnaies.isNotEmpty) {
      final start = portemonnaies.firstWhere(
        (o) => o.standCents > 0,
        orElse: () => portemonnaies.first,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ortId == null) _waehlen(start, _inDieKasse);
      });
    }
    final gewaehlt = portemonnaies.where((o) => o.id == _ortId).firstOrNull;
    final betrag = parseEuro(_betrag.text);
    final wer = gewaehlt == null
        ? null
        : gewaehlt.id == uid
        ? 'mir'
        : vorname(gewaehlt.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwUmschalter(
          links: 'In die Kasse',
          rechts: 'Aus der Kasse',
          linksGewaehlt: _inDieKasse,
          onChanged: (rein) => gewaehlt == null
              ? setState(() => _inDieKasse = rein)
              : _waehlen(gewaehlt, rein),
        ),
        const SizedBox(height: BwSpacing.space5),
        BwLabel(_inDieKasse ? 'Von Bierwart' : 'An Bierwart'),
        const SizedBox(height: BwSpacing.space2),
        for (final (i, o) in portemonnaies.indexed) ...[
          if (i > 0) const SizedBox(height: BwSpacing.space3),
          BwWahlKarte(
            text: o.id == uid ? '${o.name} (du)' : o.name,
            unterzeile: o.ehemalig ? 'ehemalig' : null,
            aufSheet: true,
            gewaehlt: o.id == _ortId,
            onTap: () => _waehlen(o, _inDieKasse),
            rechts: Text(
              formatEuro(o.standCents),
              style: text.amountM.copyWith(
                color: o.standCents < 0 ? BwColors.negative : null,
              ),
            ),
          ),
        ],
        const SizedBox(height: BwSpacing.space5),
        BwFeld(
          label: _inDieKasse ? 'Betrag erhalten' : 'Betrag gegeben',
          controller: _betrag,
          aufSheet: true,
          betrag: true,
          platzhalter: formatEuro(0),
          tastatur: const TextInputType.numberWithOptions(decimal: true),
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _buchen(gewaehlt),
          fehler: _fehler.preis,
        ),
        const SizedBox(height: BwSpacing.space4),
        const BwHinweis(
          'Nur der Kassenwart bucht Übergaben. „Aus der Kasse“ ist Geld für '
          'einen Einkauf oder eine erstattete Auslage.',
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
          text: betrag == null || betrag <= 0 || wer == null
              ? 'Übergabe buchen'
              : _inDieKasse
              ? '${formatEuro(betrag)} von $wer erhalten'
              : '${formatEuro(betrag)} an $wer geben',
          gross: true,
          onPressed: () => _buchen(gewaehlt),
        ),
      ],
    );
  }
}
