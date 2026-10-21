import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';

class BierwartApp extends ConsumerWidget {
  const BierwartApp({super.key, this.fonts = BwFonts.barlow});

  final BwFonts fonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Bierwart',
      debugShowCheckedModeBanner: false,
      theme: buildBierwartTheme(fonts: fonts),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
