// Ten starter 2.5D isometric tiles, props, and VFX in the `iso/*` category.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'iso_painter.dart';
import 'iso_sim.dart';
import 'projection.dart';

/// 1. `iso/stone-tile`: Carved 2:1 dimetric dungeon flagstone tile with beveled rim.
final PureEffect isoStoneTile = PureEffect(
  meta: const EffectMeta(
    id: 'iso/stone-tile',
    name: 'Iso Stone Tile',
    desc: 'Crisp 2:1 dimetric dungeon flagstone tile with bevel highlights and stone skirt.',
    kind: AssetKind.tileset,
    category: 'iso',
    tags: ['iso', 'tile', 'stone', 'dungeon', '2.5d'],
    size: (44, 34),
    origin: (22, 16),
    duration: 0.4,
    loop: true,
    fps: 10,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.stone, 'seed': 1},
    extra: {'archetype': 'iso_tile', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 6);
    final ip = IsoPainter.fromPainter(p);
    ip.isoBox(
      -0.46,
      -0.46,
      -0.34,
      0.92,
      0.92,
      0.34,
      topCol: c[3],
      leftCol: c[2],
      rightCol: c[1],
      bevelCol: c[4],
      outlineCol: c[0],
    );
    // Carved masonry seam & subtle corner chip details on top diamond.
    for (var i = -3; i <= 3; i++) {
      final u = i * 0.1;
      ip.isoPixel(u, 0.0, 0.01, c[2]);
      if (i.abs() <= 2) ip.isoPixel(0.0, u, 0.01, c[2]);
    }
    ip.isoPixel(-0.22, 0.18, 0.01, c[5]);
    ip.isoPixel(0.18, -0.20, 0.01, c[4]);
  },
);

/// 2. `iso/grass-tile`: Elevated 2:1 meadow diamond with layered soil skirt & swaying blades.
final PureEffect isoGrassTile = PureEffect(
  meta: const EffectMeta(
    id: 'iso/grass-tile',
    name: 'Iso Grass Tile',
    desc: '2:1 isometric turf block with layered earth cliff and animated wind-swayed grass blades.',
    kind: AssetKind.tileset,
    category: 'iso',
    tags: ['iso', 'tile', 'grass', 'nature', '2.5d'],
    size: (44, 36),
    origin: (22, 18),
    duration: 1.6,
    loop: true,
    fps: 15,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.leaf, 'seed': 2},
    extra: {'archetype': 'iso_tile', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 6);
    final earth = fit(Pal.earth, 5);
    final ip = IsoPainter.fromPainter(p);
    ip.isoBox(
      -0.46,
      -0.46,
      -0.32,
      0.92,
      0.92,
      0.24,
      topCol: earth[2],
      leftCol: earth[1],
      rightCol: earth[0],
      outlineCol: c[0],
    );
    ip.isoBox(
      -0.46,
      -0.46,
      -0.08,
      0.92,
      0.92,
      0.10,
      topCol: c[3],
      leftCol: c[2],
      rightCol: c[1],
      bevelCol: c[4],
      outlineCol: c[0],
    );

    final r = Rng(o.seed * 31 + 7);
    final ph = (t / 1.6) * tau;
    for (var i = 0; i < 8; i++) {
      final gx = r.range(-0.34, 0.34);
      final gy = r.range(-0.34, 0.34);
      final sway = math.sin(ph + gx * 4.0 + i) * 0.05;
      ip.isoPixel(gx, gy, 0.04, c[2]);
      ip.isoPixel(gx + sway, gy, 0.11, i.isEven ? c[4] : c[5]);
    }
  },
);

