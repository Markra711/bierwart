import '../../../core/fehler/verwaltung.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../strichliste/data/kassenkopf_repository.dart';
import '../data/anmeldung_repository.dart';
import '../data/einladungslinks.dart';
import '../data/kasse_repository.dart';
import '../domain/codes.dart';
import '../domain/einladung.dart';
import '../domain/erstellte_kasse.dart';

/// Wo die App beim Start steht (UI-01, AUTH-01).
sealed class Startzustand {
  const Startzustand();
}

class StartLaedt extends Startzustand {
  const StartLaedt();
}

class StartFehler extends Startzustand {
  const StartFehler(this.meldung);

  final String meldung;
}

class OhneKasse extends Startzustand {
  const OhneKasse();
}

class InKasse extends Startzustand {
  const InKasse(this.kasseId);

  final String kasseId;
}

/// Der Admin hat die Kasse aufgelöst, das Löschen ist nicht fertig. Die App
/// setzt es fort, auch nach einem Neustart (ADM-05).
class InAufloesung extends Startzustand {
  const InAufloesung(this.kasseId);

  final String kasseId;
}

final startzustandProvider = Provider<Startzustand>((ref) {
  final anmeldung = ref.watch(anmeldungProvider);
  if (anmeldung case AsyncError(:final error)) {
    return StartFehler(anmeldeFehler(error));
  }
  return switch (ref.watch(meineKasseIdProvider)) {
    // Wer entfernt wurde oder ausgetreten ist, behält `users/{uid}`, bis er
    // einer anderen Kasse beitritt; er ist trotzdem ohne Kasse (ADM-02).
    // Solange das unklar ist, gilt die Kasse (offline zuerst, NFA-02).
    AsyncData(value: final id?) => switch (ref.watch(
      mitgliedschaftProvider(id),
    )) {
      AsyncData(value: Mitgliedschaft.entfernt) => const OhneKasse(),
      AsyncData(value: Mitgliedschaft.aufloesen) => InAufloesung(id),
      _ => InKasse(id),
    },
    AsyncData() => const OhneKasse(),
    AsyncError() => const StartFehler('Deine Daten ließen sich nicht laden.'),
    _ => const StartLaedt(),
  };
});

/// Ob der Nutzer in [kasseId] noch Bierwart ist.
final mitgliedschaftProvider = StreamProvider.family<Mitgliedschaft, String>(
  (ref, kasseId) =>
      ref.watch(kassenkopfRepositoryProvider).mitgliedschaft(kasseId),
);

/// Die Kasse, die gerade erstellt wird, bis „Weiter zur Strichliste“. Die
/// Codes stehen fest, bevor geschrieben wird; so geht der
/// Wiederherstellungscode nicht verloren (AUTH-03).
class ErsteKasseNotifier extends Notifier<ErstellteKasse?> {
  @override
  ErstellteKasse? build() => null;

  /// Erstellt die Kasse (UC-01). Wirft [VerwaltungsFehler] mit Meldung.
  Future<void> erstellen({
    required String kassenName,
    required String eigenerName,
    required int startCents,
  }) async {
    final uid = await ref.read(anmeldungProvider.future);
    final repo = ref.read(kasseRepositoryProvider);
    final neu = repo.vorbereiten(
      kassenName: kassenName,
      eigenerName: eigenerName,
      startCents: startCents,
    );
    state = neu;
    try {
      await repo.erstellen(uid, neu);
      state = neu.alsGespeichert();
    } catch (_) {
      state = null;
      rethrow;
    }
  }

  /// Nach dem Einladen: weiter zur Strichliste.
  void abschliessen() => state = null;
}

final ersteKasseProvider =
    NotifierProvider<ErsteKasseNotifier, ErstellteKasse?>(
      ErsteKasseNotifier.new,
    );

