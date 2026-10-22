import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../application/aufloesen.dart';

/// Während eine aufgelöste Kasse gelöscht wird (ADM-05, UC-10). Startet das
/// Löschen selbst, auch nach einem Neustart, und zeigt, wie weit es ist.
/// Danach führt die Weiterleitung ins Onboarding.
class AufloesenScreen extends ConsumerStatefulWidget {
  const AufloesenScreen({super.key});

  @override
  ConsumerState<AufloesenScreen> createState() => _AufloesenScreenState();
}

class _AufloesenScreenState extends ConsumerState<AufloesenScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(aufloesenProvider.notifier).loeschen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(aufloesenProvider);
    return BwSeite(
      inhalt: [
        const BwTitel(voll: 'Kasse', kontur: 'wird aufgelöst'),
        BwErklaerung(
          a.fehler == null
              ? 'Alle Daten werden gelöscht. Lass die App offen und bleib im '
                    'Netz. ${a.geloescht} Einträge sind schon weg.'
              : 'Bisher sind ${a.geloescht} Einträge gelöscht. Die Kasse '
                    'bleibt aufgelöst; niemand außer dir sieht sie noch.',
        ),
        if (a.fehler != null)
          BwFehler(a.fehler!)
        else
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox.square(
              dimension: BwSpacing.space6,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BwColors.gradEnd,
              ),
            ),
          ),
      ],
      aktionen: [
        if (a.fehler != null)
          BwKnopf(
            text: 'Weiter löschen',
            gross: true,
            onPressed: ref.read(aufloesenProvider.notifier).loeschen,
          ),
      ],
    );
  }
}
