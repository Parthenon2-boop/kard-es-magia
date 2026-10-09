extends SceneTree
## Festett figurák előkészítése: a letöltött képet körbevágja, (ha nem átlátszó a háttere) a
## szélekről kiindulva eltávolítja az egyszínű hátteret, 320 képpont magasra méretezi, és az
## art/figurak mappába menti.
##   godot --headless --path . -s res://tools/figura_vag.gd -- <forrásmappa>
## A forrásmappa PNG / JPG / WEBP fájljai a játékbeli nevükkel legyenek elnevezve (pl. rat.png,
## hos_lovag.png, rust_worm_2.png) — lásd scripts/figura.gd.

const MAGAS := 320
const TURES := 0.16      # ennyire térhet el egy képpont a háttér színétől, hogy még háttérnek számítson


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Használat: -- <forrásmappa>")
		quit(1)
		return
	var forras := str(args[0]).replace("\\", "/").trim_suffix("/")
	var cel := ProjectSettings.globalize_path("res://art/figurak")
	DirAccess.make_dir_recursive_absolute(cel)
	var d := DirAccess.open(forras)
	if d == null:
		print("Nincs ilyen mappa: ", forras)
		quit(1)
		return
	var db := 0
	for f in d.get_files():
		if not (f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]):
			continue
		var img := Image.load_from_file(forras + "/" + f)
		if img == null or img.is_empty():
			print("  nem olvasható: ", f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		if img.get_pixel(0, 0).a > 0.5:
			_hatter_le(img)
		var r := img.get_used_rect()
		if r.size.x < 8 or r.size.y < 8:
			print("  üres kép: ", f)
			continue
		img = img.get_region(r)
		img.resize(maxi(1, int(round(float(img.get_width()) * MAGAS / img.get_height()))), MAGAS, Image.INTERPOLATE_LANCZOS)
		img.save_png(cel + "/" + f.get_basename() + ".png")
		print("  ", f, " -> ", img.get_width(), "x", img.get_height())
		db += 1
	print(db, " figura elkészült: ", cel)
	quit()


## Egyszínű háttér eltávolítása: a kép széléről indulva minden, a sarok színéhez hasonló képpont átlátszó lesz.
func _hatter_le(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var hatter := img.get_pixel(0, 0)
	var latott := PackedByteArray()
	latott.resize(w * h)
	var sor := PackedInt32Array()
	for x in w:
		sor.append(x)
		sor.append((h - 1) * w + x)
	for y in h:
		sor.append(y * w)
		sor.append(y * w + w - 1)
	while not sor.is_empty():
		var i := sor[sor.size() - 1]
		sor.remove_at(sor.size() - 1)
		if latott[i]:
			continue
		latott[i] = 1
		var x := i % w
		var y := int(i / w)
		var p := img.get_pixel(x, y)
		if absf(p.r - hatter.r) + absf(p.g - hatter.g) + absf(p.b - hatter.b) > TURES * 3.0:
			continue
		img.set_pixel(x, y, Color(p.r, p.g, p.b, 0.0))
		if x > 0: sor.append(i - 1)
		if x < w - 1: sor.append(i + 1)
		if y > 0: sor.append(i - w)
		if y < h - 1: sor.append(i + w)