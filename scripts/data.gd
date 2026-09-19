class_name Data
extends RefCounted
## Állandók és táblázatok (a böngészős változat P, RARITY, DIFF, ITEM_BASES, MONS... táblái).

# ══════════ TÉRKÉP / JÁTÉK ══════════
const MAP_W := 80
const MAP_H := 60
const FOV_R := 8
const MAX_LEVEL := 5
const TILE := 40
const HUD_H := 96
const WALL := 0
const FLOOR := 1
const STAIR := 3

# Egyenletes siklás: tartott gombnál a lépések üteme és a siklás sebessége
const STEP_MS := 150.0
const FIRST_DELAY := 150.0
const MOVE_SPD := 1000.0 / STEP_MS * 1.1   # mező/másodperc

const MAGE_RANGE := 5

# ══════════ PALETTA ══════════
const P := {
	"parch": "#2a1e0e", "parchLt": "#3c2c18", "parchEdge": "#7a5a2a", "parchGold": "#d4a84b",
	"ink": "#c8a870", "inkDark": "#8a7050", "vein": "#d03030", "hudBg": "#140e06", "hudBorder": "#5a3a14",
	"common": "#787878", "rare": "#3070d8", "epic": "#9030d0", "legendary": "#d89000",
}

const RARITY := {
	"common": {"label": "Közönséges", "border": "#787878", "glow": "#a8a8a8", "mult": 1.0},
	"rare": {"label": "Ritka", "border": "#3070d8", "glow": "#70b0ff", "mult": 1.6},
	"epic": {"label": "Nagyon ritka", "border": "#9030d0", "glow": "#d070ff", "mult": 2.4},
	"legendary": {"label": "Legendás", "border": "#d89000", "glow": "#ffd700", "mult": 3.5},
}
const RARITY_ORDER := ["common", "rare", "epic", "legendary"]
# a bájitalok és tekercsek ereje ritkaság szerint
const TIER := {"common": 1.0, "rare": 1.3, "epic": 1.7, "legendary": 2.2}
# nagyon ritka / legendás fegyver: életlopás; páncél és pajzs: regeneráció
const LIFESTEAL := {"epic": 0.10, "legendary": 0.20}
const REGEN := {"epic": 1, "legendary": 2}

const DIFF := {
	"easy": {"label": "Könnyű", "monHp": 0.65, "monAtk": 0.65, "xpMult": 0.8},
	"normal": {"label": "Közepes", "monHp": 1.0, "monAtk": 1.0, "xpMult": 1.0},
	"hard": {"label": "Nehéz", "monHp": 1.6, "monAtk": 1.5, "xpMult": 1.3},
}
const DIFF_ORDER := ["easy", "normal", "hard"]

# ══════════ TÁRGYAK ══════════
# A pajzsoknak saját helyük van (slot "shield"), külön a páncéltól.
const ITEM_BASES := [
	{"name": "Rozsdás kard", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 4},
	{"name": "Acélkard", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 9},
	{"name": "Rúnakard", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 15},
	{"name": "Holdfénypenge", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 22},
	{"name": "Faíj", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 5, "range": 3},
	{"name": "Összetett íj", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 11, "range": 4},
	{"name": "Ezoterikus íj", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 17, "range": 5},
	{"name": "Kéziágyú", "slot": "weapon", "subtype": "cannon", "glyph": "⌐", "baseDmg": 20, "range": 3},
	{"name": "Pokoli ágyú", "slot": "weapon", "subtype": "cannon", "glyph": "⌐", "baseDmg": 30, "range": 4},
	{"name": "Fapajzs", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 3},
	{"name": "Acélpajzs", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 8},
	{"name": "Rúnapajzs", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 14},
	{"name": "Bőrpáncél", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 2},
	{"name": "Láncpáncél", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 6},
	{"name": "Sárkánypáncél", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 12},
	{"name": "Gyógyital", "slot": "use", "subtype": "heal", "glyph": "✚", "healAmt": 25},
	{"name": "Nagy gyógyital", "slot": "use", "subtype": "heal", "glyph": "✚", "healAmt": 60},
	{"name": "Életerő töltő", "slot": "use", "subtype": "maxheal", "glyph": "♥", "maxHpUp": 10},
	{"name": "Erő tekercs", "slot": "use", "subtype": "atk_up", "glyph": "⚡", "atkUp": 5},
	{"name": "Véd tekercs", "slot": "use", "subtype": "def_up", "glyph": "❈", "defUp": 3},
	{"name": "Tűzgömb", "slot": "use", "subtype": "fireball", "glyph": "✳", "damage": 40},
]

const ITEM_COL := {
	"sword": "#a0c8e0", "bow": "#d4a84b", "cannon": "#e08030", "shield": "#80a0c0", "armor": "#a07040",
	"heal": "#40c860", "maxheal": "#40c860", "fireball": "#e05010", "atk_up": "#e05050", "def_up": "#5080e0",
}

