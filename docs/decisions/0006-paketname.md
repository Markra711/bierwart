# ADR-0006: Paketname `io.github.markra711.bierwart`

- **Status:** Angenommen
- **Datum:** 2026-10-20
- **Anforderungen:** NFA-01, AUTH-04, AUTH-12

## Kontext

Das Flutter-Template hat `com.example.bier_wart` als `applicationId` angelegt. Die Play Console lehnt Paketnamen mit `com.example` ab. Nach dem ersten Upload lässt sich der Paketname nie mehr ändern. Firebase (`google-services.json`), die App Links (`assetlinks.json`) und der Play Install Referrer hängen alle an ihm.

## Entscheidung

`applicationId` und `namespace` sind `io.github.markra711.bierwart`. Der Name folgt dem GitHub-Konto des Projekts, eine eigene Domain ist nicht nötig.

## Alternativen

- **Eigene Domain (`de.…`):** gibt es nicht und wäre nur für den Namen nötig.
- **`com.example.bier_wart` behalten:** im Play Store nicht möglich.

## Konsequenzen

- In Firebase muss eine Android-App mit diesem Paketnamen registriert werden. Die neue `google-services.json` und eine neu erzeugte `firebase_options.dart` gehören ins Repo. Bis dahin baut die Android-App nicht, weil das Google-Services-Plugin keinen passenden Client findet.
- `assetlinks.json` (AUTH-04) nennt diesen Paketnamen.
- Die iOS-Bundle-ID (`com.example.bierWart` in `firebase_options.dart`) wird in Release 3 (AUTH-13) separat festgelegt.
