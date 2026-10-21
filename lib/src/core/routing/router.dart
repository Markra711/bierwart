import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/strichliste/presentation/strichliste_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Pfade der App. Einladungslinks (`/j/{code}`, AUTH-04) kommen mit dem
/// Onboarding.
abstract final class Routen {
  static const strichliste = '/';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routen.strichliste,
    routes: [
      GoRoute(
        path: Routen.strichliste,
        builder: (context, state) => const StrichlisteScreen(),
      ),
    ],
    errorBuilder: (context, state) => const _UnbekannteSeite(),
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Unbekannter Pfad, z. B. ein kaputter Link: kein leerer Bildschirm (NFA-10).
class _UnbekannteSeite extends StatelessWidget {
  const _UnbekannteSeite();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BwSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NICHT GEFUNDEN', style: text.screenTitle),
              const SizedBox(height: BwSpacing.space2),
              Text('Die Seite gibt es nicht.', style: text.body),
              const SizedBox(height: BwSpacing.space4),
              TextButton(
                onPressed: () => context.go(Routen.strichliste),
                child: const Text('ZUR STRICHLISTE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
