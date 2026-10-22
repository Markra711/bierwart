import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../kader/application/kader_daten.dart';
import '../../kader/data/mitglieder_repository.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../data/log_repository.dart';
import '../domain/logbuchung.dart';
import 'geld.dart';

/// Filter und Länge des Verlaufs (LOG-03).
class LogFilter {
  const LogFilter({this.bierwartUid, this.mitgliedId, this.anzahl = seite});

  static const seite = 50;

  final String? bierwartUid;
  final String? mitgliedId;
  final int anzahl;
}

class LogFilterNotifier extends Notifier<LogFilter> {
  @override
  LogFilter build() => const LogFilter();

  /// Ein neuer Filter fängt wieder mit einer Seite an.
  void bierwart(String? uid) =>
      state = LogFilter(bierwartUid: uid, mitgliedId: state.mitgliedId);

  void mitglied(String? id) =>
      state = LogFilter(bierwartUid: state.bierwartUid, mitgliedId: id);

  void mehr() => state = LogFilter(
    bierwartUid: state.bierwartUid,
    mitgliedId: state.mitgliedId,
    anzahl: state.anzahl + LogFilter.seite,
  );
}

final logFilterProvider =
    NotifierProvider.autoDispose<LogFilterNotifier, LogFilter>(
      LogFilterNotifier.new,
    );

/// Die Buchungen der Kasse, neueste zuerst, nach [logFilterProvider].
final logProvider = StreamProvider.autoDispose<LogSeite>((ref) {
  final k = ref.watch(kasseIdProvider);
  final f = ref.watch(logFilterProvider);
  return k == null
      ? Stream.value(const LogSeite([], mehr: false))
      : ref
            .watch(logRepositoryProvider)
            .log(
              k,
              bierwartUid: f.bierwartUid,
              mitgliedId: f.mitgliedId,
              anzahl: f.anzahl,
            );
});

/// Namen aller Mitglieder, auch entfernter (KAD-08).
final mitgliederNamenProvider = StreamProvider<Map<String, String>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const {})
      : ref.watch(mitgliederRepositoryProvider).namen(k);
});

/// Womit der Verlauf IDs in Namen auflöst. Bierwarte sind alle, die je ein
/// Portemonnaie hatten; der aktuelle Name kommt aus dem Kader.
final logNamenProvider = Provider<LogNamen>((ref) {
  final mitglieder = ref.watch(mitgliederNamenProvider).value ?? const {};
  final aktuelle = {
    for (final m in ref.watch(mitgliederProvider).value ?? const [])
      if (m.bierwartUid != null) m.bierwartUid!: m.name,
  };
  return LogNamen(
    mitglieder: mitglieder,
    sorten: ref.watch(sortenNamenProvider).value ?? const {},
    bierwarte: {
      for (final o in ref.watch(orteProvider).value ?? const [])
        if (!o.istKasse) o.id: aktuelle[o.id] ?? o.name,
    },
  );
});
