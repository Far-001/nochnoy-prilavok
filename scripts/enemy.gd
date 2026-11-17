extends Area2D

signal damaged(amount: float, at: Vector2)
signal died(xp_value: int, at: Vector2)

const HEIGHTS := {"moth": 72.0, "shadow": 100.0, "pickpocket": 96.0, "collector": 150.0, "still": 100.0, "eel": 36.0}
const PuppetSc := preload("res://scripts/puppet.gd")

var kind := "moth"
var stats: Dictionary = {}
var hp_mul := 1.0
var speed_mul := 1.0
var hp := 10.0
var max_hp := 10.0
var speed := 80.0
var touch := 8.0
var xp := 1
var radius := 12.0
var dead := false
var knock := Vector2.ZERO
var flash := 0.0
var bite_cd := 0.0
var phase := 0.0
var anim := 0.0
var death_t := 0.0
var puppet: PuppetSc
var base_scale := 1.0
var visual_h := 28.0
var move_dir := Vector2.RIGHT
var act := "chase"
var act_t := 1.5
var dash_dir := Vector2.RIGHT
var boss_phase := 0
var lane_y := 0.0
var eel_sign := 1.0

func _ready() -> void:
	hp = float(stats.hp) * hp_mul
	max_hp = hp
	speed = float(stats.speed) * speed_mul * randf_range(0.92, 1.08)
	touch = float(stats.damage)
	xp = int(stats.xp)
	radius = float(stats.radius)
	phase = randf() * TAU
	anim = phase
	if kind == "eel":
		lane_y = global_position.y
		eel_sign = -1.0 if randf() < 0.5 else 1.0
	collision_layer = 2
	collision_mask = 1 | 2
	monitoring = true
	monitorable = true
	add_to_group("enemies")
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	_add_sprite()

func hit(amount: float, from: Vector2, knock_strength: float = 90.0) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.1
	var away := global_position - from
	if away.length_squared() < 4.0:
		away = Vector2.from_angle(randf() * TAU)
	var shove := knock_strength
	if kind == "collector":
		shove *= 0.3
	knock = away.normalized() * shove
	damaged.emit(amount, global_position)
	if hp <= 0.0:
		_begin_death()

func _begin_death() -> void:
	dead = true
	death_t = 0.28
	collision_layer = 0
	monitoring = false
	died.emit(xp, global_position)