/// 3. `iso/water-tile`: Animated translucent water basin with crest ripples & specular glints.
final PureEffect isoWaterTile = PureEffect(
  meta: const EffectMeta(
    id: 'iso/water-tile',
    name: 'Iso Water Tile',
    desc: 'Looping 2:1 dimetric water tile with traveling diagonal ripple crests and glints.',
    kind: AssetKind.tileset,
    category: 'iso',
    tags: ['iso', 'tile', 'water', 'loop', '2.5d'],
    size: (44, 34),
    origin: (22, 16),
    duration: 1.6,
    loop: true,
    fps: 15,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.water, 'seed': 3},
    extra: {'archetype': 'iso_tile', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 7);
    final ip = IsoPainter.fromPainter(p);
    ip.isoBox(
      -0.46,
      -0.46,
      -0.30,
      0.92,
      0.92,
      0.28,
      topCol: c[2],
      leftCol: c[1],
      rightCol: c[0],
      bevelCol: c[3],
      outlineCol: c[0],
    );
    final ph = (t / 1.6) * tau;
    for (var iy = -3; iy <= 3; iy++) {
      for (var ix = -3; ix <= 3; ix++) {
        final wx = ix * 0.11;
        final wy = iy * 0.11;
        final wv = math.sin(ph + (wx + wy) * 5.0);
        if (wv > 0.45) {
          ip.isoPixel(wx, wy, 0.0, wv > 0.8 ? c[5] : c[4]);
        }
      }
    }
    final glX = math.cos(ph) * 0.2;
    final glY = math.sin(ph) * 0.18;
    ip.isoPixel(glX, glY, 0.02, c[6]);
    ip.isoGlow(glX, glY, 0.05, 5.0, c[4], 0.35);
  },
);

/// 4. `iso/lava-tile`: Basalt crust floating over glowing molten fissures & popping embers.
final PureEffect isoLavaTile = PureEffect(
  meta: const EffectMeta(
    id: 'iso/lava-tile',
    name: 'Iso Lava Tile',
    desc: 'Looping 2:1 volcanic basalt tile with pulsing magma seams and rising ember glow.',
    kind: AssetKind.tileset,
    category: 'iso',
    tags: ['iso', 'tile', 'lava', 'fire', 'loop'],
    size: (44, 34),
    origin: (22, 16),
    duration: 1.8,
    loop: true,
    fps: 15,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.lava, 'seed': 4},
    extra: {'archetype': 'iso_tile', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 7);
    final rock = fit(Pal.stone, 5);
    final ip = IsoPainter.fromPainter(p);
    ip.isoBox(
      -0.46,
      -0.46,
      -0.30,
      0.92,
      0.92,
      0.28,
      topCol: c[2],
      leftCol: rock[1],
      rightCol: rock[0],
      bevelCol: c[3],
      outlineCol: c[0],
    );
    final ph = (t / 1.8) * tau;
    final pulse = 0.5 + 0.5 * math.sin(ph);
    // Basalt crust islands + pulsing lava vein down the center.
    ip.isoBox(-0.36, -0.36, -0.02, 0.30, 0.30, 0.06,
        topCol: rock[2], leftCol: rock[1], rightCol: rock[0]);
    ip.isoBox(0.06, 0.06, -0.02, 0.30, 0.30, 0.06,
        topCol: rock[2], leftCol: rock[1], rightCol: rock[0]);
    for (var i = -3; i <= 3; i++) {
      final u = i * 0.1;
      ip.isoPixel(u, -u * 0.6, 0.01, pulse > 0.5 ? c[5] : c[4]);
    }
    ip.isoGlow(0.0, 0.0, 0.05, 8.0 + pulse * 3.0, c[4], 0.45 + 0.25 * pulse);
  },
);

/// 5. `iso/dungeon-crate`: Beveled 2:1 wooden crate with corner bands & soft ground shadow.
final PureEffect isoDungeonCrate = PureEffect(
  meta: const EffectMeta(
    id: 'iso/dungeon-crate',
    name: 'Iso Dungeon Crate',
    desc: 'Sturdy 2.5D wooden supply crate with top-left lighting bevel, dark ink outline, and shadow.',
    kind: AssetKind.prop,
    category: 'iso',
    tags: ['iso', 'prop', 'crate', 'wood', '2.5d'],
    size: (64, 64),
    origin: (32, 44),
    duration: 0.4,
    loop: true,
    fps: 10,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.wood, 'seed': 5},
    extra: {'archetype': 'iso_prop', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 7);
    final metal = fit(Pal.metal, 5);
    final ip = IsoPainter.fromPainter(p);
    ip.isoShadow(0.0, 0.0, 0.0, 0.52, 0.52, 0.55);
    ip.isoBox(
      -0.36,
      -0.36,
      0.0,
      0.72,
      0.72,
      0.70,
      topCol: c[4],
      leftCol: c[3],
      rightCol: c[2],
      bevelCol: c[5],
      outlineCol: c[0],
    );
    // Diagonal brace ribs + iron rim rivets on front faces.
    ip.isoLine3D(const IsoCoord(-0.28, 0.37, 0.1), const IsoCoord(0.28, 0.37, 0.6), c[1]);
    ip.isoLine3D(const IsoCoord(0.37, -0.28, 0.1), const IsoCoord(0.37, 0.28, 0.6), c[1]);
    ip.isoPixel(-0.34, 0.36, 0.66, metal[3]);
    ip.isoPixel(0.36, -0.34, 0.66, metal[3]);
    ip.isoPixel(0.36, 0.36, 0.66, metal[4]);
  },
);

