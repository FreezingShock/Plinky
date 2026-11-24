extends RefCounted
## ZoneAssets: the Ember Quarry's prop textures come from its manifest, load once, prefetch on threads, and are released.

func run(t: Object) -> void:
	var manifest: String = str(ZoneAssets.SCENE_MANIFESTS.get("res://world/quarry_scene.tscn", ""))
	t.ok(manifest != "", "the Ember Quarry has a prop manifest")
	var paths: PackedStringArray = ZoneAssets.paths_for_manifest(manifest)
	t.ok(paths.size() > 300, "the manifest lists its sprites, normal maps and lava tiles (%d)" % paths.size())
	var seen: Dictionary = {}
	var missing: int = 0
	for p: String in paths:
		seen[p] = true
		if not ResourceLoader.exists(p):
			missing += 1
	t.eq(seen.size(), paths.size(), "no texture is listed twice")
	t.eq(missing, 0, "every listed prop texture exists")

	ZoneAssets.release()
	ZoneAssets.prefetch(paths)
	var first: Texture2D = ZoneAssets.texture(paths[0])
	t.ok(first != null, "a prefetched prop texture is available")
	t.ok(ZoneAssets.texture(paths[0]) == first, "the second request gets the same cached texture")
	t.eq(ZoneAssets.texture("res://no/such/texture.png"), null, "a missing texture is null, not a crash")
	ZoneAssets.release()
	t.ok(ZoneAssets.texture(paths[0]) != null, "a released texture loads again")
	ZoneAssets.release()
