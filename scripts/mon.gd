class_name Mon
extends RefCounted
## Egy szörny a pályán.

var key := ""
var name := ""
var x := 0
var y := 0
var rx := 0.0   # kirajzolt (sikló) helyzet
var ry := 0.0
var seedv := 0.0
var facing := 1
var max_hp := 1
var hp := 1
var atk := 1
var def := 0
var mres := 0   # varázsellenállás
var xp := 0
var sp := ""
var boss := false
var alive := true
var guard := false   # a kincstár őre: erősebb és több aranyat ejt
var awake := false   # riasztó ébresztette fel: a látótéren kívülről is a hős felé tart
var stun := 0        # hány körig nem léphet (pajzsdöfés)


static func make(k: String, px: int, py: int, diff: String) -> Mon:
	var t: Dictionary = Data.MONS[k]
	var d: Dictionary = Data.DIFF[diff]
	var m := Mon.new()
	m.key = k
	m.x = px
	m.y = py
	m.rx = px
	m.ry = py
	m.name = t["name"]
	m.seedv = randf() * 100.0
	m.facing = Data.pick([-1, 1])
	m.max_hp = Data.jround(t["hp"] * d["monHp"])
	m.hp = m.max_hp
	m.atk = Data.jround(t["atk"] * d["monAtk"])
	m.def = t["def"]
	m.mres = t.get("mres", 0)
	m.xp = t["xp"]
	m.sp = t.get("sp", "")
	m.boss = t.get("boss", false)
	return m


## A kincstár őre: másfélszeres életerő, erősebb ütés, több tapasztalat.
static func make_guard(k: String, px: int, py: int, diff: String) -> Mon:
	var m := make(k, px, py, diff)
	m.guard = true
	m.max_hp = Data.jround(m.max_hp * 1.5)
	m.hp = m.max_hp
	m.atk = Data.jround(m.atk * 1.2)
	m.def += 2
	m.xp = Data.jround(m.xp * 1.5)
	m.name = "Kincstár őre (%s)" % m.name
	return m
