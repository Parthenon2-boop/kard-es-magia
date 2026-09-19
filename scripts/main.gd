extends Node2D
## Kard és Mágia — főjelenet: állapotgép (menü, nehézség, hősválasztás, játék, táska, láda, vége),
## billentyűzet/egér, egyenletes lépés-ismétlés, rajzrétegek, képernyőkép-mód (--shot=...).

const LayerScript := preload("res://scripts/layer.gd")
const CFG_PATH := "user://beallitasok.cfg"
const DEFAULT_BINDS := {"up": "ArrowUp", "down": "ArrowDown", "left": "ArrowLeft", "right": "ArrowRight",
	"stair": "Control", "inventory": "i", "menu": "Escape"}
const KEY_DIRS := {"ArrowUp": Vector2i(0, -1), "ArrowDown": Vector2i(0, 1), "ArrowLeft": Vector2i(-1, 0), "ArrowRight": Vector2i(1, 0),
	"w": Vector2i(0, -1), "s": Vector2i(0, 1), "a": Vector2i(-1, 0), "d": Vector2i(1, 0)}
const WORLD_STATES := ["play", "inv", "chest", "over", "win"]

var game := Game.new()
var audio: Audio
var cv := Cv.new()
var state := "menu"
var W := 1280.0
var H := 800.0
var tick := 0.0
var dt := 16.0
var char_sel := 0
var diff_sel := 1
var chest_ui: Variant = null       # {"chest": Dictionary, "sel": int}
var inv_scroll := 0
var hits: Array = []               # [Rect2, Callable]
var binds := DEFAULT_BINDS.duplicate()
var key_dirs_dyn := {}
var bind_edit := ""
var held := {"dx": 0, "dy": 0, "active": false}
var last_step := 0.0
var hold_start := 0.0
var cam := Vector2.ZERO
var layers := {}
var _bg_size := Vector2.ZERO

# előre elkészített fény-textúrák (a canvas-os sugaras színátmenetek helyett)
var tex_torch: Texture2D
var tex_glow: Texture2D
var tex_orb: Texture2D
var tex_burst: Texture2D
var tex_dark: Texture2D
var tex_menu_torch: Texture2D
var tex_vignette: GradientTexture2D
var tex_grain: Texture2D
var title_mat: ShaderMaterial
var clip_mat: ShaderMaterial

# képernyőkép-mód
var shot_path := ""
var shot_scene := ""
var shot_cls := "Lovag"
var shot_frames := 45
var _frame := 0
var _shot_at := 0.0


func _ready() -> void:
	randomize()
	_parse_args()
	_setup_fonts()
	_make_textures()
	_make_layers()
	_load_cfg()
	_build_dir_map()
	audio = Audio.new()
	add_child(audio)
	audio.setup(shot_path == "")
	audio.set_muted(_cfg_muted)
	game.sfx = func(n: String) -> void: audio.play(n)
	get_window().min_size = Vector2i(900, 600)
	if shot_path != "":
		_setup_shot()


# ══════════ BETŰK ══════════
func _setup_fonts() -> void:
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji"])
	var sym := SystemFont.new()
	sym.font_names = PackedStringArray(["Segoe UI Symbol", "Apple Symbols", "DejaVu Sans", "Arial Unicode MS"])
	var sym2 := SystemFont.new()
	sym2.font_names = PackedStringArray(["Segoe UI", "Arial", "Helvetica", "sans-serif"])
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "DejaVu Serif", "serif"])
	serif.font_weight = 700
	serif.fallbacks = [sym, emoji, sym2]
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Courier New", "Menlo", "DejaVu Sans Mono", "monospace"])
	mono.font_weight = 700
	mono.fallbacks = [sym, emoji, sym2]
	Cv.font_serif = serif
	Cv.font_mono = mono


