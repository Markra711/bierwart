# CLAUDE.md – Bierwart

Strichliste mit Kasse für eine Amateurmannschaft. Flutter (Android zuerst) + Firebase (anonyme Auth, Firestore, Cloud Functions, Hosting). Projekt-ID `bier-wart`, Firestore-Region `europe-west10`.

## Pflichtlektüre

| Datei | Wofür |
| --- | --- |
| `docs/requirements.md` | Anforderungen mit IDs (UC-, AUTH-, ADM-, KAD-, BES-, STR-, GEL-, LOG-, NFA-, UI-) |
| `docs/architecture.md` | Schichten, Datenmodell, Rules, Functions, Einladungslinks, offene Fragen |
| `docs/styleguide.md` + `docs/design/tokens.json` | Design: Tokens, Komponenten, Texte |
| `docs/decisions/` | ADRs; neue Grundsatzentscheidungen bekommen einen neuen ADR |

Externe Quellen (verbindlich, `docs/` spiegelt sie): Anforderungsdokument, Design System, Design-Canvas. Die Links stehen am Kopf der jeweiligen Datei in `docs/`.

## Befehle

```bash
flutter pub get
flutter analyze                       # muss ohne Befund durchlaufen
flutter test                          # alle Dart-Tests
dart format lib test                  # vor jedem Commit
flutter run                           # gegen das echte Projekt
flutter run --dart-define=USE_EMULATORS=true   # gegen lokale Emulatoren (sobald verdrahtet)

# Emulatoren immer mit Demo-Projekt, nie mit echten Daten
firebase emulators:start --project demo-bierwart
```

**Nie ohne ausdrückliche Freigabe:** `firebase deploy` (egal welches Ziel), Änderungen in der Firebase- oder Play-Konsole, `git push`.

## Ordnerstruktur

```
lib/
  main.dart                 Firebase init, ProviderScope
  firebase_options.dart     generiert von FlutterFire, nicht von Hand ändern
  src/
    app.dart                MaterialApp, Theme, Routing
    core/                   theme/, money/, firebase/, routing/, widgets/
    features/<feature>/     domain/ data/ application/ presentation/
test/                       spiegelt lib/src/
docs/                       requirements, architecture, styleguide, decisions/, design/
firestore.rules             Security Rules (Tests gegen Emulator)
firestore.indexes.json
functions/                  Cloud Functions (TypeScript), kommt mit der ersten Function
hosting/public/             assetlinks.json, Fallback-Seite für Einladungslinks (kommt mit AUTH-04)
.github/workflows/ci.yml    analyze + test
```

Features: `onboarding`, `strichliste`, `kader`, `lager`, `geld`, `einstellungen`.

## Konventionen

- **Sprache:** Fachbegriffe im Code auf Deutsch wie in den Anforderungen (`Kasse`, `Mitglied`, `Sorte`, `Buchung`, `Ort`, `Portemonnaie`, `Bierwart`, `Kassenwart`). Technische Begriffe auf Englisch (`Repository`, `Provider`, `Notifier`). UI-Texte auf Deutsch im Kabinen-Ton (siehe Styleguide).
- **Geld:** immer `int` in Cent, Felder mit Suffix `Cents`. Kein `double` für Geld. Formatierung nur über `lib/src/core/money/` (ADR-0002).
- **State:** Riverpod, ohne Code-Generierung (ADR-0001). Widgets lesen nur Provider, nie Firestore direkt.
- **Schichten:** `domain/` importiert weder Flutter noch Firebase. Collection- und Feldnamen nur in `data/`.
- **Design:** nur Tokens aus `lib/src/core/theme/` verwenden, keine Hex-Werte oder freien Abstände in Widgets. Ändert sich `tokens.json`, `tokens.dart` nachziehen; `test/core/theme/tokens_test.dart` prüft das.
- **Firestore:** Buchungen sind unveränderlich, Korrekturen sind Gegenbuchungen (LOG-02). Rechte gehören in Rules oder Functions, nie nur in die UI (NFA-07).
- **Lints:** `flutter_lints`. Keine `// ignore` ohne Begründung im selben Kommentar.
- **Branches:** `feat/…`, `fix/…`, `docs/…`, `chore/…`. Nie direkt auf `main`.
- **Commits:** Conventional Commits auf Deutsch, z. B. `feat(strichliste): Strich per Tipp buchen (STR-02, STR-04)`. Jeder Commit, der eine Anforderung umsetzt oder ändert, nennt ihre IDs.

## Definition of Done

Eine Änderung ist fertig, wenn:

1. `flutter analyze` ohne Befund und `flutter test` grün ist (lokal und in CI).
2. Neue Logik Tests hat: Domain mit Unit-Tests, Bildschirme mit Widget-Tests, Rules mit Emulator-Tests.
3. Die **Doku im selben Commit** angepasst ist: `requirements.md` (falls sich eine Anforderung ändert), `architecture.md` (Datenmodell, Rules, Functions), `styleguide.md`, ggf. ein neuer ADR.
4. Die **Commit-Nachricht die Anforderungs-IDs** nennt.
5. UI-Texte, Beträge und Design dem Styleguide entsprechen (Beträge `1,50 €`, Tabellenziffern, Tokens).
6. Fehlerfälle sichtbar sind: kein endloses Laden, jede fehlgeschlagene Schreibung meldet sich (NFA-10).
7. Nichts deployt und nichts gepusht wurde ohne Freigabe.
