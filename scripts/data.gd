class_name Data
extends RefCounted
## Állandók és táblázatok (a böngészős változat P, RARITY, DIFF, ITEM_BASES, MONS... táblái).

# ══════════ TÉRKÉP / JÁTÉK ══════════
const MAP_W := 80
const MAP_H := 60
const FOV_R := 8
const MAX_LEVEL := 4
## Zónánként ennyi emelet van (összesen 15 pálya); a zóna ura mindig a zóna utolsó emeletén vár.
const EMELET_DB := {1: 4, 2: 4, 3: 4, 4: 3}

# ══════════ A 15 PÁLYA NEHÉZSÉGE (méréssel hangolva: tests/egyensuly.gd) ══════════
## A hős pályáról pályára erősödik (szintlépés, képességek, zsákmány, tekercsek) — a mérés szerint
## az első emelet végére a támadása a kezdeti többszöröse. A közönséges szörnyek (és az őrök,
## a Fertőzöttek, a mini-bossok) ezért a PÁLYA SORSZÁMA szerint erősödnek, a kaland elejétől
## számolva (1..15), nem zónánként újrakezdve:
##  PALYA_HP:  ennyiszeres az életerejük (a hős sebzésével tart lépést),
##  PALYA_ATK: ennyivel NAGYOBB a támadásuk. Hozzáadódik, nem szorzódik: a hős védelme is
##             összeadódó, így a szörnyfajták közti különbség megmarad (az Orgyilkos nem lesz
##             a többinél sokszorta veszélyesebb, a Gőzpatkány pedig ártalmatlan),
##  PALYA_CSAPAS: ennyivel nagyobb a jelzett csapások (padlórács, mini-boss, pályaelemek,
##             rejtvény) sebzése — ezekből a hős védelmének harmada vonódik le.
## A zónák urai nem ebből kapják az erejüket: az övék a MONS táblában és a BOSS_CSAPAS-ban áll.
const PALYA_HP := [1.0, 4.0, 7.0, 10.0, 10.5, 11.5, 12.3, 13.0, 13.5, 14.5, 15.3, 16.0, 9.8, 10.3, 10.8]
const PALYA_ATK := [0, 18, 34, 48, 57, 66, 74, 81, 98, 104, 110, 116, 132, 139, 144]
const PALYA_CSAPAS := [0, 6, 11, 15, 18, 20, 22, 23, 26, 28, 30, 32, 35, 37, 38]
## a nehézség (könnyű / nehéz) a PALYA_ATK-ra csak ennyire hat (a kivonásos védelem miatt a teljes
## szorzó a könnyűt veszélytelenné, a nehezet játszhatatlanná tenné)
const NEHEZSEG_PALYA := 0.25
## a mini-boss a pálya támadás-többletét ennyiszeresen kapja
const MINI_PALYA_ATK := 1.15
## a "crit" képességű szörnyek (Orgyilkos, Őrautomata) védelmet megkerülő többletütése: a támadásuk ekkora része
const SZORNY_KRIT := 0.4
## a Boszorkány tűzgömbje és a Démon robbanása (védelmet megkerülő varázslat) pályánként erősödik:
## a szorzója 1 + PALYA_ATK / SZORNY_VARAZS
const SZORNY_VARAZS := 40.0


## A pálya sorszáma a kaland elejétől (1..15): az előző zónák emeletei + ez az emelet.
static func palya_sorszam(zona: int, emelet: int) -> int:
	var s := 0
	for z in range(1, zona):
		s += emeletek(z)
	return clampi(s + maxi(1, emelet), 1, PALYA_HP.size())


static func palya_hp(s: int) -> float:
	return float(PALYA_HP[clampi(s, 1, PALYA_HP.size()) - 1])


static func palya_atk(s: int) -> int:
	return int(PALYA_ATK[clampi(s, 1, PALYA_ATK.size()) - 1])


static func varazs_szorzo(s: int) -> float:
	return 1.0 + palya_atk(s) / SZORNY_VARAZS


static func palya_csapas(s: int) -> int:
	return int(PALYA_CSAPAS[clampi(s, 1, PALYA_CSAPAS.size()) - 1])


static func emeletek(zona: int) -> int:
	return int(EMELET_DB.get(zona, 1))


static func palyak() -> int:
	var db := 0
	for z in EMELET_DB:
		db += int(EMELET_DB[z])
	return db
