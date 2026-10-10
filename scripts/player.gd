class_name Player
extends RefCounted
## A hős: alapértékek, felszerelés (fegyver, páncél, pajzs), táska, üzenetek.

var cls := "Lovag"
var x := 0
var y := 0
var rx := 0.0
var ry := 0.0
var col := "#70c8e8"
var facing := 1
var max_hp := 1
var hp := 1
var base_atk := 0
var base_mag := 0
var base_def := 0
var lives := 3
var weapon: Item = null
var armor: Item = null
var shield: Item = null
var inventory: Array[Item] = []
var xp := 0
var plvl := 1
var xp_next := 60
var alive := true
var msgs: Array = []    # {t, c} — t: fordítási hivatkozás (Lang.ref), a kirajzoláskor fordul le
var msg_seq := 0        # hányadik üzenet (a HUD ebből tudja, hogy változott a lista)
var poison := 0
var lunge := 0.0
var rf := 1.0           # a kirajzolt irány (megforduláskor -1 és 1 között siklik át)
var lunge_dx := 0
var lunge_dy := 0
var on_level_up: Callable = Callable()
var gold := 0            # a szörnyekből hulló, játékon belüli arany (a kereskedőnél költhető)
var perks := {}          # képesség-azonosító -> hányszor vette fel
var perk_seq := 0        # nő minden új képességnél (a HUD/táska ebből tudja, hogy változott)
var steps := 0           # megtett lépések (a "Gyors léptek" képességhez)
# ── Gorgona: nyersanyag, aktív képességek, állapotok ──
var bio := 0             # Bio-Hulladék (ebben a kalandban gyűjtött; a végén a Műtőterembe kerül)
var rez := 0             # Rézötvözet
var kills := 0
var kill_heal := 0       # Szív-pumpa: ennyit gyógyul minden legyőzött szörny után
var cd_cut := 0          # Adrenalin-mirigy: ennyivel rövidebb a képességek lehűlése
var find_mult := 1.0     # Üvegszem: több nyersanyag
var dash_cd := 0         # hány kör múlva ugorhat újra félre
var skill_cd := 0        # hány kör múlva használhatja újra a kaszt-képességét
var stun := 0            # kábult: ennyi köre kimarad
var rooted := 0          # gyökerek fogják: támadhat, de nem léphet
var dir_x := 1           # az utolsó irány (a félreugrás és a képesség ebbe megy)
var dir_y := 0
var hurt_ms := 0.0       # mikor érte utoljára ütés (a kirajzolás villanásához)
# ── ereklyék (kalandonként gyűlnek; lásd relics.gd) ──
var relics: Array = []   # ereklye-azonosítók, a megszerzés sorrendjében
var relic_seq := 0       # nő minden új ereklyénél (a HUD ebből tudja, hogy változott)
var hit_count := 0       # hányadik találat (Tesla-tekercs: minden negyedik láncol)
var steam_charge := false  # Gőzköpeny: a félreugrás utáni következő ütés duplán sebez
var spark_used := false  # Végső szikra: zónánként egyszer ment meg
# ── a Sebész ──
var organs := 0          # kioperált szervek (a Beültetés ezekből gyógyít és erősít)


static func create(c: String) -> Player:
	var s: Dictionary = Data.CLASSES[c]
	var p := Player.new()
	p.cls = c
	p.col = s["col"]
	p.max_hp = s["hp"]
	p.hp = s["hp"]
	p.base_atk = s["atk"]
	p.base_mag = s["mag"]
	p.base_def = s["def"]
	# az íjász íjjal kezdi a kalandot
	if c == "Íjász":
		p.weapon = Item.make(Item.find_base("wooden_bow"), "common", 1)
	return p


var atk: int:
	get: return base_atk + (weapon.dmg if weapon else 0)

## a félreugrás hossza és lehűlése (a Réz-Idegfonat megduplázza a távot, és gyorsítja)
var dash_len: int:
	get: return Data.DASH_LEN * (2 if perk("idegfonat") > 0 else 1)

var dash_cd_max: int:
	get: return maxi(2, Data.DASH_CD - cd_cut - (2 if perk("idegfonat") > 0 else 0))

var skill_cd_max: int:
	get: return maxi(3, Data.SKILL_CD - cd_cut - (2 if has_relic("oramu") else 0))


func has_relic(id: String) -> bool:
	return id in relics

## a mágus varázsereje: a fegyver fele is hozzáadódik (a rúnakard jobban vezeti a mágiát)
var mag: int:
	get: return base_mag + int(floorf((weapon.dmg if weapon else 0) * 0.5))

## védelem = alap + páncél + pajzs
var def: int:
	get: return base_def + (armor.def if armor else 0) + (shield.def if shield else 0)

## regeneráció körönként (nagyon ritka / legendás páncél és pajzs + a "Gyors gyógyulás" képesség)
var regen: int:
	get: return (armor.regen if armor else 0) + (shield.regen if shield else 0) + perk("regen")

var lifesteal: float:
	get: return (weapon.lifesteal if weapon else 0.0) + 0.05 * perk("vamp")

## a lovag pajzsa: alap 20% + a "Pajzsmester" képességenként 5%
var block_chance: float:
	get: return (0.20 + 0.05 * perk("blokk")) if cls == "Lovag" else 0.0

## az íjász kritikusa: alap 30% + a "Sasszem" képességenként 8%
var crit_chance: float:
	get: return 0.30 + 0.08 * perk("sasszem")


## hányszor van meg egy képesség
func perk(id: String) -> int:
	return int(perks.get(id, 0))


## t: Lang.ref(...) hivatkozás (vagy kész szöveg); a HUD a mostani nyelven írja ki
func add_msg(t: Variant, c: String = "#c8a870") -> void:
	msgs.append({"t": t, "c": c})
	msg_seq += 1
	if msgs.size() > 7:
		msgs.pop_front()


func gain_xp(n: int, xm: float) -> void:
	xp += Data.jround(n * xm)
	while xp >= xp_next:
		xp -= xp_next
		plvl += 1
		xp_next = int(floorf(xp_next * 1.6))
		var hp_up: int = Data.CLASSES[cls]["hpUp"]
		max_hp += hp_up
		hp = mini(hp + hp_up, max_hp)
		if cls == "Mágus":
			base_mag += 3
			base_atk += 1
		else:
			base_atk += 2
		base_def += 1
		add_msg(Lang.ref("msg.level", plvl), Data.P["parchGold"])
		if on_level_up.is_valid():
			on_level_up.call()
