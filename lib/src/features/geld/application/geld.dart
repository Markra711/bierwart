import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/fehler/fehlerkanal.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../../core/money/cents.dart';
import '../../kader/application/kader_daten.dart';
import '../../kader/domain/eintrag.dart';
import '../../onboarding/data/anmeldung_repository.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../data/geld_batches.dart';
import '../data/orte_repository.dart';
import '../domain/ort.dart';

/// Kasse und alle Portemonnaies, roh aus `orte/`.
final orteProvider = StreamProvider<List<Ort>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const [])
      : ref.watch(orteRepositoryProvider).orte(k);
});

/// Kasse, sichtbare Portemonnaies und Vermögen (GEL-07, GEL-08). Namen
/// kommen aus dem Kader, damit ein Umbenennen auch hier ankommt.
final geldstandProvider = Provider<AsyncValue<Geldstand>>((ref) {
  final uid = ref.watch(anmeldungProvider).value;
  final mitglieder = ref.watch(mitgliederProvider).value ?? const [];
  final namen = {
    for (final m in mitglieder)
      if (m.bierwartUid != null) m.bierwartUid!: m.name,
  };
  return ref
      .watch(orteProvider)
      .whenData((orte) => geldstand(orte, eigeneUid: uid, namen: namen));
});

/// Wann zuletzt ein Kassensturz gebucht wurde (GEL-06).
final letzterKassensturzProvider = StreamProvider<DateTime?>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(null)
      : ref.watch(orteRepositoryProvider).letzterKassensturz(k);
});

/// Was im Geld-Tab gebucht wird: Ein- und Auszahlungen für alle Bierwarte,
/// Übergaben und Kassensturz nur für den Kassenwart (UI-08; die Rules prüfen
/// es trotzdem, NFA-07). Ein-, Auszahlung und Übergabe gehen offline und
/// warten nicht (NFA-02); der Kassensturz braucht Netz und wartet.
class GeldAktionen {
  GeldAktionen(this._ref, {this.antwortFrist = const Duration(seconds: 20)});

  final Ref _ref;
  final Duration antwortFrist;

  static const _nichtGeladen = Eingabefehler(
    allgemein: 'Die Kasse ist noch nicht geladen.',
  );
  static const _betragFehler = Eingabefehler(
    preis: 'Betrag wie 12,00 eingeben.',
  );

  Schreiber get _schreiber => _ref.read(schreiberProvider);

  void _beobachten(Future<void> schreiben, String was) =>
      _ref.read(fehlerkanalProvider.notifier).beobachten(schreiben, was);

  int? _betrag(String text) {
    final b = parseEuro(text);
    return b == null || b <= 0 ? null : b;
  }

  /// Ein- oder Auszahlung mit Grund (GEL-05). Aus dem eigenen Portemonnaie;
  /// der Kassenwart darf die Kasse wählen ([kasse]).
  Eingabefehler bewegen({
    required bool einzahlung,
    required String betragText,
    required String grund,
    bool kasse = false,
  }) {
    final betrag = _betrag(betragText);
    final g = grund.trim().replaceAll(RegExp(r'\s+'), ' ');
    final fehler = Eingabefehler(
      preis: betrag == null ? _betragFehler.preis : null,
      grund: g.isEmpty ? 'Grund angeben, z. B. „Schiri bezahlt“.' : null,
    );
    if (!fehler.keine) return fehler;
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    final ausKasse = kasse && _ref.read(istKassenwartProvider);
    _beobachten(
      _schreiber.schreiben(
        einAuszahlungBatch(
          uid: sitzung.uid,
          bierwartName: sitzung.name,
          kasseId: sitzung.kasseId,
          buchungId: _schreiber.neueId(),
          einzahlung: einzahlung,
          ortId: ausKasse ? Ort.kasseId : sitzung.uid,
          betragCents: betrag!,
          grund: g,
          geraetZeit: DateTime.now(),
        ),
      ),
      'Die ${einzahlung ? 'Einzahlung' : 'Auszahlung'} über '
      '${formatEuro(betrag)}',
    );
    return const Eingabefehler();
  }

  /// Übergabe zwischen [portemonnaie] und Kasse (GEL-04), nur als
  /// Kassenwart. [inDieKasse]: vom Portemonnaie in die Kasse, sonst
  /// umgekehrt.
  Eingabefehler uebergeben(
    Ort portemonnaie,
    String betragText, {
    required bool inDieKasse,
  }) {
    final betrag = _betrag(betragText);
    if (betrag == null) return _betragFehler;
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    if (!_ref.read(istKassenwartProvider)) {
      return const Eingabefehler(
        allgemein: 'Übergaben bucht nur der Kassenwart.',
      );
    }
    _beobachten(
      _schreiber.schreiben(
        uebergabeBatch(
          uid: sitzung.uid,
          bierwartName: sitzung.name,
          kasseId: sitzung.kasseId,
          buchungId: _schreiber.neueId(),
          vonOrtId: inDieKasse ? portemonnaie.id : Ort.kasseId,
          nachOrtId: inDieKasse ? Ort.kasseId : portemonnaie.id,
          betragCents: betrag,
          geraetZeit: DateTime.now(),
        ),
      ),
      'Die Übergabe ${inDieKasse ? 'von' : 'an'} '
      '${vorname(portemonnaie.name)} über ${formatEuro(betrag)}',
    );
    return const Eingabefehler();
  }

  /// Kassensturz (GEL-06): Die Kasse steht danach auf dem gezählten Betrag,
  /// die Differenz kommt ins Log. Nur mit Netz. Stimmt der Stand auf dem
  /// Server nicht mehr mit [gesehenCents] überein, bucht die App nicht,
  /// damit nie eine andere Differenz gebucht wird als die angezeigte.
  Future<Eingabefehler> kassensturz(
    String gezaehltText, {
    required int gesehenCents,
  }) async {
    final gezaehlt = parseEuro(gezaehltText);
    if (gezaehlt == null) {
      return const Eingabefehler(
        preis: 'Gezählten Betrag wie 245,40 eingeben.',
      );
    }
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    const geaendert = Eingabefehler(
      allgemein:
          'Der Kassenstand hat sich gerade geändert. Prüf die Differenz '
          'noch einmal.',
    );
    try {
      final stand = await _ref
          .read(orteRepositoryProvider)
          .kasseVomServer(sitzung.kasseId)
          .timeout(antwortFrist);
      if (stand != gesehenCents) return geaendert;
      await _schreiber
          .schreiben(
            kassensturzBatch(
              uid: sitzung.uid,
              bierwartName: sitzung.name,
              kasseId: sitzung.kasseId,
              buchungId: _schreiber.neueId(),
              gezaehltCents: gezaehlt,
              differenzCents: gezaehlt - stand,
              geraetZeit: DateTime.now(),
            ),
          )
          .timeout(antwortFrist);
      return const Eingabefehler();
    } on TimeoutException {
      return const Eingabefehler(
        allgemein: 'Keine Antwort vom Server. Prüf dein Netz.',
      );
    } on FirebaseException catch (e) {
      return switch (e.code) {
        'unavailable' => const Eingabefehler(
          allgemein: 'Für den Kassensturz brauchst du Netz.',
        ),
        'permission-denied' => geaendert,
        _ => Eingabefehler(
          allgemein: 'Der Kassensturz ließ sich nicht speichern (${e.code}).',
        ),
      };
    }
  }
}

final geldAktionenProvider = Provider<GeldAktionen>(GeldAktionen.new);
