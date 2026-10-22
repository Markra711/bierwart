import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Fester Debug-Token für Entwicklungs-Builds, z. B. auf einem eigenen Gerät:
/// `--dart-define=APP_CHECK_DEBUG_TOKEN=…`, in der Firebase-Konsole unter
/// App Check eingetragen. Ohne ihn erzeugt das SDK einen Token und schreibt
/// ihn ins Logcat.
const appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

/// Welcher Anbieter das App-Check-Token liefert (NFA-07): im Release-Build
/// Play Integrity, beim Entwickeln der Debug-Anbieter (architecture.md,
/// App Check).
AndroidAppCheckProvider appCheckAnbieter({
  bool release = kReleaseMode,
  String debugToken = appCheckDebugToken,
}) => release
    ? const AndroidPlayIntegrityProvider()
    : AndroidDebugProvider(debugToken: debugToken.isEmpty ? null : debugToken);

/// Schaltet App Check für [app] ein. Erzwungen wird es erst zum
/// Store-Release in der Konsole; bis dahin darf ein Fehler hier den Start
/// nicht verhindern, Firestore nimmt Anfragen auch ohne Token an.
Future<void> appCheckAktivieren(FirebaseApp app) async {
  try {
    await FirebaseAppCheck.instanceFor(app: app)
        .activate(providerAndroid: appCheckAnbieter());
  } on Exception catch (e) {
    debugPrint('App Check ließ sich nicht aktivieren: $e');
  }
}
