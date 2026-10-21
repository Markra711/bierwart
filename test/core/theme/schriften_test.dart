import 'dart:convert';
import 'dart:io';

import 'package:bier_wart/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jeder Schnitt aus docs/design/tokens.json liegt als Asset in der App
/// (offene Frage 15: Schriften offline).
void main() {
  const familien = {'display': 'Barlow Condensed', 'body': 'Barlow'};

  // Aus pubspec.yaml: Familie → Gewichte, deren Datei existiert.
  Map<String, Set<int>> gebuendelt() {
    final result = <String, Set<int>>{};
    String? familie;
    String? asset;
    for (final zeile in File('pubspec.yaml').readAsLinesSync()) {
      final f = RegExp(r'^\s*- family: (.+)$').firstMatch(zeile);
      final a = RegExp(r'^\s*- asset: (.+)$').firstMatch(zeile);
      final w = RegExp(r'^\s*weight: (\d+)$').firstMatch(zeile);
      if (f != null) familie = f.group(1)!.trim();
      if (a != null) asset = a.group(1)!.trim();
      if (w != null && familie != null && asset != null) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
        result.putIfAbsent(familie, () => {}).add(int.parse(w.group(1)!));
      }
    }
    return result;
  }

  test('alle Schnitte der Tokens sind mitgeliefert', () {
    final json = jsonDecode(
      File('docs/design/tokens.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final noetig = <String, Set<int>>{};
    for (final g in (json['type'] as Map<String, dynamic>)['groups'] as List) {
      final familie = familien[g['family']]!;
      for (final s in g['styles'] as List) {
        noetig.putIfAbsent(familie, () => {}).add(s['fontWeight'] as int);
      }
    }
    expect(gebuendelt(), noetig);
  });

  test('Theme nutzt die mitgelieferten Familien', () {
    final text = BwTextStyles.from(BwFonts.barlow);
    expect(text.screenTitle.fontFamily, 'Barlow Condensed');
    expect(text.amountL.fontFamily, 'Barlow Condensed');
    expect(text.body.fontFamily, 'Barlow');
    expect(text.button.fontFamily, 'Barlow');
    expect(text.body.fontWeight, FontWeight.w500);
  });

  test('Lizenz liegt bei', () {
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
  });
}
