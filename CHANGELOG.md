## 0.1.0

- Initial release: pure-Dart 2.5D isometric engine on top of `pixelfx_core ^0.2.0`.
- Adds `IsoCoord`, `IsoProjection` (2:1 dimetric forward projection + exact inverse `screenToGround`), `PixelIsoFrame` (`Int16List` depth buffer + soft light bleed), `IsoPainter` (`isoBox`, `isoPillar`, `isoSlope`, `isoDisc`, `isoRing`, `isoLine3D`, `isoBolt3D`, `isoGlow`), `IsoParticles` & `IsoBits` heightmap physics, 8-directional `posedIso` / `IsoActInstance`, `IsoProjectedEffect` wrapper for reusing 2D catalog assets across `IsoPlane` modes, 2.5D `AssetArchetype`s (`iso_tile`, `iso_prop`, `iso_effect`), and 10 starter assets in `PixelFxIsoExtension`.
