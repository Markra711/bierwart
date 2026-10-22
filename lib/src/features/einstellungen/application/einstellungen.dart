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

extension AustretenUndAufloesen on VerwaltungAktionen {
  /// Austreten (UC-05, AUTH-09). Prüft Portemonnaie und Rollen am Stand des
  /// Servers; danach ist der Nutzer ohne Kasse.
  Future<void> austreten() =>
      mitServer('Austreten hat nicht geklappt', () async {
        final s = _ref.read(sitzungProvider);
        final ich = _ref
            .read(bierwarteProvider)
            .value
            ?.where((b) => b.uid == s?.uid)
            .firstOrNull;
        if (s == null || ich == null) {
          throw const VerwaltungsFehler('Die Kasse ist noch nicht geladen.');
        }
        final repo = _ref.read(einstellungenRepositoryProvider);
        final kasse = await repo
            .kasseFuerVerwaltung(s.kasseId)
            .timeout(antwortFrist);
        final stand = await repo
            .portemonnaieVomServer(s.kasseId, s.uid)
            .timeout(antwortFrist);
        final grund = austretenGeht(
          Bierwart(
            uid: s.uid,
            name: s.name,
            mitgliedId: ich.mitgliedId,
            istAdmin: kasse.adminUid == s.uid,
            istKassenwart: kasse.kassenwartUid == s.uid,
            portemonnaieCents: stand,
          ),
          anzahlBierwarte: kasse.anzahlBierwarte,
        );
        if (grund != null) throw VerwaltungsFehler(grund);
        await _schreiber
            .schreiben(
              austretenBatch(
                uid: s.uid,
                bierwartName: s.name,
                kasseId: s.kasseId,
                buchungId: _schreiber.neueId(),
                mitgliedId: ich.mitgliedId,
                einladungCode: kasse.einladungCode,
                letzter: kasse.anzahlBierwarte == 1,
                geraetZeit: DateTime.now(),
              ),
            )
            .timeout(antwortFrist);
      });

  /// Auflösen, Schritt 1 (ADM-05, UC-10): mit abgetipptem Kassennamen.
  /// Danach führt die App auf die Seite, die alles löscht.
  Future<void> aufloesen(String bestaetigung) =>
      _ausfuehren('Die Kasse ließ sich nicht auflösen', (s, kasse) {
        if (!aufloesenBestaetigt(bestaetigung, kasse.name)) {
          throw const VerwaltungsFehler('Der Name stimmt nicht genau.');
        }
        return aufloesenBatch(
          uid: s.uid,
          bierwartName: s.name,
          kasseId: s.kasseId,
          buchungId: _schreiber.neueId(),
          bestaetigung: kasse.name,
          geraetZeit: DateTime.now(),
        );
      });
}

extension Wiederherstellung on VerwaltungAktionen {
  /// Neuer Wiederherstellungscode (ADM-08), nur der Admin. Liefert den Code
  /// in normalisierter Form, damit die App ihn genau einmal zeigt.
  Future<String> codeErneuern() async {
    final code = zufallsCode(wiederherstellungscodeLaenge);
    await _ausfuehren(
      'Der Code ließ sich nicht erneuern',
      (s, kasse) => codeErneuernBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        buchungId: _schreiber.neueId(),
        neuerHash: hashVon(code),
        altHex: kasse.wiederherstellungHex,
        geraetZeit: DateTime.now(),
      ),
    );
    return code;
  }

  /// Mit dem Wiederherstellungscode Admin werden (ADM-06, UC-04). Der Code
  /// wird dabei ersetzt; der neue kommt zurück und wird einmal gezeigt.
  Future<String> adminWiederherstellen(String eingabe) async {
    final nachweis = normalisiereCode(eingabe);
    if (!istCode(nachweis, wiederherstellungscodeLaenge)) {
      throw const VerwaltungsFehler(
        'Der Code hat 16 Zeichen, z. B. K7QM-3XRA-9DWF-T2HC.',
      );
    }
    final aktive = {
      for (final b in _ref.read(bierwarteProvider).value ?? const <Bierwart>[])
        b.uid,
    };
    final code = zufallsCode(wiederherstellungscodeLaenge);
    await _ausfuehren('Die Wiederherstellung hat nicht geklappt', (s, kasse) {
      if (hexVon(hashVon(nachweis)) != kasse.wiederherstellungHex) {
        throw const VerwaltungsFehler('Der Code passt nicht zu dieser Kasse.');
      }
      return adminWiederherstellenBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        buchungId: _schreiber.neueId(),
        nachweis: nachweis,
        neuerHash: hashVon(code),
        // Ein verwaister Kassenwart geht mit (offene Frage 25).
        kassenwartUid: aktive.contains(kasse.kassenwartUid)
            ? kasse.kassenwartUid
            : s.uid,
        geraetZeit: DateTime.now(),
      );
    });
    return code;
  }
}

final verwaltungAktionenProvider = Provider<VerwaltungAktionen>(
  VerwaltungAktionen.new,
);
