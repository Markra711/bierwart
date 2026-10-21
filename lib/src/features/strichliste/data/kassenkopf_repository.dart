import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

/// Die Kasse mit ihren Rollen (ADM-03).
class KasseInfo {
  const KasseInfo({
    required this.name,
    required this.adminUid,
    required this.kassenwartUid,
  });

  final String name;
  final String adminUid;
  final String kassenwartUid;
}

/// Was der Kopf der Tabs, der Stempel und die Rollen brauchen.
abstract interface class KassenkopfRepository {
  /// `kassen/{k}.name`, über dem Titel jedes Tabs.
  Stream<String?> kassenName(String kasseId);

  /// Der eigene Name aus `bierwarte/{uid}`, er steht in jedem Stempel.
  Stream<String?> bierwartName(String kasseId, String uid);

  /// Name und Rollen aus `kassen/{k}`.
  Stream<KasseInfo?> kasse(String kasseId);

  /// UIDs der aktiven Bierwarte (`bierwarte/`); ausgetretene fehlen.
  Stream<Set<String>> aktiveBierwarte(String kasseId);
}

class FirestoreKassenkopfRepository implements KassenkopfRepository {
  const FirestoreKassenkopfRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<String?> kassenName(String kasseId) => _db
      .doc('kassen/$kasseId')
      .snapshots()
      .map((s) => s.data()?['name'] as String?);

  @override
  Stream<String?> bierwartName(String kasseId, String uid) => _db
      .doc('kassen/$kasseId/bierwarte/$uid')
      .snapshots()
      .map((s) => s.data()?['name'] as String?);

  @override
  Stream<KasseInfo?> kasse(String kasseId) =>
      _db.doc('kassen/$kasseId').snapshots().map((s) {
        final d = s.data();
        return d == null
            ? null
            : KasseInfo(
                name: d['name'] as String,
                adminUid: d['adminUid'] as String,
                kassenwartUid: d['kassenwartUid'] as String,
              );
      });

  @override
  Stream<Set<String>> aktiveBierwarte(String kasseId) => _db
      .collection('kassen/$kasseId/bierwarte')
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id});
}

final kassenkopfRepositoryProvider = Provider<KassenkopfRepository>(
  (ref) => FirestoreKassenkopfRepository(ref.watch(firestoreProvider)),
);
