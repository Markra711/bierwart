/// Wo Geld liegt (ADR-0004): die Kasse oder das Portemonnaie eines
/// Bierwarts. Ein Portemonnaie darf ins Minus, dann schuldet die Kasse dem
/// Bierwart eine Auslage (GEL-01).
class Ort {
  const Ort({
    required this.id,
    required this.name,
    required this.standCents,
    this.uid,
    this.ehemalig = false,
  });

  static const kasseId = 'kasse';

  /// `kasse` oder die UID des Bierwarts.
  final String id;
  final String name;
  final int standCents;
  final String? uid;

  /// Portemonnaie eines entfernten Bierwarts (GEL-08).
  final bool ehemalig;

  bool get istKasse => id == kasseId;
}

/// Was der Geld-Tab zeigt (GEL-07): Kasse, Portemonnaies und das
/// Vermögen der Mannschaft.
class Geldstand {
  const Geldstand({required this.kasse, required this.portemonnaies});

  final Ort? kasse;

  /// Eigenes zuerst, dann die anderen alphabetisch, ehemalige zuletzt.
  final List<Ort> portemonnaies;

  /// Kasse plus alle Portemonnaies, auch ehemalige.
  int get vermoegenCents =>
      (kasse?.standCents ?? 0) +
      portemonnaies.fold(0, (summe, o) => summe + o.standCents);
}

/// Sortiert die Orte für den Geld-Tab. Ehemalige Portemonnaies bleiben
/// sichtbar, bis sie per Übergabe auf 0 stehen (GEL-08). [namen] ersetzt
/// den Namen am Ort, der beim Anlegen festgehalten wurde, durch den
/// aktuellen (nach UID).
Geldstand geldstand(
  Iterable<Ort> orte, {
  required String? eigeneUid,
  Map<String, String> namen = const {},
}) {
  Ort? kasse;
  final portemonnaies = <Ort>[];
  for (final o in orte) {
    if (o.istKasse) {
      kasse = o;
    } else if (!o.ehemalig || o.standCents != 0) {
      final name = namen[o.id];
      portemonnaies.add(
        name == null
            ? o
            : Ort(
                id: o.id,
                name: name,
                standCents: o.standCents,
                uid: o.uid,
                ehemalig: o.ehemalig,
              ),
      );
    }
  }
  int rang(Ort o) => o.id == eigeneUid
      ? 0
      : o.ehemalig
      ? 2
      : 1;
  portemonnaies.sort((a, b) {
    final r = rang(a).compareTo(rang(b));
    return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return Geldstand(kasse: kasse, portemonnaies: portemonnaies);
}
