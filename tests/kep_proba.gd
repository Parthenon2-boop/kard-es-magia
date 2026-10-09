extends SceneTree
## Próba: a felület-nagyítás (content_scale_factor) a játék beállításával (nyújtás kikapcsolva) is hat-e.
##   godot --path . -s res://tests/kep_proba.gd      (ablak kell hozzá, nem fej nélküli)
func _init() -> void:
	_fut.call_deferred()

func _fut() -> void:
	for i in 5: await process_frame
	var px := root.size
	var elotte := root.get_visible_rect().size
	root.content_scale_factor = 2.0
	for i in 5: await process_frame
	var utana := root.get_visible_rect().size
	print("ablak: ", px, "  logikai méret 100%-on: ", elotte, "  200%-on: ", utana)
	print("EREDMENY: ", "RENDBEN" if absf(utana.x - elotte.x / 2.0) < 2.0 else "NEM HAT")
	quit()