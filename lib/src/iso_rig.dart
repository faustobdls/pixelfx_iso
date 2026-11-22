// Pitched isometric 3D character rig rendering, 8-direction facing, and iso act execution.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'iso_frame.dart';
import 'iso_painter.dart';
import 'iso_wrapper.dart';
import 'projection.dart';

/// Convert an isometric compass facing [dir] into `RigRasterizer` yaw (radians).
double isoFacingYaw(IsoDir dir) => dir.yaw;

/// Resolve discrete [IsoDir] from an arbitrary yaw angle in radians.
IsoDir isoDirFromYaw(double yaw) {
  final idx = (yaw / (math.pi / 4.0)).round();
  return IsoDir.fromIndex(idx);
}

/// Render [pose] with [rig] at isometric camera pitch [pitch] and compass facing [dir].
PosedFigure posedIso(
  RigRasterizer rig,
  Pose pose, {
  IsoDir dir = IsoDir.se,
  double pitch = kIsoCameraPitch,
}) {
  final baseYaw = pose.yaw ?? 0.0;
  return rig.posed(
    pose.copyWith(yaw: isoFacingYaw(dir) + baseYaw),
    pitch: pitch,
  );
}

/// Extract the 3D skeleton overlay for [pose] rotated toward [dir] at isometric [pitch].
SkeletonView skeletonIso(
  RigRasterizer rig,
  Pose pose, {
  IsoDir dir = IsoDir.se,
  double pitch = kIsoCameraPitch,
}) {
  final baseYaw = pose.yaw ?? 0.0;
  return rig.skeleton(
    pose.copyWith(yaw: isoFacingYaw(dir) + baseYaw),
    pitch: pitch,
  );
}

/// Canvas geometry enclosing an isometric acted effect + pitched actor + target dummy.
class IsoActBounds {
  final int x0;
  final int y0;
  final int x1;
  final int y1;
  final int width;
  final int height;
  final int originX;
  final int originY;

  const IsoActBounds({
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.width,
    required this.height,
    required this.originX,
    required this.originY,
  });
}

/// Compute bounds covering [effect], a pitched rig facing [dir], and an optional target offset.
IsoActBounds isoActBounds(
  PixelAsset effect,
  RigRasterizer rig, {
  IsoDir dir = IsoDir.se,
  IsoProjection projection = const IsoProjection.standard(),
  double pitch = kIsoCameraPitch,
  double targetDistance = 1.05,
  int pad = 16,
}) {
  final m = effect.meta;
  var x0 = -m.originX;
  var y0 = -m.originY;
  var x1 = m.width - m.originX;
  var y1 = m.height - m.originY;

  final basePose = effect is PixelEffect && effect.act != null && effect.act!.poses.isNotEmpty
      ? effect.act!.poses.first.pose
      : kReady;

  void includeFigure(Pose p, double dx, double dy) {
    final fig = posedIso(rig, p, dir: dir, pitch: pitch);
    if (fig.n == 0) return;
    x0 = math.min(x0, fig.x0 + dx.floor());
    y0 = math.min(y0, fig.y0 + dy.floor());
    x1 = math.max(x1, fig.x1 + dx.ceil());
    y1 = math.max(y1, fig.y1 + dy.ceil());
  }

  includeFigure(basePose, 0.0, 0.0);
  if (effect is PixelEffect && effect.act != null) {
    for (final k in effect.act!.poses) {
      final (lx, ly) = projection.project(
        (k.pose.x ?? 0.0) / 24.0,
        (k.pose.y ?? 0.0) / 24.0,
        0.0,
      );
      includeFigure(k.pose, lx, ly);
    }
    if (effect.act!.target != null) {
      final (ux, uy) = dir.unitWorld;
      final (tx, ty) = projection.project(ux * targetDistance, uy * targetDistance, 0.0);
      x0 = math.min(x0, tx.floor() - 16);
      y0 = math.min(y0, ty.floor() - 36);
      x1 = math.max(x1, tx.ceil() + 16);
      y1 = math.max(y1, ty.ceil() + 8);
    }
  }

  x0 -= pad;
  y0 -= pad;
  x1 += pad;
  y1 += pad;
  return IsoActBounds(
    x0: x0,
    y0: y0,
    x1: x1,
    y1: y1,
    width: x1 - x0,
    height: y1 - y0,
    originX: -x0,
    originY: -y0,
  );
}

