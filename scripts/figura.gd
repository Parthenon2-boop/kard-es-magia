class_name Figura
extends RefCounted
## Festett figurák: ha egy szörnyhöz / hőshöz van kép a `res://art/figurak/` mappában, a játék azt
## rajzolja ki a kódból rajzolt (alakzatokból álló) változat helyett. Kép nélkül minden marad a régi.
##
## Fájlnevek (átlátszó hátterű PNG, a figura talpa a kép alján, jobbra néz):
##   szörnyek:      <kulcs>.png           pl. rat.png, drone.png, sentinel.png
##   főellenségek:  <kulcs>.png és <kulcs>_2.png (második fázis)   pl. rust_worm.png, rust_worm_2.png
##   hősök:         hos_lovag.png, hos_magus.png, hos_ijasz.png, hos_sebesz.png
##   a Műtőterem:   nora.png, profeta.png
## A letöltött képeket a tools/figura_vag.gd vágja körbe és méretezi át ide.
##
## A hősök bolti kinézete: a festett figura a viselt TEST-darabot követi, és minden test-darabhoz
## egy teljes, összeillő öltözet tartozik (fejfedővel, lábbelivel, fegyverrel):
##   hos_<kaszt>.png (alap) és hos_<kaszt>_<test-darab>.png   pl. hos_lovag_pancel_arany.png
## A fej / láb / fegyver darabok a boltban és a kinézet-választóban a régi rajzzal látszanak.

const MAPPA := "res://art/figurak/"
## a figura magassága a szörny "méretéhez" (sz) képest; a nagyok kilógnak a mezőjükből
const MAGASSAG := {"rust_worm": 1.9, "dr_karel": 1.9, "symbiote": 2.1, "weaver": 2.2, "troll": 1.25, "demon": 1.2,
	"sentinel": 1.25, "golem": 1.2, "orc": 1.1, "assassin": 1.1, "rat": 0.72, "leech": 0.8, "scalpel": 0.8, "drone": 0.85, "spore": 0.9, "spider": 0.85}
const HOS_FAJL := {"Lovag": "hos_lovag", "Mágus": "hos_magus", "Íjász": "hos_ijasz", "Sebész": "hos_sebesz"}

static var _tar := {}


## a kulcs fájlneve ("rust_worm#2" → "rust_worm_2")
static func nev(key: String) -> String:
	return key.replace("#", "_")


static func tex(key: String) -> Texture2D:
	var n := nev(key)
	if _tar.has(n):
		return _tar[n]
	var t: Texture2D = null
	if ResourceLoader.exists(MAPPA + n + ".png"):
		t = load(MAPPA + n + ".png") as Texture2D
		# A figurák a pályán a képüknél jóval kisebbek: kicsinyített változatok (mipmap) nélkül a
		# kép szemcsés, "zajos" lenne. Ezért a betöltött képből simított kicsinyítésű textúrát készítünk.
		if t != null:
			var img := t.get_image()
			if img != null and not img.is_empty():
				if img.is_compressed():
					img.decompress()
				img.generate_mipmaps()
				t = ImageTexture.create_from_image(img)
	_tar[n] = t
	return t


static func van(key: String) -> bool:
	return tex(key) != null


## Szörny kirajzolása festett képből. (cx, cy): a mező közepe; sz: a szörny mérete; a talpa a mező aljához közel áll.
static func szorny(c: Cv, key: String, cx: float, cy: float, sz: float) -> void:
	var t := tex(key)
	if t == null:
		return
	var alap := key.get_slice("#", 0)
	var h: float = sz * 1.3 * float(MAGASSAG.get(alap, 1.0))
	var w := h * t.get_width() / float(t.get_height())
	c.tex(t, Rect2(cx - w / 2.0, cy + sz * 0.46 - h, w, h), c.tint)


## A hős képének neve: az alap, vagy (ha van hozzá kép) a viselt test-darab öltözete.
static func hos_nev(cls: String, skin: Dictionary) -> String:
	var alap := str(HOS_FAJL.get(cls, ""))
	if cls != "Sebész":
		var test := str(Skins.valasztas(skin, cls).get("test", ""))
		if test != "" and van(alap + "_" + test):
			return alap + "_" + test
	return alap


## Hős kirajzolása festett képből (size: ugyanaz a méret, mint a rajzolt hősnél).
static func hos(c: Cv, cls: String, cx: float, cy: float, size: float, skin := {}) -> void:
	var t := tex(hos_nev(cls, skin))
	if t == null:
		return
	var h := size * 1.3
	var w := h * t.get_width() / float(t.get_height())
	c.tex(t, Rect2(cx - w / 2.0, cy + size * 0.5 - h, w, h))


## Van-e festett kép ehhez a hőshöz.
static func hos_festett(cls: String, _skin: Dictionary) -> bool:
	return van(str(HOS_FAJL.get(cls, "")))


## Mellkép (Nora, Próféta): a kör alakú keretbe illesztve.
static func mellkep(c: Cv, key: String, cx: float, cy: float, sz: float) -> void:
	var t := tex(key)
	if t == null:
		return
	var h := sz * 1.25
	var w := h * t.get_width() / float(t.get_height())
	c.tex(t, Rect2(cx - w / 2.0, cy - h * 0.55, w, h))