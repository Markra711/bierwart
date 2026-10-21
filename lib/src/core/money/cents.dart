// Geld ist immer ein ganzzahliger Cent-Betrag (ADR-0002, NFA-04).

/// Formatiert Cent als Euro-Betrag im deutschen Format (NFA-11):
/// `150` → `1,50 €`, `148190` → `1.481,90 €`, `-450` → `−4,50 €`.
String formatEuro(int cents) {
  final sign = cents < 0 ? '−' : '';
  final abs = cents.abs();
  final euros = (abs ~/ 100).toString();
  final rest = (abs % 100).toString().padLeft(2, '0');

  final grouped = StringBuffer();
  for (var i = 0; i < euros.length; i++) {
    if (i > 0 && (euros.length - i) % 3 == 0) grouped.write('.');
    grouped.write(euros[i]);
  }
  return '$sign$grouped,$rest €';
}

/// Liest einen eingetippten Euro-Betrag als Cent (ADR-0002), z. B. `50`,
/// `50,5`, `1.234,56` oder `12,00 €`. Negative und unlesbare Beträge ergeben
/// `null`. Ohne Komma gilt ein Punkt vor genau ein oder zwei Ziffern am Ende
/// nach reinen Ziffern als Dezimaltrenner (`12.5`), sonst als Tausenderpunkt.
int? parseEuro(String eingabe) {
  var s = eingabe.replaceAll('€', '').replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return null;
  if (!s.contains(',')) {
    final dezimal = RegExp(r'^(\d+)\.(\d{1,2})$').firstMatch(s);
    if (dezimal != null) s = '${dezimal.group(1)},${dezimal.group(2)}';
  }
  final m = RegExp(r'^(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  final euro = int.parse(m.group(1)!.replaceAll('.', ''));
  final cent = (m.group(2) ?? '0').padRight(2, '0');
  return euro * 100 + int.parse(cent);
}
