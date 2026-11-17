extends Node2D

var place := "square"

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	match place:
		"dock":
			_draw_dock()
		"books":
			_draw_books()
		"alley":
			_draw_alley()
		"dawn":
			_draw_dawn()
		_:
			_draw_square()
	draw_rect(Rect2(10, 10, 1260, 700), Color(0, 0, 0, 0.28), false, 14.0)

func _lamps(y: float, count: int, gap: float, origin: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in count:
		var x := origin + float(i) * gap
		var a := 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2.2 + float(i)))
		draw_circle(Vector2(x, y), 10, Color(1, 0.62, 0.28, 0.1 * a))
		draw_circle(Vector2(x, y), 3.2, Color(1, 0.78, 0.45, a))

func _draw_square() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("1c2433"))
	for row in 16:
		for col in 22:
			var shift := sin(float(col) * 2.3 + float(row) * 1.4) * 3.0
			var stone := Color("343c4e") if (col + row) % 2 == 0 else Color("2a3142")
			draw_rect(Rect2(float(col) * 60.0 + shift, float(row) * 48.0, 54, 40), stone)
	for x in [40, 1180]:
		draw_rect(Rect2(x, 120, 70, 460), Color("241910"))
		draw_rect(Rect2(x - 8, 108, 86, 16), Color("5c3a24"))
	_lamps(48.0, 14, 84.0, 70.0)

func _draw_dock() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	draw_rect(Rect2(0, 0, 1280, 720), Color("102430"))
	for i in 16:
		var y := 36.0 + float(i) * 44.0 + sin(t * 0.8 + float(i)) * 8.0
		draw_rect(Rect2(0, y, 1280, 18), Color("16384a") if i % 2 == 0 else Color("123042"))
	draw_circle(Vector2(1040, 84), 28, Color("f3e6cf"))
	draw_circle(Vector2(1040, 84), 70, Color(0.95, 0.9, 0.75, 0.08))
	for i in 11:
		draw_rect(Rect2(160, 150.0 + float(i) * 36.0, 960, 28), Color("6b4a30") if i % 2 == 0 else Color("5a3d28"))
	for x in [190, 640, 1080]:
		draw_rect(Rect2(x, 130, 16, 520), Color("3a2a22"))
	draw_circle(Vector2(640, 188), 78, Color(1, 0.72, 0.35, 0.16))
	_lamps(128.0, 8, 110.0, 220.0)

func _draw_books() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2c2118"))
	for i in 18:
		var tone := Color("4a3424") if i % 2 == 0 else Color("3e2c20")
		draw_rect(Rect2(0, float(i) * 42.0, 1280, 40), tone)
	draw_rect(Rect2(0, 0, 150, 720), Color("241910"))
	draw_rect(Rect2(1130, 0, 150, 720), Color("241910"))
	for i in 6:
		var y := 80.0 + float(i) * 90.0
		draw_rect(Rect2(24, y, 100, 14), Color("6e4a32"))
		draw_rect(Rect2(1156, y, 100, 14), Color("6e4a32"))
		draw_rect(Rect2(36, y - 28, 18, 26), Color("7c2f45"))
		draw_rect(Rect2(70, y - 24, 16, 22), Color("2e4a44"))
	draw_circle(Vector2(640, 150), 90, Color(1, 0.72, 0.35, 0.18))
	draw_circle(Vector2(640, 150), 16, Color("ffd27a"))

func _draw_alley() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	draw_rect(Rect2(0, 0, 1280, 720), Color("171820"))
	_bricks(Rect2(0, 0, 300, 720), Color("3a2a32"), Color("2a1e26"))
	_bricks(Rect2(980, 0, 300, 720), Color("3a2a32"), Color("2a1e26"))
	for row in 14:
		for col in 12:
			var stone := Color("2a2c36") if (col + row) % 2 == 0 else Color("23252e")
			draw_rect(Rect2(310.0 + float(col) * 56.0, float(row) * 54.0, 50, 46), stone)
	for i in 8:
		var x := 360.0 + float(i) * 80.0
		var drop := 70.0 + sin(t * 1.4 + float(i)) * 10.0
		draw_line(Vector2(x, 0), Vector2(x + 8, drop), Color("c9b6a2"), 1.5, true)
	_lamps(36.0, 6, 100.0, 360.0)

func _draw_dawn() -> void:
	draw_rect(Rect2(0, 0, 1280, 280), Color("e7b48a"))
	draw_rect(Rect2(0, 200, 1280, 180), Color("c4866a"))
	draw_rect(Rect2(0, 340, 1280, 380), Color("6d5a52"))
	for row in 8:
		for col in 22:
			var stone := Color("7a675e") if (col + row) % 2 == 0 else Color("65564e")
			draw_rect(Rect2(float(col) * 60.0, 360.0 + float(row) * 48.0, 54, 40), stone)
	for x in [48, 1100]:
		draw_rect(Rect2(x, 250, 130, 90), Color("3a2a28"))
		draw_rect(Rect2(x + 16, 268, 36, 48), Color("1c1618"))
		draw_rect(Rect2(x + 70, 268, 36, 48), Color("1c1618"))
	draw_circle(Vector2(180, 90), 36, Color("fff3d6"))
	draw_circle(Vector2(180, 90), 90, Color(1, 0.9, 0.7, 0.12))

func _bricks(rect: Rect2, a: Color, b: Color) -> void:
	for row in int(rect.size.y / 22.0):
		var off := 18.0 if row % 2 == 0 else 0.0
		for col in int(rect.size.x / 36.0) + 1:
			var tone := a if (col + row) % 2 == 0 else b
			draw_rect(Rect2(rect.position.x + float(col) * 36.0 - off, rect.position.y + float(row) * 22.0, 34, 20), tone)
