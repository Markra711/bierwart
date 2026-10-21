/// Fehler in den Eingaben eines Anlege-Sheets, je Feld.
class Eingabefehler {
  const Eingabefehler({this.name, this.preis, this.allgemein});

  final String? name;
  final String? preis;
  final String? allgemein;

  bool get keine => name == null && preis == null && allgemein == null;
}
