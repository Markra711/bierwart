import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// Startseite (UI-01). Bis zur echten Strichliste ein Platzhalter.
class StrichlisteScreen extends StatelessWidget {
  const StrichlisteScreen({super.key});

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
