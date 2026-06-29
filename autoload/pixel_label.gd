# Runtime pixel-font etiket uretici — verilen metni 3x5 piksel font ile
# ImageTexture'a cizer ve oyuncuya donuk billboard quad dondurur (PSX nearest).
extends Node

# 3x5 piksel font — buyuk harf, rakam ve birkac sembol.
const GLYPHS := {
	"A": ["010", "101", "111", "101", "101"],
	"B": ["110", "101", "110", "101", "110"],
	"C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"F": ["111", "100", "110", "100", "100"],
	"G": ["011", "100", "101", "101", "011"],
	"H": ["101", "101", "111", "101", "101"],
	"I": ["111", "010", "010", "010", "111"],
	"J": ["001", "001", "001", "101", "010"],
	"K": ["101", "110", "100", "110", "101"],
	"L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "111", "101", "101"],
	"N": ["101", "111", "111", "111", "101"],
	"O": ["010", "101", "101", "101", "010"],
	"P": ["110", "101", "110", "100", "100"],
	"Q": ["010", "101", "101", "110", "011"],
	"R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"],
	"T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "011"],
	"V": ["101", "101", "101", "101", "010"],
	"W": ["101", "101", "111", "111", "101"],
	"X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"],
	"Z": ["111", "001", "010", "100", "111"],
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["110", "001", "010", "100", "111"],
	"3": ["110", "001", "010", "001", "110"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "110", "001", "110"],
	"6": ["011", "100", "110", "101", "010"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["010", "101", "010", "101", "010"],
	"9": ["010", "101", "011", "001", "110"],
	" ": ["000", "000", "000", "000", "000"],
	"-": ["000", "000", "111", "000", "000"],
	".": ["000", "000", "000", "000", "010"],
	"[": ["011", "010", "010", "010", "011"],
	"]": ["110", "010", "010", "010", "110"],
}

const SCALE := 2          # her piksel kac gercek piksel (netlik)
const CHAR_W := 3
const CHAR_H := 5
const SPACING := 1        # harfler arasi piksel
const PAD := 2            # kenar dolgu

var _cache := {}          # text -> ImageTexture


# Metinden bir ImageTexture uretir (cache'li).
func make_texture(text: String, col: Color = Color(0.93, 0.91, 0.8), shadow: Color = Color(0.05, 0.04, 0.03, 0.9)) -> ImageTexture:
	var upper := text.to_upper()
	if _cache.has(upper):
		return _cache[upper]

	var char_count := upper.length()
	var inner_w := char_count * (CHAR_W + SPACING) - SPACING
	var w := (inner_w + PAD * 2) * SCALE
	var h := (CHAR_H + PAD * 2) * SCALE
	w = maxi(w, SCALE)
	h = maxi(h, SCALE)

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var pen_x := PAD
	for i in char_count:
		var ch := upper[i]
		var glyph: Array = GLYPHS.get(ch, GLYPHS[" "])
		for row in CHAR_H:
			var line: String = glyph[row]
			for c in CHAR_W:
				if line[c] == "1":
					_blit_pixel(img, pen_x + c, PAD + row, shadow, col)
		pen_x += CHAR_W + SPACING

	var tex := ImageTexture.create_from_image(img)
	_cache[upper] = tex
	return tex


# Tek mantik pikseli SCALE blogu olarak ciz; once golge (sag-alt) sonra renk.
func _blit_pixel(img: Image, px: int, py: int, shadow: Color, col: Color) -> void:
	var x0 := px * SCALE
	var y0 := py * SCALE
	# Golge (1 piksel sag-alt kaymali)
	for dy in SCALE:
		for dx in SCALE:
			var sx := x0 + dx + SCALE
			var sy := y0 + dy + SCALE
			if sx < img.get_width() and sy < img.get_height():
				img.set_pixel(sx, sy, shadow)
	# Asil renk
	for dy in SCALE:
		for dx in SCALE:
			img.set_pixel(x0 + dx, y0 + dy, col)


# Verilen metni oyuncuya donuk billboard quad olarak dondurur.
# height_m: dunya biriminde etiket yuksekligi (oran korunur).
func make_billboard(text: String, height_m: float = 0.09, col: Color = Color(0.93, 0.91, 0.8)) -> MeshInstance3D:
	var tex := make_texture(text, col)
	var aspect := float(tex.get_width()) / float(maxi(1, tex.get_height()))

	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(height_m * aspect, height_m)
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.render_priority = 10
	mi.material_override = mat
	return mi
