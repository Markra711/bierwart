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

/// Austreten (UC-05, AUTH-09): eigener Zugang und `users/{uid}` weg, die
/// Person bleibt Mitglied. Wer als letzter geht, setzt `leerSeit`
/// (AUTH-10). Das Portemonnaie muss leer sein, das prüfen die Rules.
List<Schreibvorgang> austretenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required String mitgliedId,
  required String einladungCode,
  required bool letzter,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang.loeschen('$k/bierwarte/$uid'),
    Schreibvorgang.update(k, {
      'anzahlBierwarte': const Erhoehen(-1),
      if (letzter) 'leerSeit': const Serverzeit(),
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang.update('einladungen/$einladungCode', {
      'anzahlBierwarte': const Erhoehen(-1),
    }),
    Schreibvorgang.loeschen('users/$uid'),
    Schreibvorgang(
      '$k/buchungen/$buchungId',
      _log(
        'ausgetreten',
        uid: uid,
        bierwartName: bierwartName,
        geraetZeit: geraetZeit,
        felder: {'mitgliedId': mitgliedId},
      ),
    ),
  ];
}

/// Auflösen, Schritt 1 (ADM-05, UC-10): Die Kasse ist danach für niemanden
/// außer dem Admin sichtbar. [bestaetigung] ist der abgetippte Kassenname.
List<Schreibvorgang> aufloesenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required String bestaetigung,
  required DateTime geraetZeit,
}) => [
  Schreibvorgang.update('kassen/$kasseId', {
    'aufgeloest': true,
    'aufloesenBestaetigung': bestaetigung,
    'letzteBuchungId': buchungId,
  }),
  Schreibvorgang(
    'kassen/$kasseId/buchungen/$buchungId',
    _log(
      'kasseAufgeloest',
      uid: uid,
      bierwartName: bierwartName,
      geraetZeit: geraetZeit,
    ),
  ),
];

/// Sammlungen unter einer Kasse, die das Auflösen leert (architecture.md,
/// Datenmodell).
const kassenSammlungen = [
  'buchungen',
  'mitglieder',
  'namen',
  'sorten',
  'orte',
  'uebernahmen',
  'bierwarte',
];

/// So viele Dokumente löscht ein Batch beim Auflösen.
const loeschPortion = 200;

/// Auflösen, Schritt 2: eine Portion Dokumente löschen.
List<Schreibvorgang> loeschBatch(Iterable<String> pfade) => [
  for (final p in pfade) Schreibvorgang.loeschen(p),
];

/// Auflösen, letzter Schritt: eigener Bierwart-Eintrag, Kasse, aktuelle
/// Einladung, Wiederherstellung und `users/{uid}`. Ersetzte Einladungen
/// bleiben liegen, bis Release 2 sie aufräumt.
List<Schreibvorgang> aufloesenSchlussBatch({
  required String uid,
  required String kasseId,
  required String einladungCode,
  required String wiederherstellungHex,
}) => [
  Schreibvorgang.loeschen('kassen/$kasseId/bierwarte/$uid'),
  Schreibvorgang.loeschen('kassen/$kasseId'),
  Schreibvorgang.loeschen('einladungen/$einladungCode'),
  Schreibvorgang.loeschen('wiederherstellung/$wiederherstellungHex'),
  Schreibvorgang.loeschen('users/$uid'),
];
