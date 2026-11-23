class_name SeasonLook
extends RefCounted
## The outdoor look for a moment in the year: the four seasons' configured values mixed by weight, so a season
## change is a slow dithered scatter and a tint drift, never a pop. Pure: weights in, plain values out. SkyCycle
## pushes the result to the ground, prop, grade, haze and fog layers; the particles read `weights`.

var weights: Array[float] = [1.0, 0.0, 0.0, 0.0]
var ground_col: Color = Color.WHITE
var ground_col2: Color = Color.WHITE
var ground_amt: float = 0.0
var prop_col: Color = Color.WHITE
var prop_col2: Color = Color.WHITE
var prop_amt: float = 0.0
var ground_snow: float = 0.0
var prop_snow: float = 0.0
var grade: Color = Color.WHITE
var haze_col: Color = Color.WHITE
var haze_mix: float = 0.0
var fog_mult: float = 1.0


static func blend(cfg: CalendarConfig, w: Array[float]) -> SeasonLook:
	var o := SeasonLook.new()
	o.weights = w.duplicate()
	var g: Array = _amt_mix(cfg.ground_col, cfg.ground_amt, w)
	var g2: Array = _amt_mix(cfg.ground_col2, cfg.ground_amt, w)
	o.ground_col = g[0]
	o.ground_amt = g[1]
	o.ground_col2 = g2[0]
	var p: Array = _amt_mix(cfg.prop_col, cfg.prop_amt, w)
	var p2: Array = _amt_mix(cfg.prop_col2, cfg.prop_amt, w)
	o.prop_col = p[0]
	o.prop_amt = p[1]
	o.prop_col2 = p2[0]
	o.ground_snow = _f(cfg.ground_snow, w, 0.0)
	o.prop_snow = _f(cfg.prop_snow, w, 0.0)
	o.grade = _c(cfg.grade_tint, w, Color.WHITE)
	o.haze_col = _c(cfg.haze_col, w, Color.WHITE)
	o.haze_mix = _f(cfg.haze_mix, w, 0.0)
	o.fog_mult = _f(cfg.fog_mult, w, 1.0)
	return o


## Quantised summary, so a caller can skip the shader writes when nothing visible has moved.
func key() -> Vector4:
	return Vector4(snappedf(ground_amt + prop_amt, 0.01), snappedf(ground_snow + prop_snow, 0.01),
			snappedf(weights[0] * 1.0 + weights[1] * 2.0 + weights[2] * 4.0, 0.01), snappedf(fog_mult + haze_mix, 0.01))


## Blend `haze` toward this season's haze colour (brightness kept, so night stays dark).
func tint_haze(haze: Color) -> Color:
	var s := Color(clampf(haze.r * haze_col.r * 1.12, 0.0, 1.0), clampf(haze.g * haze_col.g * 1.12, 0.0, 1.0),
			clampf(haze.b * haze_col.b * 1.12, 0.0, 1.0), 1.0)
	return haze.lerp(s, haze_mix)


static func _f(a: PackedFloat32Array, w: Array[float], dflt: float) -> float:
	var s: float = 0.0
	for i in mini(w.size(), 4):
		s += w[i] * (a[i] if i < a.size() else dflt)
	return s


static func _c(a: PackedColorArray, w: Array[float], dflt: Color) -> Color:
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	for i in mini(w.size(), 4):
		var c: Color = a[i] if i < a.size() else dflt
		r += w[i] * c.r
		g += w[i] * c.g
		b += w[i] * c.b
	return Color(r, g, b, 1.0)


## [colour, amount]: the colour is weighted by each season's own amount, so a season that recolours nothing
## does not wash the target toward black while it fades.
static func _amt_mix(cols: PackedColorArray, amts: PackedFloat32Array, w: Array[float]) -> Array:
	var tot: float = 0.0
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	for i in mini(w.size(), 4):
		var a: float = (amts[i] if i < amts.size() else 0.0) * w[i]
		var c: Color = cols[i] if i < cols.size() else Color.WHITE
		tot += a
		r += a * c.r
		g += a * c.g
		b += a * c.b
	if tot <= 0.0001:
		return [Color.WHITE, 0.0]
	return [Color(r / tot, g / tot, b / tot, 1.0), tot]
