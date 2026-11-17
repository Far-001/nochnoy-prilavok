extends Node2D

const Data := preload("res://scripts/data.gd")
const PlayerSc := preload("res://scripts/player.gd")
const EnemySc := preload("res://scripts/enemy.gd")
const MoteSc := preload("res://scripts/mote.gd")
const FloaterSc := preload("res://scripts/floater.gd")
const BackdropSc := preload("res://scripts/backdrop.gd")
const StallSc := preload("res://scripts/stall.gd")
const HudSc := preload("res://scripts/hud.gd")
const PropSc := preload("res://scripts/prop.gd")

enum State { SELECT, PLAY, LEVELUP, PAUSE, DEAD, WON, BRIEF }

const LEDGER := [
	[9, 2, 3, 4, 6],
	[12, 5, 1, 7, 4],
	[11, 8, 3, 6, 2],
]
const BAG_AT := [Vector2(300, 440), Vector2(490, 540), Vector2(790, 540), Vector2(980, 440)]

var state := State.SELECT
var world: Node2D
var backdrop: Node2D
var stall: Node2D
var props: Node2D
var actors: Node2D
var motes: Node2D
var camera: Camera2D
var player: CharacterBody2D
var hud: CanvasLayer
var hero_name := ""
var level := 1
var xp := 0
var xp_need := 5
var wave := 1
var time := 0.0
var wave_left := 18.0
var spawn_cd := 0.4
var kills := 0
var best := 0.0
var shake := 0.0
var blip_cd := 0.0
var floater_count := 0
var boss: EnemySc
var boss_warned := false
var night_i := 0
var night: Dictionary = {}
var night_kills := 0
var goal_count := 0
var run_time := 0.0
var hero_id := ""
var carrying := false
var carried: Node2D
var campaign_done := false
var adds_spawned := false
var enraged := false
var ledger_round := 0
var ledger_target := 0
var smoke := false
var smoke_done := false
var sfx_pools := {}
var sfx_index := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	smoke = "--smoke" in OS.get_cmdline_user_args()
	DisplayServer.window_set_title("Ночной прилавок")
	_build_world()
	_build_audio()
	hud = HudSc.new()
	add_child(hud)
	hud.hero_chosen.connect(_on_hero)
	hud.upgrade_chosen.connect(_on_upgrade)
	hud.restart_requested.connect(_on_restart)
	hud.resume_requested.connect(_on_resume)
	hud.menu_requested.connect(_on_menu)
	hud.brief_continued.connect(_on_brief)
	_load_best()
	hud.set_record("Лучшая ночь целиком: %s" % _clock(best) if best > 0.0 else "До рассвета ещё никто не доходил")
	if smoke:
		call_deferred("_on_hero", "lamp")

func _process(delta: float) -> void:
	if state == State.PLAY and not get_tree().paused:
		_tick(delta)
	elif camera:
		camera.offset = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_SPACE and state == State.PLAY and str(night.get("mode", "")) == "ledger":
		_ledger_space()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode != KEY_ESCAPE:
		return
	if state == State.PLAY:
		state = State.PAUSE
		get_tree().paused = true
		if camera:
			camera.offset = Vector2.ZERO
		hud.show_pause(true)
		get_viewport().set_input_as_handled()
	elif state == State.PAUSE:
		_on_resume()
		get_viewport().set_input_as_handled()

func _build_world() -> void:
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	backdrop = BackdropSc.new()
	world.add_child(backdrop)
	stall = StallSc.new()
	stall.position = Vector2(640, 168)
	stall.z_index = 1
	world.add_child(stall)
	props = Node2D.new()
	props.z_index = 3
	world.add_child(props)
	motes = Node2D.new()
	motes.z_index = 1
	world.add_child(motes)
	actors = Node2D.new()
	actors.z_index = 2
	actors.y_sort_enabled = true
	world.add_child(actors)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.position_smoothing_enabled = false
	world.add_child(camera)
	camera.make_current()

func _build_audio() -> void:
	var music := AudioStreamPlayer.new()
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	music.volume_db = -12.0
	add_child(music)
	var stream = load("res://assets/audio/night.wav")
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.stream = stream
		music.play()
	elif stream != null:
		music.stream = stream
		music.play()
	for sfx_name in ["whoosh", "tick", "coin", "pickup", "level", "hurt", "death", "click"]:
		var base = load("res://assets/audio/%s.wav" % sfx_name)
		if base == null:
			continue
		var players: Array = []
		for _i in 4:
			var p := AudioStreamPlayer.new()
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			p.stream = base.duplicate()
			p.volume_db = -5.0
			add_child(p)
			players.append(p)
		sfx_pools[sfx_name] = players
		sfx_index[sfx_name] = 0

