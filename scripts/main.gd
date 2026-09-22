extends Node2D
## Kard és Mágia — főjelenet: állapotgép (menü, nehézség, hősválasztás, játék, táska, láda, vége),
## billentyűzet/egér, egyenletes lépés-ismétlés, rajzrétegek, képernyőkép-mód (--shot=...).

const LayerScript := preload("res://scripts/layer.gd")
const CFG_PATH := "user://beallitasok.cfg"
const DEFAULT_BINDS := {"up": "ArrowUp", "down": "ArrowDown", "left": "ArrowLeft", "right": "ArrowRight",
	"stair": "Control", "inventory": "i", "menu": "Escape"}
const KEY_DIRS := {"ArrowUp": Vector2i(0, -1), "ArrowDown": Vector2i(0, 1), "ArrowLeft": Vector2i(-1, 0), "ArrowRight": Vector2i(1, 0),
	"w": Vector2i(0, -1), "s": Vector2i(0, 1), "a": Vector2i(-1, 0), "d": Vector2i(1, 0)}
const WORLD_STATES := ["play", "inv", "chest", "over", "win", "perk", "shop", "pause"]

var game := Game.new()
var audio: Audio
var fiok: Fiok
var cv := Cv.new()
var state := "menu"
# kinézet (kozmetika): kasztonként a négy hely kiválasztott darabja
var skins := Skins.alap_valasztas()
var bolt_ui := {"cls": 0, "slot": 0, "opt": 0, "erme": false}
var bolt_vissza := "menu"
var W := 1280.0
var H := 800.0
var tick := 0.0
var dt := 16.0
var char_sel := 0
var diff_sel := 1
var chest_ui: Variant = null       # {"chest": Dictionary, "sel": int}
var perk_ui: Variant = null        # {"ids": Array[String], "sel": int}
var shop_ui: Variant = null        # {"shop": Dictionary, "sel": int}
var pause_sel := 0
var inv_scroll := 0
# automata térkép (Tab)
var map_on := false
var map_img: Image
var map_tex: ImageTexture
var _map_world := 0
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
var _vign_ready := false

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
var shot_depth := 1
var shot_size := Vector2i(1280, 800)   # --size=1024x768: más felbontású elrendezés ellenőrzése
## borítókép-mód (--scene=borito): a főmenü gombok és súgósor nélkül, a hősök neve alájuk írva.
## Így a ParthLauncher borítója mindig a játék MOSTANI rajzait mutatja.
var borito_mod := false
var _frame := 0
var _shot_at := 0.0
var _worst := 0.0        # a leghosszabb képkocka (akadás-keresés)
var _over20 := 0         # hány kocka tartott 20 ms-nál tovább


func _ready() -> void:
	randomize()
	_parse_args()
	if shot_path != "":
		seed(20240101)   # képernyőkép-módban ugyanaz a pálya készül minden futáskor
	_setup_fonts()
	_make_textures()
	_make_layers()
	_load_cfg()
	_build_dir_map()
	fiok = Fiok.new()
	fiok.name = "Fiok"
	add_child(fiok)
	fiok.olvas()   # a ParthLauncher fiok.json-ja (ha nincs, a bolt ezt jelzi, más nem változik)
	audio = Audio.new()
	add_child(audio)
	audio.setup(shot_path == "")
	audio.set_muted(_cfg_muted)
	game.sfx = func(n: String) -> void: audio.play(n)
	game.autosave = shot_path == ""   # képernyőkép-módban nem írunk mentést
	SaveGame.refresh()
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
		["map", null], ["hud", null], ["ui", null],
	]
	for d in defs:
		var n: Node2D = LayerScript.new()
		n.name = d[0]
		if d[1] != null:
			n.material = d[1]
		add_child(n)
		layers[d[0]] = n
	# a kis térkép képpontosan (nem elmosva) nagyítódik fel
	layers["map"].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layers["menu_bg"].fn = func(rid: RID) -> void: _lay(rid, "menu_bg")
	layers["menu_clip"].fn = func(rid: RID) -> void: _lay(rid, "menu_clip")
	layers["menu_front"].fn = func(rid: RID) -> void: _lay(rid, "menu_front")
	layers["menu_title"].fn = func(rid: RID) -> void: _lay(rid, "menu_title")
	layers["world"].fn = func(rid: RID) -> void: _lay(rid, "world")
	layers["glow"].fn = func(rid: RID) -> void: _lay(rid, "glow")
	layers["mid"].fn = func(rid: RID) -> void: _lay(rid, "mid")
	layers["fx_add"].fn = func(rid: RID) -> void: _lay(rid, "fx_add")
	layers["fx"].fn = func(rid: RID) -> void: _lay(rid, "fx")
	layers["map"].fn = func(rid: RID) -> void: _lay(rid, "map")
	layers["hud"].fn = func(rid: RID) -> void: _lay(rid, "hud")
	layers["ui"].fn = func(rid: RID) -> void: _lay(rid, "ui")