/// Union bounds across all 8 [IsoDir] orientations so turntable sprite sheets share cell sizes.
IsoActBounds isoTurntableBounds(
  PixelAsset effect,
  RigRasterizer rig, {
  IsoProjection projection = const IsoProjection.standard(),
  double pitch = kIsoCameraPitch,
  double targetDistance = 1.05,
  int pad = 16,
}) {
  var x0 = 1 << 20;
  var y0 = 1 << 20;
  var x1 = -(1 << 20);
  var y1 = -(1 << 20);
  for (final d in IsoDir.values) {
    final b = isoActBounds(
      effect,
      rig,
      dir: d,
      projection: projection,
      pitch: pitch,
      targetDistance: targetDistance,
      pad: pad,
    );
    x0 = math.min(x0, b.x0);
    y0 = math.min(y0, b.y0);
    x1 = math.max(x1, b.x1);
    y1 = math.max(y1, b.y1);
  }
  return IsoActBounds(
    x0: x0,
    y0: y0,
    x1: x1,
    y1: y1,
    width: x1 - x0,
    height: y1 - y0,
    originX: -x0,
    originY: -y0,
  );
}

/// Configuration for running an acted [PixelAsset] inside a 2.5D isometric scene.
class IsoActSpec {
  final IsoDir dir;
  final IsoPlane plane;
  final IsoProjection projection;
  final double pitch;
  final double worldX;
  final double worldY;
  final double worldZ;
  final double targetDistance;
  final bool showStageTile;
  final ActSpec? actOverride;

  const IsoActSpec({
    this.dir = IsoDir.se,
    this.plane = IsoPlane.floor,
    this.projection = const IsoProjection.standard(),
    this.pitch = kIsoCameraPitch,
    this.worldX = 0.0,
    this.worldY = 0.0,
    this.worldZ = 0.0,
    this.targetDistance = 1.05,
    this.showStageTile = true,
    this.actOverride,
  });
}

/// Live 2.5D acted instance synchronizing pitched hero rig, 2:1 shadows,
/// directional knockback target, hit-stop, camera shake, and isometric FX.
class IsoActInstance implements AssetInstance {
  final PixelAsset source;
  final IsoActSpec spec;
  final RigRasterizer rig;
  final SkinRegistry skins;
  @override
  final Map<String, Object?> options;
  final AssetMeta meta;

  late final AssetInstance _fx;
  late final ActSpec _act;
  late final List<PoseKey> _track;
  late final List<HitSpec> _hits;
  late final double _startTime;
  late final double _duration;

  final int _originX;
  final int _originY;
  final bool showActor;
  final bool showTarget;
  void Function(HitSpec hit)? onHit;

  double _t;
  double _stop = 0.0;
  double _shakeT = 0.0;
  double _shake0 = 0.0;
  double _amp = 0.0;
  int _nh = 0;
  int _loopN = 0;
  bool _stopped = false;
  Pose _lastPose = kStand;
  double _targetPush = 0.0;
  double _targetVel = 0.0;
  double _targetFlash = 0.0;
  String? _targetSkin;

