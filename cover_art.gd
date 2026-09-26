class_name CoverArt
extends Control

## Full-screen cover picture used by the splash (splash.gd) and the title
## screen (game.gd): portrait art on portrait screens, landscape art on
## landscape ones (desktop cabinet mode), each over a blurred, darkened copy
## of itself so no black bars remain on any aspect ratio. The picture keeps
## the bottom BAR_ZONE of the screen free (loading bar / breathing room) and
## stays at the same place in the splash and on the title screen, so the
## hand-over between both is seamless.

const TALL := "res://assets/graphics/cover_tall.png"
const TALL_BG := "res://assets/graphics/cover_tall_bg.png"
const WIDE := "res://splash-screen.png"
const WIDE_BG := "res://assets/graphics/cover_wide_bg.png"
const BAR_ZONE := 0.08

var _back: TextureRect
var _pic: TextureRect
var _wide := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # in-tree: offsets too
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_back = TextureRect.new()
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR     # painted art, not pixel art
	_pic.anchor_right = 1.0
	_pic.anchor_bottom = 1.0 - BAR_ZONE
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pic)
	resized.connect(_pick)
	_pick()

func _pick() -> void:
	var w := 1 if size.x > size.y else 0
	if w == _wide:
		return
	_wide = w
	_pic.texture = load(WIDE if w == 1 else TALL)
	_back.texture = load(WIDE_BG if w == 1 else TALL_BG)
