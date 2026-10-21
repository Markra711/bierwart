import 'dart:typed_data';

enum Art { set, update, delete }

/// Ein Dokument eines Batches als reine Daten, ohne Firebase-Typen. So lässt
/// sich ein Batch mit `rules-tests/fixtures/` vergleichen, die dieselben
/// Batches gegen die Rules prüfen.
class Schreibvorgang {
  const Schreibvorgang(this.pfad, this.daten, {this.art = Art.set});

  const Schreibvorgang.update(this.pfad, this.daten) : art = Art.update;

  const Schreibvorgang.loeschen(this.pfad) : daten = const {}, art = Art.delete;

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

/// Stempel jeder Log-Buchung (LOG-01): wer, unter welchem Namen, wann laut
/// Server und wann laut Gerät. `am` prüfen die Rules gegen `request.time`.
Map<String, Object?> stempel({
  required String uid,
  required String name,
  required DateTime geraetZeit,
}) => {
  'uid': uid,
  'name': name,
  'am': const Serverzeit(),
  'geraetAm': geraetZeit,
};
