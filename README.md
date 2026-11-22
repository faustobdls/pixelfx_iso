# pixelfx_iso

Pure-Dart **2.5D Isometric Pixel-Art** engine built cleanly on top of [`pixelfx_core`](https://pub.dev/packages/pixelfx_core):

- **2:1 Dimetric Projection (`IsoProjection`, `IsoCoord`, `IsoDir`):** integer-locked diamond steps (`dx = 2px, dy = 1px`) and exact analytical inverse `screenToGround(sx, sy, z: ...)`.
- **Depth-Buffered Dual Buffers (`PixelIsoFrame`, `IsoPainter`):** per-pixel `Int16List` painter depth ordering with translucent blending, soft additive light occlusion bleed, and drop shadows.
- **3D Heightmap Physics (`IsoParticles`, `IsoBits`):** fixed-120 Hz `(x, y, z)` particles bouncing against custom `groundZ(x, y)` elevation maps.
- **8-Directional Hero Rig (`posedIso`, `IsoActInstance`):** pitch-corrected `RigRasterizer` (`atan(0.5)`) across all 8 isometric compass facings.
- **Reuse All 244 2D Effects (`IsoProjectedEffect`) + 10 Starter Assets (`PixelFxIsoExtension`):** project any 2D effect onto `IsoPlane.floor`, `IsoPlane.upright`, or `IsoPlane.ringAndColumn`, plus native isometric tiles, props, and VFX ready for Flutter and Flame.

## Usage

```dart
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:pixelfx_iso/pixelfx_iso.dart';

final proj = const IsoProjection.standard();
final (sx, sy) = proj.project(1.5, 0.5, 0.25);
final (gx, gy) = proj.screenToGround(sx, sy, z: 0.25);

final reg = createIsoRegistry();
final portal = reg.getAsset('iso/iso-portal')!;
```
