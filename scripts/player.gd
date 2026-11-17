extends CharacterBody2D

signal died
signal attacked(sfx_name: String)
signal hurt_landed
signal collected(amount: int)

var stats: Dictionary = {}
var kind := "lamp"
var accent := Color("ffb15a")
var max_hp := 100.0
var hp := 100.0
var damage := 10.0
var cooldown := 0.5
var speed := 200.0
var attack_range := 100.0
var xp_bonus := 0.0
var magnet := 48.0
var alive := true
var iframes := 0.0
var cd := 0.2
var facing := Vector2.RIGHT
var pulses := 1
var extra_shots := 0
var pierce := 0
var bounces := 2
var rings: Array = []
var glow: Sprite2D
var puppet: PuppetSc
var using_sprite := false
var sprite_top := 34.0
var base_scale := 1.0
var aim_dir := Vector2.RIGHT
var lunge := 0.0
var anim := 0.0
var dash_left := 0.0
var dash_cd := 0.0
var dash_vel := Vector2.ZERO
var space_was := false
var carry_mul := 1.0
var dash_enabled := true
var attack_enabled := true

const Projectile := preload("res://scripts/projectile.gd")
const PuppetSc := preload("res://scripts/puppet.gd")

func _ready() -> void:
	kind = str(stats.get("kind", kind))
	max_hp = float(stats.hp)
	hp = max_hp
	damage = float(stats.damage)
	cooldown = float(stats.cooldown)
	speed = float(stats.speed)
	attack_range = float(stats.range)
	xp_bonus = float(stats.xp_bonus)
	magnet = float(stats.magnet)
	accent = Color.html(str(stats.accent))
	if kind == "needle":
		pierce = 1
	elif kind == "ledger":
		bounces = 3
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 0
	add_to_group("player")
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	_add_portrait()
	_add_glow()

func _physics_process(delta: float) -> void:
	if not alive:
		modulate.a = 0.0
		return
	anim += delta
	iframes = max(iframes - delta, 0.0)
	dash_cd = max(dash_cd - delta, 0.0)
	lunge = max(lunge - delta * 5.5, 0.0)
	modulate.a = 0.45 if iframes > 0.0 and int(Time.get_ticks_msec() / 70.0) % 2 == 0 else 1.0
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1
	if v.length_squared() > 0.0:
		facing = v.normalized()
		velocity = facing * speed * carry_mul
	else:
		velocity = Vector2.ZERO
	_update_aim()
	var space := Input.is_physical_key_pressed(KEY_SPACE)
	if dash_enabled and space and not space_was and dash_cd <= 0.0:
		var dash_dir := facing if facing.length_squared() > 0.0 else aim_dir
		dash_vel = dash_dir * speed * 3.5
		dash_left = 0.13
		dash_cd = 0.85
		iframes = maxf(iframes, 0.12)
		lunge = 1.0
	space_was = space
	if dash_left > 0.0:
		velocity = dash_vel
		dash_left -= delta
	move_and_slide()
	global_position = global_position.clamp(Vector2(28, 28), Vector2(1252, 692))
	cd -= delta
	if attack_enabled and cd <= 0.0:
		_attack()
		cd = cooldown
	_tick_rings(delta)
	_animate_body()
	queue_redraw()

func _update_aim() -> void:
	var mouse := get_global_mouse_position() - global_position
	if mouse.length() > 150.0:
		aim_dir = mouse.normalized()
		return
	var best: Node2D = null
	var best_d := 640.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("dead"):
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist < best_d:
			best_d = dist
			best = node
	if best:
		var to := best.global_position - global_position
		if to.length() > 2.0:
			aim_dir = to.normalized()
			return
	if facing.length_squared() > 0.0:
		aim_dir = facing

func aim() -> Vector2:
	return aim_dir

func _animate_body() -> void:
	var moving := velocity.length() > 30.0
	if puppet:
		puppet.drive(get_physics_process_delta_time(), moving, aim_dir.x, 8.5)
	if glow:
		glow.scale = Vector2(1.2, 1.2) if using_sprite else Vector2(2.4, 2.4)
		glow.position = Vector2(0, -sprite_top * 0.32)
		glow.modulate.a = 0.18 if using_sprite else 0.35

func apply_upgrade(id: String) -> void:
	match id:
		"sharper":
			damage *= 1.2
		"quicker":
			cooldown = max(cooldown * 0.88, 0.11)
		"sturdier":
			max_hp += 26.0
			hp = min(hp + 26.0, max_hp)
		"longer":
			attack_range = min(attack_range * 1.16, 420.0)
		"lighter":
			speed = min(speed * 1.14, 460.0)
		"greedy":
			xp_bonus += 0.2
			magnet += 26.0
		"signature":
			_signature()

func heal_ratio(ratio: float) -> void:
	hp = min(max_hp, hp + max_hp * ratio)

func revive() -> void:
	alive = true
	hp = max_hp
	iframes = 0.6
	collision_layer = 1
	carry_mul = 1.0
	dash_enabled = true
	attack_enabled = true
	modulate.a = 1.0
	visible = true

func hurt(amount: float) -> bool:
	if not alive or iframes > 0.0:
		return false
	hp = max(hp - amount, 0.0)
	iframes = 0.32
	hurt_landed.emit()
	if hp <= 0.0:
		alive = false
		collision_layer = 0
		died.emit()
	return true

func collect(amount: int) -> void:
	if alive:
		collected.emit(amount)

func _signature() -> void:
	match kind:
		"lamp":
			attack_range = min(attack_range * 1.12, 420.0)
			pulses += 1
		"needle":
			extra_shots += 1
			pierce += 1
		"ledger":
			extra_shots += 1
			bounces += 1

