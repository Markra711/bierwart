import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/firebase/emulatoren.dart';
import 'src/core/firebase/firebase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await firebaseStarten();
  runApp(
    ProviderScope(
      overrides: [firebaseAppProvider.overrideWithValue(app)],
      child: const BierwartApp(),
    ),
  );
}
