import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_iso/pixelfx_iso.dart';
import 'package:test/test.dart';

void main() {
  group('IsoProjection & PixelIsoFrame', () {
    test('project <-> screenToGround round-trips accurately including elevated Z', () {
      const proj = IsoProjection.standard();
      for (final (x, y, z) in const [
        (0.0, 0.0, 0.0),
        (2.5, -1.25, 0.0),
        (-3.0, 4.0, 1.5),
        (1.75, 2.25, 0.8),
      ]) {
        final (sx, sy) = proj.project(x, y, z);
        final (gx, gy) = proj.screenToGround(sx, sy, z: z);
        expect(gx, closeTo(x, 1e-9));
        expect(gy, closeTo(y, 1e-9));
      }
      expect(proj.projectSnapped(1.0, 0.0, 0.0), equals((16, 8)));
      expect(proj.projectSnapped(0.0, 1.0, 0.0), equals((-16, 8)));
      expect(proj.projectSnapped(0.0, 0.0, 1.0), equals((0, -16)));
    });

    test('depth-buffered occlusion puts foreground objects in front of background objects', () {
      const proj = IsoProjection.standard();
      final frame = createIsoFrame(64, 64, -32, -32);
      final ip = IsoPainter(frame, projection: proj)..place(0, 0);

      // Draw foreground box FIRST, then background box SECOND behind it.
      final fgColor = hex('#ff4444');
      final bgColor = hex('#4488ff');
      ip.isoBox(0.25, 0.25, 0.0, 0.5, 0.5, 1.0,
          topCol: fgColor, leftCol: fgColor, rightCol: fgColor);
      ip.isoBox(-0.5, -0.5, 0.0, 0.5, 0.5, 0.25,
          topCol: bgColor, leftCol: bgColor, rightCol: bgColor);

      // Both (-0.25, -0.25, 0.25) and (0.5, 0.5, 1.0) map to screen (0, -8); fgColor must remain in front!
      final (sx, sy) = proj.projectSnapped(0.5, 0.5, 1.0);
      final bx = sx - frame.ox;
      final by = sy - frame.oy;
      expect(frame.color[by * frame.w + bx], equals(fgColor));
    });

    test('isoDiamondBackdrop builds crisp 2:1 grid buffer', () {
      final buf = isoDiamondBackdrop(64, 48);
      expect(buf.length, equals(64 * 48));
      expect(buf.toSet().length, greaterThan(2));
    });
  });

  group('IsoParticles & IsoBits', () {
    test('bounce deterministically on custom heightmap', () {
      final ps = IsoParticles(
        seed: 7,
        groundZ: (x, y) => x > 0 ? 0.5 : 0.0,
      );
      ps.spawn(0.2, 0.0, 0.8, 0.0, 0.0, -2.0, 1.0, kWhite);
      for (var i = 0; i < 30; i++) {
        ps.update(1 / 60);
      }
      expect(ps.list, isNotEmpty);
      expect(ps.list.first.z, greaterThanOrEqualTo(0.5));
    });
  });

  group('IsoProjectedEffect & IsoRig', () {
    final test2dFx = PureEffect(
      meta: const EffectMeta(
        id: 'test/orb',
        name: 'Orb',
        desc: 'Test 2D orb for projection.',
        size: (32, 32),
        origin: (16, 16),
        duration: 0.4,
        loop: true,
        fps: 10,
        defaultOptions: {'palette': Pal.electric, 'seed': 1},
      ),
      act: const ActSpec(
        target: TargetSpec(x: 24),
        poses: [
          PoseKey(-0.1, kStand),
          PoseKey(0.1, kReady),
          PoseKey(0.4, kStand),
        ],
        hits: [HitSpec(t: 0.1, stop: 0.05, shake: 0.1, amp: 2.0, target: true, push: 1.5)],
      ),
      onDraw: (p, t, o) {
        final c = fit(o.palette, 5);
        p.circle(0, 0, 6, c[3]);
        p.glow(0, 0, 8, c[4], 0.5);
      },
    );

    test('projects 2D effect across all 4 IsoPlane modes cleanly', () {
      for (final plane in IsoPlane.values) {
        final wrapped = IsoProjectedEffect(test2dFx, plane: plane, dir: IsoDir.se);
        expect(wrapped.meta.bg, equals(BackdropKind.isoGrid));
        final f = createIsoFrame(wrapped.meta.width, wrapped.meta.height);
        final inst = wrapped.createInstance();
        inst.update(0.1);
        inst.draw(f);
        expect(
          f.color.any((c) => (c >>> 24) != 0),
          isTrue,
          reason: 'Empty output for plane=$plane',
        );
      }
    });

    test('posedIso, skeletonIso, isoTurntableBounds and IsoActInstance work across 8 dirs', () {
      final rig = RigRasterizer.instance;
      for (final dir in IsoDir.values) {
        final fig = posedIso(rig, kStand.copyWith(weapon: 'sword'), dir: dir);
        expect(fig.n, greaterThan(0), reason: 'No rig pixels for $dir');
        final sk = skeletonIso(rig, kStand, dir: dir);
        expect(sk.joints['head']!.$2, lessThan(sk.joints['pelvis']!.$2));
      }

      final bounds = isoTurntableBounds(test2dFx, rig);
      expect(bounds.width, greaterThan(40));
      expect(bounds.height, greaterThan(40));

      final hitTimes = <double>[];
      final act = IsoActInstance(
        source: test2dFx,
        spec: const IsoActSpec(dir: IsoDir.se),
        onHit: (h) => hitTimes.add(h.t),
      );
      final frame = createIsoFrame(bounds.width, bounds.height);
      for (var i = 0; i < 12; i++) {
        act.update(1 / 30);
        clearIsoFrame(frame);
        act.draw(frame);
      }
      expect(hitTimes, equals([0.1]));
      expect(frame.color.any((c) => (c >>> 24) != 0), isTrue);
    });
  });

  group('PixelFxIsoExtension & 10 starter assets', () {
    test('registers 10 iso/* assets and 3 archetypes deterministically', () {
      final reg = createIsoRegistry();
      expect(reg.assets.length, equals(10));
      expect(reg.archetypes.keys, containsAll(['iso_tile', 'iso_prop', 'iso_effect']));

      for (final asset in isoStarterAssets) {
        final m = asset.meta;
        expect(m.id.startsWith('iso/'), isTrue);
        final fa = createIsoFrame(m.width, m.height);
        final fb = createIsoFrame(m.width, m.height);
        final ia = asset.createInstance({'x': m.originX, 'y': m.originY});
        final ib = asset.createInstance({'x': m.originX, 'y': m.originY});

        final steps = (m.duration * m.fps).round().clamp(4, 24);
        final dt = m.duration / steps;
        var anyDrawn = false;
        for (var i = 0; i <= steps; i++) {
          if (i > 0) {
            ia.update(dt);
            ib.update(dt);
          }
          clearIsoFrame(fa);
          clearIsoFrame(fb);
          ia.draw(fa);
          ib.draw(fb);
          expect(fa.color, orderedEquals(fb.color), reason: 'Non-deterministic ${m.id}');
          if (fa.color.any((c) => (c >>> 24) != 0)) anyDrawn = true;
        }
        expect(anyDrawn, isTrue, reason: '${m.id} drew nothing');

        if (!m.loop) {
          expect(fa.color.any((c) => (c >>> 24) != 0), isFalse,
              reason: 'One-shot ${m.id} had trailing pixels at t=duration');
        }
      }
    });
  });
}
