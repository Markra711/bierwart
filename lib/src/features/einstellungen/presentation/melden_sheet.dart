import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/link_oeffner.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../kader/application/kader_daten.dart';
import '../../onboarding/data/anmeldung_repository.dart';

/// Anstößige Namen oder Bierwarte dem Betreiber melden (NFA-13). Die App
/// öffnet eine E-Mail mit Kassenname und -ID; was und wer, schreibt der
/// Nutzer selbst.
class MeldenSheet extends ConsumerWidget {
  const MeldenSheet({super.key});

  /// Die E-Mail an [kontaktEmail] mit der Kasse im Betreff und Text.
  static Uri mail({required String kassenName, required String kasseId}) => Uri(
    scheme: 'mailto',
    path: kontaktEmail,
    query: _query({
      'subject': 'Meldung: $kassenName',
      'body':
          'Kasse: $kassenName ($kasseId)\n\n'
          'Was ist passiert, und wer hat es eingetragen?\n',
    }),
  );

  // Uri.queryParameters kodiert Leerzeichen als „+“, Mail-Programme zeigen
  // das wörtlich. Deshalb von Hand mit %20.
  static String _query(Map<String, String> werte) => werte.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BwErklaerung(
          'Hat jemand etwas Beleidigendes oder Anstößiges eingetragen? Der '
          'Admin kann Namen ändern und Bierwarte entfernen. Hilft das nicht, '
          'schreib mir. Ich sehe mir die Kasse an und lösche, was gegen die '
          'Nutzungsbedingungen verstößt.',
        ),
        const SizedBox(height: BwSpacing.space5),
        BwKnopf(
          text: 'E-Mail schreiben',
          onPressed: () => _schreiben(context, ref),
        ),
        const SizedBox(height: BwSpacing.space3),
        BwKnopf(
          text: 'Nutzungsbedingungen',
          art: BwKnopfArt.sekundaer,
          onPressed: () => _bedingungen(context, ref),
        ),
      ],
    );
  }

  Future<void> _schreiben(BuildContext context, WidgetRef ref) async {
    final boten = ScaffoldMessenger.of(context);
    final ziel = mail(
      kassenName: ref.read(kasseInfoProvider).value?.name ?? '',
      kasseId: ref.read(meineKasseIdProvider).value ?? '',
    );
    if (!await ref.read(linkOeffnerProvider).oeffnen(ziel)) {
      boten.showSnackBar(
        const SnackBar(
          content: Text(
            'Kein Mail-Programm gefunden. Schreib an $kontaktEmail.',
          ),
        ),
      );
    }
  }

  Future<void> _bedingungen(BuildContext context, WidgetRef ref) async {
    final boten = ScaffoldMessenger.of(context);
    if (!await ref.read(linkOeffnerProvider).oeffnen(nutzungsbedingungenUrl)) {
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
