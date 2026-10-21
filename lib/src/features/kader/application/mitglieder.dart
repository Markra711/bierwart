import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/fehler/fehlerkanal.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../data/mitglied_batches.dart';
import '../data/mitglieder_repository.dart';
import '../domain/name.dart';

/// Mitglied anlegen (KAD-01). Der Name muss frei sein, auch gegenüber
/// entfernten Mitgliedern (AUTH-07, KAD-08). Wartet nicht auf den Server.
Future<Eingabefehler> mitgliedAnlegen(Ref ref, String name) async {
  final nameFehler = namePruefen(name);
  if (nameFehler != null) return Eingabefehler(name: nameFehler);
  final sitzung = ref.read(sitzungProvider);
  if (sitzung == null) {
    return const Eingabefehler(allgemein: 'Die Kasse ist noch nicht geladen.');
  }
  final bereinigt = nameBereinigen(name);
  final bekannt = ref.read(mitgliederProvider).value ?? const [];
  final vergeben =
      bekannt.any((m) => nameKey(m.name) == nameKey(bereinigt)) ||
      await ref
          .read(mitgliederRepositoryProvider)
          .nameVergeben(sitzung.kasseId, bereinigt);
  if (vergeben) {
    return Eingabefehler(name: '„$bereinigt“ gibt es in der Kasse schon.');
  }
  final schreiber = ref.read(schreiberProvider);
  ref
      .read(fehlerkanalProvider.notifier)
      .beobachten(
        schreiber.schreiben(
          mitgliedAnlegenBatch(
            uid: sitzung.uid,
            bierwartName: sitzung.name,
            kasseId: sitzung.kasseId,
            mitgliedId: schreiber.neueId(),
            buchungId: schreiber.neueId(),
            name: bereinigt,
            geraetZeit: DateTime.now(),
          ),
        ),
        'Das Mitglied „$bereinigt“',
      );
  return const Eingabefehler();
}

final mitgliedAnlegenProvider =
    Provider<Future<Eingabefehler> Function(String)>(
      (ref) =>
          (name) => mitgliedAnlegen(ref, name),
    );
