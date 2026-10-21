import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/fehler/fehlerkanal.dart';
import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';

class BierwartApp extends ConsumerStatefulWidget {
  const BierwartApp({super.key, this.fonts = BwFonts.barlow});

  final BwFonts fonts;

  @override
  ConsumerState<BierwartApp> createState() => _BierwartAppState();
}

class _BierwartAppState extends ConsumerState<BierwartApp> {
  final _meldungen = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    // Fehler aus dem Hintergrund, z. B. eine beim Sync abgelehnte Buchung,
    // erscheinen auf jedem Bildschirm (NFA-10).
    ref.listen(fehlerkanalProvider, (_, meldung) {
      if (meldung == null) return;
      _meldungen.currentState?.showSnackBar(
        SnackBar(
          content: Text(meldung.text),
          duration: const Duration(seconds: 6),
        ),
      );
    });
    return MaterialApp.router(
      title: 'Bierwart',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _meldungen,
      theme: buildBierwartTheme(fonts: widget.fonts),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
