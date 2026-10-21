import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/fehler/fehlerkanal.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../../core/money/cents.dart';
import '../../kader/domain/name.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../../kader/application/kader_daten.dart';
import '../data/lager_batches.dart';
import '../data/sorte_batches.dart';
import '../data/sorten_repository.dart';
import '../domain/sorte.dart';

/// Sorte anlegen (BES-01). Wartet nicht auf den Server, das Sheet schließt
/// sofort; einen späteren Fehler meldet der Fehlerkanal (NFA-02, NFA-10).
Eingabefehler sorteAnlegen(Ref ref, String name, String preisText) {
  final preis = parseEuro(preisText);
  final fehler = Eingabefehler(
    name: namePruefen(name),
    preis: preis == null ? 'Preis wie 1,50 eingeben.' : null,
  );
  if (!fehler.keine) return fehler;
  final sitzung = ref.read(sitzungProvider);
  if (sitzung == null) {
    return const Eingabefehler(allgemein: 'Die Kasse ist noch nicht geladen.');
  }
  final schreiber = ref.read(schreiberProvider);
  final sorten = ref.read(sortenProvider).value ?? const <Sorte>[];
  final bereinigt = nameBereinigen(name);
  ref
      .read(fehlerkanalProvider.notifier)
      .beobachten(
        schreiber.schreiben(
          sorteAnlegenBatch(
            uid: sitzung.uid,
            bierwartName: sitzung.name,
            kasseId: sitzung.kasseId,
            sorteId: schreiber.neueId(),
            buchungId: schreiber.neueId(),
            name: bereinigt,
            preisCents: preis!,
            reihenfolge: naechsteReihenfolge(sorten),
            geraetZeit: DateTime.now(),
          ),
        ),
        'Die Sorte „$bereinigt“',
      );
  return const Eingabefehler();
}

final sorteAnlegenProvider = Provider<Eingabefehler Function(String, String)>(
  (ref) =>
      (name, preis) => sorteAnlegen(ref, name, preis),
);

/// Alle Sorten, sichtbare zuerst in Raster-Reihenfolge, dann ausgeblendete.
final alleSortenProvider = StreamProvider<List<Sorte>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const [])
      : ref
            .watch(sortenRepositoryProvider)
            .alle(k)
            .map(
              (alle) => [
                ...sortenFuerRaster(alle.where((s) => s.aktiv)),
                ...sortenFuerRaster(alle.where((s) => !s.aktiv)),
              ],
            );
});

/// Was Bierwarte im Lager tun: Sorten ändern, aus- und einblenden, Bestand
/// korrigieren, einkaufen. Ändern und Einkauf gehen offline und warten nicht
/// (NFA-02); die Korrektur braucht Netz und wartet auf den Server.
class LagerAktionen {
  LagerAktionen(this._ref, {this.antwortFrist = const Duration(seconds: 20)});

  final Ref _ref;
  final Duration antwortFrist;

  static const _nichtGeladen = Eingabefehler(
    allgemein: 'Die Kasse ist noch nicht geladen.',
  );

  Schreiber get _schreiber => _ref.read(schreiberProvider);

  void _beobachten(Future<void> schreiben, String was) =>
      _ref.read(fehlerkanalProvider.notifier).beobachten(schreiben, was);

  void _aendern(Sitzung s, Sorte sorte, String name, int preis, bool aktiv) =>
      _beobachten(
        _schreiber.schreiben(
          sorteAendernBatch(
            uid: s.uid,
            bierwartName: s.name,
            kasseId: s.kasseId,
            buchungId: _schreiber.neueId(),
            sorte: sorte,
            name: name,
            preisCents: preis,
            aktiv: aktiv,
            geraetZeit: DateTime.now(),
          ),
        ),
        'Die Änderung an „${sorte.name}“',
      );

