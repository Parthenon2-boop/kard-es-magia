extends SceneTree
## Rajzolási mikro-mérés (fejlesztői segédlet): godot --headless --path . -s res://tests/bench.gd

func _init() -> void:
	var c := Cv.new()
	var ci := RenderingServer.canvas_item_create()
	var tests := {
		"knight": func() -> void: Sprites.knight(c, 100, 100, 29, 10),
		"mage": func() -> void: Sprites.mage(c, 100, 100, 29, 10),
		"goblin": func() -> void: Sprites.goblin(c, 100, 100, 34, 10, 1),
		"dragon_mon": func() -> void: Sprites.dragon(c, 100, 100, 34, 10, 1),
		"icon_sword": func() -> void: Sprites.item_icon(c, Item.make(Item.find_base("Acélkard"), "epic", 1), 100, 100, 27, 10),
		"icon_heal": func() -> void: Sprites.item_icon(c, Item.make(Item.find_base("Gyógyital"), "epic", 1), 100, 100, 27, 10),
		"menu_dragon": func() -> void: MenuArt.dragon(c, 640, 500, 466, 10),
		"menu_fire": func() -> void: MenuArt.fire(c, 640, 400, 15, 10),
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
		print("%-14s %8.3f ms" % [k, (Time.get_ticks_usec() - t0) / 1000.0 / n])
	RenderingServer.free_rid(ci)
	quit()