/// 6. `iso/torch-sconce`: Iron pedestal brazier burning with 3D embers & warm floor glow.
final PureEffect isoTorchSconce = PureEffect(
  meta: const EffectMeta(
    id: 'iso/torch-sconce',
    name: 'Iso Torch Sconce',
    desc: 'Iron isometric dungeon brazier with flickering depth-sorted flame and rising embers.',
    kind: AssetKind.prop,
    category: 'iso',
    tags: ['iso', 'prop', 'fire', 'torch', 'loop'],
    size: (64, 64),
    origin: (32, 46),
    duration: 1.6,
    loop: true,
    fps: 20,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.fire, 'seed': 6},
    extra: {'archetype': 'iso_prop', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final fire = fit(o.palette, 8);
    final metal = fit(Pal.metal, 6);
    final ip = IsoPainter.fromPainter(p);
    final ph = (t / 1.6) * tau;
    final flicker = 0.88 + 0.12 * math.sin(ph * 3.0);

    ip.isoShadow(0.0, 0.0, 0.0, 0.38, 0.38, 0.5);
    ip.isoPillar(0.0, 0.0, 0.0, 0.52, 0.11, metal.sublist(0, 4), outlineCol: metal[0]);
    ip.isoBox(
      -0.20,
      -0.20,
      0.48,
      0.40,
      0.40,
      0.16,
      topCol: metal[3],
      leftCol: metal[2],
      rightCol: metal[1],
      bevelCol: metal[4],
      outlineCol: metal[0],
    );

    // Sculpted layered flame tongues.
    ip.isoGlow(0.0, 0.0, 0.85, 16.0 * flicker, fire[4], 0.55 * flicker);
    ip.isoGlow(0.0, 0.0, 0.10, 12.0 * flicker, fire[3], 0.30 * flicker);
    for (var i = 0; i < 6; i++) {
      final a = ph + i * (tau / 6.0);
      final h = 0.68 + ((i & 1) == 0 ? 0.24 : 0.14) * flicker;
      final rOff = 0.08 * math.cos(a * 2.0);
      ip.isoDisc(rOff, 0.04 * math.sin(a), h, 0.12 * (1.0 - i * 0.08),
          fire[math.min(7, 4 + (i ~/ 2))]);
    }
    cycleFixed(t, 1.6, 5, o.seed + 11, 0.7, (age, life, r, _) {
      final k = age / life;
      final a = r.range(0.0, tau);
      final rad = 0.05 + k * 0.18;
      ip.isoPixel(
        math.cos(a) * rad,
        math.sin(a) * rad,
        0.72 + k * 0.55,
        k < 0.4 ? fire[6] : fire[4],
        1.0 - k,
      );
    });
  },
);

/// 7. `iso/crystal-obelisk`: Levitating beveled crystal spire above a glowing floor rune.
final PureEffect isoCrystalObelisk = PureEffect(
  meta: const EffectMeta(
    id: 'iso/crystal-obelisk',
    name: 'Iso Crystal Obelisk',
    desc: 'Levitating isometric arcane crystal spire casting a pulsing ground rune and orbiting motes.',
    kind: AssetKind.prop,
    category: 'iso',
    tags: ['iso', 'prop', 'crystal', 'arcane', 'loop'],
    size: (64, 68),
    origin: (32, 48),
    duration: 2.0,
    loop: true,
    fps: 20,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.arcane, 'seed': 7},
    extra: {'archetype': 'iso_prop', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ip = IsoPainter.fromPainter(p);
    final ph = (t / 2.0) * tau;
    final bob = 0.08 * math.sin(ph);

    ip.isoShadow(0.0, 0.0, 0.0, 0.36 - bob * 0.4, 0.36 - bob * 0.4, 0.42);
    ip.isoRing(0.0, 0.0, 0.01, 0.48, 0.08, c[4], 0.65);
    ip.isoGlow(0.0, 0.0, 0.05, 13.0, c[4], 0.4);

    // Floating crystal column + bright bevel facets.
    ip.isoBox(
      -0.20,
      -0.20,
      0.28 + bob,
      0.40,
      0.40,
      0.86,
      topCol: c[6],
      leftCol: c[4],
      rightCol: c[2],
      bevelCol: c[7],
      outlineCol: c[0],
    );
    ip.isoSlope(
      -0.16,
      -0.16,
      1.12 + bob,
      0.32,
      0.32,
      0.04,
      0.26,
      topCol: c[6],
      leftCol: c[5],
      rightCol: c[3],
      outlineCol: c[0],
    );
    ip.isoGlow(0.0, 0.0, 0.85 + bob, 14.0, c[5], 0.55);

    for (var i = 0; i < 4; i++) {
      final a = ph + i * (tau / 4.0);
      ip.isoPixel(
        math.cos(a) * 0.46,
        math.sin(a) * 0.46,
        0.55 + bob + 0.14 * math.sin(a * 2.0),
        c[7],
      );
    }
  },
);

