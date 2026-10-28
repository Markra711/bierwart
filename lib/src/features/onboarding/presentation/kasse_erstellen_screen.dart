import '../../../core/fehler/verwaltung.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/cents.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../kader/domain/name.dart';
import '../application/onboarding.dart';
import '../../../core/widgets/zustimmung.dart';

/// Kasse erstellen (UC-01, AUTH-02): Kassenname, eigener Name, Startbetrag.
class KasseErstellenScreen extends ConsumerStatefulWidget {
  const KasseErstellenScreen({super.key});

  @override
  ConsumerState<KasseErstellenScreen> createState() =>
      _KasseErstellenScreenState();
}

class _KasseErstellenScreenState extends ConsumerState<KasseErstellenScreen> {
  final _kasse = TextEditingController();
  final _name = TextEditingController();
  final _start = TextEditingController();
  String? _kasseFehler;
  String? _nameFehler;
  String? _startFehler;
  String? _fehler;
  bool _laedt = false;

  @override
  void dispose() {
    _kasse.dispose();
    _name.dispose();
    _start.dispose();
    super.dispose();
  }

  Future<void> _erstellen() async {
    final start = _start.text.trim().isEmpty ? 0 : parseEuro(_start.text);
    setState(() {
      _kasseFehler = namePruefen(_kasse.text);
      _nameFehler = namePruefen(_name.text);
      _startFehler = start == null ? 'Betrag wie 50,00 eingeben.' : null;
      _fehler = null;
    });
    if (_kasseFehler != null || _nameFehler != null || start == null) return;

    setState(() => _laedt = true);
    try {
      await ref
          .read(ersteKasseProvider.notifier)
          .erstellen(
            kassenName: _kasse.text,
            eigenerName: _name.text,
            startCents: start,
          );
      // Weiter geht es über die Weiterleitung zum Wiederherstellungscode.
    } on VerwaltungsFehler catch (e) {
      if (mounted) setState(() => _fehler = e.meldung);
    } catch (_) {
      if (mounted) {
        setState(() => _fehler = 'Die Kasse ließ sich nicht erstellen.');
      }
    } finally {
      if (mounted) setState(() => _laedt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return BwSeite(
      zurueck: _laedt ? null : () => context.go(Routen.willkommen),
      inhalt: [
        const BwTitel(voll: 'Kasse', kontur: 'erstellen'),
        BwFeld(
          label: 'Name der Kasse',
          controller: _kasse,
          fehler: _kasseFehler,
          platzhalter: 'SV Eichwald · 1. Herren',
        ),
        BwFeld(
          label: 'Dein Name · Vor- und Nachname',
          controller: _name,
          fehler: _nameFehler,
          hinweis: 'So stehst du im Kader und im Verlauf.',
        ),
        BwFeld(
          label: 'Startbetrag in der Kasse',
          controller: _start,
          fehler: _startFehler,
          platzhalter: formatEuro(0),
          betrag: true,
          tastatur: const TextInputType.numberWithOptions(decimal: true),
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _erstellen(),
        ),
        BwErhaben(
          padding: const EdgeInsets.symmetric(
            horizontal: BwSpacing.space4,
            vertical: BwSpacing.space4,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                right: -BwSpacing.space6 - BwSpacing.space1,
                top: -BwSpacing.space6 - BwSpacing.space1,
                child: BwSchraffur(durchmesser: 48),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Du wirst '),
                    _fett('Admin'),
                    const TextSpan(text: ' und '),
                    _fett('Kassenwart'),
                    const TextSpan(
                      text:
                          '. Beides kannst du später an andere Bierwarte '
                          'abgeben.',
                    ),
                  ],
                ),
                style: text.caption,
              ),
            ],
          ),
        ),
      ],
      aktionen: [
        if (_fehler != null) BwFehler(_fehler!),
        const BwZustimmung(knopf: 'Kasse erstellen'),
        BwKnopf(
          text: 'Kasse erstellen',
          gross: true,
          laedt: _laedt,
          onPressed: _erstellen,
        ),
      ],
    );
  }

  static TextSpan _fett(String s) => TextSpan(
    text: s,
    style: const TextStyle(color: BwColors.ink, fontWeight: FontWeight.w800),
  );
}
