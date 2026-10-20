# ADR-0007: Salden, Bestand und Ortsstände per Trigger aggregieren

- **Status:** Ersetzt durch [ADR-0009](0009-release-1-ohne-cloud-functions.md)
- **Datum:** 2026-10-20
- **Anforderungen:** NFA-02, NFA-03, NFA-05, NFA-06, NFA-07, NFA-12, LOG-01, LOG-02, BES-06, GEL-06

## Kontext

Jede Buchung ist ein unveränderliches Dokument in `kassen/{k}/buchungen` (LOG-01, LOG-02, [ADR-0004](0004-geld-modell-kasse-portemonnaies.md)). Die Bildschirme brauchen daraus Summen: den Saldo je Mitglied, den Bestand je Sorte und den Stand von Kasse und Portemonnaies. Dafür gelten mehrere Anforderungen gleichzeitig:

- Buchen geht offline (NFA-02) und ist sofort lokal sichtbar (NFA-06).
- Zwei Geräte buchen gleichzeitig, ohne dass etwas verloren geht (NFA-03).
- Andere Geräte sehen die Änderung in unter 3 Sekunden (NFA-05).
- Die Summen dürfen nicht vom Client manipulierbar sein (NFA-07).
- Der Betrieb kostet unter 1 € im Monat (NFA-12). Deshalb kann nicht jede App bei jedem Start alle Buchungen lesen.

## Entscheidung

**Die App schreibt nur Buchungen. Eine Cloud Function rechnet die Summen nach. Bis dahin rechnet die App die noch offenen Buchungen selbst dazu.**

1. **Schreiben:** Die App legt eine Buchung mit eigener ID und `angewendet: false` an. Das geht offline, und zwei Geräte überschreiben sich nie. Die Rules prüfen Form, Beträge (`int`), Stempel und Rolle. Die Summenfelder (`saldoCents`, `bestand`, `standCents`) sind für Clients gesperrt.
2. **Anwenden:** Die Function `buchungAnwenden` (`onDocumentCreated`) wendet die Wirkung in **einer Transaktion** auf die Summen an. Danach setzt sie `angewendet: true` und `kassen.letzteBuchungAm`. Trigger können mehrfach feuern. Deshalb liest die Transaktion zuerst `angewendet` und bricht ab, wenn die Buchung schon angewendet ist.
3. **Anzeigen:** Die App zeigt **Summe aus Firestore + Wirkung aller Buchungen mit `angewendet == false`**. Diese Abfrage liefert nur wenige Dokumente: eigene Offline-Buchungen und frische Buchungen anderer Geräte. So stimmt die Anzeige sofort, auch offline, und unabhängig davon, wie schnell der Trigger läuft.
4. **Absolute Buchungen:** `bestandKorrektur` (BES-06) und `kassensturz` (GEL-06) setzen einen Wert, statt ihn zu verändern. Die Function rechnet sie beim Anwenden in eine Differenz um (`gezählt − aktueller Stand`). Diese Differenz speichert sie an der Buchung (`differenz`, beim Kassensturz `differenzCents`) und verbucht sie wie jede andere Änderung. Danach sind alle Wirkungen reine Plus- und Minusbeträge, und die Reihenfolge spielt keine Rolle mehr. Solange eine solche Buchung offen ist, zeigt die App den gezählten Wert plus die Wirkung später angelegter offener Buchungen.
5. **Eine Regel, zwei Sprachen:** Die Wirkung einer Buchung gibt es in Dart (Anzeige) und in TypeScript (Function). Beide werden mit denselben Testfällen geprüft: JSON-Fixtures unter `fixtures/buchungswirkung/` im Repo-Wurzelverzeichnis, je Fall Ausgangsstand, Buchungen und erwarteter Endstand.
6. **Fehler:** Eine Buchung, die die Rules durchgelassen haben, die die Function aber nicht anwenden kann (z. B. unbekannte Sorte), bekommt `angewendet: true` und `fehler: <Grund>` und ändert keine Summe. Die App zeigt sie im Verlauf als fehlgeschlagen an (NFA-10).

## Alternativen

- **Die App schreibt die Summen selbst per `FieldValue.increment()`, die Rules prüfen die Inkremente mit `getAfter()`.** Dafür braucht es keine Function, und die Logik gibt es nur einmal. Verworfen: Ein Einkauf mit vielen Zeilen ändert viele Sorten und sprengt das Limit von 20 Dokumentzugriffen pro Rules-Auswertung. Absolute Buchungen lassen sich so gar nicht sicher prüfen. Und die Rules würden zur zweiten, schwer testbaren Umsetzung der Geldlogik.
- **Die App berechnet alle Summen aus allen Buchungen.** Ganz ohne gespeicherte Summen. Verworfen: Jede App liest bei Kaltstart und nach längerer Funkstille das ganze Log. Bei ein paar tausend Buchungen pro Jahr und mehreren Bierwarten überschreitet das das kostenlose Lesekontingent (NFA-12).
- **Buchungen über Callable Functions.** Die Function würde Buchung und Summen in einem Schritt schreiben. Verworfen: Callables brauchen Netz, Buchen muss aber offline gehen (NFA-02).

## Konsequenzen

- Jede Buchung braucht die Function. Ohne Blaze-Tarif werden Buchungen nie angewendet. Die Anzeige stimmt dann zwar dank Schritt 3, aber die Liste offener Buchungen wächst immer weiter.
- Die Buchungswirkung muss in Dart und TypeScript gleich bleiben. Die gemeinsamen Fixtures sind Pflicht, und jede neue Buchungsart braucht dort Testfälle.
- Fällt die Function aus oder läuft sie in einen Fehler, bleiben Buchungen offen. Das muss sichtbar sein: Logs und Alarm bei Function-Fehlern. Ein manuelles Nachverarbeiten offener Buchungen ist als Admin-Werkzeug vorzusehen.
- Die Function ändert an einer Buchung nur Systemfelder (`angewendet`, `fehler`, `differenz`, `differenzCents`). Inhaltlich bleibt die Buchung unveränderlich (LOG-02).
- Kassensturz und Bestandskorrektur zeigen ihre Differenz erst endgültig, wenn die Function sie angewendet hat. Ob ein Kassensturz offline erlaubt sein soll, bleibt eine eigene Frage (offene Frage 11 in `architecture.md`).
- Kosten je Buchung: ein Schreibvorgang durch die App, ein Trigger-Aufruf und je nach Art 2 bis n+2 Schreibvorgänge in der Transaktion. Bei einer Mannschaft bleibt das im kostenlosen Kontingent.
