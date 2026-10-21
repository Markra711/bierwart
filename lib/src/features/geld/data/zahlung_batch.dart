import '../../../core/firebase/schreibvorgang.dart';

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