const TILE := 48
const HUD_H := 112
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
## A fegyverek sebzése, a páncélok és pajzsok védelme és a két tekercs (Erő, Véd) ereje a 15 pályás
## kalandhoz van mérve: a 4 pályás játék számaival a hős a sokszorosára nőtt a szörnyeknek (a mérés
## szerint az első zóna végére támadás 160+, védelem 110+, miközben a zóna ura 13-at ütött).
## A ritkaság szorzói és a szintenkénti +12% változatlanok.
## "id": a tárgy belső azonosítója (a mentésben is ez áll); a neve a nyelvi fájlban: item.<id>
const ITEM_BASES := [
	{"id": "rusty_sword", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 3},
	{"id": "steel_sword", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 5},
	{"id": "rune_sword", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 7},
	{"id": "moonlight_blade", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 10},
	{"id": "chain_scalpel", "slot": "weapon", "subtype": "sword", "glyph": "†", "baseDmg": 6},
	{"id": "wooden_bow", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 4, "range": 3},
	{"id": "composite_bow", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 6, "range": 4},
	{"id": "esoteric_bow", "slot": "weapon", "subtype": "bow", "glyph": ")", "baseDmg": 8, "range": 5},
	{"id": "hand_cannon", "slot": "weapon", "subtype": "cannon", "glyph": "⌐", "baseDmg": 8, "range": 3},
	{"id": "infernal_cannon", "slot": "weapon", "subtype": "cannon", "glyph": "⌐", "baseDmg": 12, "range": 4},
	{"id": "steam_carbine", "slot": "weapon", "subtype": "cannon", "glyph": "⌐", "baseDmg": 10, "range": 4},
	{"id": "wooden_shield", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 2},
	{"id": "steel_shield", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 4},
	{"id": "rune_shield", "slot": "shield", "subtype": "shield", "glyph": "⛨", "baseDef": 6},
	{"id": "leather_armor", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 2},
	{"id": "chain_mail", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 3},
	{"id": "dragon_armor", "slot": "armor", "subtype": "armor", "glyph": "▪", "baseDef": 5},
	{"id": "healing_potion", "slot": "use", "subtype": "heal", "glyph": "✚", "healAmt": 25},
	{"id": "greater_healing_potion", "slot": "use", "subtype": "heal", "glyph": "✚", "healAmt": 60},
	{"id": "vitality_elixir", "slot": "use", "subtype": "maxheal", "glyph": "♥", "maxHpUp": 10},
	{"id": "scroll_strength", "slot": "use", "subtype": "atk_up", "glyph": "⚡", "atkUp": 2},
	{"id": "scroll_warding", "slot": "use", "subtype": "def_up", "glyph": "❈", "defUp": 1},
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
	"golem": {"hp": 70, "atk": 10, "def": 8, "xp": 80, "sp": "regen", "mech": true},
	"witch": {"hp": 28, "atk": 12, "def": 2, "mres": 4, "xp": 70, "sp": "fireball"},
	"assassin": {"hp": 25, "atk": 15, "def": 2, "xp": 65, "sp": "crit"},
	"troll": {"hp": 55, "atk": 11, "def": 4, "xp": 60},
	"demon": {"hp": 80, "atk": 16, "def": 6, "mres": 4, "xp": 110, "sp": "aoe"},
	# ── Gorgona saját lényei ──
	"rat": {"hp": 10, "atk": 4, "def": 0, "xp": 9, "sp": "swift"},
	"nurse": {"hp": 26, "atk": 7, "def": 3, "xp": 34, "sp": "mend", "mech": true},
	"scalpel": {"hp": 14, "atk": 10, "def": 0, "mres": 3, "xp": 38, "sp": "swift", "mech": true},
	"spore": {"hp": 20, "atk": 5, "def": 1, "xp": 42, "sp": "burst"},
	"leech": {"hp": 16, "atk": 5, "def": 1, "xp": 16, "sp": "lifesteal"},                       # Csőpióca: vért szív
	"drone": {"hp": 18, "atk": 8, "def": 2, "mres": 2, "xp": 36, "sp": "ranged", "mech": true},  # Szerelődrón: messziről lő
	"bloom": {"hp": 30, "atk": 9, "def": 2, "xp": 48, "sp": "spit"},                             # Húsvirág: helyből mérget köp
	"sentinel": {"hp": 85, "atk": 14, "def": 9, "xp": 95, "sp": "crit", "mech": true},           # Őrautomata: lassú, de kemény
	# ── a négy zóna ura (a fázisokat lásd game.gd: boss_turn) ──
	# (az életerejük és a támadásuk a 15 pályás kalandhoz van mérve: a hős addigra sokszorosan erősebb)
	"rust_worm": {"hp": 1200, "atk": 68, "def": 8, "xp": 300, "sp": "worm", "boss": true, "mech": true},
	"dr_karel": {"hp": 2550, "atk": 255, "def": 6, "mres": 5, "xp": 420, "sp": "karel", "boss": true, "mech": true},
	"symbiote": {"hp": 3100, "atk": 345, "def": 9, "mres": 4, "xp": 560, "sp": "symbiote", "boss": true},
	"weaver": {"hp": 5400, "atk": 210, "def": 12, "mres": 6, "xp": 1500, "sp": "weaver", "boss": true, "mech": true},
}
## A zónák urainak különleges csapásai (lásd game.gd: boss_turn). A jelzett csapásokból (gőz, penge,
## gyökér) a hős védelmének harmada levonódik; a sav, a vérszívás és a gyógyulás körönkénti, teljes érték.
##  worm: gőzsugár, savtócsa · karel: szikék, vérszívás (a doktor a dupláját gyógyul) ·
##  symbiote: gyökerek, 2. fázisbeli gyógyulás körönként · weaver: a három csapás, és a
##  Tükör-fázisban a hős támadásának / varázserejének ekkora részével üt ("tukor")
const BOSS_CSAPAS := {
	"worm": {"goz": 46, "sav": 12},
	"karel": {"penge": 60, "szivas": 28},
	"symbiote": {"gyoker": 105, "gyogyul": 40},
	"weaver": {"goz": 125, "penge": 125, "gyoker": 115, "tukor": 0.75},
}


