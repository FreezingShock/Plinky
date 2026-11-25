class_name IconCache
extends RefCounted
## Icon textures the menus reuse, kept for the life of the game. A menu that loads its icons on every open would read
## the same PNG from disk each time, because a freed node drops its texture. Missing files cache as null.

static var _tex: Dictionary = {}   # path -> Texture2D or null


static func texture(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[path] as Texture2D
