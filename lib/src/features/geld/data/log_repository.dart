import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/logbuchung.dart';

DateTime? _zeit(Object? wert) => switch (wert) {
  Timestamp() => wert.toDate(),
  DateTime() => wert,
  _ => null,
};

/// Eine Buchung aus `kassen/{k}/buchungen/{id}` für den Verlauf. Solange sie
/// nur lokal liegt, fehlt `stempel.am`; dann gilt die Gerätezeit.
Logbuchung logbuchungAus(String id, Map<String, Object?> d) {
  final stempel = d['stempel']! as Map<String, Object?>;
  final typ = LogTyp.values.asNameMap()[d['typ']] ?? LogTyp.unbekannt;
  final zeilen = d['zeilen'] as Map<String, Object?>?;
  return Logbuchung(
    id: id,
    typ: typ,
    zeit: _zeit(stempel['am']) ?? _zeit(stempel['geraetAm']) ?? DateTime(2000),
    von: stempel['name'] as String? ?? '',
    mitgliedId: d['mitgliedId'] as String?,
    sorteId: d['sorteId'] as String?,
    ortId: d['ortId'] as String?,
    vonOrtId: d['vonOrtId'] as String?,
    nachOrtId: d['nachOrtId'] as String?,
    cents:
        (d['preisCents'] ??
                d['betragCents'] ??
                d['startCents'] ??
                d['gezaehltCents'])
            as int?,
    anzahl: zeilen != null
        ? zeilen.values.fold<int>(0, (a, b) => a + (b! as int))
        : d['gezaehlt'] as int?,
    differenz: (d['differenz'] ?? d['differenzCents']) as int?,
    grund: d['grund'] as String?,
    name: (d['name'] ?? d['kassenName']) as String?,
    nameAlt: d['nameAlt'] as String?,
    nameNeu: d['nameNeu'] as String?,
    rolle: d['rolle'] as String?,
    zielUid: (d['nachUid'] ?? d['uid']) as String?,
    bezugBar: d['bezugTyp'] == 'strichBar',
    bezugZahlung: d['bezugTyp'] == 'zahlung',
    aktiv: d['aktiv'] as bool? ?? true,
  );
}

/// Eine Seite des Verlaufs und ob es ältere Buchungen geben kann.
class LogSeite {
  const LogSeite(this.buchungen, {required this.mehr});

  final List<Logbuchung> buchungen;

  /// Das Limit wurde ausgeschöpft; „Ältere laden“ lohnt sich.
  final bool mehr;
}

abstract interface class LogRepository {
  /// Die letzten [anzahl] Buchungen der Kasse, neueste zuerst, optional nur
  /// die eines Bierwarts (Stempel) oder eines Mitglieds (LOG-03).
  Stream<LogSeite> log(
    String kasseId, {
    String? bierwartUid,
    String? mitgliedId,
    required int anzahl,
  });
}

class FirestoreLogRepository implements LogRepository {
  const FirestoreLogRepository(this._db);

  final FirebaseFirestore _db;

  /// Mit Filtern braucht das Indizes aus `stempel.uid`, `mitgliedId` und
  /// `stempel.am` (firestore.indexes.json).
  @override
  Stream<LogSeite> log(
    String kasseId, {
    String? bierwartUid,
    String? mitgliedId,
    required int anzahl,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('kassen/$kasseId/buchungen');
    if (bierwartUid != null) q = q.where('stempel.uid', isEqualTo: bierwartUid);
    if (mitgliedId != null) q = q.where('mitgliedId', isEqualTo: mitgliedId);
    return q
        .orderBy('stempel.am', descending: true)
        .limit(anzahl)
        .snapshots()
        .map(
          (s) => LogSeite([
            for (final d in s.docs) logbuchungAus(d.id, d.data()),
          ], mehr: s.docs.length >= anzahl),
        );
  }
}

final logRepositoryProvider = Provider<LogRepository>(
  (ref) => FirestoreLogRepository(ref.watch(firestoreProvider)),
);
