extends Node2D

func _draw() -> void:
	draw_circle(Vector2(0, 10), 78, Color(0, 0, 0, 0.18))
	draw_rect(Rect2(-80, -8, 160, 34), Color("5c3a24"))
	draw_rect(Rect2(-88, -18, 176, 14), Color("7a4e30"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-74, -18), Vector2(-18, -18), Vector2(-28, 10), Vector2(-82, 10)
	]), Color("7c2f45"))
	for i in 3:
		var x := -6.0 + float(i) * 24.0
		draw_rect(Rect2(x, -36, 14, 18), Color("d7efe8"))
		draw_rect(Rect2(x + 3, -40, 8, 6), Color("8fb8b0"))
	draw_line(Vector2(64, -16), Vector2(64, -62), Color("3a2a22"), 3.0, true)
	draw_circle(Vector2(64, -68), 8, Color("ffd27a"))
	draw_circle(Vector2(64, -68), 16, Color(1, 0.72, 0.4, 0.16))
