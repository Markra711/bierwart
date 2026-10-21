import 'dart:io';

import 'package:bier_wart/src/core/firebase/emulatoren.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Emulatoren nur mit einem Demo-Projekt, nie mit echten Daten', () {
    // Firebase behandelt nur IDs mit „demo-“ als Demo-Projekt ohne Zugriff
    // auf echte Dienste.
    expect(emulatorProjekt, startsWith('demo-'));
  });

  test('Schalter ist ohne --dart-define aus', () {
    expect(useEmulators, isFalse);
  });

  test('gleiches Demo-Projekt wie in den Befehlen von CLAUDE.md', () {
    expect(
      File('CLAUDE.md').readAsStringSync(),
      contains('emulators:start --project $emulatorProjekt'),
    );
  });

  test('Ports wie in firebase.json', () {
    final config = File('firebase.json').readAsStringSync();
    expect(config, contains('"port": $authPort'));
    expect(config, contains('"port": $firestorePort'));
  });
}
