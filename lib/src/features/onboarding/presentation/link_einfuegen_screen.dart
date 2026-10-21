import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../domain/codes.dart';

/// Link oder Code einfügen, wenn der Link nicht direkt die App geöffnet hat
/// (UC-02). Der Code wird beim Tippen erkannt.
class LinkEinfuegenScreen extends StatefulWidget {
  const LinkEinfuegenScreen({super.key});

  @override
  State<LinkEinfuegenScreen> createState() => _LinkEinfuegenScreenState();
}

class _LinkEinfuegenScreenState extends State<LinkEinfuegenScreen> {
  final _eingabe = TextEditingController();

  @override
  void initState() {
    super.initState();
    _eingabe.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _eingabe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final code = einladungscodeAus(_eingabe.text);
    void weiter() {
      if (code != null) context.go(Routen.mitCode(Routen.beitreten, code));
    }

    return BwSeite(
      zurueck: () => context.go(Routen.willkommen),
      inhalt: [
        const BwTitel(voll: 'Link', kontur: 'einfügen'),
        const BwErklaerung(
          'Am einfachsten tippst du den Link direkt in WhatsApp an. Hat das '
          'nicht geklappt, füg ihn hier ein. Der Code allein geht auch.',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BwFeld(
              label: 'Link oder Code',
              controller: _eingabe,
              autofocus: true,
              tastatur: TextInputType.url,
              eingabeAktion: TextInputAction.go,
              onSubmitted: (_) => weiter(),
              fehler: code == null && _eingabe.text.trim().isNotEmpty
                  ? 'Kein Code erkannt. Er hat 20 Zeichen.'
                  : null,
            ),
            if (code != null) ...[
              const SizedBox(height: BwSpacing.space2),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Erkannter Code: '),
                    TextSpan(
                      text: inGruppen(code),
                      style: text.amountM.copyWith(color: BwColors.positive),
                    ),
                  ],
                ),
                style: text.caption,
              ),
            ],
          ],
        ),
      ],
      aktionen: [
        BwKnopf(
          text: 'Weiter',
          gross: true,
          onPressed: code == null ? null : weiter,
        ),
      ],
    );
  }
}
