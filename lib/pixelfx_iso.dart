// Pure-Dart 2.5D isometric engine extension for pixelfx: dimetric projection, depth buffer,
// isometric primitives, 3D pitched rigs, 2D->2.5D plane projection, and starter iso/* assets.

library;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/archetypes.dart';
import 'src/starter_assets.dart';

export 'src/archetypes.dart';
export 'src/iso_backdrop.dart';
export 'src/iso_frame.dart';
export 'src/iso_painter.dart';
export 'src/iso_rig.dart';
export 'src/iso_sim.dart';
export 'src/iso_wrapper.dart';
export 'src/projection.dart';
export 'src/starter_assets.dart';

/// Official `pixelfx_iso` extension providing the `iso` category, archetypes (`iso_tile`,
/// `iso_prop`, `iso_effect`), and 10 starter 2.5D isometric assets.
class PixelFxIsoExtension extends PixelFxExtension {
  @override
  ExtensionManifest get manifest => const ExtensionManifest(
        id: 'pixelfx.iso',
        name: 'Pixelfx Isometric 2.5D',
        version: '0.1.0',
        description:
            '2:1 dimetric isometric engine, depth-buffered primitives, pitched 3D rigs, and starter iso/* tiles, props, and VFX.',
        author: 'Fausto BDLS',
        tags: ['iso', 'isometric', '2.5d', 'dimetric', 'tiles', 'vfx'],
      );

  @override
  List<CategoryMeta> get categories => const [
        CategoryMeta(
          id: 'iso',
          name: 'Isometric 2.5D',
          blurb:
              '2:1 dimetric tiles, depth-buffered lit props, and 2.5D combat VFX.',
        ),
      ];

  @override
  List<AssetArchetype> get archetypes => [
        IsoTileArchetype(),
        IsoPropArchetype(),
        IsoEffectArchetype(),
      ];

  @override
  List<PixelAsset> get assets => isoStarterAssets;
}

/// Convenience registry containing [PixelFxIsoExtension] (plus an optional catalog/other extension).
PixelFxRegistry createIsoRegistry({PixelFxExtension? catalogExtension}) {
  final reg = PixelFxRegistry()..register(PixelFxIsoExtension());
  if (catalogExtension != null) reg.register(catalogExtension);
  return reg;
}
