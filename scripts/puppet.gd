extends Node2D

const LAYOUTS := {
	"lamp": {
		"limbs": [
			{"id": "bootl", "kind": "split", "rect": [0.16, 0.835, 0.84, 1.0], "side": -1, "amp": 0.52, "phase": 0.0, "attack": 0.0},
			{"id": "bootr", "kind": "split", "rect": [0.16, 0.835, 0.84, 1.0], "side": 1, "amp": 0.52, "phase": PI, "attack": 0.0},
			{"id": "lantern", "kind": "flood", "rect": [0.0, 0.50, 0.19, 0.80], "seed": [0.07, 0.62], "amp": 0.46, "phase": PI, "attack": 1.15},
		],
	},
	"needle": {
		"limbs": [
			{"id": "bootl", "kind": "split", "rect": [0.32, 0.915, 0.78, 1.0], "side": -1, "amp": 0.48, "phase": 0.0, "attack": 0.0},
			{"id": "bootr", "kind": "split", "rect": [0.32, 0.915, 0.78, 1.0], "side": 1, "amp": 0.48, "phase": PI, "attack": 0.0},
			{"id": "needle", "kind": "flood", "rect": [0.0, 0.40, 0.24, 0.68], "seed": [0.05, 0.52], "amp": 0.28, "phase": PI, "attack": 1.25},
		],
	},
	"ledger": {
		"limbs": [
			{"id": "bootl", "kind": "split", "rect": [0.08, 0.83, 0.82, 1.0], "side": -1, "amp": 0.5, "phase": 0.0, "attack": 0.0},
			{"id": "bootr", "kind": "split", "rect": [0.08, 0.83, 0.82, 1.0], "side": 1, "amp": 0.5, "phase": PI, "attack": 0.0},
			{"id": "coins", "kind": "flood", "rect": [0.72, 0.34, 1.0, 0.50], "seed": [0.9, 0.42], "amp": 0.34, "phase": PI, "attack": 0.95},
		],
	},
	"pickpocket": {
		"limbs": [
			{"id": "bootl", "kind": "split", "rect": [0.36, 0.78, 0.88, 1.0], "side": -1, "amp": 0.55, "phase": 0.0, "attack": 0.0},
			{"id": "bootr", "kind": "split", "rect": [0.36, 0.78, 0.88, 1.0], "side": 1, "amp": 0.55, "phase": PI, "attack": 0.0},
			{"id": "lantern", "kind": "flood", "rect": [0.0, 0.58, 0.22, 0.80], "seed": [0.06, 0.68], "amp": 0.4, "phase": PI, "attack": 0.4},
		],
	},
	"shadow": {
		"limbs": [
			{"id": "bootl", "kind": "split", "rect": [0.1, 0.80, 0.72, 1.0], "side": -1, "amp": 0.4, "phase": 0.0, "attack": 0.0},
			{"id": "bootr", "kind": "split", "rect": [0.1, 0.80, 0.72, 1.0], "side": 1, "amp": 0.4, "phase": PI, "attack": 0.0},
			{"id": "clawl", "kind": "flood", "rect": [0.0, 0.44, 0.2, 0.7], "seed": [0.08, 0.56], "amp": 0.55, "phase": PI, "attack": 0.7},
			{"id": "clawr", "kind": "flood", "rect": [0.8, 0.44, 1.0, 0.7], "seed": [0.93, 0.56], "amp": 0.55, "phase": 0.0, "attack": 0.7},
		],
	},
	"moth": {"wings": true},
}

static var _cache: Dictionary = {}

var rig: Node2D
var fit := 1.0
var facing := 1.0
var shown := 1.0
var turn := 1.0
var walk := 0.0
var swing := 0.0
var limb_nodes: Array = []
var alive_pose := true

