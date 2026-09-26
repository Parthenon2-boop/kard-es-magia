class_name Skins
extends RefCounted
## Kinézet-alkatrészek (kozmetika). A hős NÉGY helyről áll össze: fej, test, láb, fegyver.
## Minden helyen az üres kulcs ("") az alap kinézet, a többi a boltban megvásárolható darab.
##
## A kulcsokat és az árakat a kiszolgáló rögzíti: <kaszt>_<hely>_<név>,
## fegyver/test 20, fej 15, láb 10 érme. Itt ugyanez szerepel — a teszt összeveti őket.
##
## FONTOS: a kozmetika SOHA nem nyúl a játékértékekhez, csak rajzol.
##
## Rajzolás: minden darab a (0,0) körüli egységekben készül (s = méret/40), így az egész
## figura egyetlen gyorsítótárazott hálóba felvehető, és képkockánként csak eltolódik.

const SLOTS := ["fej", "test", "lab", "fegyver"]
const ARAK := {"fegyver": 20, "test": 20, "fej": 15, "lab": 10}
const CLS_KEY := {"Lovag": "lovag", "Mágus": "magus", "Íjász": "ijasz"}
const KEY_CLS := {"lovag": "Lovag", "magus": "Mágus", "ijasz": "Íjász"}
const CLS_ORDER := ["lovag", "magus", "ijasz"]

const VARIANSOK := {
	"lovag": {
		"fej": ["sisak_arany", "sisak_szarv", "csuklya"],
		"test": ["pancel_arany", "pancel_sotet", "koponyas_vert"],
		"lab": ["vaslabvert", "bor_labvert"],
		"fegyver": ["kard_lang", "kard_jeg", "csatabard"],
	},
	"magus": {
		"fej": ["kalap_csillag", "kalap_sotet", "korona"],
		"test": ["kontos_kek", "kontos_bibor", "kontos_arany"],
		"lab": ["csizma_kek", "csizma_arany"],
		"fegyver": ["bot_kristaly", "bot_koponya", "bot_fa"],
	},
	"ijasz": {
		"fej": ["csuklya_zold", "csuklya_szurke", "tollas_kalap"],
		"test": ["bor_vert", "koppeny_zold", "vadasz_mellveert"],
		"lab": ["csizma_bor", "csizma_magas"],
		"fegyver": ["ij_tiszafa", "ij_csont", "szamszerij"],
	},
}

## A darabok neve a nyelvi fájlokban: skin.<kulcs> (pl. skin.lovag_fej_sisak_arany), a helyeké slot.<hely>.

# ══════════ KATALÓGUS ══════════
static func kulcs(ck: String, slot: String, v: String) -> String:
	return "%s_%s_%s" % [ck, slot, v]


static func ar(slot: String) -> int:
	return int(ARAK.get(slot, 0))


static func nev(ck: String, slot: String, v: String) -> String:
	if v == "":
		return Lang.T("skin.default")
	var k := "skin." + kulcs(ck, slot, v)
	var s := Lang.T(k)
	return v if s == k else s


## a hely (fej / test / láb / fegyver) neve a mostani nyelven
static func hely_nev(slot: String) -> String:
	return Lang.T("slot." + slot)


static func ervenyes(ck: String, slot: String, v: String) -> bool:
	if v == "":
		return true
	var cd: Dictionary = VARIANSOK.get(ck, {})
	return v in (cd.get(slot, []) as Array)


## Teljes kínálat: [{"key", "cls", "slot", "var", "nev", "ar"}]
static func katalogus() -> Array:
	var out: Array = []
	for ck in CLS_ORDER:
		for slot in SLOTS:
			for v in (VARIANSOK[ck][slot] as Array):
				out.append({"key": kulcs(ck, slot, v), "cls": ck, "slot": slot, "var": v,
					"nev": nev(ck, slot, v), "ar": ar(slot)})
	return out


# ══════════ VÁLASZTÁS (kasztonként, user://beallitasok.cfg) ══════════
static func alap_valasztas() -> Dictionary:
	var d := {}
	for ck in CLS_ORDER:
		d[ck] = {"fej": "", "test": "", "lab": "", "fegyver": ""}
	return d


static func betolt(cf: ConfigFile) -> Dictionary:
	var d := alap_valasztas()
	for ck in CLS_ORDER:
		for slot in SLOTS:
			var v := str(cf.get_value("kinezet", "%s_%s" % [ck, slot], ""))
			if ervenyes(ck, slot, v):
				(d[ck] as Dictionary)[slot] = v
	return d


static func ment(cf: ConfigFile, sel: Dictionary) -> void:
	for ck in CLS_ORDER:
		var s: Dictionary = sel.get(ck, {})
		for slot in SLOTS:
			cf.set_value("kinezet", "%s_%s" % [ck, slot], str(s.get(slot, "")))


## a kaszt nevéből (Lovag/Mágus/Íjász) a négy hely kiválasztott darabja
static func valasztas(sel: Dictionary, cls: String) -> Dictionary:
	var ck := str(CLS_KEY.get(cls, "lovag"))
	var s: Variant = sel.get(ck)
	return s if s is Dictionary else {"fej": "", "test": "", "lab": "", "fegyver": ""}


## rövid, gyorsítótár-kulcsba illő aláírás
static func sig(sel: Dictionary, cls: String) -> String:
	var s := valasztas(sel, cls)
	return "%s.%s.%s.%s" % [s.get("fej", ""), s.get("test", ""), s.get("lab", ""), s.get("fegyver", "")]


# ══════════ SZÍNSEGÉDEK ══════════
static func vil(cc: Variant, f: float) -> Color:
	var v: Color = Cv.col(cc)
	return Color(v.r + (1.0 - v.r) * f, v.g + (1.0 - v.g) * f, v.b + (1.0 - v.b) * f, v.a)


static func sot(cc: Variant, f: float) -> Color:
	var v: Color = Cv.col(cc)
	return Color(v.r * (1.0 - f), v.g * (1.0 - f), v.b * (1.0 - f), v.a)


const RIM := Color(1.0, 0.72, 0.34, 0.5)


## fáklyafény pereme: vékony meleg vonal a megadott ponthalmaz mentén
static func rim(c: Cv, pts: Array, w: float, a := 1.0) -> void:
	c.ss(Color(RIM.r, RIM.g, RIM.b, RIM.a * a))
	c.lw(w)
	c.bp()
	c.mt(pts[0], pts[1])
	var i := 2
	while i < pts.size():
		c.lt(pts[i], pts[i + 1])
		i += 2
	c.stroke()


## puha talajárnyék (a figura lebegésétől függetlenül a földön marad)
static func talajarnyek(c: Cv, cx: float, cy: float, s: float, w := 12.0) -> void:
	c.fs(Color(0, 0, 0, 0.30))
	c.ell(cx, cy + 18.8 * s, w * s, w * 0.30 * s)
	c.fs(Color(0, 0, 0, 0.34))
	c.ell(cx, cy + 18.8 * s, w * 0.62 * s, w * 0.19 * s)


# ══════════ A HŐS ÖSSZERAKÁSA ══════════
## A (0,0) köré rajzolt teljes figura, a négy hely darabjaival.
static func hos(c: Cv, cls: String, s: float, sel: Dictionary) -> void:
	var ck := str(CLS_KEY.get(cls, "lovag"))
	var v := valasztas(sel, cls)
	match ck:
		"lovag": _lovag(c, s, v)
		"magus": _magus(c, s, v)
		_: _ijasz(c, s, v)


static func _lovag(c: Cv, s: float, v: Dictionary) -> void:
	_kopeny(c, s, "#7a1518", "#a8262a")
	resz(c, "lovag", "lab", str(v.get("lab", "")), s)
	_lovag_pajzs(c, s)
	resz(c, "lovag", "test", str(v.get("test", "")), s)
	resz(c, "lovag", "fej", str(v.get("fej", "")), s)
	resz(c, "lovag", "fegyver", str(v.get("fegyver", "")), s)


static func _magus(c: Cv, s: float, v: Dictionary) -> void:
	resz(c, "magus", "lab", str(v.get("lab", "")), s)
	resz(c, "magus", "test", str(v.get("test", "")), s)
	resz(c, "magus", "fej", str(v.get("fej", "")), s)
	resz(c, "magus", "fegyver", str(v.get("fegyver", "")), s)


static func _ijasz(c: Cv, s: float, v: Dictionary) -> void:
	_ijasz_tegez(c, s)
	resz(c, "ijasz", "lab", str(v.get("lab", "")), s)
	resz(c, "ijasz", "test", str(v.get("test", "")), s)
	resz(c, "ijasz", "fej", str(v.get("fej", "")), s)
	resz(c, "ijasz", "fegyver", str(v.get("fegyver", "")), s)


## Egyetlen darab kirajzolása a figurán belüli helyén.
static func resz(c: Cv, ck: String, slot: String, v: String, s: float) -> void:
	match ck:
		"lovag":
			match slot:
				"lab": _l_lab(c, s, v)
				"test": _l_test(c, s, v)
				"fej": _l_fej(c, s, v)
				"fegyver": _l_fegyver(c, s, v)
		"magus":
			match slot:
				"lab": _m_lab(c, s, v)
				"test": _m_test(c, s, v)
				"fej": _m_fej(c, s, v)
				"fegyver": _m_fegyver(c, s, v)
		_:
			match slot:
				"lab": _i_lab(c, s, v)
				"test": _i_test(c, s, v)
				"fej": _i_fej(c, s, v)
				"fegyver": _i_fegyver(c, s, v)


