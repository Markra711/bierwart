import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/fehler/fehlerkanal.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../../core/firebase/schreibvorgang.dart';
import '../../../core/money/cents.dart';
import '../../geld/data/zahlung_batch.dart';
import '../../lager/domain/sorte.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../../strichliste/data/strich_batches.dart';
import '../../strichliste/domain/strich.dart';
import '../data/mitglied_batches.dart';
import '../data/mitglieder_repository.dart';
import '../domain/eintrag.dart';
import '../domain/mitglied.dart';
import '../domain/name.dart';
import 'kader_daten.dart';

/// Was Bierwarte im Kader tun: anlegen, umbenennen, entfernen, wieder
/// aufnehmen, Zahlungen erfassen, Striche stornieren. Geschrieben wird ohne
/// auf den Server zu warten; einen späteren Fehler meldet der Fehlerkanal
/// (NFA-02, NFA-10). Die Rules prüfen alles noch einmal (NFA-07).
class KaderAktionen {
  KaderAktionen(this._ref);

  final Ref _ref;

  static const _nichtGeladen = Eingabefehler(
    allgemein: 'Die Kasse ist noch nicht geladen.',
  );

  void _schreiben(List<Schreibvorgang> Function(Sitzung) batch, String was) {
    final sitzung = _ref.read(sitzungProvider)!;
    _ref
        .read(fehlerkanalProvider.notifier)
        .beobachten(
          _ref.read(schreiberProvider).schreiben(batch(sitzung)),
          was,
        );
  }

  String _id() => _ref.read(schreiberProvider).neueId();

  /// Wem der Name gehört: zuerst die geladenen Mitglieder, dann der Index,
  /// der auch entfernte kennt (KAD-08).
  Future<NamensBesitzer?> _besitzer(String kasseId, String name) async {
    final bekannt = _ref.read(mitgliederProvider).value ?? const [];
    for (final m in bekannt) {
      if (nameKey(m.name) == nameKey(name)) {
        return NamensBesitzer(mitgliedId: m.id, entfernt: false);
      }
    }
    return _ref.read(mitgliederRepositoryProvider).nameBelegt(kasseId, name);
  }

