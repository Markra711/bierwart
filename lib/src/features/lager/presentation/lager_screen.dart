import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/tab_seite.dart';
import '../../strichliste/application/kasse_daten.dart';

/// Tab 03 (UI-02). Bis zum eigenen Ausbau ein Platzhalter.
class LagerScreen extends ConsumerWidget {
  const LagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BwTabSeite(
      nummer: '03',
      titel: 'Lager',
      kassenName: ref.watch(kassenNameProvider).value,
      einstellungen: () => context.push(Routen.einstellungen),
      kinder: const [
        BwErklaerung('Hier entstehen Bestand und Einkauf (BES-03, BES-04).'),
      ],
    );
  }
}
