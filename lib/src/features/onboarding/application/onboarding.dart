import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/anmeldung_repository.dart';
import '../data/kasse_repository.dart';
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
