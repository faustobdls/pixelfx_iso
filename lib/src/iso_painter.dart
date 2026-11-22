// Depth-buffered 2.5D isometric raster primitives with crisp 2:1 dimetric alignment.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'iso_frame.dart';
import 'projection.dart';

final int _kShadowCol = hex('#100e17');

/// Manages optional depth scratch storage when rendering isometric primitives onto a [PixelFrame].
final Expando<Int16List> _scratchDepth = Expando<Int16List>('isoDepth');

Int16List isoDepthBufferFor(PixelFrame frame) {
  if (frame is PixelIsoFrame) return frame.depth;
  var buf = _scratchDepth[frame];
  final len = frame.w * frame.h;
  if (buf == null || buf.length != len) {
    buf = Int16List(len)..fillRange(0, len, PixelIsoFrame.kUnsetDepth);
    _scratchDepth[frame] = buf;
  }
  return buf;
}

/// Reset scratch depth buffer associated with [frame] (automatic for [PixelIsoFrame] via `clearIsoFrame`).
void clearIsoDepth(PixelFrame frame) {
  final buf = isoDepthBufferFor(frame);
  buf.fillRange(0, buf.length, PixelIsoFrame.kUnsetDepth);
}

/// Depth-buffered isometric primitive painter wrapping either [PixelIsoFrame] or plain [PixelFrame].
class IsoPainter {
  final PixelFrame frame;
  final IsoProjection projection;
  late Int16List _depth;

  double tx = 0.0;
  double ty = 0.0;
  double fade = 1.0;
  double lightK = 1.0;

  IsoPainter(
    this.frame, {
    this.projection = const IsoProjection.standard(),
    bool clearScratchDepth = false,
  }) {
    _depth = isoDepthBufferFor(frame);
    if (clearScratchDepth) {
      _depth.fillRange(0, _depth.length, PixelIsoFrame.kUnsetDepth);
    }
  }

  /// Wrap the frame owned by a 2D [Painter], inheriting placement, [fade], and [lightK].
  factory IsoPainter.fromPainter(
    Painter p, {
    IsoProjection projection = const IsoProjection.standard(),
    bool clearDepth = true,
  }) =>
      IsoPainter(
        p.frame,
        projection: projection,
        clearScratchDepth: clearDepth,
      )
        ..tx = p.tx
        ..ty = p.ty
        ..fade = p.fade
        ..lightK = p.lightK;

  IsoPainter place(double x, double y) {
    tx = x;
    ty = y;
    return this;
  }

  IsoPainter clearDepth() {
    _depth.fillRange(0, _depth.length, PixelIsoFrame.kUnsetDepth);
    return this;
  }

  @pragma('vm:prefer-inline')
  bool _fadePass(int sx, int sy) {
    if (fade >= 0.996) return true;
    if (!(fade > 0.004)) return false;
    const bayer = [
      0.5 / 16, 8.5 / 16, 2.5 / 16, 10.5 / 16,
      12.5 / 16, 4.5 / 16, 14.5 / 16, 6.5 / 16,
      3.5 / 16, 11.5 / 16, 1.5 / 16, 9.5 / 16,
      15.5 / 16, 7.5 / 16, 13.5 / 16, 5.5 / 16,
    ];
    return fade > bayer[((sy & 3) << 2) | (sx & 3)];
  }

  /// Plot a depth-tested screen pixel `(sx, sy)` in buffer coordinates.
  @pragma('vm:prefer-inline')
  void plotScreen(int sx, int sy, int depthKey, int c, [double a = 1.0]) {
    final bx = sx - frame.ox;
    final by = sy - frame.oy;
    if (bx < 0 || by < 0 || bx >= frame.w || by >= frame.h) return;
    if (c == 0 || !(a > 0.004) || !_fadePass(bx, by)) return;
    final idx = by * frame.w + bx;
    if (a >= 0.996 && (c >>> 24) == 255) {
      putDepthAtIndex(frame.color, _depth, idx, depthKey, c);
    } else {
      blendDepthAtIndex(frame.color, _depth, idx, depthKey, c, a);
    }
  }

  /// Plot a world-space voxel/pixel at `(x, y, z)`.
  @pragma('vm:prefer-inline')
  void isoPixel(double x, double y, double z, int c, [double a = 1.0]) {
    final (lx, ly) = projection.project(x, y, z);
    final sx = isoSnap(tx + lx);
    final sy = isoSnap(ty + ly);
    plotScreen(sx, sy, projection.depthKey(x, y, z), c, a);
  }

