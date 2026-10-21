import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/core/firebase/emulatoren.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: optionenFuer(
      DefaultFirebaseOptions.currentPlatform,
      emulatoren: useEmulators,
    ),
  );
  if (useEmulators) {
    await mitEmulatorenVerbinden(
      FirebaseAuth.instance,
      FirebaseFirestore.instance,
    );
  }
  runApp(const ProviderScope(child: BierwartApp()));
}