# ══════════ TEXTÚRÁK ══════════
static func radial_tex(offs: Array, cols: Array, size := 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


func _make_textures() -> void:
	# fáklya: lágy, kerek, additív fény (3.4 mező sugarú)
	tex_torch = radial_tex([0.0588, 0.4824, 1.0], [Cv.rgba(230, 130, 30, 0.32), Cv.rgba(170, 80, 15, 0.12), Cv.rgba(170, 80, 15, 0)])
	tex_glow = radial_tex([0.0, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	Sprites.glow_tex = tex_glow
	tex_orb = radial_tex([0.0, 0.3, 1.0], [Cv.rgba(200, 230, 255, 0.95), Cv.rgba(90, 160, 255, 0.75), Cv.rgba(30, 70, 200, 0)])
	tex_burst = radial_tex([0.0, 1.0], [Cv.rgba(180, 215, 255, 0.7), Cv.rgba(40, 90, 255, 0)])
	# a hős körüli sötétítés: 3 mezőn belül átlátszó, FOV_R+2 mezőnél 0.35
	tex_dark = radial_tex([0.3, 0.79, 1.0], [Cv.rgba(4, 3, 2, 0), Cv.rgba(4, 3, 2, 0.12), Cv.rgba(4, 3, 2, 0.35)], 512)
	tex_menu_torch = radial_tex([0.015, 0.409, 1.0], [Cv.rgba(255, 160, 50, 0.38 * 1.1), Cv.rgba(200, 90, 15, 0.16 * 1.1), Cv.rgba(120, 40, 0, 0)], 512)
	tex_vignette = radial_tex([0.2, 0.68, 1.0], [Color(0, 0, 0, 0), Color(0, 0, 0, 0.38), Color(0, 0, 0, 0.9)], 512)
	# filmszemcse
	var img := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	for y in 160:
		for x in 160:
			var v := randf()
			img.set_pixel(x, y, Color(v, v, v, 14.0 / 255.0))
	tex_grain = ImageTexture.create_from_image(img)


func _update_vignette() -> void:
	var r0 := minf(W, H) * 0.15
	var r1 := maxf(W, H) * 0.8
	var t0 := r0 / r1
	tex_vignette.gradient.offsets = PackedFloat32Array([t0, t0 + 0.6 * (1 - t0), 1.0])


# ══════════ RÉTEGEK ══════════
func _make_layers() -> void:
	var clip_shader := Shader.new()
	clip_shader.code = """
shader_type canvas_item;
// a sárkány csak a boltív belsejében látszik (canvas clip() megfelelője)
uniform vec2 arch_c;
uniform float arch_r;
uniform float floor_y;
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	bool inside = lp.x >= arch_c.x - arch_r && lp.x <= arch_c.x + arch_r && lp.y <= floor_y
		&& (lp.y >= arch_c.y || distance(lp, arch_c) <= arch_r);
	if (!inside) { discard; }
}
"""
	clip_mat = ShaderMaterial.new()
	clip_mat.shader = clip_shader
	var title_shader := Shader.new()
	title_shader.code = """
shader_type canvas_item;
// a cím arany színátmenete (függőleges)
uniform float top;
uniform float bot;
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float t = clamp((lp.y - top) / max(1.0, bot - top), 0.0, 1.0);
	vec3 c0 = vec3(1.0, 0.918, 0.659);
	vec3 c1 = vec3(0.914, 0.725, 0.267);
	vec3 c2 = vec3(0.718, 0.502, 0.114);
	vec3 c3 = vec3(0.957, 0.820, 0.471);
	vec3 col = t < 0.42 ? mix(c0, c1, t / 0.42) : (t < 0.62 ? mix(c1, c2, (t - 0.42) / 0.2) : mix(c2, c3, (t - 0.62) / 0.38));
	COLOR = vec4(col, COLOR.a);
}
"""
	title_mat = ShaderMaterial.new()
	title_mat.shader = title_shader
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var defs := [
		["menu_bg", null], ["menu_clip", clip_mat], ["menu_front", null], ["menu_title", title_mat],
		["world", null], ["glow", add_mat], ["mid", null], ["fx_add", add_mat], ["fx", null],
		["hud", null], ["ui", null],
	]
	for d in defs:
		var n: Node2D = LayerScript.new()
		n.name = d[0]
		if d[1] != null:
			n.material = d[1]
		add_child(n)
		layers[d[0]] = n
	layers["menu_bg"].fn = func(rid: RID) -> void: _lay(rid, "menu_bg")
	layers["menu_clip"].fn = func(rid: RID) -> void: _lay(rid, "menu_clip")
	layers["menu_front"].fn = func(rid: RID) -> void: _lay(rid, "menu_front")
	layers["menu_title"].fn = func(rid: RID) -> void: _lay(rid, "menu_title")
	layers["world"].fn = func(rid: RID) -> void: _lay(rid, "world")
	layers["glow"].fn = func(rid: RID) -> void: _lay(rid, "glow")
	layers["mid"].fn = func(rid: RID) -> void: _lay(rid, "mid")
	layers["fx_add"].fn = func(rid: RID) -> void: _lay(rid, "fx_add")
	layers["fx"].fn = func(rid: RID) -> void: _lay(rid, "fx")
	layers["hud"].fn = func(rid: RID) -> void: _lay(rid, "hud")
	layers["ui"].fn = func(rid: RID) -> void: _lay(rid, "ui")


func in_world() -> bool:
	return state in WORLD_STATES and game.world != null


var prof := {}


func _lay(rid: RID, which: String) -> void:
	var _t0 := Time.get_ticks_usec()
	_lay2(rid, which)
	cv.flush()
	if shot_path != "":   # mérés csak képernyőkép-módban
		prof[which] = prof.get(which, 0) + Time.get_ticks_usec() - _t0


func _lay2(rid: RID, which: String) -> void:
	cv.begin(rid)
	var menu := state == "menu"
	match which:
		"menu_bg": Screens.menu_bg(self, cv)
		"menu_clip": if menu: Screens.menu_clip(self, cv)
		"menu_front": if menu: Screens.menu_front(self, cv)
		"menu_title": if menu: Screens.menu_title(self, cv)
		"world": if in_world(): Render.world_base(self, cv)
		"glow": if in_world(): Render.world_glow(self, cv)
		"mid": if in_world(): Render.world_mid(self, cv)
		"fx_add": if in_world(): Render.fx_add(self, cv)
		"fx": if in_world(): Render.fx(self, cv)
		"hud": if in_world(): Render.hud(self, cv)
		"ui":
			match state:
				"menu": Screens.menu_top(self, cv)
				"help": Screens.help(self, cv)
				"diff": Screens.diff_sel(self, cv)
				"char": Screens.char_sel(self, cv)
				"inv": Screens.inventory(self, cv)
				"chest": Screens.chest(self, cv)
				"over": Screens.game_over(self, cv, false)
				"win": Screens.game_over(self, cv, true)
			Screens.mute_button(self, cv)


func add_hit(x: float, y: float, w: float, h: float, fn: Callable) -> void:
	hits.append([Rect2(x, y, w, h), fn])


# ══════════ BEÁLLÍTÁSOK (billentyűk, némítás) ══════════
func _load_cfg() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) == OK:
		for k in DEFAULT_BINDS:
			binds[k] = str(cf.get_value("binds", k, DEFAULT_BINDS[k]))
		_cfg_muted = bool(cf.get_value("hang", "nemitva", false))


var _cfg_muted := false


func save_cfg() -> void:
	var cf := ConfigFile.new()
	for k in binds:
		cf.set_value("binds", k, binds[k])
	cf.set_value("hang", "nemitva", audio.muted if audio else false)
	cf.save(CFG_PATH)


func _build_dir_map() -> void:
	key_dirs_dyn = {}
	key_dirs_dyn[binds["up"]] = Vector2i(0, -1)
	key_dirs_dyn[binds["down"]] = Vector2i(0, 1)
	key_dirs_dyn[binds["left"]] = Vector2i(-1, 0)
	key_dirs_dyn[binds["right"]] = Vector2i(1, 0)
	# a WASD másodlagos marad, hacsak át nem lett kötve
	for k in ["w", "s", "a", "d"]:
		if not key_dirs_dyn.has(k):
			key_dirs_dyn[k] = KEY_DIRS[k]


func reset_binds() -> void:
	binds = DEFAULT_BINDS.duplicate()
	save_cfg()
	_build_dir_map()
	bind_edit = ""


static func key_label(k: String) -> String:
	match k:
		"": return "?"
		"Control": return "Ctrl"
		"Escape": return "Esc"
		"ArrowUp": return "↑"
		"ArrowDown": return "↓"
		"ArrowLeft": return "←"
		"ArrowRight": return "→"
		" ": return "Szóköz"
	return k.to_upper() if k.length() == 1 else k


static func key_name(ev: InputEventKey) -> String:
	match ev.keycode:
		KEY_UP: return "ArrowUp"
		KEY_DOWN: return "ArrowDown"
		KEY_LEFT: return "ArrowLeft"
		KEY_RIGHT: return "ArrowRight"
		KEY_CTRL: return "Control"
		KEY_SHIFT: return "Shift"
		KEY_ALT: return "Alt"
		KEY_ESCAPE: return "Escape"
		KEY_ENTER, KEY_KP_ENTER: return "Enter"
		KEY_SPACE: return " "
		KEY_TAB: return "Tab"
		KEY_CAPSLOCK: return "CapsLock"
		KEY_BACKSPACE: return "Backspace"
	if ev.keycode >= KEY_F1 and ev.keycode <= KEY_F12:
		return "F%d" % (ev.keycode - KEY_F1 + 1)
	if ev.keycode >= KEY_A and ev.keycode <= KEY_Z:
		return String.chr(ev.keycode).to_lower()
	if ev.keycode >= KEY_0 and ev.keycode <= KEY_9:
		return String.chr(ev.keycode)
	if ev.unicode > 32:
		return String.chr(ev.unicode)
	return OS.get_keycode_string(ev.keycode)


func dir_of(k: String) -> Variant:
	if key_dirs_dyn.has(k):
		return key_dirs_dyn[k]
	if KEY_DIRS.has(k):
		return KEY_DIRS[k]
	return null


# ══════════ ÁLLAPOTOK ══════════
func set_state(s: String) -> void:
	state = s
	if s != "play":
		held["active"] = false


func start_game(cls: String, diff: String) -> void:
	game.start(cls, diff)
	inv_scroll = 0
	chest_ui = null
	set_state("play")


func next_level() -> void:
	if game.next_level():
		set_state("win")


func pick_chest_item() -> void:
	if chest_ui == null:
		return
	game.take_chest_item(chest_ui["chest"], chest_ui["sel"])
	chest_ui = null
	set_state("play")


func use_inv(i: int) -> void:
	var items := game.player.inventory
	if i >= 0 and i < items.size():
		game.use_item(items[i])
		inv_scroll = clampi(inv_scroll, 0, maxi(0, game.player.inventory.size() - 1))


func go_diff() -> void:
	diff_sel = 1
	set_state("diff")


func go_char() -> void:
	char_sel = 0
	set_state("char")


func close_help() -> void:
	bind_edit = ""
	set_state("menu")


func toggle_mute() -> void:
	audio.set_muted(not audio.muted)
	save_cfg()


func _after_move() -> void:
	if game.pending_chest != null:
		chest_ui = {"chest": game.pending_chest, "sel": 0}
		game.pending_chest = null
		set_state("chest")
	if game.player and not game.player.alive:
		set_state("over")
		held["active"] = false


# ══════════ EGYENLETES MOZGÁS: tartott irány ismétlése ══════════
func press_dir(dx: int, dy: int) -> void:
	held = {"dx": dx, "dy": dy, "active": true}
	hold_start = Time.get_ticks_usec() / 1000.0
	if state == "play" and game.world:
		game.do_move(dx, dy)   # azonnali első lépés
		last_step = Time.get_ticks_usec() / 1000.0
		_after_move()
	elif state == "chest" and chest_ui != null:
		chest_ui["sel"] = (chest_ui["sel"] + 1) % 2


func release_dir(d: Vector2i) -> void:
	if held["dx"] == d.x and held["dy"] == d.y:
		held = {"dx": 0, "dy": 0, "active": false}


func step_repeat(now: float) -> void:
	if not held["active"] or state != "play" or game.world == null:
		return
	if now - hold_start < Data.FIRST_DELAY:
		return
	if now - last_step >= Data.STEP_MS:
		game.do_move(held["dx"], held["dy"])
		# egyenletes ütem: a következő lépés a terv szerinti időpontból számol, nem a (késve jött) képkockából
		last_step = (last_step + Data.STEP_MS) if now - last_step < Data.STEP_MS * 2 else now
		_after_move()


# ══════════ BEMENET ══════════
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		held["active"] = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_click(mb.position)
		elif state == "inv" and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			inv_scroll = maxi(0, inv_scroll - 1)
		elif state == "inv" and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inv_scroll += 1
		return
	if not (event is InputEventKey):
		return
	var ev := event as InputEventKey
	var k := key_name(ev)
	if not ev.pressed:
		var d: Variant = dir_of(k)
		if d != null:
			release_dir(d)
		return
	if ev.echo:
		return   # az OS billentyűismétlését figyelmen kívül hagyjuk: az ütemet mi adjuk
	# billentyű-átkötés folyamatban
	if bind_edit != "":
		if k in ["Tab", "CapsLock"] or k.begins_with("F") and k.length() > 1 and k.substr(1).is_valid_int():
			return
		binds[bind_edit] = k
		save_cfg()
		_build_dir_map()
		bind_edit = ""
		get_viewport().set_input_as_handled()
		return
	if k == "F11":
		var win := get_window()
		win.mode = Window.MODE_WINDOWED if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_FULLSCREEN
		return
	if k == "m" and state != "inv" and not (state == "play" and dir_of("m") != null):
		toggle_mute()
		return
	match state:
		"menu":
			if k == "Enter":
				diff_sel = 1
				set_state("diff")
		"help":
			if k == "Escape" or k == "Enter":
				bind_edit = ""
				set_state("menu")
		"diff":
			if k in ["ArrowLeft", "a", "ArrowUp"]: diff_sel = (diff_sel + 2) % 3
			if k in ["ArrowRight", "d", "ArrowDown"]: diff_sel = (diff_sel + 1) % 3
			if k == "Enter":
				char_sel = 0
				set_state("char")
			if k == "Escape": set_state("menu")
		"char":
			var n := Data.CLASS_ORDER.size()
			if k in ["ArrowLeft", "a"]: char_sel = (char_sel + n - 1) % n
			if k in ["ArrowRight", "d"]: char_sel = (char_sel + 1) % n
			if k == "Enter": start_game(Data.CLASS_ORDER[char_sel], Data.DIFF_ORDER[diff_sel])
			if k == "Escape": set_state("diff")
		"play":
			var d: Variant = dir_of(k)
			if d != null:
				press_dir(d.x, d.y)
			if k == binds["inventory"] or k == "i":
				set_state("inv")
			if k == binds["stair"] or k == "." or k == ">":
				if game.on_stair():
					next_level()
			if k == binds["menu"] or k == "Escape":
				set_state("menu")
			if game.player and not game.player.alive:
				set_state("over")
		"inv":
			if k == binds["menu"] or k == binds["inventory"] or k == "Escape" or k == "i":
				set_state("play")
			elif k == "ArrowUp":
				inv_scroll = maxi(0, inv_scroll - 1)
			elif k == "ArrowDown":
				inv_scroll += 1
			elif k.length() == 1:
				var code := k.to_upper().unicode_at(0) - 65
				if code >= 0 and code < 26:
					use_inv(code)
		"chest":
			if chest_ui == null:
				return
			if k in ["ArrowLeft", "a", "ArrowUp"]: chest_ui["sel"] = 0
			if k in ["ArrowRight", "d", "ArrowDown"]: chest_ui["sel"] = 1
			if k == "Enter": pick_chest_item()
			elif k == "Escape":
				chest_ui = null
				set_state("play")
		"over", "win":
			if k == "Enter" or k == "Escape":
				set_state("menu")


func _click(p: Vector2) -> void:
	# a hang gomb mindig legfelül van
	if Screens.mute_rect(self).has_point(p):
		toggle_mute()
		return
	for h in hits:
		if (h[0] as Rect2).has_point(p):
			(h[1] as Callable).call()
			return


# ══════════ KÉPKOCKA ══════════
var _pt := {"frame": 0.0, "proc": 0.0, "last": 0.0}


func _process(delta: float) -> void:
	var _p0 := Time.get_ticks_usec()
	if _pt["last"] > 0: _pt["frame"] += _p0 - _pt["last"]
	_pt["last"] = _p0
	_process2(delta)
	_pt["proc"] += Time.get_ticks_usec() - _p0


func _process2(delta: float) -> void:
	var sz := get_viewport_rect().size
	if sz.x != W or sz.y != H or _bg_size == Vector2.ZERO:
		W = sz.x
		H = sz.y
		_update_vignette()
	dt = minf(50.0, delta * 1000.0)
	tick += dt / 16.67
	var now := Time.get_ticks_usec() / 1000.0
	step_repeat(now)
	if in_world():
		_update_motion()
	hits.clear()
	# a menü statikus háttere csak méretváltáskor rajzolódik újra
	var menu := state == "menu"
	layers["menu_bg"].visible = menu
	if menu and _bg_size != Vector2(W, H):
		_bg_size = Vector2(W, H)
		layers["menu_bg"].queue_redraw()
	for k in layers:
		if k != "menu_bg":
			layers[k].queue_redraw()
	if shot_path != "":
		_shot_tick()


## egyenletes sebességű siklás (nem lassul le minden lépés végén, így tartott gombnál folyamatos)
func _update_motion() -> void:
	var p := game.player
	var step_d := Data.MOVE_SPD * dt / 1000.0
	p.rx = _glide(p.rx, p.x, step_d)
	p.ry = _glide(p.ry, p.y, step_d)
	for m in game.world.mons:
		if m.alive:
			m.rx = _glide(m.rx, m.x, step_d)
			m.ry = _glide(m.ry, m.y, step_d)
	if p.lunge > 0:
		p.lunge = maxf(0.0, p.lunge - dt * 0.008)
	var t := float(Data.TILE)
	var gh := H - Data.HUD_H
	var cam_w := ceilf(W / t) + 2
	var cam_h := ceilf(gh / t) + 2
	cam.x = clampf(p.rx - cam_w / 2, 0, maxf(0, Data.MAP_W - cam_w))
	cam.y = clampf(p.ry - cam_h / 2, 0, maxf(0, Data.MAP_H - cam_h))


static func _glide(cur: float, to: float, d: float) -> float:
	var r := to - cur
	if absf(r) <= d or absf(r) > 2.5:
		return to
	return cur + signf(r) * d


func now_ms() -> float:
	return Time.get_ticks_usec() / 1000.0


# ══════════ KÉPERNYŐKÉP-MÓD (--shot=utvonal.png --scene=menu|diff|char|help|play|orb|inv|chest|over) ══════════
func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--scene="): shot_scene = a.substr(8)
		elif a.begins_with("--cls="): shot_cls = a.substr(6)
		elif a.begins_with("--frames="): shot_frames = int(a.substr(9))


func _setup_shot() -> void:
	audio.music_started = true
	# a képernyőkép mindig 1280×800-as elrendezéssel készül (kisebb kijelzőn is)
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = Vector2i(1280, 800)
	match shot_scene:
		"diff": set_state("diff")
		"char":
			diff_sel = 1
			char_sel = Data.CLASS_ORDER.find(shot_cls) if Data.CLASS_ORDER.has(shot_cls) else 0
			set_state("char")
		"help": set_state("help")
		"play", "orb", "inv", "chest", "over", "walk":
			start_game(shot_cls, "normal")
			if shot_scene != "orb" and shot_scene != "walk":
				_shot_populate()
			if shot_scene == "inv":
				_shot_items()
				set_state("inv")
			elif shot_scene == "chest":
				var ch := {"x": game.player.x, "y": game.player.y, "opened": false,
					"items": [Item.make(Item.find_base("Holdfénypenge"), "legendary", 3), Item.make(Item.find_base("Rúnapajzs"), "epic", 3)]}
				chest_ui = {"chest": ch, "sel": 0}
				set_state("chest")
			elif shot_scene == "over":
				set_state("over")


## néhány szörny a kezdőszoba közelébe, hogy a képen látszódjanak a figurák
func _shot_populate() -> void:
	var w := game.world
	var p := game.player
	var keys := ["goblin", "skeleton", "orc", "spider", "witch", "golem", "demon", "vampire"]
	var placed := 0
	var dirs := [Vector2i(4, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(3, 2), Vector2i(-3, -2), Vector2i(2, -3), Vector2i(-2, 3)]
	for d in dirs:
		var x: int = p.x + d.x
		var y: int = p.y + d.y
		if not w.blocked(x, y) and w.mon_at(x, y) == null:
			var m := Mon.make(keys[placed % keys.size()], x, y, "normal")
			w.mons.append(m)
			placed += 1
	# egy ládát is teszünk a közelbe
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if not w.blocked(p.x + d.x, p.y + d.y) and w.mon_at(p.x + d.x, p.y + d.y) == null:
			w.chests.append({"x": p.x + d.x, "y": p.y + d.y, "opened": false, "items": [Item.random(1), Item.random(1)]})
			break
	# látható boss-fény: a főellenség is közel
	for d in [Vector2i(-2, 2), Vector2i(2, 2), Vector2i(-2, -2)]:
		if not w.blocked(p.x + d.x, p.y + d.y) and w.mon_at(p.x + d.x, p.y + d.y) == null:
			w.mons.append(Mon.make("goblin_king", p.x + d.x, p.y + d.y, "normal"))
			break


func _shot_items() -> void:
	var p := game.player
	p.weapon = Item.make(Item.find_base("Rúnakard"), "epic", 3)
	p.armor = Item.make(Item.find_base("Sárkánypáncél"), "legendary", 3)
	p.shield = Item.make(Item.find_base("Acélpajzs"), "rare", 3)
	for nm_r in [["Holdfénypenge", "legendary"], ["Ezoterikus íj", "epic"], ["Pokoli ágyú", "rare"], ["Rúnapajzs", "epic"],
			["Nagy gyógyital", "legendary"], ["Életerő töltő", "rare"], ["Erő tekercs", "epic"], ["Véd tekercs", "common"], ["Tűzgömb", "legendary"]]:
		p.inventory.append(Item.make(Item.find_base(nm_r[0]), nm_r[1], 3))


func _shot_tick() -> void:
	_frame += 1
	if _shot_at < 0.0:
		return
	if shot_scene == "walk":
		_shot_walk()
	if shot_scene == "orb" and _frame == shot_frames:
		# a gömböt kilőjük, és 110 ms múlva (repülés közben) készül a kép
		_shot_fire_orb()
		_shot_at = now_ms() + 110.0
		return
	if (shot_scene == "orb" and _shot_at > 0.0 and now_ms() >= _shot_at) or (shot_scene != "orb" and _frame == shot_frames):
		_shot_at = -1.0
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(shot_path.get_base_dir())
		img.save_png(shot_path)
		print("KÉP MENTVE: ", shot_path, "  (FPS: ", Engine.get_frames_per_second(), ")")
		for k in prof: print("  ", k, ": ", prof[k] / 1000.0 / _frame, " ms/kocka")
		print("  frame: ", _pt["frame"] / 1000.0 / _frame, " ms  _process: ", _pt["proc"] / 1000.0 / _frame, " ms")
		print("  draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "  objects: ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "  process ms: ", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		get_tree().quit()


## tartott jobbra-nyíl szimulálása (valódi bemeneti eseményekkel): a hős folyamatosan lépked és siklik
var _walk_start := Vector2i.ZERO


func _shot_walk() -> void:
	if _frame == 5:
		_walk_start = Vector2i(game.player.x, game.player.y)
		var best := Vector2i(1, 0)
		var best_n := -1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := 0
			while n < 8 and not game.world.blocked(game.player.x + d.x * (n + 1), game.player.y + d.y * (n + 1)) and game.world.mon_at(game.player.x + d.x * (n + 1), game.player.y + d.y * (n + 1)) == null:
				n += 1
			if n > best_n:
				best_n = n
				best = d
		var kc := {Vector2i(1, 0): KEY_RIGHT, Vector2i(-1, 0): KEY_LEFT, Vector2i(0, 1): KEY_DOWN, Vector2i(0, -1): KEY_UP}
		_walk_key = kc[best]
		var ev := InputEventKey.new()
		ev.keycode = _walk_key
		ev.pressed = true
		Input.parse_input_event(ev)
	if _frame == shot_frames - 1:
		print("  séta: ", _walk_start, " -> ", Vector2i(game.player.x, game.player.y), "  (kirajzolt: ", Vector2(game.player.rx, game.player.ry), ")")


var _walk_key := KEY_RIGHT


func _shot_fire_orb() -> void:
	var w := game.world
	var p := game.player
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for dist in [5, 4, 3, 2]:
			var ok := true
			for i in range(1, dist + 1):
				if w.blocked(p.x + d.x * i, p.y + d.y * i) or (i < dist and w.mon_at(p.x + d.x * i, p.y + d.y * i) != null):
					ok = false
					break
			if not ok:
				continue
			var tx: int = p.x + d.x * dist
			var ty: int = p.y + d.y * dist
			var m := w.mon_at(tx, ty)
			if m == null:
				m = Mon.make("orc", tx, ty, "normal")
				m.hp = 999
				m.max_hp = 999
				w.mons.append(m)
			else:
				m.hp = 999
				m.max_hp = 999
			w.update_fov()
			game.do_move(d.x, d.y)
			return