## A bolt kis előnézetéhez: a darab önmagában, a dobozba nagyítva.
const IKON_ANCHOR := {
	"fej": [0.0, -13.2, 1.35], "test": [0.0, 0.6, 1.00],
	"lab": [0.0, 12.4, 1.30], "fegyver": [11.0, -4.0, 0.80],
}
## kasztonkénti finomhangolás (a mágus kalapja és botja jóval nyúlánkabb)
const IKON_ANCHOR_CLS := {
	"magus_fej": [0.0, -16.6, 0.95],
	"magus_test": [0.0, 3.6, 0.88],
	"magus_lab": [0.0, 15.4, 1.55],
	"magus_fegyver": [9.6, -3.0, 0.62],
	"ijasz_fegyver": [10.2, -1.0, 0.88],
}


static func resz_ikon(c: Cv, ck: String, slot: String, v: String, cx: float, cy: float, meret: float) -> void:
	var a: Array = IKON_ANCHOR_CLS.get("%s_%s" % [ck, slot], IKON_ANCHOR[slot])
	var s := meret / 40.0 * float(a[2])
	c.save()
	c.translate(cx - float(a[0]) * s, cy - float(a[1]) * s)
	resz(c, ck, slot, v, s)
	c.restore()


# ══════════ KÖZÖS ELEMEK ══════════
## bőr (arc, kéz)
const BOR := "#d8ae88"


static func _arc(c: Cv, s: float, y: float, r: float) -> void:
	c.fs(sot(BOR, 0.30)); c.ell(0, y * s, r * s, r * 1.05 * s)
	c.fs(BOR); c.ell(0.5 * s, (y - 0.2) * s, (r - 0.55) * s, (r * 1.05 - 0.55) * s)
	c.fs(vil(BOR, 0.22)); c.ell(1.2 * s, (y - 1.4) * s, (r - 2.2) * s, (r - 2.6) * s)


static func _szem(c: Cv, s: float, y: float, dx: float, col: Variant) -> void:
	c.fs("#1a1410")
	c.ell(-dx * s, y * s, 1.15 * s, 1.35 * s)
	c.ell(dx * s, y * s, 1.15 * s, 1.35 * s)
	c.fs(col)
	c.ell(-dx * s + 0.25 * s, (y - 0.1) * s, 0.6 * s, 0.75 * s)
	c.ell(dx * s + 0.25 * s, (y - 0.1) * s, 0.6 * s, 0.75 * s)


## háti köpeny (a lovag mögött)
static func _kopeny(c: Cv, s: float, sotc: String, vilc: String) -> void:
	c.fs(sot(sotc, 0.32))
	c.bp(); c.mt(-7.4 * s, -7.6 * s)
	c.qt(-12.6 * s, 3.0 * s, -9.2 * s, 16.4 * s)
	c.lt(9.2 * s, 16.4 * s)
	c.qt(12.6 * s, 3.0 * s, 7.4 * s, -7.6 * s)
	c.cp(); c.fill()
	c.fs(sotc)
	c.bp(); c.mt(-6.2 * s, -7.2 * s)
	c.qt(-10.4 * s, 3.0 * s, -7.6 * s, 15.6 * s)
	c.lt(2.0 * s, 15.6 * s)
	c.qt(1.0 * s, 2.0 * s, -0.6 * s, -7.2 * s)
	c.cp(); c.fill()
	c.fs(vilc)
	c.bp(); c.mt(3.2 * s, -7.2 * s)
	c.qt(5.2 * s, 3.0 * s, 6.4 * s, 15.2 * s)
	c.lt(9.0 * s, 15.6 * s)
	c.qt(11.0 * s, 3.0 * s, 7.0 * s, -7.4 * s)
	c.cp(); c.fill()


# ══════════ LOVAG ══════════
const ACEL := "#7f8a9e"
const ARANY := "#d9ab4d"


static func _lovag_pajzs(c: Cv, s: float) -> void:
	# a bal karon hordott pajzs (mindig látszik, nem vásárolható darab)
	c.save(); c.translate(-10.6 * s, 1.2 * s); c.rotate(-0.12)
	c.fs(sot("#5b6a86", 0.42))
	c.bp(); c.mt(0, -7.6 * s); c.lt(4.6 * s, -5.6 * s); c.lt(4.2 * s, 3.4 * s)
	c.qt(2.6 * s, 7.6 * s, 0, 9.0 * s); c.qt(-2.6 * s, 7.6 * s, -4.2 * s, 3.4 * s)
	c.lt(-4.6 * s, -5.6 * s); c.cp(); c.fill()
	c.fs("#5b6a86")
	c.bp(); c.mt(0, -6.6 * s); c.lt(3.8 * s, -4.9 * s); c.lt(3.5 * s, 3.0 * s)
	c.qt(2.2 * s, 6.5 * s, 0, 7.8 * s); c.qt(-2.2 * s, 6.5 * s, -3.5 * s, 3.0 * s)
	c.lt(-3.8 * s, -4.9 * s); c.cp(); c.fill()
	c.fs(vil("#5b6a86", 0.22))
	c.poly([0, -6.6 * s, 3.8 * s, -4.9 * s, 3.5 * s, 3.0 * s, 1.4 * s, 4.6 * s, 1.4 * s, -5.8 * s])
	c.fs(ARANY)
	c.fill_rect(-3.4 * s, -1.4 * s, 6.9 * s, 1.1 * s)
	c.poly([-0.8 * s, -5.6 * s, 0.8 * s, -5.6 * s, 0.8 * s, 5.4 * s, -0.8 * s, 5.4 * s])
	rim(c, [0.2 * s, -6.5 * s, 3.8 * s, -4.8 * s, 3.5 * s, 2.8 * s], 0.7 * s)
	c.restore()


# ── LOVAG: LÁB ──
static func _l_lab(c: Cv, s: float, v: String) -> void:
	match v:
		"vaslabvert": _l_lab_vas(c, s)
		"bor_labvert": _l_lab_bor(c, s)
		_: _l_lab_alap(c, s)


static func _l_lab_alap(c: Cv, s: float) -> void:
	for d in [-1.0, 1.0]:
		var x: float = d * 3.3 * s
		c.fs(sot("#3c4352", 0.18))
		c.rrect(x - 2.5 * s, 6.0 * s, 5.0 * s, 10.6 * s, 1.6 * s); c.fill()
		c.fs("#4d5666")
		c.rrect(x - 1.5 * s, 6.0 * s, 3.9 * s, 10.6 * s, 1.5 * s); c.fill()
		c.fs(vil("#4d5666", 0.26))
		c.rrect(x + 0.6 * s, 6.4 * s, 1.5 * s, 9.6 * s, 0.7 * s); c.fill()
		# csizma
		c.fs("#241a12")
		c.rrect(x - 3.0 * s, 15.6 * s, 6.2 * s, 3.4 * s, 1.2 * s); c.fill()
		c.fs(vil("#241a12", 0.22))
		c.rrect(x - 3.0 * s, 15.6 * s, 6.2 * s, 1.1 * s, 0.6 * s); c.fill()
	rim(c, [5.4 * s, 6.6 * s, 5.4 * s, 15.4 * s], 0.65 * s, 0.8)


static func _l_lab_vas(c: Cv, s: float) -> void:
	for d in [-1.0, 1.0]:
		var x: float = d * 3.4 * s
		c.fs(sot("#454e60", 0.24))
		c.rrect(x - 2.9 * s, 5.6 * s, 5.8 * s, 11.2 * s, 1.4 * s); c.fill()
		c.fs("#5a6478")
		c.rrect(x - 1.9 * s, 5.6 * s, 4.6 * s, 11.2 * s, 1.3 * s); c.fill()
		c.fs(vil("#5a6478", 0.30))
		c.rrect(x + 0.9 * s, 6.0 * s, 1.7 * s, 10.2 * s, 0.8 * s); c.fill()
		# térdvért
		c.fs("#6d7890"); c.ell(x, 9.4 * s, 3.1 * s, 2.3 * s)
		c.fs(vil("#6d7890", 0.30)); c.ell(x + 0.5 * s, 8.8 * s, 2.0 * s, 1.2 * s)
		c.fs(sot("#6d7890", 0.45)); c.circ(x, 9.6 * s, 0.75 * s)
		# szegecsek
		c.fs("#98a4b8")
		for i in 3:
			c.circ(x - 1.1 * s, (12.4 + i * 1.5) * s, 0.42 * s)
		# vaspapucs
		c.fs("#2e3542")
		c.poly([x - 3.2 * s, 15.6 * s, x + 3.4 * s, 15.6 * s, x + 4.0 * s, 18.7 * s, x - 3.2 * s, 18.7 * s])
		c.fs(vil("#2e3542", 0.28))
		c.fill_rect(x - 3.2 * s, 15.6 * s, 6.8 * s, 0.9 * s)
	rim(c, [6.0 * s, 6.2 * s, 6.1 * s, 15.4 * s], 0.7 * s, 0.9)


