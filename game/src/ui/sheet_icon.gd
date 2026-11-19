class_name SheetIcon
extends TextureRect
## Small animated icon cut from a horizontal strip (coin / star spin).

var frames := 1
var fps := 12.0
var ping_pong := false
var _atlas: AtlasTexture
var _t := 0.0
var _fw := 0.0


static func make(sheet: Texture2D, frame_count: int, scale_px: int, speed := 12.0, pp := false) -> SheetIcon:
	var s := SheetIcon.new()
	s.frames = frame_count
	s.fps = speed
	s.ping_pong = pp
	s._atlas = AtlasTexture.new()
	s._atlas.atlas = sheet
	s._fw = sheet.get_width() / float(frame_count)
	s._atlas.region = Rect2(0, 0, s._fw, sheet.get_height())
	s.texture = s._atlas
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.custom_minimum_size = Vector2(s._fw, sheet.get_height()) * scale_px
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _process(delta: float) -> void:
	if frames <= 1 or _atlas == null:
		return
	_t += delta * fps
	var n := frames
	var f := int(_t) % (n * 2 - 2 if ping_pong and n > 2 else n)
	if ping_pong and f >= n:
		f = n * 2 - 2 - f
	_atlas.region = Rect2(f * _fw, 0, _fw, _atlas.atlas.get_height())
