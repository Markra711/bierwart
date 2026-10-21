import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/fehlerkanal.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../../core/speicher/lokaler_speicher.dart';
import '../../kader/domain/mitglied.dart';
import '../../lager/domain/sorte.dart';
import '../data/strich_batches.dart';
import '../domain/strich.dart';
import 'kasse_daten.dart';

/// Die zuletzt gewählte Sorte bleibt über App-Neustarts gewählt (UI-07).
class GewaehlteSorteNotifier extends Notifier<String?> {
  @override
  String? build() {
    final k = ref.watch(kasseIdProvider);
    if (k != null) unawaited(_laden(k));
    return null;
  }

  static String _schluessel(String kasseId) => 'gewaehlteSorte.$kasseId';

  Future<void> _laden(String kasseId) async {
    try {
      final id = await ref
          .read(lokalerSpeicherProvider)
          .lesen(_schluessel(kasseId));
      if (state == null && id != null) state = id;
    } catch (_) {
      // Ohne Speicher gilt die erste Sorte.
    }
  }

  void waehlen(String sorteId) {
    state = sorteId;
    final k = ref.read(kasseIdProvider);
    if (k == null) return;
    unawaited(
      ref
          .read(lokalerSpeicherProvider)
          .schreiben(_schluessel(k), sorteId)
          .catchError((_) {}),
    );
  }
}

final gewaehlteSorteProvider =
    NotifierProvider<GewaehlteSorteNotifier, String?>(
      GewaehlteSorteNotifier.new,
    );

/// Die Sorte, die ein Tipp bucht: die gewählte, sonst die erste.
final aktuelleSorteProvider = Provider<Sorte?>((ref) {
  final sorten = ref.watch(sortenProvider).value ?? const [];
  if (sorten.isEmpty) return null;
  final id = ref.watch(gewaehlteSorteProvider);
  return sorten.where((s) => s.id == id).firstOrNull ?? sorten.first;
});

/// Buchen auf der Strichliste. Der Zustand ist der letzte Strich, solange
/// „Rückgängig“ angeboten wird: bis zur nächsten Buchung, höchstens 8
/// Sekunden, nur auf diesem Gerät (STR-04).
class StrichlisteNotifier extends Notifier<Strich?> {
  static const rueckgaengigFrist = Duration(seconds: 8);

  Timer? _frist;

  @override
  Strich? build() {
    ref.onDispose(() => _frist?.cancel());
    return null;
  }

  /// Tippen bucht offen, Halten bar; „Gäste“ immer bar (STR-02, STR-03,
  /// KAD-03). Auch bei leerer Sorte (STR-05). Wartet nicht auf den Server:
  /// Der Strich ist sofort sichtbar und wird offline nachgereicht (NFA-02,
  /// NFA-06). Lehnt der Server später ab, meldet das der Fehlerkanal.
  bool buchen(Mitglied mitglied, {required bool gehalten}) {
    final sitzung = ref.read(sitzungProvider);
    final sorte = ref.read(aktuelleSorteProvider);
    if (sitzung == null || sorte == null) return false;
    final schreiber = ref.read(schreiberProvider);
    final strich = Strich(
      buchungId: schreiber.neueId(),
      art: strichArtFuer(mitglied, gehalten: gehalten),
      mitglied: mitglied,
      sorte: sorte,
      preisCents: sorte.preisCents,
    );
    ref
        .read(fehlerkanalProvider.notifier)
        .beobachten(
          schreiber.schreiben(
            strichBatch(
              uid: sitzung.uid,
              bierwartName: sitzung.name,
              kasseId: sitzung.kasseId,
              buchungId: strich.buchungId,
              art: strich.art,
              mitgliedId: mitglied.id,
              sorteId: sorte.id,
              preisCents: strich.preisCents,
              geraetZeit: DateTime.now(),
            ),
          ),
          'Der Strich für ${mitglied.name}',
        );
    _frist?.cancel();
    _frist = Timer(rueckgaengigFrist, () => state = null);
    state = strich;
    return true;
  }

  /// Storno des letzten Strichs (STR-04).
  void rueckgaengig() {
    final strich = state;
    final sitzung = ref.read(sitzungProvider);
    if (strich == null || sitzung == null) return;
    _frist?.cancel();
    state = null;
    final schreiber = ref.read(schreiberProvider);
    ref
        .read(fehlerkanalProvider.notifier)
        .beobachten(
          schreiber.schreiben(
            stornoBatch(
              uid: sitzung.uid,
              bierwartName: sitzung.name,
              kasseId: sitzung.kasseId,
              strich: strich,
              geraetZeit: DateTime.now(),
            ),
          ),
          'Das Rückgängig für ${strich.mitglied.name}',
        );
  }
}

final strichlisteProvider = NotifierProvider<StrichlisteNotifier, Strich?>(
  StrichlisteNotifier.new,
);
