import '../../../core/firebase/schreibvorgang.dart';

/// Übergabe (GEL-04), nur durch den Kassenwart: von einem Portemonnaie in
/// die Kasse oder aus der Kasse in ein Portemonnaie. Genau eine Seite ist
/// die Kasse, das prüfen die Rules.
List<Schreibvorgang> uebergabeBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required String vonOrtId,
  required String nachOrtId,
  required int betragCents,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'uebergabe',
      'vonOrtId': vonOrtId,
      'nachOrtId': nachOrtId,
      'betragCents': betragCents,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    Schreibvorgang.update('$k/orte/$vonOrtId', {
      'standCents': Erhoehen(-betragCents),
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang.update('$k/orte/$nachOrtId', {
      'standCents': Erhoehen(betragCents),
      'letzteBuchungId': buchungId,
    }),
  ];
}

/// Ein- oder Auszahlung mit Grund (GEL-05), z. B. „Schiri bezahlt“: [ortId]
/// ist das eigene Portemonnaie oder, für den Kassenwart, die Kasse.
List<Schreibvorgang> einAuszahlungBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required bool einzahlung,
  required String ortId,
  required int betragCents,
  required String grund,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': einzahlung ? 'einzahlung' : 'auszahlung',
      'ortId': ortId,
      'betragCents': betragCents,
      'grund': grund,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    Schreibvorgang.update('$k/orte/$ortId', {
      'standCents': Erhoehen(einzahlung ? betragCents : -betragCents),
      'letzteBuchungId': buchungId,
    }),
  ];
}

/// Kassensturz (GEL-06): Die Kasse steht danach auf dem gezählten Betrag.
/// Absolut wie die Bestandskorrektur: [differenzCents] gilt zum Stand, den
/// der Server gerade gemeldet hat; hat er sich inzwischen geändert, lehnen
/// die Rules ab (architecture.md, Summen, Punkt 7).
List<Schreibvorgang> kassensturzBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required int gezaehltCents,
  required int differenzCents,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'kassensturz',
      'gezaehltCents': gezaehltCents,
      'differenzCents': differenzCents,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    Schreibvorgang.update('$k/orte/kasse', {
      'standCents': gezaehltCents,
      'letzteBuchungId': buchungId,
    }),
  ];
}
