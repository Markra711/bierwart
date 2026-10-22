import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../onboarding/presentation/wiederherstellungscode_screen.dart';

/// Der neue Wiederherstellungscode nach dem Erneuern (ADM-08) oder nach der
/// Wiederherstellung (ADM-06), genau einmal angezeigt.
class NeuerCodeScreen extends StatelessWidget {
  const NeuerCodeScreen({
    super.key,
    required this.code,
    required this.kassenName,
  });

  final String code;
  final String kassenName;

  @override
  Widget build(BuildContext context) => CodeEinmalZeigen(
    code: code,
    kassenName: kassenName,
    titel: 'Dein neuer',
    weiter: () =>
        context.canPop() ? context.pop() : context.go(Routen.einstellungen),
  );
}
