import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

/// Was der Kopf der Tabs und der Stempel brauchen.
abstract interface class KassenkopfRepository {
  /// `kassen/{k}.name`, über dem Titel jedes Tabs.
  Stream<String?> kassenName(String kasseId);

  /// Der eigene Name aus `bierwarte/{uid}`, er steht in jedem Stempel.
  Stream<String?> bierwartName(String kasseId, String uid);
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
}

final kassenkopfRepositoryProvider = Provider<KassenkopfRepository>(
  (ref) => FirestoreKassenkopfRepository(ref.watch(firestoreProvider)),
);
