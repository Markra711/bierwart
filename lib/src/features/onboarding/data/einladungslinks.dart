import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Woher Einladungslinks kommen: App-Links (AUTH-04) und der
/// Play-Store-Referrer nach der Installation (AUTH-12).
abstract interface class LinkQuelle {
  /// Alle geöffneten Links, auch der, mit dem die App gestartet wurde.
  Stream<Uri> get links;

  /// Der Referrer der Installation, `null` ohne Google Play.
  Future<String?> installReferrer();
}

class GeraeteLinkQuelle implements LinkQuelle {
  final _appLinks = AppLinks();

  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;

  @override
  Future<String?> installReferrer() async {
    if (!Platform.isAndroid) return null;
    try {
      return (await PlayInstallReferrer.installReferrer).installReferrer;
    } catch (_) {
      // Ohne Play Store (Emulator, Debug-Installation) gibt es keinen.
      return null;
    }
  }
}

/// Merkt einen offenen Code über einen Neustart hinweg (AUTH-06), z. B. wenn
/// die App nach dem Antippen erst installiert wird.
abstract interface class CodeSpeicher {
  Future<String?> offenerCode();
  Future<void> merken(String? code);

  /// Den Install-Referrer liest die App nur beim ersten Start.
  Future<bool> referrerGelesen();
  Future<void> referrerAlsGelesenMerken();
}

class GeraeteCodeSpeicher implements CodeSpeicher {
  static const _code = 'offenerEinladungscode';
  static const _referrer = 'installReferrerGelesen';

  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> offenerCode() => _prefs.getString(_code);

  @override
  Future<void> merken(String? code) =>
      code == null ? _prefs.remove(_code) : _prefs.setString(_code, code);

  @override
  Future<bool> referrerGelesen() async =>
      await _prefs.getBool(_referrer) ?? false;

  @override
  Future<void> referrerAlsGelesenMerken() => _prefs.setBool(_referrer, true);
}

final linkQuelleProvider = Provider<LinkQuelle>((ref) => GeraeteLinkQuelle());

final codeSpeicherProvider = Provider<CodeSpeicher>(
  (ref) => GeraeteCodeSpeicher(),
);
