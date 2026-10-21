import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fehler/eingabefehler.dart';
import '../../../core/fehler/fehlerkanal.dart';
import '../../../core/firebase/batch_schreiber.dart';
import '../../../core/money/cents.dart';
import '../../kader/domain/name.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../data/sorte_batches.dart';
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