func _tick(delta: float) -> void:
	time += delta
	blip_cd = max(blip_cd - delta, 0.0)
	var mode := str(night.get("mode", "clear"))
	match mode:
		"carry":
			_tick_carry(delta)
		"ledger":
			_tick_ledger()
		"lamps":
			_tick_lamps(delta)
		"boss":
			_tick_boss(delta)
		_:
			_tick_clear(delta)
	if state == State.PLAY and player and str(night.get("place", "")) == "alley":
		player.global_position.x = clampf(player.global_position.x, 340.0, 940.0)
	_decay_shake(delta)
	if state == State.PLAY:
		_refresh_hud()
	if smoke and not smoke_done and time > 1.2 and player:
		smoke_done = true
		print("SMOKE_OK enemies=", get_tree().get_nodes_in_group("enemies").size(), " hp=", player.hp, " level=", level)

func _roll_enemy() -> String:
	if str(night.get("mode", "")) == "carry":
		return "moth"
	if wave >= 2 and randf() < 0.38:
		return "pickpocket"
	return "moth"

func _spawn(kind: String, at: Vector2 = Vector2(-9999, -9999)) -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= 14:
		return
	var enemy: Area2D = EnemySc.new()
	enemy.kind = kind
	enemy.stats = Data.ENEMIES[kind]
	enemy.hp_mul = 1.0 + float(wave - 1) * 0.08
	enemy.speed_mul = 1.0
	enemy.damaged.connect(_on_enemy_damaged)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	if at.x > -9000.0:
		enemy.position = at
	actors.add_child(enemy)
	if at.x <= -9000.0:
		enemy.global_position = _edge_position()
		if kind == "eel":
			enemy.lane_y = enemy.global_position.y

func _edge_position() -> Vector2:
	match randi() % 4:
		0:
			return Vector2(randf_range(0, 1280), -40)
		1:
			return Vector2(randf_range(0, 1280), 760)
		2:
			return Vector2(-40, randf_range(0, 720))
		_:
			return Vector2(1320, randf_range(0, 720))

func _on_hero(id: String) -> void:
	if state != State.SELECT:
		return
	hero_id = id
	hud.hide_hero()
	_sfx("click")
	night_i = 0
	_open_brief()
	if smoke:
		_on_brief()

func _on_attacked(sfx_name: String) -> void:
	_sfx(sfx_name)
	if sfx_name == "whoosh":
		shake = max(shake, 3.2)

func _on_hurt() -> void:
	_sfx("hurt")
	shake = max(shake, 5.0)

func _on_enemy_damaged(amount: float, at: Vector2) -> void:
	_floater(at + Vector2(randf_range(-8, 8), -10), str(int(amount)), Color("ffe6c2"))

func _spawn_boss() -> void:
	boss = EnemySc.new()
	boss.kind = "collector"
	boss.stats = Data.ENEMIES.collector
	boss.hp_mul = 1.0
	boss.speed_mul = 1.0
	boss.damaged.connect(_on_enemy_damaged)
	boss.died.connect(_on_enemy_died.bind(boss))
	actors.add_child(boss)
	boss.global_position = Vector2(640, 250)
	shake = max(shake, 7.0)
	hud.announce("Ночной сборщик")

func _on_enemy_died(xp_value: int, at: Vector2, enemy: Node = null) -> void:
	if state != State.PLAY:
		return
	kills += 1
	night_kills += 1
	if xp_value > 0:
		var mote: Node2D = MoteSc.new()
		mote.value = xp_value
		motes.add_child(mote)
		mote.global_position = at
	var ekind := ""
	if enemy != null:
		ekind = str(enemy.get("kind"))
	if ekind == "collector" or (str(night.get("mode", "")) == "clear" and night_kills >= int(night.need)):
		_complete_night()

func _on_collected(amount: int) -> void:
	if state == State.DEAD or state == State.SELECT or player == null:
		return
	var gain := int(round(float(amount) * (1.0 + player.xp_bonus)))
	xp += max(gain, 1)
	if blip_cd <= 0.0:
		_sfx("pickup")
		blip_cd = 0.06
	if state == State.PLAY:
		_check_level()

