/// Ein Mitglied der Kasse (KAD-01, KAD-02, KAD-03).
class Mitglied {
  const Mitglied({
    required this.id,
    required this.name,
    required this.saldoCents,
    this.istGast = false,
  });

  final String id;
  final String name;

  /// Offener Betrag; negativ heißt Guthaben.
  final int saldoCents;

  /// „Gäste“: immer bar, nie offen (KAD-03).
  final bool istGast;
}

/// Reihenfolge im Raster der Strichliste: alphabetisch nach Vornamen,
/// „Gäste“ immer zuletzt (UI-06).
List<Mitglied> mitgliederFuerRaster(Iterable<Mitglied> mitglieder) =>
    [...mitglieder]..sort((a, b) {
      if (a.istGast != b.istGast) return a.istGast ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
