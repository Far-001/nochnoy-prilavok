extends Node2D

var text := ""
var color := Color.WHITE
var font: Font
var age := 0.0
const LIFE := 0.48

func _process(delta: float) -> void:
	age += delta
	position.y -= 34.0 * delta
	modulate.a = clampf(1.0 - age / LIFE, 0.0, 1.0)
	queue_redraw()
	if age >= LIFE:
		queue_free()

func _draw() -> void:
	if font == null:
		return
	var origin := Vector2(-8, 0)
	var ink := Color(0, 0, 0, 0.85)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, origin + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