static func _l_lab_bor(c: Cv, s: float) -> void:
	for d in [-1.0, 1.0]:
		var x: float = d * 3.3 * s
		c.fs("#4a3319")
		c.rrect(x - 2.6 * s, 5.8 * s, 5.2 * s, 7.4 * s, 1.5 * s); c.fill()
		c.fs(vil("#4a3319", 0.26))
		c.rrect(x + 0.2 * s, 6.2 * s, 2.0 * s, 6.6 * s, 0.9 * s); c.fill()
		# magas szárú bőrcsizma
		c.fs("#6a4922")
		c.rrect(x - 3.0 * s, 11.6 * s, 6.0 * s, 7.2 * s, 1.8 * s); c.fill()
		c.fs(vil("#6a4922", 0.24))
		c.rrect(x + 0.4 * s, 12.0 * s, 2.2 * s, 6.2 * s, 1.0 * s); c.fill()
		c.fs(sot("#6a4922", 0.40))
		c.fill_rect(x - 3.0 * s, 17.6 * s, 6.0 * s, 1.3 * s)
		# szíjak
		c.fs("#2c1c0c")
		c.fill_rect(x - 3.1 * s, 12.6 * s, 6.2 * s, 0.9 * s)
		c.fill_rect(x - 3.1 * s, 15.0 * s, 6.2 * s, 0.9 * s)
		c.fs(ARANY)
		c.fill_rect(x - 0.5 * s, 12.5 * s, 1.1 * s, 1.1 * s)
	rim(c, [5.8 * s, 12.2 * s, 5.9 * s, 17.6 * s], 0.7 * s, 0.85)


# ── LOVAG: TEST ──
static func _l_test(c: Cv, s: float, v: String) -> void:
	match v:
		"pancel_arany": _l_test_szin(c, s, "#b8862a", "#f0cf72", "#6b4a0f", ARANY)
		"pancel_sotet": _l_test_szin(c, s, "#2f3040", "#5c5e7c", "#16161f", "#c03040")
		"koponyas_vert": _l_test_kopo(c, s)
		_: _l_test_szin(c, s, ACEL, "#c2cddf", "#414a5b", ARANY)


static func _l_mell(c: Cv, s: float) -> void:
	c.bp()
	c.mt(-7.6 * s, -7.0 * s)
	c.qt(0, -9.4 * s, 7.6 * s, -7.0 * s)
	c.lt(6.4 * s, 4.4 * s)
	c.qt(0, 8.4 * s, -6.4 * s, 4.4 * s)
	c.cp()


static func _l_test_szin(c: Cv, s: float, alap: Variant, vilc: Variant, sotc: Variant, disz: Variant) -> void:
	# váll-lemezek
	for d in [-1.0, 1.0]:
		c.fs(sotc); c.ell(d * 7.9 * s, -6.0 * s, 3.5 * s, 2.9 * s, d * 0.30)
		c.fs(alap); c.ell(d * 7.9 * s, -6.4 * s, 3.1 * s, 2.5 * s, d * 0.30)
		c.fs(vil(vilc, 0.10)); c.ell(d * 8.2 * s, -7.0 * s, 2.0 * s, 1.2 * s, d * 0.30)
	# mellvért
	c.fs(sotc); _l_mell(c, s); c.fill()
	c.fs(alap)
	c.bp()
	c.mt(-6.9 * s, -6.7 * s)
	c.qt(0, -8.8 * s, 6.9 * s, -6.7 * s)
	c.lt(5.8 * s, 4.1 * s)
	c.qt(0, 7.7 * s, -5.8 * s, 4.1 * s)
	c.cp(); c.fill()
	# jobb oldali fény
	c.fs(vilc)
	c.bp()
	c.mt(1.6 * s, -7.8 * s)
	c.qt(5.0 * s, -7.8 * s, 6.9 * s, -6.7 * s)
	c.lt(5.8 * s, 4.1 * s)
	c.qt(4.2 * s, 5.9 * s, 2.4 * s, 6.6 * s)
	c.cp(); c.fill()
	# középborda
	c.ss(sot(sotc, 0.15)); c.lw(0.8 * s)
	c.line(0.4 * s, -7.4 * s, 0.4 * s, 6.4 * s)
	# nyakív + dísz
	c.fs(disz)
	c.bp(); c.mt(-4.4 * s, -7.1 * s); c.qt(0, -9.1 * s, 4.4 * s, -7.1 * s)
	c.qt(0, -7.6 * s, -4.4 * s, -7.1 * s); c.cp(); c.fill()
	c.fill_rect(-5.6 * s, 2.6 * s, 11.4 * s, 1.5 * s)
	c.fs(sot(disz, 0.35)); c.fill_rect(-1.3 * s, 2.4 * s, 2.6 * s, 2.0 * s)
	# kar
	c.fs(sot(alap, 0.22))
	c.rrect(5.6 * s, -4.6 * s, 3.3 * s, 8.0 * s, 1.5 * s); c.fill()
	c.fs(BOR); c.circ(7.4 * s, 4.2 * s, 1.7 * s)
	rim(c, [2.4 * s, -8.4 * s, 6.6 * s, -6.6 * s, 5.8 * s, 4.0 * s], 0.75 * s)


static func _l_test_kopo(c: Cv, s: float) -> void:
	_l_test_szin(c, s, "#b9b39c", "#e6e1cc", "#6a6452", "#3a3428")
	# koponya-embléma
	c.fs("#f2eede")
	c.ell(0.2 * s, -2.2 * s, 2.5 * s, 2.7 * s)
	c.fill_rect(-1.5 * s, -0.4 * s, 3.4 * s, 1.9 * s)
	c.fs("#24201a")
	c.ell(-0.9 * s, -2.6 * s, 0.85 * s, 1.0 * s)
	c.ell(1.3 * s, -2.6 * s, 0.85 * s, 1.0 * s)
	c.fill_rect(-0.2 * s, -1.2 * s, 0.7 * s, 0.9 * s)
	c.ss("#24201a"); c.lw(0.5 * s)
	c.line(-1.2 * s, 0.4 * s, -1.2 * s, 1.4 * s)
	c.line(0.2 * s, 0.4 * s, 0.2 * s, 1.4 * s)
	c.line(1.6 * s, 0.4 * s, 1.6 * s, 1.4 * s)


# ── LOVAG: FEJ ──
static func _l_fej(c: Cv, s: float, v: String) -> void:
	match v:
		"sisak_arany": _l_sisak(c, s, "#c08f2c", "#f5dd90", "#7a5410", true, false)
		"sisak_szarv": _l_sisak(c, s, "#5e6779", "#9fabc0", "#343b48", false, true)
		"csuklya": _l_csuklya(c, s)
		_: _l_sisak(c, s, "#7f8a9e", "#c2cddf", "#464f60", false, false)


static func _l_sisak(c: Cv, s: float, alap: Variant, vilc: Variant, sotc: Variant, szarny: bool, szarv: bool) -> void:
	# nyak
	c.fs("#2a2f38"); c.fill_rect(-2.6 * s, -8.6 * s, 5.2 * s, 2.6 * s)
	# sisakharang
	c.fs(sotc)
	c.bp(); c.arc(0, -13.0 * s, 6.3 * s, PI, 0); c.lt(6.3 * s, -7.0 * s); c.lt(-6.3 * s, -7.0 * s); c.cp(); c.fill()
	c.fs(alap)
	c.bp(); c.arc(0, -13.2 * s, 5.7 * s, PI, 0); c.lt(5.7 * s, -7.4 * s); c.lt(-5.7 * s, -7.4 * s); c.cp(); c.fill()
	# fénylő jobb oldal
	c.fs(vilc)
	c.bp(); c.arc(0, -13.2 * s, 5.7 * s, -PI * 0.42, 0); c.lt(5.7 * s, -7.4 * s); c.lt(2.6 * s, -7.4 * s); c.cp(); c.fill()
	# arc-rés
	c.fs("#14161c"); c.rrect(-4.2 * s, -12.4 * s, 8.4 * s, 1.9 * s, 0.7 * s); c.fill()
	c.fs(Color(1.0, 0.66, 0.3, 0.55))
	c.fill_rect(-3.4 * s, -11.9 * s, 1.5 * s, 0.7 * s)
	c.fill_rect(1.9 * s, -11.9 * s, 1.5 * s, 0.7 * s)
	# orrvéd + rácsok
	c.fs(sot(alap, 0.30)); c.fill_rect(-0.7 * s, -14.0 * s, 1.4 * s, 6.6 * s)
	c.ss(sot(alap, 0.40)); c.lw(0.55 * s)
	for i in 3:
		c.line(-4.6 * s, (-9.9 + i * 0.9) * s, 4.6 * s, (-9.9 + i * 0.9) * s)
	if szarny:
		c.fs(vil(alap, 0.18))
		for d in [-1.0, 1.0]:
			c.poly([d * 5.0 * s, -16.4 * s, d * 10.4 * s, -21.0 * s, d * 9.4 * s, -17.4 * s, d * 11.2 * s, -16.6 * s, d * 5.4 * s, -14.6 * s])
		c.fs(vilc)
		for d in [-1.0, 1.0]:
			c.poly([d * 5.2 * s, -16.2 * s, d * 9.4 * s, -19.6 * s, d * 8.4 * s, -17.2 * s, d * 5.6 * s, -15.6 * s])
	elif szarv:
		for d in [-1.0, 1.0]:
			c.ss("#e6dcbe"); c.lw(1.7 * s)
			c.bp(); c.mt(d * 4.8 * s, -15.6 * s); c.qt(d * 10.6 * s, -18.6 * s, d * 9.6 * s, -23.2 * s); c.stroke()
			c.ss(vil("#e6dcbe", 0.35)); c.lw(0.6 * s)
			c.bp(); c.mt(d * 5.0 * s, -16.2 * s); c.qt(d * 9.8 * s, -18.8 * s, d * 9.2 * s, -22.4 * s); c.stroke()
	else:
		# vörös sisakforgó
		c.fs("#7e1416")
		c.bp(); c.mt(-0.8 * s, -19.0 * s); c.qt(3.6 * s, -23.4 * s, 7.4 * s, -18.6 * s)
		c.qt(3.4 * s, -17.2 * s, -0.8 * s, -15.6 * s); c.cp(); c.fill()
		c.fs("#c62d2c")
		c.bp(); c.mt(-0.4 * s, -18.6 * s); c.qt(3.2 * s, -22.0 * s, 6.2 * s, -18.4 * s)
		c.qt(3.0 * s, -17.4 * s, -0.4 * s, -16.4 * s); c.cp(); c.fill()
		c.fs(ARANY); c.fill_rect(-1.4 * s, -19.4 * s, 2.6 * s, 1.5 * s)
	rim(c, [1.6 * s, -18.6 * s, 4.8 * s, -16.4 * s, 5.7 * s, -12.0 * s, 5.5 * s, -7.6 * s], 0.75 * s)


