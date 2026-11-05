import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/fehler/verwaltung.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/karten.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../application/uebernahme.dart';
import '../domain/einladung.dart';
import '../domain/uebernahme.dart';

/// „Das bin ich“ auf dem neuen Gerät (UC-03, ADR-0008): Bis ein Bierwart
/// entscheidet, ist das Gerät kein Bierwart und sieht nur den Stand der
/// Anfrage. Ohne Push meldet sich die App nicht von selbst bei den anderen;
/// deshalb der Hinweis, Bescheid zu sagen.
class WartenScreen extends ConsumerStatefulWidget {
  const WartenScreen({super.key});

  @override
  ConsumerState<WartenScreen> createState() => _WartenScreenState();
}

class _WartenScreenState extends ConsumerState<WartenScreen> {
  bool _laedt = false;
  String? _fehler;

  Future<void> _ausfuehren(Future<void> Function() aktion) async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      await aktion();
    } on VerwaltungsFehler catch (e) {
      if (mounted) setState(() => _fehler = e.meldung);
    } finally {
      if (mounted) setState(() => _laedt = false);
    }
  }

  UebernahmeAnfrageNotifier get _anfrage =>
      ref.read(uebernahmeAnfrageProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final wartend = ref.watch(uebernahmeAnfrageProvider);
    final stand = ref.watch(eigeneAnfrageProvider);

    // Bestätigt: Kasse eintragen, dann führt die Weiterleitung hinein. Nur
    // beim Wechsel auf „bestätigt“, sonst schriebe jede neue Fassung des
    // Dokuments noch einmal.
    ref.listen(eigeneAnfrageProvider, (vorher, neu) {
      const b = UebernahmeStatus.bestaetigt;
      if (neu.value?.status == b && vorher?.value?.status != b) {
        _ausfuehren(_anfrage.abschliessen);
      }
    });

    if (wartend == null) return const BwSeite(inhalt: [], aktionen: []);

    final kopf = [
      BwVerlaufText('DAS BIN ICH', style: text.label),
      const BwTitel(voll: 'Kurz', kontur: 'warten'),
      _Anfragekarte(kassenName: wartend.kassenName, name: wartend.name),
    ];
    final fehler = [if (_fehler != null) BwFehler(_fehler!)];
    BwKnopf zumStart(BwKnopfArt art) => BwKnopf(
      text: 'Zum Start',
      art: art,
      gross: true,
      onPressed: _anfrage.verwerfen,
    );

    final jetzt = DateTime.now();
    return switch (stand) {
      AsyncData(value: final a?) when a.istOffen(jetzt) => BwSeite(
        inhalt: [
          ...kopf,
          BwErklaerung(
            'Ein Bierwart aus der Kasse muss bestätigen, dass du das bist. '
            'Sag kurz Bescheid, die App meldet sich bei den anderen nicht von '
            'selbst. Hattest du ein Portemonnaie oder eine Rolle, kommt beides '
            'mit.',
          ),
          if (a.gueltigBis case final bis?)
            BwHinweis('Die Anfrage gilt bis ${gueltigBisText(bis)}'),
          const BwHinweis(
            'Bist du der einzige Bierwart? Dann geht es nur mit dem '
            'Wiederherstellungscode.',
          ),
        ],
        aktionen: [
          ...fehler,
          BwKnopf(
            text: 'Ich habe einen Wiederherstellungscode',
            art: BwKnopfArt.sekundaer,
            gross: true,
            laedt: _laedt,
            onPressed: () => _ausfuehren(() async {
              await _anfrage.zurueckziehen();
              if (context.mounted) context.go(Routen.wiederherstellen);
            }),
          ),
          BwKnopf(
            text: 'Anfrage zurückziehen',
            art: BwKnopfArt.outline,
            gross: true,
            laedt: _laedt,
            onPressed: () => _ausfuehren(_anfrage.zurueckziehen),
          ),
        ],
      ),
      AsyncData(value: final a?) when a.status == UebernahmeStatus.bestaetigt =>
        BwSeite(
          inhalt: [
            ...kopf,
            const BwErklaerung('Bestätigt. Gleich bist du drin.'),
            if (_fehler == null) const _Laden(),
          ],
          aktionen: [
            ...fehler,
            if (_fehler != null)
              BwKnopf(
                text: 'Nochmal versuchen',
                gross: true,
                laedt: _laedt,
                onPressed: () => _ausfuehren(_anfrage.abschliessen),
              ),
          ],
        ),
      AsyncData(:final value) => BwSeite(
        inhalt: [
          ...kopf,
          BwErklaerung(switch (value) {
            Uebernahme(status: UebernahmeStatus.abgelehnt) =>
              'Die Anfrage wurde abgelehnt. War das ein Versehen, frag noch '
                  'einmal an oder tritt mit einem anderen Namen bei.',
            Uebernahme(status: UebernahmeStatus.zurueckgezogen) =>
              'Die Anfrage ist zurückgezogen.',
            Uebernahme() =>
              'Die Anfrage ist abgelaufen, niemand hat sie in 7 Tagen '
                  'bestätigt. Frag nach einem neuen Link und versuch es noch '
                  'einmal.',
            null => 'Die Anfrage gibt es nicht mehr.',
          }),
        ],
        aktionen: [zumStart(BwKnopfArt.primaer)],
      ),
      AsyncError() => BwSeite(
        inhalt: [
          ...kopf,
          const BwFehler(
            'Die Anfrage ließ sich nicht laden. Vielleicht gibt es die Kasse '
            'nicht mehr.',
          ),
        ],
        aktionen: [
          BwKnopf(
            text: 'Nochmal versuchen',
            gross: true,
            onPressed: () => ref.invalidate(eigeneAnfrageProvider),
          ),
          zumStart(BwKnopfArt.outline),
        ],
      ),
      _ => BwSeite(inhalt: [...kopf, const _Laden()], aktionen: const []),
    };
  }
}

/// Kassenname und „als Jonas Weber“, wie die Karte bei „Kasse beitreten?“.
class _Anfragekarte extends StatelessWidget {
  const _Anfragekarte({required this.kassenName, required this.name});

  final String kassenName;
  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return BwErhaben(
      radius: BwRadius.xl,
      schatten: BwShadows.raisedLg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BwRadius.xl),
        child: Stack(
          children: [
            const Positioned(
              right: -BwSpacing.space5,
              top: -BwSpacing.space5,
              child: BwSchraffur(durchmesser: 80),
            ),
            Padding(
              padding: const EdgeInsets.all(BwSpacing.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(kassenName.toUpperCase(), style: text.pageTitle),
                  const SizedBox(height: BwSpacing.space1),
                  Text('als $name, mit neuem Handy', style: text.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Laden extends StatelessWidget {
  const _Laden();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: SizedBox.square(
      dimension: BwSpacing.space6,
      child: CircularProgressIndicator(strokeWidth: 2, color: BwColors.gradEnd),
    ),
  );
}
