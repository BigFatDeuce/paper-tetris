class_name UIKit
extends RefCounted
## Shared look: Paper Mario fonts, colours and small factory helpers.

const FONT_S := preload("res://assets/fonts/paper_font_x2.fnt")
const FONT_M := preload("res://assets/fonts/paper_font_x3.fnt")
const FONT_L := preload("res://assets/fonts/paper_font_x4.fnt")
## Outline-free variants for dark text printed on paper.
const INK_S := preload("res://assets/fonts/paper_ink_x2.fnt")
const INK_M := preload("res://assets/fonts/paper_ink_x3.fnt")
const INK_L := preload("res://assets/fonts/paper_ink_x4.fnt")

const INK := Color("3a2414")
const INK_SOFT := Color("6b4a32")
const CREAM := Color("fff6dc")
const PAPER := Color("f8eed2")
const RED := Color("d8402c")
const GOLD := Color("f2b51c")
const BLUE := Color("3a7bd8")
const GREEN := Color("3f9d3c")
const SELECT := Color("c8341f")
const DISABLED := Color("a89a88")

const TEX_PANEL := preload("res://assets/ui/panel_paper.png")
const TEX_PANEL_LIGHT := preload("res://assets/ui/panel_light.png")
const TEX_PANEL_NIGHT := preload("res://assets/ui/panel_night.png")
const TEX_SHADOW := preload("res://assets/ui/panel_shadow.png")
const TEX_GLOVE := preload("res://assets/sprites/ui/glove.png")

const TABS := {
	"red": preload("res://assets/ui/tab_red.png"),
	"gold": preload("res://assets/ui/tab_gold.png"),
	"blue": preload("res://assets/ui/tab_blue.png"),
	"green": preload("res://assets/ui/tab_green.png"),
	"purple": preload("res://assets/ui/tab_purple.png"),
}


static func font(size: int, outline := true) -> FontFile:
	match size:
		2: return FONT_S if outline else INK_S
		4: return FONT_L if outline else INK_L
	return FONT_M if outline else INK_M


static func font_px(size: int) -> int:
	return 18 * clampi(size, 1, 4)


## A Label using the Paper Mario font. size: 2 (small), 3 (normal), 4 (big).
## outline: the dark-outlined HUD style (for text over pictures / colour);
## without it the text is printed like ink on paper.
static func label(text: String, size := 3, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, size, color, outline)
	l.horizontal_alignment = align
	return l


static func style_label(l: Label, size := 3, color := INK, outline := false) -> void:
	l.add_theme_font_override("font", font(size, outline))
	l.add_theme_font_size_override("font_size", font_px(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 2 * size)


static func icon(tex: Texture2D, scale := 3) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.custom_minimum_size = tex.get_size() * scale
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


static func format_time(t: float, hundredths := true) -> String:
	var total := maxf(t, 0.0)
	var m := int(total / 60.0)
	var s := int(total) % 60
	if hundredths:
		var cs := int(fmod(total, 1.0) * 100.0)
		return "%d:%02d.%02d" % [m, s, cs]
	return "%d:%02d" % [m, s]


static func format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var k := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		k += 1
		if k % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
