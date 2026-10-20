# ADR-0002: Geld als Cent-Integer

- **Status:** Angenommen
- **Datum:** 2026-10-20
- **Anforderungen:** NFA-04, NFA-11, BES-02, GEL-01 bis GEL-07

## Kontext

Bierwart rechnet ständig mit Geld: Striche, Zahlungen, Einkäufe, Übergaben, Kassensturz. Gleitkommazahlen (`double`) führen zu Rundungsfehlern (0,1 + 0,2 ≠ 0,3). NFA-04 verlangt ausdrücklich: 1.000 Striche à 1,50 € ergeben exakt 1.500,00 €.

## Entscheidung

- Jeder Geldbetrag ist ein **ganzzahliger Cent-Betrag** (`int` in Dart, Integer in Firestore, `number` als Ganzzahl in den Cloud Functions). 1,50 € = `150`.
- Felder mit Geld heißen mit Suffix `Cents` (z. B. `preisCents`, `betragCents`, `saldoCents`).
- In Dart kapselt ein Werttyp `Cents` (bzw. eine Hilfsfunktion zur Formatierung) Addition, Vergleich und die Ausgabe `1.481,90 €` mit echtem Minuszeichen `−` (NFA-11). Rechnen mit `double` ist im Code verboten. Eingaben werden ohne Umweg über `double` in Cent geparst.
- Security Rules und Functions prüfen, dass Geldfelder `int` sind (`is int`).
- Firestore kennt nur 64-Bit-Integer. In JavaScript sind Werte bis 2^53 exakt, das reicht weit.

## Alternativen

- **`double` mit Rundung:** fehleranfällig, NFA-04 nicht verlässlich erfüllbar.
- **Dezimal-Bibliothek (`decimal`):** exakt, aber schwerer zu speichern (String in Firestore) und nicht nötig, weil es keine Bruchteile von Cent gibt.

## Konsequenzen

- Summen und Salden sind exakt, Tests können auf Gleichheit prüfen.
- Formatierung und Parsing liegen an einer Stelle und sind getestet.
- Es gibt keine Bruchteile von Cent. Sollte je geteilt werden (z. B. eine Runde durch n), muss die Rundung explizit festgelegt werden (Release 2, STR-07/STR-08).
