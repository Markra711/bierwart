import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/sorte.dart';

/// Eine Sorte aus `kassen/{k}/sorten/{id}`.
Sorte sorteAus(String id, Map<String, Object?> d) => Sorte(
  id: id,
  name: d['name'] as String,
  preisCents: d['preisCents'] as int,
  bestand: d['bestand'] as int,
  reihenfolge: d['reihenfolge'] as int,
  vorherigerPreisCents: d['vorherigerPreisCents'] as int?,
  aktiv: d['aktiv'] as bool? ?? true,
);

abstract interface class SortenRepository {
  /// Die sichtbaren Sorten (`aktiv`, BES-01), live und auch offline.
  Stream<List<Sorte>> aktive(String kasseId);

  /// Namen aller Sorten, auch ausgeblendeter, für den Verlauf (KAD-06).
  Stream<Map<String, String>> namen(String kasseId);

  /// Alle Sorten, auch ausgeblendete, fürs Lager (BES-01).
  Stream<List<Sorte>> alle(String kasseId);

  /// Der Bestand direkt vom Server, für die Korrektur (BES-06). Ohne Netz
  /// scheitert das, und so soll es sein.
  Future<int> bestandVomServer(String kasseId, String sorteId);
}

class FirestoreSortenRepository implements SortenRepository {
  const FirestoreSortenRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Sorte>> aktive(String kasseId) => _db
      .collection('kassen/$kasseId/sorten')
      .where('aktiv', isEqualTo: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) sorteAus(d.id, d.data())]);

  @override
  Stream<List<Sorte>> alle(String kasseId) => _db
      .collection('kassen/$kasseId/sorten')
      .snapshots()
      .map((q) => [for (final d in q.docs) sorteAus(d.id, d.data())]);

  @override
  Future<int> bestandVomServer(String kasseId, String sorteId) async {
    final d = await _db
        .doc('kassen/$kasseId/sorten/$sorteId')
        .get(const GetOptions(source: Source.server));
    return d.data()!['bestand'] as int;
  }

  @override
  Stream<Map<String, String>> namen(String kasseId) => _db
      .collection('kassen/$kasseId/sorten')
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id: d.data()['name'] as String});
}

final sortenRepositoryProvider = Provider<SortenRepository>(
  (ref) => FirestoreSortenRepository(ref.watch(firestoreProvider)),
);