func _physics_process(delta: float) -> void:
	anim += delta
	if dead:
		_animate_death(delta)
		return
	flash = max(flash - delta, 0.0)
	bite_cd -= delta
	knock = knock.move_toward(Vector2.ZERO, 640.0 * delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var dir := Vector2.ZERO
	if player and player.get("alive"):
		dir = player.global_position - global_position
		if dir.length_squared() > 1.0:
			dir = dir.normalized()
		else:
			dir = Vector2.ZERO
		if kind == "moth":
			dir = dir.rotated(sin(anim * 5.2 + phase) * 0.7)
		elif kind == "pickpocket" and hp < max_hp * 0.4:
			dir = -dir
	if dir.length_squared() > 0.0:
		move_dir = dir
	var pace := 1.0
	if kind == "pickpocket":
		pace = 0.75 + max(0.0, sin(anim * 3.4 + phase)) * 1.15
	elif kind == "shadow":
		pace = 0.55 + 0.45 * (0.5 + 0.5 * sin(anim * 2.1 + phase))
	elif kind == "collector":
		pace = _collector_pace(dir)
		if act == "dash":
			dir = dash_dir
	elif kind == "still":
		var rushing := true
		if player:
			var vel: Vector2 = player.get("velocity")
			rushing = vel.length() < 36.0
		if rushing:
			pace = 1.7
		else:
			pace = 0.0
			dir = Vector2.ZERO
	elif kind == "eel":
		_move_eel(delta, player)
		pace = 0.0
		dir = Vector2.ZERO
	var push := Vector2.ZERO
	for area in get_overlapping_areas():
		if area == self or not area.is_in_group("enemies"):
			continue
		var gap := global_position - area.global_position
		var dist := gap.length()
		if dist < 0.01:
			gap = Vector2.RIGHT
			dist = 1.0
		if dist < radius + 28.0:
			push += gap / dist * (radius + 28.0 - dist) * 8.0
	global_position += (dir * speed * pace + knock + push) * delta
	if bite_cd <= 0.0 and player and player.has_method("hurt"):
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and body.hurt(touch):
				bite_cd = 0.55 if kind == "collector" else 0.7
				if puppet:
					puppet.kick()
				break
	_animate()
	queue_redraw()

func _collector_pace(dir: Vector2) -> float:
	act_t -= get_physics_process_delta_time()
	var wind := 0.28 if boss_phase >= 2 else 0.46
	var dash_for := 0.3 if boss_phase >= 2 else 0.34
	var rest := 1.15 if boss_phase >= 2 else 2.15
	if act == "chase" and act_t <= 0.0:
		act = "windup"
		act_t = wind
		dash_dir = dir if dir.length_squared() > 0.0 else move_dir
	elif act == "windup" and act_t <= 0.0:
		act = "dash"
		act_t = dash_for
		if puppet:
			puppet.kick()
	elif act == "dash" and act_t <= 0.0:
		act = "chase"
		act_t = rest
	if act == "windup":
		return 0.2
	if act == "dash":
		move_dir = dash_dir
		return 6.2
	return 1.0

func _animate() -> void:
	if puppet == null:
		modulate = Color(2.4, 2.1, 1.9) if flash > 0.0 else Color.WHITE
		return
	var rate := 7.2
	if kind == "moth":
		rate = 10.5
	elif kind == "shadow" or kind == "collector" or kind == "still":
		rate = 5.4
	elif kind == "pickpocket":
		rate = 8.4
	puppet.drive(get_physics_process_delta_time(), true, move_dir.x, rate)
	if flash > 0.0:
		puppet.modulate = Color(2.5, 2.2, 2.0)
	elif kind == "collector":
		puppet.modulate = Color(0.78, 0.7, 1.05)
	elif kind == "still":
		puppet.modulate = Color(0.62, 0.74, 1.05)
	else:
		puppet.modulate = Color.WHITE

func _animate_death(delta: float) -> void:
	death_t -= delta
	var k := clampf(1.0 - death_t / 0.28, 0.0, 1.0)
	if puppet:
		puppet.play_death(k)
	if death_t <= 0.0:
		queue_free()

func _move_eel(delta: float, player: Node2D) -> void:
	global_position.x += eel_sign * speed * delta
	if global_position.x < 80.0 or global_position.x > 1200.0:
		eel_sign *= -1.0
		global_position.x = clampf(global_position.x, 80.0, 1200.0)
	var target_y := lane_y
	if player and absf(player.global_position.y - lane_y) < 52.0 and absf(player.global_position.x - global_position.x) < 200.0:
		target_y = player.global_position.y
	global_position.y = move_toward(global_position.y, target_y, 240.0 * delta)
	move_dir = Vector2(eel_sign, 0)

func _add_sprite() -> void:
	var art := kind
	if kind == "collector" or kind == "still":
		art = "shadow"
	elif kind == "eel":
		visual_h = float(HEIGHTS.eel)
		return
	visual_h = float(HEIGHTS.get(kind, 80.0))
	puppet = PuppetSc.new()
	add_child(puppet)
	if not puppet.build("res://assets/enemies/%s.png" % art, art, visual_h):
		puppet.queue_free()
		puppet = null
		return
	base_scale = 1.0

func _draw() -> void:
	draw_circle(Vector2(0, 6), radius * 0.85, Color(0, 0, 0, 0.25))
	if kind == "collector" and act == "windup":
		draw_line(Vector2.ZERO, dash_dir * 110.0, Color(0.78, 0.45, 1.0, 0.9), 4.0, true)
		draw_circle(dash_dir * 110.0, 7.0, Color(0.9, 0.55, 1.0, 0.8))
	if puppet == null:
		match kind:
			"eel":
				_draw_eel()
			"shadow":
				_draw_shadow()
			"pickpocket":
				_draw_pocket()
			_:
				_draw_moth()
	if not dead and (hp < max_hp or kind == "collector"):
		var w := max(radius * 2.4, 28.0)
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		var y := -visual_h - 6.0
		draw_rect(Rect2(-w * 0.5, y, w, 3), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(-w * 0.5, y, w * ratio, 3), Color("e24b6a") if ratio < 0.35 else Color("ffb15a"))

func _draw_eel() -> void:
	var body := Color("d8efe4") if flash > 0.0 else Color("7fad8a")
	for i in 8:
		var along := float(i - 4) * 9.0 * eel_sign
		var wave := sin(anim * 8.0 + float(i)) * 5.0
		draw_circle(Vector2(along, wave), 7.0 - float(i) * 0.35, body)
	draw_circle(Vector2(32.0 * eel_sign, 0), 3.0, Color("ffd27a"))

func _draw_moth() -> void:
	var flap := sin(anim * 14.0 + phase) * 6.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, 0), Vector2(-18, -8 - flap), Vector2(-12, 7), Vector2(-3, 3)
	]), Color("d9d0c1"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 0), Vector2(18, -8 - flap), Vector2(12, 7), Vector2(3, 3)
	]), Color("c9bba6"))
	draw_circle(Vector2.ZERO, 5, Color("6d6458"))

func _draw_shadow() -> void:
	var wob := sin(anim * 3.0 + phase) * 3.0
	draw_circle(Vector2(0, wob), radius, Color("2a2140"))
	draw_circle(Vector2(-5, -2 + wob), 2.2, Color("c9b6ff"))
	draw_circle(Vector2(5, -2 + wob), 2.2, Color("c9b6ff"))

func _draw_pocket() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 10), Vector2(0, -16), Vector2(12, 10)
	]), Color("4a3b32"))
	draw_circle(Vector2(8, 8), 6, Color("8a6a3b"))
