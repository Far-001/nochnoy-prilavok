extends Node2D

var prop_kind := "crate"
var amount := 0
var selected := false
var lit := false
var used := false
var font: Font
var line := ""

func setup(kind: String, amount_value: int, text_font: Font) -> void:
	prop_kind = kind
	amount = amount_value
	font = text_font
	if kind == "book":
		line = "долг"
	elif amount_value > 0:
		line = str(amount_value)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	match prop_kind:
		"crate":
			draw_rect(Rect2(-16, -12, 32, 24), Color("6b4428"))
			draw_rect(Rect2(-16, -16, 32, 6), Color("8a5a34"))
			draw_line(Vector2(-16, 0), Vector2(16, 0), Color("3a2414"), 2.0)
		"lamp":
			draw_rect(Rect2(-4, -6, 8, 28), Color("3a2a22"))
			var glow := Color("ffb15a") if lit else Color("2a3344")
			draw_circle(Vector2(0, -16), 10, glow)
			if lit:
				draw_circle(Vector2(0, -16), 22, Color(1, 0.7, 0.35, 0.28))
		"bag":
			var cloth := Color("e7c56a") if selected else Color("8a7044")
			draw_colored_polygon(PackedVector2Array([
				Vector2(-16, 10), Vector2(-12, -14), Vector2(12, -14), Vector2(16, 10)
			]), cloth)
			draw_rect(Rect2(-10, -18, 20, 6), Color("5c4030"))
			if selected:
				draw_arc(Vector2(0, -2), 22, 0, TAU, 24, Color("fff1c2"), 2.0, true)
		"book":
			draw_rect(Rect2(-28, -8, 56, 34), Color("6e2e3c"))
			draw_rect(Rect2(-24, -4, 22, 26), Color("f3e6cf"))
			draw_rect(Rect2(2, -4, 22, 26), Color("f7efe2"))
			draw_line(Vector2(0, -8), Vector2(0, 26), Color("6e2e3c"), 2.0)
	if font != null and line != "":
		var origin := Vector2(-40, -48 if prop_kind == "book" else -34)
		draw_multiline_string(font, origin, line, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, 18, Color("fff1c2"))