func in_world() -> bool:
	return state in WORLD_STATES and game.world != null


var prof := {}


var prof_poly := {}


func _lay(rid: RID, which: String) -> void:
	var _t0 := Time.get_ticks_usec()
	var _p0 := Cv.stat_polys
	_lay2(rid, which)
	cv.flush()
	if shot_path != "":   # mérés csak képernyőkép-módban
		prof[which] = prof.get(which, 0) + Time.get_ticks_usec() - _t0
		prof_poly[which] = prof_poly.get(which, 0) + Cv.stat_polys - _p0


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
		"map": if in_world(): Render.minimap(self, cv)
		"hud": if in_world(): Render.hud(self, cv)
		"ui":
			hits.clear()   # a kattintható felületeket a felület-réteg gyűjti (csak ha újrarajzolódik)
			match state:
				"menu": Screens.menu_top(self, cv)
				"help": Screens.help(self, cv)
				"diff": Screens.diff_sel(self, cv)
				"char": Screens.char_sel(self, cv)
				"inv": Screens.inventory(self, cv)
				"chest": Screens.chest(self, cv)
				"perk": Screens.perk_pick(self, cv)
				"shop": Screens.shop(self, cv)
				"bolt": Screens.bolt(self, cv)
				"pause": Screens.pause(self, cv)
				"over": Screens.game_over(self, cv, false)
				"win": Screens.game_over(self, cv, true)
			if not borito_mod: Screens.mute_button(self, cv)


func add_hit(x: float, y: float, w: float, h: float, fn: Callable) -> void:
	hits.append([Rect2(x, y, w, h), fn])


# ══════════ BEÁLLÍTÁSOK (billentyűk, némítás) ══════════
func _load_cfg() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) == OK:
		for k in DEFAULT_BINDS:
			binds[k] = str(cf.get_value("binds", k, DEFAULT_BINDS[k]))
		_cfg_muted = bool(cf.get_value("hang", "nemitva", false))
		skins = Skins.betolt(cf)


var _cfg_muted := false


func save_cfg() -> void:
	if shot_path != "":
		return   # képernyőkép-módban nem írjuk felül a játékos beállításait
	var cf := ConfigFile.new()
	cf.load(CFG_PATH)
	for k in binds:
		cf.set_value("binds", k, binds[k])
	cf.set_value("hang", "nemitva", audio.muted if audio else false)
	Skins.ment(cf, skins)
	cf.save(CFG_PATH)


## a hős kinézetének megváltoztatása (csak külső — játékértéket soha nem érint)
func set_skin(ck: String, slot: String, v: String) -> void:
	if not Skins.ervenyes(ck, slot, v):
		return
	var d: Dictionary = skins.get(ck, {})
	d[slot] = v
	skins[ck] = d
	save_cfg()


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
	else:
		# ablakból (táska, szünet, láda) visszatérve ne peregjen le azonnal egy kör
		_idle_at = now_ms()
		_idle_first = true


func start_game(cls: String, diff: String) -> void:
	game.start(cls, diff)
	inv_scroll = 0
	chest_ui = null
	perk_ui = null
	shop_ui = null
	map_on = false
	set_state("play")
	if game.autosave:
		SaveGame.save_run(game)


## Folytatás: a mentett kaland visszatöltése (a főmenüben csak akkor látszik, ha van mentés)
func continue_game() -> bool:
	var g := SaveGame.load_run()
	if g == null:
		SaveGame.erase()
		set_state("menu")
		return false
	game = g
	game.sfx = func(n: String) -> void: audio.play(n)
	game.autosave = shot_path == ""
	inv_scroll = 0
	chest_ui = null
	perk_ui = null
	shop_ui = null
	map_on = false
	_map_world = 0
	game.player.add_msg("Folytatod a kalandot...", Data.P["parchGold"])
	set_state("play")
	return true


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
		_check_perk()   # a tűzgömbbel is lehet szintet lépni


func go_diff() -> void:
	diff_sel = 1
	set_state("diff")


func go_char() -> void:
	char_sel = 0
	set_state("char")


