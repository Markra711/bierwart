import 'dart:async';

import 'package:bier_wart/src/app.dart';
import 'package:bier_wart/src/core/theme/app_theme.dart';
import 'package:bier_wart/src/features/onboarding/data/anmeldung_repository.dart';
import 'package:bier_wart/src/features/onboarding/data/einladungslinks.dart';
import 'package:bier_wart/src/features/onboarding/data/kasse_repository.dart';
import 'package:bier_wart/src/features/kader/domain/name.dart';
import 'package:bier_wart/src/features/onboarding/domain/einladung.dart';
import 'package:bier_wart/src/features/onboarding/domain/erstellte_kasse.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'links.dart';

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
  final vergebeneNamen = <String>{};
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
  Future<bool> nameVergeben(String kasseId, String name) async =>
      vergebeneNamen.contains(nameKey(name));

  @override
  Future<void> beitreten(String uid, Einladung e, String eigenerName) async {
    beitritte.add(eigenerName);
    await halten?.future;
    if (fehler != null) throw fehler!;
    kasseIds.add(e.kasseId);
  }
}

/// Startet die App mit angemeldetem Nutzer `uid` und [kasseId] (oder ohne
/// Kasse). Liefert das Fake-Repository für Erstellen und Beitreten; Links
/// kommen über [links], ein gemerkter Code über [speicher].
Future<FakeKasseRepository> appStarten(
  WidgetTester tester, {
  String? kasseId,
  Object? anmeldeFehler,
  FakeLinkQuelle? links,
  FakeCodeSpeicher? speicher,
}) async {
  final quelle = links ?? FakeLinkQuelle();
  addTearDown(quelle.schliessen);
  final kasseIds = StreamController<String?>.broadcast();
  addTearDown(kasseIds.close);
  final repo = FakeKasseRepository(kasseIds);
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
      linkQuelleProvider.overrideWithValue(quelle),
      codeSpeicherProvider.overrideWithValue(speicher ?? FakeCodeSpeicher()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const BierwartApp(fonts: BwFonts.plain),
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
