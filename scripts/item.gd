class_name Item
extends RefCounted
## Egy tárgy (fegyver, páncél, pajzs, bájital, tekercs) a kiszámolt értékeivel.

var name := ""        # belső azonosító (Data.ITEM_BASES "id"), pl. "wooden_bow" — a mentésben is ez áll
## a megjelenített név ritkaság-jellel, a mostani nyelven ("✦ Holdfénypenge")
var label: String:
	get: return Lang.txt(ref())
var slot := ""        # weapon / armor / shield / use
var subtype := ""
var glyph := ""
var rarity := "common"
var dmg := 0
var def := 0
var heal := 0
var max_hp_up := 0
var atk_up := 0
var def_up := 0
var damage := 0
var reach := 0
var lifesteal := 0.0  # a sebzés hányada, amit a fegyver visszagyógyít
var regen := 0        # HP körönként (páncél / pajzs)


func rar() -> Dictionary:
	return Data.RARITY[rarity]


func border() -> String:
	return Data.RARITY[rarity]["border"]


func glow() -> String:
	return Data.RARITY[rarity]["glow"]


static func roll_rarity(lvl: int) -> String:
	var w := {"common": maxi(5, 60 - lvl * 8), "rare": 25 + lvl * 2, "epic": 10 + lvl * 3, "legendary": 2 + lvl * 2}
	var tot := 0
	for k in w: tot += w[k]
	var r := randf() * tot
	for k in Data.RARITY_ORDER:
		r -= w[k]
		if r <= 0.0:
			return k
	return "common"


static func make(base: Dictionary, rar_key: String, lvl: int) -> Item:
	var it := Item.new()
	var m: float = Data.RARITY[rar_key]["mult"] * (1.0 + lvl * 0.12)
	var tier: float = Data.TIER[rar_key]
	it.name = base["id"]
	it.slot = base["slot"]
	it.subtype = base["subtype"]
	it.glyph = base["glyph"]
	it.rarity = rar_key
	if base.has("baseDmg"): it.dmg = Data.jround(base["baseDmg"] * m)
	if base.has("baseDef"): it.def = Data.jround(base["baseDef"] * m)
	if base.has("healAmt"): it.heal = Data.jround(base["healAmt"] * tier)
	if base.has("maxHpUp"): it.max_hp_up = Data.jround(base["maxHpUp"] * m)
	if base.has("atkUp"): it.atk_up = Data.jround(base["atkUp"] * tier)
	if base.has("defUp"): it.def_up = Data.jround(base["defUp"] * tier)
	if base.has("damage"): it.damage = Data.jround(base["damage"] * m)
	if base.has("range"): it.reach = base["range"]
	if it.slot == "weapon" and Data.LIFESTEAL.has(rar_key):
		it.lifesteal = Data.LIFESTEAL[rar_key]
	if (it.slot == "armor" or it.slot == "shield") and Data.REGEN.has(rar_key):
		it.regen = Data.REGEN[rar_key]
	return it


## a tárgy neve később fordítandó hivatkozásként (üzenetnaplóhoz)
func ref() -> Dictionary:
	return Lang.item_ref(name, rarity)


## Alaptárgy azonosító szerint; a régi mentések magyar tárgynevét is elfogadja.
static func find_base(nm: String) -> Dictionary:
	var id := str(Data.LEGACY_ITEM_IDS.get(nm, nm))
	for b in Data.ITEM_BASES:
		if b["id"] == id:
			return b
	return {}


static func random(lvl: int) -> Item:
	return make(Data.pick(Data.ITEM_BASES), roll_rarity(lvl), lvl)


func col() -> String:
	return Data.ITEM_COL.get(subtype, "#c8b890")


## Az összes hatás, teljes szöveggel (láda-kártya). A kaszt számít (mágus: varázserő).
func stat_lines(cls: String, mag := 0) -> Array[String]:
	var s: Array[String] = []
	var mage := cls == "Mágus"
	if dmg > 0: s.append(Lang.T("st.atk", dmg))
	if slot == "weapon" and mage: s.append(Lang.T("st.mag", int(floorf(dmg * 0.5))))
	if reach > 0:
		if cls == "Íjász" and subtype == "bow": s.append(Lang.T("st.range_archer", reach))
		else: s.append(Lang.T("st.range", reach))
	if lifesteal > 0.0: s.append(Lang.T("st.steal", int(roundf(lifesteal * 100))))
	if def > 0: s.append(Lang.T("st.def", def))
	if regen > 0: s.append(Lang.T("st.regen", regen))
	if heal > 0: s.append(Lang.T("st.heal", heal))
	if max_hp_up > 0:
		s.append(Lang.T("st.maxhp", max_hp_up))
		s.append(Lang.T("st.fullheal"))
	if atk_up > 0:
		if mage: s.append(Lang.T("st.mag_perm", atk_up * 2))
		else: s.append(Lang.T("st.atk_perm", atk_up))
	if def_up > 0:
		s.append(Lang.T("st.def_perm", def_up + (2 if cls == "Lovag" else 0)))
	if damage > 0:
		if mage: s.append(Lang.T("st.fire_mage", damage, mag))
		else: s.append(Lang.T("st.fire", damage))
	return s


## Rövid, egysoros összegzés (táska-sor, HUD)
func short_stats(cls: String, mag := 0) -> String:
	var s: Array[String] = []
	var mage := cls == "Mágus"
	if dmg > 0: s.append("⚔+%d" % dmg)
	if slot == "weapon" and mage: s.append("✦+%d" % int(floorf(dmg * 0.5)))
	if reach > 0: s.append("↔%d" % (reach + (1 if cls == "Íjász" and subtype == "bow" else 0)))
	if lifesteal > 0.0: s.append(Lang.T("sh.steal", int(roundf(lifesteal * 100))))
	if def > 0: s.append("🛡+%d" % def)
	if regen > 0: s.append(Lang.T("sh.regen", regen))
	if heal > 0: s.append("+%d♥" % heal)
	if max_hp_up > 0: s.append(Lang.T("sh.maxhp", max_hp_up))
	if atk_up > 0: s.append(Lang.T("sh.mag_perm", atk_up * 2) if mage else Lang.T("sh.atk_perm", atk_up))
	if def_up > 0: s.append(Lang.T("sh.def_perm", def_up + (2 if cls == "Lovag" else 0)))
	if damage > 0: s.append(("✳%d+%d" % [damage, mag]) if mage else ("✳%d" % damage))
	return "  ·  ".join(s)