func _check_level() -> void:
	if state != State.PLAY or xp < xp_need:
		return
	xp -= xp_need
	level += 1
	xp_need = 5 + level * 3
	if player:
		player.heal_ratio(0.1)
	_open_upgrade()

func _open_upgrade() -> void:
	state = State.LEVELUP
	shake = 0.0
	if camera:
		camera.offset = Vector2.ZERO
	get_tree().paused = true
	_refresh_hud()
	hud.show_upgrade(_roll_upgrades(), level)
	_sfx("level")

func _roll_upgrades() -> Array:
	var pool: Array = Data.UPGRADES.duplicate(true)
	pool.shuffle()
	var picked: Array = []
	for item in pool:
		if picked.size() >= 3:
			break
		if str(item.id) == "signature":
			item.body = _signature_text()
		picked.append(item)
	return picked

func _signature_text() -> String:
	match player.kind:
		"lamp":
			return "Круг света шире и вспыхивает ещё раз."
		"needle":
			return "Ещё один укол веером, и удар проходит навылет."
		"ledger":
			return "Ещё одна монета и лишний отскок от края."
		_:
			return "Фирменный приём сильнее."

func _on_upgrade(id: String) -> void:
	if state != State.LEVELUP or player == null:
		return
	player.apply_upgrade(id)
	_sfx("click")
	hud.hide_upgrade()
	state = State.PLAY
	get_tree().paused = false
	_check_level()

func _on_died() -> void:
	if state != State.PLAY:
		return
	state = State.DEAD
	get_tree().paused = true
	if camera:
		camera.offset = Vector2.ZERO
	hud.show_end(str(night.get("title", "Ночь")), "Это место ещё не пройдено.\n%s здесь\nуровень %d\n\nЕщё раз — с той же прокачкой." % [_clock(time), level])
	_sfx("death")

func _on_restart() -> void:
	get_tree().paused = false
	if campaign_done:
		get_tree().reload_current_scene()
		return
	hud.hide_end()
	_begin_night()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_resume() -> void:
	if state != State.PAUSE:
		return
	state = State.PLAY
	get_tree().paused = false
	hud.show_pause(false)

func _refresh_hud() -> void:
	if player == null or hud == null or night.is_empty():
		return
	var mode := str(night.mode)
	var need := int(night.need)
	var status := str(night.title)
	if mode == "clear":
		status = "отбито %d/%d" % [night_kills, need]
	elif mode == "carry":
		status = "ящики %d/%d" % [goal_count, need]
	elif mode == "ledger":
		status = "счёт %d/%d" % [ledger_round, need]
	elif mode == "lamps":
		status = "фонари %d/%d" % [goal_count, need]
	elif boss != null and is_instance_valid(boss) and not boss.dead:
		status = "сборщик %d" % int(ceil(boss.hp))
	hud.set_play(hero_name, player.hp, player.max_hp, xp, xp_need, level, status, "ночь %d/5" % [night_i + 1], str(night.title))

func _open_brief() -> void:
	var card: Dictionary = Data.NIGHTS[night_i]
	backdrop.place = str(card.place)
	if stall:
		stall.visible = str(card.place) in ["square", "dock", "dawn"]
	state = State.BRIEF
	get_tree().paused = true
	if camera:
		camera.offset = Vector2.ZERO
	hud.show_brief(night_i + 1, Data.NIGHTS.size(), str(card.title), str(card.brief))

func _on_brief() -> void:
	if state != State.BRIEF:
		return
	hud.hide_brief()
	get_tree().paused = false
	_begin_night()

func _begin_night() -> void:
	_clear_field()
	night = Data.NIGHTS[night_i]
	backdrop.place = str(night.place)
	stall.visible = str(night.place) in ["square", "dock", "dawn"]
	time = 0.0
	wave = 1
	wave_left = 14.0
	spawn_cd = 0.5
	night_kills = 0
	goal_count = 0
	carrying = false
	carried = null
	adds_spawned = false
	enraged = false
	boss = null
	ledger_round = 0
	if player == null:
		_make_player()
	else:
		player.revive()
	var mode := str(night.mode)
	player.dash_enabled = mode != "ledger"
	player.attack_enabled = mode != "ledger"
	player.carry_mul = 1.0
	player.global_position = _hero_spot()
	_lay_props(mode)
	if mode == "clear":
		_spawn("moth")
		_spawn("moth")
	elif mode == "boss":
		_spawn_boss()
	state = State.PLAY
	hud.start_hint(str(night.hint))
	hud.announce(str(night.title))
	_refresh_hud()