func close_pause() -> void:
	set_state("play")


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
	elif game.pending_shop != null:
		shop_ui = {"shop": game.pending_shop, "sel": 0}
		game.pending_shop = null
		set_state("shop")
	if game.player and not game.player.alive:
		if game.autosave:
			SaveGame.erase()   # az elesett hőst nem lehet folytatni
		set_state("over")
		held["active"] = false
		return
	_check_perk()


## Szintlépés után: három lap közül lehet választani (több szint egymás után is jöhet)
func _check_perk() -> void:
	if game.pending_perks <= 0 or state == "over" or state == "win":
		return
	var ids := Perks.offer(game.player)
	if ids.is_empty():
		game.pending_perks = 0   # már minden képesség ki van maxolva
		return
	perk_ui = {"ids": ids, "sel": 0}
	held["active"] = false
	set_state("perk")


func pick_perk(i: int) -> void:
	if perk_ui == null:
		return
	var ids: Array = perk_ui["ids"]
	if i < 0 or i >= ids.size():
		return
	Perks.apply(game.player, ids[i])
	game.pending_perks = maxi(0, game.pending_perks - 1)
	perk_ui = null
	set_state("play")
	_check_perk()


func buy_shop(i: int) -> void:
	if shop_ui == null:
		return
	game.buy(shop_ui["shop"], i)


func close_shop() -> void:
	shop_ui = null
	set_state("play")


# ══════════ KINÉZET BOLT (kozmetika) ══════════
func bolt_opciok(ck: String, slot: String) -> Array:
	var o: Array = [""]
	o.append_array((Skins.VARIANSOK[ck][slot] as Array))
	return o


func bolt_kaszt() -> String:
	return Skins.CLS_ORDER[clampi(int(bolt_ui["cls"]), 0, 2)]


func bolt_hely() -> String:
	return Skins.SLOTS[clampi(int(bolt_ui["slot"]), 0, Skins.SLOTS.size() - 1)]


func open_bolt(vissza: String) -> void:
	bolt_vissza = vissza
	var ci := 0
	if game.player != null and Data.CLASS_ORDER.has(game.player.cls):
		ci = Data.CLASS_ORDER.find(game.player.cls)
	bolt_ui = {"cls": ci, "slot": 0, "opt": 0, "erme": false}
	fiok.olvas()      # a bolt megnyitásakor újraolvassuk a fiok.json-t
	fiok.frissit()    # érme + birtokolt darabok (aszinkron: offline sem akad meg)
	set_state("bolt")


func close_bolt() -> void:
	set_state(bolt_vissza if bolt_vissza != "" else "menu")


func bolt_valaszt(ck: String, slot: String, v: String) -> void:
	var opts := bolt_opciok(ck, slot)
	bolt_ui["cls"] = Skins.CLS_ORDER.find(ck)
	bolt_ui["slot"] = Skins.SLOTS.find(slot)
	bolt_ui["opt"] = maxi(0, opts.find(v))
	if v == "" or fiok.birtokol(Skins.kulcs(ck, slot, v)):
		set_skin(ck, slot, v)
	else:
		fiok.vasarol(Skins.kulcs(ck, slot, v), func(ok: bool, _u: String) -> void:
			if ok:
				set_skin(ck, slot, v))


func bolt_enter() -> void:
	var opts := bolt_opciok(bolt_kaszt(), bolt_hely())
	bolt_valaszt(bolt_kaszt(), bolt_hely(), str(opts[clampi(int(bolt_ui["opt"]), 0, opts.size() - 1)]))


# ══════════ JÁTÉK KÖZBENI MENÜ (Esc) ══════════
func save_and_menu() -> void:
	if game.autosave:
		SaveGame.save_run(game)
	held["active"] = false
	set_state("menu")


func abandon_run() -> void:
	if game.autosave:
		SaveGame.erase()
	held["active"] = false
	set_state("menu")


func quit_app() -> void:
	if in_world() and game.autosave and game.player and game.player.alive:
		SaveGame.save_run(game)
	get_tree().quit()


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


# ══════════ ÉLŐ KATAKOMBA ══════════
## A szörnyek akkor is lépnek, ha a hős áll: ha eltelik IDLE_MS úgy, hogy nem történt kör,
## magától lepereg egy „várakozás” kör. A hős bármikor közbeléphet — az ő lépése azonnal
## újraindítja a számlálót, mert a világ körszámlálója megváltozik.
var _idle_turn := -1
var _idle_at := 0.0
var _idle_first := true    # a megtorpanás utáni ELSŐ várakozó kör kicsit később jön

