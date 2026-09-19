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
var msgs: Array = []    # {t, c}
var poison := 0
var lunge := 0.0
var lunge_dx := 0
var lunge_dy := 0
var on_level_up: Callable = Callable()


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
		p.weapon = Item.make(Item.find_base("Faíj"), "common", 1)
	return p


var atk: int:
	get: return base_atk + (weapon.dmg if weapon else 0)

## a mágus varázsereje: a fegyver fele is hozzáadódik (a rúnakard jobban vezeti a mágiát)
var mag: int:
	get: return base_mag + int(floorf((weapon.dmg if weapon else 0) * 0.5))

## védelem = alap + páncél + pajzs
var def: int:
	get: return base_def + (armor.def if armor else 0) + (shield.def if shield else 0)

## regeneráció körönként (nagyon ritka / legendás páncél és pajzs összeadódik)
var regen: int:
	get: return (armor.regen if armor else 0) + (shield.regen if shield else 0)

var lifesteal: float:
	get: return weapon.lifesteal if weapon else 0.0


func add_msg(t: String, c: String = "#c8a870") -> void:
	msgs.append({"t": t, "c": c})
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
		add_msg("⬆ Szint %d!" % plvl, Data.P["parchGold"])
		if on_level_up.is_valid():
			on_level_up.call()
