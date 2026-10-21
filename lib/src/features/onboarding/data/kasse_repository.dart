import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../kader/domain/name.dart';
import '../domain/codes.dart';
import '../domain/einladung.dart';
import '../domain/erstellte_kasse.dart';
import 'beitreten_batch.dart';
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

  /// Die Einladung zum Code, direkt vom Server; `null`, wenn es sie nicht
  /// gibt (AUTH-05, AUTH-08). Wirft [VerwaltungsFehler].
  Future<Einladung?> einladungLaden(String code);

  /// Ob der Name in der Kasse schon vergeben ist (AUTH-07).
  Future<bool> nameVergeben(String kasseId, String name);

  /// Beitreten mit gültiger Einladung (UC-02). Wirft [VerwaltungsFehler].
  Future<void> beitreten(String uid, Einladung einladung, String eigenerName);
}

class FirestoreKasseRepository implements KasseRepository {
  FirestoreKasseRepository(
    this._db, {
    this.antwortFrist = const Duration(seconds: 20),
  });

  final FirebaseFirestore _db;
  final Duration antwortFrist;

  static const _server = GetOptions(source: Source.server);

  String _neueId() => _db.collection('kassen').doc().id;

  @override
  ErstellteKasse vorbereiten({
    required String kassenName,
    required String eigenerName,
    required int startCents,
  }) => ErstellteKasse(
    kasseId: _neueId(),
    mitgliedId: _neueId(),
    buchungId: _neueId(),
    kassenName: kassenName,
    eigenerName: eigenerName,
    startCents: startCents,
    wiederherstellungscode: zufallsCode(wiederherstellungscodeLaenge),
    einladungscode: zufallsCode(einladungscodeLaenge),
  );

  /// Verwaltung braucht Netz: Eine Abfrage beim Server prüft das vorab,
  /// statt endlos zu warten (architecture.md).
  @override
  Future<void> erstellen(String uid, ErstellteKasse k) =>
      _mitServer('Die Kasse ließ sich nicht erstellen', () async {
        await _db.doc('users/$uid').get(_server).timeout(antwortFrist);
        await _schreiben(
          kasseErstellenBatch(
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
          ),
        );
      });

  @override
  Future<Einladung?> einladungLaden(String code) =>
      _mitServer('Die Einladung ließ sich nicht laden', () async {
        final snap = await _db
            .doc('einladungen/$code')
            .get(_server)
            .timeout(antwortFrist);
        final d = snap.data();
        if (d == null) return null;
        return Einladung(
          code: code,
          kasseId: d['kasseId'] as String,
          kassenName: d['kassenName'] as String,
          anzahlBierwarte: d['anzahlBierwarte'] as int,
          erstelltAm: (d['erstelltAm'] as Timestamp).toDate(),
          ersetzt: d['ersetzt'] as bool,
        );
      });

  @override
  Future<bool> nameVergeben(String kasseId, String name) =>
      _mitServer('Der Name ließ sich nicht prüfen', () async {
        final snap = await _db
            .doc('kassen/$kasseId/namen/${nameKey(name)}')
            .get(_server)
            .timeout(antwortFrist);
        return snap.exists;
      });

  @override
  Future<void> beitreten(String uid, Einladung e, String eigenerName) =>
      _mitServer(
        'Der Beitritt hat nicht geklappt',
        () => _schreiben(
          beitretenBatch(
            uid: uid,
            kasseId: e.kasseId,
            einladungscode: e.code,
            mitgliedId: _neueId(),
            buchungId: _neueId(),
            eigenerName: eigenerName,
            geraetZeit: DateTime.now(),
          ),
        ),
      );

  Future<void> _schreiben(List<Schreibvorgang> vorgaenge) async {
    final batch = _db.batch();
    for (final s in vorgaenge) {
      final ref = _db.doc(s.pfad);
      final daten = _firestoreWerte(s.daten);
      switch (s.art) {
        case Art.set:
          batch.set(ref, daten);
        case Art.update:
          batch.update(ref, daten);
      }
    }
    await batch.commit().timeout(antwortFrist);
  }

  /// Übersetzt Firebase-Fehler in Meldungen (NFA-10).
  Future<T> _mitServer<T>(String sonst, Future<T> Function() aktion) async {
    try {
      return await aktion();
    } on TimeoutException {
      throw const VerwaltungsFehler(
        'Keine Antwort vom Server. Prüf dein Netz und versuch es noch einmal.',
      );
    } on FirebaseException catch (e) {
      throw VerwaltungsFehler(switch (e.code) {
        'unavailable' => 'Dafür brauchst du Netz.',
        // Kann vieles heißen (andere Kasse, Rules nicht deployt), daher
        // keine Vermutung, aber der Code für die Fehlersuche.
        'permission-denied' => 'Der Server hat abgelehnt (permission-denied).',
        _ => '$sonst (${e.code}).',
      });
    }
  }

  static Map<String, Object?> _firestoreWerte(Map<String, Object?> daten) => {
    for (final e in daten.entries) e.key: _wert(e.value),
  };

  static Object? _wert(Object? v) => switch (v) {
    Serverzeit() => FieldValue.serverTimestamp(),
    Erhoehen(:final um) => FieldValue.increment(um),
    Bytes(:final wert) => Blob(wert),
    DateTime() => Timestamp.fromDate(v),
    Map<String, Object?>() => _firestoreWerte(v),
    _ => v,
  };
}

final kasseRepositoryProvider = Provider<KasseRepository>(
  (ref) => FirestoreKasseRepository(ref.watch(firestoreProvider)),
);