  /// Name und Preis ändern (BES-01, BES-02). Ohne Änderung wird nichts
  /// geschrieben.
  Eingabefehler aendern(Sorte sorte, String name, String preisText) {
    final preis = parseEuro(preisText);
    final fehler = Eingabefehler(
      name: namePruefen(name),
      preis: preis == null ? 'Preis wie 1,50 eingeben.' : null,
    );
    if (!fehler.keine) return fehler;
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    final neu = nameBereinigen(name);
    if (neu != sorte.name || preis != sorte.preisCents) {
      _aendern(sitzung, sorte, neu, preis!, sorte.aktiv);
    }
    return const Eingabefehler();
  }

  /// Ausblenden oder wieder einblenden (BES-01). Ausgeblendete Sorten fehlen
  /// auf der Strichliste; ihre Striche bleiben.
  void sichtbar(Sorte sorte, {required bool aktiv}) {
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return;
    _aendern(sitzung, sorte, sorte.name, sorte.preisCents, aktiv);
  }

  /// Bestand auf einen gezählten Wert setzen (BES-06). Nur mit Netz: Die
  /// Differenz gilt zum Stand auf dem Server; hat sich der inzwischen
  /// geändert, lehnen die Rules ab, und die App bittet, neu zu zählen.
  Future<Eingabefehler> korrigieren(Sorte sorte, String gezaehltText) async {
    final gezaehlt = int.tryParse(gezaehltText.trim());
    if (gezaehlt == null || gezaehlt < 0) {
      return const Eingabefehler(
        anzahl: 'Gezählte Flaschen eingeben, z. B. 24.',
      );
    }
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    try {
      final stand = await _ref
          .read(sortenRepositoryProvider)
          .bestandVomServer(sitzung.kasseId, sorte.id)
          .timeout(antwortFrist);
      await _schreiber
          .schreiben(
            bestandKorrekturBatch(
              uid: sitzung.uid,
              bierwartName: sitzung.name,
              kasseId: sitzung.kasseId,
              buchungId: _schreiber.neueId(),
              sorteId: sorte.id,
              gezaehlt: gezaehlt,
              differenz: gezaehlt - stand,
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
      return Eingabefehler(
        allgemein: switch (e.code) {
          'unavailable' => 'Zum Zählen brauchst du Netz.',
          'permission-denied' =>
            'Der Bestand hat sich gerade geändert. Zähl bitte noch einmal.',
          _ => 'Die Korrektur ließ sich nicht speichern (${e.code}).',
        },
      );
    }
  }

  /// Einkauf (BES-04, BES-05): mehrere Sorten, ein Gesamtpreis. Bezahlt aus
  /// dem eigenen Portemonnaie; der Kassenwart darf die Kasse wählen.
  Eingabefehler einkaufen(
    Map<String, int> zeilen,
    String preisText, {
    bool ausDerKasse = false,
  }) {
    final preis = parseEuro(preisText);
    final fehler = Eingabefehler(
      allgemein: zeilen.isEmpty
          ? 'Mindestens eine Sorte mit Anzahl eintragen.'
          : zeilen.length > einkaufMaxSorten
          ? 'Höchstens $einkaufMaxSorten Sorten pro Einkauf.'
          : null,
      preis: preis == null ? 'Gesamtpreis wie 38,90 eingeben.' : null,
    );
    if (!fehler.keine) return fehler;
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    final kasse = ausDerKasse && _ref.read(istKassenwartProvider);
    final flaschen = zeilen.values.fold(0, (a, b) => a + b);
    _beobachten(
      _schreiber.schreiben(
        einkaufBatch(
          uid: sitzung.uid,
          bierwartName: sitzung.name,
          kasseId: sitzung.kasseId,
          buchungId: _schreiber.neueId(),
          zeilen: zeilen,
          betragCents: preis!,
          ortId: kasse ? 'kasse' : sitzung.uid,
          geraetZeit: DateTime.now(),
        ),
      ),
      'Der Einkauf über $flaschen Flaschen',
    );
    return const Eingabefehler();
  }
}

final lagerAktionenProvider = Provider<LagerAktionen>(LagerAktionen.new);
