import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/ort.dart';

/// Ein Ort aus `kassen/{k}/orte/{id}`.
Ort ortAus(String id, Map<String, Object?> d) => Ort(
  id: id,
  name: d['name'] as String,
  standCents: d['standCents'] as int,
  uid: d['uid'] as String?,
  ehemalig: d['ehemalig'] as bool? ?? false,
);

abstract interface class OrteRepository {
  /// Kasse und alle Portemonnaies, auch ehemalige (GEL-07, GEL-08).
  Stream<List<Ort>> orte(String kasseId);

  /// Der Kassenstand direkt vom Server, für den Kassensturz (GEL-06). Ohne
  /// Netz scheitert das, und so soll es sein.
  Future<int> kasseVomServer(String kasseId);

  /// Wann zuletzt ein Kassensturz gebucht wurde, oder `null`.
  Stream<DateTime?> letzterKassensturz(String kasseId);
}

class FirestoreOrteRepository implements OrteRepository {
  const FirestoreOrteRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Ort>> orte(String kasseId) => _db
      .collection('kassen/$kasseId/orte')
      .snapshots()
      .map((q) => [for (final d in q.docs) ortAus(d.id, d.data())]);

  @override
  Future<int> kasseVomServer(String kasseId) async {
    final d = await _db
        .doc('kassen/$kasseId/orte/${Ort.kasseId}')
        .get(const GetOptions(source: Source.server));
    return d.data()!['standCents'] as int;
  }

  /// Braucht den Index `typ` + `stempel.am` (firestore.indexes.json).
  @override
  Stream<DateTime?> letzterKassensturz(String kasseId) => _db
      .collection('kassen/$kasseId/buchungen')
      .where('typ', isEqualTo: 'kassensturz')
      .orderBy('stempel.am', descending: true)
      .limit(1)
      .snapshots()
      .map((q) {
        if (q.docs.isEmpty) return null;
        final stempel = q.docs.first.data()['stempel'] as Map<String, Object?>;
        return switch (stempel['am'] ?? stempel['geraetAm']) {
          Timestamp t => t.toDate(),
          _ => null,
        };
      });
}

final orteRepositoryProvider = Provider<OrteRepository>(
  (ref) => FirestoreOrteRepository(ref.watch(firestoreProvider)),
);
