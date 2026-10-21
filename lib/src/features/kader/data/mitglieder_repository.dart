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
);

abstract interface class MitgliederRepository {
  /// Alle nicht entfernten Mitglieder, live und auch offline.
  Stream<List<Mitglied>> aktive(String kasseId);

  /// Ob der Name vergeben ist, auch an ein entferntes Mitglied (KAD-08).
  /// Ohne Netz zählt, was das Gerät kennt; den Rest prüfen die Rules.
  Future<bool> nameVergeben(String kasseId, String name);
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
  Future<bool> nameVergeben(String kasseId, String name) async {
    try {
      final d = await _db.doc('kassen/$kasseId/namen/${nameKey(name)}').get();
      return d.exists;
    } on FirebaseException {
      return false;
    }
  }
}

final mitgliederRepositoryProvider = Provider<MitgliederRepository>(
  (ref) => FirestoreMitgliederRepository(ref.watch(firestoreProvider)),
);
