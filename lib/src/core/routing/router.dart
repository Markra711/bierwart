import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/einstellungen/presentation/aufloesen_screen.dart';
import '../../features/einstellungen/presentation/datenschutz_screen.dart';
import '../../features/einstellungen/presentation/einstellungen_screen.dart';
import '../../features/einstellungen/presentation/neuer_code_screen.dart';
import '../../features/geld/presentation/geld_screen.dart';
import '../../features/geld/presentation/verlauf_screen.dart';
import '../../features/kader/presentation/kader_screen.dart';
import '../../features/kader/presentation/mitglied_detail_screen.dart';
import '../../features/lager/presentation/einkauf_screen.dart';
import '../../features/lager/presentation/lager_screen.dart';
import '../../features/lager/presentation/sorte_bearbeiten_screen.dart';
import '../../features/onboarding/application/onboarding.dart';
import '../../features/onboarding/application/wiederherstellung.dart';
import '../../features/onboarding/domain/erstellte_kasse.dart';
import '../../features/onboarding/presentation/beitreten_screen.dart';
import '../../features/onboarding/presentation/einladen_screen.dart';
import '../../features/onboarding/presentation/kasse_erstellen_screen.dart';
import '../../features/onboarding/presentation/laden_screen.dart';
import '../../features/onboarding/presentation/link_einfuegen_screen.dart';
import '../../features/onboarding/presentation/name_waehlen_screen.dart';
import '../../features/onboarding/presentation/wiederherstellen_screen.dart';
import '../../features/onboarding/presentation/wiederherstellungscode_screen.dart';
import '../../features/onboarding/presentation/willkommen_screen.dart';
import '../../features/strichliste/presentation/strichliste_screen.dart';
import '../theme/app_theme.dart';
import 'app_rahmen.dart';
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
  static const wiederherstellen = '/wiederherstellen';

  // Tabs (UI-02) und Seiten in der Kasse
  static const kader = '/kader';
  static const lager = '/lager';
  static const geld = '/geld';
  static const einstellungen = '/einstellungen';
  static const mitglied = '/mitglied';
  static const einkauf = '/einkauf';
  static const sorte = '/sorte';
  static const verlauf = '/verlauf';
  static const aufloesen = '/aufloesen';
  static const datenschutz = '/datenschutz';

  /// Der neue Wiederherstellungscode; Code und Kassenname kommen als
  /// `extra` und gehen bei einem Neustart verloren, so ist er nur einmal
  /// sichtbar (ADM-08).
  static const neuerCode = '/neuer-code';

  /// Sorte bearbeiten, eine Unterseite ohne Tab-Leiste.
  static String sorteBearbeiten(String id) => '$sorte/$id';

  /// Mitglied-Detail, eine Unterseite ohne Tab-Leiste (styleguide.md, TabBar).
  static String mitgliedDetail(String id) => '$mitglied/$id';

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
  Routen.wiederherstellen,
};