# A szörnyek siklásához: mennyi idő telik el két kör között (mérve, simítva).
# Ennyi idő alatt tesznek meg egy mezőt, így nem villannak és nem állnak meg.
var _kor_hossz_ms := 400.0
var _mozgas_kor := -1
var _mozgas_kor_ms := 0.0

func idle_tick(now: float) -> void:
	if shot_path != "":
		return                                     # képernyőkép-módban álljon az idő
	if state != "play" or game.world == null or held["active"]:
		return
	if game.player == null or not game.player.alive:
		return
	if game.pending_chest != null or game.pending_shop != null or game.pending_perks > 0:
		return
	if int(game.world.turn) != _idle_turn:         # a hős tett valamit: újraindul a várakozás
		_idle_turn = int(game.world.turn)
		_idle_at = now
		_idle_first = true
		return
	if now - _idle_at < (Data.IDLE_FIRST_MS if _idle_first else Data.IDLE_MS):
		return
	_idle_first = false
	game.advance_turn(true)     # várakozó kör: a szörnyek lépnek, de a méreg nem marja a hőst
	_idle_turn = int(game.world.turn)
	_idle_at = now
	_after_move()


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
				if SaveGame.has_save():
					continue_game()
				else:
					diff_sel = 1
					set_state("diff")
			elif k == "Escape":
				quit_app()
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
			if k == "Tab":
				map_on = not map_on
			if k == "k":
				game.search()   # kutatás: titkos ajtók és csapdák a szomszédban
				_after_move()
			if k == binds["stair"] or k == "." or k == ">":
				if game.on_stair():
					next_level()
			if k == binds["menu"] or k == "Escape":
				pause_sel = 0
				set_state("pause")
			if game.player and not game.player.alive:
				if game.autosave:
					SaveGame.erase()
				set_state("over")
		"pause":
			if k == "Escape" or k == binds["menu"]:
				set_state("play")
			elif k in ["ArrowUp", "w"]: pause_sel = (pause_sel + 3) % 4
			elif k in ["ArrowDown", "s"]: pause_sel = (pause_sel + 1) % 4
			elif k == "Enter":
				match pause_sel:
					0: set_state("play")
					1: open_bolt("pause")
					2: save_and_menu()
					_: abandon_run()
			elif k == "1": set_state("play")
			elif k == "2": open_bolt("pause")
			elif k == "3": save_and_menu()
			elif k == "4": abandon_run()
		"bolt":
			var opts := bolt_opciok(bolt_kaszt(), bolt_hely())
			if bool(bolt_ui["erme"]):
				if k == "Escape" or k == "Enter": bolt_ui["erme"] = false
				elif k in ["1", "2", "3"]: Fiok.bolt_megnyit(int(k) - 1)
			elif k == "Escape" or k == binds["menu"]:
				close_bolt()
			elif k in ["ArrowUp", "w"]:
				bolt_ui["slot"] = (int(bolt_ui["slot"]) + Skins.SLOTS.size() - 1) % Skins.SLOTS.size()
				bolt_ui["opt"] = 0
			elif k in ["ArrowDown", "s"]:
				bolt_ui["slot"] = (int(bolt_ui["slot"]) + 1) % Skins.SLOTS.size()
				bolt_ui["opt"] = 0
			elif k in ["ArrowLeft", "a"]:
				bolt_ui["opt"] = (int(bolt_ui["opt"]) + opts.size() - 1) % opts.size()
			elif k in ["ArrowRight", "d"]:
				bolt_ui["opt"] = (int(bolt_ui["opt"]) + 1) % opts.size()
			elif k == "Tab":
				bolt_ui["cls"] = (int(bolt_ui["cls"]) + 1) % 3
				bolt_ui["slot"] = 0
				bolt_ui["opt"] = 0
			elif k == "Enter" or k == " ":
				bolt_enter()
			elif k == "e":
				bolt_ui["erme"] = true
			elif k in ["1", "2", "3", "4"]:
				var ii := int(k) - 1
				if ii < opts.size():
					bolt_ui["opt"] = ii
					bolt_enter()
		"perk":
			if perk_ui == null:
				set_state("play")
			elif k in ["ArrowLeft", "a"]: perk_ui["sel"] = (perk_ui["sel"] + (perk_ui["ids"] as Array).size() - 1) % (perk_ui["ids"] as Array).size()
			elif k in ["ArrowRight", "d"]: perk_ui["sel"] = (perk_ui["sel"] + 1) % (perk_ui["ids"] as Array).size()
			elif k == "Enter": pick_perk(perk_ui["sel"])
			elif k in ["1", "2", "3"]: pick_perk(int(k) - 1)
		"shop":
			if k == "Escape" or k == binds["menu"] or k == "Enter":
				close_shop()
			elif k in ["1", "2", "3"]:
				buy_shop(int(k) - 1)
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
	if _pt["last"] > 0:
		var fms: float = (_p0 - _pt["last"]) / 1000.0
		_pt["frame"] += _p0 - _pt["last"]
		if _frame > 12:   # az indulás első kockái nem számítanak
			_worst = maxf(_worst, fms)
			if fms > 20.0: _over20 += 1
	_pt["last"] = _p0
	_process2(delta)
	_pt["proc"] += Time.get_ticks_usec() - _p0