func build(path: String, layout_name: String, target_h: float) -> bool:
	var layout: Dictionary = LAYOUTS.get(layout_name, {})
	if layout.is_empty():
		return false
	var tex = load(path)
	if not (tex is Texture2D):
		return false
	var packed: Dictionary = _textures(path, layout)
	if packed.is_empty():
		return false
	var source_h := float(packed.h)
	fit = target_h / source_h
	rig = Node2D.new()
	add_child(rig)
	var body_tex = packed.body
	if body_tex is Texture2D:
		var body := Sprite2D.new()
		body.texture = body_tex
		body.centered = true
		body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		body.offset = Vector2(0, -source_h * 0.5)
		body.z_index = 2
		rig.add_child(body)
	for item in packed.limbs:
		var info: Dictionary = item
		var sprite := Sprite2D.new()
		sprite.texture = info.tex
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.offset = info.offset
		sprite.position = info.pos
		sprite.z_index = int(info.z)
		rig.add_child(sprite)
		limb_nodes.append({
			"sprite": sprite,
			"amp": float(info.amp),
			"phase": float(info.phase),
			"attack": float(info.attack),
			"wing": int(info.wing),
		})
	rig.scale = Vector2(fit, fit)
	return true

func kick() -> void:
	swing = 1.0

func drive(delta: float, moving: bool, face_x: float, rate: float) -> void:
	if rig == null or not alive_pose:
		return
	var want := facing
	if face_x < -0.12:
		want = -1.0
	elif face_x > 0.12:
		want = 1.0
	if want != facing and turn >= 1.0:
		facing = want
		turn = 0.0
	if turn < 1.0:
		turn = minf(turn + delta / 0.2, 1.0)
	var squeeze := 1.0
	if turn < 1.0:
		squeeze = absf(turn * 2.0 - 1.0)
		squeeze = maxf(squeeze, 0.1)
		shown = -facing if turn < 0.5 else facing
	else:
		shown = facing
	var stride := 0.12
	if moving:
		walk += delta * rate
		stride = 1.0
	else:
		walk += delta * 1.6
	swing = maxf(swing - delta * 3.4, 0.0)
	var arc := sin(swing * PI)
	rig.scale = Vector2(fit * shown * squeeze, fit)
	rig.position = Vector2(arc * 12.0 * shown, sin(walk * 2.0) * (2.4 if moving else 0.5))
	rotation = 0.0 if turn < 1.0 else clampf(face_x, -1.0, 1.0) * (0.24 if moving else 0.06)
	for item in limb_nodes:
		var info: Dictionary = item
		var sprite: Sprite2D = info.sprite
		var wing := int(info.wing)
		if wing != 0:
			sprite.rotation = wing * sin(walk * 2.0) * float(info.amp)
		else:
			var step := sin(walk * 2.0 + float(info.phase)) * float(info.amp) * stride
			sprite.rotation = step + arc * float(info.attack)

func play_death(k: float) -> void:
	alive_pose = false
	modulate.a = 1.0 - k
	if rig:
		var pop := 1.0 + sin(k * PI) * 0.22
		rig.scale = Vector2(fit, fit) * pop * (1.0 - k * 0.25)
		rig.rotation = k * shown * 0.7

static func _textures(path: String, layout: Dictionary) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var tex = load(path)
	if not (tex is Texture2D):
		return {}
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return {}
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var body := img.duplicate()
	var limbs: Array = []
	if bool(layout.get("wings", false)):
		limbs = _wings(img, body, w, h)
	else:
		for spec_v in layout.get("limbs", []):
			var spec: Dictionary = spec_v
			var mask := _mask(img, spec, w, h)
			if mask.is_empty():
				continue
			var part := Image.create(w, h, false, Image.FORMAT_RGBA8)
			part.fill(Color(0, 0, 0, 0))
			var top := h
			var top_x := 0.0
			var top_n := 0
			for point in mask:
				var px: int = point.x
				var py: int = point.y
				part.set_pixel(px, py, img.get_pixel(px, py))
				body.set_pixel(px, py, Color(0, 0, 0, 0))
				if py < top:
					top = py
					top_x = 0.0
					top_n = 0
				if py <= top + 2:
					top_x += float(px)
					top_n += 1
			if top_n < 1:
				continue
			var pivot := Vector2(top_x / float(top_n), float(top))
			limbs.append(_limb_info(part, pivot, w, h, spec, 0))
	var built := {
		"h": h,
		"body": ImageTexture.create_from_image(body),
		"limbs": limbs,
	}
	_cache[path] = built
	return built

