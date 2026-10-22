# Gerätetest vor dem ersten Deploy

Checkliste für einen Durchgang auf dem Android-Emulator gegen die lokalen Firebase-Emulatoren, nie gegen das echte Projekt. Sie deckt Release 1 ab, soweit es gebaut ist (Stand 2026-10-22, `main` 23160a5). „Das bin ich (neues Gerät)“ fehlt noch (offene Frage 23).

Gebraucht werden zwei Bierwarte, also zwei Geräte. Am einfachsten sind zwei virtuelle Android-Geräte (AVDs) gleichzeitig: **A** (Gründer) und **B**.

## 0. Vorbereitung

- [ ] `firebase emulators:start --project demo-bierwart`, Oberfläche unter http://localhost:4000 offen lassen, um die Daten mitzulesen.
- [ ] Beide AVDs starten, Seriennummern mit `adb devices` notieren.
- [ ] Auf jedem Gerät: `flutter run -d <serial> --dart-define=USE_EMULATORS=true`

## 1. Kasse erstellen (A)

- [ ] „Kasse erstellen“ mit Name, eigenem Namen und Startbetrag, z. B. 50 € (UC-01).
- [ ] Der Wiederherstellungscode erscheint mit „Nur jetzt sichtbar“. **Code notieren**, er wird in Schritt 10 gebraucht. „Weiter“ geht erst nach dem Haken (AUTH-03).
- [ ] Die Seite „Einladen“ zeigt den Link, danach kommt die Strichliste.

## 2. Beitreten (B)

- [ ] Den Code aus dem Link von A holen (Einstellungen → Einladungslink) und auf B öffnen:
  `adb -s <serial-B> shell am start -W -a android.intent.action.VIEW -d "https://bier-wart.web.app/j/<CODE>" io.github.markra711.bierwart`
- [ ] B sieht „Kasse beitreten?“ mit Kassenname und Anzahl der Bierwarte (AUTH-05).
- [ ] Einmal den Namen von A eingeben, das muss abgelehnt werden (AUTH-07). Dann einen eigenen Namen nehmen.
- [ ] In den Einstellungen von A erscheint B in der Liste der Bierwarte, ohne Neuladen.

## 3. Lager

- [ ] A legt zwei Sorten an, z. B. Bier zu 1,50 € und Cola zu 1,20 € (BES-01).
- [ ] A kauft ein und wählt dabei „Kasse“. B kauft ein und sieht keine Wahl, es geht aus dem eigenen Portemonnaie (BES-05, UI-08).
- [ ] Den Bestand korrigieren (BES-06). Ein Gerät im Flugmodus muss „Zum Zählen brauchst du Netz.“ zeigen.
- [ ] Eine Sorte ausblenden: Sie verschwindet von der Strichliste und lässt sich wieder einblenden.

## 4. Strichliste

- [ ] Antippen bucht offen, Halten bucht bar. „Rückgängig“ in der Snackbar nimmt die Buchung zurück (STR-02 bis STR-04).
- [ ] Auf „Gäste“ wird immer bar gebucht (KAD-03).
- [ ] Ein Strich von A erscheint auf B sofort.

## 5. Kader und Mitglied-Detail

- [ ] Ein Mitglied ohne App anlegen und Striche darauf buchen (KAD-01).
- [ ] Im Detail eine Zahlung erfassen, mehr als offen ist. Der Rest muss als Guthaben erscheinen (GEL-02).
- [ ] Einen Strich stornieren. Der offene Betrag und der Bestand müssen wieder stimmen (STR-06).
- [ ] Zahlung stornieren: A zahlt in die Kasse ein. B versucht, das zu stornieren, und bekommt den Hinweis, dass nur der Kassenwart das kann. A storniert, mit Rückfrage (STR-06).
- [ ] Umbenennen, auch nur in der Schreibweise („tim“ → „Tim“, UI-09).
- [ ] Entfernen geht erst bei 0 € (KAD-04). Den entfernten Namen neu anlegen, dann muss „Wieder aufnehmen“ erscheinen (KAD-08).

## 6. Geld

- [ ] Vermögen, Kasse und Portemonnaies stimmen mit den Buchungen bisher überein (GEL-07).
- [ ] Ein- und Auszahlung mit Grund. B sieht keine Wahl der Kasse (GEL-05).
- [ ] B sieht weder „Übergabe“ noch „Kassensturz“. A gleicht mit „Übergabe“ das Portemonnaie von B aus (GEL-04).
- [ ] Kassensturz mit krummem Betrag: Die Differenz erscheint rot, danach steht unter der Kasse „Kassensturz am …“ (GEL-06).
- [ ] Verlauf: Gruppierung nach Tagen, Filter nach Bierwart und nach Mitglied, „Ältere laden“ (LOG-03).

## 7. Offline

- [ ] B in den Flugmodus, Striche buchen, wieder online. Die Striche müssen auf A ankommen (NFA-02).
- [ ] Kassensturz im Flugmodus: Es muss eine Meldung kommen, kein endloses Laden (NFA-10).

## 8. Einstellungen

- [ ] „Teilen“ öffnet das Teilen-Menü (UC-06). „Erneuern“ macht den alten Link ungültig. Ein Beitritt mit dem alten Link muss die Meldung „ersetzt“ zeigen (ADM-01).
- [ ] B zum Kassenwart machen: B sieht danach „Übergabe“ und „Kassensturz“ (ADM-03). Die Rolle anschließend zurück an A geben.
- [ ] Die Kasse umbenennen (ADM-04) und den eigenen Namen ändern.
- [ ] Datenschutz öffnen und den Text lesen (NFA-09, offene Frage 18).

## 9. Austreten und Entfernen

- [ ] B hat Geld im Portemonnaie und tippt auf „Austreten“: Es kommt ein Hinweis, B tritt nicht aus (AUTH-09).
- [ ] A versucht auszutreten: Als Admin kommt der Hinweis „Übergib erst die Admin-Rolle.“
- [ ] A entfernt B: B landet im Onboarding, das Portemonnaie von B steht bei A als „ehemalig“ (ADM-02, GEL-08).

## 10. Wiederherstellung (B ist jetzt ohne Kasse)

- [ ] Auf B „Ich habe einen Wiederherstellungscode“ wählen und den Code aus Schritt 1 eingeben (ADR-0010).
- [ ] „Wer bist du?“ zeigt die Mitglieder, A steht als Admin zuerst. B wählt A.
- [ ] „Admin werden“: B sieht den neuen Code genau einmal und landet dann in der Kasse. A landet im Onboarding (ADM-06, UC-03).

## 11. Zum Schluss: Auflösen

- [ ] Der Admin (jetzt B) wählt „Kasse auflösen“ und tippt den Namen ab. Ein Tippfehler muss den Knopf gesperrt lassen (ADM-05).
- [ ] Auf der Seite zum Löschen den Emulator kurz stoppen und wieder starten: Es kommt eine Meldung und „Weiter löschen“.
- [ ] Am Ende ist die Kasse in der Emulator-Oberfläche weg, und B ist im Onboarding.

## Wenn etwas hakt

Den Schritt notieren, was zu sehen war, und wenn möglich einen Screenshot. Bei Ablehnungen zeigt `firestore-debug.log` im Projektordner, welche Rule abgelehnt hat.
