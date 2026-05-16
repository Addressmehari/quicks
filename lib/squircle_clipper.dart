import 'dart:math';
import 'package:flutter/material.dart';

/// Superellipse (squircle) clipper.
/// Equation: |x/a|^n + |y/b|^n = 1
/// n=4 gives the classic squircle used by Apple/Instagram.
class SquircleClipper extends CustomClipper<Path> {
  final double n;

  const SquircleClipper({this.n = 4.0});

  @override
  Path getClip(Size size) {
    return buildSquirclePath(size, n: n);
  }

  @override
  bool shouldReclip(SquircleClipper oldClipper) => oldClipper.n != n;
}

/// Builds a superellipse path centered in [size].
Path buildSquirclePath(Size size, {double n = 4.0}) {
  final path = Path();
  final double a = size.width / 2;
  final double b = size.height / 2;
  final double cx = a;
  final double cy = b;

  // Number of points sampled around the curve (higher = smoother)
  const int steps = 360;
  final double exp = 2.0 / n; // parametric exponent

  for (int i = 0; i <= steps; i++) {
    final double t = (2 * pi * i) / steps;
    final double cosT = cos(t);
    final double sinT = sin(t);

    // Parametric superellipse: preserves sign while applying fractional power
    final double x = cx + a * _signedPow(cosT, exp);
    final double y = cy + b * _signedPow(sinT, exp);

    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }

  path.close();
  return path;
}

/// Raises [base] to [exp] while preserving sign: sign(base) * |base|^exp
double _signedPow(double base, double exp) {
  return base.sign * pow(base.abs(), exp).toDouble();
}

/// A widget that clips its child into a squircle shape.
class SquircleClip extends StatelessWidget {
  final Widget child;
  final double n;

  const SquircleClip({
    super.key,
    required this.child,
    this.n = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: SquircleClipper(n: n),
      child: child,
    );
  }
}

/// A squircle-shaped border for decorations (e.g. BoxDecoration + CustomPaint).
class SquircleBorder extends ShapeBorder {
  final BorderSide side;
  final double n;

  const SquircleBorder({this.side = BorderSide.none, this.n = 4.0});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return buildSquirclePath(rect.size, n: n)
        .shift(Offset(rect.left, rect.top));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return buildSquirclePath(rect.size, n: n)
        .shift(Offset(rect.left, rect.top));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side == BorderSide.none) return;
    final paint = side.toPaint();
    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => SquircleBorder(side: side.scale(t), n: n);
}
