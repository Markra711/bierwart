import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/flaechen.dart';

/// Rahmen der vier Tabs mit fester Leiste unten (UI-02, styleguide.md,
/// TabBar). Jeder Tab behält seinen Zustand beim Wechseln.
class AppRahmen extends StatelessWidget {
  const AppRahmen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [
    (label: 'Striche', icon: null),
    (label: 'Kader', icon: Icons.group_outlined),
    (label: 'Lager', icon: Icons.inventory_2_outlined),
    (label: 'Geld', icon: Icons.account_balance_wallet_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: _TabLeiste(
        aktiv: shell.currentIndex,
        waehlen: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

class _TabLeiste extends StatelessWidget {
  const _TabLeiste({required this.aktiv, required this.waehlen});

  final int aktiv;
  final ValueChanged<int> waehlen;

  static const hoehe = 82.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final stil = text.label.copyWith(letterSpacing: 0.06 * 11);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BwColors.bg,
        border: Border(top: BorderSide(color: BwColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: hoehe,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BwSpacing.space3,
              BwSpacing.space2,
              BwSpacing.space3,
              BwSpacing.space4,
            ),
            child: Row(
              children: [
                for (final (i, tab) in AppRahmen._tabs.indexed) ...[
                  if (i > 0) const SizedBox(width: BwSpacing.space2),
                  Expanded(
                    child: _Tab(
                      label: tab.label,
                      icon: tab.icon,
                      aktiv: i == aktiv,
                      stil: stil,
                      onTap: () => waehlen(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.aktiv,
    required this.stil,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool aktiv;
  final TextStyle stil;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final farbe = aktiv ? BwColors.ink : BwColors.inkMuted;
    Widget symbol = icon == null
        ? CustomPaint(size: const Size.square(22), painter: _StricheIcon(farbe))
        : Icon(icon, size: 22, color: farbe);
    Widget beschriftung = Text(
      label.toUpperCase(),
      style: stil.copyWith(color: farbe),
    );
    if (aktiv) {
      symbol = _verlauf(symbol);
      beschriftung = _verlauf(beschriftung);
    }
    final inhalt = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [symbol, const SizedBox(height: 3), beschriftung],
    );
    return Semantics(
      button: true,
      selected: aktiv,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: aktiv
            ? BwEingedrueckt(
                radius: BwRadius.md,
                schatten: BwShadows.insetSm,
                child: SizedBox.expand(child: inhalt),
              )
            : inhalt,
      ),
    );
  }

  static Widget _verlauf(Widget kind) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (r) => BwGradients.accent.createShader(r),
    child: kind,
  );
}

/// Strichliste als Strichliste: vier Striche, quer durchgestrichen.
class _StricheIcon extends CustomPainter {
  const _StricheIcon(this.farbe);

  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()
      ..color = farbe
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round;
    for (final x in [5.0, 10.0, 15.0, 20.0]) {
      canvas.drawLine(Offset(x * s, 4 * s), Offset(x * s, 20 * s), p);
    }
    canvas.drawLine(Offset(3 * s, 16 * s), Offset(22 * s, 8 * s), p);
  }

  @override
  bool shouldRepaint(_StricheIcon old) => old.farbe != farbe;
}
