import 'package:bier_wart/firebase_options.dart';
import 'package:bier_wart/src/core/firebase/emulatoren.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Plattform unabhängig vom Testrechner festlegen.
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Emulatoren laufen mit dem Demo-Projekt, nie mit echten Daten', () {
    final echt = DefaultFirebaseOptions.currentPlatform;
    final emu = optionenFuer(echt, emulatoren: true);
    expect(emu.projectId, 'demo-bierwart');
    expect(emu.appId, echt.appId);
  });

  test('ohne Schalter das echte Projekt', () {
    final echt = DefaultFirebaseOptions.currentPlatform;
    expect(optionenFuer(echt, emulatoren: false).projectId, 'bier-wart');
  });

  test('Schalter ist ohne --dart-define aus', () {
    expect(useEmulators, isFalse);
  });
}
