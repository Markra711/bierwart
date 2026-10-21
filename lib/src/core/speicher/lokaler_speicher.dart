import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kleine Einstellungen nur auf diesem Gerät, z. B. die gewählte Sorte
/// (UI-07). Nichts davon ist Geschäftslogik.
abstract interface class LokalerSpeicher {
  Future<String?> lesen(String schluessel);

  /// `null` löscht den Eintrag.
  Future<void> schreiben(String schluessel, String? wert);
}

class GeraeteSpeicher implements LokalerSpeicher {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> lesen(String schluessel) => _prefs.getString(schluessel);

  @override
  Future<void> schreiben(String schluessel, String? wert) => wert == null
      ? _prefs.remove(schluessel)
      : _prefs.setString(schluessel, wert);
}

final lokalerSpeicherProvider = Provider<LokalerSpeicher>(
  (ref) => GeraeteSpeicher(),
);
