class_name CrispFont
extends RefCounted
## Makes a vector face (Pixelify Sans) render pixel-crisp: no grey anti-aliasing, full hinting, no subpixel
## positioning. The import settings aren't committed (*.import is ignored), so the defaults (grey AA, light
## hinting) would blur the glyphs; set them on the shared resource in code instead. Use integer font sizes.


static func apply(f: FontFile) -> FontFile:
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NORMAL
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	return f
