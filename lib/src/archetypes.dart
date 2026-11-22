// Isometric archetypes (iso_tile, iso_prop, iso_effect), check rules, and scaffold templates.

import 'package:pixelfx_core/pixelfx_core.dart';

/// Ensures isometric assets produce non-empty pixel frames.
class IsoNonEmptyRule implements CheckRule {
  final String prefix;

  const IsoNonEmptyRule([this.prefix = 'iso']);

  @override
  String get id => '$prefix.non_empty';

  @override
  List<CheckIssue> validate(CheckContext ctx) {
    if (ctx.rawColorFrames.isEmpty) {
      return [
        CheckIssue(
          CheckSeverity.error,
          '$prefix.no_frames',
          'Isometric asset "${ctx.asset.meta.id}" produced no rendered frames.',
        ),
      ];
    }
    var drawn = false;
    for (final frame in ctx.rawColorFrames) {
      for (final c in frame) {
        if ((c >>> 24) != 0) {
          drawn = true;
          break;
        }
      }
      if (drawn) break;
    }
    if (!drawn) {
      return [
        CheckIssue(
          CheckSeverity.error,
          '$prefix.empty',
          'Isometric asset "${ctx.asset.meta.id}" rendered zero opaque pixels.',
        ),
      ];
    }
    return const [];
  }
}

/// Validates 2:1 dimetric tile dimensions (`width >= 32`, `height >= 16`) and origin bounds.
class IsoTileGridRule implements CheckRule {
  @override
  String get id => 'iso_tile.grid_alignment';

  @override
  List<CheckIssue> validate(CheckContext ctx) {
    final m = ctx.asset.meta;
    final out = <CheckIssue>[];
    if (m.width < 32 || m.height < 16) {
      out.add(CheckIssue(
        CheckSeverity.error,
        'iso_tile.too_small',
        'Tile "${m.id}" is ${m.width}x${m.height}; minimum 2:1 iso diamond is 32x16.',
      ));
    }
    if (m.originX < 8 || m.originX > m.width - 8) {
      out.add(CheckIssue(
        CheckSeverity.warning,
        'iso_tile.origin_offcenter',
        'Tile "${m.id}" originX=${m.originX} sits close to horizontal canvas edge.',
      ));
    }
    return out;
  }
}

/// Enforces an interactive 2.5D frame budget (`<= 2.5 ms` per frame).
class IsoFrameBudgetRule implements CheckRule {
  final double maxMedianMs;

  const IsoFrameBudgetRule({this.maxMedianMs = 2.5});

  @override
  String get id => 'iso.frame_budget';

  @override
  List<CheckIssue> validate(CheckContext ctx) {
    final med = ctx.medianFrameMs;
    if (med > maxMedianMs) {
      return [
        CheckIssue(
          CheckSeverity.warning,
          'iso.slow_frame',
          'Isometric asset "${ctx.asset.meta.id}" took ${med.toStringAsFixed(2)} ms/frame (budget <= ${maxMedianMs.toStringAsFixed(1)} ms).',
        ),
      ];
    }
    return const [];
  }
}

/// Archetype for 2:1 dimetric floor & water/lava terrain tiles (`iso_tile`).
class IsoTileArchetype extends AssetArchetype {
  @override
  String get id => 'iso_tile';

  @override
  AssetKind get kind => AssetKind.tileset;

  @override
  String get description =>
      'Isometric 2:1 dimetric terrain tile with top highlight bevel and extruded skirt.';

  @override
  List<CheckRule> get checkRules => [
        const IsoNonEmptyRule('iso_tile'),
        IsoTileGridRule(),
        const IsoFrameBudgetRule(),
      ];

