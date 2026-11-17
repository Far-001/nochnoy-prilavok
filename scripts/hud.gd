extends CanvasLayer

signal hero_chosen(id: String)
signal upgrade_chosen(id: String)
signal restart_requested
signal resume_requested
signal menu_requested
signal brief_continued

const Data := preload("res://scripts/data.gd")
const ORDER := ["lamp", "needle", "ledger"]

var font_regular: Font
var font_bold: Font
var hero_root: Control
var play_root: Control
var upgrade_root: Control
var death_root: Control
var pause_root: Control
var brief_root: Control
var brief_title: Label
var brief_body: Label
var upgrade_row: HBoxContainer
var upgrade_title: Label
var upgrade_ids: Array = []
var name_label: Label
var xp_label: Label
var wave_label: Label
var time_label: Label
var kills_label: Label
var hp_back: ColorRect
var hp_fill: ColorRect
var xp_back: ColorRect
var xp_fill: ColorRect
var banner: Label
var hint: Label
var death_body: Label
var end_title: Label
var end_button: Button
var record_label: Label
var banner_life := 0.0
var hint_life := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	font_regular = _load_font("res://assets/fonts/DejaVuSans.ttf", 400)
	font_bold = _load_font("res://assets/fonts/DejaVuSans-Bold.ttf", 700)
	_build_hero()
	_build_play()
	_build_upgrade()
	_build_death()
	_build_pause()
	_build_brief()

func _process(delta: float) -> void:
	if banner_life > 0.0:
		banner_life -= delta
		banner.modulate.a = clampf(banner_life, 0.0, 1.0)
		banner.visible = banner_life > 0.0
	if hint_life > 0.0:
		hint_life -= delta
		hint.modulate.a = clampf(hint_life / 1.4, 0.0, 1.0)
		if hint_life <= 0.0:
			hint.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var slot := _number_slot(event.physical_keycode)
	if hero_root.visible and slot >= 0 and slot < ORDER.size():
		_emit_hero(ORDER[slot])
		get_viewport().set_input_as_handled()
	elif upgrade_root.visible and event.physical_keycode == KEY_ESCAPE:
		menu_requested.emit()
		get_viewport().set_input_as_handled()
	elif upgrade_root.visible and slot >= 0 and slot < upgrade_ids.size():
		_emit_upgrade(str(upgrade_ids[slot]))
		get_viewport().set_input_as_handled()
	elif brief_root.visible and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		brief_continued.emit()
		get_viewport().set_input_as_handled()
	elif death_root.visible and event.physical_keycode in [KEY_R, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		restart_requested.emit()
		get_viewport().set_input_as_handled()

func hide_hero() -> void:
	hero_root.visible = false

func start_hint(text: String = "") -> void:
	if text != "":
		hint.text = text
	hint.visible = true
	hint.modulate.a = 1.0
	hint_life = 8.0
	play_root.visible = true

func announce(text: String) -> void:
	banner.text = text
	banner.visible = true
	banner.modulate.a = 1.0
	banner_life = 1.7

func set_play(hero: String, hp: float, max_hp: float, xp: int, need: int, level: int, status: String, clock: String, goal: String) -> void:
	play_root.visible = true
	var max_safe := maxf(max_hp, 1.0)
	name_label.text = "%s    %d / %d" % [hero, int(ceil(hp)), int(max_hp)]
	var hp_ratio := clampf(hp / max_safe, 0.0, 1.0)
	hp_fill.color = Color("e24b6a") if hp_ratio < 0.35 else Color("8fd6a8")
	hp_fill.size = Vector2(max(hp_back.size.x, 280.0) * hp_ratio, 12)
	xp_label.text = "опыт %d / %d    ·    ур. %d" % [xp, need, level]
	xp_fill.size = Vector2(max(xp_back.size.x, 280.0) * clampf(float(xp) / float(maxi(need, 1)), 0.0, 1.0), 8)
	wave_label.text = status
	time_label.text = clock
	kills_label.text = goal

func show_upgrade(options: Array, level: int) -> void:
	for child in upgrade_row.get_children():
		upgrade_row.remove_child(child)
		child.queue_free()
	upgrade_ids.clear()
	var slot := 1
	for item in options:
		var id := str(item.id)
		upgrade_ids.append(id)
		var card := _card(str(item.title), str(item.body), "", Color("ffb15a"), "Взять · %d" % slot, _emit_upgrade.bind(id))
		upgrade_row.add_child(card)
		slot += 1
	upgrade_title.text = "Уровень %d" % level
	hint.visible = false
	hint_life = 0.0
	upgrade_root.visible = true

func hide_upgrade() -> void:
	upgrade_root.visible = false

func show_end(title: String, body: String, again: String = "Ещё раз · R") -> void:
	end_title.text = title
	death_body.text = body
	end_button.text = again
	death_root.visible = true
	upgrade_root.visible = false
	pause_root.visible = false
	hero_root.visible = false

func show_brief(index: int, total: int, title: String, body: String) -> void:
	brief_title.text = "Ночь %d из %d · %s" % [index, total, title]
	brief_body.text = body
	brief_root.visible = true
	hero_root.visible = false
	death_root.visible = false
	upgrade_root.visible = false
	pause_root.visible = false
	play_root.visible = false

func hide_brief() -> void:
	brief_root.visible = false

func hide_end() -> void:
	death_root.visible = false

func show_pause(on: bool) -> void:
	pause_root.visible = on
	if on:
		hint.visible = false
		hint_life = 0.0

func _number_slot(key: int) -> int:
	match key:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		_:
			return -1

func _build_brief() -> void:
	brief_root = _screen(Color(0.04, 0.04, 0.07, 0.62))
	brief_root.visible = false
	var center := _center(brief_root)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.08, 0.14, 0.96), Color("ffb15a")))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	brief_title = _label("", 30, Color("ffd7a1"), true)
	brief_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(brief_title)
	brief_body = _label("", 18, Color("f3e6cf"), false)
	brief_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief_body.custom_minimum_size = Vector2(580, 0)
	column.add_child(brief_body)
	var button := _button("Дальше · Enter", Color("ffb15a"))
	button.pressed.connect(func() -> void: brief_continued.emit())
	column.add_child(button)

