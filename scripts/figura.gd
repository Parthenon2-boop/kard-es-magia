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
## A kirajzolás előtt a pálya állítja be: a figura helye mezőben (rx + ry). Egész értéknél a figura
## áll, két mező között lép – így a lépés üteme pontosan a mozgás sebességéhez igazodik.
static var lep := 0.0
static var ido := 0.0     # a lélegzés üteme (képkocka-számláló)

## Mozgásfajták: a lebegők megdőlnek, a kúszók összehúzódnak és megnyúlnak, a gyökeresek csak ringanak;
## mindenki más lép (a test emelkedik, a két láb felváltva emelkedik el a talajtól).
const LEBEG := ["drone", "scalpel"]
const KUSZIK := ["leech", "rust_worm", "symbiote", "weaver", "spore"]
const ALL := ["bloom"]
const LAB_RESZ := 0.30    # a kép alsó ennyied része a "láb"


## A figura kirajzolása mozgással. (cx, talp): a talp közepe; w, h: a kirajzolt méret.
static func _rajz(c: Cv, t: Texture2D, cx: float, talp: float, w: float, h: float, fajta: String, mod: Color) -> void:
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var f := lep - floorf(lep)                       # 0..1 a két mező között
	var megy := f > 0.004 and f < 0.996
	var paros := int(floorf(lep)) % 2 == 0
	var hull := sin(f * PI) if megy else 0.0         # 0 -> 1 -> 0 egy mező alatt
	var leg := 1.0 + 0.012 * sin(ido * 0.055)        # lélegzés
	if fajta == "all":
		c.save(); c.translate(cx, talp); c.rotate(sin(ido * 0.04) * 0.035)
		c.tex(t, Rect2(-w / 2.0, -h * leg, w, h * leg), mod)
		c.restore()
		return
	if fajta == "lebeg":
		c.save(); c.translate(cx, talp - h * 0.5 - hull * h * 0.03); c.rotate(hull * 0.16)
		c.tex(t, Rect2(-w / 2.0, -h * 0.5, w, h), mod)
		c.restore()
		return
	if fajta == "kuszik":
		# araszolás: a mező első felében megnyúlik, a másodikban összehúzódik
		var ny := sin(f * TAU) * 0.085 if megy else 0.0
		var sw := w * (1.0 + ny)
		var sh := h * leg * (1.0 - ny * 0.8)
		c.tex(t, Rect2(cx - sw / 2.0, talp - sh, sw, sh), mod)
		return
	if not megy:
		c.tex(t, Rect2(cx - w / 2.0, talp - h * leg, w, h * leg), mod)
		return
	# LÉPÉS: a test megemelkedik és kicsit előredől, az egyik láb elemelkedik, a másik megnyúlva a talajon marad
	var emel := hull * h * 0.055
	var lab_h := h * LAB_RESZ
	var test_h := h - lab_h
	c.save()
	c.translate(cx, talp)
	c.rotate((0.5 - f) * 0.09 * (1.0 if paros else -1.0) + hull * 0.035)
	c.tex_region(t, Rect2(-w / 2.0, -lab_h - emel - test_h, w, test_h + 0.6), Rect2(0, 0, tw, th * (1.0 - LAB_RESZ)), mod)
	var bal := hull * h * 0.075 if paros else 0.0
	var jobb := 0.0 if paros else hull * h * 0.075
	var tol := (f - 0.5) * w * 0.07                  # a lépő láb előrelendül, a támasztó hátramarad
	c.tex_region(t, Rect2(-w / 2.0 + (tol if paros else -tol), -lab_h - emel, w / 2.0 + 0.5, lab_h + emel - bal),
		Rect2(0, th * (1.0 - LAB_RESZ), tw / 2.0, th * LAB_RESZ), mod)
	c.tex_region(t, Rect2((-tol if paros else tol), -lab_h - emel, w / 2.0, lab_h + emel - jobb),
		Rect2(tw / 2.0, th * (1.0 - LAB_RESZ), tw / 2.0, th * LAB_RESZ), mod)
	c.restore()


static func _fajta(alap: String) -> String:
	if alap in LEBEG: return "lebeg"
	if alap in KUSZIK: return "kuszik"
	if alap in ALL: return "all"
	return "lep"


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
	_rajz(c, t, cx, cy + sz * 0.46, w, h, _fajta(alap), c.tint)


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
	_rajz(c, t, cx, cy + size * 0.5, w, h, "lep", Color.WHITE)


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