static func boss_csapas(sp: String, mi: String) -> float:
	return float((BOSS_CSAPAS.get(sp, {}) as Dictionary).get(mi, 0))
const BOSS_LVL := {1: "rust_worm", 2: "dr_karel", 3: "symbiote", 4: "weaver"}
const POOL := {
	1: ["rat", "rat", "goblin", "skeleton", "leech", "leech"],
	2: ["nurse", "scalpel", "skeleton", "orc", "vampire", "drone", "assassin"],
	3: ["spore", "spore", "spider", "troll", "witch", "bloom", "bloom", "leech"],
	4: ["demon", "sentinel", "golem", "witch", "drone", "sentinel", "assassin"],
}
## a szint "különleges" szörnyei (ritkábban, a szokásos csapat mellé)
const RARE_POOL := {1: ["spider", "orc"], 2: ["golem", "spider"], 3: ["vampire", "golem"], 4: ["scalpel", "nurse", "vampire", "troll"]}
## Minden példány kicsit más: méret (szorzó) és árnyalat (a színekre szorzott tónus) a szörny magjából.
const VAR_MERET := [0.90, 0.97, 1.04, 1.12]
const VAR_TONUS := [Color(1, 1, 1), Color(1.0, 0.90, 0.78), Color(0.84, 0.94, 1.0), Color(0.86, 1.0, 0.80), Color(1.0, 0.84, 0.86)]
## Szörnyhangok fajtánként (audio.gd): "gep" kattogás / szervó, "hus" nedves cuppanás / hörgés,
## "lebego" zümmögés, "kuszo" surrogás. Csak a LÁTHATÓ, közeli, éppen mozduló szörny szól,
## távolsággal halkulva, és körönként legfeljebb SZORNYHANG_MAX darab (ne legyen hangzavar).
const MON_HANG := {
	"goblin": "hus", "orc": "hus", "troll": "hus", "vampire": "hus", "demon": "hus", "witch": "hus", "assassin": "hus",
	"skeleton": "gep", "golem": "gep", "nurse": "gep", "sentinel": "gep", "dr_karel": "gep", "weaver": "gep",
	"scalpel": "lebego", "drone": "lebego", "spore": "lebego",
	"rat": "kuszo", "spider": "kuszo", "leech": "kuszo", "bloom": "kuszo", "rust_worm": "kuszo", "symbiote": "kuszo",
}
const SZORNYHANG_MAX := 2
const SZORNYHANG_TAV := 7        # ennél távolabbi szörny már nem hallatszik
const SZORNYHANG_ESELY := 0.55   # egy mozduló szörny ekkora eséllyel ad hangot (ritkítás)
## a hős lépése halk: ennyi a hangereje a többi hanghoz képest
const LEPES_HANGERO := 0.55

