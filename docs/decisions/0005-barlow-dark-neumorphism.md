# ADR-0005: Barlow + Dark Neumorphism

- **Status:** Angenommen
- **Datum:** 2026-10-20
- **Anforderungen:** NFA-11, UI-02, UI-05; Abschnitt „Design“ in `requirements.md`

## Kontext

Gebucht wird in der Kabine, oft abends, mit einer Hand und bei wenig Licht. Die App muss schnell lesbar sein, Beträge müssen untereinander stehen, und die Hauptaktion muss sofort auffallen. Das [Bierwart Design System](https://claude.ai/artifact/MdRHobZdVde6Xi7uVTDMPM) legt den Stil verbindlich fest. Im Design-Canvas wurden Schriftvarianten verglichen, gewählt wurde Variante B.

## Entscheidung

- **Stil: Dark Neumorphism.** Ein einziger dunkler Grund (`bg`), Tiefe nur über erhabene und eingedrückte Doppelschatten. Erhaben heißt antippbar, eingedrückt heißt gewählt oder Anzeige.
- **Akzent: ein Verlauf** Pink → Orange (`grad-accent`), nur für Hauptaktion, Auswahl, den großen Betrag und den aktiven Tab.
- **Schrift: Barlow Condensed** für Titel und Beträge (Tabellenziffern), **Barlow** für Text. Beide über das Paket `google_fonts`.
- **Release 1 nur dunkel.**
- Das Flutter-Theme wird aus `tokens.json` abgeleitet (Kopie in `docs/design/tokens.json`). Widgets nutzen nur Tokens.

## Alternativen

- **Material 3 Standard:** schnell umgesetzt, aber generisch. Erhaben/eingedrückt als Bedeutungsträger fehlt.
- **Helles Theme:** blendet abends in der Kabine.
- **Andere Schriftpaare** wurden im Schriftvergleich des Canvas geprüft und verworfen.

## Konsequenzen

- Neumorphism hat schwache Kontraste an Kanten. Lesbarkeit muss über Textkontrast kommen (Tokens sind auf ≥ 4,5:1 geprüft, `ink-faint` nur für Deko).
- Flutter kann innere Schatten (`inset`) nicht nativ. Wir brauchen einen eigenen Painter oder ein Paket (offene Frage in `architecture.md`).
- `google_fonts` lädt Schriften zur Laufzeit. Weil offline gebucht wird (NFA-02), sollten die Schriften als Assets mitgeliefert werden (offene Frage in `architecture.md`).
- Viele Schatten pro Bildschirm kosten Renderzeit. Die Strichliste muss trotzdem flüssig bleiben (NFA-06).