  /// Draw a 2:1 elliptical contact shadow projected onto ground plane elevation [z].
  void isoShadow(
    double cx,
    double cy,
    double z,
    double rx, [
    double? ry,
    double k = 0.55,
  ]) {
    if (rx <= 0.05 || !(k > 0.004)) return;
    final ryy = ry ?? rx;
    final pxPerUnitX = projection.tileHalfW * 2.0;
    final stepsU = math.max(4, (rx * pxPerUnitX * 1.5).ceil());
    final stepsV = math.max(4, (ryy * pxPerUnitX * 1.5).ceil());
    for (var iv = -stepsV; iv <= stepsV; iv++) {
      final v = (iv / stepsV) * ryy;
      for (var iu = -stepsU; iu <= stepsU; iu++) {
        final u = (iu / stepsU) * rx;
        final d2 = (u * u) / (rx * rx) + (v * v) / (ryy * ryy);
        if (d2 > 1.0) continue;
        final alpha = k * (1.0 - d2 * 0.75);
        final (lx, ly) = projection.project(cx + u, cy + v, z);
        plotScreen(
          isoSnap(tx + lx),
          isoSnap(ty + ly),
          projection.depthKey(cx + u, cy + v, z - 0.02),
          _kShadowCol,
          alpha,
        );
      }
    }
  }

  /// Draw a shaded axis-aligned isometric prism with top-left highlight bevel & optional 1px ink outline.
  void isoBox(
    double x,
    double y,
    double z,
    double dx,
    double dy,
    double dz, {
    required int topCol,
    required int leftCol,
    required int rightCol,
    int? bevelCol,
    int? outlineCol,
    double outlineBias = 0.0,
  }) {
    final samplesU = math.max(6, (dx * projection.tileHalfW * 2.2).ceil());
    final samplesV = math.max(6, (dy * projection.tileHalfW * 2.2).ceil());
    final samplesZ = math.max(4, (dz * projection.zScale * 1.5).ceil());
    final touched = outlineCol != null ? <int, int>{} : null;

    void writeFacePixel(double wx, double wy, double wz, double bias, int c) {
      final (lx, ly) = projection.project(wx, wy, wz);
      final sx = isoSnap(tx + lx);
      final sy = isoSnap(ty + ly);
      final bx = sx - frame.ox;
      final by = sy - frame.oy;
      if (bx < 0 || by < 0 || bx >= frame.w || by >= frame.h) return;
      if (!_fadePass(bx, by)) return;
      final dk = projection.depthKey(wx, wy, wz + bias);
      final idx = by * frame.w + bx;
      putDepthAtIndex(frame.color, _depth, idx, dk, c);
      if (touched != null) {
        final prev = touched[idx];
        if (prev == null || dk > prev) touched[idx] = dk;
      }
    }

    // Left visible face (+y side: south-west facing).
    for (var ih = 0; ih <= samplesZ; ih++) {
      final hVal = (ih / samplesZ) * dz;
      for (var iu = 0; iu <= samplesU; iu++) {
        final uVal = (iu / samplesU) * dx;
        final isTopEdge = ih == samplesZ;
        final c = isTopEdge && bevelCol != null ? bevelCol : leftCol;
        writeFacePixel(x + uVal, y + dy, z + hVal, isTopEdge ? 0.02 : 0.0, c);
      }
    }

    // Right visible face (+x side: south-east facing).
    for (var ih = 0; ih <= samplesZ; ih++) {
      final hVal = (ih / samplesZ) * dz;
      for (var iv = 0; iv <= samplesV; iv++) {
        final vVal = (iv / samplesV) * dy;
        final isEdge = ih == samplesZ && vVal < 0.05;
        final c = isEdge && bevelCol != null ? bevelCol : rightCol;
        writeFacePixel(x + dx, y + vVal, z + hVal, 0.0, c);
      }
    }

    // Top visible face (+z side), with slightly brighter outer bevel ridges.
    for (var iv = 0; iv <= samplesV; iv++) {
      final vVal = (iv / samplesV) * dy;
      for (var iu = 0; iu <= samplesU; iu++) {
        final uVal = (iu / samplesU) * dx;
        final onTopLeftBevel = bevelCol != null &&
            (iu <= 1 || iv <= 1 || (iu == samplesU && iv >= samplesV - 1));
        writeFacePixel(
          x + uVal,
          y + vVal,
          z + dz,
          0.03,
          onTopLeftBevel ? bevelCol : topCol,
        );
      }
    }

    if (touched != null && outlineCol != null) {
      _applyLocalOutline(touched, outlineCol, outlineBias);
    }
  }

