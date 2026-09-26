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
## titkos ajtó: falnak látszik és nem járható, amíg meg nem találják (utána FLOOR lesz).
## A bejárhatóság-ellenőrzés átjárhatónak veszi, mert kutatással MINDIG kinyitható.
const SECRET := 4

# Egyenletes siklás: tartott gombnál a lépések üteme és a siklás sebessége
const STEP_MS := 150.0
const FIRST_DELAY := 150.0
const MOVE_SPD := 1000.0 / STEP_MS * 1.1   # mező/másodperc

## A katakomba akkor is él, ha te nem mozdulsz: ennyi ezredmásodpercenként eltelik egy kör,
## tehát a szörnyek közelednek és támadnak. Így nem lehet nyugodtan kivárni őket — de
## a hősnek marad ideje gondolkodni. (Ablakban, halál után és képernyőkép-módban áll az idő.)
const IDLE_MS := 1100.0
## Az első várakozó kör kicsit később jön, hogy egy pillanatnyi megtorpanás még ne számítson.
const IDLE_FIRST_MS := 1600.0

const MAGE_RANGE := 5

# ══════════ PALETTA ══════════
const P := {
	"parch": "#2a1e0e", "parchLt": "#3c2c18", "parchEdge": "#7a5a2a", "parchGold": "#d4a84b",
	"ink": "#c8a870", "inkDark": "#8a7050", "vein": "#d03030", "hudBg": "#140e06", "hudBorder": "#5a3a14",
	"common": "#787878", "rare": "#3070d8", "epic": "#9030d0", "legendary": "#d89000",
}

## A megjelenített nevek a nyelvi fájlokban vannak (rarity.<kulcs>, diff.<kulcs>, item.<id>,
## mon.<kulcs>, cls.<kaszt>, room.<kulcs>, trap.<kulcs>, shrine.<kulcs>) — lásd lang.gd.
const RARITY := {
	"common": {"border": "#787878", "glow": "#a8a8a8", "mult": 1.0},
	"rare": {"border": "#3070d8", "glow": "#70b0ff", "mult": 1.6},
	"epic": {"border": "#9030d0", "glow": "#d070ff", "mult": 2.4},
	"legendary": {"border": "#d89000", "glow": "#ffd700", "mult": 3.5},
}
const RARITY_ORDER := ["common", "rare", "epic", "legendary"]
# a bájitalok és tekercsek ereje ritkaság szerint
const TIER := {"common": 1.0, "rare": 1.3, "epic": 1.7, "legendary": 2.2}
# nagyon ritka / legendás fegyver: életlopás; páncél és pajzs: regeneráció
const LIFESTEAL := {"epic": 0.10, "legendary": 0.20}
const REGEN := {"epic": 1, "legendary": 2}

const DIFF := {
	"easy": {"monHp": 0.65, "monAtk": 0.65, "xpMult": 0.8},
	"normal": {"monHp": 1.0, "monAtk": 1.0, "xpMult": 1.0},
	"hard": {"monHp": 1.6, "monAtk": 1.5, "xpMult": 1.3},
}
const DIFF_ORDER := ["easy", "normal", "hard"]

