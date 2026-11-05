import 'dart:async';

import 'package:bier_wart/src/app.dart';
import 'package:bier_wart/src/core/firebase/batch_schreiber.dart';
import 'package:bier_wart/src/core/links/link_oeffner.dart';
import 'package:bier_wart/src/core/speicher/lokaler_speicher.dart';
import 'package:bier_wart/src/core/theme/app_theme.dart';
import 'package:bier_wart/src/features/einstellungen/data/einstellungen_repository.dart';
import 'package:bier_wart/src/features/geld/data/log_repository.dart';
import 'package:bier_wart/src/features/geld/data/orte_repository.dart';
import 'package:bier_wart/src/features/kader/data/mitglieder_repository.dart';
import 'package:bier_wart/src/features/kader/data/verlauf_repository.dart';
import 'package:bier_wart/src/features/lager/data/sorten_repository.dart';
import 'package:bier_wart/src/features/onboarding/data/anmeldung_repository.dart';
import 'package:bier_wart/src/features/onboarding/data/einladungslinks.dart';
import 'package:bier_wart/src/features/onboarding/data/kasse_repository.dart';
import 'package:bier_wart/src/features/onboarding/data/uebernahme_repository.dart';
import 'package:bier_wart/src/features/onboarding/data/wiederherstellung_repository.dart';
import 'package:bier_wart/src/features/kader/domain/name.dart';
import 'package:bier_wart/src/features/onboarding/domain/einladung.dart';
import 'package:bier_wart/src/features/onboarding/domain/erstellte_kasse.dart';
import 'package:bier_wart/src/features/strichliste/data/kassenkopf_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'datenbank.dart';
import 'links.dart';

/// Merkt sich geöffnete Links; [geht] = false wie ohne Browser/Mail-App.
class FakeLinkOeffner implements LinkOeffner {
  final geoeffnet = <Uri>[];
  var geht = true;

  @override
  Future<bool> oeffnen(Uri ziel) async {
    geoeffnet.add(ziel);
    return geht;
  }
}

/// Zählt, wie oft die App das Konto löscht (AUTH-15).
class FakeKonto implements KontoRepository {
  var geloescht = 0;

  @override
  Future<void> loeschen() async => geloescht++;
}

/// Ersetzt Firestore beim Erstellen und Beitreten. Nach Erfolg meldet es die
/// Kasse über [kasseIds], wie es `users/{uid}` täte.
class FakeKasseRepository implements KasseRepository {
  FakeKasseRepository(this.kasseIds);

  final StreamController<String?> kasseIds;
  final aufrufe = <ErstellteKasse>[];
  Object? fehler;
  Completer<void>? halten;

  /// Einladungen nach Code; fehlt ein Code, gibt es die Einladung nicht.
  final einladungen = <String, Einladung>{};

  /// Vergebene Namen: Namensschlüssel → mitgliedId.
  final vergebeneNamen = <String, String>{};
  final beitritte = <String>[];
  Object? ladeFehler;

  @override
  ErstellteKasse vorbereiten({
    required String kassenName,
    required String eigenerName,
    required int startCents,
  }) => ErstellteKasse(
    kasseId: 'k1',
    mitgliedId: 'm1',
    buchungId: 'l1',
    kassenName: kassenName,
    eigenerName: eigenerName,
    startCents: startCents,
    wiederherstellungscode: 'K7QM3XRA9DWFT2HC',
    einladungscode: 'K7Q2MXA93DWFT2HC8RNP',
  );

  @override
  Future<void> erstellen(String uid, ErstellteKasse kasse) async {
    aufrufe.add(kasse);
    await halten?.future;
    if (fehler != null) throw fehler!;
    kasseIds.add(kasse.kasseId);
  }

  @override
  Future<Einladung?> einladungLaden(String code) async {
    if (ladeFehler != null) throw ladeFehler!;
    return einladungen[code];
  }

  @override
  Future<String?> namensBesitzer(String kasseId, String name) async =>
      vergebeneNamen[nameKey(name)];

  @override
  Future<void> beitreten(String uid, Einladung e, String eigenerName) async {
    beitritte.add(eigenerName);
    await halten?.future;
    if (fehler != null) throw fehler!;
    kasseIds.add(e.kasseId);
  }
}

/// Eine Fake-Datenbank mit Kasse `k1`, dem Nutzer `uid` als Bierwart
/// „Tobias Meier“, der Kasse und „Gäste“.
FakeDatenbank testDatenbank() => FakeDatenbank()
  ..neueKasse('k1', name: 'SV Test')
  ..ort('k1', 'kasse', 'Kasse')
  ..bierwart('k1', 'uid', 'Tobias Meier')
  ..mitglied('k1', 'gaeste', 'Gäste', gast: true);

/// Startet die App mit angemeldetem Nutzer `uid` und [kasseId] (oder ohne
/// Kasse). Liefert das Fake-Repository für Erstellen und Beitreten; Links
/// kommen über [links], ein gemerkter Code über [speicher], die Daten der
/// Kasse aus [db] (Standard: [testDatenbank]). Schriften nur für Screenshots
/// mit [fonts] setzen; sonst rendert der Test mit der Ersatzschrift.
Future<FakeKasseRepository> appStarten(
  WidgetTester tester, {
  String? kasseId,
  Object? anmeldeFehler,
  FakeLinkQuelle? links,
  FakeCodeSpeicher? speicher,
  FakeDatenbank? db,
  FakeSpeicher? einstellungen,
  FakeKonto? konto,
  FakeLinkOeffner? oeffner,
  BwFonts fonts = BwFonts.plain,
}) async {
  final daten = db ?? testDatenbank();
  addTearDown(daten.schliessen);
  final quelle = links ?? FakeLinkQuelle();
  addTearDown(quelle.schliessen);
  final kasseIds = StreamController<String?>.broadcast();
  addTearDown(kasseIds.close);
  final repo = FakeKasseRepository(kasseIds);
  daten.beiNutzer = kasseIds.add;
  final container = ProviderContainer(
    overrides: [
      anmeldungProvider.overrideWith((ref) async {
        if (anmeldeFehler != null) throw anmeldeFehler;
        return 'uid';
      }),
      meineKasseIdProvider.overrideWith((ref) async* {
        yield kasseId;
        yield* kasseIds.stream;
      }),
      kasseRepositoryProvider.overrideWithValue(repo),
      kontoRepositoryProvider.overrideWithValue(konto ?? FakeKonto()),
      linkOeffnerProvider.overrideWithValue(oeffner ?? FakeLinkOeffner()),
      linkQuelleProvider.overrideWithValue(quelle),
      codeSpeicherProvider.overrideWithValue(speicher ?? FakeCodeSpeicher()),
      schreiberProvider.overrideWithValue(daten),
      sortenRepositoryProvider.overrideWithValue(daten),
      mitgliederRepositoryProvider.overrideWithValue(FakeMitglieder(daten)),
      kassenkopfRepositoryProvider.overrideWithValue(daten),
      verlaufRepositoryProvider.overrideWithValue(daten),
      orteRepositoryProvider.overrideWithValue(daten),
      logRepositoryProvider.overrideWithValue(daten),
      einstellungenRepositoryProvider.overrideWithValue(daten),
      wiederherstellungRepositoryProvider.overrideWithValue(daten),
      uebernahmeRepositoryProvider.overrideWithValue(daten),
      lokalerSpeicherProvider.overrideWithValue(
        einstellungen ?? FakeSpeicher(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BierwartApp(fonts: fonts),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Telefongröße wie im Design-Canvas (390 × 844).
void telefon(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