static func _wings(img: Image, body: Image, w: int, h: int) -> Array:
	var mid_l := int(float(w) * 0.4)
	var mid_r := int(float(w) * 0.6)
	var split := int(float(w) * 0.5)
	var clear := Color(0, 0, 0, 0)
	var left := img.duplicate()
	left.fill_rect(Rect2i(split, 0, w - split, h), clear)
	var right := img.duplicate()
	right.fill_rect(Rect2i(0, 0, split, h), clear)
	body.blit_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	body.fill_rect(Rect2i(0, 0, mid_l, h), clear)
	body.fill_rect(Rect2i(mid_r, 0, w - mid_r, h), clear)
	var pivot := Vector2(float(w) * 0.5, float(h) * 0.46)
	var blank := {"amp": 0.7, "phase": 0.0, "attack": 0.0}
	return [
		_limb_info(left, pivot, w, h, blank, -1),
		_limb_info(right, pivot, w, h, blank, 1),
	]

static func _limb_info(part: Image, pivot: Vector2, w: int, h: int, spec: Dictionary, wing: int) -> Dictionary:
	return {
		"tex": ImageTexture.create_from_image(part),
		"offset": Vector2(float(w) * 0.5 - pivot.x, float(h) * 0.5 - pivot.y),
		"pos": Vector2(pivot.x - float(w) * 0.5, pivot.y - float(h)),
		"z": 4 if float(spec.get("attack", 0.0)) > 0.5 else 0,
		"amp": float(spec.get("amp", 0.4)),
		"phase": float(spec.get("phase", 0.0)),
		"attack": float(spec.get("attack", 0.0)),
		"wing": wing,
	}

static func _mask(img: Image, spec: Dictionary, w: int, h: int) -> Array:
	var rect_a: Array = spec.rect
	var rect := Rect2i(
		int(float(rect_a[0]) * float(w)),
		int(float(rect_a[1]) * float(h)),
		maxi(int(float(rect_a[2] - rect_a[0]) * float(w)), 1),
		maxi(int(float(rect_a[3] - rect_a[1]) * float(h)), 1)
	)
	rect = rect.intersection(Rect2i(0, 0, w, h))
	if rect.size.x < 2 or rect.size.y < 2:
		return []
	var points: Array = []
	if str(spec.kind) == "flood":
		var seed_a: Array = spec.seed
		points = _flood(img, Vector2i(int(float(seed_a[0]) * float(w)), int(float(seed_a[1]) * float(h))), rect)
		if points.size() > 24000:
			return []
	else:
		points = _split(img, rect, int(spec.side))
		if points.size() > 42000:
			return []
	if points.size() < 30:
		return []
	return points

static func _split(img: Image, rect: Rect2i, side: int) -> Array:
	var sum_x := 0.0
	var count := 0
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if img.get_pixel(x, y).a > 0.12:
				sum_x += float(x)
				count += 1
	if count < 30:
		return []
	var mid := sum_x / float(count)
	var points: Array = []
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if img.get_pixel(x, y).a <= 0.12:
				continue
			if side < 0 and float(x) <= mid:
				points.append(Vector2i(x, y))
			elif side > 0 and float(x) > mid:
				points.append(Vector2i(x, y))
	return points

static func _flood(img: Image, seed: Vector2i, rect: Rect2i) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	if not rect.has_point(seed) or img.get_pixelv(seed).a < 0.12:
		var found := false
		var best := seed
		var best_d := 1.0e12
		var y := rect.position.y
		while y < rect.position.y + rect.size.y:
			var x := rect.position.x
			while x < rect.position.x + rect.size.x:
				if img.get_pixel(x, y).a > 0.12:
					var dx := float(x - seed.x)
					var dy := float(y - seed.y)
					var dist := dx * dx + dy * dy
					if dist < best_d:
						best_d = dist
						best = Vector2i(x, y)
						found = true
				x += 2
			y += 2
		if not found:
			return []
		seed = best
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array = [seed]
	var points: Array = []
	while stack.size() > 0:
		var current: Vector2i = stack.pop_back()
		if not rect.has_point(current):
			continue
		var index := current.y * w + current.x
		if seen[index] != 0:
			continue
		if img.get_pixelv(current).a < 0.1:
			continue
		seen[index] = 1
		points.append(current)
		if points.size() > 24000:
			return []
		stack.append(Vector2i(current.x + 1, current.y))
		stack.append(Vector2i(current.x - 1, current.y))
		stack.append(Vector2i(current.x, current.y + 1))
		stack.append(Vector2i(current.x, current.y - 1))
	return points
