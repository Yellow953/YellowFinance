import 'package:flutter/material.dart';

/// Official Google "G" logo rendered from the canonical SVG paths (viewBox 0 0 24 24).
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Scale from the 24x24 viewBox to the actual widget size
    canvas.scale(size.width / 24, size.height / 24);

    // Blue — top-right arc
    canvas.drawPath(
      _parse('M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92'
          'c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57'
          'c2.08-1.92 3.28-4.74 3.28-8.09z'),
      Paint()..color = const Color(0xFF4285F4),
    );

    // Green — bottom arc
    canvas.drawPath(
      _parse('M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77'
          'c-.98.66-2.23 1.06-3.71 1.06'
          'c-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84'
          'C3.99 20.53 7.7 23 12 23z'),
      Paint()..color = const Color(0xFF34A853),
    );

    // Yellow — left arc
    canvas.drawPath(
      _parse('M5.84 14.09c-.22-.66-.35-1.36-.35-2.09'
          's.13-1.43.35-2.09V7.07H2.18'
          'C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93'
          'l2.85-2.22.81-.62z'),
      Paint()..color = const Color(0xFFFBBC05),
    );

    // Red — top-left arc
    canvas.drawPath(
      _parse('M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15'
          'C17.45 2.09 14.97 1 12 1'
          'C7.7 1 3.99 3.47 2.18 7.07l3.66 2.84'
          'c.87-2.6 3.3-4.53 6.16-4.53z'),
      Paint()..color = const Color(0xFFEA4335),
    );
  }

  /// Parses a compact SVG path string into a Flutter [Path].
  Path _parse(String d) {
    final path = Path();
    // Tokenise: split on command letters while keeping them
    final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?')
        .allMatches(d)
        .map((m) => m.group(0)!)
        .toList();

    double cx = 0, cy = 0;
    String cmd = 'M';
    int i = 0;

    double next() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      final t = tokens[i];
      if (RegExp(r'[A-Za-z]').hasMatch(t)) {
        cmd = t;
        i++;
      }
      switch (cmd) {
        case 'M':
          cx = next(); cy = next();
          path.moveTo(cx, cy);
          cmd = 'L';
        case 'm':
          cx += next(); cy += next();
          path.moveTo(cx, cy);
          cmd = 'l';
        case 'L':
          cx = next(); cy = next();
          path.lineTo(cx, cy);
        case 'l':
          cx += next(); cy += next();
          path.lineTo(cx, cy);
        case 'H':
          cx = next();
          path.lineTo(cx, cy);
        case 'h':
          cx += next();
          path.lineTo(cx, cy);
        case 'V':
          cy = next();
          path.lineTo(cx, cy);
        case 'v':
          cy += next();
          path.lineTo(cx, cy);
        case 'C':
          final x1 = next(), y1 = next();
          final x2 = next(), y2 = next();
          cx = next(); cy = next();
          path.cubicTo(x1, y1, x2, y2, cx, cy);
        case 'c':
          final x1 = cx + next(), y1 = cy + next();
          final x2 = cx + next(), y2 = cy + next();
          final dx = next(), dy = next();
          path.cubicTo(x1, y1, x2, y2, cx + dx, cy + dy);
          cx += dx; cy += dy;
        case 'S':
          final x2 = next(), y2 = next();
          cx = next(); cy = next();
          path.conicTo(x2, y2, cx, cy, 1);
        case 's':
          final x2 = cx + next(), y2 = cy + next();
          final dx = next(), dy = next();
          path.conicTo(x2, y2, cx + dx, cy + dy, 1);
          cx += dx; cy += dy;
        case 'Z':
        case 'z':
          path.close();
        default:
          i++;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
