import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';

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

/// Startet Firebase und liefert die App, die alle Provider nutzen.
///
/// Gegen die Emulatoren eine eigene App mit `demoProjectId`: Unter Android
/// legt das native SDK aus `google-services.json` schon die Standard-App für
/// `bier-wart` an, und FlutterFire würde andere Optionen dafür ignorieren.
Future<FirebaseApp> firebaseStarten({bool emulatoren = useEmulators}) async {
  if (!emulatoren) {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final app = await Firebase.initializeApp(demoProjectId: emulatorProjekt);
  await FirebaseAuth.instanceFor(app: app)
      .useAuthEmulator(emulatorHost, authPort);
  FirebaseFirestore.instanceFor(app: app)
      .useFirestoreEmulator(emulatorHost, firestorePort);
  return app;
}