static func _l_csuklya(c: Cv, s: float) -> void:
	c.fs("#2a2f38"); c.fill_rect(-2.6 * s, -8.6 * s, 5.2 * s, 2.6 * s)
	c.fs("#33251a")
	c.bp(); c.arc(0, -12.8 * s, 6.6 * s, PI * 0.88, PI * 2.12); c.lt(6.2 * s, -6.2 * s)
	c.qt(0, -4.6 * s, -6.2 * s, -6.2 * s); c.cp(); c.fill()
	c.fs("#4b3826")
	c.bp(); c.arc(0, -13.0 * s, 5.9 * s, PI * 0.9, PI * 2.1); c.lt(5.4 * s, -7.0 * s)
	c.qt(0, -5.6 * s, -5.4 * s, -7.0 * s); c.cp(); c.fill()
	c.fs(vil("#4b3826", 0.24))
	c.bp(); c.arc(0, -13.0 * s, 5.9 * s, -PI * 0.45, PI * 0.10); c.lt(3.0 * s, -8.2 * s)
	c.qt(3.4 * s, -13.4 * s, 1.4 * s, -18.6 * s); c.cp(); c.fill()
	# árnyékos arc
	c.fs("#140f0b")
	c.ell(0, -11.6 * s, 4.0 * s, 4.2 * s)
	_szem(c, s, -12.0, 1.9, "#8fd4ff")
	c.fs(ARANY); c.fill_rect(-3.4 * s, -7.4 * s, 6.8 * s, 1.0 * s)
	rim(c, [1.4 * s, -18.4 * s, 4.6 * s, -15.0 * s, 5.4 * s, -8.4 * s], 0.7 * s)


# ── LOVAG: FEGYVER ──
static func _l_fegyver(c: Cv, s: float, v: String) -> void:
	match v:
		"kard_lang": _l_kard(c, s, "#e07020", "#ffd27a", "#8a2a06", true, false)
		"kard_jeg": _l_kard(c, s, "#7fc8ea", "#e6fbff", "#2b6f96", false, true)
		"csatabard": _l_bard(c, s)
		_: _l_kard(c, s, "#93a1b6", "#e4ecf6", "#4a5566", false, false)


static func _l_kard(c: Cv, s: float, penge: Variant, vilc: Variant, sotc: Variant, lang: bool, jeg: bool) -> void:
	c.save(); c.translate(7.8 * s, 3.4 * s); c.rotate(0.62)
	# markolat
	c.fs("#3a2410"); c.rrect(-0.9 * s, 0.4 * s, 1.8 * s, 4.2 * s, 0.8 * s); c.fill()
	c.fs(ARANY); c.circ(0, 5.2 * s, 1.2 * s)
	c.fs(sot(ARANY, 0.35)); c.fill_rect(-3.3 * s, -0.8 * s, 6.6 * s, 1.5 * s)
	c.fs(ARANY); c.fill_rect(-3.3 * s, -0.8 * s, 6.6 * s, 0.7 * s)
	# penge
	c.fs(sotc)
	c.poly([0, -20.6 * s, 1.5 * s, -18.0 * s, 1.5 * s, -0.8 * s, -1.5 * s, -0.8 * s, -1.5 * s, -18.0 * s])
	c.fs(penge)
	c.poly([0, -20.0 * s, 1.15 * s, -17.8 * s, 1.15 * s, -1.0 * s, -1.15 * s, -1.0 * s, -1.15 * s, -17.8 * s])
	c.fs(vilc)
	c.poly([0.15 * s, -19.6 * s, 1.0 * s, -17.6 * s, 1.0 * s, -1.2 * s, 0.25 * s, -1.2 * s])
	if lang:
		for i in 5:
			var y := -3.0 - i * 3.4
			c.fs(Color(1.0, 0.55 + i * 0.07, 0.12, 0.55 - i * 0.07))
			c.ell(0, y * s, (2.5 - i * 0.28) * s, (2.6 - i * 0.2) * s)
		c.fs(Color(1.0, 0.94, 0.7, 0.75))
		c.ell(0, -17.4 * s, 1.1 * s, 2.4 * s)
	if jeg:
		c.fs(Color(0.75, 0.94, 1.0, 0.55))
		for i in 3:
			var y2 := -5.0 - i * 4.6
			c.poly([1.0 * s, y2 * s, 3.4 * s, (y2 - 1.6) * s, 1.0 * s, (y2 - 2.6) * s])
			c.poly([-1.0 * s, (y2 - 2.2) * s, -3.2 * s, (y2 - 3.6) * s, -1.0 * s, (y2 - 4.6) * s])
	rim(c, [0.6 * s, -19.6 * s, 1.1 * s, -1.4 * s], 0.7 * s)
	c.restore()
	c.fs(BOR); c.circ(7.6 * s, 4.0 * s, 1.75 * s)


static func _l_bard(c: Cv, s: float) -> void:
	c.save(); c.translate(8.2 * s, 3.2 * s); c.rotate(0.55)
	c.fs("#4a3218"); c.rrect(-1.05 * s, -15.0 * s, 2.1 * s, 20.0 * s, 0.9 * s); c.fill()
	c.fs(vil("#4a3218", 0.26)); c.fill_rect(0.1 * s, -15.0 * s, 0.9 * s, 20.0 * s)
	c.fs("#2a1a0a")
	for i in 4:
		c.fill_rect(-1.2 * s, (0.4 + i * 1.3) * s, 2.4 * s, 0.6 * s)
	# fejsze lap
	c.fs("#495364")
	c.bp(); c.mt(0.8 * s, -14.4 * s)
	c.qt(8.4 * s, -13.0 * s, 7.0 * s, -6.4 * s)
	c.qt(4.4 * s, -7.6 * s, 0.8 * s, -7.2 * s); c.cp(); c.fill()
	c.fs("#8b97ac")
	c.bp(); c.mt(0.9 * s, -14.0 * s)
	c.qt(7.6 * s, -12.7 * s, 6.4 * s, -7.0 * s)
	c.qt(4.2 * s, -8.0 * s, 0.9 * s, -7.6 * s); c.cp(); c.fill()
	c.fs("#dfe8f4")
	c.bp(); c.mt(2.4 * s, -13.6 * s)
	c.qt(7.5 * s, -12.4 * s, 6.3 * s, -7.3 * s)
	c.qt(5.0 * s, -8.2 * s, 4.0 * s, -8.6 * s); c.cp(); c.fill()
	c.fs("#495364")
	c.bp(); c.mt(-0.8 * s, -13.8 * s)
	c.qt(-4.6 * s, -12.6 * s, -3.8 * s, -8.2 * s)
	c.qt(-2.2 * s, -8.8 * s, -0.8 * s, -8.6 * s); c.cp(); c.fill()
	c.fs(ARANY); c.fill_rect(-1.3 * s, -15.4 * s, 2.6 * s, 1.3 * s)
	rim(c, [2.2 * s, -14.0 * s, 7.4 * s, -12.0 * s, 6.4 * s, -7.2 * s], 0.75 * s)
	c.restore()
	c.fs(BOR); c.circ(7.9 * s, 4.0 * s, 1.75 * s)


# ══════════ MÁGUS ══════════
# ── MÁGUS: LÁB ──
static func _m_lab(c: Cv, s: float, v: String) -> void:
	match v:
		"csizma_kek": _m_csizma(c, s, "#25407e", "#4f77c4", ARANY)
		"csizma_arany": _m_csizma(c, s, "#8d6416", "#e5c76a", "#fff0b0")
		_: _m_csizma(c, s, "#3a2a18", "#65492a", "#8a6a3a")