func _attack() -> void:
	lunge = 1.0
	if puppet:
		puppet.kick()
	match kind:
		"lamp":
			_lamp_hit(1.0)
			for i in range(1, pulses):
				var mul := 0.72 if i == 1 else 0.5
				get_tree().create_timer(0.11 * float(i), false).timeout.connect(_lamp_hit.bind(mul))
			attacked.emit("whoosh")
		"needle":
			_fan("needle")
			attacked.emit("tick")
		"ledger":
			_fan("coin")
			attacked.emit("coin")

func _fan(proj_kind: String) -> void:
	var dir := aim_dir
	var shots := 1 + extra_shots
	var base := dir.angle()
	var spread := 0.16 if proj_kind == "needle" else 0.22
	for i in shots:
		var ang := base + (float(i) - float(shots - 1) * 0.5) * spread
		_spawn_proj(Vector2.RIGHT.rotated(ang), proj_kind)

func _spawn_proj(dir: Vector2, proj_kind: String) -> void:
	var proj := Projectile.new()
	proj.kind = proj_kind
	proj.damage = damage
	proj.accent = accent
	if proj_kind == "needle":
		proj.vel = dir * 720.0
		proj.pierce = pierce
		proj.life = max(attack_range / 720.0, 0.12)
		proj.bounces = 0
	else:
		proj.vel = dir * 340.0
		proj.pierce = 99
		proj.bounces = bounces
		proj.steer = 0.42
		proj.life = 1.35 + attack_range / 320.0
	get_parent().add_child(proj)
	proj.global_position = global_position + dir * 18.0

func _lamp_hit(mul: float) -> void:
	if not alive:
		return
	var dir := aim_dir
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("dead"):
			continue
		var to: Vector2 = node.global_position - global_position
		var dist: float = to.length()
		if dist > attack_range or dist < 0.001:
			continue
		if dir.dot(to / dist) < 0.15:
			continue
		node.hit(damage * mul, global_position, 240.0)
	rings.append({"r": 24.0, "a": 0.85, "dir": dir})

func _tick_rings(delta: float) -> void:
	var next: Array = []
	for ring in rings:
		ring.r += delta * 260.0
		ring.a -= delta * 2.6
		if ring.a > 0.0:
			next.append(ring)
	rings = next

func _add_portrait() -> void:
	puppet = PuppetSc.new()
	add_child(puppet)
	if not puppet.build("res://assets/heroes/%s.png" % kind, kind, 104.0):
		puppet.queue_free()
		puppet = null
		return
	using_sprite = true
	base_scale = 1.0
	sprite_top = 112.0

func _add_glow() -> void:
	glow = Sprite2D.new()
	var tex = load("res://assets/glow.png")
	if tex is Texture2D:
		glow.texture = tex
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.modulate = Color(accent.r, accent.g, accent.b, 0.42)
	glow.scale = Vector2(2.7, 2.7)
	glow.z_index = -1
	add_child(glow)

func _draw() -> void:
	for ring in rings:
		var dir: Vector2 = ring.get("dir", aim_dir)
		var ang := dir.angle()
		draw_arc(Vector2.ZERO, ring.r, ang - 1.2, ang + 1.2, 22, Color(accent.r, accent.g, accent.b, ring.a), 3.4, true)
	draw_circle(Vector2(0, 8), 16, Color(0, 0, 0, 0.28))
	if not using_sprite:
		var b := Vector2(0, sin(Time.get_ticks_msec() / 180.0) * 1.5)
		match kind:
			"needle":
				_draw_needle(b)
			"ledger":
				_draw_ledger(b)
			_:
				_draw_lamp(b)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var bar_y := -sprite_top
	draw_rect(Rect2(-18, bar_y, 36, 4), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(-18, bar_y, 36.0 * ratio, 4), Color("e24b6a") if ratio < 0.35 else accent)

func _draw_lamp(b: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		b + Vector2(-12, 2), b + Vector2(12, 2), b + Vector2(9, 18), b + Vector2(-9, 18)
	]), Color("24324a"))
	draw_circle(b + Vector2(0, -4), 7, Color("f0c9a0"))
	draw_circle(b + Vector2(0, -12), 8, Color("2c3548"))
	var lp := b + aim() * 16.0
	draw_line(b, lp, Color("6b4423"), 2.0, true)
	draw_circle(lp, 6.5, Color("ffd27a"))
	draw_circle(lp, 3.0, Color("fff6d8"))

func _draw_needle(b: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		b + Vector2(-5, 16), b + Vector2(5, 16), b + Vector2(3, -10), b + Vector2(-3, -10)
	]), Color("1c1e26"))
	draw_circle(b + Vector2(0, -14), 4.5, Color("f3d2c2"))
	var tip := b + aim() * 20.0
	draw_line(b + Vector2(0, -2), tip, Color("f4f1ea"), 1.7, true)
	draw_line(b + Vector2(-2, 4), b + Vector2(4, 9), Color("e24b6a"), 1.5, true)

func _draw_ledger(b: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		b + Vector2(-13, 1), b + Vector2(13, 1), b + Vector2(11, 18), b + Vector2(-11, 18)
	]), Color("3e4a38"))
	draw_circle(b + Vector2(0, -5), 7, Color("f0c9a0"))
	draw_arc(b + Vector2(-3, -5), 3.1, 0, TAU, 12, Color("d7efe8"), 1.2, true)
	draw_arc(b + Vector2(3, -5), 3.1, 0, TAU, 12, Color("d7efe8"), 1.2, true)
	draw_circle(b + aim() * 12.0, 4.2, Color("f0c14a"))
	draw_circle(b + aim() * 12.0, 1.8, Color("fff1c2"))
