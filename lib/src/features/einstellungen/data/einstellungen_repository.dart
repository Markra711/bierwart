import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../onboarding/domain/einladung.dart';

/// Ein Eintrag aus `kassen/{k}/bierwarte/{uid}`.
class BierwartEintrag {
  const BierwartEintrag({
    required this.uid,
    required this.name,
    required this.mitgliedId,
  });

  final String uid;
  final String name;
  final String mitgliedId;
}

/// Die Kasse, wie sie gerade auf dem Server steht. Verwaltungsaktionen
/// brauchen Netz und bauen ihren Batch aus diesem Stand (architecture.md).
class KasseVomServer {
  const KasseVomServer({
    required this.name,
    required this.einladungCode,
    required this.anzahlBierwarte,
    required this.adminUid,
    required this.kassenwartUid,
  });

  final String name;
  final String einladungCode;
  final int anzahlBierwarte;
  final String adminUid;
  final String kassenwartUid;
}

abstract interface class EinstellungenRepository {
  /// Die aktiven Bierwarte der Kasse.
  Stream<List<BierwartEintrag>> bierwarte(String kasseId);

  /// Die Einladung zum aktuellen Code, für „Gültig bis“ (AUTH-08).
  Stream<Einladung?> einladung(String code);

  /// Die Kasse direkt vom Server. Ohne Netz scheitert das, und so soll es
  /// sein (NFA-10).
  Future<KasseVomServer> kasseFuerVerwaltung(String kasseId);
}

class FirestoreEinstellungenRepository implements EinstellungenRepository {
  const FirestoreEinstellungenRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<BierwartEintrag>> bierwarte(String kasseId) => _db
      .collection('kassen/$kasseId/bierwarte')
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            BierwartEintrag(
              uid: d.id,
              name: d.data()['name'] as String,
              mitgliedId: d.data()['mitgliedId'] as String,
            ),
        ],
      );

  @override
  Stream<Einladung?> einladung(String code) =>
      _db.doc('einladungen/$code').snapshots().map((s) {
        final d = s.data();
        final erstellt = d?['erstelltAm'];
        if (d == null || erstellt is! Timestamp) return null;
        return Einladung(
          code: code,
          kasseId: d['kasseId'] as String,
          kassenName: d['kassenName'] as String,
          anzahlBierwarte: d['anzahlBierwarte'] as int,
          erstelltAm: erstellt.toDate(),
          ersetzt: d['ersetzt'] as bool,
        );
      });

  @override
  Future<KasseVomServer> kasseFuerVerwaltung(String kasseId) async {
    final s = await _db
        .doc('kassen/$kasseId')
        .get(const GetOptions(source: Source.server));
    final d = s.data()!;
    return KasseVomServer(
      name: d['name'] as String,
      einladungCode: d['einladungCode'] as String,
      anzahlBierwarte: d['anzahlBierwarte'] as int,
      adminUid: d['adminUid'] as String,
      kassenwartUid: d['kassenwartUid'] as String,
    );
  }
}

final einstellungenRepositoryProvider = Provider<EinstellungenRepository>(
  (ref) => FirestoreEinstellungenRepository(ref.watch(firestoreProvider)),
);
