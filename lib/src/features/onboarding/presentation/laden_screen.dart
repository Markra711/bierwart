import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../application/onboarding.dart';
import '../data/anmeldung_repository.dart';

/// Während der Anmeldung (AUTH-01). Schlägt sie fehl, steht hier warum, mit
/// „Nochmal versuchen“, statt endlos zu laden (NFA-10).
class LadenScreen extends ConsumerWidget {
  const LadenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final zustand = ref.watch(startzustandProvider);
    return BwSeite(
      inhalt: [
        Text('BIERWART', style: text.screenTitle),
        if (zustand case StartFehler(:final meldung))
          BwFehler(meldung)
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
        if (zustand is StartFehler)
          BwKnopf(
            text: 'Nochmal versuchen',
            gross: true,
            onPressed: () => ref.invalidate(anmeldungProvider),
          ),
      ],
    );
  }
}
