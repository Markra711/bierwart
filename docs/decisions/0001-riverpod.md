# ADR-0001: Riverpod für State-Management und Abhängigkeiten

- **Status:** Angenommen
- **Datum:** 2026-10-20
- **Anforderungen:** NFA-02, NFA-05, NFA-06, NFA-10

## Kontext

Fast jeder Bildschirm zeigt Live-Daten aus Firestore: Salden, Bestand, Portemonnaies, Log. Mehrere Bierwarte buchen gleichzeitig, und Änderungen sollen in unter 3 Sekunden überall erscheinen (NFA-05). Lade- und Fehlerzustände müssen überall sichtbar sein, kein Bildschirm darf endlos laden (NFA-10). Repositories für Firestore und Cloud Functions müssen sich in Tests durch Fakes ersetzen lassen.

## Entscheidung

Wir nutzen **Riverpod** (`flutter_riverpod`) für State-Management und Dependency Injection.

- Firestore-Streams kommen als `StreamProvider`. Aktionen laufen über `Notifier`/`AsyncNotifier`. Lade- und Fehlerzustände sind über `AsyncValue` einheitlich.
- Repositories und Services sind Provider. Tests überschreiben sie mit `ProviderScope(overrides: …)` oder `ProviderContainer`.
- Wir starten **ohne Code-Generierung** (`riverpod_generator`), damit kein `build_runner` nötig ist. Wird die Zahl der Provider unübersichtlich, entscheidet ein neuer ADR über Code-Generierung.
- Widgets lesen nur Provider. Firestore wird nie direkt im Widget angesprochen.

## Alternativen

- **Bloc/Cubit:** gut testbar, aber mehr Boilerplate pro Stream. Für eine kleine App mit vielen Live-Listen lohnt sich das nicht.
- **Provider:** Vorgänger von Riverpod. Er hängt am Widget-Baum, und `AsyncValue` fehlt.
- **setState + StreamBuilder:** wird bei geteiltem Zustand (gewählte Sorte, aktuelle Kasse, Rollen) schnell unübersichtlich und lässt sich schlecht testen.

## Konsequenzen

- Einheitliches Muster für Laden/Fehler/Daten auf allen Bildschirmen.
- Domain- und Datenschicht bleiben ohne Flutter testbar.
- Alle Entwickler müssen die Riverpod-Lebenszyklen kennen (`autoDispose`, `ref.watch` vs. `ref.read`).