static func _m_csizma(c: Cv, s: float, alap: Variant, vilc: Variant, disz: Variant = "#8a6a3a") -> void:
	for d in [-1.0, 1.0]:
		var x: float = d * 3.0 * s
		c.fs(sot(alap, 0.28))
		c.rrect(x - 2.5 * s, 12.2 * s, 5.0 * s, 6.6 * s, 1.6 * s); c.fill()
		c.fs(alap)
		c.rrect(x - 1.9 * s, 12.2 * s, 4.2 * s, 6.6 * s, 1.5 * s); c.fill()
		c.fs(vilc)
		c.rrect(x + 0.3 * s, 12.6 * s, 1.7 * s, 5.8 * s, 0.8 * s); c.fill()
		c.fs(disz)
		c.fill_rect(x - 2.5 * s, 12.2 * s, 5.0 * s, 1.0 * s)
	rim(c, [5.2 * s, 12.8 * s, 5.3 * s, 18.2 * s], 0.65 * s, 0.8)


# ── MÁGUS: TEST ──
static func _m_test(c: Cv, s: float, v: String) -> void:
	match v:
		"kontos_kek": _m_kontos(c, s, "#1d3a86", "#3f6fd0", "#0f1e4a", "#9fd0ff")
		"kontos_bibor": _m_kontos(c, s, "#6a1450", "#b23a8a", "#38062a", "#ffb0e0")
		"kontos_arany": _m_kontos(c, s, "#9a7314", "#eac74a", "#4e3706", "#fff0b0")
		_: _m_kontos(c, s, "#3a1f74", "#6a3fc0", "#1c0d3c", "#c9a6ff")


static func _m_kontos(c: Cv, s: float, alap: Variant, vilc: Variant, sotc: Variant, diszc: Variant) -> void:
	# köntös
	c.fs(sotc)
	c.bp(); c.mt(-4.2 * s, -9.2 * s)
	c.qt(-6.4 * s, 0.0, -9.6 * s, 17.4 * s)
	c.lt(9.6 * s, 17.4 * s)
	c.qt(6.4 * s, 0.0, 4.2 * s, -9.2 * s)
	c.cp(); c.fill()
	c.fs(alap)
	c.bp(); c.mt(-3.7 * s, -8.9 * s)
	c.qt(-5.8 * s, 0.0, -8.7 * s, 16.7 * s)
	c.lt(8.7 * s, 16.7 * s)
	c.qt(5.8 * s, 0.0, 3.7 * s, -8.9 * s)
	c.cp(); c.fill()
	# jobb oldali fény
	c.fs(vilc)
	c.bp(); c.mt(1.4 * s, -9.0 * s)
	c.qt(3.4 * s, 0.0, 4.6 * s, 16.7 * s)
	c.lt(8.7 * s, 16.7 * s)
	c.qt(5.8 * s, 0.0, 3.7 * s, -8.9 * s)
	c.cp(); c.fill()
	# redők
	c.ss(sot(sotc, 0.10)); c.lw(0.7 * s)
	c.bp(); c.mt(-2.0 * s, -6.0 * s); c.qt(-3.4 * s, 4.0 * s, -4.6 * s, 16.4 * s); c.stroke()
	c.bp(); c.mt(1.2 * s, -6.0 * s); c.qt(1.0 * s, 4.0 * s, 0.6 * s, 16.4 * s); c.stroke()
	# vállgallér
	c.fs(sot(alap, 0.22))
	c.bp(); c.mt(-6.6 * s, -7.6 * s); c.qt(0, -11.4 * s, 6.6 * s, -7.6 * s)
	c.qt(0, -5.2 * s, -6.6 * s, -7.6 * s); c.cp(); c.fill()
	c.fs(diszc)
	c.bp(); c.mt(-5.0 * s, -8.0 * s); c.qt(0, -10.6 * s, 5.0 * s, -8.0 * s)
	c.qt(0, -8.8 * s, -5.0 * s, -8.0 * s); c.cp(); c.fill()
	# öv
	c.fs("#3a2a12"); c.fill_rect(-5.4 * s, 2.0 * s, 10.8 * s, 1.8 * s)
	c.fs(ARANY); c.fill_rect(-1.5 * s, 1.6 * s, 3.0 * s, 2.6 * s)
	c.fs(sot(ARANY, 0.4)); c.circ(0, 2.9 * s, 0.6 * s)
	# csillagminta az alján
	c.fs(Color(Cv.col(diszc), 0.75))
	for i in 3:
		_csillag(c, (-4.6 + i * 4.4) * s, (13.2 + (i % 2) * 1.6) * s, 0.95 * s)
	# kéz
	c.fs(BOR); c.circ(6.6 * s, 3.6 * s, 1.6 * s)
	rim(c, [2.2 * s, -9.4 * s, 4.8 * s, 0.0, 7.4 * s, 12.0 * s, 8.6 * s, 16.4 * s], 0.75 * s)


static func _csillag(c: Cv, x: float, y: float, r: float) -> void:
	var pts: Array = []
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(x + cos(a) * rr)
		pts.append(y + sin(a) * rr)
	c.poly(pts)


# ── MÁGUS: FEJ ──
static func _m_fej(c: Cv, s: float, v: String) -> void:
	_arc(c, s, -12.4, 4.4)
	_szem(c, s, -12.8, 1.7, "#6ec8ff")
	# szakáll
	c.fs("#cfd4de")
	c.bp(); c.mt(-3.6 * s, -11.4 * s)
	c.qt(-3.0 * s, -4.0 * s, 0, -2.6 * s)
	c.qt(3.0 * s, -4.0 * s, 3.6 * s, -11.4 * s)
	c.qt(0, -8.6 * s, -3.6 * s, -11.4 * s); c.cp(); c.fill()
	c.fs(vil("#cfd4de", 0.35))
	c.bp(); c.mt(0.6 * s, -10.4 * s)
	c.qt(2.4 * s, -6.0 * s, 1.0 * s, -3.2 * s)
	c.qt(3.0 * s, -5.6 * s, 3.4 * s, -11.0 * s); c.cp(); c.fill()
	match v:
		"kalap_csillag": _m_kalap(c, s, "#2a4aa0", "#5a86e0", "#14275c", true, false)
		"kalap_sotet": _m_kalap(c, s, "#231a34", "#463762", "#100b1c", false, true)
		"korona": _m_korona(c, s)
		_: _m_kalap(c, s, "#3a1f74", "#6a3fc0", "#1c0d3c", false, false)


static func _m_kalap(c: Cv, s: float, alap: Variant, vilc: Variant, sotc: Variant, csillagos: bool, sotet: bool) -> void:
	# karima
	c.fs(sotc); c.ell(0, -15.4 * s, 9.2 * s, 2.2 * s)
	c.fs(alap); c.ell(0, -15.8 * s, 8.6 * s, 1.9 * s)
	c.fs(vilc); c.ell(1.2 * s, -16.4 * s, 6.0 * s, 1.0 * s)
	# kúp
	c.fs(sotc)
	c.bp(); c.mt(-6.6 * s, -15.6 * s); c.lt(6.6 * s, -15.6 * s)
	c.qt(3.4 * s, -24.4 * s, -1.6 * s, -28.6 * s); c.cp(); c.fill()
	c.fs(alap)
	c.bp(); c.mt(-5.6 * s, -16.0 * s); c.lt(5.8 * s, -16.0 * s)
	c.qt(2.8 * s, -24.0 * s, -1.6 * s, -27.8 * s); c.cp(); c.fill()
	c.fs(vilc)
	c.bp(); c.mt(1.0 * s, -16.0 * s); c.lt(5.8 * s, -16.0 * s)
	c.qt(2.8 * s, -24.0 * s, -1.6 * s, -27.8 * s)
	c.qt(1.4 * s, -22.6 * s, 1.0 * s, -16.0 * s); c.cp(); c.fill()
	# szalag
	c.fs(sot(alap, 0.45)); c.fill_rect(-6.0 * s, -17.6 * s, 12.0 * s, 1.7 * s)
	c.fs(ARANY); c.fill_rect(-1.6 * s, -18.0 * s, 3.2 * s, 2.5 * s)
	if csillagos:
		c.fs("#ffe680")
		_csillag(c, -1.0 * s, -22.6 * s, 1.5 * s)
		_csillag(c, 2.6 * s, -19.4 * s, 0.85 * s)
		_csillag(c, -4.0 * s, -18.8 * s, 0.7 * s)
	if sotet:
		c.fs(Color(0.72, 0.35, 1.0, 0.85))
		c.ell(-1.4 * s, -22.4 * s, 1.3 * s, 1.5 * s)
		c.fs(Color(0.92, 0.78, 1.0, 0.9))
		c.ell(-1.4 * s, -22.8 * s, 0.55 * s, 0.7 * s)
	rim(c, [-1.2 * s, -27.4 * s, 4.4 * s, -18.8 * s, 6.4 * s, -15.8 * s], 0.7 * s)


