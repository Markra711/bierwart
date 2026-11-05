import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/verwaltung.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../../core/speicher/lokaler_speicher.dart';
import '../../geld/application/verlauf.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../data/anmeldung_repository.dart';
import '../data/uebernahme_batches.dart';
import '../data/uebernahme_repository.dart';
import '../domain/einladung.dart';
import '../domain/uebernahme.dart';
import 'onboarding.dart';

// „Das bin ich“ (UC-03, AUTH-07, ADR-0008). Das neue Gerät fragt an und
// wartet; ein aktiver Bierwart bestätigt oder lehnt ab. Alles braucht Netz
// und meldet Fehler als [VerwaltungsFehler] (NFA-10).

const _antwortFrist = Duration(seconds: 20);

/// Die Anfrage dieses Geräts, solange es wartet. Übersteht einen Neustart
/// über den Gerätespeicher.
class UebernahmeAnfrageNotifier extends Notifier<WartendeAnfrage?> {
  static const schluessel = 'wartendeAnfrage';

  @override
  WartendeAnfrage? build() {
    unawaited(_laden());
    return null;
  }

  LokalerSpeicher get _speicher => ref.read(lokalerSpeicherProvider);

  Future<void> _laden() async {
    try {
      final json = await _speicher.lesen(schluessel);
      if (state == null && json != null) {
        state = WartendeAnfrage.fromJson(jsonDecode(json));
      }
    } catch (_) {
      // Ohne Speicher geht nur das Warten nach einem Neustart verloren; die
      // Anfrage selbst bleibt beim Server und lässt sich neu stellen.
    }
  }

  void _setzen(WartendeAnfrage? neu) {
    state = neu;
    unawaited(
      _speicher
          .schreiben(schluessel, neu == null ? null : jsonEncode(neu.toJson()))
          .catchError((_) {}),
    );
  }

  /// „Das bin ich“: Anfrage für das Mitglied [mitgliedId] stellen.
  Future<void> anfragen(
    Einladung einladung, {
    required String mitgliedId,
    required String name,
  }) async {
    final meldung = einladung.zustand(DateTime.now()).meldung;
    if (meldung != null) throw VerwaltungsFehler(meldung);
    final schreiber = ref.read(schreiberProvider);
    final anfrageId = schreiber.neueId();
    await mitServer('Die Anfrage ließ sich nicht stellen', () async {
      final uid = await ref.read(anmeldungProvider.future);
      await schreiber
          .schreiben(
            uebernahmeAnfragenBatch(
              uid: uid,
              kasseId: einladung.kasseId,
              anfrageId: anfrageId,
              buchungId: schreiber.neueId(),
              mitgliedId: mitgliedId,
              einladungscode: einladung.code,
              eingetippterName: name,
              geraetZeit: DateTime.now(),
            ),
          )
          .timeout(_antwortFrist);
    });
    _setzen(
      WartendeAnfrage(
        kasseId: einladung.kasseId,
        anfrageId: anfrageId,
        mitgliedId: mitgliedId,
        name: name,
        kassenName: einladung.kassenName,
      ),
    );
    ref.read(offenerCodeProvider.notifier).verwerfen();
  }

  /// Das neue Gerät zieht die Anfrage zurück.
  Future<void> zurueckziehen() async {
    final w = state;
    if (w == null) return;
    await mitServer('Die Anfrage ließ sich nicht zurückziehen', () async {
      final uid = await ref.read(anmeldungProvider.future);
      final schreiber = ref.read(schreiberProvider);
      await schreiber
          .schreiben(
            uebernahmeZurueckziehenBatch(
              uid: uid,
              kasseId: w.kasseId,
              anfrageId: w.anfrageId,
              buchungId: schreiber.neueId(),
              mitgliedId: w.mitgliedId,
              eingetippterName: w.name,
              geraetZeit: DateTime.now(),
            ),
          )
          .timeout(_antwortFrist);
    });
    _setzen(null);
  }

  /// Nach der Bestätigung: Kasse in `users/{uid}` eintragen. Die Anfrage
  /// bleibt gemerkt, bis die Kasse da ist; dann verwirft der Router sie und
  /// führt auf die Strichliste.
  Future<void> abschliessen() async {
    final w = state;
    if (w == null) return;
    await mitServer('Der Einstieg in die Kasse hat nicht geklappt', () async {
      final uid = await ref.read(anmeldungProvider.future);
      await ref
          .read(schreiberProvider)
          .schreiben(uebernahmeAbschliessenBatch(uid: uid, kasseId: w.kasseId))
          .timeout(_antwortFrist);
    });
  }

  /// Nach Ablehnung oder Ablauf: zurück zum Start.
  void verwerfen() => _setzen(null);
}

