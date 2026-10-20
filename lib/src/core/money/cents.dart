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
