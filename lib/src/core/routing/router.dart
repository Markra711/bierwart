import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/application/onboarding.dart';
import '../../features/onboarding/domain/erstellte_kasse.dart';
import '../../features/onboarding/presentation/beitreten_screen.dart';
import '../../features/onboarding/presentation/einladen_screen.dart';
import '../../features/onboarding/presentation/kasse_erstellen_screen.dart';
import '../../features/onboarding/presentation/laden_screen.dart';
import '../../features/onboarding/presentation/link_einfuegen_screen.dart';
import '../../features/onboarding/presentation/name_waehlen_screen.dart';
import '../../features/onboarding/presentation/wiederherstellungscode_screen.dart';
import '../../features/onboarding/presentation/willkommen_screen.dart';
import '../../features/strichliste/presentation/strichliste_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Pfade der App. Beitreten und Name wählen tragen den Einladungscode als
/// `?code=`, damit Einladungslinks (`/j/{code}`, AUTH-04) später direkt dort
/// einsteigen können.
abstract final class Routen {
  static const strichliste = '/';
  static const laden = '/laden';
  static const willkommen = '/willkommen';
  static const kasseErstellen = '/kasse-erstellen';
  static const wiederherstellungscode = '/wiederherstellungscode';
  static const einladen = '/einladen';
  static const linkEinfuegen = '/link-einfuegen';
  static const beitreten = '/beitreten';
  static const nameWaehlen = '/name-waehlen';

  static String mitCode(String pfad, String code) =>
      Uri(path: pfad, queryParameters: {'code': code}).toString();
}

const _onboarding = {
  Routen.laden,
  Routen.wiederherstellungscode,
  Routen.einladen,
  ...ohneKasse,
};

/// Erlaubt, solange der Nutzer in keiner Kasse ist.
const ohneKasse = {
  Routen.willkommen,
  Routen.kasseErstellen,
  Routen.linkEinfuegen,
  Routen.beitreten,
  Routen.nameWaehlen,
};

/// Wohin die App den Nutzer schickt; `null` = bleiben. Ohne Kasse ins
/// Onboarding, mit Kasse auf die Strichliste (UI-01). Wer gerade eine Kasse
/// erstellt, bleibt im Ablauf, bis der Server sie angenommen hat und Code und
/// Einladung gezeigt wurden (AUTH-03). Wer gerade beitritt, bleibt auf „Wie
/// heißt du?“, bis der Server geantwortet hat.
String? weiterleitung(
  Startzustand zustand,
  ErstellteKasse? neu,
  String ort, {
  bool beitrittLaeuft = false,
}) {
  if (beitrittLaeuft) {
    return ort == Routen.nameWaehlen ? null : Routen.nameWaehlen;
  }
  if (neu != null) {
    if (!neu.gespeichert) {
      return ort == Routen.kasseErstellen ? null : Routen.kasseErstellen;
    }
    return ort == Routen.wiederherstellungscode || ort == Routen.einladen
        ? null
        : Routen.wiederherstellungscode;
  }
  return switch (zustand) {
    StartLaedt() || StartFehler() => ort == Routen.laden ? null : Routen.laden,
    OhneKasse() => ohneKasse.contains(ort) ? null : Routen.willkommen,
    InKasse() => _onboarding.contains(ort) ? Routen.strichliste : null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final aenderung = ValueNotifier(0);
  ref.listen(startzustandProvider, (_, _) => aenderung.value++);
  ref.listen(ersteKasseProvider, (_, _) => aenderung.value++);
  ref.listen(beitrittProvider, (_, _) => aenderung.value++);

  GoRoute seite(String pfad, Widget Function() bauen) =>
      GoRoute(path: pfad, builder: (context, state) => bauen());

  final router = GoRouter(
    initialLocation: Routen.strichliste,
    refreshListenable: aenderung,
    redirect: (context, state) => weiterleitung(
      ref.read(startzustandProvider),
      ref.read(ersteKasseProvider),
      state.uri.path,
      beitrittLaeuft: ref.read(beitrittProvider),
    ),
    routes: [
      seite(Routen.strichliste, () => const StrichlisteScreen()),
      seite(Routen.laden, () => const LadenScreen()),
      seite(Routen.willkommen, () => const WillkommenScreen()),
      seite(Routen.kasseErstellen, () => const KasseErstellenScreen()),
      seite(
        Routen.wiederherstellungscode,
        () => const WiederherstellungscodeScreen(),
      ),
      seite(Routen.einladen, () => const EinladenScreen()),
      seite(Routen.linkEinfuegen, () => const LinkEinfuegenScreen()),
      GoRoute(
        path: Routen.beitreten,
        builder: (context, state) =>
            BeitretenScreen(code: state.uri.queryParameters['code'] ?? ''),
      ),
      GoRoute(
        path: Routen.nameWaehlen,
        builder: (context, state) =>
            NameWaehlenScreen(code: state.uri.queryParameters['code'] ?? ''),
      ),
    ],
    errorBuilder: (context, state) => const _UnbekannteSeite(),
  );
  ref.onDispose(() {
    router.dispose();
    aenderung.dispose();
  });
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
