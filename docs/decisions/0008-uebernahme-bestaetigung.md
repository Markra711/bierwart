# ADR-0008: Übernahme einer Mitgliedschaft braucht die Bestätigung eines Bierwarts

- **Status:** Angenommen
- **Datum:** 2026-10-21
- **Anforderungen:** AUTH-07, UC-03, ADM-06, LOG-01, NFA-07; ergänzt [ADR-0003](0003-anonyme-auth-wiederherstellungscode.md)

## Kontext

Mit anonymer Auth (ADR-0003) bekommt jedes neue Gerät und jede Neuinstallation eine neue UID. Zurück in die eigene Mitgliedschaft kommt man über „Das bin ich (neues Gerät)“ beim Beitritt (AUTH-07, UC-03). Dabei gehen Mitgliedschaft, Portemonnaie und Rollen (Admin, Kassenwart) auf die neue UID über.

Der Einladungslink steckt meist in der Mannschaftsgruppe. Ohne Absicherung könnte jeder mit dem Link jeden vergebenen Namen übernehmen und damit fremdes Portemonnaie und fremde Rollen. Das alte Gerät kann die Übernahme oft nicht bestätigen, weil es verloren oder zurückgesetzt ist.

## Entscheidung

- „Das bin ich“ erzeugt eine **Übernahme-Anfrage**, keine sofortige Übernahme.
- **Irgendein aktiver Bierwart der Kasse** bestätigt oder lehnt die Anfrage in der App ab. Das alte Gerät derselben Person zählt auch, falls es noch da ist.
- Erst nach der Bestätigung überträgt eine Cloud Function Mitgliedschaft, Portemonnaie und Rollen auf die neue UID. Die alte UID verliert sofort den Zugang.
- **Gibt es keinen anderen aktiven Bierwart**, ist die übernommene Person also der einzige: Dann geht die Übernahme nur mit dem Wiederherstellungscode (ADM-06). Die Person wird dabei Admin, wie bisher.
- Bis zur Entscheidung ist das neue Gerät **kein Bierwart**. Es sieht nur einen Warte-Bildschirm mit dem Stand der Anfrage.
- Anfrage, Bestätigung und Ablehnung erscheinen mit Stempel im Log (LOG-01).
- Alles läuft über Callables, und die Rules erlauben Clients keinen direkten Schreibzugriff (NFA-07).

## Alternativen

- **Ohne Absicherung** (Stand der Anforderungen): Jeder mit Link übernimmt jeden Namen. Verworfen, weil das Portemonnaie und Rollen ungeschützt lässt.
- **Nur der Admin bestätigt:** strenger, blockiert aber, wenn der Admin nicht erreichbar ist oder selbst das Gerät gewechselt hat.
- **Nur mit Wiederherstellungscode:** sicher, aber dann müsste jeder Bierwart den Admin-Code kennen, und der wäre kein Geheimnis mehr.
- **Persönlicher Übertragungscode je Bierwart:** hilft nicht bei verlorenem Gerät, denn den Code sieht man nur auf dem alten Gerät.

## Konsequenzen

- AUTH-07 und UC-03 sind angepasst (`docs/requirements.md`). Das Online-Anforderungsdokument muss nachgezogen werden.
- Es gibt neue Oberflächen, die im Design-Canvas fehlen: ein Warte-Bildschirm im Onboarding und eine Stelle, an der Bierwarte offene Anfragen sehen und entscheiden.
- Release 1 hat keine Push-Benachrichtigungen. Die anderen Bierwarte sehen eine Anfrage also erst, wenn sie die App öffnen. Bis dahin wartet die neue Person.
- Zwei Bierwarte, die zusammenarbeiten, können eine falsche Übernahme bestätigen. Das nehmen wir in Kauf. Sie steht im Log und lässt sich durch den Admin rückgängig machen (Bierwart entfernen, ADM-02).
- Datenmodell, Rules und Callables: siehe `docs/architecture.md`.
