import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

/// Die Kasse mit ihren Rollen (ADM-03) und dem aktuellen Einladungscode
/// (ADM-01).
class KasseInfo {
  const KasseInfo({
    required this.name,
    required this.adminUid,
    required this.kassenwartUid,
    this.einladungCode = '',
    this.anzahlBierwarte = 1,
  });

  final String name;
  final String adminUid;
  final String kassenwartUid;
  final String einladungCode;
  final int anzahlBierwarte;
}

/// Ob der Nutzer in seiner Kasse (noch) Bierwart ist.
enum Mitgliedschaft {
  aktiv,

  /// Ausgetreten, entfernt (ADM-02) oder die Kasse ist aufgelöst und er ist
  /// nicht der Admin: Lesen lehnen die Rules ab.
  entfernt,

  /// Der Admin hat die Kasse aufgelöst, das Löschen ist nicht fertig
  /// (ADM-05).
  aufloesen,
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

  /// Ob der Nutzer hier noch Bierwart ist. Ohne Netz und ohne Cache gilt er
  /// als aktiv; erst der Server sagt, dass er es nicht mehr ist.
  Stream<Mitgliedschaft> mitgliedschaft(String kasseId);
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
                einladungCode: d['einladungCode'] as String? ?? '',
                anzahlBierwarte: d['anzahlBierwarte'] as int? ?? 1,
              );
      });

  @override
  Stream<Set<String>> aktiveBierwarte(String kasseId) => _db
      .collection('kassen/$kasseId/bierwarte')
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id});

  /// Wer nicht mehr Bierwart ist, darf `kassen/{k}` nicht lesen (NFA-07).
  @override
  Stream<Mitgliedschaft> mitgliedschaft(String kasseId) => _db
      .doc('kassen/$kasseId')
      .snapshots()
      .map(
        (s) => !s.exists
            ? (s.metadata.isFromCache
                  ? Mitgliedschaft.aktiv
                  : Mitgliedschaft.entfernt)
            : s.data()?['aufgeloest'] == true
            ? Mitgliedschaft.aufloesen
            : Mitgliedschaft.aktiv,
      )
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (e, st, sink) =>
              e is FirebaseException && e.code == 'permission-denied'
              ? sink.add(Mitgliedschaft.entfernt)
              : sink.addError(e, st),
        ),
      );
}

final kassenkopfRepositoryProvider = Provider<KassenkopfRepository>(
  (ref) => FirestoreKassenkopfRepository(ref.watch(firestoreProvider)),
);