func _make_player() -> void:
	var hero: Dictionary = Data.HEROES[hero_id].duplicate()
	hero["kind"] = hero_id
	hero_name = str(hero.name)
	player = PlayerSc.new()
	player.stats = hero
	actors.add_child(player)
	player.died.connect(_on_died)
	player.attacked.connect(_on_attacked)
	player.hurt_landed.connect(_on_hurt)
	player.collected.connect(_on_collected)

func _hero_spot() -> Vector2:
	match str(night.get("place", "square")):
		"dock":
			return Vector2(640, 430)
		"books":
			return Vector2(640, 580)
		"alley":
			return Vector2(640, 640)
		"dawn":
			return Vector2(640, 540)
		_:
			return Vector2(640, 490)

func _clear_field() -> void:
	for node in actors.get_children():
		if node == player:
			continue
		actors.remove_child(node)
		node.queue_free()
	for node in motes.get_children():
		motes.remove_child(node)
		node.queue_free()
	for node in props.get_children():
		props.remove_child(node)
		node.queue_free()
	carrying = false
	carried = null

func _lay_props(mode: String) -> void:
	match mode:
		"carry":
			for at in [Vector2(200, 560), Vector2(1080, 500), Vector2(230, 280)]:
				_add_prop("crate", 0, at)
			_spawn("eel", Vector2(280, 280))
			_spawn("eel", Vector2(980, 430))
			_spawn("eel", Vector2(520, 580))
		"ledger":
			_lay_ledger()
		"lamps":
			for at in [Vector2(420, 200), Vector2(860, 200), Vector2(420, 520), Vector2(860, 520)]:
				_add_prop("lamp", 0, at)
			_spawn("still", Vector2(500, 160))
			_spawn("still", Vector2(780, 600))
			_spawn("still", Vector2(640, 380))

func _lay_ledger() -> void:
	for node in props.get_children():
		props.remove_child(node)
		node.queue_free()
	var round: Array = LEDGER[mini(ledger_round, LEDGER.size() - 1)]
	ledger_target = int(round[0])
	var book := _add_prop("book", ledger_target, Vector2(640, 250))
	for i in 4:
		_add_prop("bag", int(round[i + 1]), BAG_AT[i])
	_ledger_caption(book)

func _add_prop(kind: String, amount: int, at: Vector2) -> Node2D:
	var prop := PropSc.new()
	prop.setup(kind, amount, hud.font_bold)
	props.add_child(prop)
	prop.global_position = at
	return prop

func _tick_clear(delta: float) -> void:
	wave_left -= delta
	if wave_left <= 0.0:
		wave += 1
		wave_left = 14.0
		hud.announce("Их больше")
		_spawn(_roll_enemy())
	spawn_cd -= delta
	if spawn_cd <= 0.0:
		spawn_cd = maxf(0.55, 1.3 - float(wave) * 0.08)
		_spawn(_roll_enemy())

func _tick_carry(delta: float) -> void:
	spawn_cd -= delta
	if spawn_cd <= 0.0:
		spawn_cd = 2.6
		_spawn("moth")
	if player == null:
		return
	if carrying and is_instance_valid(carried):
		carried.global_position = player.global_position + Vector2(22, -30)
		if player.global_position.distance_to(Vector2(640, 190)) <= 110.0:
			_deliver_crate()
		return
	for node in props.get_children():
		if str(node.get("prop_kind")) != "crate" or bool(node.get("used")):
			continue
		if player.global_position.distance_to(node.global_position) <= 50.0:
			carrying = true
			carried = node
			node.set("used", true)
			player.carry_mul = 0.62
			player.dash_enabled = false
			_sfx("pickup")
			hud.announce("Неси к прилавку")
			return

func _deliver_crate() -> void:
	carrying = false
	player.carry_mul = 1.0
	player.dash_enabled = true
	if is_instance_valid(carried):
		props.remove_child(carried)
		carried.queue_free()
	carried = null
	goal_count += 1
	_sfx("coin")
	if goal_count >= int(night.need):
		_complete_night()
	else:
		hud.announce("Ящик %d" % goal_count)

func _tick_ledger() -> void:
	_ledger_caption(null)

func _ledger_caption(book: Node) -> void:
	var sum := _bag_sum()
	var target := book
	if target == null:
		for node in props.get_children():
			if str(node.get("prop_kind")) == "book":
				target = node
				break
	if target == null:
		return
	target.set("line", "долг %d\nсейчас %d" % [ledger_target, sum])

