import '../../../core/firebase/schreibvorgang.dart';
import '../../strichliste/data/strich_batches.dart';

/// Zahlung eines Mitglieds (GEL-02, GEL-03): Saldo sinkt um den Betrag, auch
/// unter 0 (Guthaben); das Geld geht in [ortId], das eigene Portemonnaie oder,
/// für den Kassenwart, die Kasse.
List<Schreibvorgang> zahlungBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required String mitgliedId,
  required int betragCents,
  required String ortId,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'zahlung',
      'mitgliedId': mitgliedId,
      'betragCents': betragCents,
      'ortId': ortId,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    Schreibvorgang.update('$k/mitglieder/$mitgliedId', {
      'saldoCents': Erhoehen(-betragCents),
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang.update('$k/orte/$ortId', {
      'standCents': Erhoehen(betragCents),
      'letzteBuchungId': buchungId,
    }),
  ];
}

/// Storno einer Zahlung (offene Frage 24): Der Saldo steigt wieder um den
/// Betrag, das Geld geht aus [ortId], dem Ort, in den es ging. Das darf nur,
/// wer diesen Ort verändern darf; die feste ID macht jedes Storno einmalig
/// (STR-06).
List<Schreibvorgang> zahlungStornoBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String zahlungId,
  required String mitgliedId,
  required int betragCents,
  required String ortId,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  final id = stornoId(zahlungId);
  return [
    Schreibvorgang('$k/buchungen/$id', {
      'typ': 'storno',
      'bezugId': zahlungId,
      'bezugTyp': 'zahlung',
      'mitgliedId': mitgliedId,
      'betragCents': betragCents,
      'ortId': ortId,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    Schreibvorgang.update('$k/mitglieder/$mitgliedId', {
      'saldoCents': Erhoehen(betragCents),
      'letzteBuchungId': id,
    }),
    Schreibvorgang.update('$k/orte/$ortId', {
      'standCents': Erhoehen(-betragCents),
      'letzteBuchungId': id,
    }),
  ];
}
