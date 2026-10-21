import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'flaechen.dart';
import 'knoepfe.dart';

/// Titel im Stil `screen-title`: ein voller Teil und ein Teil in Kontur
/// (Barlow Condensed 300), Großbuchstaben. Beispiel: KASSE *erstellen*.
class BwTitel extends StatelessWidget {
  const BwTitel({super.key, this.voll, this.kontur, this.danach});

  final String? voll;
  final String? kontur;
  final String? danach;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.screenTitle;
    final duenn = alsKontur(stil.copyWith(fontWeight: FontWeight.w300));
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          children: [
            if (voll != null)
              TextSpan(
                text: kontur == null && danach == null
                    ? voll!.toUpperCase()
                    : '${voll!.toUpperCase()} ',
              ),
            if (kontur != null)
              TextSpan(text: kontur!.toUpperCase(), style: duenn),
            if (danach != null) TextSpan(text: ' ${danach!.toUpperCase()}'),
          ],
        ),
        style: stil,
      ),
    );
  }
}

/// Grundgerüst der Onboarding-Seiten: optional Zurück-Button im Kopf, Inhalt
/// mit Seitenrand, die Aktionen unten. Scrollt, wenn die Tastatur Platz
/// braucht.
class BwSeite extends StatelessWidget {
  const BwSeite({
    super.key,
    required this.inhalt,
    this.aktionen = const [],
    this.zurueck,
    this.deko,
  });

  final List<Widget> inhalt;
  final List<Widget> aktionen;
  final VoidCallback? zurueck;

  /// Schmuck hinter dem Inhalt (Schraffur, Deko-Punkte).
  final List<Widget>? deko;

  @override
  Widget build(BuildContext context) {
    const abstand = SizedBox(height: BwSpacing.space5);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ...?deko,
            LayoutBuilder(
              builder: (context, raum) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  BwSpacing.space6,
                  BwSpacing.space4,
                  BwSpacing.space6,
                  BwSpacing.space6,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // Höhe ohne Innenrand oben und unten
                    minHeight:
                        raum.maxHeight - BwSpacing.space4 - BwSpacing.space6,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (zurueck != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: BwZurueck(onPressed: zurueck!),
                          )
                        else
                          const SizedBox(height: BwSpacing.space6 * 2),
                        abstand,
                        for (final (i, w) in inhalt.indexed) ...[
                          if (i > 0) abstand,
                          w,
                        ],
                        const Spacer(),
                        for (final w in aktionen) ...[abstand, w],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fließtext in `ink-muted` (Erklärungen unter dem Titel).
class BwErklaerung extends StatelessWidget {
  const BwErklaerung(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.body;
    return Text(text, style: stil.copyWith(color: BwColors.inkMuted));
  }
}

/// Fehlermeldung einer Aktion (NFA-10), über den Knöpfen.
class BwFehler extends StatelessWidget {
  const BwFehler(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.body;
    return Semantics(
      liveRegion: true,
      child: Text(text, style: stil.copyWith(color: BwColors.negative)),
    );
  }
}