  /// Draw a bevelled or sloped isometric block rising from [dzStart] to [dzEnd].
  void isoSlope(
    double x,
    double y,
    double z,
    double dx,
    double dy,
    double dzStart,
    double dzEnd, {
    bool alongY = false,
    required int topCol,
    required int leftCol,
    required int rightCol,
    int? outlineCol,
  }) {
    final samplesU = math.max(6, (dx * projection.tileHalfW * 2.2).ceil());
    final samplesV = math.max(6, (dy * projection.tileHalfW * 2.2).ceil());
    final maxDz = math.max(dzStart, dzEnd);
    final samplesZ = math.max(4, (maxDz * projection.zScale * 1.5).ceil());
    final touched = outlineCol != null ? <int, int>{} : null;

    double surfaceDz(double uFrac, double vFrac) =>
        dzStart + (dzEnd - dzStart) * (alongY ? vFrac : uFrac);

    void writePx(double wx, double wy, double wz, int c) {
      final (lx, ly) = projection.project(wx, wy, wz);
      final sx = isoSnap(tx + lx);
      final sy = isoSnap(ty + ly);
      final bx = sx - frame.ox;
      final by = sy - frame.oy;
      if (bx < 0 || by < 0 || bx >= frame.w || by >= frame.h) return;
      if (!_fadePass(bx, by)) return;
      final dk = projection.depthKey(wx, wy, wz);
      final idx = by * frame.w + bx;
      putDepthAtIndex(frame.color, _depth, idx, dk, c);
      if (touched != null) {
        final prev = touched[idx];
        if (prev == null || dk > prev) touched[idx] = dk;
      }
    }

    for (var iu = 0; iu <= samplesU; iu++) {
      final uf = iu / samplesU;
      final colTop = surfaceDz(uf, 1.0);
      final hSteps = math.max(1, (colTop * projection.zScale * 1.5).ceil());
      for (var ih = 0; ih <= hSteps; ih++) {
        writePx(x + uf * dx, y + dy, z + (ih / hSteps) * colTop, leftCol);
      }
    }

    for (var iv = 0; iv <= samplesV; iv++) {
      final vf = iv / samplesV;
      final colTop = surfaceDz(1.0, vf);
      final hSteps = math.max(1, (colTop * projection.zScale * 1.5).ceil());
      for (var ih = 0; ih <= hSteps; ih++) {
        writePx(x + dx, y + vf * dy, z + (ih / hSteps) * colTop, rightCol);
      }
    }

    for (var iv = 0; iv <= samplesV; iv++) {
      final vf = iv / samplesV;
      for (var iu = 0; iu <= samplesU; iu++) {
        final uf = iu / samplesU;
        final sz = surfaceDz(uf, vf);
        writePx(x + uf * dx, y + vf * dy, z + sz + 0.02, topCol);
      }
    }

    if (touched != null && outlineCol != null) {
      final _ = samplesZ;
      _applyLocalOutline(touched, outlineCol, 0.0);
    }
  }

