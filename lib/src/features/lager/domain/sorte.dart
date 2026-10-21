/// Eine Getränkesorte (BES-01).
class Sorte {
  const Sorte({
    required this.id,
    required this.name,
    required this.preisCents,
    required this.bestand,
    required this.reihenfolge,
  });

  final String id;
  final String name;
  final int preisCents;

  /// Flaschen; darf unter 0 fallen, gebucht wird trotzdem (STR-05).
  final int bestand;
  final int reihenfolge;

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
