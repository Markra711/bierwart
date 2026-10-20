# ADR-0003: Anonyme Auth + Wiederherstellungscode

- **Status:** Angenommen
- **Datum:** 2026-10-20
- **Anforderungen:** AUTH-01, AUTH-03, AUTH-07, AUTH-10, ADM-06, NFA-07, NFA-08

## Kontext

Bierwarte sollen ohne E-Mail und Passwort loslegen. Konten mit E-Mail oder Passwort sind ausdrücklich nicht Teil von Bierwart. Gespeichert werden nur Namen, Beträge, Zeitstempel und anonyme Nutzer-IDs (NFA-08). Trotzdem müssen Rechte serverseitig durchgesetzt werden (NFA-07), und eine Kasse darf nicht verloren gehen, wenn der Admin sein Handy verliert.

## Entscheidung

- Beim ersten Start meldet die App den Nutzer **anonym bei Firebase Auth** an, ohne Eingabe (AUTH-01). Die UID ist die Identität des Bierwarts. Mitgliedschaft und Rollen hängen an ihr.
- Beim Erstellen der Kasse erzeugt eine **Cloud Function** einen zufälligen **Wiederherstellungscode** mit hoher Entropie und zeigt ihn genau einmal an (AUTH-03). Gespeichert wird **nur ein Hash** des Codes, nie der Klartext.
- Wer den Code eingibt, wird über eine Cloud Function **Admin**. Der bisherige Admin wird normaler Bierwart (ADM-06). Eine Kasse ohne Bierwarte lässt sich bis zur Löschung nach 30 Tagen so reaktivieren (AUTH-10).
- Ein neues Gerät übernimmt eine bestehende Mitgliedschaft über „Das bin ich (neues Gerät)“ beim Beitritt (AUTH-07, UC-03). Die Übernahme macht eine Cloud Function: Sie überträgt Mitgliedschaft und Portemonnaie auf die neue UID.

## Alternativen

- **E-Mail/Passwort, Google-Login:** widerspricht der Abgrenzung und NFA-08.
- **Anonyme Konten später mit Login verknüpfen (Account Linking):** wäre eine spätere Option, falls nötig. Für Release 1 nicht vorgesehen.
- **Wiederherstellungscode im Klartext speichern:** jeder mit Lesezugriff auf die Datenbank (auch ein Admin-SDK-Fehler) könnte Admin werden. Verworfen.

## Konsequenzen

- App-Neuinstallation oder Gerätewechsel erzeugt eine neue UID. Der Weg zurück führt immer über einen Einladungslink plus „Das bin ich“ oder über den Wiederherstellungscode.
- Anonyme Nutzer ohne Kasse sammeln sich in Firebase Auth an. Ein Aufräumen ist zu klären (offene Frage in `architecture.md`).
- Die Übernahme per „Das bin ich“ ist ein Angriffspunkt: Wer den Einladungslink hat, kann sich als jemand anderes ausgeben. Wie das abgesichert wird, ist eine offene Frage in `architecture.md`.
- Alle rechteändernden Aktionen laufen über Cloud Functions und brauchen den Blaze-Tarif.
