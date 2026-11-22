// Deterministic 3D (x, y, z) particles & tumbling debris bouncing on heightmaps at 120 Hz.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'iso_painter.dart';

/// Callback returning floor elevation `z` at world ground coordinates `(x, y)`.
typedef IsoHeightFn = double Function(double x, double y);

double _flatGround(double x, double y) => 0.0;

class IsoParticle {
  double x;
  double y;
  double z;
  double vx;
  double vy;
  double vz;
  double life;
  final double maxLife;
  final int color;
  final double radius;
  final bool glow;
  final bool shadow;

  IsoParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.maxLife,
    required this.color,
    this.radius = 0.08,
    this.glow = true,
    this.shadow = true,
  }) : life = maxLife;
}

/// 120 Hz 3D particle simulation colliding against a caller-supplied heightmap [groundZ].
class IsoParticles {
  final Rng rng;
  final IsoHeightFn groundZ;
  final double gravityZ;
  final double bounce;
  final double drag;
  final List<IsoParticle> list = [];

  IsoParticles({
    Rng? rng,
    int seed = 1,
    IsoHeightFn? groundZ,
    this.gravityZ = 18.0,
    this.bounce = 0.42,
    this.drag = 0.8,
  })  : rng = rng ?? Rng(seed),
        groundZ = groundZ ?? _flatGround;

  void spawn(
    double x,
    double y,
    double z,
    double vx,
    double vy,
    double vz,
    double life,
    int color, {
    double radius = 0.08,
    bool glow = true,
    bool shadow = true,
  }) {
    if (life <= 0.0) return;
    list.add(IsoParticle(
      x: x,
      y: y,
      z: z,
      vx: vx,
      vy: vy,
      vz: vz,
      maxLife: life,
      color: color,
      radius: radius,
      glow: glow,
      shadow: shadow,
    ));
  }

  void clear() => list.clear();

  /// Integrate physics with at least 120 Hz substepping.
  void update(double dt) {
    if (dt <= 0.0 || list.isEmpty) return;
    final sub = math.max(1, (dt * 120.0 - 1e-9).ceil());
    final step = dt / sub;
    final dFactor = drag > 0.0 ? math.max(0.0, 1.0 - drag * step) : 1.0;

    for (var s = 0; s < sub; s++) {
      for (var i = list.length - 1; i >= 0; i--) {
        final pt = list[i];
        pt.life -= step;
        if (pt.life <= 0.0) {
          list.removeAt(i);
          continue;
        }
        pt.vx *= dFactor;
        pt.vy *= dFactor;
        pt.vz -= gravityZ * step;
        pt.x += pt.vx * step;
        pt.y += pt.vy * step;
        pt.z += pt.vz * step;

        final gz = groundZ(pt.x, pt.y);
        if (pt.z <= gz && pt.vz < 0.0) {
          pt.z = gz;
          pt.vz = -pt.vz * bounce;
          pt.vx *= 0.65;
          pt.vy *= 0.65;
        }
      }
    }
  }

  void draw(IsoPainter p) {
    for (final pt in list) {
      final k = clamp(pt.life / pt.maxLife);
      final gz = groundZ(pt.x, pt.y);
      final height = math.max(0.0, pt.z - gz);
      if (pt.shadow && height < 1.5) {
        p.isoShadow(
          pt.x,
          pt.y,
          gz,
          pt.radius * (1.1 - height * 0.35),
          null,
          0.45 * k,
        );
      }
      if (k > 0.72) {
        p.isoPixel(pt.x, pt.y, pt.z, kWhite, k);
      } else {
        p.isoPixel(pt.x, pt.y, pt.z, pt.color, k);
      }
      if (pt.glow && k > 0.15) {
        p.isoGlow(pt.x, pt.y, pt.z, 4.0 * k + 1.5, pt.color, 0.3 * k);
      }
    }
  }
}

class IsoBit {
  double x;
  double y;
  double z;
  double vx;
  double vy;
  double vz;
  double life;
  final double maxLife;
  final double size;
  final int topCol;
  final int leftCol;
  final int rightCol;

  IsoBit({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.maxLife,
    required this.size,
    required this.topCol,
    required this.leftCol,
    required this.rightCol,
  }) : life = maxLife;
}

/// 3D isometric tumbling block debris bouncing against a heightmap.
class IsoBits {
  final IsoHeightFn groundZ;
  final double gravityZ;
  final double bounce;
  final List<IsoBit> list = [];

  IsoBits({
    IsoHeightFn? groundZ,
    this.gravityZ = 22.0,
    this.bounce = 0.35,
  }) : groundZ = groundZ ?? _flatGround;

  void add({
    required double x,
    required double y,
    required double z,
    required double vx,
    required double vy,
    required double vz,
    required double life,
    double size = 0.14,
    required List<int> rampColors,
  }) {
    final len = rampColors.length;
    if (len == 0 || life <= 0.0) return;
    final topCol = rampColors[math.min(len - 1, len - 2)];
    final leftCol = rampColors[math.max(0, len ~/ 2)];
    final rightCol = rampColors[math.max(0, len ~/ 3)];
    list.add(IsoBit(
      x: x,
      y: y,
      z: z,
      vx: vx,
      vy: vy,
      vz: vz,
      maxLife: life,
      size: size,
      topCol: topCol,
      leftCol: leftCol,
      rightCol: rightCol,
    ));
  }

  void update(double dt) {
    if (dt <= 0.0 || list.isEmpty) return;
    final sub = math.max(1, (dt * 120.0 - 1e-9).ceil());
    final step = dt / sub;
    for (var s = 0; s < sub; s++) {
      for (var i = list.length - 1; i >= 0; i--) {
        final b = list[i];
        b.life -= step;
        if (b.life <= 0.0) {
          list.removeAt(i);
          continue;
        }
        b.vz -= gravityZ * step;
        b.x += b.vx * step;
        b.y += b.vy * step;
        b.z += b.vz * step;
        final gz = groundZ(b.x, b.y);
        if (b.z <= gz && b.vz < 0.0) {
          b.z = gz;
          b.vz = -b.vz * bounce;
          b.vx *= 0.55;
          b.vy *= 0.55;
        }
      }
    }
  }

  void draw(IsoPainter p) {
    final prevFade = p.fade;
    for (final b in list) {
      final k = clamp(b.life / b.maxLife);
      final gz = groundZ(b.x, b.y);
      p.isoShadow(b.x, b.y, gz, b.size * 0.8, null, 0.45 * k);
      p.fade = prevFade * math.min(1.0, k * 2.2);
      final half = b.size * 0.5;
      p.isoBox(
        b.x - half,
        b.y - half,
        b.z,
        b.size,
        b.size,
        b.size,
        topCol: b.topCol,
        leftCol: b.leftCol,
        rightCol: b.rightCol,
      );
    }
    p.fade = prevFade;
  }
}
