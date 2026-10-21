import '../../../core/firebase/schreibvorgang.dart';
import '../../kader/domain/name.dart';
import '../domain/sorte.dart';

/// Sorte ändern oder aus- und einblenden (BES-01). Ändert sich der Preis,
/// wandert der alte nach `vorherigerPreisCents` (BES-02); der Bestand bleibt.
List<Schreibvorgang> sorteAendernBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required Sorte sorte,
  required String name,
  required int preisCents,
  required bool aktiv,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  final neuerName = nameBereinigen(name);
  final vorheriger = preisCents == sorte.preisCents
      ? sorte.vorherigerPreisCents
      : sorte.preisCents;
  return [
    Schreibvorgang.update('$k/sorten/${sorte.id}', {
      'name': neuerName,
      'preisCents': preisCents,
      'vorherigerPreisCents': vorheriger,
      'aktiv': aktiv,
      'letzteBuchungId': buchungId,
    }),
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'sorteGeaendert',
      'sorteId': sorte.id,
      'name': neuerName,
      'preisCents': preisCents,
      'aktiv': aktiv,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
  ];
}

/// Bestand auf einen gezählten Wert setzen (BES-06). Absolut, nicht per
/// increment: [differenz] ist der Abstand zum Stand, den der Server gerade
/// gemeldet hat. Hat sich der Bestand inzwischen geändert, lehnen die Rules
/// ab (architecture.md, Summen, Punkt 7).
List<Schreibvorgang> bestandKorrekturBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required String sorteId,
  required int gezaehlt,
  required int differenz,
  required DateTime geraetZeit,
}) {
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'bestandKorrektur',
      'sorteId': sorteId,
      'gezaehlt': gezaehlt,
      'differenz': differenz,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    Schreibvorgang.update('$k/sorten/$sorteId', {
      'bestand': gezaehlt,
      'letzteBuchungId': buchungId,
    }),
  ];
}

/// Einkauf (BES-04, BES-05): Bestand jeder Sorte steigt, der Gesamtpreis geht
/// aus [ortId], dem eigenen Portemonnaie oder für den Kassenwart der Kasse.
List<Schreibvorgang> einkaufBatch({
  required String uid,
  required String bierwartName,
  required String kasseId,
  required String buchungId,
  required Map<String, int> zeilen,
  required int betragCents,
  required String ortId,
  required DateTime geraetZeit,
}) {
  assert(zeilen.isNotEmpty && zeilen.length <= einkaufMaxSorten);
  final k = 'kassen/$kasseId';
  return [
    Schreibvorgang('$k/buchungen/$buchungId', {
      'typ': 'einkauf',
      'zeilen': zeilen,
      'betragCents': betragCents,
      'ortId': ortId,
      'stempel': stempel(uid: uid, name: bierwartName, geraetZeit: geraetZeit),
    }),
    for (final MapEntry(key: sorteId, value: anzahl) in zeilen.entries)
      Schreibvorgang.update('$k/sorten/$sorteId', {
        'bestand': Erhoehen(anzahl),
        'letzteBuchungId': buchungId,
      }),
    Schreibvorgang.update('$k/orte/$ortId', {
      'standCents': Erhoehen(-betragCents),
      'letzteBuchungId': buchungId,
    }),
  ];
}