func set_record(text: String) -> void:
	if record_label:
		record_label.text = text

func _emit_hero(id: String) -> void:
	hero_chosen.emit(id)

func _emit_upgrade(id: String) -> void:
	upgrade_chosen.emit(id)

func _build_hero() -> void:
	hero_root = _screen(Color(0.04, 0.045, 0.07, 0.5))
	var center := _center(hero_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	var header := PanelContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header_box := _box(Color(0.05, 0.04, 0.08, 0.78), Color(0, 0, 0, 0))
	header_box.set_border_width_all(0)
	header.add_theme_stylebox_override("panel", header_box)
	column.add_child(header)
	var header_col := VBoxContainer.new()
	header_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_col.add_theme_constant_override("separation", 4)
	header.add_child(header_col)
	var title := _label("Ночной прилавок", 46, Color("ffd7a1"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	header_col.add_child(title)
	var sub := _label("Одна ночь, пять мест. Площадь, причал, контора, переулок — и сборщик на рассвете.", 18, Color("f3e6cf"), false)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_col.add_child(sub)
	record_label = _label("", 15, Color("ffd7a1"), false)
	record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_col.add_child(record_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	var slot := 1
	for id in ORDER:
		var hero: Dictionary = Data.HEROES[id]
		var accent := Color.html(str(hero.accent))
		var portrait: Texture2D = null
		var picture = load("res://assets/heroes/%s.png" % id)
		if picture is Texture2D:
			portrait = picture
		var card := _card(str(hero.name), str(hero.blurb), str(hero.stats), accent, "Выбрать · %d" % slot, _emit_hero.bind(id), portrait)
		row.add_child(card)
		slot += 1
	var keys := _label("WASD — ход, пробел — рывок, 1 2 3 — герой. Бьют ближайшего сами", 15, Color("d9cbb4"), false)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(keys)

func _build_play() -> void:
	play_root = Control.new()
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.visible = false
	add_child(play_root)
	play_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	play_root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(top)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 6)
	top.add_child(left)
	name_label = _label("Герой", 20, Color("f3e6cf"), true)
	left.add_child(name_label)
	hp_back = _bar_back(Color(0.08, 0.07, 0.1, 0.72), 12)
	hp_fill = _bar_fill(Color("8fd6a8"))
	hp_back.add_child(hp_fill)
	left.add_child(hp_back)
	xp_label = _label("опыт", 14, Color("d9cbb4"), false)
	left.add_child(xp_label)
	xp_back = _bar_back(Color(0.08, 0.07, 0.1, 0.72), 8)
	xp_fill = _bar_fill(Color("ffb15a"))
	xp_back.add_child(xp_fill)
	left.add_child(xp_back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 2)
	top.add_child(right)
	wave_label = _label("волна 1", 18, Color("ffd7a1"), true)
	time_label = _label("0:00", 16, Color("f3e6cf"), false)
	kills_label = _label("отбито 0", 16, Color("d9cbb4"), false)
	for label in [wave_label, time_label, kills_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(label)
	banner = _label("", 32, Color("ffd7a1"), true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -240
	banner.offset_right = 240
	banner.offset_top = 210
	banner.offset_bottom = 258
	hint = _label("WASD — ход, пробел — рывок. Бьют ближайшего сами. Цель — сборщик до рассвета. Esc — пауза", 16, Color("f3e6cf"), false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	play_root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -360
	hint.offset_right = 360
	hint.offset_top = -58
	hint.offset_bottom = -24

func _build_upgrade() -> void:
	upgrade_root = _screen(Color(0.04, 0.04, 0.07, 0.72))
	upgrade_root.visible = false
	var center := _center(upgrade_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	upgrade_title = _label("Уровень 2", 36, Color("ffd7a1"), true)
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(upgrade_title)
	upgrade_row = HBoxContainer.new()
	upgrade_row.add_theme_constant_override("separation", 16)
	upgrade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(upgrade_row)
	var keys := _label("1  2  3 — выбрать    ·    Esc — в меню", 15, Color("d9cbb4"), false)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(keys)
	var leave := _button("В меню", Color("8d8070"))
	leave.pressed.connect(func() -> void: menu_requested.emit())
	column.add_child(leave)

func _build_death() -> void:
	death_root = _screen(Color(0.03, 0.03, 0.05, 0.78))
	death_root.visible = false
	var center := _center(death_root)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.08, 0.14, 0.96), Color("ffb15a")))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	end_title = _label("Прилавок закрылся", 30, Color("ffd7a1"), true)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(end_title)
	death_body = _label("", 18, Color("f3e6cf"), false)
	death_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(death_body)
	end_button = _button("Ещё раз · R", Color("ffb15a"))
	end_button.pressed.connect(func() -> void: restart_requested.emit())
	column.add_child(end_button)

func _build_pause() -> void:
	pause_root = _screen(Color(0.04, 0.04, 0.07, 0.55))
	pause_root.visible = false
	var center := _center(pause_root)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.08, 0.14, 0.96), Color("ffb15a")))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := _label("Пауза", 32, Color("ffd7a1"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var goal := _label("Пять мест одной ночи. Прокачка остаётся с тобой.", 15, Color("d9cbb4"), false)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(goal)
	var button := _button("Дальше", Color("ffb15a"))
	button.pressed.connect(func() -> void: resume_requested.emit())
	column.add_child(button)
	var leave := _button("В меню", Color("8d8070"))
	leave.pressed.connect(func() -> void: menu_requested.emit())
	column.add_child(leave)

func _screen(dim: Color) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = dim
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root

func _center(parent: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return center

func _card(title: String, body: String, stats: String, accent: Color, button_text: String, callback: Callable, portrait: Texture2D = null) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", _box(Color(0.11, 0.09, 0.16, 0.95), accent))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			callback.call()
	)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.custom_minimum_size = Vector2(0, 6)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stripe)
	if portrait:
		var pic := TextureRect.new()
		pic.texture = portrait
		pic.custom_minimum_size = Vector2(0, 132)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(pic)
	column.add_child(_label(title, 22, Color("f3e6cf"), true))
	if stats != "":
		column.add_child(_label(stats, 14, accent, false))
	var blurb := _label(body, 15, Color("d9cbb4"), false)
	blurb.custom_minimum_size = Vector2(268, 0)
	column.add_child(blurb)
	var button := _button(button_text, accent)
	button.pressed.connect(callback)
	column.add_child(button)
	return panel

func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_stylebox_override("normal", _box(Color("2a2238"), accent.darkened(0.35)))
	button.add_theme_stylebox_override("hover", _box(Color("3a2d4e"), accent))
	button.add_theme_stylebox_override("pressed", _box(accent.darkened(0.45), accent))
	button.add_theme_stylebox_override("focus", _box(Color("3a2d4e"), accent))
	button.add_theme_font_override("font", font_bold)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("f3e6cf"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("fff1d6"))
	return button

func _label(text: String, size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font_bold if bold else font_regular)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _bar_back(color: Color, height: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = Vector2(280, height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _bar_fill(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(280, 12)
	return rect

func _load_font(path: String, weight: int) -> Font:
	var res = load(path)
	if res is Font:
		return res
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["DejaVu Sans", "Noto Sans", "Liberation Sans"])
	sys.font_weight = weight
	return sys
