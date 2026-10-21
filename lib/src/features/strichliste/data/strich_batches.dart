import '../../../core/firebase/schreibvorgang.dart';
import '../domain/strich.dart';

// Striche und ihr Storno als Batch aus Buchung und Summen (ADR-0009): Jede
// geänderte Summe bekommt `letzteBuchungId`, Summen ändern sich nur per
// `increment()` (NFA-03).

/// Strich offen (STR-02) oder bar (STR-03). Bar geht der Preis ins
/// Portemonnaie des Buchenden ([uid]), offen auf den Saldo.
List<Schreibvorgang> strichBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required StrichArt art,
  required String mitgliedId,
  required String sorteId,
  required int preisCents,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  final offen = art == StrichArt.offen;
  return [
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': offen ? 'strich' : 'strichBar',
      'mitgliedId': mitgliedId,
      'sorteId': sorteId,
      'preisCents': preisCents,
      if (!offen) 'ortId': uid,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    if (offen)
      Schreibvorgang.update('$k/mitglieder/$mitgliedId', {
        'saldoCents': Erhoehen(preisCents),
        'letzteBuchungId': buchungId,
      })
    else
      Schreibvorgang.update('$k/orte/$uid', {
        'standCents': Erhoehen(preisCents),
        'letzteBuchungId': buchungId,
      }),
    // Auch bei Bestand 0 und darunter (STR-05).
    Schreibvorgang.update('$k/sorten/$sorteId', {
      'bestand': const Erhoehen(-1),
      'letzteBuchungId': buchungId,
    }),
  ];
}

/// Feste ID des Stornos: Ein zweites Storno derselben Buchung wäre ein
/// Update, und das lehnen die Rules ab (STR-06).
String stornoId(String bezugId) => 'storno-$bezugId';

/// Storno eines Strichs („Rückgängig“, STR-04). Bar geht der Preis aus dem
/// Portemonnaie dessen, der storniert ([uid]).
List<Schreibvorgang> stornoBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required Strich strich,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  final id = stornoId(strich.buchungId);
  final offen = strich.art == StrichArt.offen;
  return [
    Schreibvorgang('$k/buchungen/$id', {
      'typ': 'storno',
      'bezugId': strich.buchungId,
      'bezugTyp': offen ? 'strich' : 'strichBar',
      'mitgliedId': strich.mitglied.id,
      'sorteId': strich.sorte.id,
      'preisCents': strich.preisCents,
      if (!offen) 'ortId': uid,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    if (offen)
      Schreibvorgang.update('$k/mitglieder/${strich.mitglied.id}', {
        'saldoCents': Erhoehen(-strich.preisCents),
        'letzteBuchungId': id,
      })
    else
      Schreibvorgang.update('$k/orte/$uid', {
        'standCents': Erhoehen(-strich.preisCents),
        'letzteBuchungId': id,
      }),
    Schreibvorgang.update('$k/sorten/${strich.sorte.id}', {
      'bestand': const Erhoehen(1),
      'letzteBuchungId': id,
    }),
  ];
}
