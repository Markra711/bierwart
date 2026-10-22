import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Fehler einer Verwaltungsaktion mit einer Meldung für den Nutzer (NFA-10).
class VerwaltungsFehler implements Exception {
  const VerwaltungsFehler(this.meldung);

  final String meldung;

  @override
  String toString() => meldung;
}

/// Führt eine Verwaltungsaktion aus und übersetzt Firebase-Fehler und
/// Zeitüberschreitung in [VerwaltungsFehler] (NFA-10). [sonst] beginnt die
/// Meldung für unbekannte Fehler.
Future<T> mitServer<T>(String sonst, Future<T> Function() aktion) async {
  try {
    return await aktion();
  } on TimeoutException {
    throw const VerwaltungsFehler(
      'Keine Antwort vom Server. Prüf dein Netz und versuch es noch einmal.',
    );
  } on FirebaseException catch (e) {
    throw VerwaltungsFehler(switch (e.code) {
      'unavailable' => 'Dafür brauchst du Netz.',
      // Kann vieles heißen (andere Kasse, Rules nicht deployt), daher
      // keine Vermutung, aber der Code für die Fehlersuche.
      'permission-denied' => 'Der Server hat abgelehnt (permission-denied).',
      _ => '$sonst (${e.code}).',
    });
  }
}
