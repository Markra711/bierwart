import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/mitglied.dart';
import '../domain/name.dart';

/// Ein Mitglied aus `kassen/{k}/mitglieder/{id}`.
Mitglied mitgliedAus(String id, Map<String, Object?> d) => Mitglied(
  id: id,
  name: d['name'] as String,
  saldoCents: d['saldoCents'] as int,
  istGast: d['istGast'] as bool? ?? false,
  bierwartUid: d['bierwartUid'] as String?,
);

abstract interface class MitgliederRepository {
  /// Alle nicht entfernten Mitglieder, live und auch offline.
  Stream<List<Mitglied>> aktive(String kasseId);

  /// Wem der Name gehört, auch einem entfernten Mitglied (KAD-08); `null`,
  /// wenn er frei ist. Ohne Netz zählt, was das Gerät kennt; den Rest prüfen
  /// die Rules.
  Future<NamensBesitzer?> nameBelegt(String kasseId, String name);
}

/// Das Mitglied, dem ein Name im Index gehört.
class NamensBesitzer {
  const NamensBesitzer({required this.mitgliedId, required this.entfernt});

  final String mitgliedId;
  final bool entfernt;
}

class FirestoreMitgliederRepository implements MitgliederRepository {
  const FirestoreMitgliederRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Mitglied>> aktive(String kasseId) => _db
      .collection('kassen/$kasseId/mitglieder')
      .where('entfernt', isEqualTo: false)
      .snapshots()
      .map((q) => [for (final d in q.docs) mitgliedAus(d.id, d.data())]);

  @override
  Future<NamensBesitzer?> nameBelegt(String kasseId, String name) async {
    try {
      final index = await _db
          .doc('kassen/$kasseId/namen/${nameKey(name)}')
          .get();
      final id = index.data()?['mitgliedId'] as String?;
      if (id == null) return null;
      final m = await _db.doc('kassen/$kasseId/mitglieder/$id').get();
      return NamensBesitzer(
        mitgliedId: id,
        entfernt: m.data()?['entfernt'] == true,
      );
    } on FirebaseException {
      return null;
    }
  }
}

final mitgliederRepositoryProvider = Provider<MitgliederRepository>(
  (ref) => FirestoreMitgliederRepository(ref.watch(firestoreProvider)),
);
