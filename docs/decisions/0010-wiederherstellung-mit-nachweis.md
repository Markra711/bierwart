# ADR-0010: Wiederherstellung ohne Bierwart-Eintrag in zwei Schritten mit Nachweis

- **Status:** Angenommen
- **Datum:** 2026-10-22
- **Anforderungen:** ADM-06, UC-03, UC-04, AUTH-07, NFA-07; ergänzt [ADR-0003](0003-anonyme-auth-wiederherstellungscode.md), [ADR-0008](0008-uebernahme-bestaetigung.md) und [ADR-0009](0009-release-1-ohne-cloud-functions.md)

## Kontext

Wer sein Gerät verloren hat und als einziger Bierwart übrig ist, kommt nur mit dem Wiederherstellungscode zurück (ADR-0008). Die Rules erlauben dafür einen Batch `adminWiederhergestellt` mit Eintritt: Er übernimmt ein bestehendes Mitglied oder legt ein neues an, wird Admin, und der Code wechselt.

Diesen Batch kann die App aber nicht bauen. Ohne Bierwart-Eintrag darf sie nur `wiederherstellung/{hash}` (darin steht die `kasseId`), `einladungen/{code}` und `namen/{key}` lesen. Die Rules verlangen jedoch Werte aus nicht lesbaren Dokumenten: die alte UID des Mitglieds, ob sie noch aktiv ist und ein Portemonnaie hat, den Kassenwart und den aktuellen Einladungscode. Die Rules-Tests haben das nicht bemerkt, weil sie die Werte kennen. Release 1 hat keine Cloud Functions (ADR-0009), die das für den Client erledigen könnten.

## Entscheidung

Die Wiederherstellung ohne Bierwart-Eintrag läuft in zwei Schritten:

1. **Nachweis:** Die App schreibt `kassen/{k}/wiederherstellungen/{uid}` mit dem normalisierten Code (`nachweis`) und `angelegtAm`. Die Rules prüfen `sha256(nachweis) == wiederherstellungHash` der Kasse, die eigene UID und dass die Kasse nicht aufgelöst ist.
2. **Lesen und Eintritt:** Solange der Nachweis zum aktuellen Code passt, darf die UID die Kasse lesen (`darfLesen()` = Bierwart oder gültiger Nachweis). Die App liest Kasse, Mitglieder, Bierwarte und Orte und schreibt den bestehenden Batch `adminWiederhergestellt`. Darin wechselt der Code, und sie löscht ihren Nachweis.

Den Nachweis lesen nur sein Inhaber und, beim Auflösen, der Admin. Bierwarte sehen ihn nicht.

## Alternativen

- **Nur als neues Mitglied, Rules lockern:** Die Einladung zieht bei der Wiederherstellung nicht mit, der Kassenwart bleibt unverändert. Dann braucht die App nichts zu lesen, aber die alte Mitgliedschaft mit Name und Portemonnaie lässt sich nicht übernehmen; UC-03 wäre nur halb erfüllt. Verworfen.
- **Kasse für jeden Angemeldeten lesbar:** Die `kasseId` steht auch in alten, ersetzten Einladungen. Wer eine kennt, sähe den aktuellen Einladungscode und könnte beitreten. Verworfen.
- **Werte in `wiederherstellung/{hash}` spiegeln:** Kassenwart und Code ließen sich mitführen, die Zuordnung Mitglied → UID und aktive Bierwarte nicht ohne viele zusätzliche Schreibvorgänge. Verworfen.
- **Cloud Function:** Erst ab Release 2 (ADR-0009).

## Konsequenzen

- Wer den Code kennt, kann die ganze Kasse lesen, bevor er sie übernimmt. Das ist keine neue Macht: Mit dem Code kann er ohnehin Admin werden.
- Der Code steht im Nachweis-Dokument, bis die App es löscht. Nach dem Wechsel des Codes ist er wertlos, und Bierwarte können das Dokument nicht lesen.
- Bricht die App zwischen den Schritten ab, bleibt der Nachweis liegen. Er gilt weiter, bis der Code wechselt; ein neuer Versuch überschreibt ihn.
- `darfLesen()` kostet für Nicht-Bierwarte zwei Lesevorgänge mehr. Für Bierwarte ändert sich nichts.
- Das Auflösen löscht auch die Sammlung `wiederherstellungen/`.
