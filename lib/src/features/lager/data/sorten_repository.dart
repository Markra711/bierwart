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
);

abstract interface class SortenRepository {
  /// Die sichtbaren Sorten (`aktiv`, BES-01), live und auch offline.
  Stream<List<Sorte>> aktive(String kasseId);
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
}

final sortenRepositoryProvider = Provider<SortenRepository>(
  (ref) => FirestoreSortenRepository(ref.watch(firestoreProvider)),
);
