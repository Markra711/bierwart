# Bierwart – Styleguide

> Abgeleitet aus dem [Bierwart Design System](https://claude.ai/artifact/MdRHobZdVde6Xi7uVTDMPM) (Brand Book, Tokens, Kernkomponenten), Stand 2026-10-19.
> Alle Werte stehen maschinenlesbar in [`design/tokens.json`](design/tokens.json), einer unveränderten Kopie der `tokens.json` aus dem Design System.
> Die Bildschirme liegen klickbar im [Design-Canvas](https://claude.ai/artifact/PNLXqS6vuCMe2gmbqYQdnf).

**Quelle der Wahrheit:** das Design System. Ändert sich dort etwas, wird `design/tokens.json` neu kopiert und `lib/src/core/theme/tokens.dart` nachgezogen. Ein Test (`test/core/theme/tokens_test.dart`) bricht, wenn beide auseinanderlaufen.

Bierwart ist die Strichliste mit Kasse für eine Amateurmannschaft. Gebucht wird in der Kabine, oft abends und mit einer Hand. Das Design ist deshalb dunkel und weich. Laut ist es nur an einer Stelle: dem Verlauf von Pink nach Orange.

Drei Bausteine tragen den Look:

1. **Dark Neumorphism.** Alles liegt auf einem einzigen dunklen Grund (`bg`). Elemente heben sich durch zwei Schatten heraus (`raised`) oder sind eingedrückt (`inset`), nie durch eine andere Flächenfarbe.
2. **Ein Verlauf als Akzent** (`grad-accent`, von `grad-start` zu `grad-end`). Er markiert, was zählt: die Hauptaktion, die aktuelle Auswahl, den einen großen Betrag.
3. **Wireframe-Details.** Outline-Ziffern, Anfasser an der Auswahl, schraffierte Kreise, gestrichelte Linien. Sie erinnern an eine Skizze am Whiteboard und bleiben immer leise.

Warum dieser Stil: [ADR-0005](decisions/0005-barlow-dark-neumorphism.md).

## Inhaltliche Grundsätze

- **Deutsch, Kabinen-Ton, kurz.** „Strich wieder weg“, „Erst abrechnen – 4,50 € sind noch offen“. Keine Ausrufezeichen, keine Entschuldigungen.
- **Buttons sagen, was passiert:** „12,00 € verbuchen“, „Kassensturz buchen“, nicht „OK“.
- **Beträge immer mit Komma und €:** `1,50 €`, Tausender mit Punkt: `1.481,90 €`. Minus als echtes Minuszeichen `−` (U+2212). Siehe NFA-11.
- **Namen in voller Länge** (Vor- und Nachname). Wird es eng, kürzt die Kachel mit „…“, nie das Datenmodell.

## Farbe

Release 1 kennt nur das dunkle Theme.

| Token | Wert | Verwendung |
| --- | --- | --- |
| `bg` | `#25272c` | Einziger Grund der App, auch Fläche aller erhabenen und eingedrückten Elemente |
| `shadow-dark` | `#18191d` | Dunkler Schatten (nur in Schatten) |
| `shadow-light` | `#32353b` | Heller Schatten (nur in Schatten) |
| `surface-float` | `#2c2f35` | Nur Snackbar und Bottom-Sheet |
| `ink` | `#f1eee9` | Haupttext, Beträge, Namen (13,9:1 auf `bg`) |
| `ink-muted` | `#a3a09b` | Sekundärtext, Labels, inaktive Tabs (6,4:1) |
| `ink-faint` | `#6e7179` | Nur „—“ bei Saldo 0 und Deko, kein Fließtext (3,3:1) |
| `line` | `#3a3d44` | Outline-Ziffern, Trennlinie über der Tab-Leiste |
| `line-strong` | `#5a5d64` | Gestrichelte Rahmen (Gäste-Kachel), hohle Deko-Kreise, Badge-Rahmen |
| `grad-start` | `#ff4d86` | Start des Akzentverlaufs, nie allein als Fläche |
| `grad-end` | `#ffa24a` | Ende des Akzentverlaufs; allein erlaubt für Links und Fokusringe |
| `on-accent` | `#1e1f23` | Text und Icons auf dem Verlauf |
| `positive` | `#7cd39a` | Guthaben und Plus-Beträge (9,1:1) |
| `negative` | `#ff6f8f` | Probleme: leerer Bestand, Portemonnaie im Minus, Kassendifferenz (5,9:1), immer mit Wort oder Zeichen |
| `handle` | `#f1eee9` | Die vier Anfasser der Auswahlbox |

| Rolle | Token | Regel |
| --- | --- | --- |
| Grund | `bg` | Die einzige Flächenfarbe für Seite, Kacheln und Karten |
| Schwebend | `surface-float` | Nur Snackbar und Bottom-Sheet |
| Text | `ink`, `ink-muted` | `ink` für alles Wichtige, `ink-muted` für Labels und Zweitzeilen |
| Deko | `ink-faint`, `line`, `line-strong` | Platzhalter, Outline-Ziffern, gestrichelte Rahmen; nie für lesbaren Text |
| Akzent | `grad-accent` | Hauptaktion, Auswahl, der große Betrag, aktiver Tab |
| Bedeutung | `positive`, `negative` | Guthaben und Probleme, immer zusammen mit Text („Guthaben“, „leer“, „−“) |

**Was der Verlauf nicht ist:** keine Warnfarbe. Offene Beträge sind normal und stehen in `ink`. Probleme bekommen `negative`, Guthaben `positive`. Pro Bildschirm gibt es höchstens eine große Verlaufsfläche (meist der Primärbutton) plus kleine Akzente.

**Verlauf:** `grad-accent` = `linear-gradient(100deg, #ff4d86, #ffa24a)`.

## Typografie

- **Barlow Condensed** (`display`) für Titel, Beträge und Outline-Ziffern. Titel immer in Großbuchstaben.
- **Barlow** (`body`) für alles andere.
- **Beträge immer mit Tabellenziffern** (`FontFeature.tabularFigures()`), damit sie untereinander stehen und beim Buchen nicht springen.
- Beide Schriften stammen von Google Fonts (Lizenz OFL) und liegen als Assets in der App (`assets/fonts/`), nur in den Schnitten aus `tokens.json`. So sieht die App auch beim ersten Start ohne Netz richtig aus. `test/core/theme/schriften_test.dart` prüft, dass jeder Schnitt der Tokens mitgeliefert ist.

| Stil | Familie | Größe / Zeile | Gewicht | Sperrung | Verwendung |
| --- | --- | --- | --- | --- | --- |
| `outline-numeral` | display | 132 / 132 | 300 | – | Outline-Ziffer 01–04 hinter dem Tab-Titel, Füllung transparent, Kontur 1px `line` |
| `screen-title` | display | 42 / 42 | 700 | 0,02em | Seitentitel der vier Tabs, Großbuchstaben |
| `page-title` | display | 28 / 32 | 700 | 0,02em | Titel von Unterseiten und Sheets, Großbuchstaben |
| `amount-xl` | display | 52 / 54 | 700 | – | Der eine große Betrag einer Seite, gern mit Verlauf, Tabellenziffern |
| `amount-l` | display | 24 / 28 | 600 | – | Beträge in Listenzeilen, Tabellenziffern |
| `amount-m` | display | 20 / 24 | 600 | – | Beträge in Kacheln der Strichliste, Tabellenziffern |
| `label` | body | 11 / 14 | 700 | 0,14em | Abschnitts- und Feldlabels, Großbuchstaben, `ink-muted` |
| `button` | body | 12 / 16 | 800 | 0,1em | Beschriftung von Pillen-Buttons, Großbuchstaben |
| `name` | body | 14 / 18 | 800 | – | Namen in Listen und Kacheln |
| `body` | body | 14 / 20 | 500 | – | Fließtext, Hinweise |
| `caption` | body | 12 / 17 | 600 | – | Zweite Zeile unter Namen, Metadaten, `ink-muted` |

## Abstände und Radien

| Token | Wert | Verwendung |
| --- | --- | --- |
| `space-1` | 4 | Name zu Unterzeile |
| `space-2` | 8 | Innenabstände in Badges, Icon zu Label |
| `space-3` | 12 | Zwischen Listenzeilen |
| `space-4` | 16 | Zwischen Kacheln; Mindestabstand zwischen erhabenen Elementen |
| `space-5` | 20 | Seitenrand links und rechts |
| `space-6` | 24 | Zwischen Abschnitten, Innenrand von Sheets |

| Token | Wert | Verwendung |
| --- | --- | --- |
| `radius-sm` | 6 | Rollen-Badges |
| `radius-md` | 16 | Sortenkacheln, aktiver Tab |
| `radius-lg` | 18 | Mitgliederkacheln, Listenzeilen, Eingabefelder |
| `radius-xl` | 26 | Große Karten (Kasse), obere Ecken von Sheets |
| `radius-pill` | 999 | Buttons, runde Icon-Buttons |

## Fläche und Tiefe

Jedes Element hat genau eine Lage:

| Lage | Schatten | Bedeutet |
| --- | --- | --- |
| erhaben | `raised`, `raised-sm`, `raised-lg` | antippbar |
| eingedrückt | `inset`, `inset-sm` | gewählt, gerade gebucht, oder reine Anzeige |
| schwebend | `float` + `surface-float` | liegt über dem Inhalt |

| Token | Wert (CSS) | Verwendung |
| --- | --- | --- |
| `raised` | `5px 5px 12px #18191d, -5px -5px 12px #32353b` | Antippbare Kacheln, Listenzeilen, Sekundärbuttons |
| `raised-sm` | `4px 4px 10px …, -4px -4px 10px …` | Sortenkacheln, runde Icon-Buttons |
| `raised-lg` | `7px 7px 16px …, -7px -7px 16px …` | Die eine Hauptkarte einer Seite (Kasse) |
| `inset` | `inset 4px 4px 9px …, inset -4px -4px 9px …` | Anzeigeflächen, Eingabefelder, gerade gebuchte Kachel |
| `inset-sm` | `inset 3px 3px 7px …, inset -3px -3px 7px …` | Gewählte Sorte, aktiver Tab |
| `track` | `inset 2px 2px 4px …, inset -2px -2px 4px …` | Rinne von Bestandsbalken |
| `float` | `6px 6px 14px #18191d, -4px -4px 10px #32353b` | Snackbar |

Zwischen erhabenen Elementen mindestens `space-4` Abstand, sonst verkleben die Schatten. Radien: Kacheln `radius-lg`, Sorten und Tabs `radius-md`, große Karten `radius-xl`, Buttons `radius-pill`.

**Flutter-Hinweis:** `BoxShadow` kennt kein `inset`. Erhabene Schatten werden direkt als `BoxShadow`-Liste umgesetzt. Eingedrückte Schatten zeichnet ein eigener Painter aus den Tokens (`BwEingedrueckt` in `lib/src/core/widgets/flaechen.dart`); die CSS-Unschärfe `blur` entspricht dort einem Sigma von `blur / 2`.

## Wireframe-Details

| Detail | Wo | Wie |
| --- | --- | --- |
| Outline-Ziffer | hinter dem Titel jedes Tabs, 01–04 | Stil `outline-numeral`, Füllung transparent, Kontur 1px `line` |
| Auswahlbox | um die gewählte Getränkesorte | Verlaufsrahmen + vier 6×6-Quadrate in `handle` an den Ecken |
| Schraffur | Ecke von Summen- und Kassenkarten, leere Sorte | feine diagonale Linien, 1px, Abstand 6px |
| Gestrichelte Linie | neben Hinweisen, Abschnittslabels | 4px Strich, 4px Lücke in `line-strong` |
| Deko-Punkte | im Kopf | ein voller Punkt im Verlauf, ein hohler Kreis in `line-strong` |

Wireframe-Details sind Schmuck. Sie dürfen keine Information tragen, die nirgends sonst steht.

## Ikonografie

Linien-Icons, 22px, Strichstärke 1,8, runde Enden. Inaktiv in `ink-muted`, aktiv mit Verlauf als Strichfarbe. Keine Emojis, keine gefüllten Icons.

**App-Icon:** ein Fünferstrich im Verlauf auf `bg`, dasselbe Motiv wie das Tab-Icon „Striche“. Das Design System hat noch kein eigenes Logo; bis dahin ist `docs/store/icon.svg` die Quelle. Der Startbildschirm liegt auf `bg`, im hellen wie im dunklen Systemmodus. Details in [`store/store-eintrag.md`](store/store-eintrag.md).

## Bedienung

- Touch-Ziele mindestens 44px.
- Die Strichliste startet die App (UI-01). Tippen bucht offen, Halten bucht bar (STR-02, STR-03).
- Bestätigungsdialoge nur bei Unumkehrbarem (UI-04). Buchungen bekommen stattdessen „Rückgängig“ in der Snackbar (STR-04), der Knopf heißt genau so, nicht „Zurück“. Sie bleibt bis zur nächsten Buchung, höchstens 8 Sekunden.
- Kassenwart- und Admin-Funktionen sind für andere unsichtbar, nicht ausgegraut (UI-08).

## Komponenten

### Button

Pillen-Buttons in vier Varianten; pro Bildschirm höchstens ein primärer Button.

| Variante | Aussehen | Wofür |
| --- | --- | --- |
| Primär | Fläche `grad-accent`, Text `on-accent` | Die Hauptaktion: „12,00 € verbuchen“, „Einkauf“, „Weiter“ |
| Sekundär | Fläche `bg`, Schatten `raised` | Gleichwertige Nebenaktionen |
| Outline | 1,5px Rahmen in `ink` | Ruhige Aktionen neben einem Primärbutton: „Liste teilen“, „Übergabe“ und „Kassensturz“ im Geld-Tab |
| Icon | runder Button 46px, `raised-sm` | Zahnrad, Schließen, Zurück; braucht ein Semantics-Label |

- Höhe 48px (Icon 46px), Radius `radius-pill`, Text im Stil `button` (Großbuchstaben). Die Hauptaktionen der Onboarding-Seiten sind im Canvas 56px hoch (`BwKnopf(gross: true)`).
- Deaktiviert: ohne Fläche, gestrichelter Rahmen in `line-strong`, Text `ink-muted`.
- Destruktive Aktionen („Austreten“, „Kasse auflösen“) als Outline in `negative`, mit Bestätigung.
- Filter (Verlauf: „Alle Bierwarte ▾“): erhabene Pille `raised-sm`, Text im Stil `name`, Pfeil in `ink-muted`; die Auswahl öffnet ein Sheet.
- Fokusring 2px in `grad-end`, 3px Abstand.

### Card

Flächen für Inhalte; ihre Lage (erhaben oder eingedrückt) sagt, ob man sie antippen kann.

| Art | Lage | Inhalt |
| --- | --- | --- |
| Hauptkarte | `raised-lg`, `radius-xl`, innen ein Verlaufsrahmen | Der eine große Betrag der Seite (`amount-xl` mit Verlauf), dazu eine schraffierte Kreisecke |
| Summenkarte | `inset`, `radius-lg` | Reine Anzeige: „Offen gesamt“, „Guthaben“ |
| Listenzeile | `raised`, `radius-lg`, mind. 60px hoch | Name, Zweitzeile, Betrag rechts (`amount-l`); antippbar |
| Gruppierte Liste | `inset`, Zeilen ohne eigenen Schatten | Portemonnaies, Striche im Mitglied-Detail |
| Kachel | `raised-sm`, `radius-lg`, zwei Spalten | Einstellungen „Kasse & ich“: Text, darunter z. B. „nur Admin“ |
| Bestandsbalken | Rinne `track`, Füllung `grad-accent` | Bestand je Sorte; leere Sorte stattdessen gestrichelt in `negative` mit Schraffur |

Pro Seite gibt es höchstens eine Hauptkarte.

### Sheet

Bottom-Sheet für kurze Aktionen (UI-03): Zahlung erfassen, Ein-/Auszahlung, Übergabe, Kassensturz, Mitglied/Sorte anlegen.

- Fläche `surface-float`, obere Ecken `radius-xl`, Griff 40×4px in `line-strong`, Innenrand `space-6`.
- Scrim Schwarz 60 %; Tippen darauf schließt.
- Titel im Stil `page-title`, der Betrag als großes eingedrücktes Feld im Display-Font mit Tabellenziffern.
- Schnellwahl als erhabene Chips; der gewählte Chip ist eingedrückt mit Text in `grad-end`. In Flutter `BwChip`.
- Umschalter zwischen zwei Möglichkeiten („Einzahlung“/„Auszahlung“, „In die Kasse“/„Aus der Kasse“): eingedrückte Rinne (`radius-pill`), die gewählte Seite mit Fläche `grad-accent` und Text `on-accent`, die andere in `ink-muted` (`BwUmschalter`).
- Zustimmung zu den Nutzungsbedingungen (NFA-13): eine Zeile `caption` in `ink-muted`, zentriert direkt über dem Hauptknopf: „Mit „Kasse erstellen“ stimmst du den Nutzungsbedingungen zu.“ Das Wort „Nutzungsbedingungen“ in `ink`, fett und unterstrichen; ein Tipp öffnet die Seite im Browser (`BwZustimmung`).
- Wahl einer Option mit Text (Ort des Geldes, Bierwart bei der Übergabe): erhabene Karte `radius-md`, gewählt eingedrückt mit Verlaufsrahmen, Betrag rechts (`BwWahlKarte`).
- Kassendifferenz: gestrichelter Rahmen in `negative`, Betrag mit Vorzeichen in `negative`.
- Unten genau ein Primärbutton, dessen Text den Betrag nennt: „12,00 € verbuchen“.
- Weil `surface-float` heller ist als `bg`, nutzen Schatten im Sheet einen eigenen hellen Ton (`#363a41`). Er steht nicht in `tokens.json`; in Flutter liegt er als `BwSheet.schattenHell` in `tokens.dart`, Eingabefelder im Sheet nutzen `BwFeld(aufSheet: true)`.

### TabBar

Feste Leiste unten mit den vier Tabs Striche, Kader, Lager und Geld (UI-02).

- 82px hoch, Trennlinie oben in `line`, sonst Grund `bg`.
- Inaktiv: Icon und Label in `ink-muted`.
- Aktiv: eingedrückt (`inset-sm`, `radius-md`), Icon-Strich und Label mit `grad-accent`.
- Labels in Großbuchstaben, 11px, Sperrung 0,06em; „Strichliste“ heißt in der Leiste kurz „Striche“.
- Unterseiten (Mitglied-Detail, Einkauf, Verlauf, Einstellungen) zeigen keine Tab-Leiste, sondern einen Zurück-Button.

### Tile

Kacheln der Strichliste: oben die Getränkesorten, darunter die Mitglieder, beide im Raster mit drei Spalten und `space-4` Abstand (UI-05, UI-06).

**Sortenkachel** (56px hoch, `radius-md`): Name und Preis. Die gewählte Sorte ist eingedrückt (`inset-sm`), hat einen Verlaufsrahmen und die vier Anfasser der Auswahlbox. Eine leere Sorte zeigt „leer“ in `negative`, bleibt aber wählbar (STR-05). Ab 10 aktiven Sorten wird aus dem Raster eine Liste.

**Mitgliederkachel** (74px hoch, `radius-lg`), vier Zustände:

| Zustand | Aussehen |
| --- | --- |
| normal | erhaben (`raised`), Saldo in `ink` oder „—“ in `ink-faint` |
| Guthaben | Saldo in `positive` mit „+“ |
| gerade gebucht | eingedrückt, Verlaufsrahmen, Saldo mit Verlauf und „+1“, bis die Snackbar verschwindet |
| Gäste | gestrichelter Rahmen in `line-strong`, ohne Schatten, immer letzte Kachel |

Antippen bucht offen, Halten bucht bar. Auf „Gäste“ buchen beide Gesten bar (KAD-03). Namen kürzen mit „…“, Beträge im Stil `amount-m` mit Tabellenziffern.

## Bildschirme im Design-Canvas

| Gruppe | Artboards |
| --- | --- |
| Navigationskarte | Navigationskarte (Release 1) |
| Onboarding | Willkommen, Kasse erstellen, Wiederherstellungscode, Einladen, Link einfügen, Beitreten?, Name wählen |
| Vier Tabs + Einstellungen | Strichliste (Start), Kader, Lager, Geld, Einstellungen |
| Eigene Seiten | Mitglied-Detail, Einkauf, Sorte bearbeiten, Verlauf |
| Sheets | Zahlung erfassen, Ein-/Auszahlung, Übergabe, Kassensturz |
| Schriftvergleich | Variante B gewählt (Barlow Condensed + Barlow) |

Die Artboards sind 390×844 (Phone). Bei Abweichungen zwischen Canvas und diesem Styleguide gilt das Design System; Widersprüche kommen als Frage in die Anforderungsrunde.

## Umsetzung in Flutter

| Datei | Inhalt |
| --- | --- |
| `docs/design/tokens.json` | Kopie der Tokens aus dem Design System |
| `lib/src/core/theme/tokens.dart` | Tokens als Dart-Konstanten (`BwColors`, `BwSpacing`, `BwRadius`, `BwShadows`, `BwGradients`) |
| `lib/src/core/theme/app_theme.dart` | `ThemeData` (dunkel) + `ThemeExtension` `BwTextStyles` für die Token-Stile |
| `lib/src/core/widgets/` | Bausteine: Flächen (`BwErhaben`, `BwEingedrueckt`, Schraffur, Verlaufstext), Knöpfe (`BwKnopf`, `BwIconKnopf`), Eingaben (`BwFeld`, `BwLabel`), Seitengerüst (`BwSeite`, `BwTitel`) |
| `test/core/theme/tokens_test.dart` | Prüft, dass `tokens.dart` und `tokens.json` übereinstimmen |

Widgets nutzen Token-Namen, keine Hex-Werte oder freien Zahlen.
