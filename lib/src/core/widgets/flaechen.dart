import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Erhabene Fläche: antippbar oder hervorgehoben (styleguide.md, Fläche und
/// Tiefe).
class BwErhaben extends StatelessWidget {
  const BwErhaben({
    super.key,
    required this.child,
    this.radius = BwRadius.lg,
    this.schatten = BwShadows.raised,
    this.padding,
  });

  final Widget child;
  final double radius;
  final List<NeuShadow> schatten;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: BwColors.bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: BwShadows.boxShadows(schatten),
      ),
      child: child,
    );
  }
}

/// Eingedrückte Fläche: Eingabefelder, Anzeigen, Gewähltes. `BoxShadow`
/// kennt kein `inset`, deshalb zeichnet ein eigener Painter die inneren
/// Schatten aus den Tokens (offene Frage 16).
class BwEingedrueckt extends StatelessWidget {
  const BwEingedrueckt({
    super.key,
    required this.child,
    this.radius = BwRadius.lg,
    this.schatten = BwShadows.inset,
    this.padding,
    this.rahmen,
  });

  final Widget child;
  final double radius;
  final List<NeuShadow> schatten;
  final EdgeInsetsGeometry? padding;

  /// Optionaler Verlaufsrahmen, z. B. für das Feld mit Fokus.
  final Gradient? rahmen;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: InnenschattenPainter(
        radius: radius,
        schatten: schatten,
        rahmen: rahmen,
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

/// Zeichnet Grund, innere Schatten und optional einen Verlaufsrahmen.
/// CSS-Unschärfe `blur` entspricht einem Sigma von `blur / 2`.
class InnenschattenPainter extends CustomPainter {
  const InnenschattenPainter({
    required this.radius,
    required this.schatten,
    this.rahmen,
    this.rahmenBreite = 1.5,
  });

  final double radius;
  final List<NeuShadow> schatten;
  final Gradient? rahmen;
  final double rahmenBreite;

  @override
  void paint(Canvas canvas, Size size) {
    final flaeche = Offset.zero & size;
    final form = RRect.fromRectAndRadius(flaeche, Radius.circular(radius));
    canvas.drawRRect(form, Paint()..color = BwColors.bg);

    canvas.save();
    canvas.clipRRect(form);
    for (final s in schatten) {
      assert(s.inset, 'Nur innere Schatten.');
      // Ein Rahmen außerhalb der Form wirft seinen Schatten nach innen.
      final aussen = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(flaeche.inflate(s.blur * 2 + s.dx.abs() + s.dy.abs()))
        ..addRRect(form);
      canvas.drawPath(
        aussen.shift(Offset(s.dx, s.dy)),
        Paint()
          ..color = s.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2),
      );
    }
    canvas.restore();

    if (rahmen != null) {
      canvas.drawRRect(
        form.deflate(rahmenBreite / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rahmenBreite
          ..shader = rahmen!.createShader(flaeche),
      );
    }
  }

  @override
  bool shouldRepaint(InnenschattenPainter old) =>
      old.radius != radius || old.schatten != schatten || old.rahmen != rahmen;
}

/// Gestrichelter Rahmen (4px Strich, 4px Lücke), z. B. für deaktivierte
/// Buttons (styleguide.md, Wireframe-Details).
class GestricheltPainter extends CustomPainter {
  const GestricheltPainter({
    required this.radius,
    this.farbe = BwColors.lineStrong,
    this.breite = 1.5,
  });

  final double radius;
  final Color farbe;
  final double breite;

  @override
  void paint(Canvas canvas, Size size) {
    final form = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(breite / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = breite
      ..color = farbe;
    for (final metric in (Path()..addRRect(form)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(GestricheltPainter old) =>
      old.radius != radius || old.farbe != farbe || old.breite != breite;
}

/// Schraffierter Kreis als leise Deko (styleguide.md, Wireframe-Details).
class BwSchraffur extends StatelessWidget {
  const BwSchraffur({
    super.key,
    required this.durchmesser,
    this.farbe = BwColors.line,
    this.winkel = 0.785,
  });

  final double durchmesser;
  final Color farbe;

  /// Neigung der Linien im Bogenmaß; 0 = waagerecht.
  final double winkel;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(durchmesser),
        painter: _SchraffurPainter(farbe, winkel),
      ),
    );
  }
}

class _SchraffurPainter extends CustomPainter {
  const _SchraffurPainter(this.farbe, this.winkel);

  final Color farbe;
  final double winkel;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.translate(r, r);
    canvas.rotate(winkel);
    final paint = Paint()
      ..color = farbe
      ..strokeWidth = 1;
    for (var y = -r * 1.5; y < r * 1.5; y += 6) {
      canvas.drawLine(Offset(-r * 1.5, y), Offset(r * 1.5, y), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SchraffurPainter old) =>
      old.farbe != farbe || old.winkel != winkel;
}

/// Text mit dem Akzentverlauf (`grad-accent`).
class BwVerlaufText extends StatelessWidget {
  const BwVerlaufText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => BwGradients.accent.createShader(bounds),
      child: Text(text, style: style.copyWith(color: BwColors.ink)),
    );
  }
}

/// Konturschrift ohne Füllung, wie der helle Teil der Titel. `color` und
/// `foreground` schließen sich aus, deshalb ein neuer Stil.
TextStyle alsKontur(TextStyle style, {double breite = 1.2}) => TextStyle(
  fontFamily: style.fontFamily,
  fontSize: style.fontSize,
  fontWeight: style.fontWeight,
  letterSpacing: style.letterSpacing,
  height: style.height,
  fontFeatures: style.fontFeatures,
  foreground: Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = breite
    ..color = BwColors.ink
    ..strokeJoin = ui.StrokeJoin.round,
);
