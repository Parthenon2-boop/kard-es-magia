class_name Fiok
extends Node
## Fiók és kozmetika-bolt kiszolgáló (Supabase). A ParthLauncher írja a
## `<Godot felhasználói mappa>/fiok.json` fájlt: {url, anon, email, access_token, refresh_token, mentve}.
##
## Minden hálózati hívás ASZINKRON (HTTPRequest), így offline sem fagy le és nem omlik össze a játék:
## a hibák csak az `uzenet` mezőbe kerülnek, a játék többi része változatlanul működik.

const FAJL := "user://fiok.json"
## a ParthLauncher a Godot felhasználói mappájába ír; ha a projekt máshova tenné a user://-t,
## ez a tartalék útvonal is megpróbálkozik vele
const TARTALEK := "Godot/app_userdata/Kard és Mágia/fiok.json"

const GUMROAD := [
	{"erme": 100, "ar": "0,99 $", "url": "https://parthenon62.gumroad.com/l/iszcby"},
	{"erme": 220, "ar": "1,99 $", "url": "https://parthenon62.gumroad.com/l/zwaqr"},
	{"erme": 600, "ar": "4,99 $", "url": "https://parthenon62.gumroad.com/l/bnjaw"},
]

const HIBA_SZOVEG := {
	"keves_erme": "Nincs elég érméd — vegyél a „Érmét veszek” gombbal!",
	"mar_megvan": "Ez a darab már a tiéd.",
	"unknown_item": "Ismeretlen darab — frissítsd a játékot.",
	"not_logged_in": "Jelentkezz be a ParthLauncherben.",
}

var url := ""
var anon := ""
var email := ""
var access := ""
var refresh := ""
var betoltve := false         # van-e érvényes fiok.json
var erme := 0
var erme_ismert := false
var birtok := {}              # item_key -> true
var uzenet := ""
var uzenet_hiba := false
var folyamatban := false
var seq := 0                  # minden változásnál nő (a rajzréteg ebből tudja, hogy frissíteni kell)
## teszteléshez: ha igaz, nem indul valódi hálózati hívás
var offline_mod := false


func _valt() -> void:
	seq += 1


# ══════════ fiok.json ══════════
static func utvonalak() -> Array:
	var l := [FAJL]
	var d := OS.get_data_dir()
	if d != "":
		l.append(d.path_join(TARTALEK))
	return l


## Csendes JSON-értelmezés: sérült fájlnál/válasznál nem ír hibát a naplóba, csak null-t ad.
static func json(szoveg: String) -> Variant:
	var p := JSON.new()
	if p.parse(szoveg) != OK:
		return null
	return p.data


## A fájl tartalmának feldolgozása (tisztán, hálózat nélkül — ezt teszteli a run_tests).
static func ertelmez(szoveg: String) -> Dictionary:
	var j: Variant = json(szoveg)
	if not (j is Dictionary):
		return {}
	var d: Dictionary = j
	var u := str(d.get("url", "")).strip_edges().rstrip("/")
	var a := str(d.get("anon", "")).strip_edges()
	if u == "" or a == "":
		return {}
	return {
		"url": u, "anon": a,
		"email": str(d.get("email", "")),
		"access_token": str(d.get("access_token", "")),
		"refresh_token": str(d.get("refresh_token", "")),
		"mentve": d.get("mentve", 0),
	}


## Újraolvasás (indításkor és a bolt megnyitásakor). Igaz, ha van érvényes fiók.
func olvas() -> bool:
	betoltve = false
	for p in utvonalak():
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var d := ertelmez(f.get_as_text())
		f.close()
		if d.is_empty():
			continue
		url = d["url"]
		anon = d["anon"]
		email = d["email"]
		access = d["access_token"]
		refresh = d["refresh_token"]
		betoltve = true
		break
	if not betoltve:
		uzenet = "Jelentkezz be a ParthLauncherben"
		uzenet_hiba = false
		erme_ismert = false
	_valt()
	return betoltve


func ment_tokenek() -> void:
	var p: String = utvonalak()[0]
	for q in utvonalak():
		if FileAccess.file_exists(q):
			p = q
			break
	var d := {"url": url, "anon": anon, "email": email, "access_token": access,
		"refresh_token": refresh, "mentve": Time.get_unix_time_from_system()}
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()


# ══════════ HTTP ══════════
func _fejek(auth := true) -> PackedStringArray:
	var h := PackedStringArray(["apikey: " + anon, "Content-Type: application/json"])
	if auth and access != "":
		h.append("Authorization: Bearer " + access)
	return h


func _keres(mod: int, cim: String, fejek: PackedStringArray, test: String, kesz: Callable) -> void:
	if offline_mod:
		kesz.call(0, "")
		return
	var r := HTTPRequest.new()
	r.timeout = 8.0
	r.accept_gzip = false
	add_child(r)
	r.request_completed.connect(func(_res: int, kod: int, _h: PackedStringArray, test2: PackedByteArray) -> void:
		r.queue_free()
		kesz.call(kod, test2.get_string_from_utf8()))
	var err := r.request(cim, fejek, mod, test)
	if err != OK:
		r.queue_free()
		kesz.call(0, "")


