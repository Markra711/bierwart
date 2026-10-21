/// Eine Kasse, die gerade erstellt wird oder wurde (UC-01). Hält die beiden
/// Codes, die die App genau einmal anzeigt (AUTH-03).
class ErstellteKasse {
  const ErstellteKasse({
    required this.kasseId,
    required this.mitgliedId,
    required this.buchungId,
    required this.kassenName,
    required this.eigenerName,
    required this.startCents,
    required this.wiederherstellungscode,
    required this.einladungscode,
    this.gespeichert = false,
  });

  final String kasseId;
  final String mitgliedId;
  final String buchungId;
  final String kassenName;
  final String eigenerName;
  final int startCents;
  final String wiederherstellungscode;
  final String einladungscode;

  /// Der Server hat den Batch angenommen.
  final bool gespeichert;

  ErstellteKasse alsGespeichert() => ErstellteKasse(
    kasseId: kasseId,
    mitgliedId: mitgliedId,
    buchungId: buchungId,
    kassenName: kassenName,
    eigenerName: eigenerName,
    startCents: startCents,
    wiederherstellungscode: wiederherstellungscode,
    einladungscode: einladungscode,
    gespeichert: true,
  );
}
