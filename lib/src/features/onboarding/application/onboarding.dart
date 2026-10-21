import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/anmeldung_repository.dart';
import '../data/kasse_repository.dart';
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

final startzustandProvider = Provider<Startzustand>((ref) {
  final anmeldung = ref.watch(anmeldungProvider);
  if (anmeldung case AsyncError(:final error)) {
    return StartFehler(anmeldeFehler(error));
  }
  return switch (ref.watch(meineKasseIdProvider)) {
    AsyncData(value: final id?) => InKasse(id),
    AsyncData() => const OhneKasse(),
    AsyncError() => const StartFehler('Deine Daten ließen sich nicht laden.'),
    _ => const StartLaedt(),
  };
});

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
enum Beitritt { erfolgreich, nameVergeben }

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
    if (await repo.nameVergeben(einladung.kasseId, eigenerName)) {
      return Beitritt.nameVergeben;
    }
    final uid = await ref.read(anmeldungProvider.future);
    state = true;
    try {
      await repo.beitreten(uid, einladung, eigenerName);
      return Beitritt.erfolgreich;
    } finally {
      state = false;
    }
  }
}

final beitrittProvider = NotifierProvider<BeitrittNotifier, bool>(
  BeitrittNotifier.new,
);
