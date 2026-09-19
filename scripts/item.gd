class_name Item
extends RefCounted
## Egy tárgy (fegyver, páncél, pajzs, bájital, tekercs) a kiszámolt értékeivel.

var name := ""
var label := ""
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
	it.name = base["name"]
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
	if rar_key == "legendary": it.label = "✦ " + it.name
	elif rar_key == "epic": it.label = "★ " + it.name
	else: it.label = it.name
	return it


static func find_base(nm: String) -> Dictionary:
	for b in Data.ITEM_BASES:
		if b["name"] == nm:
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
	if dmg > 0: s.append("⚔ Támadás +%d" % dmg)
	if slot == "weapon" and mage: s.append("✦ Varázserő +%d" % int(floorf(dmg * 0.5)))
	if reach > 0:
		if cls == "Íjász" and subtype == "bow": s.append("↔ Táv %d (+1 íjász)" % reach)
		else: s.append("↔ Táv %d" % reach)
	if lifesteal > 0.0: s.append("♥ Életlopás %d%%" % int(roundf(lifesteal * 100)))
	if def > 0: s.append("🛡 Védelem +%d" % def)
	if regen > 0: s.append("✚ Regeneráció +%d HP/kör" % regen)
	if heal > 0: s.append("♥ Gyógyít +%d" % heal)
	if max_hp_up > 0:
		s.append("♥ MaxHP +%d" % max_hp_up)
		s.append("♥ Teljes gyógyulás")
	if atk_up > 0:
		if mage: s.append("✦ Varázserő +%d örökre" % (atk_up * 2))
		else: s.append("⚡ ATK +%d örökre" % atk_up)
	if def_up > 0:
		s.append("❈ DEF +%d örökre" % (def_up + (2 if cls == "Lovag" else 0)))
	if damage > 0:
		if mage: s.append("✳ Tűz %d (+✦%d)" % [damage, mag])
		else: s.append("✳ Tűz %d" % damage)
	return s


## Rövid, egysoros összegzés (táska-sor, HUD)
func short_stats(cls: String, mag := 0) -> String:
	var s: Array[String] = []
	var mage := cls == "Mágus"
	if dmg > 0: s.append("⚔+%d" % dmg)
	if slot == "weapon" and mage: s.append("✦+%d" % int(floorf(dmg * 0.5)))
	if reach > 0: s.append("↔%d" % (reach + (1 if cls == "Íjász" and subtype == "bow" else 0)))
	if lifesteal > 0.0: s.append("Életlopás %d%%" % int(roundf(lifesteal * 100)))
	if def > 0: s.append("🛡+%d" % def)
	if regen > 0: s.append("✚+%d/kör" % regen)
	if heal > 0: s.append("+%d♥" % heal)
	if max_hp_up > 0: s.append("MaxHP +%d, teljes gyógyulás" % max_hp_up)
	if atk_up > 0: s.append(("✦+%d örökre" % (atk_up * 2)) if mage else ("⚡+%d örökre" % atk_up))
	if def_up > 0: s.append("❈+%d örökre" % (def_up + (2 if cls == "Lovag" else 0)))
	if damage > 0: s.append(("✳%d+%d" % [damage, mag]) if mage else ("✳%d" % damage))
	return "  ·  ".join(s)
