import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/tab_seite.dart';
import '../../strichliste/application/kasse_daten.dart';

/// Tab 04 (UI-02). Bis zum eigenen Ausbau ein Platzhalter.
class GeldScreen extends ConsumerWidget {
  const GeldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BwTabSeite(
      nummer: '04',
      titel: 'Geld',
      kassenName: ref.watch(kassenNameProvider).value,
      einstellungen: () => context.push(Routen.einstellungen),
      kinder: const [
        BwErklaerung('Hier entstehen Kasse und Portemonnaies (GEL-01).'),
      ],
    );
  }
}
