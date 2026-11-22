# render/

Dither renderer. UNTESTED in the Godot editor (no Godot in the build sandbox). First job after merge: run `render_demo.gd` and check the points under "Verify first".

## Pipeline
World SubViewport (642x362, no AA) -> `toon.gdshader` writes a G-buffer (R palette index, G light, B object id) -> `post_dither.gdshader` on a ColorRect does outline, 3 dithered light bands, 4x4 Bayer pinned to the world, shimmer (10 fps), press ripples (max 8), palette lookup, zone shift, invert, ASCII.
No shadow maps: light is a direction uniform plus blob shadows (`ToonMaterial.shadow`).

## Files
- `pixel_viewport.gd` (`PixelViewport`): scene root for the view. Put 3D nodes in `world_root`. Integer scale, letterbox. Set `screen_shake` to a ScreenShake node and its whole-texel offset is added to the image offset.
- `iso_camera.gd` (`IsoCamera`): ortho, 30 deg down, 45 yaw, 16 texels per unit, camera-space texel snap, leftover fraction becomes the image offset. `target` follows with smoothing.
- `toon_material.gd` (`ToonMaterial.make(lit_index, object_id, wind, use_vertex_index)`): object id 1 = ground (no outline between ground texels).
- `fx_driver.gd`: autoload `Fx`. `Fx.bind(pixel_viewport)` once. Handles ripples, time, shimmer, palette targets. Listens to EventBus `button_pressed`, `zone_entered`, `gate_opened`, `rebirth_done` if EventBus exists.
- `palettes.gd`, `render_globals.gd`: the four palettes and the global shader uniforms (added at runtime).
- `render_demo.gd`: demo scene script (zone, tree, pad, walker). Keys: Space ripple, 1/2/3 palettes, I invert, A ASCII.

## For UI Transitions
`PixelViewport.post` is a ColorRect with uniforms `shift`, `invert`, `ascii`, as `transitions.gd` expects. Zone entry: `Fx.set_zone_palette(id)` (sets palette A/B, shift 0), then `Transitions.zone_shift()`. Fx does the first step itself on `zone_entered`. For rebirth, call `Fx.set_zone_palette(&"iris")` before `rebirth_ascii()` and set the zone palette back after.

## Verify first
1. Colour round trip: toon writes sRGB-encoded bytes via `to_linear()`. If the screenshot shows wrong palette indices, check the viewport/tonemap setup (Linear tonemap, no glow or fog).
2. Pan the camera slowly: dither must stay fixed to the world and not shimmer.
3. Ripples use screen-space ellipses (2:1) around the press point, not true ground projection.
4. The ripple array is passed as `PackedVector4Array`.
Deviation from SPEC section 4: no depth/normal outline, no directional-light shadows. Outlines come from object ids, shadows are blobs, matching art-bible section 2.
