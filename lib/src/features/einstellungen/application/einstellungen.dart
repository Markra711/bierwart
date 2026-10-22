import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/verwaltung.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../../core/firebase/schreibvorgang.dart';
import '../../geld/application/geld.dart';
import '../../kader/application/kader_daten.dart';
import '../../kader/domain/name.dart';
import '../../onboarding/data/anmeldung_repository.dart';
import '../../onboarding/domain/codes.dart';
import '../../onboarding/domain/einladung.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../data/einstellungen_repository.dart';
import '../data/verwaltung_batches.dart';
import '../domain/bierwart.dart';

final _eintraegeProvider = StreamProvider<List<BierwartEintrag>>((ref) {
  final k = ref.watch(kasseIdProvider);
  return k == null
      ? Stream.value(const [])
      : ref.watch(einstellungenRepositoryProvider).bierwarte(k);
});

/// Die aktiven Bierwarte mit Rollen und Portemonnaie, eigener zuerst.
final bierwarteProvider = Provider<AsyncValue<List<Bierwart>>>((ref) {
  final uid = ref.watch(anmeldungProvider).value;
  final kasse = ref.watch(kasseInfoProvider).value;
  final staende = {
    for (final o in ref.watch(orteProvider).value ?? const [])
      o.id: o.standCents,
  };
  return ref
      .watch(_eintraegeProvider)
      .whenData(
        (eintraege) => bierwarteSortiert([
          for (final e in eintraege)
            Bierwart(
              uid: e.uid,
              name: e.name,
              mitgliedId: e.mitgliedId,
              istAdmin: kasse?.adminUid == e.uid,
              istKassenwart: kasse?.kassenwartUid == e.uid,
              portemonnaieCents: staende[e.uid] ?? 0,
            ),
        ], uid),
      );
});

/// Admin-Funktionen sind für andere unsichtbar; die Rules prüfen sie
/// trotzdem (NFA-07).
final istAdminProvider = Provider<bool>((ref) {
  final uid = ref.watch(anmeldungProvider).value;
  return uid != null && ref.watch(kasseInfoProvider).value?.adminUid == uid;
});

/// Die aktuelle Einladung der Kasse, für Link und „Gültig bis“.
final aktuelleEinladungProvider = StreamProvider<Einladung?>((ref) {
  final code = ref.watch(kasseInfoProvider).value?.einladungCode;
  return code == null || code.isEmpty
      ? Stream.value(null)
      : ref.watch(einstellungenRepositoryProvider).einladung(code);
});

/// Verwaltung durch den Admin (ADM-01 bis ADM-04). Jede Aktion braucht Netz:
/// Sie liest die Kasse vom Server, schreibt und wartet auf die Antwort. Eine
/// Ablehnung oder fehlendes Netz kommt als [VerwaltungsFehler] zurück
/// (NFA-10).
class VerwaltungAktionen {
  VerwaltungAktionen(
    this._ref, {
    this.antwortFrist = const Duration(seconds: 20),
  });

  final Ref _ref;
  final Duration antwortFrist;

  Schreiber get _schreiber => _ref.read(schreiberProvider);

  Future<void> _ausfuehren(
    String sonst,
    List<Schreibvorgang> Function(Sitzung s, KasseVomServer kasse) batch,
  ) => mitServer(sonst, () async {
    final s = _ref.read(sitzungProvider);
    if (s == null) {
      throw const VerwaltungsFehler('Die Kasse ist noch nicht geladen.');
    }
    final kasse = await _ref
        .read(einstellungenRepositoryProvider)
        .kasseFuerVerwaltung(s.kasseId)
        .timeout(antwortFrist);
    await _schreiber.schreiben(batch(s, kasse)).timeout(antwortFrist);
  });

  /// Neuer Einladungslink, der alte gilt sofort nicht mehr (ADM-01).
  Future<void> linkErneuern() => _ausfuehren(
    'Der Link ließ sich nicht erneuern',
    (s, kasse) => linkErneuernBatch(
      uid: s.uid,
      bierwartName: s.name,
      kasseId: s.kasseId,
      buchungId: _schreiber.neueId(),
      alterCode: kasse.einladungCode,
      neuerCode: zufallsCode(einladungscodeLaenge),
      kassenName: kasse.name,
      anzahlBierwarte: kasse.anzahlBierwarte,
      geraetZeit: DateTime.now(),
    ),
  );

  /// Bierwart entfernen (ADM-02): bleibt Mitglied, Link wird erneuert.
  Future<void> entfernen(Bierwart wer) {
    final grund = entfernenGeht(wer);
    if (grund != null) return Future.error(VerwaltungsFehler(grund));
    return _ausfuehren(
      '${wer.name} ließ sich nicht entfernen',
      (s, kasse) => bierwartEntfernenBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        buchungId: _schreiber.neueId(),
        wer: wer,
        alterCode: kasse.einladungCode,
        neuerCode: zufallsCode(einladungscodeLaenge),
        kassenName: kasse.name,
        anzahlBierwarte: kasse.anzahlBierwarte,
        geraetZeit: DateTime.now(),
      ),
    );
  }

  /// Kassenwart bestimmen oder Admin-Rolle übergeben (ADM-03).
  Future<void> rolleUebertragen(Rolle rolle, Bierwart an) => _ausfuehren(
    'Die Rolle ließ sich nicht übertragen',
    (s, kasse) => rolleBatch(
      uid: s.uid,
      bierwartName: s.name,
      kasseId: s.kasseId,
      buchungId: _schreiber.neueId(),
      rolle: rolle,
      vonUid: rolle == Rolle.admin ? kasse.adminUid : kasse.kassenwartUid,
      nachUid: an.uid,
      geraetZeit: DateTime.now(),
    ),
  );

  /// Kasse umbenennen (ADM-04). Liefert eine Meldung zum Namen oder `null`.
  Future<String?> kasseUmbenennen(String neu) async {
    final fehler = namePruefen(neu);
    if (fehler != null) return fehler;
    final name = nameBereinigen(neu);
    if (name == _ref.read(kasseInfoProvider).value?.name) {
      return 'So heißt die Kasse schon.';
    }
    await _ausfuehren(
      'Die Kasse ließ sich nicht umbenennen',
      (s, kasse) => kasseUmbenennenBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        buchungId: _schreiber.neueId(),
        nameAlt: kasse.name,
        nameNeu: name,
        einladungCode: kasse.einladungCode,
        geraetZeit: DateTime.now(),
      ),
    );
    return null;
  }
}

final verwaltungAktionenProvider = Provider<VerwaltungAktionen>(
  VerwaltungAktionen.new,
);
