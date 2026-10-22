import 'dart:typed_data';

import '../../../core/firebase/schreibvorgang.dart';
import '../../kader/domain/name.dart';
import '../domain/codes.dart';
import '../domain/wiederherstellung.dart';

/// Wiederherstellung, Schritt 1 (ADR-0010): Der Nachweis belegt den Code
/// und gibt Lesezugriff auf die Kasse. [nachweis] ist normalisiert.
List<Schreibvorgang> nachweisBatch({
  required String uid,
  required String kasseId,
  required String nachweis,
}) => [
  Schreibvorgang('kassen/$kasseId/wiederherstellungen/$uid', {
    'nachweis': nachweis,
    'angelegtAm': const Serverzeit(),
  }),
];

/// Wiederherstellung, Schritt 2 (ADM-06, UC-03, UC-04): Wer den Code hat,
/// übernimmt ein Mitglied ([kandidat]) oder kommt als neues Mitglied
/// ([neuerName]) und wird Admin. Ein aktiver alter Zugang fällt weg, das alte
/// Portemonnaie wird ehemalig (GEL-08), weil sein Stand zur Übernahme nicht
/// sicher feststeht. Der Code wechselt, der Nachweis geht.
List<Schreibvorgang> wiederherstellenBatch({
  required String uid,
  required WiederherstellungsStand stand,
  required String buchungId,
  required String nachweis,
  required Uint8List neuerHash,
  required String neueMitgliedId,
  Kandidat? kandidat,
  String? neuerName,
  required DateTime geraetZeit,
}) {
  assert((kandidat == null) != (neuerName == null));
  const jetzt = Serverzeit();
  final k = 'kassen/${stand.kasseId}';
  final mitgliedId = kandidat?.mitgliedId ?? neueMitgliedId;
  final name = kandidat?.name ?? nameBereinigen(neuerName!);
  final alteUid = kandidat?.bierwartUid;
  final alteAktiv = stand.aktiv(alteUid);
  final altesOrt =
      alteUid != null && alteUid != uid && stand.orte.contains(alteUid);

  return [
    Schreibvorgang.update(k, {
      'adminUid': uid,
      'kassenwartUid': stand.kassenwartDanach(alteUid: alteUid, uid: uid),
      'wiederherstellungHash': Bytes(neuerHash),
      'leerSeit': null,
      if (!alteAktiv) 'anzahlBierwarte': const Erhoehen(1),
      'letzteBuchungId': buchungId,
    }),
    if (!alteAktiv)
      Schreibvorgang.update('einladungen/${stand.einladungCode}', {
        'anzahlBierwarte': const Erhoehen(1),
      }),
    Schreibvorgang('wiederherstellung/${hexVon(neuerHash)}', {
      'kasseId': stand.kasseId,
    }),
    Schreibvorgang.loeschen('wiederherstellung/${hexVon(hashVon(nachweis))}'),
    if (kandidat != null)
      Schreibvorgang.update('$k/mitglieder/$mitgliedId', {
        'bierwartUid': uid,
        'entfernt': false,
        'letzteBuchungId': buchungId,
      })
    else ...[
      Schreibvorgang('$k/mitglieder/$mitgliedId', {
        'name': name,
        'nameKey': nameKey(name),
        'istGast': false,
        'bierwartUid': uid,
        'entfernt': false,
        'saldoCents': 0,
        'letzteBuchungId': buchungId,
        'angelegtAm': jetzt,
      }),
      Schreibvorgang('$k/namen/${nameKey(name)}', {'mitgliedId': mitgliedId}),
    ],
    Schreibvorgang('$k/bierwarte/$uid', {
      'mitgliedId': mitgliedId,
      'name': name,
      'beigetretenAm': jetzt,
      'einladungCode': null,
      'letzteBuchungId': buchungId,
    }),
    if (alteAktiv) Schreibvorgang.loeschen('$k/bierwarte/$alteUid'),
    if (altesOrt)
      Schreibvorgang.update('$k/orte/$alteUid', {
        'ehemalig': true,
        'letzteBuchungId': buchungId,
      }),
    Schreibvorgang('$k/orte/$uid', {
      'art': 'portemonnaie',
      'uid': uid,
      'name': name,
      'standCents': 0,
      'ehemalig': false,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang('users/$uid', {'kasseId': stand.kasseId}),
    Schreibvorgang.loeschen('$k/wiederherstellungen/$uid'),
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'adminWiederhergestellt',
      'nachweis': nachweis,
      'mitgliedId': mitgliedId,
      'alteUid': alteUid,
      'neueUid': uid,
      'stempel': stempel(uid: uid, name: name, geraetZeit: geraetZeit),
    }),
  ];
}