static func _m_korona(c: Cv, s: float) -> void:
	# hosszú haj
	c.fs("#b9bfcc")
	c.bp(); c.mt(-4.6 * s, -15.0 * s)
	c.qt(-7.0 * s, -10.0 * s, -5.6 * s, -4.4 * s)
	c.qt(-3.6 * s, -8.0 * s, -3.6 * s, -13.0 * s); c.cp(); c.fill()
	c.bp(); c.mt(4.6 * s, -15.0 * s)
	c.qt(7.0 * s, -10.0 * s, 5.6 * s, -4.4 * s)
	c.qt(3.6 * s, -8.0 * s, 3.6 * s, -13.0 * s); c.cp(); c.fill()
	c.fs("#8f9098")
	c.bp(); c.arc(0, -15.4 * s, 4.8 * s, PI, 0); c.lt(4.8 * s, -14.2 * s); c.lt(-4.8 * s, -14.2 * s); c.cp(); c.fill()
	# korona
	c.fs(sot(ARANY, 0.40))
	c.poly([-5.6 * s, -16.0 * s, 5.6 * s, -16.0 * s, 5.6 * s, -18.4 * s, 3.4 * s, -20.2 * s,
		1.9 * s, -18.0 * s, 0, -21.4 * s, -1.9 * s, -18.0 * s, -3.4 * s, -20.2 * s, -5.6 * s, -18.4 * s])
	c.fs(ARANY)
	c.poly([-5.1 * s, -16.2 * s, 5.1 * s, -16.2 * s, 5.1 * s, -18.4 * s, 3.2 * s, -19.8 * s,
		1.8 * s, -17.9 * s, 0, -20.8 * s, -1.8 * s, -17.9 * s, -3.2 * s, -19.8 * s, -5.1 * s, -18.4 * s])
	c.fs(vil(ARANY, 0.42))
	c.poly([0.6 * s, -16.4 * s, 5.1 * s, -16.4 * s, 5.1 * s, -18.4 * s, 3.2 * s, -19.6 * s, 2.0 * s, -18.0 * s, 0.6 * s, -18.4 * s])
	c.fs("#6ad0ff"); c.circ(0, -17.2 * s, 0.85 * s)
	c.fs("#ff6a8a"); c.circ(-3.2 * s, -17.0 * s, 0.6 * s)
	c.fs("#8aff9a"); c.circ(3.2 * s, -17.0 * s, 0.6 * s)
	rim(c, [0.6 * s, -20.4 * s, 4.4 * s, -18.0 * s, 4.8 * s, -15.4 * s], 0.65 * s)


# ── MÁGUS: FEGYVER ──
static func _m_fegyver(c: Cv, s: float, v: String) -> void:
	match v:
		"bot_kristaly": _m_bot(c, s, "#4a5a72", "#8fb6d8", "kristaly")
		"bot_koponya": _m_bot(c, s, "#3c3226", "#6b5b44", "koponya")
		"bot_fa": _m_bot(c, s, "#4a3418", "#7a5626", "fa")
		_: _m_bot(c, s, "#5a4020", "#8a6432", "gomb")


static func _m_bot(c: Cv, s: float, alap: Variant, vilc: Variant, fej: String) -> void:
	var x := 9.6 * s
	c.fs(sot(alap, 0.30)); c.rrect(x - 1.15 * s, -17.0 * s, 2.3 * s, 35.0 * s, 1.0 * s); c.fill()
	c.fs(alap); c.rrect(x - 0.9 * s, -17.0 * s, 1.8 * s, 35.0 * s, 0.85 * s); c.fill()
	c.fs(vilc); c.fill_rect(x + 0.15 * s, -16.6 * s, 0.65 * s, 34.2 * s)
	match fej:
		"kristaly":
			c.fs(Color(0.35, 0.80, 1.0, 0.30))
			c.circ(x, -20.6 * s, 5.2 * s)
			c.fs("#2f6f9a")
			c.poly([x, -26.4 * s, x + 2.8 * s, -21.4 * s, x, -16.8 * s, x - 2.8 * s, -21.4 * s])
			c.fs("#6fc0ea")
			c.poly([x, -25.6 * s, x + 2.1 * s, -21.4 * s, x, -17.6 * s, x - 2.1 * s, -21.4 * s])
			c.fs("#dff5ff")
			c.poly([x, -25.2 * s, x + 1.6 * s, -21.6 * s, x, -21.0 * s])
			c.fs(ARANY); c.fill_rect(x - 1.5 * s, -17.6 * s, 3.0 * s, 1.5 * s)
		"koponya":
			c.fs(Color(0.55, 1.0, 0.55, 0.26))
			c.circ(x, -20.4 * s, 5.0 * s)
			c.fs("#b6b09a"); c.ell(x, -21.0 * s, 3.1 * s, 3.4 * s)
			c.fs("#e8e2cc"); c.ell(x + 0.5 * s, -21.4 * s, 2.5 * s, 2.8 * s)
			c.fs("#efe9d4"); c.fill_rect(x - 1.9 * s, -19.0 * s, 4.0 * s, 2.0 * s)
			c.fs("#1e2a18")
			c.ell(x - 1.1 * s, -21.6 * s, 0.95 * s, 1.15 * s)
			c.ell(x + 1.4 * s, -21.6 * s, 0.95 * s, 1.15 * s)
			c.fs(Color(0.55, 1.0, 0.5, 0.95))
			c.ell(x - 1.1 * s, -21.6 * s, 0.5 * s, 0.6 * s)
			c.ell(x + 1.4 * s, -21.6 * s, 0.5 * s, 0.6 * s)
			c.ss("#1e2a18"); c.lw(0.45 * s)
			c.line(x - 0.6 * s, -18.9 * s, x - 0.6 * s, -17.2 * s)
			c.line(x + 0.8 * s, -18.9 * s, x + 0.8 * s, -17.2 * s)
		"fa":
			c.ss("#5f4220"); c.lw(1.5 * s)
			c.bp(); c.mt(x, -17.0 * s); c.qt(x - 3.6 * s, -21.0 * s, x - 1.0 * s, -24.2 * s); c.stroke()
			c.bp(); c.mt(x, -18.0 * s); c.qt(x + 4.0 * s, -21.6 * s, x + 2.2 * s, -25.0 * s); c.stroke()
			c.fs("#2f6b2c")
			for p in [[-1.6, -24.6], [2.6, -25.2], [0.4, -22.2], [-2.8, -21.4], [3.4, -22.4]]:
				c.ell(x + float(p[0]) * s, float(p[1]) * s, 1.5 * s, 0.9 * s, 0.4)
			c.fs("#57a24a")
			for p in [[-1.4, -24.9], [2.8, -25.5], [0.6, -22.5]]:
				c.ell(x + float(p[0]) * s, float(p[1]) * s, 1.0 * s, 0.55 * s, 0.4)
			c.fs("#ffd76a"); c.circ(x + 0.6 * s, -23.4 * s, 0.85 * s)
		_:
			c.fs(Color(0.45, 0.78, 1.0, 0.28))
			c.circ(x, -19.4 * s, 4.6 * s)
			c.fs("#2c5fa8"); c.circ(x, -19.4 * s, 2.6 * s)
			c.fs("#7ec4ff"); c.circ(x + 0.4 * s, -19.8 * s, 1.9 * s)
			c.fs("#e6f6ff"); c.circ(x + 0.9 * s, -20.4 * s, 0.85 * s)
			c.fs(ARANY)
			c.poly([x - 2.6 * s, -16.6 * s, x + 2.6 * s, -16.6 * s, x + 1.6 * s, -18.6 * s, x - 1.6 * s, -18.6 * s])
	rim(c, [x + 0.7 * s, -16.4 * s, x + 0.7 * s, 16.4 * s], 0.6 * s, 0.7)


# ══════════ ÍJÁSZ ══════════
static func _ijasz_tegez(c: Cv, s: float) -> void:
	c.save(); c.translate(-7.6 * s, -1.0 * s); c.rotate(0.32)
	c.fs("#3b2812"); c.rrect(-2.3 * s, -6.6 * s, 4.6 * s, 12.6 * s, 1.6 * s); c.fill()
	c.fs("#5d4020"); c.rrect(-1.7 * s, -6.6 * s, 3.4 * s, 12.6 * s, 1.4 * s); c.fill()
	c.fs(vil("#5d4020", 0.26)); c.rrect(0.1 * s, -6.2 * s, 1.2 * s, 11.6 * s, 0.6 * s); c.fill()
	c.fs("#2a1b0a"); c.fill_rect(-2.4 * s, -2.4 * s, 4.8 * s, 1.0 * s)
	for i in 3:
		var dx: float = (-1.2 + i * 1.2) * s
		c.ss("#c9b58a"); c.lw(0.55 * s)
		c.line(dx, -6.4 * s, dx, -10.4 * s)
		c.fs("#c03a30" if i % 2 == 0 else "#e8e0c8")
		c.poly([dx, -10.6 * s, dx - 0.9 * s, -9.0 * s, dx + 0.9 * s, -9.0 * s])
	c.restore()


