import 'package:bier_wart/src/core/firebase/app_check.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Release-Build nutzt Play Integrity (NFA-07)', () {
    expect(
      appCheckAnbieter(release: true),
      isA<AndroidPlayIntegrityProvider>(),
    );
  });

  test('beim Entwickeln der Debug-Anbieter, mit Token nur wenn gesetzt', () {
    final ohne = appCheckAnbieter(release: false, debugToken: '');
    expect(ohne, isA<AndroidDebugProvider>());
    expect((ohne as AndroidDebugProvider).debugToken, isNull);
    final mit = appCheckAnbieter(release: false, debugToken: 'abc-123');
    expect((mit as AndroidDebugProvider).debugToken, 'abc-123');
  });
}
