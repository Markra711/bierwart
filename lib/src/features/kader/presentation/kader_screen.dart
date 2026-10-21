import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/tab_seite.dart';
import '../../strichliste/application/kasse_daten.dart';

/// Tab 02 (UI-02). Bis zum eigenen Ausbau ein Platzhalter.
class KaderScreen extends ConsumerWidget {
  const KaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BwTabSeite(
      nummer: '02',
      titel: 'Kader',
      kassenName: ref.watch(kassenNameProvider).value,
      einstellungen: () => context.push(Routen.einstellungen),
      kinder: const [BwErklaerung('Hier entstehen Kader und Salden (KAD-05).')],
    );
  }
}
