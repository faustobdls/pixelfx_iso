// Zero-rewrite bridge projecting any 2D PixelAsset onto isometric billboard, floor, or walls.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'iso_frame.dart';
import 'iso_painter.dart';
import 'projection.dart';

/// Projection plane used when lifting a 2D [PixelAsset] into 2.5D isometric space.
enum IsoPlane {
  /// Upright sprite facing the camera with depth sorted by its ground anchor and height.
  billboard,

  /// Projected flat onto the 2:1 dimetric ground diamond (`z = worldZ`).
  floor,

  /// Projected onto the left-hand isometric wall plane (parallel to world `+X`).
  wallLeft,

  /// Projected onto the right-hand isometric wall plane (parallel to world `+Y`).
  wallRight,
}

/// Parse an [IsoPlane] from CLI or option strings.
IsoPlane parseIsoPlane(String raw) {
  switch (raw.trim().toLowerCase().replaceAll('_', '-')) {
    case 'billboard':
    case 'upright':
      return IsoPlane.billboard;
    case 'floor':
    case 'ground':
      return IsoPlane.floor;
    case 'wall-left':
    case 'wallleft':
    case 'left':
      return IsoPlane.wallLeft;
    case 'wall-right':
    case 'wallright':
    case 'right':
      return IsoPlane.wallRight;
    default:
      throw ArgumentError.value(
        raw,
        'plane',
        'Expected one of: billboard, floor, wall-left, wall-right.',
      );
  }
}

/// Wraps any existing 2D [PixelAsset] (including all 244 catalog effects) and projects it
/// into 2.5D isometric space with per-pixel depth testing and occlusion-aware additive light.
class IsoProjectedEffect implements PixelAsset {
  final PixelAsset source;
  final IsoPlane plane;
  final IsoProjection projection;
  final IsoDir dir;
  final double scale;
  final double worldX;
  final double worldY;
  final double worldZ;

  @override
  final AssetMeta meta;

  IsoProjectedEffect(
    this.source, {
    this.plane = IsoPlane.floor,
    this.projection = const IsoProjection.standard(),
    this.dir = IsoDir.e,
    this.scale = 1.0,
    this.worldX = 0.0,
    this.worldY = 0.0,
    this.worldZ = 0.0,
    (int w, int h)? size,
    (int ox, int oy)? origin,
    BackdropKind? bg,
  }) : meta = _buildMeta(source, plane, dir, size, origin, bg);

  static EffectMeta _buildMeta(
    PixelAsset source,
    IsoPlane plane,
    IsoDir dir,
    (int w, int h)? size,
    (int ox, int oy)? origin,
    BackdropKind? bg,
  ) {
    final sm = source.meta;
    final defW = math.max(sm.width + 16, (sm.width * 1.35).ceil());
    final defH = math.max(sm.height + 16, (sm.height * 1.25).ceil());
    final outSize = size ?? (defW, defH);
    final outOrigin =
        origin ?? (outSize.$1 ~/ 2, (outSize.$2 * 0.65).round());
    final actorScale = sm is EffectMeta ? sm.actorScale : 1;
    return EffectMeta(
      id: sm.id,
      name: '${sm.name} (Iso)',
      desc: sm.desc,
      kind: sm.kind,
      category: sm.category,
      tags: [...sm.tags, 'iso', plane.name],
      size: outSize,
      origin: outOrigin,
      duration: sm.duration,
      loop: sm.loop,
      fps: sm.fps,
      bg: bg ?? BackdropKind.isoGrid,
      actorScale: actorScale,
      defaultOptions: sm.defaultOptions,
      extra: {
        ...sm.extra,
        'iso': true,
        'plane': plane.name,
        'dir': dir.label,
      },
    );
  }

  @override
  AssetInstance createInstance([Map<String, Object?> options = const {}]) {
    final sm = source.meta;
    final forwarded = Map<String, Object?>.of(options);
    forwarded['x'] = sm.originX;
    forwarded['y'] = sm.originY;
    final srcInst = source.createInstance(forwarded);
    return _IsoProjectedInstance(
      owner: this,
      srcInst: srcInst,
      options: options,
    );
  }
}

class _IsoProjectedInstance implements AssetInstance {
  final IsoProjectedEffect owner;
  final AssetInstance srcInst;
  @override
  final Map<String, Object?> options;
  late final PixelFrame _scratch;

  _IsoProjectedInstance({
    required this.owner,
    required this.srcInst,
    required this.options,
  }) : _scratch = createFrame(owner.source.meta.width, owner.source.meta.height);

  AssetMeta get meta => owner.meta;

  @override
  double get t => srcInst.t;

  @override
  void update(double dt) => srcInst.update(dt);

  @override
  void stop() => srcInst.stop();

  @override
  bool get done => srcInst.done;

