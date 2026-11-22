// Crisp 2:1 dimetric diamond grid backdrop & subtle outer studio vignette.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

final int _vignetteDark = hex('#0d0b14');
final int _tileEven = hex('#1c1829');
final int _tileOdd = hex('#181524');
final int _diamondLine = hex('#312a47');

/// Build an isometric 2:1 diamond grid background buffer of [w] x [h] pixels.
Uint32List isoDiamondBackdrop(
  int w,
  int h, {
  int? originX,
  int? originY,
  int tileHalfW = 16,
  int tileHalfH = 8,
  bool vignette = true,
}) {
  final out = Uint32List(w * h);
  final cx = originX ?? (w ~/ 2);
  final cy = originY ?? (h * 0.65).round();
  final span = math.max(2, tileHalfW + tileHalfH * 2);
  final rx = math.max(1.0, w * 0.58);
  final ry = math.max(1.0, h * 0.58);

  for (var y = 0; y < h; y++) {
    final dy = y - cy;
    for (var x = 0; x < w; x++) {
      final dx = x - cx;
      final a = dx * tileHalfH + dy * tileHalfW;
      final b = dy * tileHalfW - dx * tileHalfH;
      final cellStep = 2 * tileHalfW * tileHalfH;
      final tx = (a / cellStep).floor();
      final ty = (b / cellStep).floor();
      final ra = a - tx * cellStep;
      final rb = b - ty * cellStep;
      final edgeTol = span ~/ 2;
      final edge = ra < edgeTol || rb < edgeTol;
      var c = edge ? _diamondLine : (((tx + ty) & 1) == 0 ? _tileEven : _tileOdd);
      if (vignette) {
        final dist = math.sqrt((dx / rx) * (dx / rx) + (dy / ry) * (dy / ry));
        final vig = clamp((dist - 0.55) / 0.55) * 0.72;
        if (vig > 0.0) c = mix(c, _vignetteDark, vig);
      }
      out[y * w + x] = c;
    }
  }
  return out;
}
