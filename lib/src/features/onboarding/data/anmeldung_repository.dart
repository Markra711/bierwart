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
    yield* bestaetigteKasseId(
      db
          .doc('users/$uid')
          .snapshots(includeMetadataChanges: true)
          .map(
            (s) => (
              ausstehend: s.metadata.hasPendingWrites,
              kasseId: s.data()?['kasseId'] as String?,
            ),
          ),
    );
  },
);

/// Die Kasse erst, wenn der Server den Eintrag angenommen hat. Sonst hört
/// die App beim Erstellen und Beitreten schon auf die Kasse, solange der
/// Batch unterwegs ist; der Server lehnt das Zuhören ab, weil der Nutzer
/// dort noch kein Bierwart ist, und die App hält ihn für entfernt (ADM-02).
Stream<String?> bestaetigteKasseId(
  Stream<({bool ausstehend, String? kasseId})> stand,
) => stand.where((s) => !s.ausstehend).map((s) => s.kasseId).distinct();

/// Das anonyme Konto bei Firebase Authentication (AUTH-15).
class KontoRepository {
  KontoRepository(this._auth);

  final FirebaseAuth _auth;

  /// Löscht das Konto dieses Geräts, nachdem `users/{uid}` weg ist.
  /// Verlangt Firebase eine frische Anmeldung, die es für anonyme Konten
  /// nicht gibt, meldet sich die App nur ab; das Konto hat dann keine Daten
  /// mehr. Danach `ref.invalidate(anmeldungProvider)` für eine neue UID.
  Future<void> loeschen() async {
    final nutzer = _auth.currentUser;
    if (nutzer == null) return;
    try {
      await nutzer.delete();
    } on FirebaseAuthException {
      await _auth.signOut();
    }
  }
}

final kontoRepositoryProvider = Provider<KontoRepository>(
  (ref) => KontoRepository(ref.watch(firebaseAuthProvider)),
);

/// Meldung für eine fehlgeschlagene Anmeldung (NFA-10).
String anmeldeFehler(Object fehler) => switch (fehler) {
  FirebaseAuthException(code: 'network-request-failed') =>
    'Für den ersten Start brauchst du Netz.',
  FirebaseAuthException(:final code) => 'Anmeldung fehlgeschlagen ($code).',
  _ => 'Anmeldung fehlgeschlagen.',
};