func _process2(delta: float) -> void:
	var sz := get_viewport_rect().size
	if sz.x != W or sz.y != H or not _vign_ready:
		W = sz.x
		H = sz.y
		_vign_ready = true
		_update_vignette()
	dt = minf(50.0, delta * 1000.0)
	tick += dt / 16.67
	if shot_path != "":
		tick = _frame * 2.5   # képernyőkép-módban rögzített ütem: két futás képe összevethető
	var now := Time.get_ticks_usec() / 1000.0
	step_repeat(now)
	idle_tick(now)
	if game != null:
		game.prune_fx()      # a lejárt lövedékek és villanások eltűnnek
	if in_world():
		_update_motion(now)
	_update_layers()
	if shot_path != "":
		_shot_tick()


# ══════════ MELYIK RÉTEGET KELL ÚJRARAJZOLNI? ══════════
## Egy köteg átadása a grafikus meghajtónak (ANGLE/D3D11) sokszorta drágább, mint a rajzolás maga,
## ezért csak azt a réteget rajzoljuk újra, amelynek a tartalma tényleg változott. A rétegek
## "aláírása" minden olyan értéket tartalmaz, amitől a kép függ (mozgó részeknél a fázisukat is).
var _sig := {}
var world_fading := true


func _gate(which: String, sig: Variant) -> void:
	if _sig.get(which) != sig:
		_sig[which] = sig
		layers[which].queue_redraw()


func _show(which: String, vis: bool, redraw: bool) -> void:
	layers[which].visible = vis
	if vis and redraw:
		layers[which].queue_redraw()


func _update_layers() -> void:
	var menu := state == "menu"
	var wo := in_world()
	# menü: a háttér csak átméretezéskor, az élő rétegek (sárkány, tűz, parázs) minden kockán
	layers["menu_bg"].visible = menu
	if menu and _bg_size != Vector2(W, H):
		_bg_size = Vector2(W, H)
		layers["menu_bg"].queue_redraw()
	_show("menu_clip", menu, true)
	_show("menu_front", menu, true)
	_show("menu_title", menu, true)
	# pálya: a fények, szörnyek és villanások mozognak, a csempék és a HUD ritkán változnak
	_show("glow", wo, true)
	_show("mid", wo, true)
	_show("fx_add", wo, true)
	_show("fx", wo, true)
	layers["world"].visible = wo
	layers["hud"].visible = wo
	layers["map"].visible = wo and map_on
	if wo:
		var ws := [cam.x, cam.y, W, H, game.world.get_instance_id(), game.world.fov_version]
		if world_fading or _sig.get("world") != ws:
			_sig["world"] = ws
			layers["world"].queue_redraw()
		_gate("hud", _hud_sig())
		if map_on:
			_sync_map()
			_gate("map", [W, H, game.world.explored_seq, game.player.x, game.player.y, game.world.dungeon_level, _map_world])
	_gate("ui", _ui_sig())


# ══════════ AUTOMATA TÉRKÉP: a bejárt mezők képe ══════════
## A 80×60-as kép CSAK az újonnan felfedezett mezőkkel frissül (szintenként egyszer épül fel
## teljesen), így a kirajzolás egyetlen textúra-hívás marad.
func _sync_map() -> void:
	var w := game.world
	if map_img == null:
		map_img = Image.create(Data.MAP_W, Data.MAP_H, false, Image.FORMAT_RGBA8)
		map_tex = ImageTexture.create_from_image(map_img)
	var id := int(w.get_instance_id())
	var dirty := false
	if _map_world != id:
		_map_world = id
		map_img.fill(Color(0, 0, 0, 0))
		for i in w.explored.size():
			if w.explored[i]:
				map_img.set_pixel(int(i / Data.MAP_H), i % Data.MAP_H, _map_col(w, i))
		w.new_explored.clear()
		dirty = true
	elif w.new_explored.size() > 0:
		for i in w.new_explored:
			map_img.set_pixel(int(i / Data.MAP_H), i % Data.MAP_H, _map_col(w, i))
		w.new_explored.clear()
		dirty = true
	if dirty:
		map_tex.update(map_img)


