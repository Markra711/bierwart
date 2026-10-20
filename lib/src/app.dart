import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';

class BierwartApp extends StatelessWidget {
  const BierwartApp({super.key, this.fonts = BwFonts.google});

  final BwFonts fonts;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bierwart',
      debugShowCheckedModeBanner: false,
      theme: buildBierwartTheme(fonts: fonts),
      themeMode: ThemeMode.dark,
      home: const _Platzhalter(),
    );
  }
}

/// Startseite bis zur Strichliste (UI-01).
class _Platzhalter extends StatelessWidget {
  const _Platzhalter();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BwSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BIERWART', style: text.screenTitle),
              const SizedBox(height: BwSpacing.space2),
              Text('Hier entsteht die Strichliste.', style: text.body),
            ],
          ),
        ),
      ),
    );
  }
}
