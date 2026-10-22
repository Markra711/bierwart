/// Ein Mitglied, als das sich jemand mit dem Wiederherstellungscode
/// zurückmelden kann (UC-03, ADM-06). „Gäste“ gehört nicht dazu.
class Kandidat {
  const Kandidat({
    required this.mitgliedId,
    required this.name,
    this.bierwartUid,
    this.entfernt = false,
  });

  final String mitgliedId;
  final String name;

  /// Die UID, die das Mitglied zuletzt als Bierwart hatte, oder `null`.
  final String? bierwartUid;
  final bool entfernt;
}

/// Was die App nach dem Nachweis über die Kasse weiß (ADR-0010).
class WiederherstellungsStand {
  const WiederherstellungsStand({
    required this.kasseId,
    required this.kassenName,
    required this.adminUid,
    required this.kassenwartUid,
    required this.einladungCode,
    required this.kandidaten,
    required this.aktiveBierwarte,
    required this.orte,
    this.namenKeys = const {},
  });

  final String kasseId;
  final String kassenName;
  final String adminUid;
  final String kassenwartUid;
  final String einladungCode;
  final List<Kandidat> kandidaten;

  /// UIDs mit Bierwart-Eintrag.
  final Set<String> aktiveBierwarte;

  /// IDs der Orte (Kasse und Portemonnaies).
  final Set<String> orte;

  /// Vergebene Namen im Index, auch „Gäste“ und entfernte (AUTH-07).
  final Set<String> namenKeys;

  bool aktiv(String? uid) => uid != null && aktiveBierwarte.contains(uid);

  /// Wer nach der Wiederherstellung Kassenwart ist: der bisherige, solange
  /// er aktiver Bierwart bleibt; sonst wer zurückkommt (offene Frage 25).
  String kassenwartDanach({required String? alteUid, required String uid}) =>
      kassenwartUid == alteUid || !aktiv(kassenwartUid) ? uid : kassenwartUid;

  /// Rolle oder Lage eines Kandidaten für die Auswahl.
  String beschreibung(Kandidat k) => [
    if (k.bierwartUid != null && k.bierwartUid == adminUid) 'Admin',
    if (k.bierwartUid != null && k.bierwartUid == kassenwartUid) 'Kassenwart',
    if (k.entfernt)
      'entfernt'
    else if (aktiv(k.bierwartUid))
      'Bierwart'
    else if (k.bierwartUid != null)
      'früher Bierwart'
    else
      'ohne App',
  ].join(' · ');

  /// Der Admin zuerst, er kommt am ehesten zurück; dann alphabetisch,
  /// entfernte zuletzt.
  List<Kandidat> get sortiert {
    int rang(Kandidat k) => k.bierwartUid != null && k.bierwartUid == adminUid
        ? 0
        : k.entfernt
        ? 2
        : 1;
    return [...kandidaten]..sort((a, b) {
      final r = rang(a).compareTo(rang(b));
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
}
