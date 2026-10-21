import '../../../core/firebase/schreibvorgang.dart';
import '../domain/name.dart';

/// Mitglied anlegen (KAD-01): Saldo 0, kein Gast, kein Bierwart, Name im
/// Index (AUTH-07) und Log-Buchung `mitgliedAngelegt` (LOG-01).
List<Schreibvorgang> mitgliedAnlegenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String mitgliedId,
  required String buchungId,
  required String name,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  final mitglied = nameBereinigen(name);
  return [
    Schreibvorgang('$k/mitglieder/$mitgliedId', {
      'name': mitglied,
      'nameKey': nameKey(mitglied),
      'istGast': false,
      'bierwartUid': null,
      'entfernt': false,
      'saldoCents': 0,
      'letzteBuchungId': buchungId,
      'angelegtAm': const Serverzeit(),
    }),
    Schreibvorgang('$k/namen/${nameKey(mitglied)}', {'mitgliedId': mitgliedId}),
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'mitgliedAngelegt',
      'mitgliedId': mitgliedId,
      'name': mitglied,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
  ];
}

/// Umbenennen (KAD-01, UI-09): neuer Name in den Index, alter wird frei.
/// Ist das Mitglied ein aktiver Bierwart, zieht sein Name im Stempel mit
/// ([bierwartUid]).
List<Schreibvorgang> mitgliedUmbenennenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String mitgliedId,
  required String buchungId,
  required String nameAlt,
  required String nameNeu,
  required String? bierwartUid,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  final neu = nameBereinigen(nameNeu);
  return [
    Schreibvorgang.update('$k/mitglieder/$mitgliedId', {
      'name': neu,
      'nameKey': nameKey(neu),
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang('$k/namen/${nameKey(neu)}', {'mitgliedId': mitgliedId}),
    Schreibvorgang.loeschen('$k/namen/${nameKey(nameAlt)}'),
    if (bierwartUid != null)
      Schreibvorgang.update('$k/bierwarte/$bierwartUid', {
        'name': neu,
        'letzteBuchungId': buchungId,
      }),
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'mitgliedUmbenannt',
      'mitgliedId': mitgliedId,
      'nameAlt': nameAlt,
      'nameNeu': neu,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
  ];
}

/// Entfernen (KAD-04) oder wieder aufnehmen (KAD-08). Der Name bleibt im
/// Index reserviert; Saldo und Verlauf bleiben.
List<Schreibvorgang> mitgliedEntfernenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String mitgliedId,
  required String buchungId,
  required bool entfernen,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang.update('$k/mitglieder/$mitgliedId', {
      'entfernt': entfernen,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': entfernen ? 'mitgliedEntfernt' : 'mitgliedWiederaufgenommen',
      'mitgliedId': mitgliedId,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
  ];
}
