# Bierwart

Strichliste mit Kasse für eine Amateurmannschaft. Flutter (Android zuerst) mit Firebase.

- Anforderungen: [docs/requirements.md](docs/requirements.md)
- Architektur: [docs/architecture.md](docs/architecture.md)
- Styleguide: [docs/styleguide.md](docs/styleguide.md)
- Entscheidungen: [docs/decisions/](docs/decisions/README.md)
- Arbeitsweise, Befehle, Definition of Done: [CLAUDE.md](CLAUDE.md)

```bash
flutter pub get
flutter analyze
flutter test
firebase emulators:start --project demo-bierwart
```

## App lokal ausprobieren

Mit einem Android-Emulator auf demselben Rechner:

1. Firebase-Emulatoren starten: `firebase emulators:start --project demo-bierwart` (ohne globale Firebase CLI: `npx --prefix rules-tests firebase emulators:start --project demo-bierwart`). Die Oberfläche mit allen Daten liegt unter http://localhost:4000.
2. In einem zweiten Terminal: `flutter run --dart-define=USE_EMULATORS=true`.

Einen Einladungslink öffnest du auf dem Android-Emulator mit `adb shell am start -W -a android.intent.action.VIEW -d "https://bier-wart.web.app/j/<CODE>" io.github.markra711.bierwart`. Die Fallback-Seite für Leute ohne App liegt lokal unter http://localhost:5000/j/<CODE>.

Ohne den Schalter spricht die App mit dem echten Projekt `bier-wart`. Dort sind die Security Rules noch nicht deployt, deshalb wird alles außer der Anmeldung abgelehnt.
