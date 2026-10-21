/// Eine Getränkesorte (BES-01).
class Sorte {
  const Sorte({
    required this.id,
    required this.name,
    required this.preisCents,
    required this.bestand,
    required this.reihenfolge,
    this.vorherigerPreisCents,
    this.aktiv = true,
  });

  final String id;
  final String name;
  final int preisCents;

  /// Flaschen; darf unter 0 fallen, gebucht wird trotzdem (STR-05).
  final int bestand;
  final int reihenfolge;

  /// Der Preis vor der letzten Änderung. Offline gebuchte Striche zu diesem
  /// Preis bleiben gültig (BES-02).
  final int? vorherigerPreisCents;

  /// Ausgeblendete Sorten fehlen auf der Strichliste (BES-01).
  final bool aktiv;

  bool get leer => bestand <= 0;
}

/// Sorten in der Reihenfolge des Rasters, bei Gleichstand nach Name.
List<Sorte> sortenFuerRaster(Iterable<Sorte> sorten) =>
    [...sorten]..sort((a, b) {
      final r = a.reihenfolge.compareTo(b.reihenfolge);
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

/// Ab 10 aktiven Sorten wird aus dem Raster eine Liste (UI-05).
const sortenAlsListeAb = 10;

/// Nächste freie Position für eine neue Sorte: ans Ende.
int naechsteReihenfolge(Iterable<Sorte> sorten) => sorten.isEmpty
    ? 0
    : sorten.map((s) => s.reihenfolge).reduce((a, b) => a > b ? a : b) + 1;

/// Kopfzeile des Lagers: „5 Sorten · 83 Flaschen“. Fehlbestand zählt nicht
/// mit.
({int sorten, int flaschen}) lagerSumme(Iterable<Sorte> aktive) => (
  sorten: aktive.length,
  flaschen: aktive.fold(0, (s, x) => s + (x.bestand > 0 ? x.bestand : 0)),
);

/// Füllung des Bestandsbalkens zwischen 0 und 1, gemessen an der Sorte mit
/// dem größten Bestand (BES-03).
double balkenAnteil(Sorte sorte, Iterable<Sorte> alle) {
  final groesster = alle.fold(1, (m, x) => x.bestand > m ? x.bestand : m);
  return sorte.bestand <= 0 ? 0 : sorte.bestand / groesster;
}

/// „38 Fl.“, bei Fehlbestand „−3 Fl.“.
String flaschenText(int bestand) =>
    '${bestand < 0 ? '−${-bestand}' : bestand} Fl.';

/// Höchstens 10 Sorten pro Einkauf: Die Rules prüfen jede Zeile einzeln, und
/// pro Request sind die Dokumentzugriffe begrenzt (architecture.md, Summen).
const einkaufMaxSorten = 10;

/// Schnellknöpfe je Zeile (BES-04).
const einkaufSchnell = [1, 6, 20, 24];

/// Zeilen eines Einkaufs zu `{sorteId: anzahl}`: ohne Sorte oder ohne Anzahl
/// fällt eine Zeile weg, doppelte Sorten werden zusammengezählt.
Map<String, int> einkaufZeilen(Iterable<(String?, int)> zeilen) {
  final summe = <String, int>{};
  for (final (sorte, anzahl) in zeilen) {
    if (sorte == null || anzahl <= 0) continue;
    summe[sorte] = (summe[sorte] ?? 0) + anzahl;
  }
  return summe;
}
