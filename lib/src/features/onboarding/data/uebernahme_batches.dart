import '../../../core/firebase/schreibvorgang.dart';
import '../../kader/domain/name.dart';
import '../domain/uebernahme.dart';

// „Das bin ich“ (UC-03, AUTH-07, ADR-0008), genau so, wie `firestore.rules`
// die Batches verlangt (architecture.md, Verwaltung als Batches).

Map<String, Object?> _log(
  String typ, {
  required String uid,
  required String stempelName,
  required DateTime geraetZeit,
  required Map<String, Object?> felder,
}) => {
  'typ': typ,
  ...felder,
  'stempel': stempel(uid: uid, name: stempelName, geraetZeit: geraetZeit),
};

/// Übernahme anfragen: nur die Anfrage und ihr Log. Der Stempel trägt den
/// Namen, wie ihn das neue Gerät eingetippt hat; die Rules vergleichen ihn
/// über den Namensschlüssel.
List<Schreibvorgang> uebernahmeAnfragenBatch({
  required String uid,
  required String kasseId,
  required String anfrageId,
  required String buchungId,
  required String mitgliedId,
  required String einladungscode,
  required String eingetippterName,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang('$k/uebernahmen/$anfrageId', {
      'neueUid': uid,
      'mitgliedId': mitgliedId,
      'einladungCode': einladungscode,
      'status': 'offen',
      'angefragtAm': const Serverzeit(),
      'entschiedenVon': null,
      'entschiedenAm': null,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang(
      '$k/buchungen/$buchungId',
      _log(
        'uebernahmeAngefragt',
        uid: uid,
        stempelName: nameBereinigen(eingetippterName),
        geraetZeit: geraetZeit,
        felder: {'uebernahmeId': anfrageId, 'mitgliedId': mitgliedId},
      ),
    ),
  ];
}

List<Schreibvorgang> _entscheiden({
  required String typ,
  required String status,
  required String uid,
  required String stempelName,
  required String kasseId,
  required String anfrageId,
  required String mitgliedId,
  required String buchungId,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang.update('$k/uebernahmen/$anfrageId', {
      'status': status,
      'entschiedenVon': uid,
      'entschiedenAm': const Serverzeit(),
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang(
      '$k/buchungen/$buchungId',
      _log(
        typ,
        uid: uid,
        stempelName: stempelName,
        geraetZeit: geraetZeit,
        felder: {'uebernahmeId': anfrageId, 'mitgliedId': mitgliedId},
      ),
    ),
  ];
}

/// Das neue Gerät zieht seine Anfrage zurück.
List<Schreibvorgang> uebernahmeZurueckziehenBatch({
  required String uid,
  required String kasseId,
  required String anfrageId,
  required String buchungId,
  required String mitgliedId,
  required String eingetippterName,
  required DateTime geraetZeit,
}) => _entscheiden(
  typ: 'uebernahmeZurueckgezogen',
  status: 'zurueckgezogen',
  uid: uid,
  stempelName: nameBereinigen(eingetippterName),
  kasseId: kasseId,
  anfrageId: anfrageId,
  mitgliedId: mitgliedId,
  buchungId: buchungId,
  geraetZeit: geraetZeit,
);

/// Ein Bierwart lehnt ab.
List<Schreibvorgang> uebernahmeAblehnenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required Uebernahme anfrage,
  required String buchungId,
  required DateTime geraetZeit,
}) => _entscheiden(
  typ: 'uebernahmeAbgelehnt',
  status: 'abgelehnt',
  uid: uid,
  stempelName: bierwartName,
  kasseId: kasseId,
  anfrageId: anfrage.id,
  mitgliedId: anfrage.mitgliedId,
  buchungId: buchungId,
  geraetZeit: geraetZeit,
);

/// Ein Bierwart bestätigt: Mitgliedschaft, Portemonnaie und Rollen gehen
/// 1:1 auf die neue UID über, die alte verliert den Zugang. Das alte
/// Portemonnaie bleibt mit Stand 0 stehen, damit der Verlauf lesbar bleibt.
List<Schreibvorgang> uebernahmeBestaetigenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required UebernahmeStand stand,
  required String buchungId,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  final a = stand.anfrage;
  final neu = a.neueUid;
  final alt = stand.alteUid;
  final rollen = <String, Object?>{
    if (alt != null && stand.adminUid == alt) 'adminUid': neu,
    if (alt != null && stand.kassenwartUid == alt) 'kassenwartUid': neu,
  };
  return [
    ..._entscheiden(
      typ: 'uebernahmeBestaetigt',
      status: 'bestaetigt',
      uid: uid,
      stempelName: bierwartName,
      kasseId: kasseId,
      anfrageId: a.id,
      mitgliedId: a.mitgliedId,
      buchungId: buchungId,
      geraetZeit: geraetZeit,
    ).where((s) => !s.pfad.contains('/buchungen/')),
    // Ein entferntes Mitglied wird dabei wieder aktiv (KAD-08).
    Schreibvorgang.update('$k/mitglieder/${a.mitgliedId}', {
      'bierwartUid': neu,
      'entfernt': false,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang('$k/bierwarte/$neu', {
      'mitgliedId': a.mitgliedId,
      'name': stand.mitgliedName,
      'beigetretenAm': const Serverzeit(),
      'einladungCode': a.einladungCode,
      'letzteBuchungId': buchungId,
    }),
    if (alt != neu)
      Schreibvorgang('$k/orte/$neu', {
        'art': 'portemonnaie',
        'uid': neu,
        'name': stand.mitgliedName,
        'standCents': stand.standCents,
        'ehemalig': false,
        'letzteBuchungId': buchungId,
      }),
    if (stand.alteAktiv) Schreibvorgang.loeschen('$k/bierwarte/$alt'),
    if (stand.umzug && stand.standCents != 0)
      Schreibvorgang.update('$k/orte/$alt', {
        'standCents': Erhoehen(-stand.standCents),
        'letzteBuchungId': buchungId,
      }),
    // Wer vorher kein aktiver Bierwart war, zählt jetzt mit, in Kasse und
    // aktueller Einladung (AUTH-05).
    if (!stand.alteAktiv || rollen.isNotEmpty)
      Schreibvorgang.update(k, {
        ...rollen,
        if (!stand.alteAktiv) 'anzahlBierwarte': const Erhoehen(1),
        'letzteBuchungId': buchungId,
      }),
    if (!stand.alteAktiv)
      Schreibvorgang.update('einladungen/${stand.einladungCode}', {
        'anzahlBierwarte': const Erhoehen(1),
      }),
    Schreibvorgang(
      '$k/buchungen/$buchungId',
      _log(
        'uebernahmeBestaetigt',
        uid: uid,
        stempelName: bierwartName,
        geraetZeit: geraetZeit,
        felder: {
          'uebernahmeId': a.id,
          'mitgliedId': a.mitgliedId,
          'alteUid': alt,
          'neueUid': neu,
          'standCents': stand.standCents,
        },
      ),
    ),
  ];
}

/// Nach der Bestätigung trägt das neue Gerät seine Kasse selbst ein; die
/// Rules erlauben das, sobald es Bierwart ist.
List<Schreibvorgang> uebernahmeAbschliessenBatch({
  required String uid,
  required String kasseId,
}) => [
  Schreibvorgang('users/$uid', {'kasseId': kasseId}),
];
