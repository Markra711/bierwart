import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/uebernahme.dart';

/// Lesen rund um „Das bin ich“ (UC-03, ADR-0008). Geschrieben wird über den
/// `Schreiber` mit den Batches aus `uebernahme_batches.dart`.
abstract interface class UebernahmeRepository {
  /// Die eigene Anfrage; das neue Gerät darf sie lesen, obwohl es noch kein
  /// Bierwart ist. `null`, wenn es sie nicht gibt.
  Stream<Uebernahme?> anfrage(String kasseId, String anfrageId);

  /// Offene Anfragen der Kasse, für die Bierwarte.
  Stream<List<Uebernahme>> offene(String kasseId);

  /// Alles, was der Batch „Bestätigen“ braucht, direkt vom Server.
  Future<UebernahmeStand> standVomServer(String kasseId, String anfrageId);
}

class FirestoreUebernahmeRepository implements UebernahmeRepository {
  const FirestoreUebernahmeRepository(this._db);

  final FirebaseFirestore _db;

  static const _server = GetOptions(source: Source.server);

  static Uebernahme _aus(String kasseId, String id, Map<String, dynamic> d) =>
      Uebernahme(
        id: id,
        kasseId: kasseId,
        mitgliedId: d['mitgliedId'] as String,
        neueUid: d['neueUid'] as String,
        einladungCode: d['einladungCode'] as String,
        status: UebernahmeStatus.values.byName(d['status'] as String),
        angefragtAm: (d['angefragtAm'] as Timestamp?)?.toDate(),
      );

  @override
  Stream<Uebernahme?> anfrage(String kasseId, String anfrageId) =>
      _db.doc('kassen/$kasseId/uebernahmen/$anfrageId').snapshots().map((s) {
        final d = s.data();
        return d == null ? null : _aus(kasseId, s.id, d);
      });

  @override
  Stream<List<Uebernahme>> offene(String kasseId) => _db
      .collection('kassen/$kasseId/uebernahmen')
      .where('status', isEqualTo: 'offen')
      .snapshots()
      .map((q) => [for (final d in q.docs) _aus(kasseId, d.id, d.data())]);

  @override
  Future<UebernahmeStand> standVomServer(
    String kasseId,
    String anfrageId,
  ) async {
    // Nacheinander statt parallel: so kommen Firebase-Fehler unverpackt an
    // und werden zu einer Meldung (NFA-10).
    final k = 'kassen/$kasseId';
    Future<DocumentSnapshot<Map<String, dynamic>>> lesen(String pfad) =>
        _db.doc(pfad).get(_server);
    final anfrage = _aus(
      kasseId,
      anfrageId,
      (await lesen('$k/uebernahmen/$anfrageId')).data()!,
    );
    final kasseSnap = await lesen(k);
    final mitglied = (await lesen('$k/mitglieder/${anfrage.mitgliedId}'))
        .data()!;
    final alteUid = mitglied['bierwartUid'] as String?;
    final bierwart = alteUid == null
        ? null
        : await lesen('$k/bierwarte/$alteUid');
    final ort = alteUid == null ? null : await lesen('$k/orte/$alteUid');
    final kasse = kasseSnap.data()!;
    return UebernahmeStand(
      anfrage: anfrage,
      mitgliedName: mitglied['name'] as String,
      alteUid: alteUid,
      alteAktiv: bierwart?.exists ?? false,
      altesPortemonnaieCents: ort?.data()?['standCents'] as int?,
      adminUid: kasse['adminUid'] as String,
      kassenwartUid: kasse['kassenwartUid'] as String,
      einladungCode: kasse['einladungCode'] as String,
    );
  }
}

final uebernahmeRepositoryProvider = Provider<UebernahmeRepository>(
  (ref) => FirestoreUebernahmeRepository(ref.watch(firestoreProvider)),
);