  @override
  void draw(PixelFrame frame, [DrawLayer layer = DrawLayer.both]) {
    clearFrame(_scratch);
    srcInst.draw(_scratch, layer);

    final outOx =
        ((options['x'] as num?)?.toDouble() ?? owner.meta.originX.toDouble()) -
            frame.ox;
    final outOy =
        ((options['y'] as num?)?.toDouble() ?? owner.meta.originY.toDouble()) -
            frame.oy;
    final lightOpt = (options['light'] as num?)?.toDouble() ?? 1.0;

    final plane = options['plane'] is IsoPlane
        ? options['plane'] as IsoPlane
        : (options['plane'] is String
            ? parseIsoPlane(options['plane'] as String)
            : owner.plane);
    final dir = options['dir'] is IsoDir ? options['dir'] as IsoDir : owner.dir;
    final effScale =
        (options['scale'] as num?)?.toDouble() ?? owner.scale;

    final depthBuf = isoDepthBufferFor(frame);
    final (projX, projY) = owner.projection.project(
      owner.worldX,
      owner.worldY,
      owner.worldZ,
    );
    final centerBx = outOx + projX;
    final centerBy = outOy + projY;

    switch (plane) {
      case IsoPlane.billboard:
        _blitBillboard(frame, depthBuf, centerBx, centerBy, effScale, lightOpt);
      case IsoPlane.floor:
        _blitFloor(frame, depthBuf, outOx, outOy, dir, effScale, lightOpt);
      case IsoPlane.wallLeft:
        _blitWall(
          frame,
          depthBuf,
          centerBx,
          centerBy,
          effScale,
          lightOpt,
          leftWall: true,
        );
      case IsoPlane.wallRight:
        _blitWall(
          frame,
          depthBuf,
          centerBx,
          centerBy,
          effScale,
          lightOpt,
          leftWall: false,
        );
    }
  }

  void _emitPixel(
    PixelFrame frame,
    Int16List depthBuf,
    int bx,
    int by,
    int dk,
    int col,
    int lgt,
    double lightOpt,
  ) {
    final idx = by * frame.w + bx;
    final a = col >>> 24;
    if (a == 255) {
      putDepthAtIndex(frame.color, depthBuf, idx, dk, col);
    } else if (a > 0) {
      blendDepthAtIndex(frame.color, depthBuf, idx, dk, col);
    }
    if ((lgt & 0xffffff) != 0) {
      addLightDepthAtIndex(
        frame.color,
        frame.light,
        depthBuf,
        idx,
        dk,
        lgt,
        lightOpt,
      );
    }
  }

  void _blitBillboard(
    PixelFrame frame,
    Int16List depthBuf,
    double centerBx,
    double centerBy,
    double effScale,
    double lightOpt,
  ) {
    final sw = _scratch.w;
    final sh = _scratch.h;
    final sox = owner.source.meta.originX.toDouble();
    final soy = owner.source.meta.originY.toDouble();
    final minX = -sox * effScale;
    final maxX = (sw - sox) * effScale;
    final minY = -soy * effScale;
    final maxY = (sh - soy) * effScale;

    final x0 = math.max(0, (centerBx + minX).floor() - 1);
    final x1 = math.min(frame.w - 1, (centerBx + maxX).ceil() + 1);
    final y0 = math.max(0, (centerBy + minY).floor() - 1);
    final y1 = math.min(frame.h - 1, (centerBy + maxY).ceil() + 1);
    final invS = 1.0 / math.max(0.05, effScale);
    final zStep = math.max(1.0, owner.projection.zScale);

    for (var by = y0; by <= y1; by++) {
      final ly = (by + 0.5 - centerBy) * invS;
      final sy = (ly + soy).floor();
      if (sy < 0 || sy >= sh) continue;
      final wz = owner.worldZ + math.max(0.0, -ly * effScale) / zStep;
      final dk = owner.projection.depthKey(owner.worldX, owner.worldY, wz);
      for (var bx = x0; bx <= x1; bx++) {
        final lx = (bx + 0.5 - centerBx) * invS;
        final sx = (lx + sox).floor();
        if (sx < 0 || sx >= sw) continue;
        final sIdx = sy * sw + sx;
        final col = _scratch.color[sIdx];
        final lgt = _scratch.light[sIdx];
        if ((col >>> 24) == 0 && (lgt & 0xffffff) == 0) continue;
        _emitPixel(frame, depthBuf, bx, by, dk, col, lgt, lightOpt);
      }
    }
  }