  /// Draw a cylindrical isometric column from [z0] to [z1] shaded from the top-left.
  void isoPillar(
    double cx,
    double cy,
    double z0,
    double z1,
    double radius,
    List<int> rampColors, {
    bool cap = true,
    int? outlineCol,
  }) {
    if (rampColors.isEmpty || z1 <= z0) return;
    final stepsZ = math.max(4, ((z1 - z0) * projection.zScale * 1.5).ceil());
    final stepsAng = math.max(16, (radius * projection.tileHalfW * 4.0).ceil());
    final touched = outlineCol != null ? <int, int>{} : null;

    void writePx(double wx, double wy, double wz, int c) {
      final (lx, ly) = projection.project(wx, wy, wz);
      final sx = isoSnap(tx + lx);
      final sy = isoSnap(ty + ly);
      final bx = sx - frame.ox;
      final by = sy - frame.oy;
      if (bx < 0 || by < 0 || bx >= frame.w || by >= frame.h) return;
      if (!_fadePass(bx, by)) return;
      final dk = projection.depthKey(wx, wy, wz);
      final idx = by * frame.w + bx;
      putDepthAtIndex(frame.color, _depth, idx, dk, c);
      if (touched != null) {
        final prev = touched[idx];
        if (prev == null || dk > prev) touched[idx] = dk;
      }
    }

    // Light direction in ground plane favors top-left (-x, +y side looks left on screen).
    const lxDir = -0.78;
    const lyDir = 0.62;
    for (var iz = 0; iz <= stepsZ; iz++) {
      final wz = z0 + (iz / stepsZ) * (z1 - z0);
      for (var ia = 0; ia <= stepsAng; ia++) {
        final ang = (ia / stepsAng) * tau;
        final nx = math.cos(ang);
        final ny = math.sin(ang);
        // Only draw front hemisphere facing camera (+x + y > 0) for crisp depth fill.
        if (nx + ny < -0.15) continue;
        final lit = clamp(0.45 + 0.5 * (nx * lxDir + ny * lyDir));
        final col = at(rampColors, lit);
        writePx(cx + nx * radius, cy + ny * radius, wz, col);
      }
    }

    if (cap) {
      final rSteps = math.max(4, (radius * projection.tileHalfW * 1.8).ceil());
      final capCol = rampColors[math.max(0, rampColors.length - 2)];
      for (var iy = -rSteps; iy <= rSteps; iy++) {
        final dy = (iy / rSteps) * radius;
        for (var ix = -rSteps; ix <= rSteps; ix++) {
          final dx = (ix / rSteps) * radius;
          if (dx * dx + dy * dy > radius * radius) continue;
          writePx(cx + dx, cy + dy, z1 + 0.02, capCol);
        }
      }
    }

    if (touched != null && outlineCol != null) {
      _applyLocalOutline(touched, outlineCol, 0.0);
    }
  }

  /// Draw a foreshortened 2:1 ground disc at world center `(cx, cy, z)`.
  void isoDisc(
    double cx,
    double cy,
    double z,
    double radius,
    int c, [
    double a = 1.0,
  ]) {
    if (radius <= 0.0 || c == 0 || !(a > 0.004)) return;
    final steps = math.max(6, (radius * projection.tileHalfW * 2.0).ceil());
    final r2 = radius * radius;
    for (var iy = -steps; iy <= steps; iy++) {
      final dy = (iy / steps) * radius;
      for (var ix = -steps; ix <= steps; ix++) {
        final dx = (ix / steps) * radius;
        if (dx * dx + dy * dy <= r2) {
          isoPixel(cx + dx, cy + dy, z, c, a);
        }
      }
    }
  }