const MAP_COL_WALL := Color(0.14, 0.12, 0.09, 0.92)
const MAP_COL_FLOOR := Color(0.40, 0.35, 0.26, 0.92)
const MAP_COL_STAIR := Color(0.70, 0.64, 1.0, 1.0)


func _map_col(w: World, i: int) -> Color:
	var t := w.tiles[i]
	if t == Data.STAIR:
		return MAP_COL_STAIR
	if t == Data.WALL or t == Data.SECRET:
		return MAP_COL_WALL
	var k := w.kind_map[i] if i < w.kind_map.size() else 0
	if k > 0:
		var cc: Color = Cv.col(Data.ROOM_KINDS[Data.ROOM_KIND_ORDER[k - 1]]["col"])
		return Color(cc.r * 0.62, cc.g * 0.62, cc.b * 0.62, 0.92)
	return MAP_COL_FLOOR


func _hud_sig() -> Array:
	var p := game.player
	var w := game.world
	return [W, H, p.hp, p.max_hp, p.xp, p.xp_next, p.lives, p.poison, p.regen, p.lifesteal,
		p.cls, p.plvl, p.atk, p.mag, p.def, p.msg_seq, w.turn, w.dungeon_level, w.diff,
		p.weapon, p.armor, p.shield, game.on_stair(), binds["stair"], p.gold, p.perk_seq]


func _ui_sig() -> Array:
	var s: Array = [state, W, H, audio.muted if audio else false]
	match state:
		"menu":
			s.append(audio.music_started if audio else false)
			s.append(SaveGame.has_save())
		"pause": s.append(pause_sel)
		"bolt":
			s.append_array([bolt_ui["cls"], bolt_ui["slot"], bolt_ui["opt"], bolt_ui["erme"],
				fiok.seq if fiok else 0, Sprites.hero_phase(tick),
				Skins.sig(skins, Data.CLASS_ORDER[clampi(int(bolt_ui["cls"]), 0, 2)])])
		"perk":
			if perk_ui != null:
				s.append_array(perk_ui["ids"])
				s.append(perk_ui["sel"])
				s.append(game.player.plvl if game.player else 0)
		"shop":
			if shop_ui != null:
				for e in (shop_ui["shop"]["stock"] as Array):
					s.append(e["sold"])
			s.append(game.player.gold if game.player else 0)
			s.append(tick)
		"help":
			s.append(bind_edit)
			for k in DEFAULT_BINDS:
				s.append(binds[k])
		"diff": s.append(diff_sel)
		"char":
			s.append(char_sel)
			s.append(Sprites.hero_phase(tick))   # a hősök lebegése 16 fázisú
		"over", "win":
			if game.world:
				s.append_array([game.player.plvl, game.world.turn, game.world.dungeon_level])
		"inv", "chest":
			s.append(tick)                       # a tárgy-ikonok élnek: minden képkockán kell
	return s


## egyenletes sebességű siklás (nem lassul le minden lépés végén, így tartott gombnál folyamatos)
func _update_motion(now: float) -> void:
	var p := game.player
	var step_d := Data.MOVE_SPD * dt / 1000.0
	p.rx = _glide(p.rx, p.x, step_d)
	p.ry = _glide(p.ry, p.y, step_d)
	# A SZÖRNYEK a kör HOSSZÁHOZ igazodnak, nem a hős sebességéhez.
	#
	# Régen ugyanazzal a fix sebességgel siklottak, mint a hős: egy mezőt ~136 ms
	# alatt tettek meg, a várakozó körök viszont 1,1 másodpercenként jönnek –
	# vagyis villantak egyet, aztán majdnem egy teljes másodpercig álltak. Ettől
	# volt szaggatott. Most megmérjük, mennyi idő telik el két kör között, és a
	# lépést pont ennyi idő alatt teszik meg: így folyamatosan, egyenletesen
	# közelednek. Ha a játékos rohan, a körök sűrűbbek, és velük együtt gyorsulnak.
	var kor := int(game.world.turn)
	if kor != _mozgas_kor:
		if _mozgas_kor >= 0:
			var telt := now - _mozgas_kor_ms
			_kor_hossz_ms = clampf(lerpf(_kor_hossz_ms, telt, 0.5), float(Data.STEP_MS), float(Data.IDLE_MS))
		_mozgas_kor = kor
		_mozgas_kor_ms = now
	var mon_d := dt / maxf(1.0, _kor_hossz_ms)
	for m in game.world.mons:
		if m.alive:
			m.rx = _glide(m.rx, m.x, mon_d)
			m.ry = _glide(m.ry, m.y, mon_d)
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