## Fertőzött (elit) szörny: erősebb, zölden izzik, és rézötvözetet ejt.
const ELITE_CHANCE := 0.11
const ELITE_HP := 1.6
const ELITE_ATK := 1.25
# ══════════ KASZTOK ══════════
#   Lovag – közelharc: +35% sebzés, 20% eséllyel pajzzsal felfogja az ütés felét, sok életerő
#   Íjász – fizikai sebzés messziről: íjjal indul, +1 lőtáv, gyakori kritikus; közelről gyengébb
#   Mágus – kék varázsgömb (5 mező): varázssebzés, amely nagyrészt átüt a páncélon; kevés életerő
const CLASS_ORDER := ["Lovag", "Mágus", "Íjász"]
const CLASSES := {
	"Lovag": {"hp": 46, "atk": 9, "mag": 0, "def": 5, "col": "#70c8e8", "hpUp": 13},
	"Mágus": {"hp": 26, "atk": 4, "mag": 11, "def": 1, "col": "#6aa8ff", "hpUp": 8},
	"Íjász": {"hp": 32, "atk": 6, "mag": 0, "def": 2, "col": "#70d860", "hpUp": 10},
	# A negyedik hős: Vane eredeti teste. A Bronz Klinika elérésével oldódik fel (lásd Meta.sebesz_van).
	#   Sebész – közelharc: minden vágása vérzést okoz; a legyőzöttekből szerveket operál ki,
	#   és harc közben be is ülteti őket magába (gyógyulás + erő).
	"Sebész": {"hp": 34, "atk": 8, "mag": 0, "def": 2, "col": "#a0f0d8", "hpUp": 10},
}
## a feloldható hősök (a CLASS_ORDER a három alap; a hősválasztó a feloldottakat is mutatja)
const EXTRA_CLASSES := ["Sebész"]
const MELEE_MULT := {"Lovag": 1.35, "Íjász": 0.7, "Mágus": 0.6, "Sebész": 1.1}
## a Véd tekercs a lovagnak ennyivel többet ad (a 4 pályás játékban 2 volt; a hosszú kalandban a sok
## tekercs a lovagot a többi kaszthoz képest sebezhetetlenné tette)
const LOVAG_VED_TEKERCS := 1
const ORGAN_MAX := 3
const ORGAN_CHANCE := 0.3
const BLEED_MAX := 6

# ══════════ KÜLÖNLEGES TERMEK ══════════
## A különleges termek csak a szoba tartalmát változtatják meg (láda, őr, csapda, szobor,
## kereskedő) — egyik sem tesz falat sehova, így a „mindig bejárható" biztosíték sértetlen.
const ROOM_KINDS := {
	"kincstar": {"col": "#d4a84b", "icon": "⚜"},
	"szentely": {"col": "#70d0ff", "icon": "✛"},
	"kereskedo": {"col": "#60d080", "icon": "◉"},
	"csapda": {"col": "#e05050", "icon": "⚠"},
	"esemeny": {"col": "#ffd870", "icon": "?"},
	"rejtveny": {"col": "#b890ff", "icon": "◈"},
}
const ROOM_KIND_ORDER := ["kincstar", "szentely", "kereskedo", "csapda", "esemeny"]
## a térkép színezéséhez: a minden emeleten meglévő termek + a csak néha megjelenő rejtvényszoba
const ROOM_KIND_ALL := ["kincstar", "szentely", "kereskedo", "csapda", "esemeny", "rejtveny"]

## Egy hétköznapi szobában ekkora eséllyel áll láda (a kincstár, a csapdaterem és a titkos
## kamrák ládái ezen felül vannak).
const LADA_ESELY := 0.12

# ══════════ REJTVÉNYSZOBA ══════════
## Nem minden emeleten van. Egy leláncolt páncélláda áll a közepén, körülötte jeles nyomólapok:
## a láda fölött izzó jelek SORRENDJÉBEN kell rájuk lépni. Rossz lapra lépve a sor elölről
## kezdődik, és a zóna csapása (előre jelezve) kitör a hős körül. A lapokra csak a hős hat.
const REJTVENY_ESELY := 0.45
## a lapok jelei sorban: kör, háromszög, négyzet, rombusz, kereszt (rajzolva: Sprites2.lap_jel)
const LAP_SZINEK := ["#ff7060", "#ffd060", "#70d0ff", "#90e070", "#d090ff"]

