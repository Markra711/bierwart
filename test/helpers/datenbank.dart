import 'dart:async';

import 'package:bier_wart/src/core/firebase/batch_schreiber.dart';
import 'package:bier_wart/src/core/firebase/schreibvorgang.dart';
import 'package:bier_wart/src/core/speicher/lokaler_speicher.dart';
import 'package:bier_wart/src/features/einstellungen/data/einstellungen_repository.dart';
import 'package:bier_wart/src/features/geld/data/log_repository.dart';
import 'package:bier_wart/src/features/geld/data/orte_repository.dart';
import 'package:bier_wart/src/features/geld/domain/ort.dart';
import 'package:bier_wart/src/features/kader/data/mitglieder_repository.dart';
import 'package:bier_wart/src/features/kader/data/verlauf_repository.dart';
import 'package:bier_wart/src/features/kader/domain/mitglied.dart';
import 'package:bier_wart/src/features/kader/domain/name.dart';
import 'package:bier_wart/src/features/lager/data/sorten_repository.dart';
import 'package:bier_wart/src/features/lager/domain/sorte.dart';
import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
import 'package:bier_wart/src/features/onboarding/domain/einladung.dart';
import 'package:bier_wart/src/features/strichliste/data/kassenkopf_repository.dart';

/// Dokumente im Arbeitsspeicher statt Firestore. Wendet Batches an wie der
/// Server (set, update, increment) und liefert die Daten als Streams, damit
/// Widget-Tests sehen, was eine Buchung bewirkt. Mitglieder liefert
/// [FakeMitglieder], weil `aktive` schon für Sorten vergeben ist.
class FakeDatenbank
    implements
        Schreiber,
        SortenRepository,
        KassenkopfRepository,
        VerlaufRepository,
        OrteRepository,
        LogRepository,
        EinstellungenRepository {
  final docs = <String, Map<String, Object?>>{};
  final batches = <List<Schreibvorgang>>[];
  final _aenderung = StreamController<void>.broadcast();
  var _id = 0;

  /// Was die Fake-Datenbank als Serverzeit einsetzt.
  DateTime jetzt = DateTime(2026, 10, 22, 20);

  /// Lässt [schreiben] scheitern, z. B. wie eine Ablehnung beim Sync.
  Object? schreibFehler;

  Future<void> schliessen() => _aenderung.close();

  /// Kasse mit Rollen; ohne Angabe ist `uid` Admin und Kassenwart.
  void neueKasse(
    String k, {
    required String name,
    String admin = 'uid',
    String kassenwart = 'uid',
    String einladungCode = 'K7Q2MXA93DWFT2HC8RNP',
  }) {
    docs['kassen/$k'] = {
      'name': name,
      'adminUid': admin,
      'kassenwartUid': kassenwart,
      'einladungCode': einladungCode,
      'anzahlBierwarte': 0,
      'wiederherstellungHash': null,
      'aufgeloest': false,
    };
    docs['einladungen/$einladungCode'] = {
      'kasseId': k,
      'kassenName': name,
      'anzahlBierwarte': 0,
      'erstelltAm': DateTime(2026, 10, 19, 18),
      'ersetzt': false,
    };
    _aenderung.add(null);
  }

  /// Zählt `anzahlBierwarte` in Kasse und Einladung mit, wie beim Beitreten.
  void bierwart(String k, String uid, String name, {int stand = 0}) {
    docs['kassen/$k/bierwarte/$uid'] = {'name': name, 'mitgliedId': uid};
    final kasse = docs['kassen/$k']!;
    kasse['anzahlBierwarte'] = (kasse['anzahlBierwarte']! as int) + 1;
    final einladung = docs['einladungen/${kasse['einladungCode']}']!;
    einladung['anzahlBierwarte'] = kasse['anzahlBierwarte'];
    ort(k, uid, name, stand: stand);
    mitglied(k, uid, name, bierwartUid: uid);
  }

  /// Kasse oder Portemonnaie; ehemalige gehören zu entfernten Bierwarten.
  void ort(
    String k,
    String id,
    String name, {
    int stand = 0,
    bool ehemalig = false,
  }) {
    docs['kassen/$k/orte/$id'] = {
      'art': id == Ort.kasseId ? 'kasse' : 'portemonnaie',
      'uid': id == Ort.kasseId ? null : id,
      'name': name,
      'standCents': stand,
      'ehemalig': ehemalig,
    };
    _aenderung.add(null);
  }

  void mitglied(
    String k,
    String id,
    String name, {
    int saldo = 0,
    bool gast = false,
    bool entfernt = false,
    String? bierwartUid,
  }) {
    docs['kassen/$k/mitglieder/$id'] = {
      'name': name,
      'saldoCents': saldo,
      'istGast': gast,
      'entfernt': entfernt,
      'bierwartUid': bierwartUid,
    };
    docs['kassen/$k/namen/${nameKey(name)}'] = {'mitgliedId': id};
    _aenderung.add(null);
  }

  void sorte(
    String k,
    String id,
    String name,
    int preis, {
    int bestand = 10,
    int reihenfolge = 0,
    bool aktiv = true,
  }) {
    docs['kassen/$k/sorten/$id'] = {
      'name': name,
      'preisCents': preis,
      'bestand': bestand,
      'reihenfolge': reihenfolge,
      'aktiv': aktiv,
      'vorherigerPreisCents': null,
    };
    _aenderung.add(null);
  }

  @override
  String neueId() => 'id${++_id}';

  @override
  Future<void> schreiben(List<Schreibvorgang> vorgaenge) async {
    batches.add(vorgaenge);
    for (final s in vorgaenge) {
      if (s.art == Art.delete) {
        docs.remove(s.pfad);
        continue;
      }
      final alt = docs[s.pfad] ?? <String, Object?>{};
      final neu = s.art == Art.set ? <String, Object?>{} : {...alt};
      for (final e in s.daten.entries) {
        neu[e.key] = switch (e.value) {
          Erhoehen(:final um) => ((alt[e.key] as int?) ?? 0) + um,
          Serverzeit() => jetzt,
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

  Stream<Map<String, String>> mitgliederNamen(String kasseId) => _beobachten(
    () => {
      for (final e in _unter('kassen/$kasseId/mitglieder'))
        _letzte(e.key): e.value['name']! as String,
    },
  );

  Future<NamensBesitzer?> nameBelegt(String kasseId, String name) async {
    final id = docs['kassen/$kasseId/namen/${nameKey(name)}']?['mitgliedId'];
    if (id == null) return null;
    return NamensBesitzer(
      mitgliedId: id as String,
      entfernt: docs['kassen/$kasseId/mitglieder/$id']?['entfernt'] == true,
    );
  }

  @override
  Stream<List<Sorte>> alle(String kasseId) => _beobachten(
    () => [
      for (final e in _unter('kassen/$kasseId/sorten'))
        sorteAus(_letzte(e.key), e.value),
    ],
  );

  /// Lässt [bestandVomServer] scheitern, z. B. ohne Netz.
  Object? serverFehler;

  @override
  Future<int> bestandVomServer(String kasseId, String sorteId) async {
    if (serverFehler != null) throw serverFehler!;
    return docs['kassen/$kasseId/sorten/$sorteId']!['bestand']! as int;
  }

  @override
  Stream<Map<String, String>> namen(String kasseId) => _beobachten(
    () => {
      for (final e in _unter('kassen/$kasseId/sorten'))
        _letzte(e.key): e.value['name']! as String,
    },
  );

  @override
  Stream<KasseInfo?> kasse(String kasseId) => _beobachten(() {
    final d = docs['kassen/$kasseId'];
    return d == null
        ? null
        : KasseInfo(
            name: d['name']! as String,
            adminUid: d['adminUid']! as String,
            kassenwartUid: d['kassenwartUid']! as String,
            einladungCode: d['einladungCode'] as String? ?? '',
            anzahlBierwarte: d['anzahlBierwarte'] as int? ?? 1,
          );
  });

  @override
  Stream<Set<String>> aktiveBierwarte(String kasseId) => _beobachten(
    () => {for (final e in _unter('kassen/$kasseId/bierwarte')) _letzte(e.key)},
  );

  /// Wie die Firestore-Abfrage: Buchungen des Mitglieds, neueste zuerst,
  /// höchstens [anzahl], dann als Einträge.
  @override
  Stream<Verlauf> verlauf(
    String kasseId,
    String mitgliedId, {
    required int anzahl,
  }) => _beobachten(() {
    DateTime zeit(Map<String, Object?> d) =>
        (d['stempel']! as Map)['geraetAm']! as DateTime;
    final buchungen = [
      for (final e in _unter('kassen/$kasseId/buchungen'))
        if (e.value['mitgliedId'] == mitgliedId) (_letzte(e.key), e.value),
    ]..sort((a, b) => zeit(b.$2).compareTo(zeit(a.$2)));
    return Verlauf(
      eintraegeAus(buchungen.take(anzahl)),
      mehr: buchungen.length > anzahl,
    );
  });

  @override
  Stream<List<Ort>> orte(String kasseId) => _beobachten(
    () => [
      for (final e in _unter('kassen/$kasseId/orte'))
        ortAus(_letzte(e.key), e.value),
    ],
  );

  @override
  Future<int> kasseVomServer(String kasseId) async {
    if (serverFehler != null) throw serverFehler!;
    return docs['kassen/$kasseId/orte/kasse']!['standCents']! as int;
  }

  @override
  Stream<DateTime?> letzterKassensturz(String kasseId) => _beobachten(() {
    DateTime? letzter;
    for (final e in _unter('kassen/$kasseId/buchungen')) {
      if (e.value['typ'] != 'kassensturz') continue;
      final t = (e.value['stempel']! as Map)['geraetAm']! as DateTime;
      if (letzter == null || t.isAfter(letzter)) letzter = t;
    }
    return letzter;
  });

  /// Wie die Firestore-Abfrage: alle Buchungen, optional gefiltert,
  /// neueste zuerst, höchstens [anzahl].
  @override
  Stream<LogSeite> log(
    String kasseId, {
    String? bierwartUid,
    String? mitgliedId,
    required int anzahl,
  }) => _beobachten(() {
    DateTime zeit(Map<String, Object?> d) =>
        (d['stempel']! as Map)['geraetAm']! as DateTime;
    final buchungen = [
      for (final e in _unter('kassen/$kasseId/buchungen'))
        if ((bierwartUid == null ||
                (e.value['stempel']! as Map)['uid'] == bierwartUid) &&
            (mitgliedId == null || e.value['mitgliedId'] == mitgliedId))
          (_letzte(e.key), e.value),
    ]..sort((a, b) => zeit(b.$2).compareTo(zeit(a.$2)));
    return LogSeite([
      for (final (id, d) in buchungen.take(anzahl)) logbuchungAus(id, d),
    ], mehr: buchungen.length > anzahl);
  });

  /// Wie die Rules für den Testnutzer `uid`: ohne Bierwart-Eintrag oder in
  /// einer aufgelösten Kasse als Nicht-Admin kein Zugriff.
  @override
  Stream<Mitgliedschaft> mitgliedschaft(String kasseId) => _beobachten(() {
    final kasse = docs['kassen/$kasseId'];
    final bierwart = docs.containsKey('kassen/$kasseId/bierwarte/uid');
    if (kasse == null || !bierwart) return Mitgliedschaft.entfernt;
    if (kasse['aufgeloest'] == true) {
      return kasse['adminUid'] == 'uid'
          ? Mitgliedschaft.aufloesen
          : Mitgliedschaft.entfernt;
    }
    return Mitgliedschaft.aktiv;
  });

  @override
  Stream<List<BierwartEintrag>> bierwarte(String kasseId) => _beobachten(
    () => [
      for (final e in _unter('kassen/$kasseId/bierwarte'))
        BierwartEintrag(
          uid: _letzte(e.key),
          name: e.value['name']! as String,
          mitgliedId: e.value['mitgliedId']! as String,
        ),
    ],
  );

  @override
  Stream<Einladung?> einladung(String code) => _beobachten(() {
    final d = docs['einladungen/$code'];
    final erstellt = d?['erstelltAm'];
    if (d == null || erstellt is! DateTime) return null;
    return Einladung(
      code: code,
      kasseId: d['kasseId']! as String,
      kassenName: d['kassenName']! as String,
      anzahlBierwarte: d['anzahlBierwarte']! as int,
      erstelltAm: erstellt,
      ersetzt: d['ersetzt']! as bool,
    );
  });

  @override
  Future<KasseVomServer> kasseFuerVerwaltung(String kasseId) async {
    if (serverFehler != null) throw serverFehler!;
    final d = docs['kassen/$kasseId']!;
    return KasseVomServer(
      name: d['name']! as String,
      einladungCode: d['einladungCode']! as String,
      anzahlBierwarte: d['anzahlBierwarte']! as int,
      adminUid: d['adminUid']! as String,
      kassenwartUid: d['kassenwartUid']! as String,
      wiederherstellungHex: switch (d['wiederherstellungHash']) {
        Bytes(:final wert) => hexVon(wert),
        _ => '',
      },
    );
  }

  @override
  Future<int> portemonnaieVomServer(String kasseId, String uid) async {
    if (serverFehler != null) throw serverFehler!;
    return docs['kassen/$kasseId/orte/$uid']?['standCents'] as int? ?? 0;
  }

  @override
  Future<List<String>> pfade(
    String kasseId,
    String sammlung,
    int anzahl,
  ) async {
    if (serverFehler != null) throw serverFehler!;
    return [for (final e in _unter('kassen/$kasseId/$sammlung')) e.key]
        .take(anzahl)
        .toList();
  }

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
  Future<NamensBesitzer?> nameBelegt(String kasseId, String name) =>
      db.nameBelegt(kasseId, name);

  @override
  Stream<Map<String, String>> namen(String kasseId) =>
      db.mitgliederNamen(kasseId);
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