  void _blitFloor(
    PixelFrame frame,
    Int16List depthBuf,
    double outOx,
    double outOy,
    IsoDir dir,
    double effScale,
    double lightOpt,
  ) {
    final proj = owner.projection;
    final sw = _scratch.w;
    final sh = _scratch.h;
    final sox = owner.source.meta.originX.toDouble();
    final soy = owner.source.meta.originY.toDouble();
    final groundScale = effScale / (2.0 * math.max(1.0, proj.tileHalfW));
    final cs = math.cos(dir.yaw);
    final sn = math.sin(dir.yaw);

    // Map the 4 source corners to compute a tight screen-space bounding box.
    var bx0 = frame.w;
    var bx1 = -1;
    var by0 = frame.h;
    var by1 = -1;
    for (final cx in [0.0 - sox, sw - sox]) {
      for (final cy in [0.0 - soy, sh - soy]) {
        final rx = cx * cs - cy * sn;
        final ry = cx * sn + cy * cs;
        final wx = owner.worldX + (rx + ry) * groundScale;
        final wy = owner.worldY + (ry - rx) * groundScale;
        final (lx, ly) = proj.project(wx, wy, owner.worldZ);
        final sx = outOx + lx;
        final sy = outOy + ly;
        if (sx.floor() - 1 < bx0) bx0 = sx.floor() - 1;
        if (sx.ceil() + 1 > bx1) bx1 = sx.ceil() + 1;
        if (sy.floor() - 1 < by0) by0 = sy.floor() - 1;
        if (sy.ceil() + 1 > by1) by1 = sy.ceil() + 1;
      }
    }

    bx0 = math.max(0, bx0);
    by0 = math.max(0, by0);
    bx1 = math.min(frame.w - 1, bx1);
    by1 = math.min(frame.h - 1, by1);
    if (bx0 > bx1 || by0 > by1) return;

    final invGS = 1.0 / groundScale;
    for (var by = by0; by <= by1; by++) {
      final relSy = by + 0.5 - outOy;
      for (var bx = bx0; bx <= bx1; bx++) {
        final relSx = bx + 0.5 - outOx;
        final (wx, wy) =
            proj.screenToGround(relSx, relSy, z: owner.worldZ);
        final dwx = wx - owner.worldX;
        final dwy = wy - owner.worldY;
        final rx = (dwx - dwy) * 0.5 * invGS;
        final ry = (dwx + dwy) * 0.5 * invGS;
        final lx = rx * cs + ry * sn;
        final ly = -rx * sn + ry * cs;
        final sx = (lx + sox).floor();
        final sy = (ly + soy).floor();
        if (sx < 0 || sy < 0 || sx >= sw || sy >= sh) continue;
        final sIdx = sy * sw + sx;
        final col = _scratch.color[sIdx];
        final lgt = _scratch.light[sIdx];
        if ((col >>> 24) == 0 && (lgt & 0xffffff) == 0) continue;
        final dk = proj.depthKey(wx, wy, owner.worldZ);
        _emitPixel(frame, depthBuf, bx, by, dk, col, lgt, lightOpt);
      }
    }
  }

  void _blitWall(
    PixelFrame frame,
    Int16List depthBuf,
    double centerBx,
    double centerBy,
    double effScale,
    double lightOpt, {
    required bool leftWall,
  }) {
    final proj = owner.projection;
    final sw = _scratch.w;
    final sh = _scratch.h;
    final sox = owner.source.meta.originX.toDouble();
    final soy = owner.source.meta.originY.toDouble();
    final slopeRatio = proj.tileHalfH / math.max(1.0, proj.tileHalfW);
    final invS = 1.0 / math.max(0.05, effScale);
    final wallSign = leftWall ? 1.0 : -1.0;

    final minX = -sox * effScale;
    final maxX = (sw - sox) * effScale;
    final maxSkew = math.max(minX.abs(), maxX.abs()) * slopeRatio;
    final minY = -soy * effScale - maxSkew;
    final maxY = (sh - soy) * effScale + maxSkew;

    final bx0 = math.max(0, (centerBx + minX).floor() - 1);
    final bx1 = math.min(frame.w - 1, (centerBx + maxX).ceil() + 1);
    final by0 = math.max(0, (centerBy + minY).floor() - 1);
    final by1 = math.min(frame.h - 1, (centerBy + maxY).ceil() + 1);
    final zStep = math.max(1.0, proj.zScale);

    for (var by = by0; by <= by1; by++) {
      final relY = by + 0.5 - centerBy;
      for (var bx = bx0; bx <= bx1; bx++) {
        final relX = bx + 0.5 - centerBx;
        final slopeY = wallSign * relX * slopeRatio;
        final lx = relX * invS;
        final ly = (relY - slopeY) * invS;
        final sx = (lx + sox).floor();
        final sy = (ly + soy).floor();
        if (sx < 0 || sy < 0 || sx >= sw || sy >= sh) continue;
        final sIdx = sy * sw + sx;
        final col = _scratch.color[sIdx];
        final lgt = _scratch.light[sIdx];
        if ((col >>> 24) == 0 && (lgt & 0xffffff) == 0) continue;

        final tileDelta = relX / math.max(1.0, proj.tileHalfW);
        final wx = leftWall ? owner.worldX + tileDelta : owner.worldX;
        final wy = leftWall ? owner.worldY : owner.worldY - tileDelta;
        final wz = owner.worldZ + (-ly * effScale) / zStep;
        final dk = proj.depthKey(wx, wy, wz);
        _emitPixel(frame, depthBuf, bx, by, dk, col, lgt, lightOpt);
      }
    }
  }
}
