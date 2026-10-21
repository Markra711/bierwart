import 'package:bier_wart/src/core/fehler/fehlerkanal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('abgelehnte Buchung landet im Kanal (NFA-10)', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c
        .read(fehlerkanalProvider.notifier)
        .beobachten(
          Future.error(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          ),
          'Der Strich für Jonas',
        );
    await Future<void>.delayed(Duration.zero);
    expect(
      c.read(fehlerkanalProvider)!.text,
      'Der Strich für Jonas hat der Server abgelehnt und zurückgenommen.',
    );
  });

  test('erfolgreiches Schreiben meldet nichts', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(fehlerkanalProvider.notifier).beobachten(Future.value(), 'x');
    await Future<void>.delayed(Duration.zero);
    expect(c.read(fehlerkanalProvider), isNull);
  });

  test('gleicher Text zweimal ist zweimal eine Meldung', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(fehlerkanalProvider.notifier);
    n.melden('a');
    final erste = c.read(fehlerkanalProvider)!.nr;
    n.melden('a');
    expect(c.read(fehlerkanalProvider)!.nr, isNot(erste));
  });
}