# ── ÍJÁSZ: LÁB ──
static func _i_lab(c: Cv, s: float, v: String) -> void:
	match v:
		"csizma_bor": _i_csizma(c, s, "#6a4a24", "#996c34", "#33200c", 6.6)
		"csizma_magas": _i_csizma(c, s, "#43301a", "#6d5028", "#221508", 10.2)
		_: _i_csizma(c, s, "#3c4a2a", "#5c7040", "#20280f", 5.0)


static func _i_csizma(c: Cv, s: float, alap: Variant, vilc: Variant, sotc: Variant, magas: float) -> void:
	for d in [-1.0, 1.0]:
		var x: float = d * 3.3 * s
		# nadrág
		c.fs("#3b3524")
		c.rrect(x - 2.2 * s, 5.6 * s, 4.4 * s, 9.0 * s, 1.4 * s); c.fill()
		c.fs(vil("#3b3524", 0.22))
		c.rrect(x + 0.2 * s, 6.0 * s, 1.5 * s, 8.2 * s, 0.8 * s); c.fill()
		# csizma
		var top := 18.8 - magas
		c.fs(sotc)
		c.rrect(x - 2.7 * s, top * s, 5.4 * s, magas * s, 1.6 * s); c.fill()
		c.fs(alap)
		c.rrect(x - 2.1 * s, top * s, 4.6 * s, magas * s, 1.5 * s); c.fill()
		c.fs(vilc)
		c.rrect(x + 0.4 * s, (top + 0.4) * s, 1.6 * s, (magas - 1.2) * s, 0.8 * s); c.fill()
		c.fs(sot(alap, 0.45))
		c.fill_rect(x - 2.7 * s, 17.8 * s, 5.4 * s, 1.1 * s)
		if magas > 6.0:
			c.fs("#221508")
			c.fill_rect(x - 2.8 * s, (top + 1.4) * s, 5.6 * s, 0.8 * s)
			c.fill_rect(x - 2.8 * s, (top + magas * 0.55) * s, 5.6 * s, 0.8 * s)
			c.fs("#b9903c")
			c.fill_rect(x + 1.0 * s, (top + 1.2) * s, 1.0 * s, 1.2 * s)
	rim(c, [5.4 * s, 7.0 * s, 5.6 * s, 17.8 * s], 0.65 * s, 0.8)


# ── ÍJÁSZ: TEST ──
static func _i_test(c: Cv, s: float, v: String) -> void:
	match v:
		"bor_vert": _i_torzs(c, s, "#6b4a22", "#9d7136", "#38230c", "bor")
		"koppeny_zold": _i_torzs(c, s, "#1f5a2c", "#3f9048", "#0e2d14", "kopeny")
		"vadasz_mellveert": _i_torzs(c, s, "#4a5340", "#77836a", "#232a1d", "mellvert")
		_: _i_torzs(c, s, "#2c6030", "#4f9448", "#123016", "alap")


static func _i_torzs(c: Cv, s: float, alap: Variant, vilc: Variant, sotc: Variant, mod: String) -> void:
	if mod == "kopeny":
		c.fs(sot(alap, 0.42))
		c.bp(); c.mt(-6.6 * s, -8.0 * s)
		c.qt(-11.4 * s, 3.0 * s, -8.6 * s, 15.6 * s)
		c.lt(8.6 * s, 15.6 * s)
		c.qt(11.4 * s, 3.0 * s, 6.6 * s, -8.0 * s)
		c.cp(); c.fill()
	# törzs
	c.fs(sotc)
	c.bp(); c.mt(-6.6 * s, -7.4 * s)
	c.qt(0, -9.4 * s, 6.6 * s, -7.4 * s)
	c.lt(5.4 * s, 6.2 * s)
	c.qt(0, 8.4 * s, -5.4 * s, 6.2 * s)
	c.cp(); c.fill()
	c.fs(alap)
	c.bp(); c.mt(-5.9 * s, -7.1 * s)
	c.qt(0, -8.9 * s, 5.9 * s, -7.1 * s)
	c.lt(4.8 * s, 5.9 * s)
	c.qt(0, 7.7 * s, -4.8 * s, 5.9 * s)
	c.cp(); c.fill()
	c.fs(vilc)
	c.bp(); c.mt(1.2 * s, -8.0 * s)
	c.qt(4.2 * s, -7.8 * s, 5.9 * s, -7.1 * s)
	c.lt(4.8 * s, 5.9 * s)
	c.qt(3.2 * s, 7.0 * s, 1.8 * s, 7.2 * s)
	c.cp(); c.fill()
	match mod:
		"bor":
			c.ss(sot(sotc, 0.15)); c.lw(0.6 * s)
			for i in 3:
				c.bp(); c.mt(-5.0 * s, (-4.0 + i * 3.0) * s); c.qt(0, (-2.6 + i * 3.0) * s, 5.0 * s, (-4.0 + i * 3.0) * s); c.stroke()
			c.fs("#c9a24a")
			for i in 3:
				c.circ(-3.4 * s, (-4.4 + i * 3.0) * s, 0.45 * s)
				c.circ(3.8 * s, (-4.4 + i * 3.0) * s, 0.45 * s)
		"mellvert":
			c.fs(sot(alap, 0.30))
			c.poly([-4.6 * s, -6.0 * s, 4.6 * s, -6.0 * s, 3.8 * s, 2.6 * s, -3.8 * s, 2.6 * s])
			c.fs(vil(alap, 0.22))
			c.poly([0.4 * s, -6.0 * s, 4.6 * s, -6.0 * s, 3.8 * s, 2.6 * s, 0.4 * s, 2.6 * s])
			c.fs("#b9903c")
			c.poly([0, -5.0 * s, 1.5 * s, -3.4 * s, 0, 1.8 * s, -1.5 * s, -3.4 * s])
		"kopeny":
			c.fs(vil(alap, 0.30))
			c.bp(); c.mt(-6.2 * s, -7.8 * s); c.qt(0, -10.4 * s, 6.2 * s, -7.8 * s)
			c.qt(0, -5.0 * s, -6.2 * s, -7.8 * s); c.cp(); c.fill()
			c.fs("#c9a24a"); c.circ(-4.4 * s, -7.4 * s, 1.0 * s)
			c.circ(4.4 * s, -7.4 * s, 1.0 * s)
	# öv + tegez-szíj
	c.fs("#33240f"); c.fill_rect(-5.4 * s, 2.6 * s, 10.6 * s, 1.6 * s)
	c.fs("#b9903c"); c.fill_rect(-1.2 * s, 2.3 * s, 2.4 * s, 2.2 * s)
	c.fs("#4a3418")
	c.poly([-5.6 * s, -6.4 * s, -3.4 * s, -7.6 * s, 5.0 * s, 3.4 * s, 2.8 * s, 4.4 * s])
	# kar + kéz
	c.fs(sot(alap, 0.26))
	c.rrect(4.6 * s, -5.0 * s, 3.0 * s, 7.4 * s, 1.4 * s); c.fill()
	c.fs(BOR); c.circ(6.2 * s, 3.4 * s, 1.55 * s)
	rim(c, [1.8 * s, -8.6 * s, 5.6 * s, -6.8 * s, 4.9 * s, 5.6 * s], 0.72 * s)


# ── ÍJÁSZ: FEJ ──
static func _i_fej(c: Cv, s: float, v: String) -> void:
	match v:
		"csuklya_zold": _i_csuklya(c, s, "#1f5a2c", "#3f9048", "#0e2d14")
		"csuklya_szurke": _i_csuklya(c, s, "#3d434a", "#6e767f", "#1c2025")
		"tollas_kalap": _i_kalap(c, s)
		_: _i_csuklya(c, s, "#5c5230", "#877a45", "#2a2410")


static func _i_csuklya(c: Cv, s: float, alap: Variant, vilc: Variant, sotc: Variant) -> void:
	c.fs("#2a2f24"); c.fill_rect(-2.4 * s, -8.8 * s, 4.8 * s, 2.4 * s)
	_arc(c, s, -11.6, 4.2)
	c.fs(sotc)
	c.bp(); c.arc(0, -13.0 * s, 6.4 * s, PI * 0.86, PI * 2.14)
	c.lt(6.0 * s, -6.6 * s); c.qt(0, -4.8 * s, -6.0 * s, -6.6 * s); c.cp(); c.fill()
	c.fs(alap)
	c.bp(); c.arc(0, -13.2 * s, 5.8 * s, PI * 0.88, PI * 2.12)
	c.lt(5.3 * s, -7.2 * s); c.qt(0, -5.8 * s, -5.3 * s, -7.2 * s); c.cp(); c.fill()
	c.fs(vilc)
	c.bp(); c.arc(0, -13.2 * s, 5.8 * s, -PI * 0.46, PI * 0.06)
	c.lt(2.8 * s, -8.4 * s); c.qt(3.6 * s, -13.6 * s, 1.2 * s, -18.8 * s); c.cp(); c.fill()
	# arnyékolt arcnyílás
	c.fs(Color(0, 0, 0, 0.55))
	c.ell(0, -12.2 * s, 3.5 * s, 3.4 * s)
	_szem(c, s, -12.4, 1.75, "#9ff08a")
	# csuklyacsúcs hátra
	c.fs(sotc)
	c.poly([-4.4 * s, -15.6 * s, -9.6 * s, -9.2 * s, -5.4 * s, -10.2 * s])
	rim(c, [1.2 * s, -18.8 * s, 4.6 * s, -15.4 * s, 5.3 * s, -8.6 * s], 0.7 * s)