/// Die Einladung zu einem Code, frisch vom Server (AUTH-05). `null`, wenn es
/// sie nicht gibt.
final einladungProvider = FutureProvider.autoDispose.family<Einladung?, String>(
  (ref, code) => ref.read(kasseRepositoryProvider).einladungLaden(code),
  retry: (_, _) => null,
);

/// Ergebnis eines Beitrittsversuchs.
sealed class Beitritt {
  const Beitritt();
}

class BeitrittErfolgreich extends Beitritt {
  const BeitrittErfolgreich();
}

/// Der Name gehört schon dem Mitglied [mitgliedId] (AUTH-07); vielleicht ist
/// es der Nutzer selbst mit neuem Gerät (UC-03).
class NameVergeben extends Beitritt {
  const NameVergeben(this.mitgliedId);

  final String mitgliedId;
}

/// Beitreten (UC-02). Der Zustand ist `true`, solange geschrieben wird; die
/// Weiterleitung lässt den Nutzer dann auf „Wie heißt du?“, auch wenn die
/// Kasse lokal schon sichtbar ist. Lehnt der Server ab, sieht er die Meldung
/// dort (NFA-10).
class BeitrittNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Prüft zuerst den Namen (AUTH-07), dann der Batch. Wirft
  /// [VerwaltungsFehler] mit Meldung.
  Future<Beitritt> beitreten(Einladung einladung, String eigenerName) async {
    final meldung = einladung.zustand(DateTime.now()).meldung;
    if (meldung != null) throw VerwaltungsFehler(meldung);
    final repo = ref.read(kasseRepositoryProvider);
    final besitzer = await repo.namensBesitzer(einladung.kasseId, eigenerName);
    if (besitzer != null) return NameVergeben(besitzer);
    final uid = await ref.read(anmeldungProvider.future);
    state = true;
    try {
      await repo.beitreten(uid, einladung, eigenerName);
      ref.read(offenerCodeProvider.notifier).verwerfen();
      return const BeitrittErfolgreich();
    } finally {
      state = false;
    }
  }
}

final beitrittProvider = NotifierProvider<BeitrittNotifier, bool>(
  BeitrittNotifier.new,
);

/// Ein Einladungscode aus einem Link oder dem Play-Store-Referrer, der noch
/// nicht erledigt ist (AUTH-04, AUTH-06, AUTH-12). Er überlebt einen
/// Neustart, bis der Nutzer beitritt oder ablehnt.
class OffenerCodeNotifier extends Notifier<String?> {
  @override
  String? build() {
    final quelle = ref.watch(linkQuelleProvider);
    final abo = quelle.links.listen((link) {
      final code = einladungscodeAusLink(link);
      if (code != null) _setzen(code);
    });
    ref.onDispose(abo.cancel);
    unawaited(_beimStart(quelle));
    return null;
  }

  CodeSpeicher get _speicher => ref.read(codeSpeicherProvider);

  Future<void> _beimStart(LinkQuelle quelle) async {
    try {
      final gemerkt = await _speicher.offenerCode();
      if (state == null && gemerkt != null) state = gemerkt;
      if (await _speicher.referrerGelesen()) return;
      await _speicher.referrerAlsGelesenMerken();
      final code = einladungscodeAusReferrer(await quelle.installReferrer());
      if (state == null && code != null) _setzen(code);
    } catch (_) {
      // Ohne Speicher geht nur der gemerkte Code verloren; der Link selbst
      // funktioniert weiter.
    }
  }

  /// Erst merken, dann setzen: Wer auf den Zustand hört, darf den Code
  /// sofort verwerfen, und das Löschen muss danach kommen.
  void _setzen(String code) {
    unawaited(_speicher.merken(code).catchError((_) {}));
    state = code;
  }

  /// Nach dem Beitritt, nach „Nein“ oder „Anderer Link“.
  void verwerfen() {
    if (state == null) return;
    state = null;
    unawaited(_speicher.merken(null).catchError((_) {}));
  }
}

final offenerCodeProvider = NotifierProvider<OffenerCodeNotifier, String?>(
  OffenerCodeNotifier.new,
);
