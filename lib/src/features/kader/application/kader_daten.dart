import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lager/data/sorten_repository.dart';
import '../../onboarding/data/anmeldung_repository.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../../strichliste/data/kassenkopf_repository.dart';
import '../data/verlauf_repository.dart';

/// Name und Rollen der Kasse (ADM-03).
final kasseInfoProvider = StreamProvider<KasseInfo?>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(null)
      : ref.watch(kassenkopfRepositoryProvider).kasse(k);
});

/// UIDs der aktiven Bierwarte, für Rollen-Badges und KAD-02.
final aktiveBierwarteProvider = StreamProvider<Set<String>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const {})
      : ref.watch(kassenkopfRepositoryProvider).aktiveBierwarte(k);
});

/// Kassenwart-Funktionen sind für andere unsichtbar (UI-08); die Rules
/// prüfen sie trotzdem (NFA-07).
final istKassenwartProvider = Provider<bool>((ref) {
  final uid = ref.watch(anmeldungProvider).value;
  final kasse = ref.watch(kasseInfoProvider).value;
  return uid != null && kasse?.kassenwartUid == uid;
});

/// Namen aller Sorten, auch ausgeblendeter, für den Verlauf.
final sortenNamenProvider = StreamProvider<Map<String, String>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const {})
      : ref.watch(sortenRepositoryProvider).namen(k);
});

/// Wie viele Buchungen das Mitglied-Detail lädt; „Ältere laden“ erhöht.
class VerlaufAnzahl extends Notifier<int> {
  VerlaufAnzahl(this.mitgliedId);

  final String mitgliedId;
  static const seite = 30;

  @override
  int build() => seite;

  void mehr() => state += seite;
}

final verlaufAnzahlProvider =
    NotifierProvider.family<VerlaufAnzahl, int, String>(VerlaufAnzahl.new);

/// Striche und Zahlungen eines Mitglieds, neueste zuerst (KAD-06).
final verlaufProvider = StreamProvider.family<Verlauf, String>((
  ref,
  mitgliedId,
) {
  final k = ref.watch(kasseIdProvider);
  if (k == null) return Stream.value(const Verlauf([], mehr: false));
  return ref
      .watch(verlaufRepositoryProvider)
      .verlauf(
        k,
        mitgliedId,
        anzahl: ref.watch(verlaufAnzahlProvider(mitgliedId)),
      );
});
