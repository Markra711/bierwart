import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// `flutter run --dart-define=USE_EMULATORS=true` verbindet mit den lokalen
/// Emulatoren. In Release-Builds ist der Schalter immer aus.
const useEmulators = !kReleaseMode && bool.fromEnvironment('USE_EMULATORS');

/// Der Android-Emulator erreicht den Rechner unter 10.0.2.2. Für ein echtes
/// Gerät im WLAN: `--dart-define=EMULATOR_HOST=192.168.x.y`.
const emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

/// Emulatoren laufen immer mit dem Demo-Projekt, nie mit echten Daten
/// (CLAUDE.md). Ports wie in firebase.json.
const emulatorProjekt = 'demo-bierwart';
const authPort = 9099;
const firestorePort = 8080;

/// Gegen die Emulatoren mit der Projekt-ID des Demo-Projekts, sonst unverändert.
FirebaseOptions optionenFuer(FirebaseOptions echt, {required bool emulatoren}) {
  return emulatoren ? echt.copyWith(projectId: emulatorProjekt) : echt;
}

Future<void> mitEmulatorenVerbinden(
  FirebaseAuth auth,
  FirebaseFirestore firestore,
) async {
  await auth.useAuthEmulator(emulatorHost, authPort);
  firestore.useFirestoreEmulator(emulatorHost, firestorePort);
}