/// 8. `iso/diagonal-slash`: One-shot 3D sweeping sword arc with depth-sorted impact sparks & act spec.
final PureEffect isoDiagonalSlash = PureEffect(
  meta: const EffectMeta(
    id: 'iso/diagonal-slash',
    name: 'Iso Diagonal Slash',
    desc: 'One-shot 2.5D isometric diagonal blade cleave sweeping across space with bright edge glow.',
    kind: AssetKind.effect,
    category: 'iso',
    tags: ['iso', 'vfx', 'melee', 'slash', 'one-shot'],
    size: (80, 64),
    origin: (40, 42),
    duration: 0.45,
    loop: false,
    fps: 30,
    bg: BackdropKind.isoGrid,
    actorScale: 1,
    defaultOptions: {'palette': Pal.electric, 'seed': 8},
    extra: {'archetype': 'iso_effect', 'iso': true},
  ),
  act: const ActSpec(
    target: TargetSpec(x: 30),
    poses: [
      PoseKey(-0.15, kReady),
      PoseKey(0.08, Pose(weapon: 'sword', crouch: 4, lean: 5, fx: 20, fy: -21, sa: 0.4, ghost: 1), PoseEase.snap),
      PoseKey(0.45, kStand),
    ],
    hits: [
      HitSpec(t: 0.08, stop: 0.06, shake: 0.12, amp: 2.0, target: true, push: 2.2, straw: 8),
    ],
  ),
  onDraw: (p, t, o) {
    final u = t / 0.45;
    if (u >= 0.999 || t < 0.0) return;
    final c = fit(o.palette, 7);
    final ip = IsoPainter.fromPainter(p);

    final sweep = Ease.outCubic(clamp(u / 0.55));
    final fade = 1.0 - seg(u, 0.35, 0.98);
    if (fade <= 0.01) return;

    const steps = 16;
    const radius = 0.85;
    final headAngle = lerp(-1.1, 1.35, sweep);
    final tailAngle = math.max(-1.1, headAngle - 1.15);

    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final ang = lerp(tailAngle, headAngle, f);
      final z = 0.55 - ang * 0.16;
      final wx = math.cos(ang) * radius + 0.15;
      final wy = math.sin(ang) * radius;
      final col = f > 0.7 ? c[6] : (f > 0.35 ? c[5] : c[3]);
      final thickness = f > 0.6 ? 0.12 : 0.06;
      ip.isoDisc(wx, wy, z, thickness, col, fade * (0.35 + 0.65 * f));
      if (i.isEven) {
        ip.isoGlow(wx, wy, z, 7.0, c[4], 0.4 * fade * f);
      }
    }

    // Impact sparks bursting outward at peak hit.
    if (u > 0.15) {
      final r = Rng(o.seed * 19 + 3);
      for (var i = 0; i < 6; i++) {
        final a = r.range(-1.0, 1.0);
        final sp = r.range(0.5, 1.2) * (u - 0.15);
        final vz = r.range(0.2, 0.6);
        final px = 0.7 + math.cos(a) * sp;
        final py = math.sin(a) * sp;
        final pz = math.max(0.02, 0.45 + vz * (u - 0.15) - 1.6 * (u - 0.15) * (u - 0.15));
        ip.isoPixel(px, py, pz, c[6], fade);
      }
    }
  },
);

/// 9. `iso/ground-shockwave`: One-shot 2.5D crater pulse with bouncing rock splinters via [IsoBits].
class _IsoShockwaveSim extends BaseEffectSim {
  final IsoBits bits = IsoBits();
  final List<int> palette;
  final double duration = 0.6;
  double _elapsed = 0.0;

