extends SceneTree
## Próba: ha a hős áll, az ellenségek maguktól lépnek-e (a főjelenet várakozó köreivel).
##   godot --path . -s res://tests/idle_proba.gd
func _init() -> void:
	_fut.call_deferred()

func _fut() -> void:
	Meta.persist = false
	SaveGame.DIR = "user://_teszt_mentesek/"
	var m: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 10: await process_frame
	m.game.autosave = false
	Meta.data()["intro"] = true
	m.start_game("Lovag", "normal")
	var w: World = m.game.world
	for mo in w.mons:
		mo.awake = true   # mindenki a hős felé tart
	var kor0 := int(w.turn)
	var hely0: Array = []
	for mo in w.mons:
		hely0.append(Vector2i(mo.x, mo.y))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4500:
		await process_frame
	var mozdult := 0
	for i in w.mons.size():
		if Vector2i(w.mons[i].x, w.mons[i].y) != hely0[i]:
			mozdult += 1
	print("4,5 mp állás alatt: ", int(w.turn) - kor0, " kör telt el, ", mozdult, " / ", w.mons.size(), " szörny mozdult el")
	print("EREDMENY: ", "RENDBEN" if int(w.turn) - kor0 >= 3 and mozdult > 0 else "NEM MOZOGNAK")
	SaveGame.erase_all()
	quit()