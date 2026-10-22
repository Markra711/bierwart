/// Fehler in den Eingaben eines Anlege-Sheets, je Feld.
class Eingabefehler {
  const Eingabefehler({
    this.name,
    this.preis,
    this.allgemein,
    this.entferntesMitgliedId,
    this.anzahl,
    this.grund,
  });

  final String? name;

  /// Preis oder Betrag.
  final String? preis;
  final String? allgemein;

  /// Eine Anzahl, z. B. gezählte Flaschen.
  final String? anzahl;

  /// Grund einer Ein- oder Auszahlung (GEL-05).
  final String? grund;

  /// Der Name gehört einem entfernten Mitglied; das Sheet bietet „wieder
  /// aufnehmen“ an (KAD-08).
  final String? entferntesMitgliedId;

  bool get keine =>
      name == null &&
      preis == null &&
      allgemein == null &&
      anzahl == null &&
      grund == null;
}
