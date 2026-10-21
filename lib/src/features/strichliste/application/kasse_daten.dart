import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../kader/data/mitglieder_repository.dart';
import '../../kader/domain/mitglied.dart';
import '../../lager/data/sorten_repository.dart';
import '../../lager/domain/sorte.dart';
import '../../onboarding/application/onboarding.dart';
import '../../onboarding/data/anmeldung_repository.dart';
import '../data/kassenkopf_repository.dart';

/// Die Kasse, in der der Nutzer ist, oder `null`.
final kasseIdProvider = Provider<String?>(
  (ref) => switch (ref.watch(startzustandProvider)) {
    InKasse(:final kasseId) => kasseId,
    _ => null,
  },
);

final kassenNameProvider = StreamProvider<String?>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(null)
      : ref.watch(kassenkopfRepositoryProvider).kassenName(k);
});

final bierwartNameProvider = StreamProvider<String?>((ref) {
  final k = ref.watch(kasseIdProvider);
  final uid = ref.watch(anmeldungProvider).value;
  return k == null || uid == null
      ? Stream.value(null)
      : ref.watch(kassenkopfRepositoryProvider).bierwartName(k, uid);
});

/// Sichtbare Sorten in der Reihenfolge des Rasters (STR-01, UI-05).
final sortenProvider = StreamProvider<List<Sorte>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const [])
      : ref.watch(sortenRepositoryProvider).aktive(k).map(sortenFuerRaster);
});

/// Nicht entfernte Mitglieder, alphabetisch, „Gäste“ zuletzt (UI-06).
final mitgliederProvider = StreamProvider<List<Mitglied>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const [])
      : ref
            .watch(mitgliederRepositoryProvider)
            .aktive(k)
            .map(mitgliederFuerRaster);
});

/// Wer schreibt: Kasse, UID und der Name für den Stempel (LOG-01). Erst wenn
/// alle drei bekannt sind, lässt sich buchen.
class Sitzung {
  const Sitzung({required this.kasseId, required this.uid, required this.name});

  final String kasseId;
  final String uid;
  final String name;
}

final sitzungProvider = Provider<Sitzung?>((ref) {
  final k = ref.watch(kasseIdProvider);
  final uid = ref.watch(anmeldungProvider).value;
  final name = ref.watch(bierwartNameProvider).value;
  return k == null || uid == null || name == null
      ? null
      : Sitzung(kasseId: k, uid: uid, name: name);
});