# ══════════ KÉPERNYŐKÉP-MÓD ══════════
## --shot=utvonal.png --scene=menu|diff|char|help|play|orb|walk|inv|chest|over|perk|shop|trap|map|pause|load
func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--scene="): shot_scene = a.substr(8)
		elif a.begins_with("--cls="): shot_cls = a.substr(6)
		elif a.begins_with("--frames="): shot_frames = int(a.substr(9))
		elif a.begins_with("--depth="): shot_depth = int(a.substr(8))
		elif a.begins_with("--size="):
			var wh := a.substr(7).split("x")
			if wh.size() == 2:
				shot_size = Vector2i(maxi(640, int(wh[0])), maxi(480, int(wh[1])))


func _setup_shot() -> void:
	audio.music_started = true
	# a képernyőkép rögzített elrendezéssel készül (alapból 1280×800, --size=…-szal más is)
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = shot_size
	match shot_scene:
		"blank": set_state("blank")
		"borito":
			borito_mod = true
			skins = Skins.alap_valasztas()   # a borítón mindenki az alap kinézetét viselje
			set_state("menu")
		"diff": set_state("diff")
		"char":
			diff_sel = 1
			char_sel = Data.CLASS_ORDER.find(shot_cls) if Data.CLASS_ORDER.has(shot_cls) else 0
			set_state("char")
		"help": set_state("help")
		"bolt", "bolt_preview", "shop_preview": _shot_bolt(shot_scene != "bolt")
		"load", "folytat":
			# mentett kaland a főmenü "Folytatás" gombjához (a "folytat" rögtön vissza is tölti)
			start_game(shot_cls, "normal")
			game.player.gold = 148
			Perks.apply(game.player, "eletero")
			Perks.apply(game.player, "kincs")
			for i in 30:
				game.do_move([1, 0, -1, 0][i % 4], [0, 1, 0, -1][i % 4])
			SaveGame.save_run(game)
			SaveGame.refresh()
			if shot_scene == "folytat":
				continue_game()
				map_on = true
			else:
				set_state("menu")
		"play", "orb", "inv", "chest", "over", "walk", "perk", "shop", "trap", "map", "pause":
			start_game(shot_cls, "normal")
			# mérési célra mélyebb szint (ott sokkal több a szörny)
			while game.world.dungeon_level < shot_depth:
				game.player.plvl = game.world.dungeon_level * 3
				game.player.max_hp = 500
				game.player.hp = 500
				game.next_level()
			if shot_scene != "orb" and shot_scene != "walk" and shot_scene != "map":
				_shot_populate()
			if shot_scene == "inv":
				_shot_items()
				Perks.apply(game.player, "eletero")
				Perks.apply(game.player, "eletero")
				Perks.apply(game.player, "kincs")
				Perks.apply(game.player, "regen")
				game.player.gold = 214
				set_state("inv")
			elif shot_scene == "perk":
				var ids: Array = ["eletero", "szivossag", "regen"]
				match shot_cls:
					"Lovag": ids = ["blokk", "dofes", "eletero"]
					"Mágus": ids = ["fokusz", "atuto", "regen"]
					"Íjász": ids = ["sasszem", "gyorslab", "kincs"]
				game.player.plvl = 4
				perk_ui = {"ids": ids, "sel": 0}
				set_state("perk")
			elif shot_scene == "shop":
				_shot_shop()
			elif shot_scene == "trap":
				_shot_traps()
			elif shot_scene == "map":
				_shot_map()
			elif shot_scene == "pause":
				pause_sel = 1
				set_state("pause")
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


