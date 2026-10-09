class_name Daily
extends RefCounted
## Napi kihívás: aznap mindenki ugyanazt a Gorgonát kapja (ugyanaz a pálya, ugyanazok a ládák
## és szörnyek — a nap dátumából számolt maggal), a Műtőterem fejlesztései nélkül.
## A pontszám a ranglistára kerül (Fiok.napi_bekuld; a kiszolgáló oldala:
## Birodalom_Godot/server/supabase/schema_kem_napi.sql).

## a mai nap (UTC szerint, hogy a világ minden pontján ugyanaz a kihívás legyen)
static func nap() -> String:
	return Time.get_date_string_from_system(true)


## a nap magja (a pályák ebből épülnek)
static func mag(n: String) -> int:
	return int(n.hash() & 0x7fffffff)


## A pontszám: meddig jutott, mennyit ölt, mit gyűjtött — a tétovázás levon.
static func pont(p: Player, zona: int, won: bool, kor: int) -> int:
	var s := (zona - 1) * 1000 + p.kills * 15 + p.gold * 2 + (p.plvl - 1) * 100 + p.relics.size() * 150
	if won:
		s += 5000 + p.lives * 500
	return clampi(s - int(kor / 4.0), 0, 200000)