  @override
  String scaffoldTemplate({
    required String id,
    required String className,
    Map<String, String> params = const {},
  }) =>
      """
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_iso/pixelfx_iso.dart';

final PureEffect $className = PureEffect(
  meta: const EffectMeta(
    id: '$id',
    name: '$className',
    desc: 'Generated 2:1 isometric terrain tile with extruded stone rim.',
    kind: AssetKind.tileset,
    category: 'iso',
    tags: ['iso', 'tile', '2.5d'],
    size: (44, 34),
    origin: (22, 16),
    duration: 1.0,
    loop: true,
    fps: 12,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.stone, 'seed': 1},
    extra: {'archetype': 'iso_tile', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 6);
    IsoPainter.fromPainter(p).isoBox(
      -0.5,
      -0.5,
      -0.35,
      1.0,
      1.0,
      0.35,
      topCol: c[3],
      leftCol: c[2],
      rightCol: c[1],
      bevelCol: c[4],
      outlineCol: c[0],
    );
  },
);
""";
}

/// Archetype for 2.5D lit props, crates, sconces, and interactive shrines (`iso_prop`).
class IsoPropArchetype extends AssetArchetype {
  @override
  String get id => 'iso_prop';

  @override
  AssetKind get kind => AssetKind.prop;

  @override
  String get description =>
      'Isometric 2.5D depth-buffered prop with top-left light bevel, contact shadow, and optional flame/glow.';

  @override
  List<CheckRule> get checkRules => [
        const IsoNonEmptyRule('iso_prop'),
        const IsoFrameBudgetRule(),
      ];

  @override
  String scaffoldTemplate({
    required String id,
    required String className,
    Map<String, String> params = const {},
  }) =>
      """
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_iso/pixelfx_iso.dart';

final PureEffect $className = PureEffect(
  meta: const EffectMeta(
    id: '$id',
    name: '$className',
    desc: 'Generated 2.5D isometric pulsing prop with ground shadow.',
    kind: AssetKind.prop,
    category: 'iso',
    tags: ['iso', 'prop', '2.5d'],
    size: (64, 64),
    origin: (32, 46),
    duration: 1.6,
    loop: true,
    fps: 24,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.arcane, 'seed': 1},
    extra: {'archetype': 'iso_prop', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 7);
    final ip = IsoPainter.fromPainter(p);
    final pulse = 0.85 + 0.15 * math.sin((t / 1.6) * tau * 2.0);
    ip.isoShadow(0.0, 0.0, 0.0, 0.42, 0.42, 0.5);
    ip.isoPillar(0.0, 0.0, 0.0, 0.65, 0.24, c, outlineCol: c[0]);
    ip.isoGlow(0.0, 0.0, 0.85, 16.0 * pulse, c[4], 0.5 * pulse);
  },
);
""";
}

/// Archetype for 2.5D depth-buffered VFX, combat slashes, and ground rings (`iso_effect`).
class IsoEffectArchetype extends AssetArchetype {
  @override
  String get id => 'iso_effect';

  @override
  AssetKind get kind => AssetKind.effect;

  @override
  String get description =>
      'Isometric 2.5D visual effect with world-space particles, ground shockwaves, or 3D bolts.';

  @override
  List<CheckRule> get checkRules => [
        const IsoNonEmptyRule('iso_effect'),
        const IsoFrameBudgetRule(),
      ];

  @override
  String scaffoldTemplate({
    required String id,
    required String className,
    Map<String, String> params = const {},
  }) =>
      """
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_iso/pixelfx_iso.dart';

final PureEffect $className = PureEffect(
  meta: const EffectMeta(
    id: '$id',
    name: '$className',
    desc: 'Generated 2.5D isometric expanding energy ring and glow pulse.',
    kind: AssetKind.effect,
    category: 'iso',
    tags: ['iso', 'vfx', 'one-shot'],
    size: (80, 56),
    origin: (40, 32),
    duration: 0.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.electric, 'seed': 1},
    extra: {'archetype': 'iso_effect', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final u = clamp(t / 0.6);
    if (u >= 1.0) return;
    final c = fit(o.palette, 6);
    final ip = IsoPainter.fromPainter(p);
    final r = 0.2 + Ease.outCubic(u) * 0.85;
    final a = 1.0 - u;
    ip.isoRing(0.0, 0.0, 0.05, r, 0.16 * a, c[4], a);
    ip.isoGlow(0.0, 0.0, 0.1, 14.0 * (1.0 - u * 0.5), c[3], 0.5 * a);
  },
);
""";
}