# ══════════ ZÓNÁNKÉNTI PÁLYAELEMEK ("gépek", World.gepek) ══════════
## Minden zónának saját, működő pályaeleme van. Mind ELŐRE JELEZ (a jelzett mező egy kör múlva
## sújt le), a szörnyekre ugyanúgy hat, mint a hősre, és mélyebb emeleten több van belőle,
## nagyobbat sebez és szaporább.
##  1. "zsilip": gőzzsilip a folyosón — szabályos ütemben két körre gőz zárja el (a nyomásmérő mutatja)
##  2. "szike":  sínen ingázó szike — körönként egy mezőt halad, a következő mezője előre villog
##  3. "gubo":   spóragubó — ha valaki mellé lép, megduzzad, a következő körben spórafelhővé pukkad
##  4. "korong": forgó fogaskerék-padló — felizzik, megcsíp, és negyedfordulatot tesz azzal, aki rajta áll
const GEP_ZONA := {1: "zsilip", 2: "szike", 3: "gubo", 4: "korong"}
## emeletenként (1..4) a gőzzsilip üteme: ennyi körből az utolsó kettőben fúj a gőz
const ZSILIP_PERIOD := [8, 8, 7, 6]
const KORONG_PERIOD := [7, 6, 5, 5]
const GUBO_UJRA := [14, 12, 10, 8]      # ennyi kör múlva érik be újra a kipukkadt gubó
const FELHO_KOR := 3                    # a spórafelhő ennyi körig marad
## a gépek sebzése: alap + emeletenként (a hősnél a védelem harmada levonódik, mint minden jelzett csapásnál)
const GEP_DMG := {"zsilip": [7, 2], "szike": [9, 2], "gubo": [8, 3], "korong": [10, 2]}


## Egy pályaelem sebzése a zóna adott emeletén. A jelzett csapásokhoz (gőz, szike, fogak) a pálya
## csapás-többlete is hozzáadódik (a hős védelme addigra megnőtt); a spórafelhő körönként, a
## védelemtől függetlenül mar, ahhoz nem.
static func gep_dmg(tip: String, zona: int, emelet: int) -> int:
	var d: Array = GEP_DMG.get(tip, [5, 1])
	var alap := int(d[0]) + int(d[1]) * (emelet - 1)
	return alap if tip == "gubo" else alap + palya_csapas(palya_sorszam(zona, emelet))

# ══════════ ZÓNA-VESZÉLYEK, ESEMÉNYEK, MINI-BOSSOK ══════════
## Padlórácsok: szabályos időközönként kitör belőlük a zóna csapása (előtte egy körrel jeleznek).
const VENT_KIND := {1: "steam", 2: "blade", 3: "root", 4: "steam"}
const VENT_PERIOD := 6
## Döntési események (a nevük: event.<kulcs>, a két válasz: event.<kulcs>.a / .b)
const EVENTS := ["fogoly", "verautomata", "mutoasztal"]
## Zónánként egy vándorló mini-boss: háromszoros életerő, saját csapás, és ereklyét hagy maga után.
const MINI := {1: "rat", 2: "nurse", 3: "spore", 4: "demon"}
const MINI_HP := 2.6
## ...és ennyi életerő jár még hozzá (a pálya szorzója előtt)
const MINI_HP_PLUSZ := 8
const MINI_ATK := 1.35
## a kincstár őre: erős, aranyban gazdag szörny
const GUARD_POOL := {1: ["orc", "skeleton"], 2: ["orc", "golem"], 3: ["troll", "golem"], 4: ["golem", "demon"]}

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

# ══════════ AKTÍV KÉPESSÉGEK (lehűlés körökben) ══════════
const DASH_CD := 6
const DASH_LEN := 2
const SKILL_CD := 9
## kasztonként: a képesség kulcsa (a neve: ab.<kulcs>, a leírása: ab.<kulcs>.d)
const SKILL := {"Lovag": "forgoszel", "Mágus": "gozrobbanas", "Íjász": "nyilzapor", "Sebész": "beultetes"}
const SKILL_ICON := {"Lovag": "⚔", "Mágus": "✳", "Íjász": "➶", "Sebész": "✚"}
const SKILL_COL := {"Lovag": "#ffd060", "Mágus": "#8cc4ff", "Íjász": "#a0e070", "Sebész": "#a0f0d8"}

# ══════════ VESZÉLYZÓNÁK (a főellenségek előre jelzett támadásai) ══════════
## "warn": a mező egy kör múlva robban (ki lehet lépni belőle); "acid": tócsa, amíg el nem párolog.
## "spora": a spóragubó felhője (mérgez); "gear": a forgó fogaskerék-padló fogai.
const HAZ_COL := {"steam": "#ffe0b0", "blade": "#ffffff", "root": "#70d060", "acid": "#b0e030", "spora": "#c8e060", "gear": "#ffc050"}
## akiket a spórafelhő nem bánt (maguk is gombák)
const SPORA_IMMUNIS := ["spore", "bloom", "symbiote"]
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
