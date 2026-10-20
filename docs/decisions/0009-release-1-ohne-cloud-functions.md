# ADR-0009: Release 1 ohne Cloud Functions

- **Status:** Angenommen
- **Datum:** 2026-10-21
- **Ersetzt:** [ADR-0007](0007-aggregation-per-trigger.md)
- **Ändert die Umsetzung von:** [ADR-0003](0003-anonyme-auth-wiederherstellungscode.md), [ADR-0008](0008-uebernahme-bestaetigung.md) (die Entscheidungen selbst bleiben)
- **Anforderungen:** NFA-02, NFA-03, NFA-07, NFA-12, AUTH-08, AUTH-10, AUTH-11, ADM-05, ADM-06, BES-02, BES-04, LOG-02

## Kontext

Der erste Architektur-Entwurf hat Cloud Functions für fast alles eingeplant: für jede Verwaltungsaktion (Callables), für das Verarbeiten jeder Buchung (ADR-0007) und für das automatische Löschen. Damit braucht schon Release 1 den Blaze-Tarif, eine zweite Sprache (TypeScript) und die Buchungslogik doppelt.

Marvin möchte Release 1 ohne Cloud Functions bauen, nur mit Firestore, Security Rules, Auth und Hosting.

Ein Prototyp mit Emulator-Tests (Branch `spike/rules-buchungen`, 27 Tests) hat gezeigt, dass Buchen ohne Functions geht:

- Strich, Zahlung und Einkauf lassen sich als Batch aus Buchung und Summen schreiben und von den Rules vollständig prüfen.
- Ein Einkauf mit **bis zu 12 Sorten** geht, ab 13 greift das Limit der Dokumentzugriffe pro Request.

## Entscheidung

**Release 1 kommt ohne Cloud Functions und ohne Blaze-Tarif aus.** Alle Rechte setzen die Security Rules durch (NFA-07).

1. **Buchen = ein Batch aus Buchung und Summen.**
   - Die App schreibt die Buchung und ändert im selben Batch Saldo, Bestand und Ortsstand mit `FieldValue.increment()`.
   - Jedes geänderte Summen-Dokument bekommt `letzteBuchungId`.
   - Die Rules prüfen in beide Richtungen:
     - Die Buchung hat den Zeitstempel dieses Requests (`stempel.am == request.time`), ist also neu.
     - Die Änderung jeder Summe entspricht genau der Wirkung der Buchung.
     - Jede Summe, die die Buchung betrifft, verweist im selben Batch auf sie.
   - Weil `increment()` auf dem Server addiert, gehen gleichzeitige Buchungen nicht verloren (NFA-03). Offline gebuchte Batches werden beim Sync in Reihenfolge übertragen (NFA-02).
2. **Einkauf höchstens 10 Sorten pro Buchung.** Die Grenze liegt unter den gemessenen 12, als Sicherheitsabstand. Bei mehr Sorten teilt die App den Einkauf in mehrere Buchungen.
3. **Preis zum Buchungszeitpunkt (BES-02):** Die Sorte führt `preisCents` und `vorherigerPreisCents`. Die Rules akzeptieren beide. Ein offline gebuchter Strich wird dadurch nach einer Preisänderung nicht abgelehnt.
4. **Absolute Buchungen** (Bestandskorrektur BES-06, Kassensturz GEL-06):
   - Die App setzt den gezählten Wert und schreibt die Differenz zum Stand, den sie gerade sieht, in die Buchung.
   - Die Rules prüfen beides gegen den Stand auf dem Server.
   - Hat sich der Stand zwischendurch geändert, wird die Buchung abgelehnt, und die App fordert zum erneuten Zählen auf.
5. **Verwaltung ohne Callables:** Kasse erstellen, beitreten, Übernahme (ADR-0008), Rollen, Link erneuern, Bierwart entfernen, austreten und Admin wiederherstellen sind Batches der App. Die Rules prüfen sie, Einladungscode und Ablauf eingeschlossen (AUTH-08).
6. **Wiederherstellungscode** (ADR-0003, ADM-06):
   - Die App erzeugt den Code, gespeichert wird nur sein SHA-256-Hash.
   - Wer wiederherstellt, sendet den Code. Die Rules vergleichen mit `hashing.sha256()`.
   - Im selben Batch wird ein **neuer Code** gesetzt. Der gesendete alte Code ist danach wertlos und darf im Dokument stehen bleiben.
7. **Auflösen** (ADM-05):
   - Der Admin markiert die Kasse als aufgelöst. Danach haben andere keinen Zugriff mehr.
   - Seine App löscht alle Dokumente seitenweise. Dafür erlauben die Rules ausnahmsweise das Löschen von Buchungen (LOG-02).
   - Bricht das Löschen ab, setzt die App es beim nächsten Start fort.
8. **Automatisches Löschen (AUTH-10, AUTH-11) kommt in Release 2** mit der ersten Cloud Function. Release 1 pflegt dafür nur `kassen.leerSeit`.

## Alternativen

- **Functions wie geplant** (ADR-0007): Die Rules wären einfacher und die Logik zentral. Dafür bräuchte es Blaze ab Tag 1, TypeScript und die Buchungslogik in zwei Sprachen. Für Release 1 verworfen.
- **Summen in der App aus allen Buchungen berechnen:** Dafür bräuchte es keine Summen-Dokumente. Aber jede App liest bei Kaltstart das ganze Log, und das sprengt das Lesekontingent (NFA-12).
- **TTL-Löschung für AUTH-10/AUTH-11:** TTL löscht keine Untersammlungen und kann „keine Buchung seit 12 Monaten“ nicht ausdrücken. Verworfen.

## Konsequenzen

- **Die Rules sind die Geschäftslogik.** Jede Buchungsart und jede Verwaltungsaktion braucht Emulator-Tests mit erlaubten und verbotenen Fällen. Die Rules-Tests (`rules-tests/`) gehören in die CI.
- Die Buchungswirkung gibt es weiter zweimal: in Dart, das die Batches baut, und in den Rules, die sie prüfen. Die Rules-Tests decken jede Wirkung ab.
- Release 1 braucht keinen Blaze-Tarif. Blaze, Functions-Region (`europe-west10`) und die Sprache der Functions werden erst mit Release 2 wieder aktuell.
- **Änderungen an den Anforderungen:**
  - AUTH-10 und AUTH-11 rücken in Release 2.
  - Bei ADM-05 entfällt „serverseitige Löschung“: Die App des Admins löscht.
- **Ohne Server-Code gibt es keine Bremse gegen Durchprobieren** von Einladungs- und Wiederherstellungscodes. Beide müssen deshalb genug Zufall enthalten: mindestens 80 Bit beim Wiederherstellungscode. App Check bleibt offene Frage 13.
- **Grenze der Messung:** Das Limit von 12 Sorten stammt aus dem Emulator. Ob die Produktion genauso zählt, wird vor dem Release mit einem echten Projekt geprüft.
- **Noch nicht im Prototyp getestet** und deshalb Pflicht, bevor die echten Rules auf `main` kommen:
  - Strich bar, Storno, Übergabe, Ein-/Auszahlung, Kassensturz, Bestandskorrektur
  - Stammdaten, Beitritt, Übernahme, Rollen, Wiederherstellung, Auflösen
  - der vorherige Preis