## Kinézet bolt képernyőképe: bejelentkezett fiók, érmék és néhány már megvásárolt darab.
## (Hálózat nélkül — a Fiok offline módban egyetlen kérést sem indít.)
func _shot_bolt(felveve: bool) -> void:
	fiok.offline_mod = true
	open_bolt("menu")
	fiok.betoltve = true
	fiok.email = "hos@parthenon.hu"
	fiok.erme = 240
	fiok.erme_ismert = true
	fiok.uzenet = ""
	fiok.uzenet_hiba = false
	fiok.folyamatban = false
	for k in ["lovag_fej_sisak_arany", "lovag_fej_sisak_szarv", "lovag_test_pancel_arany",
			"lovag_lab_vaslabvert", "lovag_fegyver_kard_lang",
			"magus_fej_kalap_csillag", "magus_test_kontos_kek", "magus_lab_csizma_arany", "magus_fegyver_bot_kristaly",
			"ijasz_fej_tollas_kalap", "ijasz_test_bor_vert", "ijasz_lab_csizma_magas", "ijasz_fegyver_szamszerij"]:
		fiok.birtok[k] = true
	if felveve:
		skins["lovag"] = {"fej": "sisak_arany", "test": "pancel_arany", "lab": "vaslabvert", "fegyver": "kard_lang"}
		skins["magus"] = {"fej": "kalap_csillag", "test": "kontos_kek", "lab": "csizma_arany", "fegyver": "bot_kristaly"}
		skins["ijasz"] = {"fej": "tollas_kalap", "test": "bor_vert", "lab": "csizma_magas", "fegyver": "szamszerij"}
		bolt_ui["slot"] = 3
		bolt_ui["opt"] = 1
	bolt_ui["cls"] = maxi(0, Data.CLASS_ORDER.find(shot_cls))


## kereskedő a hős mezőjére, tele erszénnyel
func _shot_shop() -> void:
	var p := game.player
	p.gold = 96
	var sh := {"x": p.x, "y": p.y, "stock": Dungeon.make_stock(3)}
	game.world.shops.append(sh)
	shop_ui = {"shop": sh, "sel": 0}
	set_state("shop")


## csapdák és titkos ajtó a hős köré, egy el is sül
func _shot_traps() -> void:
	var w := game.world
	var p := game.player
	var spots := [[Vector2i(1, 0), "tuske"], [Vector2i(-1, 0), "mereg"], [Vector2i(0, 1), "riaszto"],
		[Vector2i(2, 1), "tuske"], [Vector2i(-2, -1), "mereg"]]
	for s in spots:
		var d: Vector2i = s[0]
		var x: int = p.x + d.x
		var y: int = p.y + d.y
		if not w.blocked(x, y) and w.trap_at(x, y) == null:
			w.traps.append({"x": x, "y": y, "type": s[1], "found": true, "sprung": false})
	# egy titkos ajtó a közelben, már megtalálva
	for d in [Vector2i(0, -2), Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3)]:
		var x: int = p.x + d.x
		var y: int = p.y + d.y
		if x > 1 and y > 1 and x < Data.MAP_W - 2 and y < Data.MAP_H - 2 and w.tile(x, y) == Data.WALL:
			w.tiles[x * Data.MAP_H + y] = Data.FLOOR
			w.secrets.append({"x": x, "y": y, "kind": "kamra", "found": true})
			break
	# a hős mezőjén is van egy, ami rögtön el is sül
	w.traps.append({"x": p.x, "y": p.y, "type": "tuske", "found": false, "sprung": false})
	game.trigger_trap()
	w.update_fov()


## sok felderített mező + bekapcsolt automata térkép
func _shot_map() -> void:
	var w := game.world
	map_on = true
	for i in mini(14, w.rooms.size()):
		var r: Rect2i = w.rooms[i].grow(1)
		for x in range(maxi(0, r.position.x), mini(Data.MAP_W, r.position.x + r.size.x)):
			for y in range(maxi(0, r.position.y), mini(Data.MAP_H, r.position.y + r.size.y)):
				var k := x * Data.MAP_H + y
				if not w.explored[k]:
					w.explored[k] = 1
					w.explored_seq += 1
					w.new_explored.append(k)
	# az utolsó (lépcsős) szoba is legyen a térképen
	var last: Rect2i = w.rooms[w.rooms.size() - 1].grow(1)
	for x in range(maxi(0, last.position.x), mini(Data.MAP_W, last.position.x + last.size.x)):
		for y in range(maxi(0, last.position.y), mini(Data.MAP_H, last.position.y + last.size.y)):
			var k2 := x * Data.MAP_H + y
			if not w.explored[k2]:
				w.explored[k2] = 1
				w.explored_seq += 1
				w.new_explored.append(k2)


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
		for k in prof: print("  %-10s %7.3f ms/kocka   %6.2f poly/kocka" % [k, prof[k] / 1000.0 / _frame, float(prof_poly.get(k, 0)) / _frame])
		print("  frame: ", _pt["frame"] / 1000.0 / _frame, " ms  _process: ", _pt["proc"] / 1000.0 / _frame, " ms")
		print("  legrosszabb kocka: %.1f ms   20 ms feletti kockák: %d / %d" % [_worst, _over20, _frame])
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
