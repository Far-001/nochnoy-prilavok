extends Area2D

var kind := "needle"
var vel := Vector2.RIGHT
var damage := 8.0
var pierce := 0
var bounces := 0
var life := 1.0
var steer := 0.0
var accent := Color.WHITE
var hit := {}

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 6.0 if kind == "coin" else 4.0
	var body := CollisionShape2D.new()
	body.shape = shape
	add_child(body)
	area_entered.connect(_on_area)

func _physics_process(delta: float) -> void:
	if steer > 0.0:
		steer -= delta
		_steer()
	global_position += vel * delta
	life -= delta
	if kind == "coin":
		rotation += delta * 5.0
	else:
		rotation = vel.angle()
	var bounced := false
	if global_position.x < 16.0 or global_position.x > 1264.0:
		vel.x = -vel.x
		global_position.x = clampf(global_position.x, 16.0, 1264.0)
		bounced = true
	if global_position.y < 16.0 or global_position.y > 704.0:
		vel.y = -vel.y
		global_position.y = clampf(global_position.y, 16.0, 704.0)
		bounced = true
	if bounced:
		if kind != "coin" or bounces <= 0:
			queue_free()
			return
		bounces -= 1
	if life <= 0.0:
		queue_free()
		return
	modulate.a = 1.0 if life > 0.18 else clampf(life / 0.18, 0.0, 1.0)
	queue_redraw()

func _steer() -> void:
	var best: Node2D = null
	var best_d := 240.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("dead"):
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist < best_d:
			best_d = dist
			best = node
	if best == null:
		return
	var want := best.global_position - global_position
	if want.length_squared() < 4.0:
		return
	var speed := vel.length()
	vel = vel.lerp(want.normalized() * speed, 0.28).limit_length(speed)

func _on_area(area: Area2D) -> void:
	if not area.is_in_group("enemies") or not area.has_method("hit"):
		return
	var id := area.get_instance_id()
	if hit.has(id):
		return
	hit[id] = true
	var knock := 36.0 if kind == "needle" else 18.0
	area.hit(damage, global_position, knock)
	if kind == "needle":
		if pierce <= 0:
			queue_free()
		else:
			pierce -= 1

func _draw() -> void:
	if kind == "coin":
		var pulse := 1.0 + sin(Time.get_ticks_msec() / 40.0) * 0.12
		draw_circle(Vector2.ZERO, 7.0 * pulse, Color("f0c14a"))
		draw_circle(Vector2.ZERO, 2.8, Color("fff1c2"))
		draw_arc(Vector2.ZERO, 7.0 * pulse, 0, TAU, 14, Color("8a6420"), 1.3, true)
	else:
		draw_line(Vector2(-11, 0), Vector2(8, 0), Color("f4f1ea"), 2.0, true)
		draw_line(Vector2(-7, 2), Vector2(-13, 5), accent, 1.4, true)
