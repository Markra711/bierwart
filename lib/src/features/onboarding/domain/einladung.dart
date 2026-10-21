/// Eine Einladung aus `einladungen/{code}`: was „Kasse beitreten?“ zeigt
/// (AUTH-05) und ob der Link noch gilt (AUTH-08).
class Einladung {
  const Einladung({
    required this.code,
    required this.kasseId,
    required this.kassenName,
    required this.anzahlBierwarte,
    required this.erstelltAm,
    required this.ersetzt,
  });

  final String code;
  final String kasseId;
  final String kassenName;
  final int anzahlBierwarte;
  final DateTime erstelltAm;
  final bool ersetzt;

  static const gueltigkeit = Duration(days: 7);

  /// Prüfung für die Anzeige. Maßgeblich bleiben die Rules mit der
  /// Serverzeit; eine falsch gehende Uhr am Gerät ändert daran nichts.
  EinladungsZustand zustand(DateTime jetzt) {
    if (ersetzt) return EinladungsZustand.ersetzt;
    if (!jetzt.isBefore(erstelltAm.add(gueltigkeit))) {
      return EinladungsZustand.abgelaufen;
    }
    return EinladungsZustand.gueltig;
  }

  /// „1 Bierwart“, „3 Bierwarte“.
  String get bierwarteText =>
      '$anzahlBierwarte ${anzahlBierwarte == 1 ? 'Bierwart' : 'Bierwarte'}';
}

enum EinladungsZustand {
  gueltig,
  ersetzt,
  abgelaufen;

  /// Meldung für einen Link, der nicht mehr gilt (AUTH-08).
  String? get meldung => switch (this) {
    gueltig => null,
    ersetzt =>
      'Dieser Link wurde durch einen neuen ersetzt. Frag nach dem aktuellen.',
    abgelaufen =>
      'Dieser Link ist abgelaufen. Einladungen gelten 7 Tage, frag nach '
          'einem neuen.',
  };
}
