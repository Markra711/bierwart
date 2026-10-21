import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';
import 'schreibvorgang.dart';

/// Schreibt Batches. Die Anwendungsschicht baut sie als reine Daten und
/// schreibt sie hierüber; Tests ersetzen den Schreiber.
abstract interface class Schreiber {
  /// Eine neue Dokument-ID, ohne zu schreiben (auch offline).
  String neueId();

  /// Endet erst, wenn der Server den Batch angenommen hat; lokal ist er
  /// sofort sichtbar (NFA-06). Offline wartet es, bis wieder Netz da ist
  /// (NFA-02). Buchungen warten deshalb nicht darauf.
  Future<void> schreiben(List<Schreibvorgang> vorgaenge);
}

/// Schreibt eine Liste von [Schreibvorgang]en als einen Firestore-Batch.
/// Die Platzhalter werden hier zu Firestore-Werten.
class BatchSchreiber implements Schreiber {
  const BatchSchreiber(this._db);

  final FirebaseFirestore _db;

  @override
  String neueId() => _db.collection('kassen').doc().id;

  @override
  Future<void> schreiben(List<Schreibvorgang> vorgaenge) {
    final batch = _db.batch();
    for (final s in vorgaenge) {
      final ref = _db.doc(s.pfad);
      final daten = firestoreWerte(s.daten);
      switch (s.art) {
        case Art.set:
          batch.set(ref, daten);
        case Art.update:
          batch.update(ref, daten);
        case Art.delete:
          batch.delete(ref);
      }
    }
    return batch.commit();
  }

  static Map<String, Object?> firestoreWerte(Map<String, Object?> daten) => {
    for (final e in daten.entries) e.key: _wert(e.value),
  };

  static Object? _wert(Object? v) => switch (v) {
    Serverzeit() => FieldValue.serverTimestamp(),
    Erhoehen(:final um) => FieldValue.increment(um),
    Bytes(:final wert) => Blob(wert),
    DateTime() => Timestamp.fromDate(v),
    Map<String, Object?>() => firestoreWerte(v),
    _ => v,
  };
}

final schreiberProvider = Provider<Schreiber>(
  (ref) => BatchSchreiber(ref.watch(firestoreProvider)),
);
