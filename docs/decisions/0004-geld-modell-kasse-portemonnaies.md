# ADR-0004: Geld-Modell – Kasse und Portemonnaies

- **Status:** Angenommen
- **Datum:** 2026-10-20
- **Anforderungen:** GEL-01 bis GEL-08, BES-05, UC-13, UC-16, UC-18 bis UC-20, LOG-01, LOG-02

## Kontext

In der Praxis liegt das Geld einer Mannschaft nicht an einem Ort. Der Kassenwart hat die Kassette, andere Bierwarte kassieren bar in der Kabine oder legen beim Einkauf Geld aus. Eine App, die nur „die Kasse“ kennt, stimmt deshalb nie mit der Wirklichkeit überein.

## Entscheidung

Geld liegt immer an **genau einem Ort**:

- **Kasse:** die physische Kassette beim Kassenwart. Nur der Kassenwart bucht direkt hinein oder heraus.
- **Portemonnaie** je Bierwart: das Geld, das er für die Mannschaft bei sich trägt. Es darf negativ sein. Dann schuldet die Kasse ihm eine Auslage (GEL-01).

Daneben stehen die **Salden der Mitglieder** (offener Betrag bzw. Guthaben). Sie sind Forderungen, kein Geld an einem Ort.

| Vorgang | Wirkung |
| --- | --- |
| Strich offen | Saldo des Mitglieds + Preis |
| Strich bar | Portemonnaie des buchenden Bierwarts + Preis |
| Zahlung | Saldo − Betrag; Portemonnaie des Kassierenden + Betrag (Kassenwart: wahlweise Kasse) |
| Einkauf | Portemonnaie − Kosten (Kassenwart: wahlweise Kasse) |
| Übergabe | Portemonnaie ↔ Kasse (nur Kassenwart) |
| Ein-/Auszahlung | Portemonnaie bzw. Kasse ± Betrag, mit Grund |
| Kassensturz | Kasse auf gezählten Betrag, Differenz als „Kassendifferenz“ |

- **Vermögen** = Kasse + Summe aller Portemonnaies (GEL-07).
- Jede Bewegung ist eine **unveränderliche Buchung** mit Stempel (LOG-01, LOG-02). Korrekturen sind Gegenbuchungen.
- Das Portemonnaie eines entfernten Bierwarts bleibt als „ehemalig“ sichtbar, bis es per Übergabe auf 0 steht (GEL-08).
- Austreten ist nur mit Portemonnaie = 0 möglich (AUTH-09).

## Alternativen

- **Nur eine Kasse:** einfacher, bildet aber Bargeld bei Bierwarten nicht ab. Der Kassenstand stimmt dann nie.
- **Konten mit doppelter Buchführung:** sauber, aber zu schwer für die Zielgruppe. Das gewählte Modell ist ein vereinfachter Spezialfall davon (Orte = Konten).

## Konsequenzen

- Jede Geldaktion muss angeben, welcher Ort betroffen ist. Die UI wählt den Standard (eigenes Portemonnaie), der Kassenwart kann auf die Kasse umstellen.
- Die Rechte hängen am Ort: Buchungen auf die Kasse prüfen serverseitig die Rolle Kassenwart (NFA-07).
- Salden und Ortsstände sind Summen über Buchungen. Wie sie aggregiert werden, beschreibt `architecture.md`.
