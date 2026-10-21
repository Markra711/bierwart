import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/eintrag.dart';

/// Einträge aus den Buchungen eines Mitglieds, neueste zuerst. Stornos
/// werden nicht selbst gezeigt, sondern markieren ihren Strich (STR-06).
/// Solange eine Buchung nur lokal liegt, fehlt `stempel.am`; dann gilt die
/// Gerätezeit.
List<Eintrag> eintraegeAus(Iterable<(String, Map<String, Object?>)> buchungen) {
  final storniert = <String>{
    for (final (_, d) in buchungen)
      if (d['typ'] == 'storno') d['bezugId']! as String,
  };
  final eintraege = <Eintrag>[];
  for (final (id, d) in buchungen) {
    final art = switch (d['typ']) {
      'strich' => EintragArt.strich,
      'strichBar' => EintragArt.strichBar,
      'zahlung' => EintragArt.zahlung,
      _ => null,
    };
    if (art == null) continue;
    final stempel = d['stempel']! as Map<String, Object?>;
    eintraege.add(
      Eintrag(
        buchungId: id,
        art: art,
        cents: (d['preisCents'] ?? d['betragCents'])! as int,
        zeit: _zeit(stempel['am']) ?? _zeit(stempel['geraetAm'])!,
        von: stempel['name']! as String,
        sorteId: d['sorteId'] as String?,
        ortId: d['ortId'] as String?,
        storniert: storniert.contains(id),
      ),
    );
  }
  eintraege.sort((a, b) => b.zeit.compareTo(a.zeit));
  return eintraege;
}

DateTime? _zeit(Object? wert) => switch (wert) {
  Timestamp() => wert.toDate(),
  DateTime() => wert,
  _ => null,
};

/// Die geladenen Einträge und ob es ältere Buchungen geben kann.
class Verlauf {
  const Verlauf(this.eintraege, {required this.mehr});

  final List<Eintrag> eintraege;

  /// Das Limit wurde ausgeschöpft; „Ältere laden“ lohnt sich.
  final bool mehr;
}

abstract interface class VerlaufRepository {
  /// Die letzten [anzahl] Buchungen des Mitglieds als Einträge (KAD-06).
  Stream<Verlauf> verlauf(
    String kasseId,
    String mitgliedId, {
    required int anzahl,
  });
}

class FirestoreVerlaufRepository implements VerlaufRepository {
  const FirestoreVerlaufRepository(this._db);

  final FirebaseFirestore _db;

  /// Braucht den Index `mitgliedId` + `stempel.am` (firestore.indexes.json).
  @override
  Stream<Verlauf> verlauf(
    String kasseId,
    String mitgliedId, {
    required int anzahl,
  }) => _db
      .collection('kassen/$kasseId/buchungen')
      .where('mitgliedId', isEqualTo: mitgliedId)
      .orderBy('stempel.am', descending: true)
      .limit(anzahl)
      .snapshots()
      .map(
        (q) => Verlauf(
          eintraegeAus([for (final d in q.docs) (d.id, d.data())]),
          mehr: q.docs.length >= anzahl,
        ),
      );
}

final verlaufRepositoryProvider = Provider<VerlaufRepository>(
  (ref) => FirestoreVerlaufRepository(ref.watch(firestoreProvider)),
);
