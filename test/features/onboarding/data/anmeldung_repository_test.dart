import 'package:bier_wart/src/features/onboarding/data/anmeldung_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