# ══════════ SZÖRNYEK ══════════
const MONS := {
	"goblin": {"name": "Goblin", "hp": 14, "atk": 4, "def": 1, "xp": 12},
	"skeleton": {"name": "Csontváz", "hp": 18, "atk": 5, "def": 2, "xp": 18},
	"orc": {"name": "Ork", "hp": 30, "atk": 7, "def": 2, "xp": 30},
	"vampire": {"name": "Vámpír", "hp": 35, "atk": 9, "def": 3, "mres": 2, "xp": 55, "sp": "lifesteal"},
	"spider": {"name": "Mérgespók", "hp": 22, "atk": 6, "def": 1, "xp": 40, "sp": "poison"},
	"golem": {"name": "Kőgolem", "hp": 70, "atk": 10, "def": 8, "xp": 80, "sp": "regen"},
	"witch": {"name": "Boszorkány", "hp": 28, "atk": 12, "def": 2, "mres": 4, "xp": 70, "sp": "fireball"},
	"assassin": {"name": "Bérgyilkos", "hp": 25, "atk": 15, "def": 2, "xp": 65, "sp": "crit"},
	"troll": {"name": "Troll", "hp": 55, "atk": 11, "def": 4, "xp": 60},
	"demon": {"name": "Démon", "hp": 80, "atk": 16, "def": 6, "mres": 4, "xp": 110, "sp": "aoe"},
	"goblin_king": {"name": "👑 Goblin Király", "hp": 120, "atk": 14, "def": 5, "xp": 300, "sp": "summon", "boss": true},
	"necromancer": {"name": "💀 Nekromanta", "hp": 160, "atk": 18, "def": 6, "mres": 5, "xp": 400, "sp": "revive", "boss": true},
	"stone_titan": {"name": "⚙ Kő Titán", "hp": 240, "atk": 20, "def": 12, "xp": 500, "sp": "regen", "boss": true},
	"shadow_lord": {"name": "🌑 Árnyak Ura", "hp": 300, "atk": 24, "def": 10, "mres": 6, "xp": 700, "sp": "teleport", "boss": true},
	"dragon": {"name": "🐉 SÁRKÁNY", "hp": 420, "atk": 32, "def": 15, "mres": 5, "xp": 1500, "sp": "aoe", "boss": true},
}
const BOSS_LVL := {1: "goblin_king", 2: "necromancer", 3: "stone_titan", 4: "shadow_lord", 5: "dragon"}
const POOL := {
	1: ["goblin", "skeleton"],
	2: ["goblin", "skeleton", "orc", "spider", "vampire"],
	3: ["orc", "troll", "golem", "witch", "spider"],
	4: ["troll", "demon", "witch", "assassin", "golem"],
	5: ["demon", "assassin", "vampire", "golem", "witch"],
}

# ══════════ KASZTOK ══════════
#   Lovag – közelharc: +35% sebzés, 20% eséllyel pajzzsal felfogja az ütés felét, sok életerő
#   Íjász – fizikai sebzés messziről: íjjal indul, +1 lőtáv, gyakori kritikus; közelről gyengébb
#   Mágus – kék varázsgömb (5 mező): varázssebzés, amely nagyrészt átüt a páncélon; kevés életerő
const CLASS_ORDER := ["Lovag", "Mágus", "Íjász"]
const CLASSES := {
	"Lovag": {"hp": 46, "atk": 9, "mag": 0, "def": 5, "col": "#70c8e8", "hpUp": 13,
		"desc": "A közelharc mestere: +35% kardsebzés, és 20% eséllyel pajzzsal felfogja az ütés felét."},
	"Mágus": {"hp": 26, "atk": 4, "mag": 11, "def": 1, "col": "#6aa8ff", "hpUp": 8,
		"desc": "Kék varázsgömböt lő 5 mezőre: varázssebzés, amely átüt a páncélon. Kevés életereje van."},
	"Íjász": {"hp": 32, "atk": 6, "mag": 0, "def": 2, "col": "#70d860", "hpUp": 10,
		"desc": "Fizikai sebzés messziről: íjjal indul, +1 lőtáv, gyakori kritikus. Közelről gyengébb."},
}
const MELEE_MULT := {"Lovag": 1.35, "Íjász": 0.7, "Mágus": 0.6}


static func rnd(a: int, b: int) -> int:
	return randi_range(a, b)


static func pick(arr: Array) -> Variant:
	return arr[randi() % arr.size()]


## JS Math.round megfelelője (fél felfelé)
static func jround(v: float) -> int:
	return int(floorf(v + 0.5))


static func rnd_seed(n: float) -> float:
	var x := sin(n * 127.1) * 43758.5
	return x - floorf(x)


static func rnd_seed_m(n: float) -> float:
	var x := sin(n * 127.1) * 43758.5453
	return x - floorf(x)
