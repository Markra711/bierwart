/// Eine Zeile im Verlauf eines Mitglieds (KAD-06): Strich, Bar-Strich oder
/// Zahlung, mit Zeit und Stempel.
enum EintragArt { strich, strichBar, zahlung }

class Eintrag {
  const Eintrag({
    required this.buchungId,
    required this.art,
    required this.cents,
    required this.zeit,
    required this.von,
    this.sorteId,
    this.ortId,
    this.storniert = false,
  });

  final String buchungId;
  final EintragArt art;

  /// Preis des Strichs oder Betrag der Zahlung.
  final int cents;
  final DateTime zeit;

  /// Name im Stempel: wer gebucht hat.
  final String von;
  final String? sorteId;
  final String? ortId;

  /// Für diesen Strich gibt es ein Storno (STR-06).
  final bool storniert;

  bool get istStrich => art != EintragArt.zahlung;
}

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String _zwei(int n) => n.toString().padLeft(2, '0');

/// „Sa 17.10., 20:41“ wie im Design-Canvas.
String zeitText(DateTime t) =>
    '${_wochentage[t.weekday - 1]} ${_zwei(t.day)}.${_zwei(t.month)}., '
    '${_zwei(t.hour)}:${_zwei(t.minute)}';

/// Vorname aus einem Namen, für „von Tobias“.
String vorname(String name) => name.trim().split(RegExp(r'\s+')).first;
