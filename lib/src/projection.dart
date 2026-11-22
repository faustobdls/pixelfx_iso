// 2:1 dimetric isometric coordinate system, snap helpers, and analytical inverse ground picking.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

/// Eight discrete isometric compass directions aligned with `RigRasterizer` yaw angles.
enum IsoDir {
  e(0, 'E', 1.0, -1.0),
  se(1, 'SE', 1.0, 0.0),
  s(2, 'S', 1.0, 1.0),
  sw(3, 'SW', 0.0, 1.0),
  w(4, 'W', -1.0, 1.0),
  nw(5, 'NW', -1.0, 0.0),
  n(6, 'N', -1.0, -1.0),
  ne(7, 'NE', 0.0, -1.0);

  final int id;
  final String label;
  final double worldDx;
  final double worldDy;

  const IsoDir(this.id, this.label, this.worldDx, this.worldDy);

  /// Yaw in radians matching `RigRasterizer` (`dir * pi / 4`).
  double get yaw => id * (math.pi / 4.0);

  /// Normalized ground direction vector `(ux, uy)` in isometric world axes.
  (double ux, double uy) get unitWorld {
    final len = math.sqrt(worldDx * worldDx + worldDy * worldDy);
    return (worldDx / len, worldDy / len);
  }

  /// Screen-space unit vector `(sx, sy)` when projected with standard 2:1 dimetric axes.
  (double sx, double sy) get unitScreen => (math.cos(yaw), math.sin(yaw));

  static IsoDir fromIndex(int dir) => IsoDir.values[((dir % 8) + 8) % 8];
}

/// 3D world coordinate in isometric space (`x` South-East, `y` South-West, `z` Up).
class IsoCoord {
  final double x;
  final double y;
  final double z;

  const IsoCoord(this.x, this.y, [this.z = 0.0]);

  static const IsoCoord zero = IsoCoord(0.0, 0.0, 0.0);

  IsoCoord operator +(IsoCoord other) =>
      IsoCoord(x + other.x, y + other.y, z + other.z);

  IsoCoord operator -(IsoCoord other) =>
      IsoCoord(x - other.x, y - other.y, z - other.z);

  IsoCoord operator *(double s) => IsoCoord(x * s, y * s, z * s);

  IsoCoord translate(double dx, double dy, [double dz = 0.0]) =>
      IsoCoord(x + dx, y + dy, z + dz);

  double get length => math.sqrt(x * x + y * y + z * z);

  double distanceTo(IsoCoord other) => (this - other).length;

  @override
  bool operator ==(Object other) =>
      other is IsoCoord && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'IsoCoord($x, $y, $z)';
}

/// Asymmetric Math.round helper (`(v + 0.5).floor()`) keeping 2:1 pixel edges shimmer-free.
@pragma('vm:prefer-inline')
int isoSnap(double v) => (v + 0.5).floor();

/// Classic 2:1 dimetric pixel projection and exact analytical ground picking.
class IsoProjection {
  final double tileHalfW;
  final double tileHalfH;
  final double zScale;

  const IsoProjection({
    this.tileHalfW = 16.0,
    this.tileHalfH = 8.0,
    this.zScale = 16.0,
  });

  /// Default tile-unit projection (`32x16` tile diamond, `1` world Z = `16 px`).
  const IsoProjection.standard()
      : tileHalfW = 16.0,
        tileHalfH = 8.0,
        zScale = 16.0;

  /// Pixel-elevation projection (`32x16` tile diamond, `1` world Z = `1 px`).
  const IsoProjection.pixel()
      : tileHalfW = 16.0,
        tileHalfH = 8.0,
        zScale = 1.0;

  double get tileWidth => tileHalfW * 2.0;
  double get tileHeight => tileHalfH * 2.0;

  /// Forward dimetric projection from world `(x, y, z)` to local screen `(sx, sy)`.
  @pragma('vm:prefer-inline')
  (double sx, double sy) project(double x, double y, [double z = 0.0]) => (
        (x - y) * tileHalfW,
        (x + y) * tileHalfH - z * zScale,
      );

  (double sx, double sy) projectCoord(IsoCoord coord) =>
      project(coord.x, coord.y, coord.z);

  /// Pixel-snapped forward projection for jitter-free sprite & tile rasterization.
  @pragma('vm:prefer-inline')
  (int px, int py) projectSnapped(double x, double y, [double z = 0.0]) {
    final (sx, sy) = project(x, y, z);
    return (isoSnap(sx), isoSnap(sy));
  }

  /// Exact analytical inverse from local screen `(sx, sy)` at elevation `z` to `(x, y)`.
  (double x, double y) screenToGround(
    double sx,
    double sy, {
    double z = 0.0,
  }) {
    final syAdj = sy + z * zScale;
    final u = sx / tileHalfW;
    final v = syAdj / tileHalfH;
    return (0.5 * (u + v), 0.5 * (v - u));
  }

  /// Quantized 16-bit depth key (`-32767..32767`); higher means closer to camera.
  @pragma('vm:prefer-inline')
  int depthKey(double x, double y, [double z = 0.0]) =>
      clampInt(((x + y) * 256.0 + z * 16.0).round(), -32767, 32767);

  int depthKeyCoord(IsoCoord coord) => depthKey(coord.x, coord.y, coord.z);
}
