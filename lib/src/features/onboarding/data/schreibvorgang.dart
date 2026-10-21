import 'dart:typed_data';

enum Art { set, update }

/// Ein Dokument eines Batches als reine Daten, ohne Firebase-Typen. So lässt
/// sich ein Batch mit `rules-tests/fixtures/` vergleichen, die dieselben
/// Batches gegen die Rules prüfen.
class Schreibvorgang {
  const Schreibvorgang(this.pfad, this.daten, {this.art = Art.set});

  const Schreibvorgang.update(this.pfad, this.daten) : art = Art.update;

  final String pfad;
  final Map<String, Object?> daten;
  final Art art;
}

/// Platzhalter für `FieldValue.serverTimestamp()`.
class Serverzeit {
  const Serverzeit();
}

/// Platzhalter für `FieldValue.increment()`: Summen addieren auf dem Server,
/// so geht bei gleichzeitigen Batches nichts verloren (NFA-03).
class Erhoehen {
  const Erhoehen(this.um);

  final int um;
}

/// Platzhalter für Firestore-Bytes.
class Bytes {
  const Bytes(this.wert);

  final Uint8List wert;
}
