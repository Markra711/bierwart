// Namen von Mitgliedern und Kassen (AUTH-07, UI-09, KAD-08).

/// So wird ein Name gespeichert: ohne Leerraum am Rand, Leerraum innen auf
/// ein Leerzeichen. Danach stimmt [nameKey] mit der Normalisierung in den
/// Rules überein, die nur ASCII-Leerraum kennt.
String nameBereinigen(String eingabe) =>
    eingabe.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Schlüssel im Namensindex `namen/{nameKey}`: klein geschrieben.
/// Unicode-NFC macht die App noch nicht (architecture.md, Grenze der
/// Normalisierung); Android-Tastaturen liefern NFC.
String nameKey(String name) => nameBereinigen(name).toLowerCase();

/// Höchstlänge wie in den Rules (`nameGueltig`).
const nameMaxLaenge = 60;

/// Fehlermeldung für die Eingabe oder `null`, wenn der Name passt.
String? namePruefen(String eingabe) {
  final name = nameBereinigen(eingabe);
  if (name.isEmpty) return 'Bitte einen Namen eingeben.';
  if (name.length > nameMaxLaenge) {
    return 'Höchstens $nameMaxLaenge Zeichen.';
  }
  return null;
}
