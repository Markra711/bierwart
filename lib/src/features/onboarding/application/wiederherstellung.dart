import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/verwaltung.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../kader/domain/name.dart';
import '../data/anmeldung_repository.dart';
import '../data/wiederherstellung_batches.dart';
import '../data/wiederherstellung_repository.dart';
import '../domain/codes.dart';
import '../domain/wiederherstellung.dart';

enum WiederherstellungsSchritt { code, auswahl, neuerCode }

/// Stand der Wiederherstellung aus dem Onboarding (ADM-06, UC-03, UC-04).
class Wiederherstellung {
  const Wiederherstellung({
    this.schritt = WiederherstellungsSchritt.code,
    this.stand,
    this.nachweis,
    this.neuerCode,
    this.laeuft = false,
    this.fehler,
  });

  final WiederherstellungsSchritt schritt;
  final WiederherstellungsStand? stand;
  final String? nachweis;

  /// Der neue Code, genau einmal angezeigt.
  final String? neuerCode;
  final bool laeuft;
  final String? fehler;

  /// Die Weiterleitung hält den Nutzer hier, bis er den neuen Code gesehen
  /// hat, obwohl er schon in der Kasse ist.
  bool get haeltFest =>
      schritt == WiederherstellungsSchritt.neuerCode ||
      (laeuft && schritt == WiederherstellungsSchritt.auswahl);

  Wiederherstellung mit({bool? laeuft, String? fehler}) => Wiederherstellung(
    schritt: schritt,
    stand: stand,
    nachweis: nachweis,
    neuerCode: neuerCode,
    laeuft: laeuft ?? this.laeuft,
    fehler: fehler,
  );
}

/// Wer kein Bierwart mehr ist, kommt mit dem Wiederherstellungscode zurück
/// (ADR-0010): Code prüfen und Nachweis schreiben, Kasse lesen, als
/// bestehendes oder neues Mitglied eintreten und Admin werden.
class WiederherstellungNotifier extends Notifier<Wiederherstellung> {
  static const antwortFrist = Duration(seconds: 20);

  @override
  Wiederherstellung build() => const Wiederherstellung();

  Future<void> codePruefen(String eingabe) async {
    final nachweis = normalisiereCode(eingabe);
    if (!istCode(nachweis, wiederherstellungscodeLaenge)) {
      state = state.mit(
        fehler: 'Der Code hat 16 Zeichen, z. B. K7QM-3XRA-9DWF-T2HC.',
      );
      return;
    }
    state = state.mit(laeuft: true);
    try {
      final stand = await mitServer(
        'Der Code ließ sich nicht prüfen',
        () async {
          final repo = ref.read(wiederherstellungRepositoryProvider);
          final kasseId = await repo
              .kasseZumCode(nachweis)
              .timeout(antwortFrist);
          if (kasseId == null) {
            throw const VerwaltungsFehler(
              'Zu diesem Code gibt es keine Kasse.',
            );
          }
          final uid = await ref.read(anmeldungProvider.future);
          await ref
              .read(schreiberProvider)
              .schreiben(
                nachweisBatch(uid: uid, kasseId: kasseId, nachweis: nachweis),
              )
              .timeout(antwortFrist);
          return repo.laden(kasseId).timeout(antwortFrist);
        },
      );
      state = Wiederherstellung(
        schritt: WiederherstellungsSchritt.auswahl,
        stand: stand,
        nachweis: nachweis,
      );
    } on VerwaltungsFehler catch (e) {
      state = state.mit(laeuft: false, fehler: e.meldung);
    }
  }

  /// Als [kandidat] oder mit [neuerName] eintreten und Admin werden.
  Future<void> eintreten({Kandidat? kandidat, String? neuerName}) async {
    final stand = state.stand;
    final nachweis = state.nachweis;
    if (stand == null || nachweis == null) return;
    if (kandidat == null) {
      final fehler = namePruefen(neuerName ?? '');
      if (fehler != null) {
        state = state.mit(fehler: fehler);
        return;
      }
      if (stand.namenKeys.contains(nameKey(neuerName!))) {
        state = state.mit(
          fehler:
              'Den Namen gibt es in der Kasse schon. Bist du das, wähl '
              'ihn oben aus.',
        );
        return;
      }
    }
    state = state.mit(laeuft: true);
    final code = zufallsCode(wiederherstellungscodeLaenge);
    try {
      await mitServer('Die Wiederherstellung hat nicht geklappt', () async {
        final uid = await ref.read(anmeldungProvider.future);
        final schreiber = ref.read(schreiberProvider);
        await schreiber
            .schreiben(
              wiederherstellenBatch(
                uid: uid,
                stand: stand,
                buchungId: schreiber.neueId(),
                nachweis: nachweis,
                neuerHash: hashVon(code),
                neueMitgliedId: schreiber.neueId(),
                kandidat: kandidat,
                neuerName: kandidat == null ? neuerName : null,
                geraetZeit: DateTime.now(),
              ),
            )
            .timeout(antwortFrist);
      });
      state = Wiederherstellung(
        schritt: WiederherstellungsSchritt.neuerCode,
        stand: stand,
        neuerCode: code,
      );
    } on VerwaltungsFehler catch (e) {
      state = state.mit(laeuft: false, fehler: e.meldung);
    }
  }

  /// Zurück zur Eingabe des Codes.
  void zurueck() => state = const Wiederherstellung();

  /// Der neue Code ist gesehen; die Weiterleitung führt in die Kasse.
  void abschliessen() => state = const Wiederherstellung();
}

final wiederherstellungProvider =
    NotifierProvider<WiederherstellungNotifier, Wiederherstellung>(
      WiederherstellungNotifier.new,
    );
