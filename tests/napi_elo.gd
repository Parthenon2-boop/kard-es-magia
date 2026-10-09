extends SceneTree
## ÉLŐ próba a napi ranglistához (valódi hálózat és belépett fiók kell hozzá; pontszámot NEM küld be):
##   godot --headless --path . -s res://tests/napi_elo.gd
## Lekéri a mai ranglistát a játék fiókjával (lejárt belépésnél magától megújítja).

func _init() -> void:
	_fut.call_deferred()


func _fut() -> void:
	var f := Fiok.new()
	root.add_child(f)
	if not f.olvas():
		print("nincs belépett fiók (fiok.json)")
		quit(1)
		return
	f.napi_leker(Daily.nap())
	var t0 := Time.get_ticks_msec()
	while f.napi_allapot == "tolt" and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	print("nap: ", Daily.nap(), "  állapot: ", f.napi_allapot, "  sorok: ", f.napi_lista.size())
	for e in f.napi_lista:
		print("  ", e)
	quit(0 if f.napi_allapot == "kesz" else 1)