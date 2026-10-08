class_name Story
extends RefCounted
## A történet táblái (Flesh & Cog — A Hús és a Fogaskerék): Gorgona négy zónája a saját
## színvilágával, a főellenségek párbeszédei, a megtalálható feljegyzések, a bevezető és a
## befejezés képsorai. Minden szöveg a nyelvi fájlokban van; itt csak kulcsok és színek állnak.

# ══════════ ZÓNÁK ══════════
## wall / floor: a csempék alapszíne; line: a fugák; acc: a zóna jelzőszíne (felirat, fény);
## lamp: a fali lámpák fénye; fog: a levegőben úszó részecskék; pat: a padló mintája.
const ZONES := {
	1: {"id": "kazan", "wall": "#4a3524", "floor": "#262a1e", "line": "#6e4a26", "fline": "#3a4030",
		"acc": "#e08a3a", "lamp": "#ffb060", "fog": "#9ad070", "pat": "plate", "part": "steam"},
	2: {"id": "klinika", "wall": "#77726a", "floor": "#45423c", "line": "#a8884a", "fline": "#5c5850",
		"acc": "#e8c070", "lamp": "#fff0c8", "fog": "#c8f0e8", "pat": "checker", "part": "mote"},
	3: {"id": "tudokert", "wall": "#64283a", "floor": "#2a1c22", "line": "#96405a", "fline": "#3c3a26",
		"acc": "#f07090", "lamp": "#c0ff90", "fog": "#d8e860", "pat": "vein", "part": "spore"},
	4: {"id": "mag", "wall": "#33303e", "floor": "#221c12", "line": "#c89a3a", "fline": "#5a4418",
		"acc": "#ffd060", "lamp": "#ffd870", "fog": "#ffb040", "pat": "plate", "part": "ember"},
}


static func zone(level: int) -> Dictionary:
	return ZONES[clampi(level, 1, ZONES.size())]


static func zone_id(level: int) -> String:
	return str(zone(level)["id"])


# ══════════ FŐELLENSÉGEK ══════════
## pre: párbeszéd, amikor a hős először megpillantja; mid: a 2. fázis kezdetén; win: a legyőzése után.
## Egy sor: [ki beszél, szövegkulcs] — a "vane" a hős, a többi a szörny kulcsa.
const BOSS_TALK := {
	"rust_worm": {
		"pre": [["vane", "talk.worm.pre1"]],
		"mid": [["vane", "talk.worm.mid1"]],
		"win": [["vane", "talk.worm.win1"]],
	},
	"dr_karel": {
		"pre": [["dr_karel", "talk.karel.pre1"], ["vane", "talk.karel.pre2"]],
		"mid": [["dr_karel", "talk.karel.mid1"]],
		"win": [["vane", "talk.karel.win1"]],
	},
	"symbiote": {
		"pre": [["symbiote", "talk.symb.pre1"]],
		"mid": [["symbiote", "talk.symb.mid1"], ["vane", "talk.symb.mid2"]],
		"win": [["vane", "talk.symb.win1"]],
	},
	"weaver": {
		"pre": [["vane", "talk.weaver.pre1"]],
		"mid": [["vane", "talk.weaver.mid1"]],
		"win": [["vane", "talk.weaver.win1"]],
	},
}


static func talk(boss: String, part: String) -> Array:
	var d: Dictionary = BOSS_TALK.get(boss, {})
	return (d.get(part, []) as Array).duplicate(true)


# ══════════ FELJEGYZÉSEK (a Napló lapjai) ══════════
## Zónánként két megtalálható lap; a címük note.<id>, a szövegük note.<id>.d.
const NOTES := {
	1: ["n041", "sargulas"],
	2: ["klinika", "szike"],
	3: ["n112", "epeholyag"],
	4: ["istengep", "idegfonat"],
}
const NOTE_ORDER := ["n041", "sargulas", "klinika", "szike", "n112", "epeholyag", "istengep", "idegfonat"]


static func note_zone(id: String) -> int:
	for z in NOTES:
		if id in (NOTES[z] as Array):
			return int(z)
	return 1


# ══════════ BEVEZETŐ ÉS BEFEJEZÉS ══════════
## Egy képsor: a háttérkép fajtája + a szöveg kulcsa. A "narr" sorok idézetként jelennek meg.
const INTRO := [
	{"art": "gorgona", "k": "intro.1"},
	{"art": "mag", "k": "intro.2"},
	{"art": "sargulas", "k": "intro.3"},
	{"art": "lombik", "k": "intro.4"},
	{"art": "gorgona", "k": "intro.5"},
]
const ENDING := [
	{"art": "mag", "k": "end.1"},
	{"art": "sziv", "k": "end.2", "narr": true},
	{"art": "sziv", "k": "end.3"},
	{"art": "gorgona_tiszta", "k": "end.4", "narr": true},
	{"art": "gorgona_tiszta", "k": "end.5"},
]


# ══════════ A MŰTŐTEREM LAKÓI ══════════
## Nora, a Csontkovács: mit mond, amikor a hős visszatér (a történet állása szerint).
static func nora_line(meta: Dictionary) -> String:
	if bool(meta.get("just_bought_nora", false)):
		return "hub.nora.buy"
	if int(meta.get("wins", 0)) > 0:
		return "hub.nora.win"
	if int(meta.get("deepest", 0)) >= 3:
		return "hub.nora.z3"
	if int(meta.get("last_death", 0)) == 1:
		return "hub.nora.z1"
	if int(meta.get("runs", 0)) == 0:
		return "hub.nora.first"
	return "hub.nora.idle"


## A Megnyúzott Próféta.
static func prophet_line(meta: Dictionary) -> String:
	if bool(meta.get("just_bought_prophet", false)):
		return "hub.prophet.buy"
	return "hub.prophet.idle"
