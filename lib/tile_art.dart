import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Visual state of a rendered tile.
enum TileVisualState { normal, selected, hint }

/// Muted "ink" colours for the 12 glyphs. All are low-saturation so that the
/// designs read as a single elegant set and differences are subtle — this is
/// intentional to force pattern recognition (a healthy cognitive challenge).
const List<Color> _inks = [
  Color(0xFF6E7F63), // moss
  Color(0xFF7C6E5A), // walnut
  Color(0xFF5E7480), // slate teal
  Color(0xFF8A6E63), // clay
  Color(0xFF6C6E82), // dusty indigo
  Color(0xFF7E7A5C), // olive brass
  Color(0xFF63808A), // steel
  Color(0xFF87695F), // terracotta
  Color(0xFF6B7A6E), // sage
  Color(0xFF7A6B72), // mauve
  Color(0xFF60727E), // harbour
  Color(0xFF7D765E), // fawn
  Color(0xFF6F8079), // teal grey
  Color(0xFF80756B), // taupe
  Color(0xFF6A6F80), // periwinkle grey
  Color(0xFF7F6E6E), // rosewood
];

/// Normalise every glyph to the same brightness and saturation so no single
/// hue (e.g. terracotta rings) pops more than the others on the slate tile.
Color _uniformInk(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withLightness(0.54).withSaturation(0.30).toColor();
}

/// Paints a single premium, textured tile plus its vector glyph.
class TilePainter extends CustomPainter {
  TilePainter({
    required this.tileId,
    required this.state,
    this.glow = 0,
  });

  /// 1-based design id (0 = empty, not painted).
  final int tileId;
  final TileVisualState state;

