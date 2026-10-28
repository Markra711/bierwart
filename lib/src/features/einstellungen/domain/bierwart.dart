import '../../../core/money/cents.dart';

/// Die beiden Rollen, die der Admin vergibt (ADM-03).
enum Rolle { admin, kassenwart }

/// Ein aktiver Bierwart mit Rollen und Portemonnaie, für die Einstellungen.
class Bierwart {
  const Bierwart({
    required this.uid,
    required this.name,
    required this.mitgliedId,
    this.istAdmin = false,
    this.istKassenwart = false,
    this.portemonnaieCents = 0,
  });

  final String uid;
  final String name;
  final String mitgliedId;
  final bool istAdmin;
  final bool istKassenwart;
  final int portemonnaieCents;

  bool hat(Rolle r) => r == Rolle.admin ? istAdmin : istKassenwart;
}

/// Eigener Eintrag zuerst, dann alphabetisch.
List<Bierwart> bierwarteSortiert(Iterable<Bierwart> alle, String? eigeneUid) =>
    [...alle]..sort((a, b) {
      if (a.uid == eigeneUid) return -1;
      if (b.uid == eigeneUid) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

/// Unterzeile wie im Design-Canvas: „du · Admin · Kassenwart“ oder
/// „Bierwart · Portemonnaie 32,00 €“.
String bierwartZeile(Bierwart b, {required bool ich}) => [
  if (ich) 'du',
  if (b.istAdmin) 'Admin',
  if (b.istKassenwart) 'Kassenwart',
  if (!b.istAdmin && !b.istKassenwart) 'Bierwart',
  if (!ich) 'Portemonnaie ${formatEuro(b.portemonnaieCents)}',
].join(' · ');

/// Warum der Admin [b] nicht entfernen kann, oder `null` (ADM-02): Admin
/// und Kassenwart übergeben ihre Rolle vorher.
String? entfernenGeht(Bierwart b) => b.istAdmin
    ? 'Den Admin kann niemand entfernen.'
    : b.istKassenwart
    ? 'Bestimm erst einen anderen Kassenwart.'
    : null;

/// Was beim Austreten mit dem Konto passiert (AUTH-15). Buchungen sind
/// unveränderlich (LOG-02), deshalb bleibt der Name im Verlauf.
const austretenLoeschtKonto =
    'Dein Konto auf diesem Gerät wird gelöscht. Dein Name und deine '
    'Buchungen bleiben im Verlauf der Kasse, damit die Abrechnung stimmt.';

/// Warum [ich] nicht austreten kann, oder `null` (AUTH-09): Das Portemonnaie
/// muss leer sein; Admin und Kassenwart übergeben vorher ihre Rolle, außer
/// sie sind der letzte Bierwart.
String? austretenGeht(Bierwart ich, {required int anzahlBierwarte}) {
  final stand = ich.portemonnaieCents;
  if (stand > 0) {
    return 'In deinem Portemonnaie sind noch ${formatEuro(stand)}. Gib sie '
        'erst dem Kassenwart.';
  }
  if (stand < 0) {
    return 'Die Kasse schuldet dir noch ${formatEuro(-stand)}. Lass dir das '
        'erst vom Kassenwart erstatten.';
  }
  if (anzahlBierwarte > 1) {
    if (ich.istAdmin) return 'Übergib erst die Admin-Rolle.';
    if (ich.istKassenwart) return 'Bestimm erst einen anderen Kassenwart.';
  }
  return null;
}

/// Ob der abgetippte Name zur Kasse passt (ADM-05); Leerraum am Rand zählt
/// nicht, Groß- und Kleinschreibung schon, wie in den Rules.
bool aufloesenBestaetigt(String eingabe, String kassenName) =>
    eingabe.trim() == kassenName;
