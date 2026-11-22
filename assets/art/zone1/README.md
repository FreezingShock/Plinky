Meadow backdrop is generated: `python3 tools/art/gen_meadow.py` (Pillow + numpy). Edit the layout list in that file, rerun, commit the PNG and src/world/meadow_placements.json.
Composition rules: clustered props, y-sorted overlap, off-grid positions, noisy island edge, shade pools under trees, path wanders. Light stays upper-left, so lit props are not flipped.
