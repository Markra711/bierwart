import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/money/cents.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/karten.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/sheet.dart';
import '../application/geld.dart';

/// „Kassensturz“ (GEL-06), nur für den Kassenwart: gezählten Betrag
/// eintragen, die Differenz zum Stand laut App kommt als
/// „Kassendifferenz“ ins Log. Braucht Netz und wartet auf den Server.
Future<void> zeigeKassensturz(BuildContext context) => zeigeSheet(
  context,
  titel: 'Kassensturz',
  inhalt: (_) => const _Kassensturz(),
);

class _Kassensturz extends ConsumerStatefulWidget {
  const _Kassensturz();

  @override
  ConsumerState<_Kassensturz> createState() => _KassensturzState();
}

class _KassensturzState extends ConsumerState<_Kassensturz> {
  final _gezaehlt = TextEditingController();
  Eingabefehler _fehler = const Eingabefehler();
  bool _laeuft = false;

  @override
  void initState() {
    super.initState();
    _gezaehlt.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _gezaehlt.dispose();
    super.dispose();
  }

  Future<void> _buchen(int stand) async {
    setState(() => _laeuft = true);
    final fehler = await ref
        .read(geldAktionenProvider)
        .kassensturz(_gezaehlt.text, gesehenCents: stand);
    if (!mounted) return;
    if (fehler.keine) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _laeuft = false;
        _fehler = fehler;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final stand = ref.watch(geldstandProvider).value?.kasse?.standCents ?? 0;
    final gezaehlt = parseEuro(_gezaehlt.text);
    final differenz = gezaehlt == null ? null : gezaehlt - stand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BwErklaerung(
          'Zähl das Geld in der Kassette und trag den Betrag ein.',
        ),
        const SizedBox(height: BwSpacing.space4),
        _Zeile(
          label: 'Laut App in der Kasse',
          betrag: Text(formatEuro(stand), style: text.amountL),
        ),
        const SizedBox(height: BwSpacing.space4),
        BwFeld(
          label: 'Gezählt',
          controller: _gezaehlt,
          aufSheet: true,
          betrag: true,
          autofocus: true,
          platzhalter: formatEuro(0),
          tastatur: const TextInputType.numberWithOptions(decimal: true),
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _laeuft ? null : _buchen(stand),
          fehler: _fehler.preis,
        ),
        if (differenz != null) ...[
          const SizedBox(height: BwSpacing.space4),
          if (differenz == 0)
            _Zeile(
              label: 'Stimmt genau',
              betrag: Text(
                formatEuro(0),
                style: text.amountL.copyWith(color: BwColors.positive),
              ),
            )
          else
            _Differenz(differenz),
        ],
        const SizedBox(height: BwSpacing.space4),
        const BwHinweis(
          'Die Differenz wird mit deinem Namen ins Log gebucht. Danach stimmt '
          'der Kassenstand wieder.',
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
          text: 'Kassensturz buchen',
          gross: true,
          laedt: _laeuft,
          onPressed: () => _buchen(stand),
        ),
      ],
    );
  }
}

/// Erhabene Zeile mit Label links und Betrag rechts.
class _Zeile extends StatelessWidget {
  const _Zeile({required this.label, required this.betrag});

  final String label;
  final Widget betrag;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BwColors.surfaceFloat,
        borderRadius: BorderRadius.circular(BwRadius.lg),
        boxShadow: BwShadows.boxShadows(BwSheet.raisedSm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BwSpacing.space4,
          vertical: BwSpacing.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                label,
                style: text.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            betrag,
          ],
        ),
      ),
    );
  }
}

/// Kassendifferenz: gestrichelt und schraffiert in `negative`, mit
/// Vorzeichen (styleguide.md, `negative`).
class _Differenz extends StatelessWidget {
  const _Differenz(this.cents);

  final int cents;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final betrag = cents > 0 ? '+${formatEuro(cents)}' : formatEuro(cents);
    return CustomPaint(
      painter: const GestricheltPainter(
        radius: BwRadius.lg,
        farbe: BwColors.negative,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BwSpacing.space4,
          vertical: BwSpacing.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Kassendifferenz',
                style: text.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: BwColors.negative,
                ),
              ),
            ),
            Text(
              betrag,
              style: text.amountL.copyWith(color: BwColors.negative),
            ),
          ],
        ),
      ),
    );
  }
}
