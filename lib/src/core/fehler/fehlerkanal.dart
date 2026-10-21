import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Eine Meldung im Fehlerkanal; [nr] unterscheidet zwei gleiche Texte.
class Fehlermeldung {
  const Fehlermeldung(this.nr, this.text);

  final int nr;
  final String text;
}

/// Fehler, die nicht mehr zu einem Bildschirm gehören: Eine offline
/// geschriebene Buchung lehnt der Server erst beim Sync ab, Firestore nimmt
/// sie zurück, und der Nutzer muss davon erfahren (NFA-10). Die App zeigt
/// jede Meldung als Snackbar.
class FehlerkanalNotifier extends Notifier<Fehlermeldung?> {
  var _nr = 0;

  @override
  Fehlermeldung? build() => null;

  void melden(String text) => state = Fehlermeldung(++_nr, text);

  /// Beobachtet ein Schreib-Future, ohne darauf zu warten. Schlägt es fehl,
  /// erscheint „[was] …“ im Kanal.
  void beobachten(Future<void> schreiben, String was) {
    unawaited(
      schreiben.catchError((Object e) {
        melden(switch (e) {
          FirebaseException(code: 'permission-denied') =>
            '$was hat der Server abgelehnt und zurückgenommen.',
          FirebaseException(:final code) =>
            '$was ließ sich nicht speichern ($code).',
          _ => '$was ließ sich nicht speichern.',
        });
      }),
    );
  }
}

final fehlerkanalProvider =
    NotifierProvider<FehlerkanalNotifier, Fehlermeldung?>(
      FehlerkanalNotifier.new,
    );
