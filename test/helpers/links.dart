import 'dart:async';

import 'package:bier_wart/src/features/onboarding/data/einladungslinks.dart';

/// App-Links von Hand auslösen, Referrer vorgeben.
class FakeLinkQuelle implements LinkQuelle {
  FakeLinkQuelle({this.referrer});

  final _links = StreamController<Uri>.broadcast();
  String? referrer;
  var referrerAbfragen = 0;

  void oeffnen(String link) => _links.add(Uri.parse(link));

  Future<void> schliessen() => _links.close();

  @override
  Stream<Uri> get links => _links.stream;

  @override
  Future<String?> installReferrer() async {
    referrerAbfragen++;
    return referrer;
  }
}

/// Speicher im Arbeitsspeicher statt shared_preferences.
class FakeCodeSpeicher implements CodeSpeicher {
  FakeCodeSpeicher({this.code, this.gelesen = false});

  String? code;
  bool gelesen;

  @override
  Future<String?> offenerCode() async => code;

  @override
  Future<void> merken(String? code) async => this.code = code;

  @override
  Future<bool> referrerGelesen() async => gelesen;

  @override
  Future<void> referrerAlsGelesenMerken() async => gelesen = true;
}
