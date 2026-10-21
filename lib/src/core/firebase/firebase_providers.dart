import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die Firebase-App aus `firebaseStarten()`; `main.dart` setzt sie. Gegen die
/// Emulatoren ist das nicht die Standard-App, deshalb nutzen alle Dienste
/// `instanceFor(app: …)`.
final firebaseAppProvider = Provider<FirebaseApp>((ref) => Firebase.app());

/// Zugriff auf Firebase nur über diese Provider. Repositories in `data/`
/// lesen sie, Widgets nie (CLAUDE.md, Schichten). Tests überschreiben sie.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instanceFor(app: ref.watch(firebaseAppProvider)),
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instanceFor(app: ref.watch(firebaseAppProvider)),
);
