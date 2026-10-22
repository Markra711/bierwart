import '../../../core/firebase/schreibvorgang.dart';
import '../domain/bierwart.dart';

// Verwaltung durch den Admin (ADM-01 bis ADM-04), genau so, wie
// `firestore.rules` sie verlangt (architecture.md, Verwaltung als Batches).
// Werte wie Name und Anzahl der Kasse kommen frisch vom Server, weil die
// Rules sie in Kasse und Einladung gleich verlangen (AUTH-05).

Map<String, Object?> _log(
  String typ, {
  required String uid,
  required String bierwartName,
  required DateTime geraetZeit,
  Map<String, Object?> felder = const {},
}) => {
  'typ': typ,
  ...felder,
  'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
};

/// Neue Einladung, die alte ersetzt (ADM-01). [anzahlBierwarte] ist die
/// Anzahl nach dem Batch.
List<Schreibvorgang> _neuerLink({
  required String kasseId,
  required String alterCode,
  required String neuerCode,
  required String kassenName,
  required int anzahlBierwarte,
}) => [
  Schreibvorgang('einladungen/$neuerCode', {
    'kasseId': kasseId,
    'kassenName': kassenName,
    'anzahlBierwarte': anzahlBierwarte,
    'erstelltAm': const Serverzeit(),
    'ersetzt': false,
  }),
  Schreibvorgang.update('einladungen/$alterCode', {'ersetzt': true}),
];

/// Einladungslink erneuern (ADM-01, UC-07): Der alte gilt sofort nicht mehr.
List<Schreibvorgang> linkErneuernBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required String alterCode,
  required String neuerCode,
  required String kassenName,
  required int anzahlBierwarte,
  required DateTime geraetZeit,
}) => [
  Schreibvorgang.update('kassen/$kasseId', {
    'einladungCode': neuerCode,
    'letzteBuchungId': buchungId,
  }),
  ..._neuerLink(
    kasseId: kasseId,
    alterCode: alterCode,
    neuerCode: neuerCode,
    kassenName: kassenName,
    anzahlBierwarte: anzahlBierwarte,
  ),
  Schreibvorgang(
    'kassen/$kasseId/buchungen/$buchungId',
    _log(
      'einladungErneuert',
      uid: uid,
      bierwartName: bierwartName,
      geraetZeit: geraetZeit,
    ),
  ),
];

/// Bierwart entfernen (ADM-02, UC-08): Zugang weg, er bleibt Mitglied, sein
/// Portemonnaie wird ehemalig (GEL-08), der Link wird erneuert.
/// [anzahlBierwarte] ist die Anzahl vor dem Batch.
List<Schreibvorgang> bierwartEntfernenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required Bierwart wer,
  required String alterCode,
  required String neuerCode,
  required String kassenName,
  required int anzahlBierwarte,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang.loeschen('$k/bierwarte/${wer.uid}'),
    Schreibvorgang.update('$k/orte/${wer.uid}', {
      'ehemalig': true,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang.update(k, {
      'anzahlBierwarte': const Erhoehen(-1),
      'einladungCode': neuerCode,
      'letzteBuchungId': buchungId,
    }),
    ..._neuerLink(
      kasseId: kasseId,
      alterCode: alterCode,
      neuerCode: neuerCode,
      kassenName: kassenName,
      anzahlBierwarte: anzahlBierwarte - 1,
    ),
    Schreibvorgang(
      '$k/buchungen/$buchungId',
      _log(
        'bierwartEntfernt',
        uid: uid,
        bierwartName: bierwartName,
        geraetZeit: geraetZeit,
        felder: {'uid': wer.uid, 'mitgliedId': wer.mitgliedId},
      ),
    ),
  ];
}

/// Rolle übertragen (ADM-03, UC-09): Kassenwart bestimmen oder die
/// Admin-Rolle übergeben.
List<Schreibvorgang> rolleBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required Rolle rolle,
  required String vonUid,
  required String nachUid,
  required DateTime geraetZeit,
}) => [
  Schreibvorgang.update('kassen/$kasseId', {
    '${rolle.name}Uid': nachUid,
    'letzteBuchungId': buchungId,
  }),
  Schreibvorgang(
    'kassen/$kasseId/buchungen/$buchungId',
    _log(
      'rolleGeaendert',
      uid: uid,
      bierwartName: bierwartName,
      geraetZeit: geraetZeit,
      felder: {'rolle': rolle.name, 'vonUid': vonUid, 'nachUid': nachUid},
    ),
  ),
];

/// Kasse umbenennen (ADM-04); der Name in der Einladung zieht mit (AUTH-05).
List<Schreibvorgang> kasseUmbenennenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required String nameAlt,
  required String nameNeu,
  required String einladungCode,
  required DateTime geraetZeit,
}) => [
  Schreibvorgang.update('kassen/$kasseId', {
    'name': nameNeu,
    'letzteBuchungId': buchungId,
  }),
  Schreibvorgang.update('einladungen/$einladungCode', {'kassenName': nameNeu}),
  Schreibvorgang(
    'kassen/$kasseId/buchungen/$buchungId',
    _log(
      'kasseUmbenannt',
      uid: uid,
      bierwartName: bierwartName,
      geraetZeit: geraetZeit,
      felder: {'nameAlt': nameAlt, 'nameNeu': nameNeu},
    ),
  ),
];