  IsoActInstance({
    required this.source,
    this.spec = const IsoActSpec(),
    RigRasterizer? rig,
    SkinRegistry? skins,
    this.options = const {},
    this.showActor = true,
    this.showTarget = true,
    this.onHit,
  })  : rig = rig ?? RigRasterizer.instance,
        skins = skins ?? SkinRegistry.instance,
        meta = source.meta,
        _originX = (options['x'] as num?)?.toInt() ?? source.meta.originX,
        _originY = (options['y'] as num?)?.toInt() ?? source.meta.originY,
        _t = 0.0 {
    final eff = source;
    final rawAct = spec.actOverride ??
        (eff is PixelEffect ? eff.act : null) ??
        const ActSpec(poses: [PoseKey(0.0, kReady)]);
    _act = rawAct;
    _track = rawAct.poses.isNotEmpty
        ? rawAct.poses
        : const [PoseKey(0.0, kStand)];
    _hits = rawAct.hits;
    _duration = math.max(0.05, source.meta.duration);
    _startTime = math.min(0.0, _track.first.t);
    _t = _startTime;

    final isNativeIso = source.meta.extra['iso'] == true;
    final fxAsset = isNativeIso
        ? source
        : IsoProjectedEffect(
            source,
            plane: spec.plane,
            projection: spec.projection,
            dir: spec.dir,
            worldX: spec.worldX,
            worldY: spec.worldY,
            worldZ: spec.worldZ,
          );
    final fxOpts = Map<String, Object?>.of(options)
      ..['x'] = _originX
      ..['y'] = _originY;
    _fx = fxAsset.createInstance(fxOpts);
    _lastPose = _samplePose();
  }

  @override
  double get t => _t;

  bool get frozen => _stop > 0.0;

  Pose get pose => _lastPose;

  (int sx, int sy) get shake {
    if (_shakeT <= 0.0) return (0, 0);
    final k = _amp * (_shakeT / math.max(1e-6, _shake0));
    final f = (_shakeT * 60.0).floor();
    return (
      (math.sin(f * 2.4) * k).round(),
      (math.cos(f * 3.7) * k * 0.7).round(),
    );
  }

  SkeletonView get currentSkeleton => skeletonIso(
        rig,
        _lastPose,
        dir: spec.dir,
        pitch: spec.pitch,
      );

  Pose _samplePose() {
    final tt = meta.loop && _t >= _duration ? (_t % _duration) : _t;
    var q = poseAt(_track, tt);
    if (!meta.loop && isPoseHeld(_track, tt)) {
      final up = (((tt * 3.0).floor()) & 1).toDouble();
      q = kStand.merge(q).copyWith(
            crouch: (q.crouch ?? 0.0) + up,
            fy: (q.fy ?? kStand.fy!) + up,
            by: (q.by ?? kStand.by!) + up,
          );
    }
    return q;
  }

  @override
  void update(double dt) {
    if (_shakeT > 0.0) _shakeT = math.max(0.0, _shakeT - dt);
    if (_stop > 0.0) {
      _stop = math.max(0.0, _stop - dt);
      return;
    }
    final t0 = _t;
    _t += dt;
    if (_t >= 0.0) {
      _fx.update(t0 < 0.0 ? _t : dt);
    }

    if (meta.loop && _t >= _duration) {
      final n = (_t / _duration).floor();
      if (n != _loopN) {
        _loopN = n;
        _nh = 0;
      }
    }

    final tt = meta.loop && _t >= _duration ? (_t % _duration) : _t;
    for (; _nh < _hits.length && _hits[_nh].t <= tt; _nh++) {
      final h = _hits[_nh];
      if (h.stop > 0.0) _stop = math.max(_stop, h.stop);
      if (h.shake > 0.0) {
        _shakeT = _shake0 = h.shake;
        _amp = h.amp;
      }
      if (h.target) {
        _targetVel += h.push * 1.4;
        _targetFlash = math.max(_targetFlash, h.flash);
        if (h.clearSkin) {
          _targetSkin = null;
        } else if (h.skin != null) {
          _targetSkin = h.skin;
        }
      }
      onHit?.call(h);
    }

    // Damped spring physics for isometric target dummy knockback.
    _targetVel += (-48.0 * _targetPush - 5.2 * _targetVel) * dt;
    _targetPush = clamp(_targetPush + _targetVel * dt, -0.35, 0.45);
    if (_targetFlash > 0.0) _targetFlash = math.max(0.0, _targetFlash - dt);

    _lastPose = _samplePose();
  }