# ══════════ TÁRGYAK ══════════
# A pajzsoknak saját helyük van (slot "shield"), külön a páncéltól.
## "id": a tárgy belső azonosítója (a mentésben is ez áll); a neve a nyelvi fájlban: item.<id>
const ITEM_BASES := [
	{"id": "rusty_sword", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 4},
	{"id": "steel_sword", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 9},
	{"id": "rune_sword", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 15},
	{"id": "moonlight_blade", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 22},
	{"id": "wooden_bow", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 5, "range": 3},
	{"id": "composite_bow", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 11, "range": 4},
	{"id": "esoteric_bow", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 17, "range": 5},
	{"id": "hand_cannon", "slot": "weapon", "subtype": "cannon", "glyph": "⌐", "baseDmg": 20, "range": 3},
	{"id": "infernal_cannon", "slot": "weapon", "subtype": "cannon", "glyph": "⌐", "baseDmg": 30, "range": 4},
	{"id": "wooden_shield", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 3},
	{"id": "steel_shield", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 8},
	{"id": "rune_shield", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 14},
	{"id": "leather_armor", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 2},
	{"id": "chain_mail", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 6},
	{"id": "dragon_armor", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 12},
	{"id": "healing_potion", "slot": "use", "subtype": "heal", "glyph": "✚", "healAmt": 25},
	{"id": "greater_healing_potion", "slot": "use", "subtype": "heal", "glyph": "✚", "healAmt": 60},
	{"id": "vitality_elixir", "slot": "use", "subtype": "maxheal", "glyph": "♥", "maxHpUp": 10},
	{"id": "scroll_strength", "slot": "use", "subtype": "atk_up", "glyph": "⚡", "atkUp": 5},
	{"id": "scroll_warding", "slot": "use", "subtype": "def_up", "glyph": "❈", "defUp": 3},
	{"id": "fireball", "slot": "use", "subtype": "fireball", "glyph": "✳", "damage": 40},
]
## Mentés-kompatibilitás: a régi (2.0-s) mentésekben a tárgyak a MAGYAR nevükkel szerepelnek.
## Betöltéskor ezekből lesz a belső azonosító (ez nem megjelenített szöveg).
const LEGACY_ITEM_IDS := {
	"Rozsdás kard": "rusty_sword", "Acélkard": "steel_sword", "Rúnakard": "rune_sword",
	"Holdfénypenge": "moonlight_blade", "Faíj": "wooden_bow", "Összetett íj": "composite_bow",
	"Ezoterikus íj": "esoteric_bow", "Kéziágyú": "hand_cannon", "Pokoli ágyú": "infernal_cannon",
	"Fapajzs": "wooden_shield", "Acélpajzs": "steel_shield", "Rúnapajzs": "rune_shield",
	"Bőrpáncél": "leather_armor", "Láncpáncél": "chain_mail", "Sárkánypáncél": "dragon_armor",
	"Gyógyital": "healing_potion", "Nagy gyógyital": "greater_healing_potion",
	"Életerő töltő": "vitality_elixir", "Erő tekercs": "scroll_strength", "Véd tekercs": "scroll_warding",
	"Tűzgömb": "fireball",
}

const ITEM_COL := {
	"sword": "#a0c8e0", "bow": "#d4a84b", "cannon": "#e08030", "shield": "#80a0c0", "armor": "#a07040",
	"heal": "#40c860", "maxheal": "#40c860", "fireball": "#e05010", "atk_up": "#e05050", "def_up": "#5080e0",
}