  /// Mitglied anlegen (KAD-01). Gehört der Name einem entfernten Mitglied,
  /// kommt dessen ID zurück, damit das Sheet „wieder aufnehmen“ anbietet.
  Future<Eingabefehler> anlegen(String name) async {
    final nameFehler = namePruefen(name);
    if (nameFehler != null) return Eingabefehler(name: nameFehler);
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    final bereinigt = nameBereinigen(name);
    final besitzer = await _besitzer(sitzung.kasseId, bereinigt);
    if (besitzer != null) {
      return besitzer.entfernt
          ? Eingabefehler(
              name: '„$bereinigt“ war schon Mitglied.',
              entferntesMitgliedId: besitzer.mitgliedId,
            )
          : Eingabefehler(name: '„$bereinigt“ gibt es in der Kasse schon.');
    }
    _schreiben(
      (s) => mitgliedAnlegenBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        mitgliedId: _id(),
        buchungId: _id(),
        name: bereinigt,
        geraetZeit: DateTime.now(),
      ),
      'Das Mitglied „$bereinigt“',
    );
    return const Eingabefehler();
  }

  /// Ein entferntes Mitglied mit Saldo und Verlauf zurückholen (KAD-08).
  void wiederaufnehmen(String mitgliedId, String name) => _schreiben(
    (s) => mitgliedEntfernenBatch(
      uid: s.uid,
      bierwartName: s.name,
      kasseId: s.kasseId,
      mitgliedId: mitgliedId,
      buchungId: _id(),
      entfernen: false,
      geraetZeit: DateTime.now(),
    ),
    'Das Wiederaufnehmen von „$name“',
  );

  /// Umbenennen (KAD-01, UI-09). Ist das Mitglied aktiver Bierwart, zieht
  /// der Name im Stempel mit.
  Future<Eingabefehler> umbenennen(Mitglied m, String neu) async {
    if (m.istGast) {
      return const Eingabefehler(name: '„Gäste“ behält seinen Namen.');
    }
    final nameFehler = namePruefen(neu);
    if (nameFehler != null) return Eingabefehler(name: nameFehler);
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    final bereinigt = nameBereinigen(neu);
    if (bereinigt == m.name) {
      return const Eingabefehler(name: 'Das ist schon der Name.');
    }
    // Die Rules verlangen einen anderen Schlüssel im Namensindex.
    if (nameKey(bereinigt) == nameKey(m.name)) {
      return const Eingabefehler(
        name: 'Nur Groß- und Kleinschreibung ändern geht noch nicht.',
      );
    }
    if (await _besitzer(sitzung.kasseId, bereinigt) != null) {
      return Eingabefehler(name: '„$bereinigt“ gibt es in der Kasse schon.');
    }
    final aktiv = _ref.read(aktiveBierwarteProvider).value ?? const {};
    final uid = m.bierwartUid;
    _schreiben(
      (s) => mitgliedUmbenennenBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        mitgliedId: m.id,
        buchungId: _id(),
        nameAlt: m.name,
        nameNeu: bereinigt,
        bierwartUid: uid != null && aktiv.contains(uid) ? uid : null,
        geraetZeit: DateTime.now(),
      ),
      'Das Umbenennen von „${m.name}“',
    );
    return const Eingabefehler();
  }

  /// Warum sich [m] nicht entfernen lässt, oder `null` (KAD-04, KAD-02).
  String? entfernenGeht(Mitglied m) {
    if (m.istGast) return '„Gäste“ lässt sich nicht entfernen.';
    if (m.saldoCents > 0) {
      return 'Entfernen geht erst, wenn nichts mehr offen ist.';
    }
    if (m.saldoCents < 0) {
      return 'Entfernen geht erst, wenn das Guthaben aufgebraucht ist.';
    }
    final aktiv = _ref.read(aktiveBierwarteProvider).value ?? const {};
    if (m.bierwartUid != null && aktiv.contains(m.bierwartUid)) {
      return 'Bierwarte bleiben Mitglied, solange sie dabei sind.';
    }
    return null;
  }

  /// Entfernen (KAD-04). Der Name bleibt reserviert (KAD-08).
  void entfernen(Mitglied m) {
    assert(entfernenGeht(m) == null);
    _schreiben(
      (s) => mitgliedEntfernenBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        mitgliedId: m.id,
        buchungId: _id(),
        entfernen: true,
        geraetZeit: DateTime.now(),
      ),
      'Das Entfernen von „${m.name}“',
    );
  }

  /// Zahlung erfassen (GEL-02, GEL-03): beliebige Höhe, Überzahlung wird
  /// Guthaben. Das Geld geht in das eigene Portemonnaie; der Kassenwart darf
  /// die Kasse wählen ([inDieKasse]).
  Eingabefehler zahlen(
    Mitglied m,
    String betragText, {
    bool inDieKasse = false,
  }) {
    final betrag = parseEuro(betragText);
    if (betrag == null || betrag <= 0) {
      return const Eingabefehler(preis: 'Betrag wie 12,00 eingeben.');
    }
    final sitzung = _ref.read(sitzungProvider);
    if (sitzung == null) return _nichtGeladen;
    final kasse = inDieKasse && _ref.read(istKassenwartProvider);
    _schreiben(
      (s) => zahlungBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        buchungId: _id(),
        mitgliedId: m.id,
        betragCents: betrag,
        ortId: kasse ? 'kasse' : s.uid,
        geraetZeit: DateTime.now(),
      ),
      'Die Zahlung von ${m.name} über ${formatEuro(betrag)}',
    );
    return const Eingabefehler();
  }

  /// Einen Strich im Mitglied-Detail stornieren (STR-06). Ein Bar-Strich
  /// geht aus dem Portemonnaie dessen, der storniert.
  void stornieren(Mitglied m, Eintrag e) {
    if (!e.istStrich || e.storniert || e.sorteId == null) return;
    _schreiben(
      (s) => stornoBatch(
        uid: s.uid,
        bierwartName: s.name,
        kasseId: s.kasseId,
        strich: Strich(
          buchungId: e.buchungId,
          art: e.art == EintragArt.strich ? StrichArt.offen : StrichArt.bar,
          mitglied: m,
          sorte: Sorte(
            id: e.sorteId!,
            name: '',
            preisCents: e.cents,
            bestand: 0,
            reihenfolge: 0,
          ),
          preisCents: e.cents,
        ),
        geraetZeit: DateTime.now(),
      ),
      'Das Storno für ${m.name}',
    );
  }
}

final kaderAktionenProvider = Provider<KaderAktionen>(KaderAktionen.new);