  @override
  void draw(PixelFrame frame, [DrawLayer layer = DrawLayer.both]) {
    final ip = IsoPainter(frame, projection: spec.projection)
      ..place(_originX.toDouble(), _originY.toDouble());
    if (frame is! PixelIsoFrame) {
      clearIsoDepth(frame);
    }

    if (spec.showStageTile) {
      _drawStageDiamonds(ip);
    }

    final hasTarget = showTarget && _act.target != null;
    if (hasTarget) {
      _drawIsoDummy(ip);
    }

    if (showActor) {
      final q = _lastPose;
      final fig = posedIso(rig, q, dir: spec.dir, pitch: spec.pitch);
      final (ux, uy) = spec.dir.unitWorld;
      final disp = (q.x ?? 0.0) / 24.0;
      final actorWx = spec.worldX + ux * disp;
      final actorWy = spec.worldY + uy * disp;
      final actorWz = spec.worldZ - (q.y ?? 0.0) / spec.projection.zScale;

      ip.isoShadow(actorWx, actorWy, spec.worldZ, 0.34, 0.34, 0.48);

      final (ax, ay) = spec.projection.project(actorWx, actorWy, actorWz);
      final cx = _originX + ax;
      final cy = _originY + ay;
      final zStep = math.max(1.0, spec.projection.zScale);
      for (var i = 0; i < fig.n; i++) {
        final px = cx + fig.xs[i];
        final py = cy + fig.ys[i];
        final hWorld = math.max(0.0, -fig.ys[i]) / zStep;
        final dk = spec.projection.depthKey(actorWx, actorWy, actorWz + hWorld);
        ip.plotScreen(px.round(), py.round(), dk, fig.color[i]);
      }
    }

    if (_t >= 0.0) {
      _fx.draw(frame, layer);
    }
  }

  void _drawStageDiamonds(IsoPainter ip) {
    final top = hex('#252038');
    final bevel = hex('#342d4f');
    final left = hex('#191526');
    final right = hex('#120f1c');
    final outline = hex('#0c0a12');
    ip.isoBox(
      spec.worldX - 0.5,
      spec.worldY - 0.5,
      spec.worldZ - 0.12,
      1.0,
      1.0,
      0.12,
      topCol: top,
      leftCol: left,
      rightCol: right,
      bevelCol: bevel,
      outlineCol: outline,
      outlineBias: -0.05,
    );
  }

  void _drawIsoDummy(IsoPainter ip) {
    final (ux, uy) = spec.dir.unitWorld;
    final wx = spec.worldX + ux * (spec.targetDistance + _targetPush * 0.35);
    final wy = spec.worldY + uy * (spec.targetDistance + _targetPush * 0.35);
    final skinName = _targetFlash > 0.0 ? 'flash' : _targetSkin;
    final sk = skinName != null ? skins[skinName] : null;

    int tint(int c) => sk != null ? mix(c, sk.color, sk.mixAmount) : c;

    ip.isoShadow(wx, wy, spec.worldZ, 0.28, 0.28, 0.45);
    ip.isoPillar(
      wx,
      wy,
      spec.worldZ,
      spec.worldZ + 0.35,
      0.07,
      [tint(hex('#4a2c14')), tint(hex('#6a421e')), tint(hex('#8e5c2c'))],
      cap: false,
    );
    final leanX = _targetPush * 0.22 * ux;
    final leanY = _targetPush * 0.22 * uy;
    ip.isoBox(
      wx - 0.16 + leanX,
      wy - 0.16 + leanY,
      spec.worldZ + 0.32,
      0.32,
      0.32,
      0.56,
      topCol: tint(hex('#dcc8a2')),
      leftCol: tint(hex('#b89f78')),
      rightCol: tint(hex('#927a58')),
      bevelCol: tint(hex('#efe0be')),
      outlineCol: hex('#14101c'),
    );
  }

  @override
  void stop() {
    _stopped = true;
    _fx.stop();
  }

  @override
  bool get done =>
      _stopped || (!meta.loop && _t >= _duration && _stop <= 0.0 && _targetFlash <= 0.0 && _fx.done);
}
