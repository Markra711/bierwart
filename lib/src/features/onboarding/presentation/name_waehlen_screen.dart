import '../../../core/fehler/verwaltung.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../kader/domain/name.dart';
import '../application/onboarding.dart';
import '../domain/codes.dart';
import '../domain/einladung.dart';

/// „Wie heißt du?“: Namenswahl beim Beitreten (UC-02, AUTH-07). Ein
/// vergebener Name wird erkannt; „Das bin ich“ (UC-03) kommt mit dem
/// Warte-Bildschirm aus dem Design-Canvas.
class NameWaehlenScreen extends ConsumerStatefulWidget {
  const NameWaehlenScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<NameWaehlenScreen> createState() => _NameWaehlenScreenState();
}

class _NameWaehlenScreenState extends ConsumerState<NameWaehlenScreen> {
  final _name = TextEditingController();
  final _fokus = FocusNode();
  String? _nameFehler;
  String? _fehler;
  String? _vergeben;
  bool _laedt = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (_vergeben != null && nameKey(_name.text) != nameKey(_vergeben!)) {
        setState(() => _vergeben = null);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _fokus.dispose();
    super.dispose();
  }

  Future<void> _beitreten(Einladung einladung) async {
    setState(() {
      _nameFehler = namePruefen(_name.text);
      _fehler = null;
    });
    if (_nameFehler != null) return;
    setState(() => _laedt = true);
    try {
      final ergebnis = await ref
          .read(beitrittProvider.notifier)
          .beitreten(einladung, _name.text);
      if (ergebnis == Beitritt.nameVergeben && mounted) {
        setState(() => _vergeben = nameBereinigen(_name.text));
      }
      // Bei Erfolg geht es über die Weiterleitung zur Strichliste.
    } on VerwaltungsFehler catch (e) {
      if (mounted) setState(() => _fehler = e.meldung);
    } catch (_) {
      if (mounted) setState(() => _fehler = 'Der Beitritt hat nicht geklappt.');
    } finally {
      if (mounted) setState(() => _laedt = false);
    }
  }

  void _andererName() {
    _name.clear();
    _fokus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final code = einladungscodeAus(widget.code);
    final einladung = code == null
        ? null
        : ref.watch(einladungProvider(code)).value;
    final zurueck = _laedt
        ? null
        : () => context.go(
            code == null
                ? Routen.linkEinfuegen
                : Routen.mitCode(Routen.beitreten, code),
          );

    return BwSeite(
      zurueck: zurueck,
      inhalt: [
        const BwTitel(voll: 'Wie heißt', kontur: 'du?'),
        BwFeld(
          label: 'Vor- und Nachname',
          controller: _name,
          fokus: _fokus,
          fehler: _nameFehler,
          hinweis: 'So stehst du im Kader und im Verlauf.',
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) {
            if (einladung != null) _beitreten(einladung);
          },
        ),
        if (_vergeben != null)
          _NameVergeben(name: _vergeben!, andererName: _andererName),
      ],
      aktionen: [
        if (_fehler != null) BwFehler(_fehler!),
        BwKnopf(
          text: 'Beitreten',
          gross: true,
          laedt: _laedt,
          onPressed: einladung == null || _vergeben != null
              ? null
              : () => _beitreten(einladung),
        ),
      ],
    );
  }
}

/// Karte, wenn der Name in der Kasse schon vergeben ist (AUTH-07).
class _NameVergeben extends StatelessWidget {
  const _NameVergeben({required this.name, required this.andererName});

  final String name;
  final VoidCallback andererName;

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
              child: BwSchraffur(
                durchmesser: 80,
                farbe: BwColors.lineStrong,
                winkel: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BwSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '„$name“ gibt es hier schon. ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(
                            text:
                                'Wähl einen anderen Namen, zum Beispiel mit '
                                'Spitznamen oder zweitem Vornamen.',
                            style: TextStyle(color: BwColors.inkMuted),
                          ),
                        ],
                      ),
                      style: text.body,
                    ),
                  ),
                  const SizedBox(height: BwSpacing.space4),
                  BwKnopf(
                    text: 'Anderen Namen wählen',
                    art: BwKnopfArt.outline,
                    onPressed: andererName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
