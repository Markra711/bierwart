import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/verwaltung.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../onboarding/application/onboarding.dart';
import '../../onboarding/data/anmeldung_repository.dart';
import '../data/einstellungen_repository.dart';
import '../data/verwaltung_batches.dart';

/// Wie weit das Löschen einer aufgelösten Kasse ist (ADM-05).
class Aufloesung {
  const Aufloesung({this.geloescht = 0, this.laeuft = false, this.fehler});

  final int geloescht;
  final bool laeuft;
  final String? fehler;
}

/// Löscht eine aufgelöste Kasse portionsweise, Sammlung für Sammlung, und
/// zuletzt Kasse, Einladung, Wiederherstellung und `users/{uid}`. Bricht es
/// ab, bleibt die Kasse aufgelöst; der nächste Start setzt fort
/// (architecture.md, Auflösen).
class AufloesenNotifier extends Notifier<Aufloesung> {
  static const antwortFrist = Duration(seconds: 20);

  @override
  Aufloesung build() => const Aufloesung();

  Future<void> loeschen() async {
    if (state.laeuft) return;
    final zustand = ref.read(startzustandProvider);
    if (zustand is! InAufloesung) return;
    final k = zustand.kasseId;
    state = Aufloesung(geloescht: state.geloescht, laeuft: true);
    try {
      await mitServer('Das Löschen ist hängen geblieben', () async {
        final uid = await ref.read(anmeldungProvider.future);
        final repo = ref.read(einstellungenRepositoryProvider);
        final schreiber = ref.read(schreiberProvider);
        final kasse = await repo.kasseFuerVerwaltung(k).timeout(antwortFrist);
        final eigener = 'kassen/$k/bierwarte/$uid';
        for (final sammlung in kassenSammlungen) {
          while (true) {
            final pfade = [
              for (final p
                  in await repo
                      .pfade(k, sammlung, loeschPortion + 1)
                      .timeout(antwortFrist))
                if (p != eigener) p,
            ].take(loeschPortion).toList();
            if (pfade.isEmpty) break;
            await schreiber.schreiben(loeschBatch(pfade)).timeout(antwortFrist);
            state = Aufloesung(
              geloescht: state.geloescht + pfade.length,
              laeuft: true,
            );
          }
        }
        await schreiber
            .schreiben(
              aufloesenSchlussBatch(
                uid: uid,
                kasseId: k,
                einladungCode: kasse.einladungCode,
                wiederherstellungHex: kasse.wiederherstellungHex,
              ),
            )
            .timeout(antwortFrist);
      });
      state = Aufloesung(geloescht: state.geloescht);
    } on VerwaltungsFehler catch (e) {
      state = Aufloesung(geloescht: state.geloescht, fehler: e.meldung);
    }
  }
}

final aufloesenProvider = NotifierProvider<AufloesenNotifier, Aufloesung>(
  AufloesenNotifier.new,
);
