import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tab_kopf.dart';

/// Gerüst eines Tabs: Kopf und Inhalt scrollen zusammen, Seitenrand
/// `space-5`. [unten] liegt über dem Inhalt am unteren Rand, z. B. die
/// Snackbar mit „Rückgängig“.
class BwTabSeite extends StatelessWidget {
  const BwTabSeite({
    super.key,
    required this.nummer,
    required this.titel,
    required this.kassenName,
    required this.einstellungen,
    required this.kinder,
    this.unten,
  });

  final String nummer;
  final String titel;
  final String? kassenName;
  final VoidCallback einstellungen;
  final List<Widget> kinder;
  final Widget? unten;

  /// Platz unter dem Inhalt, damit [unten] nichts verdeckt.
  static const _untenFrei = BwSpacing.space6 * 4;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              BwSpacing.space5,
              BwSpacing.space2,
              BwSpacing.space5,
              unten == null ? BwSpacing.space6 : _untenFrei,
            ),
            children: [
              BwTabKopf(
                nummer: nummer,
                titel: titel,
                kassenName: kassenName,
                einstellungen: einstellungen,
              ),
              for (final k in kinder) ...[
                const SizedBox(height: BwSpacing.space4),
                k,
              ],
            ],
          ),
          if (unten != null)
            Positioned(
              left: BwSpacing.space4,
              right: BwSpacing.space4,
              bottom: BwSpacing.space3,
              child: unten!,
            ),
        ],
      ),
    );
  }
}
