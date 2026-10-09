extends SceneTree
## Figuralap (egy képen több festett figura, egyszínű háttéren, rácsban) szétvágása külön figurákra.
##   godot --headless --path . -s res://tools/figura_racs.gd -- <kép> <oszlop>x<sor> <név1,név2,...> [célmappa] [fust]
## A "fust" kapcsoló a figura belsejében is kiszedi a háttér áttetsző visszfényét (gőz, füst, szikra) —
## csak a világos képpontokat érinti, a sötét lila ruha megmarad.
## A neveket sorfolytonosan kell megadni (balról jobbra, fentről le); a "-" nevű cella kimarad.
## Lépések: a háttér színét a sarokból veszi, színkulccsal átlátszóvá teszi (a szegély elszíneződését
## is visszaveszi), megkeresi az összefüggő foltokat (a figurákat), sorba rendezi őket, körbevágja,
## 360 képpont magasra méretezi, és az art/figurak mappába menti.

const MAGAS := 360
const T0 := 0.22      # eddig a színtávolságig teljesen háttér
const T1 := 0.42      # ettől teljesen figura


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		print("Használat: -- <kép> <oszlop>x<sor> <nevek vesszővel> [célmappa]")
		quit(1)
		return
	var img := Image.load_from_file(str(a[0]))
	if img == null or img.is_empty():
		print("Nem olvasható: ", a[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var rs := str(a[1]).split("x")
	var cols := int(rs[0])
	var rows := int(rs[1])
	var nevek := str(a[2]).split(",")
	var cel := ProjectSettings.globalize_path("res://art/figurak") if a.size() < 4 or str(a[3]) == "-" else str(a[3]).replace("\\", "/")
	var fust := a.size() >= 5 and str(a[4]) == "fust"
	var racs := false
	DirAccess.make_dir_recursive_absolute(cel)
	_kulcs(img)
	_perem(img)
	if fust:
		_fust(img)
	var dobozok := _foltok(img, cols * rows)
	if dobozok.size() != cols * rows:
		print("  a foltok száma ", dobozok.size(), " (várt: ", cols * rows, ") — a rács celláit használom")
		dobozok = []
		racs = true
		var cw := img.get_width() / float(cols)
		var ch := img.get_height() / float(rows)
		for r in rows:
			for c in cols:
				dobozok.append(Rect2i(int(c * cw), int(r * ch), int(cw), int(ch)))
	else:
		dobozok = _sorba(dobozok, cols, rows)
	var db := 0
	for i in mini(dobozok.size(), nevek.size()):
		var nev := str(nevek[i]).strip_edges()
		if nev == "-" or nev == "":
			continue
		var resz := img.get_region(dobozok[i])
		if racs:
			_szel_le(resz)
		_fo_marad(resz)
		var r2 := resz.get_used_rect()
		if r2.size.x < 8 or r2.size.y < 8:
			print("  üres cella: ", nev)
			continue
		resz = resz.get_region(r2)
		resz.resize(maxi(1, int(round(float(resz.get_width()) * MAGAS / resz.get_height()))), MAGAS, Image.INTERPOLATE_LANCZOS)
		resz.save_png(cel + "/" + nev + ".png")
		print("  ", nev, " -> ", resz.get_width(), "x", resz.get_height())
		db += 1
	print(db, " figura elkészült: ", cel)
	quit()


## Színkulcs: a sarok színéhez közeli képpontok átlátszók lesznek; a félig átlátszó szegélyből
## kivesszük a háttér színét (hogy ne maradjon rikító perem a figura körül).
func _kulcs(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bg := img.get_pixel(2, 2)
	for y in h:
		for x in w:
			var p := img.get_pixel(x, y)
			var d := sqrt((p.r - bg.r) * (p.r - bg.r) + (p.g - bg.g) * (p.g - bg.g) + (p.b - bg.b) * (p.b - bg.b))
			if d <= T0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d < T1:
				var al := (d - T0) / (T1 - T0)
				# a háttérszín részét kivonjuk a képpontból
				var r := clampf((p.r - bg.r * (1.0 - al)) / maxf(0.05, al), 0.0, 1.0)
				var g := clampf((p.g - bg.g * (1.0 - al)) / maxf(0.05, al), 0.0, 1.0)
				var b := clampf((p.b - bg.b * (1.0 - al)) / maxf(0.05, al), 0.0, 1.0)
				img.set_pixel(x, y, Color(r, g, b, al))


## A figura széléről leszedi a háttér visszfényét: az átlátszó rész 2 képpontos közelében a
## rózsaszínbe hajló (a zöldnél jóval vörösebb ÉS kékebb) képpontokat a zöld csatornához húzza.
func _perem(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			var p := src.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var tobb := minf(p.r, p.b) - p.g
			if tobb < 0.10:
				continue
			var szel := false
			for dd in [[2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [-1, -1], [1, -1], [-1, 1]]:
				var nx: int = x + dd[0]
				var ny: int = y + dd[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h or src.get_pixel(nx, ny).a < 0.5:
					szel = true
					break
			if szel:
				img.set_pixel(x, y, Color(p.r - tobb * 0.85, p.g, p.b - tobb * 0.85, p.a * 0.85))


## A kivágott figurán csak a fő alak marad, meg ami a befoglaló téglalapjába ér (szikra, gőz):
## a távolabb lebegő foltokat (a szomszéd figura lelógó darabjait) töröljük.
func _fo_marad(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cimke := PackedInt32Array()
	cimke.resize(w * h)
	var dob: Array = []     # [Rect2i, terület]
	for i0 in w * h:
		if cimke[i0] != 0 or img.get_pixel(i0 % w, int(i0 / w)).a <= 0.3:
			continue
		var id := dob.size() + 1
		var r := Rect2i(i0 % w, int(i0 / w), 1, 1)
		var ter := 0
		var sor := PackedInt32Array([i0])
		cimke[i0] = id
		while not sor.is_empty():
			var i := sor[sor.size() - 1]
			sor.remove_at(sor.size() - 1)
			var x := i % w
			var y := int(i / w)
			ter += 1
			r = r.expand(Vector2i(x, y))
			for dd in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + dd[0]
				var ny: int = y + dd[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni := ny * w + nx
				if cimke[ni] == 0 and img.get_pixel(nx, ny).a > 0.3:
					cimke[ni] = id
					sor.append(ni)
		dob.append([r, ter])
	if dob.size() < 2:
		return
	var fo := 0
	for k in dob.size():
		if int(dob[k][1]) > int(dob[fo][1]):
			fo = k
	var fr: Rect2i = (dob[fo][0] as Rect2i).grow(2)
	var torol := {}
	for k in dob.size():
		if k != fo and not fr.intersects(dob[k][0] as Rect2i):
			torol[k + 1] = true
	if torol.is_empty():
		return
	# a törölt foltok áttetsző pereme is menjen: a folt téglalapját töröljük
	for k in torol:
		var tr: Rect2i = (dob[int(k) - 1][0] as Rect2i).grow(3)
		for y in range(maxi(0, tr.position.y), mini(h, tr.end.y)):
			for x in range(maxi(0, tr.position.x), mini(w, tr.end.x)):
				if not fr.has_point(Vector2i(x, y)):
					img.set_pixel(x, y, Color(0, 0, 0, 0))


## Áttetsző gőz / füst: a figura belsejében is visszaveszi az erősen rózsaszín (háttérszínű) árnyalatot.
func _fust(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var tobb := minf(p.r, p.b) - p.g
			# csak a világos (gőzszerű) képpontokon: a sötét lila ruha marad
			if tobb > 0.11 and p.g > 0.4:
				img.set_pixel(x, y, Color(p.r - tobb * 0.9, p.g, p.b - tobb * 0.9, p.a * (1.0 - tobb * 0.6)))


## Rács szerinti vágásnál a cellába belóghat a szomszéd figura széle: a cella külső negyedében
## megkeressük a legüresebb oszlopot / sort, és ami azon kívül esik, azt töröljük.
func _szel_le(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var oszl := PackedInt32Array()
	oszl.resize(w)
	var sorok := PackedInt32Array()
	sorok.resize(h)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.3:
				oszl[x] += 1
				sorok[y] += 1
	var bal := _legures(oszl, 0, int(w * 0.25), true)
	var jobb := _legures(oszl, int(w * 0.75), w - 1, false)
	var fent := _legures(sorok, 0, int(h * 0.2), true)
	var lent := _legures(sorok, int(h * 0.8), h - 1, false)
	for y in h:
		for x in w:
			if x < bal or x > jobb or y < fent or y > lent:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


## A [tol, ig] sávban a legüresebb hely; ha a szélén nincs semmi, a szél marad (nincs mit levágni).
func _legures(db: PackedInt32Array, tol: int, ig: int, elejen: bool) -> int:
	var szel := tol if elejen else ig
	var van := false
	for i in range(szel - 3 if not elejen else szel, szel + 4 if elejen else szel + 1):
		if i >= 0 and i < db.size() and db[i] > 0:
			van = true
	if not van:
		return szel
	var legj := szel
	var legk := 1 << 30
	for i in range(tol, ig + 1):
		# egyenlőségnél a szélhez közelebbi nyer
		var jobb_e := db[i] < legk or (db[i] == legk and not elejen)
		if jobb_e:
			legk = db[i]
			legj = i
	return legj


## Az összefüggő, nem átlátszó foltok befoglaló téglalapjai (negyedakkora maszkon keresve).
## A kis foltokat (cseppek, szikrák) a legközelebbi nagyhoz csapja. Legfeljebb `varni` darabot ad vissza.
func _foltok(img: Image, varni: int) -> Array:
	const L := 4
	var w := int(img.get_width() / L)
	var h := int(img.get_height() / L)
	var maszk := PackedByteArray()
	maszk.resize(w * h)
	for y in h:
		for x in w:
			if img.get_pixel(x * L + 1, y * L + 1).a > 0.5:
				maszk[y * w + x] = 1
	var cimke := PackedInt32Array()
	cimke.resize(w * h)
	var dobozok: Array = []     # [Rect2i (maszk-egységben), terület]
	for i0 in w * h:
		if maszk[i0] == 0 or cimke[i0] != 0:
			continue
		var id := dobozok.size() + 1
		var x0 := i0 % w
		var y0 := int(i0 / w)
		var minx := x0
		var maxx := x0
		var miny := y0
		var maxy := y0
		var ter := 0
		var sor := PackedInt32Array([i0])
		cimke[i0] = id
		while not sor.is_empty():
			var i := sor[sor.size() - 1]
			sor.remove_at(sor.size() - 1)
			var x := i % w
			var y := int(i / w)
			ter += 1
			minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
			for dd in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]:
				var nx: int = x + dd[0]
				var ny: int = y + dd[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni := ny * w + nx
				if maszk[ni] == 1 and cimke[ni] == 0:
					cimke[ni] = id
					sor.append(ni)
		dobozok.append([Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1), ter])
	dobozok.sort_custom(func(p: Array, q: Array) -> bool: return int(p[1]) > int(q[1]))
	var nagy: Array = []
	for d in dobozok:
		if nagy.size() < varni and int(d[1]) > w * h * 0.004:
			nagy.append(d[0])
		elif not nagy.is_empty():
			# kis folt: a legközelebbi nagy doboz kapja meg (ha elég közel van)
			var r: Rect2i = d[0]
			var legj := -1
			var tav := 1e9
			for k in nagy.size():
				var nr: Rect2i = nagy[k]
				var t := Vector2(nr.get_center()).distance_to(Vector2(r.get_center())) - maxf(nr.size.x, nr.size.y) * 0.5
				if t < tav:
					tav = t
					legj = k
			if legj >= 0 and tav < w * 0.03:
				nagy[legj] = (nagy[legj] as Rect2i).merge(r)
	var out: Array = []
	for r in nagy:
		var rr: Rect2i = r
		out.append(Rect2i(maxi(0, rr.position.x * L - L), maxi(0, rr.position.y * L - L),
			mini(img.get_width() - rr.position.x * L + L, rr.size.x * L + 2 * L), mini(img.get_height() - rr.position.y * L + L, rr.size.y * L + 2 * L)))
	return out


## A dobozok sorfolytonos rendbe: előbb sorok szerint (a közepük magassága), soron belül balról jobbra.
func _sorba(dobozok: Array, cols: int, rows: int) -> Array:
	var l := dobozok.duplicate()
	l.sort_custom(func(p: Rect2i, q: Rect2i) -> bool: return p.get_center().y < q.get_center().y)
	var out: Array = []
	for r in rows:
		var sor: Array = l.slice(r * cols, (r + 1) * cols)
		sor.sort_custom(func(p: Rect2i, q: Rect2i) -> bool: return p.get_center().x < q.get_center().x)
		out.append_array(sor)
	return out