/// Wohin die App den Nutzer schickt; `null` = bleiben. Ohne Kasse ins
/// Onboarding, mit Kasse auf die Strichliste (UI-01), während des Auflösens
/// nur auf dessen Seite (ADM-05). Wer gerade eine Kasse erstellt, bleibt im
/// Ablauf, bis der Server sie angenommen hat und Code und Einladung gezeigt
/// wurden (AUTH-03). Wer gerade beitritt, bleibt auf „Wie heißt du?“, bis
/// der Server geantwortet hat; wer sich mit dem Wiederherstellungscode
/// zurückmeldet, bis er den neuen Code gesehen hat (ADR-0010). Ein offener
/// Einladungscode führt ohne Kasse vom Start direkt zu „Kasse beitreten?“
/// (AUTH-06).
String? weiterleitung(
  Startzustand zustand,
  ErstellteKasse? neu,
  String ort, {
  bool beitrittLaeuft = false,
  bool wiederherstellungHaeltFest = false,
  String? offenerCode,
}) {
  if (wiederherstellungHaeltFest) {
    return ort == Routen.wiederherstellen ? null : Routen.wiederherstellen;
  }
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
    OhneKasse()
        when offenerCode != null &&
            (ort == Routen.willkommen || !ohneKasse.contains(ort)) =>
      Routen.mitCode(Routen.beitreten, offenerCode),
    OhneKasse() => ohneKasse.contains(ort) ? null : Routen.willkommen,
    InKasse() => _onboarding.contains(ort) ? Routen.strichliste : null,
    InAufloesung() => ort == Routen.aufloesen ? null : Routen.aufloesen,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final aenderung = ValueNotifier(0);
  ref.listen(startzustandProvider, (_, _) => aenderung.value++);
  ref.listen(ersteKasseProvider, (_, _) => aenderung.value++);
  ref.listen(beitrittProvider, (_, _) => aenderung.value++);
  ref.listen(
    wiederherstellungProvider.select((w) => w.haeltFest),
    (_, _) => aenderung.value++,
  );

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
      wiederherstellungHaeltFest: ref.read(wiederherstellungProvider).haeltFest,
      offenerCode: ref.read(offenerCodeProvider),
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppRahmen(shell: shell),
        branches: [
          for (final (pfad, bauen) in [
            (Routen.strichliste, () => const StrichlisteScreen()),
            (Routen.kader, () => const KaderScreen()),
            (Routen.lager, () => const LagerScreen()),
            (Routen.geld, () => const GeldScreen()),
          ])
            StatefulShellBranch(routes: [seite(pfad, bauen)]),
        ],
      ),
      seite(Routen.einstellungen, () => const EinstellungenScreen()),
      seite(Routen.einkauf, () => const EinkaufScreen()),
      seite(Routen.verlauf, () => const VerlaufScreen()),
      seite(Routen.aufloesen, () => const AufloesenScreen()),
      seite(Routen.datenschutz, () => const DatenschutzScreen()),
      GoRoute(
        path: Routen.neuerCode,
        builder: (context, state) => switch (state.extra) {
          (String code, String kassenName) => NeuerCodeScreen(
            code: code,
            kassenName: kassenName,
          ),
          _ => const _UnbekannteSeite(),
        },
      ),
      GoRoute(
        path: '${Routen.sorte}/:id',
        builder: (context, state) =>
            SorteBearbeitenScreen(sorteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routen.mitglied}/:id',
        builder: (context, state) =>
            MitgliedDetailScreen(mitgliedId: state.pathParameters['id']!),
      ),
      seite(Routen.laden, () => const LadenScreen()),
      seite(Routen.willkommen, () => const WillkommenScreen()),
      seite(Routen.kasseErstellen, () => const KasseErstellenScreen()),
      seite(
        Routen.wiederherstellungscode,
        () => const WiederherstellungscodeScreen(),
      ),
      seite(Routen.einladen, () => const EinladenScreen()),
      seite(Routen.linkEinfuegen, () => const LinkEinfuegenScreen()),
      seite(Routen.wiederherstellen, () => const WiederherstellenScreen()),
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
  // Ein Link bei offener App springt sofort zu „Kasse beitreten?“; wer schon
  // in einer Kasse ist, braucht ihn nicht (Release 1: eine Kasse, AUTH-14).
  ref.listen(offenerCodeProvider, (alt, code) {
    if (code == null || code == alt) return;
    if (ref.read(startzustandProvider) is InKasse) {
      ref.read(offenerCodeProvider.notifier).verwerfen();
    } else if (ref.read(ersteKasseProvider) == null &&
        !ref.read(beitrittProvider)) {
      router.go(Routen.mitCode(Routen.beitreten, code));
    }
  });
  ref.listen(startzustandProvider, (_, zustand) {
    if (zustand is InKasse) ref.read(offenerCodeProvider.notifier).verwerfen();
  });
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