static func _i_kalap(c: Cv, s: float) -> void:
	c.fs("#2a2f24"); c.fill_rect(-2.4 * s, -8.8 * s, 4.8 * s, 2.4 * s)
	# haj (az arc mögött)
	c.fs("#6a4520")
	c.bp(); c.arc(0, -13.0 * s, 5.4 * s, PI * 0.90, PI * 2.10); c.lt(5.0 * s, -9.6 * s)
	c.qt(0, -11.0 * s, -5.0 * s, -9.6 * s); c.cp(); c.fill()
	c.fs("#8a5c2c")
	c.bp(); c.arc(0, -13.0 * s, 5.4 * s, -PI * 0.44, PI * 0.02); c.lt(3.0 * s, -10.2 * s)
	c.qt(3.6 * s, -14.0 * s, 1.2 * s, -18.2 * s); c.cp(); c.fill()
	_arc(c, s, -11.8, 4.1)
	_szem(c, s, -12.4, 1.75, "#9ff08a")
	# karima
	c.fs("#3b2b14"); c.ell(0, -15.0 * s, 8.4 * s, 2.0 * s)
	c.fs("#60451f"); c.ell(0, -15.4 * s, 7.8 * s, 1.7 * s)
	c.fs(vil("#60451f", 0.26)); c.ell(1.2 * s, -15.9 * s, 5.4 * s, 0.9 * s)
	# kupak
	c.fs("#3b2b14")
	c.bp(); c.mt(-4.6 * s, -15.4 * s); c.qt(0, -21.4 * s, 4.6 * s, -15.4 * s); c.cp(); c.fill()
	c.fs("#60451f")
	c.bp(); c.mt(-4.0 * s, -15.7 * s); c.qt(0, -20.6 * s, 4.0 * s, -15.7 * s); c.cp(); c.fill()
	c.fs(vil("#60451f", 0.22))
	c.bp(); c.mt(0.6 * s, -15.8 * s); c.qt(2.6 * s, -19.6 * s, 4.0 * s, -15.7 * s); c.cp(); c.fill()
	c.fs("#2a1e0c"); c.fill_rect(-4.6 * s, -16.4 * s, 9.2 * s, 1.2 * s)
	# toll
	c.fs("#1e6a3a")
	c.bp(); c.mt(3.6 * s, -16.6 * s); c.qt(8.6 * s, -21.0 * s, 10.4 * s, -25.6 * s)
	c.qt(7.4 * s, -21.6 * s, 3.0 * s, -18.0 * s); c.cp(); c.fill()
	c.fs("#3fa05a")
	c.bp(); c.mt(4.0 * s, -17.2 * s); c.qt(8.4 * s, -21.2 * s, 10.0 * s, -25.0 * s)
	c.qt(8.2 * s, -20.8 * s, 4.4 * s, -18.2 * s); c.cp(); c.fill()
	rim(c, [0.6 * s, -20.2 * s, 4.0 * s, -16.6 * s, 7.4 * s, -15.2 * s], 0.7 * s)


# ── ÍJÁSZ: FEGYVER ──
static func _i_fegyver(c: Cv, s: float, v: String) -> void:
	match v:
		"ij_tiszafa": _i_ij(c, s, "#7a4f1c", "#b8863a", "#3f2709")
		"ij_csont": _i_ij(c, s, "#cbc4ac", "#f2ecd8", "#7d7561")
		"szamszerij": _i_szamszerij(c, s)
		_: _i_ij(c, s, "#5f451f", "#8b6a32", "#301e08")


static func _i_ij(c: Cv, s: float, alap: Variant, vilc: Variant, sotc: Variant) -> void:
	# Az íj ívét a MARKOLAT helyéhez igazítjuk: a húr a kéznél van, nem a test mellett lebeg.
	var r := 9.4 * s
	var gx := 8.1 * s                      # a markoló kéz helye (a test előtt)
	var cyp := -1.0 * s
	var cxp := gx - r * cos(PI * 0.44)     # így az ív húrja pont a kézhez kerül
	# alkar a vállból a markolatig, hogy látszódjon: a hős fogja az íjat
	c.ss(BOR); c.lw(2.2 * s)
	c.bp(); c.mt(3.6 * s, -3.0 * s); c.qt(5.6 * s, -1.6 * s, gx, cyp + 0.4 * s); c.stroke()
	c.ss(sotc); c.lw(2.3 * s)
	c.bp(); c.arc(cxp, cyp, r, -PI * 0.44, PI * 0.44); c.stroke()
	c.ss(alap); c.lw(1.5 * s)
	c.bp(); c.arc(cxp, cyp, r, -PI * 0.44, PI * 0.44); c.stroke()
	c.ss(vilc); c.lw(0.55 * s)
	c.bp(); c.arc(cxp, cyp + 0.5 * s, r - 0.55 * s, -PI * 0.40, PI * 0.40); c.stroke()
	var ex := cxp + r * cos(PI * 0.44)
	var ey := cyp + r * sin(PI * 0.44)
	var ey2 := cyp - (ey - cyp)
	c.ss("#e6dfc8"); c.lw(0.6 * s)
	c.line(ex, ey2, ex, ey)
	c.fs(ARANY)
	c.circ(ex, ey, 0.75 * s)
	c.circ(ex, ey2, 0.75 * s)
	# markolat: az ív közepén, a kéz alatt
	c.fs(sotc); c.rrect(ex - 1.2 * s, cyp - 2.6 * s, 2.4 * s, 5.2 * s, 0.9 * s); c.fill()
	c.fs("#3a2a12"); c.rrect(ex - 0.9 * s, cyp - 2.2 * s, 1.8 * s, 4.4 * s, 0.8 * s); c.fill()
	# nyíl: a markolattól előre
	c.ss("#c9b58a"); c.lw(0.65 * s)
	c.line(ex - 2.6 * s, cyp, ex + 7.4 * s, cyp)
	c.fs("#e8eef6")
	c.poly([ex + 8.6 * s, cyp, ex + 6.8 * s, cyp - 1.1 * s, ex + 6.8 * s, cyp + 1.1 * s])
	# a markoló kéz a fogantyún
	c.fs(BOR); c.circ(ex, cyp + 0.4 * s, 1.7 * s)
	c.fs(sot(BOR, 0.18)); c.circ(ex + 0.5 * s, cyp + 1.1 * s, 0.9 * s)
	rim(c, [cxp + r * cos(-PI * 0.30) - 0.6 * s, cyp + r * sin(-PI * 0.30), cxp + r - 0.6 * s, cyp,
		cxp + r * cos(PI * 0.30) - 0.6 * s, cyp + r * sin(PI * 0.30)], 0.6 * s)


static func _i_szamszerij(c: Cv, s: float) -> void:
	c.save(); c.translate(5.2 * s, 1.0 * s); c.scale(1.28, 1.28)
	# ágy
	c.fs("#33210c")
	c.poly([-3.0 * s, -0.9 * s, 11.0 * s, -0.9 * s, 11.0 * s, 1.1 * s, -3.0 * s, 1.1 * s])
	c.fs("#5d3e17")
	c.poly([-2.6 * s, -0.6 * s, 10.6 * s, -0.6 * s, 10.6 * s, 0.8 * s, -2.6 * s, 0.8 * s])
	c.fs(vil("#5d3e17", 0.25))
	c.fill_rect(-2.6 * s, -0.6 * s, 13.2 * s, 0.45 * s)
	# kar
	c.ss("#2c3440"); c.lw(1.9 * s)
	c.bp(); c.mt(6.0 * s, -6.6 * s); c.qt(9.4 * s, 0.0, 6.0 * s, 6.6 * s); c.stroke()
	c.ss("#6c7a8e"); c.lw(1.0 * s)
	c.bp(); c.mt(6.0 * s, -6.4 * s); c.qt(9.0 * s, 0.0, 6.0 * s, 6.4 * s); c.stroke()
	# ideg
	c.ss("#d8d2bc"); c.lw(0.5 * s)
	c.bp(); c.mt(6.2 * s, -6.4 * s); c.lt(1.6 * s, 0.0); c.lt(6.2 * s, 6.4 * s); c.stroke()
	# vessző
	c.ss("#c9b58a"); c.lw(0.6 * s)
	c.line(1.8 * s, 0.0, 9.0 * s, 0.0)
	c.fs("#e8eef6")
	c.poly([10.2 * s, 0.0, 8.6 * s, -1.0 * s, 8.6 * s, 1.0 * s])
	# ravasz + agy
	c.fs("#33210c")
	c.poly([-3.0 * s, 0.6 * s, 0.4 * s, 0.6 * s, -0.6 * s, 4.6 * s, -3.8 * s, 4.0 * s])
	c.fs(ARANY); c.fill_rect(1.2 * s, 0.9 * s, 1.2 * s, 1.8 * s)
	c.fs(BOR); c.circ(0.2 * s, 2.4 * s, 1.55 * s)
	rim(c, [6.2 * s, -6.2 * s, 8.8 * s, 0.0, 6.2 * s, 6.2 * s], 0.6 * s)
	c.restore()
