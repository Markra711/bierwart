import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Bottom-Sheet für kurze Aktionen (UI-03, styleguide.md, Sheet): Fläche
/// `surface-float`, Griff, Titel im Stil `page-title`, Innenrand `space-6`.
/// Rückt mit der Tastatur nach oben.
Future<T?> zeigeSheet<T>(
  BuildContext context, {
  required String titel,
  required WidgetBuilder inhalt,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final text = Theme.of(context).extension<BwTextStyles>()!;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            BwSpacing.space6,
            BwSpacing.space3,
            BwSpacing.space6,
            BwSpacing.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: BwColors.lineStrong,
                      borderRadius: BorderRadius.all(
                        Radius.circular(BwRadius.pill),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BwSpacing.space5),
              Semantics(
                header: true,
                child: Text(titel.toUpperCase(), style: text.pageTitle),
              ),
              const SizedBox(height: BwSpacing.space5),
              inhalt(context),
            ],
          ),
        ),
      );
    },
  );
}
