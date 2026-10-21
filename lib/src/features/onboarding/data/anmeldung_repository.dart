import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

/// Ohne automatische Wiederholung: Der Ladebildschirm zeigt den Fehler und
/// „Nochmal versuchen“ (NFA-10).
Duration? _keineWiederholung(int versuch, Object fehler) => null;

/// Anonyme Anmeldung ohne Eingabe (AUTH-01). Ist das Gerät schon angemeldet,
/// bleibt es bei dieser UID. Nach einem Fehler: `ref.invalidate`.
final anmeldungProvider = FutureProvider<String>(retry: _keineWiederholung, (
  ref,
) async {
  final auth = ref.watch(firebaseAuthProvider);
  final vorhanden = await auth.authStateChanges().first;
  if (vorhanden != null) return vorhanden.uid;
  final neu = await auth.signInAnonymously();
  return neu.user!.uid;
});

/// Die Kasse dieses Nutzers aus `users/{uid}`, `null` ohne Kasse.
final meineKasseIdProvider = StreamProvider<String?>(
  retry: _keineWiederholung,
  (ref) async* {
    final uid = await ref.watch(anmeldungProvider.future);
    final db = ref.watch(firestoreProvider);
    yield* db
        .doc('users/$uid')
        .snapshots()
        .map((s) => s.data()?['kasseId'] as String?);
  },
);

/// Meldung für eine fehlgeschlagene Anmeldung (NFA-10).
String anmeldeFehler(Object fehler) => switch (fehler) {
  FirebaseAuthException(code: 'network-request-failed') =>
    'Für den ersten Start brauchst du Netz.',
  FirebaseAuthException(:final code) => 'Anmeldung fehlgeschlagen ($code).',
  _ => 'Anmeldung fehlgeschlagen.',
};