# ══════════ SZÖRNYEK ══════════
const MONS := {
	"goblin": {"hp": 14, "atk": 4, "def": 1, "xp": 12},
	"skeleton": {"hp": 18, "atk": 5, "def": 2, "xp": 18},
	"orc": {"hp": 30, "atk": 7, "def": 2, "xp": 30},
	"vampire": {"hp": 35, "atk": 9, "def": 3, "mres": 2, "xp": 55, "sp": "lifesteal"},
	"spider": {"hp": 22, "atk": 6, "def": 1, "xp": 40, "sp": "poison"},
	"golem": {"hp": 70, "atk": 10, "def": 8, "xp": 80, "sp": "regen"},
	"witch": {"hp": 28, "atk": 12, "def": 2, "mres": 4, "xp": 70, "sp": "fireball"},
	"assassin": {"hp": 25, "atk": 15, "def": 2, "xp": 65, "sp": "crit"},
	"troll": {"hp": 55, "atk": 11, "def": 4, "xp": 60},
	"demon": {"hp": 80, "atk": 16, "def": 6, "mres": 4, "xp": 110, "sp": "aoe"},
	"goblin_king": {"hp": 120, "atk": 14, "def": 5, "xp": 300, "sp": "summon", "boss": true},
	"necromancer": {"hp": 160, "atk": 18, "def": 6, "mres": 5, "xp": 400, "sp": "revive", "boss": true},
	"stone_titan": {"hp": 240, "atk": 20, "def": 12, "xp": 500, "sp": "regen", "boss": true},
	"shadow_lord": {"hp": 300, "atk": 24, "def": 10, "mres": 6, "xp": 700, "sp": "teleport", "boss": true},
	"dragon": {"hp": 420, "atk": 32, "def": 15, "mres": 5, "xp": 1500, "sp": "aoe", "boss": true},
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
	"Lovag": {"hp": 46, "atk": 9, "mag": 0, "def": 5, "col": "#70c8e8", "hpUp": 13},
	"Mágus": {"hp": 26, "atk": 4, "mag": 11, "def": 1, "col": "#6aa8ff", "hpUp": 8},
	"Íjász": {"hp": 32, "atk": 6, "mag": 0, "def": 2, "col": "#70d860", "hpUp": 10},
}
const MELEE_MULT := {"Lovag": 1.35, "Íjász": 0.7, "Mágus": 0.6}

# ══════════ KÜLÖNLEGES TERMEK ══════════
## A különleges termek csak a szoba tartalmát változtatják meg (láda, őr, csapda, szobor,
## kereskedő) — egyik sem tesz falat sehova, így a „mindig bejárható" biztosíték sértetlen.
const ROOM_KINDS := {
	"kincstar": {"col": "#d4a84b", "icon": "⚜"},
	"szentely": {"col": "#70d0ff", "icon": "✛"},
	"kereskedo": {"col": "#60d080", "icon": "◉"},
	"csapda": {"col": "#e05050", "icon": "⚠"},
}
const ROOM_KIND_ORDER := ["kincstar", "szentely", "kereskedo", "csapda"]
## a kincstár őre: erős, aranyban gazdag szörny
const GUARD_POOL := {1: ["orc", "skeleton"], 2: ["orc", "troll"], 3: ["troll", "golem"], 4: ["golem", "demon"], 5: ["demon", "vampire"]}

# ══════════ CSAPDÁK ══════════
## Rejtettek: rálépve sülnek el, vagy szomszédos mezőről észre lehet venni (az íjász jobban).
const TRAPS := {
	"tuske": {"col": "#c0c8d8"},
	"mereg": {"col": "#90c030"},
	"riaszto": {"col": "#e0a030"},
}
const TRAP_ORDER := ["tuske", "mereg", "riaszto"]
const TRAP_DMG_MIN := 0.08     # a max. életerő hányada
const TRAP_DMG_MAX := 0.15
const TRAP_SPOT := 0.10        # esély körönként egy szomszédos csapda észrevételére
const TRAP_SPOT_ARCHER := 0.26
const SEARCH_CHANCE := 0.75    # kutatás (K) sikere; az íjásznál biztos
const ALARM_R := 10            # a riasztó ennyi mezőn belül ébreszt

# ══════════ SZENTÉLY ══════════
const SHRINES := {
	"gyogyulas": {"col": "#50d080"},
	"elet": {"col": "#e06080"},
	"vedelem": {"col": "#5080e0"},
	"varazs": {"col": "#8cc4ff"},
}
const SHRINE_ORDER := ["gyogyulas", "elet", "vedelem", "varazs"]

# ══════════ ARANY (a szörnyekből hulló, játékon belüli pénz — nem a boltban vett érme) ══════════
const GOLD_MIN := 2
const GOLD_MAX := 7
const GOLD_BOSS := [45, 80]
## a kereskedő árai ritkaság szerint (10–60 arany között marad)
const SHOP_PRICE := {"common": 14, "rare": 24, "epic": 38, "legendary": 56}


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