static func _json(t: String) -> Dictionary:
	var j: Variant = json(t)
	return j if j is Dictionary else {}


## Token-frissítés; a végén meghívja a kész-visszahívást (siker igaz/hamis).
func frissit_token(kesz: Callable) -> void:
	if refresh == "":
		kesz.call(false)
		return
	_keres(HTTPClient.METHOD_POST, "%s/auth/v1/token?grant_type=refresh_token" % url,
		PackedStringArray(["apikey: " + anon, "Content-Type: application/json"]),
		JSON.stringify({"refresh_token": refresh}),
		func(kod: int, t: String) -> void:
			var d := _json(t)
			if kod == 200 and str(d.get("access_token", "")) != "":
				access = str(d["access_token"])
				if str(d.get("refresh_token", "")) != "":
					refresh = str(d["refresh_token"])
				ment_tokenek()
				kesz.call(true)
			else:
				kesz.call(false))


## GET, 401 esetén egyszeri token-frissítéssel újrapróbálva
func _get_auth(ut: String, kesz: Callable, ujra := true) -> void:
	_keres(HTTPClient.METHOD_GET, url + ut, _fejek(), "",
		func(kod: int, t: String) -> void:
			if (kod == 401 or kod == 403) and ujra:
				frissit_token(func(ok: bool) -> void:
					if ok:
						_get_auth(ut, kesz, false)
					else:
						kesz.call(kod, t))
				return
			kesz.call(kod, t))


func _post_auth(ut: String, test: String, kesz: Callable, ujra := true) -> void:
	_keres(HTTPClient.METHOD_POST, url + ut, _fejek(), test,
		func(kod: int, t: String) -> void:
			if (kod == 401 or kod == 403) and ujra:
				frissit_token(func(ok: bool) -> void:
					if ok:
						_post_auth(ut, test, kesz, false)
					else:
						kesz.call(kod, t))
				return
			kesz.call(kod, t))


# ══════════ LEKÉRDEZÉSEK ══════════
## Érme-egyenleg + a birtokolt darabok (a bolt megnyitásakor)
func frissit() -> void:
	if not betoltve:
		return
	folyamatban = true
	uzenet = "Betöltés…"
	uzenet_hiba = false
	_valt()
	_get_auth("/rest/v1/my_coins?select=coins", func(kod: int, t: String) -> void:
		folyamatban = false
		if kod == 200:
			var j: Variant = json(t)
			if j is Array and (j as Array).size() > 0 and (j as Array)[0] is Dictionary:
				erme = int((j as Array)[0].get("coins", 0))
				erme_ismert = true
			else:
				erme = 0
				erme_ismert = true
			uzenet = ""
		else:
			uzenet = "Nincs kapcsolat a kiszolgálóval."
			uzenet_hiba = true
		_valt())
	_get_auth("/rest/v1/cosmetics?select=item_key", func(kod: int, t: String) -> void:
		if kod != 200:
			return
		var j: Variant = json(t)
		if j is Array:
			birtok = {}
			for e in (j as Array):
				if e is Dictionary:
					birtok[str((e as Dictionary).get("item_key", ""))] = true
		_valt())


func birtokol(kulcs: String) -> bool:
	return birtok.has(kulcs)


## Vásárlás. A `kesz` visszahívás: (siker: bool, uzenet: String)
func vasarol(kulcs: String, kesz := Callable()) -> void:
	if not betoltve:
		uzenet = HIBA_SZOVEG["not_logged_in"]
		uzenet_hiba = true
		_valt()
		if kesz.is_valid():
			kesz.call(false, uzenet)
		return
	folyamatban = true
	uzenet = "Vásárlás…"
	uzenet_hiba = false
	_valt()
	_post_auth("/functions/v1/buy-cosmetic", JSON.stringify({"item": kulcs}), func(kod: int, t: String) -> void:
		folyamatban = false
		var d := _json(t)
		var siker := false
		if kod == 200 and bool(d.get("ok", false)):
			erme = int(d.get("coins", erme))
			erme_ismert = true
			birtok[kulcs] = true
			uzenet = "Megvetted! A darab felkerült a hősödre."
			uzenet_hiba = false
			siker = true
		elif d.has("error"):
			uzenet = str(HIBA_SZOVEG.get(str(d["error"]), "Ismeretlen hiba: " + str(d["error"])))
			uzenet_hiba = true
		elif kod == 0:
			uzenet = "Nincs internetkapcsolat — próbáld újra később."
			uzenet_hiba = true
		else:
			uzenet = "A kiszolgáló nem válaszolt (%d)." % kod
			uzenet_hiba = true
		_valt()
		if kesz.is_valid():
			kesz.call(siker, uzenet))


static func bolt_megnyit(i: int) -> void:
	if i >= 0 and i < GUMROAD.size():
		OS.shell_open(str(GUMROAD[i]["url"]))
