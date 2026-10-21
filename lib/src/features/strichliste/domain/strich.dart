import '../../kader/domain/mitglied.dart';
import '../../lager/domain/sorte.dart';

/// Offen auf den Saldo (STR-02) oder sofort bar ins eigene Portemonnaie
/// (STR-03).
enum StrichArt { offen, bar }

/// Ein gebuchter Strich, wie ihn „Rückgängig“ braucht (STR-04).
class Strich {
  const Strich({
    required this.buchungId,
    required this.art,
    required this.mitglied,
    required this.sorte,
    required this.preisCents,
  });

  final String buchungId;
  final StrichArt art;
  final Mitglied mitglied;
  final Sorte sorte;

  /// Preis zum Zeitpunkt der Buchung (BES-02).
  final int preisCents;
}

/// Auf „Gäste“ wird immer bar gebucht, beim Tippen wie beim Halten (KAD-03).
StrichArt strichArtFuer(Mitglied mitglied, {required bool gehalten}) =>
    gehalten || mitglied.istGast ? StrichArt.bar : StrichArt.offen;
