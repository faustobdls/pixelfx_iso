// Depth-buffered dual-buffer frame and shared per-pixel occlusion compositing primitives.

import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

/// A [PixelFrame] augmented with an [Int16List] per-pixel painter depth key buffer.
class PixelIsoFrame extends PixelFrame {
  static const int kUnsetDepth = -32768;

  /// Quantized painter-order depth per pixel (`depth = (x + y) * 256 + z * 16`).
  final Int16List depth;

  PixelIsoFrame(super.w, super.h, [super.ox = 0, super.oy = 0])
      : depth = Int16List(w * h)..fillRange(0, w * h, kUnsetDepth);
}

PixelIsoFrame createIsoFrame(int w, int h, [int ox = 0, int oy = 0]) =>
    PixelIsoFrame(w, h, ox, oy);

PixelIsoFrame clearIsoFrame(PixelIsoFrame f) {
  clearFrame(f);
  f.depth.fillRange(0, f.depth.length, PixelIsoFrame.kUnsetDepth);
  return f;
}

/// Write opaque color [c] into [frame] + [depth] when [d] passes depth test (`d >= depth[idx]`).
@pragma('vm:prefer-inline')
void putDepthAtIndex(
  Uint32List colorBuf,
  Int16List depthBuf,
  int idx,
  int d,
  int c,
) {
  if (c == 0) return;
  if (d < depthBuf[idx]) return;
  colorBuf[idx] = c;
  depthBuf[idx] = d;
}

/// Depth-aware Porter-Duff source-over blend into [colorBuf] + [depthBuf].
void blendDepthAtIndex(
  Uint32List colorBuf,
  Int16List depthBuf,
  int idx,
  int d,
  int c, [
  double alpha = 1.0,
]) {
  if (c == 0 || !(alpha > 0.004)) return;
  if (d < depthBuf[idx]) return;
  final a = clamp(alpha) * ((c >>> 24) / 255.0);
  if (a >= 0.996) {
    colorBuf[idx] = rgba(red(c), green(c), blue(c), 255);
    depthBuf[idx] = d;
    return;
  }
  if (a <= 0.004) return;
  final dst = colorBuf[idx];
  final da = (dst >>> 24) / 255.0;
  final outA = a + da * (1.0 - a);
  if (outA <= 0.004) return;
  final r = ((red(c) * a + red(dst) * da * (1.0 - a)) / outA).round();
  final g = ((green(c) * a + green(dst) * da * (1.0 - a)) / outA).round();
  final b = ((blue(c) * a + blue(dst) * da * (1.0 - a)) / outA).round();
  colorBuf[idx] = rgba(r, g, b, (outA * 255.0).round());
  if (a > 0.35 && d > depthBuf[idx]) {
    depthBuf[idx] = d;
  }
}

/// Add glowing [lightColor] with soft attenuation when behind opaque geometry.
void addLightDepthAtIndex(
  Uint32List colorBuf,
  Uint32List lightBuf,
  Int16List depthBuf,
  int idx,
  int d,
  int lightColor,
  double k, {
  double occludedBleed = 0.25,
}) {
  if (lightColor == 0 || !(k > 0.004)) return;
  var effK = k;
  final existingD = depthBuf[idx];
  if (existingD != PixelIsoFrame.kUnsetDepth && d < existingD) {
    final dstA = colorBuf[idx] >>> 24;
    if (dstA > 16) {
      effK *= occludedBleed;
    }
  }
  if (!(effK > 0.004)) return;
  final cur = lightBuf[idx];
  final r = clampInt((cur & 255) + (red(lightColor) * effK).round(), 0, 255);
  final g = clampInt(
      ((cur >>> 8) & 255) + (green(lightColor) * effK).round(), 0, 255);
  final b = clampInt(
      ((cur >>> 16) & 255) + (blue(lightColor) * effK).round(), 0, 255);
  lightBuf[idx] = (r | (g << 8) | (b << 16)) & 0xffffffff;
}

/// Depth-checked pixel write into a [PixelIsoFrame] at buffer coordinates `(sx, sy)`.
void putDepth(PixelIsoFrame f, int sx, int sy, int d, int c) {
  if (sx < 0 || sy < 0 || sx >= f.w || sy >= f.h) return;
  putDepthAtIndex(f.color, f.depth, sy * f.w + sx, d, c);
}

/// Depth-checked translucent pixel write into a [PixelIsoFrame].
void blendDepth(
  PixelIsoFrame f,
  int sx,
  int sy,
  int d,
  int c, [
  double alpha = 1.0,
]) {
  if (sx < 0 || sy < 0 || sx >= f.w || sy >= f.h) return;
  blendDepthAtIndex(f.color, f.depth, sy * f.w + sx, d, c, alpha);
}

/// Depth-checked additive light accumulation with optional foreground bleed attenuation.
void addLightDepth(
  PixelIsoFrame f,
  int sx,
  int sy,
  int d,
  int lightColor,
  double k, {
  double occludedBleed = 0.25,
}) {
  if (sx < 0 || sy < 0 || sx >= f.w || sy >= f.h) return;
  addLightDepthAtIndex(
    f.color,
    f.light,
    f.depth,
    sy * f.w + sx,
    d,
    lightColor,
    k,
    occludedBleed: occludedBleed,
  );
}
