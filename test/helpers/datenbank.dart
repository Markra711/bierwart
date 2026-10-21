import 'dart:async';

import 'package:bier_wart/src/core/firebase/batch_schreiber.dart';
import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/core/speicher/lokaler_speicher.dart';
import 'package:bier_wart/src/features/kader/data/mitglieder_repository.dart';
import 'package:bier_wart/src/features/kader/domain/mitglied.dart';
import 'package:bier_wart/src/features/kader/domain/name.dart';
import 'package:bier_wart/src/features/lager/data/sorten_repository.dart';
import 'package:bier_wart/src/features/lager/domain/sorte.dart';
import 'package:bier_wart/src/features/strichliste/data/kassenkopf_repository.dart';

/// Dokumente im Arbeitsspeicher statt Firestore. Wendet Batches an wie der
/// Server (set, update, increment) und liefert die Daten als Streams, damit
/// Widget-Tests sehen, was eine Buchung bewirkt. Mitglieder liefert
/// [FakeMitglieder], weil `aktive` schon für Sorten vergeben ist.
class FakeDatenbank
    implements Schreiber, SortenRepository, KassenkopfRepository {
  final docs = <String, Map<String, Object?>>{};
  final batches = <List<Schreibvorgang>>[];
  final _aenderung = StreamController<void>.broadcast();
  var _id = 0;

  /// Lässt [schreiben] scheitern, z. B. wie eine Ablehnung beim Sync.
  Object? schreibFehler;

  Future<void> schliessen() => _aenderung.close();

  void kasse(String k, {required String name}) {
    docs['kassen/$k'] = {'name': name};
    _aenderung.add(null);
  }

  void bierwart(String k, String uid, String name) {
    docs['kassen/$k/bierwarte/$uid'] = {'name': name, 'mitgliedId': uid};
    mitglied(k, uid, name);
  }

  void mitglied(
    String k,
    String id,
    String name, {
    int saldo = 0,
    bool gast = false,
  }) {
    docs['kassen/$k/mitglieder/$id'] = {
      'name': name,
      'saldoCents': saldo,
      'istGast': gast,
      'entfernt': false,
    };
    _aenderung.add(null);
  }

  void sorte(
    String k,
    String id,
    String name,
    int preis, {
    int bestand = 10,
    int reihenfolge = 0,
  }) {
    docs['kassen/$k/sorten/$id'] = {
      'name': name,
      'preisCents': preis,
      'bestand': bestand,
      'reihenfolge': reihenfolge,
      'aktiv': true,
    };
    _aenderung.add(null);
  }

  @override
  String neueId() => 'id${++_id}';

  @override
  Future<void> schreiben(List<Schreibvorgang> vorgaenge) async {
    batches.add(vorgaenge);
    for (final s in vorgaenge) {
      final alt = docs[s.pfad] ?? <String, Object?>{};
      final neu = s.art == Art.set ? <String, Object?>{} : {...alt};
      for (final e in s.daten.entries) {
        neu[e.key] = switch (e.value) {
          Erhoehen(:final um) => ((alt[e.key] as int?) ?? 0) + um,
          _ => e.value,
        };
      }
      docs[s.pfad] = neu;
    }
    _aenderung.add(null);
    if (schreibFehler != null) throw schreibFehler!;
  }

  Stream<T> _beobachten<T>(T Function() lesen) async* {
    yield lesen();
    await for (final _ in _aenderung.stream) {
      yield lesen();
    }
  }

  Iterable<MapEntry<String, Map<String, Object?>>> _unter(String pfad) =>
      docs.entries.where(
        (e) =>
            e.key.startsWith('$pfad/') &&
            !e.key.substring(pfad.length + 1).contains('/'),
      );

  String _letzte(String pfad) => pfad.split('/').last;

  @override
  Stream<List<Sorte>> aktive(String kasseId) => _beobachten(
    () => [
      for (final e in _unter('kassen/$kasseId/sorten'))
        if (e.value['aktiv'] == true) sorteAus(_letzte(e.key), e.value),
    ],
  );

  Stream<List<Mitglied>> mitgliederAktiv(String kasseId) => _beobachten(
    () => [
      for (final e in _unter('kassen/$kasseId/mitglieder'))
        if (e.value['entfernt'] != true) mitgliedAus(_letzte(e.key), e.value),
    ],
  );

  Future<bool> nameVergeben(String kasseId, String name) async =>
      _unter('kassen/$kasseId/mitglieder')
          .any((e) => nameKey(e.value['name']! as String) == nameKey(name));

  @override
  Stream<String?> kassenName(String kasseId) =>
      _beobachten(() => docs['kassen/$kasseId']?['name'] as String?);

  @override
  Stream<String?> bierwartName(String kasseId, String uid) => _beobachten(
    () => docs['kassen/$kasseId/bierwarte/$uid']?['name'] as String?,
  );
}

/// Leitet [MitgliederRepository.aktive] auf die Fake-Datenbank um.
class FakeMitglieder implements MitgliederRepository {
  const FakeMitglieder(this.db);

  final FakeDatenbank db;

  @override
  Stream<List<Mitglied>> aktive(String kasseId) => db.mitgliederAktiv(kasseId);

  @override
  Future<bool> nameVergeben(String kasseId, String name) =>
      db.nameVergeben(kasseId, name);
}

/// Einstellungen im Arbeitsspeicher statt shared_preferences.
class FakeSpeicher implements LokalerSpeicher {
  final werte = <String, String>{};

  @override
  Future<String?> lesen(String schluessel) async => werte[schluessel];

  @override
  Future<void> schreiben(String schluessel, String? wert) async =>
      wert == null ? werte.remove(schluessel) : werte[schluessel] = wert;
}
