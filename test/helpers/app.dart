import 'dart:async';

import 'package:bier_wart/src/app.dart';
import 'package:bier_wart/src/core/theme/app_theme.dart';
import 'package:bier_wart/src/features/onboarding/data/anmeldung_repository.dart';
import 'package:bier_wart/src/features/onboarding/data/kasse_repository.dart';
import 'package:bier_wart/src/features/onboarding/domain/erstellte_kasse.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ersetzt Firestore beim Erstellen. Nach Erfolg meldet es die neue Kasse
/// über [kasseIds], wie es `users/{uid}` täte.
class FakeKasseRepository implements KasseRepository {
  FakeKasseRepository(this.kasseIds);

  final StreamController<String?> kasseIds;
  final aufrufe = <ErstellteKasse>[];
  Object? fehler;
  Completer<void>? halten;

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
}

/// Startet die App mit angemeldetem Nutzer `uid` und [kasseId] (oder ohne
/// Kasse). Liefert das Fake-Repository für Erstellen.
Future<FakeKasseRepository> appStarten(
  WidgetTester tester, {
  String? kasseId,
  Object? anmeldeFehler,
}) async {
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
