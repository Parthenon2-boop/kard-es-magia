extends Node2D
## Egy rajzréteg: a _draw()-ban a főjelenet megadott függvényét hívja a saját vászonelemére.
## (Külön réteg kell az additív fényekhez és a vágott/színátmenetes részekhez.)

var fn: Callable = Callable()


func _draw() -> void:
	if fn.is_valid():
		fn.call(get_canvas_item())
