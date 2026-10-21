import 'dart:typed_data';

/// Ein Dokument eines Batches als reine Daten, ohne Firebase-Typen. So lässt
/// sich ein Batch mit `rules-tests/fixtures/` vergleichen, die dieselben
/// Batches gegen die Rules prüfen.
class Schreibvorgang {
  const Schreibvorgang(this.pfad, this.daten);

  final String pfad;
  final Map<String, Object?> daten;
}

/// Platzhalter für `FieldValue.serverTimestamp()`.
class Serverzeit {
  const Serverzeit();
}

/// Platzhalter für Firestore-Bytes.
class Bytes {
  const Bytes(this.wert);

  final Uint8List wert;
}