  _IsoShockwaveSim(this.palette, int seed) {
    final r = Rng(seed + 17);
    for (var i = 0; i < 8; i++) {
      final a = (i / 8.0) * tau + r.range(-0.2, 0.2);
      final sp = r.range(0.9, 1.7);
      bits.add(
        x: math.cos(a) * 0.15,
        y: math.sin(a) * 0.15,
        z: 0.06,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp,
        vz: r.range(2.8, 4.4),
        life: duration - 0.06,
        size: r.range(0.10, 0.15),
        rampColors: palette,
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    _elapsed += dt;
    bits.update(dt);
  }

  @override
  void draw(Painter p) {
    final u = _elapsed / duration;
    if (u >= 0.999) return;
    final ip = IsoPainter.fromPainter(p);
    final ringU = Ease.outCubic(clamp(u / 0.8));
    final a = 1.0 - seg(u, 0.35, 0.98);
    if (a > 0.01) {
      ip.isoRing(0.0, 0.0, 0.02, 0.12 + ringU * 0.9, 0.16 * a, palette[4], a);
      ip.isoGlow(0.0, 0.0, 0.05, 14.0 * (1.0 - u), palette[3], 0.55 * a);
      bits.draw(ip);
    }
  }
}

final SimulatedEffect isoGroundShockwave = SimulatedEffect(
  meta: const EffectMeta(
    id: 'iso/ground-shockwave',
    name: 'Iso Ground Shockwave',
    desc: 'One-shot 2.5D expanding floor shockwave with depth-sorted rock splinters bouncing on ground.',
    kind: AssetKind.effect,
    category: 'iso',
    tags: ['iso', 'vfx', 'impact', 'shockwave', 'one-shot'],
    size: (80, 58),
    origin: (40, 34),
    duration: 0.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.earth, 'seed': 9},
    extra: {'archetype': 'iso_effect', 'iso': true},
  ),
  onCreate: (o) => _IsoShockwaveSim(fit(o.palette, 6), o.seed),
);

/// 10. `iso/iso-portal`: Looping twin obsidian pillars flanking a swirling 2.5D arcane gateway.
final PureEffect isoPortal = PureEffect(
  meta: const EffectMeta(
    id: 'iso/iso-portal',
    name: 'Iso Arcane Portal',
    desc: 'Looping 2.5D isometric portal archway with swirling magic vortex and flanking stone pillars.',
    kind: AssetKind.prop,
    category: 'iso',
    tags: ['iso', 'portal', 'magic', 'prop', 'loop'],
    size: (76, 72),
    origin: (38, 50),
    duration: 2.0,
    loop: true,
    fps: 20,
    bg: BackdropKind.isoGrid,
    defaultOptions: {'palette': Pal.arcane, 'seed': 10},
    extra: {'archetype': 'iso_prop', 'iso': true},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final stone = fit(Pal.stone, 5);
    final ip = IsoPainter.fromPainter(p);
    final ph = (t / 2.0) * tau;

    ip.isoShadow(0.0, 0.0, 0.0, 0.68, 0.52, 0.5);
    // Floor threshold ring.
    ip.isoRing(0.0, 0.0, 0.02, 0.56, 0.1, c[3], 0.75);

    // Twin stone pillars along NE-SW diagonal (separated on screen).
    ip.isoPillar(-0.48, 0.48, 0.0, 1.08, 0.13, stone, outlineCol: stone[0]);
    ip.isoPillar(0.48, -0.48, 0.0, 1.08, 0.13, stone, outlineCol: stone[0]);

    // Swirling vertical portal curtain between pillars.
    const pts = 18;
    for (var i = 0; i < pts; i++) {
      final a = ph + i * (tau / pts);
      final rad = 0.28 + 0.06 * math.sin(a * 2.0 - ph);
      final along = math.cos(a) * rad;
      final z = 0.56 + math.sin(a) * 0.34;
      ip.isoDisc(along, -along, z, 0.08, c[4 + (i % 3)], 0.85);
    }
    ip.isoGlow(0.0, 0.0, 0.56, 15.0, c[4], 0.55);
  },
);

/// Ordered catalog of all 10 starter 2.5D isometric tiles, props, and VFX.
final List<PixelAsset> isoStarterAssets = [
  isoCrystalObelisk,
  isoDiagonalSlash,
  isoDungeonCrate,
  isoGrassTile,
  isoGroundShockwave,
  isoLavaTile,
  isoPortal,
  isoStoneTile,
  isoTorchSconce,
  isoWaterTile,
];
