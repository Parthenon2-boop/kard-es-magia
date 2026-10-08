extends SceneTree
## ÉLŐ próba a felhő-mentéshez (nem része a run_tests-nek: valódi hálózat és belépett fiók kell hozzá).
##   godot --headless --path . -s res://tests/felho_elo.gd
## A játék fiok.json-jával (ParthLauncher) egy külön próba-"játék" alá ("_proba") feltölt egy fájlt,
## aztán úgy tesz, mintha másik gép lenne (üres mappa, üres napló): le kell jönnie; végül törli,
## és a "másik gépről" is el kell tűnnie. A játékos valódi mentéseihez nem nyúl.

const MAPPA := "user://_felho_proba/"
const NEV := "proba.json"
var hibak := 0


func ell(felt: bool, mit: String) -> void:
	print("  %s  %s" % ["OK  " if felt else "HIBA", mit])
	if not felt:
		hibak += 1


func uj_modul() -> FelhoMentes:
	var f := FelhoMentes.new()
	root.add_child(f)
	return f


func varj(f: FelhoMentes, mp := 30.0) -> void:
	var t0 := Time.get_ticks_msec()
	await process_frame
	while (f._dolgozik or not f._sor.is_empty()) and Time.get_ticks_msec() - t0 < mp * 1000.0:
		await process_frame


func _init() -> void:
	_fut.call_deferred()


func _fut() -> void:
	DirAccess.make_dir_recursive_absolute(MAPPA)
	var tartalom := "felhő-próba %d árvíztűrő tükörfúrógép" % int(Time.get_unix_time_from_system())
	var fa := FileAccess.open(MAPPA + NEV, FileAccess.WRITE)
	fa.store_string(tartalom)
	fa.close()
	# a napló ne emlékezzen korábbi próbára
	var naplo := FelhoMentes._olvas_json(FelhoMentes.NAPLO)
	naplo.erase("_proba")
	var nf := FileAccess.open(FelhoMentes.NAPLO, FileAccess.WRITE)
	nf.store_string(JSON.stringify(naplo))
	nf.close()

	print("── 1. gép: feltöltés")
	var a := uj_modul()
	a.indit("_proba", MAPPA, ["json"])
	ell(a.be_van_lepve(), "van belépett fiók (fiok.json)")
	if not a.be_van_lepve():
		quit(1)
		return
	await varj(a)
	ell(a.allapot == "kesz", "a szinkron lefutott (állapot: %s %s)" % [a.allapot, a.hiba])
	ell(a.felhoben_van(NEV), "a fájl a felhőben van")

	print("── 2. gép: üres mappa, üres napló → le kell jönnie")
	DirAccess.remove_absolute(MAPPA + NEV)
	a._naplo = {}
	a._naplo_ment()
	a.free()
	var b := uj_modul()
	var jott := [false]
	b.valtozott.connect(func() -> void: jott[0] = true)
	b.indit("_proba", MAPPA, ["json"])
	await varj(b)
	ell(FileAccess.file_exists(MAPPA + NEV), "a mentés megjelent a másik gépen")
	ell(FileAccess.get_file_as_string(MAPPA + NEV) == tartalom, "bájtra ugyanaz a tartalom")
	ell(jott[0], "a játék értesítést kapott (frissítheti a listát)")

	print("── módosítás a 2. gépen → felmegy")
	fa = FileAccess.open(MAPPA + NEV, FileAccess.WRITE)
	fa.store_string(tartalom + " v2")
	fa.close()
	b.feltolt(NEV)
	await varj(b)
	ell(b.allapot == "kesz", "a módosított mentés feltöltve (állapot: %s %s)" % [b.allapot, b.hiba])

	print("── törlés a 2. gépen → az 1. gépről is tűnjön el")
	var regi_naplo: Dictionary = b._naplo.duplicate(true)
	DirAccess.remove_absolute(MAPPA + NEV)
	b.torol(NEV)
	await varj(b)
	# az "1. gép": megvan nála a fájl, és a naplója szerint szinkronban volt
	fa = FileAccess.open(MAPPA + NEV, FileAccess.WRITE)
	fa.store_string(tartalom + " v2")
	fa.close()
	regi_naplo[NEV]["helyi"] = int(FileAccess.get_modified_time(MAPPA + NEV))
	b._naplo = regi_naplo
	b._naplo_ment()
	b.free()
	var c := uj_modul()
	c.indit("_proba", MAPPA, ["json"])
	await varj(c)
	ell(not FileAccess.file_exists(MAPPA + NEV), "a másik gépen törölt mentés itt is eltűnt")
	ell(not c.felhoben_van(NEV), "a felhőben sincs már élő példány")
	c.free()
	if FileAccess.file_exists(MAPPA + NEV):
		DirAccess.remove_absolute(MAPPA + NEV)
	DirAccess.remove_absolute(MAPPA)
	print("══ %s (%d hiba) ══" % ["RENDBEN" if hibak == 0 else "HIBÁS", hibak])
	quit(1 if hibak > 0 else 0)