func _bag_sum() -> int:
	var sum := 0
	for node in props.get_children():
		if str(node.get("prop_kind")) == "bag" and bool(node.get("selected")):
			sum += int(node.get("amount"))
	return sum

func _ledger_space() -> void:
	if player == null:
		return
	var best: Node = null
	var best_d := 78.0
	for node in props.get_children():
		var dist := player.global_position.distance_to(node.global_position)
		if dist < best_d:
			best_d = dist
			best = node
	if best == null:
		return
	if str(best.get("prop_kind")) == "book":
		_ledger_submit()
	elif str(best.get("prop_kind")) == "bag":
		best.set("selected", not bool(best.get("selected")))
		_sfx("click")
		_ledger_caption(null)

func _ledger_submit() -> void:
	var sum := _bag_sum()
	if sum == ledger_target:
		ledger_round += 1
		_sfx("level")
		if ledger_round >= int(night.need):
			_complete_night()
		else:
			hud.announce("Сошлось")
			_lay_ledger()
	else:
		shake = 6.0
		hud.announce("Мало" if sum < ledger_target else "Много")
		_sfx("tick")

func _tick_lamps(delta: float) -> void:
	spawn_cd -= delta
	if spawn_cd <= 0.0:
		spawn_cd = 11.0
		_spawn("still", Vector2(randf_range(420, 860), randf_range(160, 220)))
	if player == null:
		return
	for node in props.get_children():
		if str(node.get("prop_kind")) != "lamp" or bool(node.get("lit")):
			continue
		if player.global_position.distance_to(node.global_position) <= 48.0:
			node.set("lit", true)
			goal_count += 1
			_sfx("pickup")
			if goal_count >= int(night.need):
				_complete_night()
				return

func _tick_boss(_delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or boss.dead:
		return
	if not adds_spawned and boss.hp <= boss.max_hp * 0.6:
		adds_spawned = true
		boss.boss_phase = maxi(boss.boss_phase, 1)
		hud.announce("Он зовёт мотыльков")
		_spawn("moth")
		_spawn("moth")
	if not enraged and boss.hp <= boss.max_hp * 0.3:
		enraged = true
		boss.boss_phase = 2
		boss.speed *= 1.15
		hud.announce("Сборщик злится")

func _complete_night() -> void:
	if state != State.PLAY:
		return
	run_time += time
	_sfx("level")
	if night_i >= Data.NIGHTS.size() - 1:
		_finish_campaign()
		return
	night_i += 1
	_clear_field()
	if player:
		player.carry_mul = 1.0
		player.dash_enabled = true
		player.attack_enabled = true
		player.heal_ratio(1.0)
	_open_brief()

func _finish_campaign() -> void:
	campaign_done = true
	state = State.WON
	var fresh := best <= 0.0 or run_time < best
	if fresh:
		best = run_time
		_save_best()
	get_tree().paused = true
	if camera:
		camera.offset = Vector2.ZERO
	var record := "Новая лучшая ночь." if fresh else "Лучшая ночь %s." % _clock(best)
	hud.show_end("Прилавок ваш", "Сборщик ушёл с пустыми руками.\nГирлянды снова наши.\nВся ночь %s.\n\n%s" % [_clock(run_time), record], "С начала · R")

func _floater(at: Vector2, text: String, color: Color) -> void:
	if floater_count >= 26 or hud == null or hud.font_regular == null:
		return
	floater_count += 1
	var floater: Node2D = FloaterSc.new()
	floater.text = text
	floater.color = color
	floater.font = hud.font_regular
	floater.tree_exited.connect(_floater_gone)
	actors.add_child(floater)
	floater.global_position = at

func _floater_gone() -> void:
	floater_count = max(floater_count - 1, 0)

func _decay_shake(delta: float) -> void:
	if camera == null:
		return
	if shake > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		shake = max(shake - delta * 22.0, 0.0)
	else:
		camera.offset = Vector2.ZERO

func _sfx(sfx_name: String) -> void:
	if not sfx_pools.has(sfx_name):
		return
	var players: Array = sfx_pools[sfx_name]
	var index := int(sfx_index[sfx_name])
	sfx_index[sfx_name] = (index + 1) % players.size()
	players[index].play()

func _clock(t: float) -> String:
	var seconds := int(t)
	return "%d:%02d" % [int(seconds / 60.0), seconds % 60]

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://best.cfg") == OK:
		best = float(cfg.get_value("run", "clear", 0.0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "clear", best)
	cfg.save("user://best.cfg")
