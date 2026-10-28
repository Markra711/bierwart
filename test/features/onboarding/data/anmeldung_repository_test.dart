import 'package:bier_wart/src/features/onboarding/data/anmeldung_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Nutzer extends Fake implements User {
  Object? fehler;
  var geloescht = false;

  @override
  Future<void> delete() async {
    if (fehler != null) throw fehler!;
    geloescht = true;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser);

  @override
  final User? currentUser;
  var abgemeldet = false;

  @override
  Future<void> signOut() async => abgemeldet = true;
}

void main() {
  test('die Kasse gilt erst, wenn der Server den Batch angenommen hat', () {
    final ids = bestaetigteKasseId(
      Stream.fromIterable([
        (ausstehend: false, kasseId: null),
        (ausstehend: true, kasseId: 'k1'),
        (ausstehend: false, kasseId: 'k1'),
        (ausstehend: false, kasseId: 'k1'),
      ]),
    );
    expect(ids, emitsInOrder([null, 'k1', emitsDone]));
  });

  test('offline aus dem Cache gilt die gemerkte Kasse sofort (NFA-02)', () {
    expect(
      bestaetigteKasseId(Stream.value((ausstehend: false, kasseId: 'k1'))),
      emitsInOrder(['k1', emitsDone]),
    );
  });

  group('Konto löschen (AUTH-15)', () {
    test('löscht das Konto', () async {
      final nutzer = _Nutzer();
      final auth = _Auth(nutzer);
      await KontoRepository(auth).loeschen();
      expect(nutzer.geloescht, isTrue);
      expect(auth.abgemeldet, isFalse);
    });

    test('ohne frische Anmeldung nur abmelden', () async {
      final nutzer = _Nutzer()
        ..fehler = FirebaseAuthException(code: 'requires-recent-login');
      final auth = _Auth(nutzer);
      await KontoRepository(auth).loeschen();
      expect(nutzer.geloescht, isFalse);
      expect(auth.abgemeldet, isTrue);
    });

    test('ohne Konto nichts tun', () async {
      final auth = _Auth(null);
      await KontoRepository(auth).loeschen();
      expect(auth.abgemeldet, isFalse);
    });
  });
}
