import '../../kader/domain/name.dart';
import 'schreibvorgang.dart';

/// Der Batch „Beitreten“ (UC-02, AUTH-07, AUTH-08), genau so, wie ihn
/// `firestore.rules` verlangt (architecture.md, Verwaltung als Batches): eigener
/// Bierwart-Eintrag mit dem Code, neues Mitglied samt Namensindex,
/// Portemonnaie, Anzahl in Kasse und Einladung, `users/{uid}` und Log.
List<Schreibvorgang> beitretenBatch({
  required String uid,
  required String kasseId,
  required String einladungscode,
  required String mitgliedId,
  required String buchungId,
  required String eigenerName,
  required DateTime geraetZeit,
}) {
  const jetzt = Serverzeit();
  final k = 'kassen/$kasseId';
  final name = nameBereinigen(eigenerName);

  return [
    Schreibvorgang('$k/bierwarte/$uid', {
      'mitgliedId': mitgliedId,
      'name': name,
      'beigetretenAm': jetzt,
      'einladungCode': einladungscode,
      'letzteBuchungId': buchungId,
    }),
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
    Schreibvorgang('$k/orte/$uid', {
      'art': 'portemonnaie',
      'uid': uid,
      'name': name,
      'standCents': 0,
      'ehemalig': false,
      'letzteBuchungId': buchungId,
    }),
    // Eine leere Kasse ist mit dem Beitritt nicht mehr leer (AUTH-10).
    Schreibvorgang.update(k, {
      'anzahlBierwarte': const Erhoehen(1),
      'leerSeit': null,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang.update('einladungen/$einladungscode', {
      'anzahlBierwarte': const Erhoehen(1),
    }),
    Schreibvorgang('users/$uid', {'kasseId': kasseId}),
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'bierwartBeigetreten',
      'mitgliedId': mitgliedId,
      'name': name,
      'stempel': {
        'uid': uid,
        'name': name,
        'am': jetzt,
        'geraetAm': geraetZeit,
      },
    }),
  ];
}
