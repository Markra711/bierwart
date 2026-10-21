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
