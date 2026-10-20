import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:bier_wart/src/core/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hält lib/src/core/theme/tokens.dart und docs/design/tokens.json gleich.
void main() {
  final json = jsonDecode(
    File('docs/design/tokens.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  Map<String, String> tokens(String family) => {
    for (final t in (json[family] as Map<String, dynamic>)['tokens'] as List)
      t['name'] as String: t['value'] as String,
  };

  Color hex(String v) => Color(int.parse('FF${v.substring(1)}', radix: 16));
  double px(String v) => double.parse(v.replaceAll('px', ''));

  test('Farben', () {
    const dart = {
      'bg': BwColors.bg,
      'shadow-dark': BwColors.shadowDark,
      'shadow-light': BwColors.shadowLight,
      'surface-float': BwColors.surfaceFloat,
      'ink': BwColors.ink,
      'ink-muted': BwColors.inkMuted,
      'ink-faint': BwColors.inkFaint,
      'line': BwColors.line,
      'line-strong': BwColors.lineStrong,
      'grad-start': BwColors.gradStart,
      'grad-end': BwColors.gradEnd,
      'on-accent': BwColors.onAccent,
      'positive': BwColors.positive,
      'negative': BwColors.negative,
      'handle': BwColors.handle,
    };
    final source = tokens('color');
    expect(dart.keys.toSet(), source.keys.toSet());
    source.forEach(
      (name, value) => expect(dart[name], hex(value), reason: name),
    );
  });

  test('Abstände', () {
    const dart = {
      'space-1': BwSpacing.space1,
      'space-2': BwSpacing.space2,
      'space-3': BwSpacing.space3,
      'space-4': BwSpacing.space4,
      'space-5': BwSpacing.space5,
      'space-6': BwSpacing.space6,
    };
    final source = tokens('spacing');
    expect(dart.keys.toSet(), source.keys.toSet());
    source.forEach(
      (name, value) => expect(dart[name], px(value), reason: name),
    );
  });

  test('Radien', () {
    const dart = {
      'radius-sm': BwRadius.sm,
      'radius-md': BwRadius.md,
      'radius-lg': BwRadius.lg,
      'radius-xl': BwRadius.xl,
      'radius-pill': BwRadius.pill,
    };
    final source = tokens('radius');
    expect(dart.keys.toSet(), source.keys.toSet());
    source.forEach(
      (name, value) => expect(dart[name], px(value), reason: name),
    );
  });

  test('Schatten', () {
    const dart = {
      'raised': BwShadows.raised,
      'raised-sm': BwShadows.raisedSm,
      'raised-lg': BwShadows.raisedLg,
      'inset': BwShadows.inset,
      'inset-sm': BwShadows.insetSm,
      'track': BwShadows.track,
      'float': BwShadows.float,
    };
    final source = tokens('shadow');
    expect(dart.keys.toSet(), source.keys.toSet());
    source.forEach((name, value) {
      final parts = value
          .split(',')
          .map((p) => p.trim().split(RegExp(r'\s+')))
          .toList();
      final shadows = dart[name]!;
      expect(shadows.length, parts.length, reason: name);
      for (var i = 0; i < parts.length; i++) {
        final p = parts[i];
        final inset = p.first == 'inset';
        final v = inset ? p.sublist(1) : p;
        final s = shadows[i];
        expect(
          [s.dx, s.dy, s.blur, s.color, s.inset],
          [px(v[0]), px(v[1]), px(v[2]), hex(v[3]), inset],
          reason: '$name[$i]',
        );
      }
    });
  });

  test('Verlauf', () {
    final value = tokens('gradient')['grad-accent']!;
    final colors = RegExp(r'#[0-9a-fA-F]{6}')
        .allMatches(value)
        .map((m) => hex(m[0]!));
    expect(BwGradients.accent.colors, colors.toList());
    expect(value, contains('100deg'));
  });

  test('Textstile', () {
    const dart = {
      'outline-numeral': BwType.outlineNumeral,
      'screen-title': BwType.screenTitle,
      'page-title': BwType.pageTitle,
      'amount-xl': BwType.amountXl,
      'amount-l': BwType.amountL,
      'amount-m': BwType.amountM,
      'label': BwType.label,
      'button': BwType.button,
      'name': BwType.name,
      'body': BwType.body,
      'caption': BwType.caption,
    };
    final groups = (json['type'] as Map<String, dynamic>)['groups'] as List;
    final seen = <String>{};
    for (final g in groups) {
      final family = g['family'] == 'display'
          ? BwFamily.display
          : BwFamily.body;
      for (final s in g['styles'] as List) {
        final name = s['name'] as String;
        seen.add(name);
        final t = dart[name];
        expect(t, isNotNull, reason: name);
        final spacing = s['letterSpacing'] as String?;
        expect(
          [
            t!.family,
            t.fontSize,
            t.lineHeight,
            t.fontWeight,
            t.letterSpacingEm,
          ],
          [
            family,
            px(s['fontSize'] as String),
            px(s['lineHeight'] as String),
            s['fontWeight'],
            spacing == null ? 0 : double.parse(spacing.replaceAll('em', '')),
          ],
          reason: name,
        );
      }
    }
    expect(seen, dart.keys.toSet());
  });
}
