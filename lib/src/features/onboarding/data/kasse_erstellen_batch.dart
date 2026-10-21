import 'dart:typed_data';

import '../../kader/domain/name.dart';
import '../domain/codes.dart';
import '../../../core/firebase/schreibvorgang.dart';

/// Feste ID und Name des Mitglieds „Gäste“ (KAD-03).
const gaesteId = 'gaeste';
const gaesteName = 'Gäste';

/// Der Batch „Kasse erstellen“ (UC-01, AUTH-02, AUTH-03), genau so, wie ihn
/// `firestore.rules` verlangt (architecture.md, Verwaltung als Batches).
List<Schreibvorgang> kasseErstellenBatch({
  required String uid,
  required String kasseId,
  required String mitgliedId,
  required String buchungId,
  required String kassenName,
  required String eigenerName,
  required int startCents,
  required String einladungscode,
  required Uint8List wiederherstellungsHash,
  required DateTime geraetZeit,
}) {
  const jetzt = Serverzeit();
  final k = 'kassen/$kasseId';
  final kasse = nameBereinigen(kassenName);
  final name = nameBereinigen(eigenerName);

  Map<String, Object?> mitglied(String n, {String? bierwartUid}) => {
    'name': n,
    'nameKey': nameKey(n),
    'istGast': bierwartUid == null,
    'bierwartUid': bierwartUid,
    'entfernt': false,
    'saldoCents': 0,
    'letzteBuchungId': buchungId,
    'angelegtAm': jetzt,
  };

  return [
    Schreibvorgang(k, {
      'name': kasse,
      'adminUid': uid,
      'kassenwartUid': uid,
      'einladungCode': einladungscode,
      'anzahlBierwarte': 1,
      'wiederherstellungHash': Bytes(wiederherstellungsHash),
      'leerSeit': null,
      'aufgeloest': false,
      'erstelltAm': jetzt,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang('$k/bierwarte/$uid', {
      'mitgliedId': mitgliedId,
      'name': name,
      'beigetretenAm': jetzt,
      'einladungCode': null,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang(
      '$k/mitglieder/$mitgliedId',
      mitglied(name, bierwartUid: uid),
    ),
    Schreibvorgang('$k/namen/${nameKey(name)}', {'mitgliedId': mitgliedId}),
    Schreibvorgang('$k/mitglieder/$gaesteId', mitglied(gaesteName)),
    Schreibvorgang('$k/namen/${nameKey(gaesteName)}', {'mitgliedId': gaesteId}),
    Schreibvorgang('$k/orte/kasse', {
      'art': 'kasse',
      'uid': null,
      'name': 'Kasse',
      'standCents': startCents,
      'ehemalig': false,
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
    Schreibvorgang('einladungen/$einladungscode', {
      'kasseId': kasseId,
      'kassenName': kasse,
      'anzahlBierwarte': 1,
      'erstelltAm': jetzt,
      'ersetzt': false,
    }),
    Schreibvorgang('wiederherstellung/${hexVon(wiederherstellungsHash)}', {
      'kasseId': kasseId,
    }),
    Schreibvorgang('users/$uid', {'kasseId': kasseId}),
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'kasseErstellt',
      'kassenName': kasse,
      'startCents': startCents,
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
