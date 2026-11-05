# Store-Eintrag (Google Play)

Inhalte für die Play Console unter „Store-Präsenz → Hauptstore-Eintrag“. Die Texte folgen dem Kabinen-Ton aus dem [Styleguide](../styleguide.md): kurz, deutsch, keine Ausrufezeichen. Ändert sich die App, werden Texte und Screenshots hier mitgezogen.

## Grafiken

| Datei | Play Console | Vorgabe von Play |
| --- | --- | --- |
| `icon-512.png` | App-Symbol | 512 × 512, PNG mit Alphakanal; Play rundet die Ecken selbst |
| `feature-grafik.png` | Vorstellungsgrafik | 1024 × 500, PNG ohne Alphakanal |
| `screenshots/01-strichliste.png` … `06-verlauf.png` | Screenshots für Smartphones | 1080 × 1920, mindestens 2, höchstens 8 |

Neu erzeugen:

```bash
python3 tool/store_grafiken.py                          # Icon, Feature-Grafik, Launcher-PNGs (Inkscape, ImageMagick)
SCREENSHOTS_AKTUALISIEREN=1 flutter test test/store     # Screenshots mit Demo-Daten
```

- **Icon:** ein Fünferstrich im Akzentverlauf auf `bg`, wie das Tab-Icon „Striche“. Quelle `icon.svg` (adaptives Icon, Raster 108) und `icon-play.svg` (dasselbe Motiv ohne sichere Zone). In der App liegt es als Vektor in `android/app/src/main/res/drawable/ic_launcher_foreground.xml`, dazu eine einfarbige Ebene für Themen-Icons ab Android 13.
- **Feature-Grafik:** das Cover aus dem Design System im Format 1024 × 500.
- **Screenshots:** gerendert von `test/store/screenshots_test.dart` mit der erfundenen Mannschaft „SV Grünwiese“. Keine echten Namen.

## Texte

**App-Name** (höchstens 30 Zeichen):

> Bierwart – Strichliste & Kasse

**Kurzbeschreibung** (höchstens 80 Zeichen):

> Striche, Kasse und Getränkelager für eure Mannschaft. Ein Tipp, ein Strich.

**Vollständige Beschreibung** (höchstens 4.000 Zeichen):

> Bierwart ist die Strichliste mit Kasse für eure Mannschaft. Schluss mit dem Zettel an der Kühlschranktür: Wer was getrunken hat, was offen ist und wie viel in der Kasse liegt, steht auf jedem Handy der Bierwarte.
>
> STRICHE IN EINEM TIPP
> Sorte wählen, Namen antippen, fertig. Tippen bucht offen, Halten bucht bar. Daneben gibt es „Gäste“ für alle, die nicht im Kader stehen. Vertippt? „Rückgängig“ nimmt den Strich wieder weg.
>
> KADER UND OFFENE BETRÄGE
> Jedes Mitglied hat seinen offenen Betrag. Zahlungen in beliebiger Höhe werden verrechnet, zu viel Gezahltes bleibt als Guthaben stehen. Im Mitglied-Detail steht jeder Strich und jede Zahlung.
>
> GETRÄNKELAGER
> Sorten mit Preis, Bestand in Flaschen, Einkauf mit +6, +20, +24. Wenn eine Sorte leer ist, sieht man es sofort.
>
> GELD IM BLICK
> Kasse, die Portemonnaies der Bierwarte und das Vermögen der Mannschaft. Der Kassenwart bucht Übergaben, Ein- und Auszahlungen mit Grund und den Kassensturz. Jede Buchung landet im Verlauf. Korrigiert wird nur per Gegenbuchung, gelöscht wird nichts.
>
> FÜR MEHRERE BIERWARTE
> Einer erstellt die Kasse, die anderen kommen per Einladungslink dazu. Alle buchen gleichzeitig, auch ohne Netz in der Kabine. Sobald wieder Empfang da ist, gleicht die App ab.
>
> OHNE KONTO UND OHNE E-MAIL
> Anmelden musst du dich nicht, ein Name reicht. Gespeichert werden nur Namen, Beträge und Zeitpunkte, bei Google Firebase in Deutschland. Werbung gibt es nicht.

**Versionshinweise für den geschlossenen Test** (höchstens 500 Zeichen):

> Erste Testversion für die Mannschaft. Bucht ruhig echt. Wenn etwas hakt, schreibt an bierwart.app@gmail.com.

## Einstellungen in der Play Console

| Feld | Wert |
| --- | --- |
| App oder Spiel | App |
| Kostenlos oder kostenpflichtig | Kostenlos |
| Kategorie | Sport (Vorschlag; Alternative: Finanzen) |
| Tags | Sport, Finanzen |
| E-Mail-Adresse | `bierwart.app@gmail.com` |
| Website | `https://bier-wart.web.app` |
| Datenschutzerklärung | `https://bier-wart.web.app/datenschutz` (eingetragen) |
| Werbung | Nein |
| Zielgruppe | 18 Jahre und älter, weil es um Bier geht. Damit fällt die App nicht unter die Familienrichtlinien. |
| Einstufung (IARC-Fragebogen) | Kategorie „Alle anderen App-Typen“. Bezug auf Alkohol: ja (Getränkenamen, Strichliste). Nutzer interagieren: ja, Namen sind für die Mitglieder einer Kasse sichtbar. Kein Kauf von Waren, kein Glücksspiel. |