  /// Draw a foreshortened 2:1 horizontal ring at `(cx, cy, z)`.
  void isoRing(
    double cx,
    double cy,
    double z,
    double radius,
    double width,
    int c, [
    double a = 1.0,
  ]) {
    if (radius <= 0.0 || width <= 0.0 || c == 0 || !(a > 0.004)) return;
    final outer = radius + width * 0.5;
    final inner = math.max(0.0, radius - width * 0.5);
    final steps = math.max(8, (outer * projection.tileHalfW * 2.2).ceil());
    for (var iy = -steps; iy <= steps; iy++) {
      final dy = (iy / steps) * outer;
      for (var ix = -steps; ix <= steps; ix++) {
        final dx = (ix / steps) * outer;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d >= inner && d <= outer) {
          isoPixel(cx + dx, cy + dy, z, c, a);
        }
      }
    }
  }

  /// Draw a depth-interpolated 3D line between [a] and [b].
  void isoLine3D(
    IsoCoord a,
    IsoCoord b,
    int c, {
    double width = 1.0,
    double alpha = 1.0,
  }) {
    if (c == 0 || !(alpha > 0.004)) return;
    final (ax, ay) = projection.project(a.x, a.y, a.z);
    final (bx, by) = projection.project(b.x, b.y, b.z);
    final distPx = hypot(bx - ax, by - ay);
    final steps = math.max(2, (distPx * 1.5).ceil());
    final rOff = ((width - 1.0) * 0.5).floor();
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final wx = lerp(a.x, b.x, u);
      final wy = lerp(a.y, b.y, u);
      final wz = lerp(a.z, b.z, u);
      final (lx, ly) = projection.project(wx, wy, wz);
      final sx = isoSnap(tx + lx);
      final sy = isoSnap(ty + ly);
      final dk = projection.depthKey(wx, wy, wz);
      if (width <= 1.01) {
        plotScreen(sx, sy, dk, c, alpha);
      } else {
        for (var oy = -rOff; oy <= rOff + 1; oy++) {
          for (var ox = -rOff; ox <= rOff + 1; ox++) {
            plotScreen(sx + ox, sy + oy, dk, c, alpha);
          }
        }
      }
    }
  }

  /// Draw a jagged 3D lightning/laser bolt from [a] to [b] with additive glow.
  void isoBolt3D(
    Rng rng,
    IsoCoord a,
    IsoCoord b,
    List<int> rampColors, {
    int segments = 8,
    double jitter = 0.22,
    double glowK = 0.35,
  }) {
    if (rampColors.isEmpty || segments < 1) return;
    var pts = <IsoCoord>[a, b];
    var amp = jitter;
    final levels = math.max(1, (math.log(segments) / math.ln2).round());
    for (var l = 0; l < levels; l++) {
      final next = <IsoCoord>[pts.first];
      for (var i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i];
        final p1 = pts[i + 1];
        final mid = IsoCoord(
          (p0.x + p1.x) * 0.5 + rng.range(-amp, amp),
          (p0.y + p1.y) * 0.5 + rng.range(-amp, amp),
          (p0.z + p1.z) * 0.5 + rng.range(-amp * 0.5, amp * 0.5),
        );
        next
          ..add(mid)
          ..add(p1);
      }
      pts = next;
      amp *= 0.55;
    }

    final outerCol = rampColors[math.max(0, rampColors.length ~/ 2)];
    final coreCol = rampColors.last;
    for (var i = 0; i < pts.length - 1; i++) {
      isoLine3D(pts[i], pts[i + 1], outerCol, width: 1.5);
      isoLine3D(pts[i], pts[i + 1], coreCol, width: 1.0);
      if (glowK > 0.004 && i.isEven) {
        isoGlow(pts[i].x, pts[i].y, pts[i].z, 6.0, outerCol, glowK * 0.65);
      }
    }
  }

  /// Add depth-aware additive glow anchored at world point `(x, y, z)`.
  void isoGlow(
    double x,
    double y,
    double z,
    double radiusPx,
    int c, [
    double k = 0.35,
    double occludedBleed = 0.25,
  ]) {
    final effK = k * lightK * fade;
    if (c == 0 || !(effK > 0.004) || radiusPx < 0.5) return;
    final (lx, ly) = projection.project(x, y, z);
    final cx = tx + lx - frame.ox;
    final cy = ty + ly - frame.oy;
    final dk = projection.depthKey(x, y, z);
    final x0 = math.max(0, (cx - radiusPx).floor());
    final y0 = math.max(0, (cy - radiusPx).floor());
    final x1 = math.min(frame.w - 1, (cx + radiusPx).ceil());
    final y1 = math.min(frame.h - 1, (cy + radiusPx).ceil());
    final invR = 1.0 / radiusPx;

    for (var by = y0; by <= y1; by++) {
      for (var bx = x0; bx <= x1; bx++) {
        final dist = hypot(bx + 0.5 - cx, by + 0.5 - cy) * invR;
        if (dist >= 1.0) continue;
        final f = 1.0 - dist;
        addLightDepthAtIndex(
          frame.color,
          frame.light,
          _depth,
          by * frame.w + bx,
          dk,
          c,
          effK * f * f,
          occludedBleed: occludedBleed,
        );
      }
    }
  }

  void _applyLocalOutline(
    Map<int, int> touched,
    int outlineCol,
    double outlineBias,
  ) {
    final w = frame.w;
    final h = frame.h;
    final biasDepth = (outlineBias * 16.0).round();
    final outlinePixels = <int, int>{};
    for (final entry in touched.entries) {
      final idx = entry.key;
      final dk = entry.value - 1 + biasDepth;
      final bx = idx % w;
      final by = idx ~/ w;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = bx + dx;
        final ny = by + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final nIdx = ny * w + nx;
        if (touched.containsKey(nIdx)) continue;
        final prev = outlinePixels[nIdx];
        if (prev == null || dk > prev) outlinePixels[nIdx] = dk;
      }
    }
    for (final entry in outlinePixels.entries) {
      final idx = entry.key;
      if ((frame.color[idx] >>> 24) > 0 && _depth[idx] >= entry.value) {
        continue;
      }
      putDepthAtIndex(frame.color, _depth, idx, entry.value, outlineCol);
    }
  }
}
