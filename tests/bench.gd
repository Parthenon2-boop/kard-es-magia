extends SceneTree
## Rajzolási mikro-mérés (fejlesztői segédlet): godot --headless --path . -s res://tests/bench.gd

func _init() -> void:
	var c := Cv.new()
	var ci := RenderingServer.canvas_item_create()
	# a játékban a ragyogás kész textúrából jön — enélkül a tárgy-ikonok mérése félrevezető
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	Sprites.glow_tex = gt
	var icon := func(nm: String) -> Callable:
		var it := Item.make(Item.find_base(nm), "epic", 1)
		return func() -> void: Sprites.item_icon(c, it, 100, 100, 27, Time.get_ticks_usec() * 0.001)
	var tests := {
		"knight": func() -> void: Sprites.knight(c, 100, 100, 29, 10),
		"mage": func() -> void: Sprites.mage(c, 100, 100, 29, 10),
		"goblin": func() -> void: Sprites.goblin(c, 100, 100, 34, 10, 1),
		"dragon_mon": func() -> void: Sprites.dragon(c, 100, 100, 34, 10, 1),
		"icon_sword": func() -> void: Sprites.item_icon(c, Item.make(Item.find_base("Acélkard"), "epic", 1), 100, 100, 27, 10),
		"icon_heal": func() -> void: Sprites.item_icon(c, Item.make(Item.find_base("Gyógyital"), "epic", 1), 100, 100, 27, 10),
		"menu_dragon": func() -> void: MenuArt.dragon(c, 640, 500, 466, 10),
		"menu_dragon_t": func() -> void: MenuArt.dragon(c, 640, 500, 466, Time.get_ticks_usec() * 0.001),
		"menu_fire": func() -> void: MenuArt.fire(c, 640, 400, 15, 10),
		"menu_torch": func() -> void: MenuArt.torch(c, 200, 300, 1.33, 10, 0.0),
		"hero_cached": func() -> void: Sprites.hero_cached(c, "Lovag", 100, 100, 135, 10),
		"embers": func() -> void:
			for i in 55:
				c.fs(Color(1, 0.6, 0.2, 0.3))
				c.circ(i * 7, 100, 2.0),
		"menu_dg": func() -> void:
			var dg := Cv.radial(640, 360, 8, 560).stop(0, Cv.rgba(180, 45, 18, 0.32)).stop(1, Cv.rgba(80, 8, 8, 0))
			dg.seg = 30.0
			c.fs(dg); c.fill_rect(360, 220, 560, 460),
		"ls_text": func() -> void: MenuArt.ls_text(c, "KARD ÉS MÁGIA", 640, 100, "#ffffff", 48, 2.6, "center"),
		"crossed_swords": func() -> void: MenuArt.crossed_swords(c, 200, 200, 37, "#c8a03a"),
		"soft_shadow": func() -> void: c.soft_shadow(100, 100, 580, 168, 12, Color(0, 0, 0, 0.88), 36, 10),
		"ic_sword": icon.call("Acélkard"),
		"ic_heal": icon.call("Gyógyital"),
		"ic_maxheal": icon.call("Életerő töltő"),
		"ic_cannon": icon.call("Kéziágyú"),
		"ic_fireball": icon.call("Tűzgömb"),
		"ic_scroll": icon.call("Erő tekercs"),
		"ic_armor": icon.call("Bőrpáncél"),
		"trap_tuske": func() -> void: Sprites.trap(c, "tuske", 100, 100, 40, false),
		"trap_mereg": func() -> void: Sprites.trap(c, "mereg", 100, 100, 40, false),
		"trap_riaszto": func() -> void: Sprites.trap(c, "riaszto", 100, 100, 40, true),
		"secret_door": func() -> void: Sprites.secret_door(c, 100, 100, 40),
		"shrine": func() -> void: Sprites.shrine(c, 100, 100, 40, "gyogyulas", false, 10),
		"merchant": func() -> void: Sprites.merchant(c, 100, 100, 40, 10),
		"mon_goblin": func() -> void: Sprites.monster(c, "goblin", 100, 100, 34, 10, 1),
		"mon_dragon": func() -> void: Sprites.monster(c, "dragon", 100, 100, 34, 10, 1),
		"circle_small": func() -> void: c.fs("#ff0000"); c.circ(100, 100, 5),
		"circle_big": func() -> void: c.fs("#ff0000"); c.circ(100, 100, 150),
		"radial_big": func() -> void: c.fs(Cv.radial(100, 100, 5, 130).stop(0, Color(1, 0, 0, 0.2)).stop(1, Color(1, 0, 0, 0))); c.circ(100, 100, 130),
		"stroke_arc": func() -> void: c.ss("#ffffff"); c.lw(2); c.bp(); c.arc(100, 100, 30, 0, 3); c.stroke(),
		"ftxt": func() -> void: c.ftxt("Életerő 46/46", 10, 10, "#ffffff", 12),
		"measure": func() -> void: Cv.measure("Életerő 46/46", 12),
		"panel": func() -> void: c.panel(10, 10, 200, 40, "#2e2210", "#d4a84b", 2, 8),
	}
	for k in tests:
		c.begin(ci)
		var t0 := Time.get_ticks_usec()
		var n := 200
		for i in n:
			tests[k].call()
			if i % 20 == 0:
				c.flush()
		c.flush()
		RenderingServer.canvas_item_clear(ci)
		print("%-16s %8.3f ms" % [k, (Time.get_ticks_usec() - t0) / 1000.0 / n])
	# a gyorsítótárazott hálók mérete (az index-szám dönti el, mennyire éri meg összefűzni)
	print("── gyorsítótárazott hálók (csúcs) ──")
	for key in Cv._rec_cache:
		print("  %-26s %7d" % [key, ((Cv._rec_cache[key] as Array)[0] as PackedVector2Array).size()])
	for key in MenuArt._dcache:
		if MenuArt._dcache[key] is Array:
			print("  sárkány/%-18s %7d" % [key, ((MenuArt._dcache[key] as Array)[0] as PackedVector2Array).size()])
	RenderingServer.free_rid(ci)
	quit()
