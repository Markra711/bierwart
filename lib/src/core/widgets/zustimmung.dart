import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../links/link_oeffner.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Hinweis über dem Knopf beim Erstellen und Beitreten: Wer tippt, stimmt
/// den Nutzungsbedingungen zu (NFA-13). Ein Tipp auf den Hinweis öffnet sie.
class BwZustimmung extends ConsumerWidget {
  const BwZustimmung({required this.knopf, super.key});

  /// Beschriftung des Knopfs darunter, z. B. „Kasse erstellen“.
  final String knopf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.caption;
    return Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _oeffnen(context, ref),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Mit „$knopf“ stimmst du den '),
              const TextSpan(
                text: 'Nutzungsbedingungen',
                style: TextStyle(
                  color: BwColors.ink,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                  decorationColor: BwColors.ink,
                ),
              ),
              const TextSpan(text: ' zu.'),
            ],
          ),
          style: stil,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _oeffnen(BuildContext context, WidgetRef ref) async {
    final boten = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(linkOeffnerProvider)
        .oeffnen(nutzungsbedingungenUrl);
    if (!ok) {
      boten.showSnackBar(
        const SnackBar(
          content: Text(
            'Kein Browser gefunden. Die Bedingungen stehen unter '
            'bier-wart.web.app/nutzungsbedingungen.',
          ),
        ),
      );
    }
  }
}
