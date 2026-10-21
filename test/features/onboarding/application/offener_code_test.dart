import 'package:bier_wart/src/features/onboarding/application/onboarding.dart';
import 'package:bier_wart/src/features/onboarding/data/einladungslinks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/links.dart';

const code = 'K7Q2MXA93DWFT2HC8RNP';
const andererCode = 'ABCDEFGHJKMNPQRSTVWX';

void main() {
  late FakeLinkQuelle quelle;
  late FakeCodeSpeicher speicher;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        linkQuelleProvider.overrideWithValue(quelle),
        codeSpeicherProvider.overrideWithValue(speicher),
      ],
    );
    addTearDown(c.dispose);
    // Lauschen hält den Provider am Leben wie im Router.
    c.listen(offenerCodeProvider, (_, _) {});
    return c;
  }

  Future<void> warten() => Future<void>.delayed(Duration.zero);

  setUp(() {
    quelle = FakeLinkQuelle();
    speicher = FakeCodeSpeicher();
  });
  tearDown(() => quelle.schliessen());

  test('App-Link setzt den Code und merkt ihn (AUTH-04, AUTH-06)', () async {
    final c = container();
    quelle.oeffnen('https://bier-wart.web.app/j/$code');
    await warten();
    expect(c.read(offenerCodeProvider), code);
    expect(speicher.code, code);
  });

  test('fremde Links ändern nichts', () async {
    final c = container();
    quelle.oeffnen('https://example.org/j/$code');
    await warten();
    expect(c.read(offenerCodeProvider), isNull);
  });

  test('gemerkter Code ist nach einem Neustart wieder da (AUTH-06)', () async {
    speicher.code = code;
    final c = container();
    await warten();
    expect(c.read(offenerCodeProvider), code);
  });

  test('Install-Referrer nur beim ersten Start (AUTH-12)', () async {
    quelle.referrer = 'code=$code';
    final c = container();
    await warten();
    await warten();
    expect(c.read(offenerCodeProvider), code);
    expect(speicher.gelesen, isTrue);

    c.read(offenerCodeProvider.notifier).verwerfen();
    final zweiterStart = container();
    await warten();
    expect(zweiterStart.read(offenerCodeProvider), isNull);
    expect(quelle.referrerAbfragen, 1);
  });

  test('ein neuer Link ersetzt den gemerkten Code', () async {
    speicher.code = code;
    final c = container();
    await warten();
    quelle.oeffnen('https://bier-wart.web.app/j/$andererCode');
    await warten();
    expect(c.read(offenerCodeProvider), andererCode);
  });

  test('verwerfen löscht auch den gemerkten Code', () async {
    final c = container();
    quelle.oeffnen('https://bier-wart.web.app/j/$code');
    await warten();
    c.read(offenerCodeProvider.notifier).verwerfen();
    await warten();
    expect(c.read(offenerCodeProvider), isNull);
    expect(speicher.code, isNull);
  });
}
