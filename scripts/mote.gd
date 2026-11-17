extends Node2D

var value := 1

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	queue_redraw()
	if player == null or not player.get("alive"):
		return
	var reach := float(player.magnet) if "magnet" in player else 48.0
	var gap := player.global_position - global_position
	var dist := gap.length()
	if dist < 18.0:
		if player.has_method("collect"):
			player.collect(value)
		queue_free()
		return
	if dist < reach:
		global_position += gap.normalized() * min(460.0, 90.0 + (reach - dist) * 5.0) * delta
	else:
		position.y += sin(Time.get_ticks_msec() / 220.0 + value) * 8.0 * delta

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)
	]), Color("ffd27a"))
	draw_circle(Vector2.ZERO, 1.4, Color("fff6d4"))
