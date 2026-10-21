import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/codes.dart';
import '../domain/erstellte_kasse.dart';
import 'kasse_erstellen_batch.dart';
import 'schreibvorgang.dart';

/// Fehler einer Verwaltungsaktion mit einer Meldung für den Nutzer (NFA-10).
class VerwaltungsFehler implements Exception {
  const VerwaltungsFehler(this.meldung);

  final String meldung;

  @override
  String toString() => meldung;
}

abstract interface class KasseRepository {
  /// Codes und IDs für eine neue Kasse. Sie stehen fest, bevor geschrieben
  /// wird, damit die App den Wiederherstellungscode sicher anzeigen kann.
  ErstellteKasse vorbereiten({
    required String kassenName,
    required String eigenerName,
    required int startCents,
  });

  /// Kasse erstellen (UC-01). Wirft [VerwaltungsFehler] mit Meldung.
  Future<void> erstellen(String uid, ErstellteKasse kasse);
}

class FirestoreKasseRepository implements KasseRepository {
  FirestoreKasseRepository(
    this._db, {
    this.antwortFrist = const Duration(seconds: 20),
  });

  final FirebaseFirestore _db;
  final Duration antwortFrist;

  @override
  ErstellteKasse vorbereiten({
    required String kassenName,
    required String eigenerName,
    required int startCents,
  }) => ErstellteKasse(
    kasseId: _db.collection('kassen').doc().id,
    mitgliedId: _db.collection('kassen').doc().id,
    buchungId: _db.collection('kassen').doc().id,
    kassenName: kassenName,
    eigenerName: eigenerName,
    startCents: startCents,
    wiederherstellungscode: zufallsCode(wiederherstellungscodeLaenge),
    einladungscode: zufallsCode(einladungscodeLaenge),
  );

  /// Verwaltung braucht Netz: Eine Abfrage beim Server prüft das vorab,
  /// statt endlos zu warten (architecture.md).
  @override
  Future<void> erstellen(String uid, ErstellteKasse k) async {
    try {
      await _db
          .doc('users/$uid')
          .get(const GetOptions(source: Source.server))
          .timeout(antwortFrist);
      final batch = _db.batch();
      for (final s in kasseErstellenBatch(
        uid: uid,
        kasseId: k.kasseId,
        mitgliedId: k.mitgliedId,
        buchungId: k.buchungId,
        kassenName: k.kassenName,
        eigenerName: k.eigenerName,
        startCents: k.startCents,
        einladungscode: k.einladungscode,
        wiederherstellungsHash: hashVon(k.wiederherstellungscode),
        geraetZeit: DateTime.now(),
      )) {
        batch.set(_db.doc(s.pfad), _firestoreWerte(s.daten));
      }
      await batch.commit().timeout(antwortFrist);
    } on TimeoutException {
      throw const VerwaltungsFehler(
        'Keine Antwort vom Server. Prüf dein Netz und versuch es noch einmal.',
      );
    } on FirebaseException catch (e) {
      throw VerwaltungsFehler(switch (e.code) {
        'unavailable' => 'Dafür brauchst du Netz.',
        'permission-denied' =>
          'Abgelehnt. Bist du schon in einer anderen Kasse?',
        _ => 'Die Kasse ließ sich nicht erstellen (${e.code}).',
      });
    }
  }

  static Map<String, Object?> _firestoreWerte(Map<String, Object?> daten) => {
    for (final e in daten.entries) e.key: _wert(e.value),
  };

  static Object? _wert(Object? v) => switch (v) {
    Serverzeit() => FieldValue.serverTimestamp(),
    Bytes(:final wert) => Blob(wert),
    DateTime() => Timestamp.fromDate(v),
    Map<String, Object?>() => _firestoreWerte(v),
    _ => v,
  };
}

final kasseRepositoryProvider = Provider<KasseRepository>(
  (ref) => FirestoreKasseRepository(ref.watch(firestoreProvider)),
);