final uebernahmeAnfrageProvider =
    NotifierProvider<UebernahmeAnfrageNotifier, WartendeAnfrage?>(
      UebernahmeAnfrageNotifier.new,
    );

/// Stand der eigenen Anfrage, live vom Server.
final eigeneAnfrageProvider = StreamProvider<Uebernahme?>((ref) {
  final w = ref.watch(uebernahmeAnfrageProvider);
  return w == null
      ? Stream.value(null)
      : ref.watch(uebernahmeRepositoryProvider).anfrage(w.kasseId, w.anfrageId);
});

/// Eine offene Anfrage, wie Bierwarte sie sehen.
class OffeneAnfrage {
  const OffeneAnfrage({
    required this.anfrage,
    required this.name,
    required this.binIch,
  });

  final Uebernahme anfrage;

  /// Name des Mitglieds, das übernommen werden soll.
  final String name;

  /// Das ist mein eigenes Mitglied: Jemand will auf ein neues Handy wechseln.
  final bool binIch;
}

final _offeneProvider = StreamProvider<List<Uebernahme>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const [])
      : ref.watch(uebernahmeRepositoryProvider).offene(k);
});

/// Offene, nicht abgelaufene Anfragen der Kasse, älteste zuerst (offene
/// Frage 23: Hinweis auf der Strichliste und in den Einstellungen).
final offeneAnfragenProvider = Provider<List<OffeneAnfrage>>((ref) {
  final namen = ref.watch(mitgliederNamenProvider).value ?? const {};
  final uid = ref.watch(anmeldungProvider).value;
  final eigene = {
    for (final m in ref.watch(mitgliederProvider).value ?? const [])
      if (uid != null && m.bierwartUid == uid) m.id,
  };
  final jetzt = DateTime.now();
  final liste = [
    for (final a in ref.watch(_offeneProvider).value ?? const <Uebernahme>[])
      if (a.istOffen(jetzt) && namen[a.mitgliedId] != null)
        OffeneAnfrage(
          anfrage: a,
          name: namen[a.mitgliedId]!,
          binIch: eigene.contains(a.mitgliedId),
        ),
  ];
  liste.sort(
    (x, y) => (x.anfrage.angefragtAm ?? jetzt).compareTo(
      y.anfrage.angefragtAm ?? jetzt,
    ),
  );
  return liste;
});

/// Bestätigen und Ablehnen durch einen aktiven Bierwart. Liest vorher vom
/// Server und wartet auf die Antwort (architecture.md, Verwaltung).
class UebernahmeAktionen {
  UebernahmeAktionen(this._ref);

  final Ref _ref;

  Future<void> bestaetigen(Uebernahme anfrage) =>
      mitServer('Die Bestätigung hat nicht geklappt', () async {
        final s = _sitzung();
        final stand = await _ref
            .read(uebernahmeRepositoryProvider)
            .standVomServer(s.kasseId, anfrage.id)
            .timeout(_antwortFrist);
        _nochOffen(stand.anfrage);
        final schreiber = _ref.read(schreiberProvider);
        await schreiber
            .schreiben(
              uebernahmeBestaetigenBatch(
                uid: s.uid,
                bierwartName: s.name,
                kasseId: s.kasseId,
                stand: stand,
                buchungId: schreiber.neueId(),
                geraetZeit: DateTime.now(),
              ),
            )
            .timeout(_antwortFrist);
      });

  Future<void> ablehnen(Uebernahme anfrage) =>
      mitServer('Die Ablehnung hat nicht geklappt', () async {
        final s = _sitzung();
        final schreiber = _ref.read(schreiberProvider);
        await schreiber
            .schreiben(
              uebernahmeAblehnenBatch(
                uid: s.uid,
                bierwartName: s.name,
                kasseId: s.kasseId,
                anfrage: anfrage,
                buchungId: schreiber.neueId(),
                geraetZeit: DateTime.now(),
              ),
            )
            .timeout(_antwortFrist);
      });

  Sitzung _sitzung() =>
      _ref.read(sitzungProvider) ??
      (throw const VerwaltungsFehler('Die Kasse ist noch nicht geladen.'));

  /// Hat inzwischen jemand anderes entschieden oder ist sie abgelaufen, sagt
  /// die App das, statt eine Ablehnung der Rules zu zeigen.
  void _nochOffen(Uebernahme a) {
    if (a.status != UebernahmeStatus.offen) {
      throw const VerwaltungsFehler(
        'Die Anfrage ist schon entschieden oder zurückgezogen.',
      );
    }
    if (a.istAbgelaufen(DateTime.now())) {
      throw const VerwaltungsFehler(
        'Die Anfrage ist abgelaufen. Sie gilt 7 Tage.',
      );
    }
  }
}

final uebernahmeAktionenProvider = Provider<UebernahmeAktionen>(
  UebernahmeAktionen.new,
);
