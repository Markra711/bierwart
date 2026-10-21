import 'dart:math';

import 'package:bier_wart/src/features/onboarding/domain/codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Zufallscode', () {
    test('nur Crockford-Zeichen in der verlangten Länge', () {
      final code = zufallsCode(einladungscodeLaenge, Random(1));
      expect(code, hasLength(20));
      expect(istCode(code, 20), isTrue);
      expect(code, isNot(matches(RegExp('[ILOU]'))));
    });

    test('Einladungscode hat mindestens 96 Bit (AUTH-08)', () {
      expect(einladungscodeLaenge * 5, greaterThanOrEqualTo(96));
      expect(wiederherstellungscodeLaenge * 5, 80);
    });

    test('passt zu den Rules (URL-sicher, 16 bis 64 Zeichen)', () {
      final code = zufallsCode(einladungscodeLaenge);
      expect(code, matches(RegExp(r'^[A-Za-z0-9_-]{16,64}$')));
    });
  });

  group('Normalisierung (AUTH-03, ADM-06)', () {
    test('Gruppen, Kleinschreibung und Verwechsler', () {
      expect(normalisiereCode('k7qm-3xra 9dwf-t2hc'), 'K7QM3XRA9DWFT2HC');
      expect(normalisiereCode('OIL'), '011');
    });

    test('Anzeige in Vierergruppen', () {
      expect(inGruppen('K7QM3XRA9DWFT2HC'), 'K7QM-3XRA-9DWF-T2HC');
      expect(inGruppen('ABCDEFGHJK'), 'ABCD-EFGH-JK');
    });
  });

  test('Hash wie hashing.sha256() in den Rules, ID klein geschrieben', () {
    expect(
      hexVon(hashVon('K7QM3XRA9DWFT2HC')),
      '4fbd503d82c7c1d69d4752c55b927e735f76c8c5f6a2bf7aff339ef6bb0776e8',
    );
    expect(hashVon('K7QM3XRA9DWFT2HC'), hasLength(32));
  });

  group('Einladungscode aus Eingabe', () {
    const code = 'K7Q2MXA93DWFT2HC8RNP';

    test('aus Link', () {
      expect(einladungscodeAus('https://bier-wart.web.app/j/$code'), code);
      expect(einladungscodeAus('bier-wart.web.app/j/$code/'), code);
      expect(einladungscodeAus('Komm dazu: bier-wart.web.app/j/$code'), code);
    });

    test('aus Code allein, auch gruppiert und klein', () {
      expect(einladungscodeAus(code), code);
      expect(einladungscodeAus('k7q2-mxa9-3dwf-t2hc-8rnp'), code);
    });

    test('nichts Erkennbares', () {
      expect(einladungscodeAus(''), isNull);
      expect(einladungscodeAus('K7Q2MX'), isNull);
      expect(einladungscodeAus('https://example.org'), isNull);
    });

    test('Link wird aus dem Code gebaut', () {
      expect(einladungslink(code), 'https://bier-wart.web.app/j/$code');
    });
  });

  group('App-Link und Referrer (AUTH-04, AUTH-12)', () {
    const code = 'K7Q2MXA93DWFT2HC8RNP';

    test('App-Link von bier-wart.web.app', () {
      expect(
        einladungscodeAusLink(Uri.parse('https://bier-wart.web.app/j/$code')),
        code,
      );
      expect(
        einladungscodeAusLink(
          Uri.parse('https://bier-wart.web.app/j/$code?x=1'),
        ),
        code,
      );
    });

    test('fremde oder kaputte Links', () {
      expect(
        einladungscodeAusLink(Uri.parse('https://example.org/j/$code')),
        isNull,
      );
      expect(
        einladungscodeAusLink(Uri.parse('https://bier-wart.web.app/x/$code')),
        isNull,
      );
      expect(
        einladungscodeAusLink(Uri.parse('https://bier-wart.web.app/j/K7Q2')),
        isNull,
      );
    });

    test('Referrer aus Google Play', () {
      expect(einladungscodeAusReferrer('code=$code'), code);
      expect(
        einladungscodeAusReferrer('utm_source=google-play&code=$code'),
        code,
      );
      expect(einladungscodeAusReferrer('utm_source=google-play'), isNull);
      expect(einladungscodeAusReferrer(null), isNull);
    });
  });
}
