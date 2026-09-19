extends SceneTree
## Minden szkript betöltése (fordítási hibák kiírása).
func _init() -> void:
	var bad := 0
	for d in ["res://scripts/", "res://tests/"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s: Script = load(d + f)
				if s == null or not s.can_instantiate():
					print("HIBÁS: ", d + f)
					bad += 1
	print("szkript-ellenőrzés kész, hibás: ", bad)
	quit(1 if bad > 0 else 0)