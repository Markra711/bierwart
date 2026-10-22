import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/codes.dart';
import '../domain/wiederherstellung.dart';

/// Lesen für die Wiederherstellung ohne Bierwart-Eintrag (ADR-0010). Alles
/// direkt vom Server: Es ist eine Verwaltungsaktion und braucht Netz.
abstract interface class WiederherstellungRepository {
  /// Die Kasse zum normalisierten Code, oder `null`, wenn es keine gibt.
  Future<String?> kasseZumCode(String nachweis);

  /// Kasse, Mitglieder, Bierwarte und Orte. Geht erst nach dem Nachweis.
  Future<WiederherstellungsStand> laden(String kasseId);
}

class FirestoreWiederherstellungRepository
    implements WiederherstellungRepository {
  const FirestoreWiederherstellungRepository(this._db);

  final FirebaseFirestore _db;

  static const _server = GetOptions(source: Source.server);

  @override
  Future<String?> kasseZumCode(String nachweis) async {
    final s = await _db
        .doc('wiederherstellung/${hexVon(hashVon(nachweis))}')
        .get(_server);
    return s.data()?['kasseId'] as String?;
  }

  @override
  Future<WiederherstellungsStand> laden(String kasseId) async {
    final k = 'kassen/$kasseId';
    final (kasse, mitglieder, bierwarte, orte, namen) = await (
      _db.doc(k).get(_server),
      _db.collection('$k/mitglieder').get(_server),
      _db.collection('$k/bierwarte').get(_server),
      _db.collection('$k/orte').get(_server),
      _db.collection('$k/namen').get(_server),
    ).wait;
    final d = kasse.data()!;
    return WiederherstellungsStand(
      kasseId: kasseId,
      kassenName: d['name'] as String,
      adminUid: d['adminUid'] as String,
      kassenwartUid: d['kassenwartUid'] as String,
      einladungCode: d['einladungCode'] as String,
      kandidaten: [
        for (final m in mitglieder.docs)
          if (m.data()['istGast'] != true)
            Kandidat(
              mitgliedId: m.id,
              name: m.data()['name'] as String,
              bierwartUid: m.data()['bierwartUid'] as String?,
              entfernt: m.data()['entfernt'] == true,
            ),
      ],
      aktiveBierwarte: {for (final b in bierwarte.docs) b.id},
      orte: {for (final o in orte.docs) o.id},
      namenKeys: {for (final n in namen.docs) n.id},
    );
  }
}

final wiederherstellungRepositoryProvider =
    Provider<WiederherstellungRepository>(
      (ref) =>
          FirestoreWiederherstellungRepository(ref.watch(firestoreProvider)),
    );