  /// 0..1 pulse used for the hint highlight animation.
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (tileId <= 0) return;
    final rect = Offset.zero & size;
    final radius = size.shortestSide * 0.18;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(size.shortestSide * 0.035),
      Radius.circular(radius),
    );

    _paintFace(canvas, rrect, size);
    _paintGrain(canvas, rrect);
    _paintBevel(canvas, rrect);
    _paintGlyph(canvas, rrect.outerRect, tileId);
    _paintStateOverlay(canvas, rrect);
  }

  void _paintFace(Canvas canvas, RRect rrect, Size size) {
    // Soft drop shadow for a raised, tactile feel.
    canvas.drawRRect(
      rrect.shift(Offset(0, size.shortestSide * 0.03)),
      Paint()
        ..color = AppTheme.tileEdgeDark.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final face = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppTheme.tileTop, AppTheme.tileBottom],
      ).createShader(rrect.outerRect);
    canvas.drawRRect(rrect, face);
  }

  /// Subtle wood/slate grain — thin translucent horizontal strokes.
  void _paintGrain(Canvas canvas, RRect rrect) {
    canvas.save();
    canvas.clipRRect(rrect);
    final r = rrect.outerRect;
    final rnd = Random(tileId * 97 + 13);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.04);
    for (var i = 0; i < 7; i++) {
      final y = r.top + r.height * (i + 0.5) / 7;
      final path = Path()..moveTo(r.left, y);
      final segs = 6;
      for (var s = 1; s <= segs; s++) {
        final x = r.left + r.width * s / segs;
        final wobble = (rnd.nextDouble() - 0.5) * r.height * 0.03;
        path.lineTo(x, y + wobble);
      }
      canvas.drawPath(path, grain);
    }
    canvas.restore();
  }

  void _paintBevel(Canvas canvas, RRect rrect) {
    canvas.drawRRect(
      rrect.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppTheme.tileEdgeLight.withValues(alpha: 0.6),
    );
    // Top inner highlight.
    final r = rrect.outerRect;
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.4),
        rrect.tlRadius,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(r),
    );
    canvas.restore();
  }

  void _paintStateOverlay(Canvas canvas, RRect rrect) {
    if (state == TileVisualState.selected) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppTheme.tileSelected,
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = AppTheme.tileSelected.withValues(alpha: 0.14),
      );
    } else if (state == TileVisualState.hint) {
      final pulse = 0.65 + 0.35 * glow;
      // Outer halo so the hinted pair is easy to spot for older players.
      canvas.drawRRect(
        rrect.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = AppTheme.tileHint.withValues(alpha: pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = AppTheme.tileHint.withValues(alpha: pulse),
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = AppTheme.tileHint.withValues(alpha: 0.22 + 0.18 * glow),
      );
    }
  }

  // --- Glyphs -------------------------------------------------------------

  void _paintGlyph(Canvas canvas, Rect outer, int id) {
    final ink = _uniformInk(_inks[(id - 1) % _inks.length]);
    final side = outer.shortestSide;
    final box = Rect.fromCenter(
      center: outer.center,
      width: side * 0.56,
      height: side * 0.56,
    );
    canvas.save();
    canvas.translate(box.center.dx, box.center.dy);
    final unit = box.width / 2;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.030
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = ink.withValues(alpha: 0.85);
    final fillSoft = Paint()
      ..style = PaintingStyle.fill
      ..color = ink.withValues(alpha: 0.28);

    switch (id) {
      case 1:
      case 2:
      case 3:
        _leaf(canvas, unit, stroke, fillSoft, veins: id + 1, width: 0.62);
        break;
      case 4:
        _fern(canvas, unit, stroke);
        break;
      case 5:
      case 6:
      case 7:
        _rosette(canvas, unit, stroke, fillSoft, petals: id); // 5,6,7 petals
        break;
      case 8:
        _coin(canvas, unit, stroke, fillSoft);
        break;
      case 9:
      case 10:
        _bamboo(canvas, unit, stroke, fill, segments: id - 7); // 2,3 segments
        break;
      case 11:
      case 12:
        _hills(canvas, unit, stroke, ridges: id - 9); // 2,3 ridges
        break;
      case 13:
        _leaf(canvas, unit, stroke, fillSoft, veins: 6, width: 0.5);
        break;
      case 14:
        _rosette(canvas, unit, stroke, fillSoft, petals: 8);
        break;
      case 15:
        _bamboo(canvas, unit, stroke, fill, segments: 4);
        break;
      case 16:
        _hills(canvas, unit, stroke, ridges: 4);
        break;
      default:
        canvas.drawCircle(Offset.zero, unit * 0.5, stroke);
    }
    canvas.restore();
  }

  void _leaf(Canvas canvas, double u, Paint stroke, Paint fillSoft,
      {required int veins, required double width}) {
    final w = u * width;
    final path = Path()
      ..moveTo(0, -u)
      ..quadraticBezierTo(w, -u * 0.25, 0, u)
      ..quadraticBezierTo(-w, -u * 0.25, 0, -u)
      ..close();
    canvas.drawPath(path, fillSoft);
    canvas.drawPath(path, stroke);
    // Midrib.
    canvas.drawLine(Offset(0, -u * 0.92), Offset(0, u * 0.92), stroke);
    // Side veins.
    for (var i = 1; i <= veins; i++) {
      final t = i / (veins + 1);
      final y = -u + 2 * u * t;
      final vx = w * (1 - (2 * t - 1).abs()) * 0.85;
      canvas.drawLine(Offset(0, y), Offset(vx, y + u * 0.18), stroke);
      canvas.drawLine(Offset(0, y), Offset(-vx, y + u * 0.18), stroke);
    }
  }

  void _fern(Canvas canvas, double u, Paint stroke) {
    canvas.drawLine(Offset(0, u), Offset(0, -u), stroke);
    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      final y = u - 2 * u * t;
      final len = u * (0.7 - 0.5 * t) + u * 0.15;
      canvas.drawLine(Offset(0, y), Offset(len, y - len * 0.5), stroke);
      canvas.drawLine(Offset(0, y), Offset(-len, y - len * 0.5), stroke);
    }
  }

  void _rosette(Canvas canvas, double u, Paint stroke, Paint fillSoft,
      {required int petals}) {
    final r = u * 0.9;
    for (var i = 0; i < petals; i++) {
      final a = (i / petals) * 2 * pi - pi / 2;
      final cx = cos(a) * r * 0.5;
      final cy = sin(a) * r * 0.5;
      final petal = Rect.fromCenter(
        center: Offset(cx, cy),
        width: r * 0.7,
        height: r * 0.42,
      );
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(a);
      canvas.translate(-cx, -cy);
      canvas.drawOval(petal, fillSoft);
      canvas.drawOval(petal, stroke);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, r * 0.22, stroke);
  }

  void _coin(Canvas canvas, double u, Paint stroke, Paint fillSoft) {
    canvas.drawCircle(Offset.zero, u * 0.92, fillSoft);
    canvas.drawCircle(Offset.zero, u * 0.92, stroke);
    canvas.drawCircle(Offset.zero, u * 0.62, stroke);
    final hole = u * 0.32;
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: hole, height: hole),
      stroke,
    );
  }

  void _bamboo(Canvas canvas, double u, Paint stroke, Paint fill,
      {required int segments}) {
    final gap = 2 * u / segments;
    for (var i = 0; i < segments; i++) {
      final top = -u + i * gap + gap * 0.12;
      final bottom = -u + (i + 1) * gap - gap * 0.12;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTRB(-u * 0.28, top, u * 0.28, bottom),
        Radius.circular(u * 0.14),
      );
      canvas.drawRRect(rrect, stroke);
      canvas.drawLine(
        Offset(0, top + u * 0.08),
        Offset(0, bottom - u * 0.08),
        stroke,
      );
    }
  }

  void _hills(Canvas canvas, double u, Paint stroke, {required int ridges}) {
    for (var i = 0; i < ridges; i++) {
      final baseY = u * 0.75 - i * (u * 0.7);
      final path = Path()..moveTo(-u, baseY);
      path.quadraticBezierTo(-u * 0.4, baseY - u * 0.7, 0, baseY - u * 0.25);
      path.quadraticBezierTo(u * 0.4, baseY - u * 0.7, u, baseY);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant TilePainter old) =>
      old.tileId != tileId || old.state != state || old.glow != glow;
}
