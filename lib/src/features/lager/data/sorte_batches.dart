import '../../../core/firebase/schreibvorgang.dart';
import '../../kader/domain/name.dart';

/// Sorte anlegen (BES-01): Bestand 0, sichtbar, Log-Buchung `sorteAngelegt`
/// (LOG-01), wie es `firestore.rules` verlangt.
List<Schreibvorgang> sorteAnlegenBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String sorteId,
  required String buchungId,
  required String name,
  required int preisCents,
  required int reihenfolge,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  final sorte = nameBereinigen(name);
  return [
    Schreibvorgang('$k/sorten/$sorteId', {
      'name': sorte,
      'preisCents': preisCents,
      'vorherigerPreisCents': null,
      'aktiv': true,
      'bestand': 0,
      'letzteBuchungId': buchungId,
      'reihenfolge': reihenfolge,
    }),
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'sorteAngelegt',
      'sorteId': sorteId,
      'name': sorte,
      'preisCents': preisCents,
      'aktiv': true,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
  ];
}
