class_name Audio
extends Node
## Hangok fájlok nélkül: indításkor szintetizált AudioStreamWAV-ok (az eredeti WebAudio hangok mintájára).
## Zene: rétegzett, sötét aláfestés — zúgó basszus + vonós pad + kórus hurok (hibátlanul ismétlődik),
## rá véletlen ütemben furulyadallam, kísértetszólam, csepegő harangok, sóhajok és szívverés.

const SR := 22050
const MSR := 16000           # a zene mintavétele (mély, lágy hangok: ennyi bőven elég)
const MASTER := 0.6
const MUSIC_GAIN := 0.22

var muted := false
var music_started := false
var _sfx := {}               # név -> Array[AudioStreamWAV] (változatok)
var _players: Array[AudioStreamPlayer] = []
var _pi := 0
var _mplayers: Array[AudioStreamPlayer] = []
var _mpi := 0
var _loop_player: AudioStreamPlayer
var _thread: Thread
var _mus := {}
var _t := 0.0
var _next := {}
var _mel_idx := 0
var _phrase_gen := 0
var _ghost_idx := 0

const MEL_SCALE := [110, 123.47, 130.81, 146.83, 164.81, 174.61, 196, 220, 246.94, 261.63, 293.66, 329.63]
const PHRASE_A := [0, 2, 1, 0, 4, 3, 2, 0, 5, 4, 3, 2, 6, 5, 4, 0]
const PHRASE_B := [2, 4, 5, 4, 2, 0, 3, 2, 1, 3, 4, 2, 5, 4, 3, 1]
const GHOST_SCALE := [220, 261.63, 293.66, 329.63, 392, 440, 523.25, 587.33]
const GHOST_PHRASE := [0, 2, 4, 3, 1, 0, 5, 4, 2, 1, 3, 2, 0, 4, 3, 1]
const DRIP_BASES := [110, 138.59, 164.81, 185, 220, 246.94, 277.18, 293.66]
const BREATH_NOTES := [110, 130.81, 146.83, 164.81, 196]


func setup(with_music: bool) -> void:
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.volume_db = linear_to_db(MASTER)
		add_child(p)
		_players.append(p)
	_build_sfx()
	if with_music:
		for i in 16:
			var p := AudioStreamPlayer.new()
			p.volume_db = linear_to_db(MASTER)
			add_child(p)
			_mplayers.append(p)
		_loop_player = AudioStreamPlayer.new()
		add_child(_loop_player)
		_thread = Thread.new()
		_thread.start(_gen_music)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)


func play(n: String) -> void:
	if muted or not _sfx.has(n):
		return
	var arr: Array = _sfx[n]
	var p := _players[_pi]
	_pi = (_pi + 1) % _players.size()
	p.stream = arr[randi() % arr.size()]
	p.play()


# ══════════ ALAPOK ══════════
static func to_wav(buf: PackedFloat32Array, sr: int, loop := false) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize(buf.size() * 2)
	for i in buf.size():
		b.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


## RBJ biquad szűrő (lowpass / highpass / bandpass), menet közben változtatható frekvenciával
class Biquad:
	var type := "lowpass"
	var q := 1.0
	var sr := 22050.0
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func _init(t: String, f: float, qq: float, rate: float) -> void:
		type = t
		q = qq
		sr = rate
		set_freq(f)

	func set_freq(f: float) -> void:
		var w0 := TAU * clampf(f, 10.0, sr * 0.45) / sr
		var cw := cos(w0)
		var al := sin(w0) / (2.0 * q)
		var a0 := 1.0 + al
		if type == "lowpass":
			b0 = (1.0 - cw) / 2.0; b1 = 1.0 - cw; b2 = (1.0 - cw) / 2.0
		elif type == "highpass":
			b0 = (1.0 + cw) / 2.0; b1 = -(1.0 + cw); b2 = (1.0 + cw) / 2.0
		else:
			b0 = al; b1 = 0.0; b2 = -al
		a1 = -2.0 * cw
		a2 = 1.0 - al
		b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0

	func process(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		return y


static func _buf(dur: float, sr: int = SR) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * sr))
	return b


## exponenciális átmenet v0 -> v1 a [t0, t1] időben (utána v1 marad)
static func xr(t: float, t0: float, t1: float, v0: float, v1: float) -> float:
	if t <= t0: return v0
	if t >= t1: return v1
	return v0 * pow(v1 / v0, (t - t0) / (t1 - t0))


static func lr(t: float, t0: float, t1: float, v0: float, v1: float) -> float:
	if t <= t0: return v0
	if t >= t1: return v1
	return v0 + (v1 - v0) * (t - t0) / (t1 - t0)


# ══════════ HANGEFFEKTEK ══════════
func _build_sfx() -> void:
	_sfx["step"] = [_step(), _step(), _step()]
	_sfx["sword"] = [_sword()]
	_sfx["growl"] = [_growl(), _growl(), _growl(), _growl()]
	_sfx["shoot"] = [_shoot()]
	_sfx["magic"] = [_magic()]
	_sfx["cannon"] = [_cannon()]
	_sfx["hit"] = [_hit()]
	_sfx["chest"] = [_arp([523, 659, 784, 1047], 0.08, 0.12, 0.35, "sine")]
	_sfx["levelup"] = [_arp([392, 494, 587, 784], 0.09, 0.15, 0.4, "triangle")]
	_sfx["death"] = [_death()]


func _step() -> AudioStreamWAV:
	var b := _buf(0.08)
	var f := Biquad.new("lowpass", 300 + randf() * 150, 1.0, SR)
	for i in b.size():
		var t := float(i) / SR
		b[i] = f.process(randf() * 2 - 1) * xr(t, 0, 0.07, 0.25, 0.001)
	return to_wav(b, SR)


func _sword() -> AudioStreamWAV:
	var b := _buf(0.17)
	var hp := Biquad.new("highpass", 3000, 1.0, SR)
	var ph := [0.0, 0.0]
	var frs := [880.0, 1320.0]
	for i in b.size():
		var t := float(i) / SR
		var v := 0.0
		for k in 2:
			var fr: float = xr(t, 0, 0.12, frs[k], frs[k] * 0.4)
			ph[k] = fmod(ph[k] + fr / SR, 1.0)
			v += (1.0 if ph[k] < 0.5 else -1.0) * xr(t, 0, 0.15, 0.12, 0.001)
		v += hp.process(randf() * 2 - 1) * xr(t, 0, 0.1, 0.15, 0.001)
		b[i] = v
	return to_wav(b, SR)


func _growl() -> AudioStreamWAV:
	var b := _buf(0.45)
	var base := 55 + randf() * 35
	var lfo_f := 18 + randf() * 12
	var lp := Biquad.new("lowpass", 500, 1.0, SR)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var fr := lr(t, 0, 0.35, base, base * 0.7) + sin(TAU * lfo_f * t) * base * 0.4
		ph = fmod(ph + fr / SR, 1.0)
		var saw := 2.0 * (ph - floorf(ph + 0.5))
		var g := lr(t, 0, 0.05, 0.001, 0.18) if t < 0.05 else xr(t, 0.05, 0.4, 0.18, 0.001)
		b[i] = lp.process(saw) * g
	return to_wav(b, SR)


func _shoot() -> AudioStreamWAV:
	var b := _buf(0.26)
	var bp := Biquad.new("bandpass", 600, 6.0, SR)
	for i in b.size():
		var t := float(i) / SR
		if i % 16 == 0:
			bp.set_freq(xr(t, 0, 0.2, 600, 3200))
		b[i] = bp.process(randf() * 2 - 1) * xr(t, 0, 0.25, 0.22, 0.001) * 2.5
	return to_wav(b, SR)


## varázsgömb: csilingelő, felfelé ívelő hang
func _magic() -> AudioStreamWAV:
	var b := _buf(0.45)
	var notes := [[660.0, 0.0], [990.0, 0.04], [1320.0, 0.08]]
	var ph := [0.0, 0.0, 0.0]
	for i in b.size():
		var t := float(i) / SR
		var v := 0.0
		for k in 3:
			var fr: float = notes[k][0]
			var dl: float = notes[k][1]
			if t < dl or t > dl + 0.32:
				continue
			var tt := t - dl
			ph[k] = fmod(ph[k] + xr(tt, 0, 0.22, fr, fr * 1.6) / SR, 1.0)
			var g := xr(tt, 0, 0.02, 0.0001, 0.09) if tt < 0.02 else xr(tt, 0.02, 0.3, 0.09, 0.0001)
			v += sin(TAU * ph[k]) * g
		b[i] = v
	return to_wav(b, SR)


func _cannon() -> AudioStreamWAV:
	var b := _buf(0.42)
	var lp := Biquad.new("lowpass", 900, 1.0, SR)
	for i in b.size():
		var t := float(i) / SR
		if i % 16 == 0:
			lp.set_freq(xr(t, 0, 0.35, 900, 80))
		b[i] = lp.process(randf() * 2 - 1) * xr(t, 0, 0.4, 0.4, 0.001) * 1.6
	return to_wav(b, SR)


func _hit() -> AudioStreamWAV:
	var b := _buf(0.13)
	var lp := Biquad.new("lowpass", 700, 1.0, SR)
	for i in b.size():
		var t := float(i) / SR
		b[i] = lp.process(randf() * 2 - 1) * xr(t, 0, 0.12, 0.3, 0.001) * 1.4
	return to_wav(b, SR)


func _arp(frs: Array, step: float, peak: float, decay: float, wave: String) -> AudioStreamWAV:
	var b := _buf(step * frs.size() + decay + 0.1)
	for i in b.size():
		var t := float(i) / SR
		var v := 0.0
		for k in frs.size():
			var t0: float = k * step
			if t < t0 or t > t0 + decay + 0.05:
				continue
			var tt := t - t0
			var x: float = fmod(frs[k] * tt, 1.0)
			var osc := sin(TAU * x) if wave == "sine" else (4.0 * absf(x - 0.5) - 1.0)
			var g := lr(tt, 0, 0.02, 0.001, peak) if tt < 0.02 else xr(tt, 0.02, decay, peak, 0.001)
			v += osc * g
		b[i] = v
	return to_wav(b, SR)


func _death() -> AudioStreamWAV:
	var b := _buf(0.9)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		ph = fmod(ph + xr(t, 0, 0.8, 220, 40) / SR, 1.0)
		b[i] = 2.0 * (ph - floorf(ph + 0.5)) * xr(t, 0, 0.85, 0.2, 0.001)
	return to_wav(b, SR)


# ══════════ ZENE (külön szálon készül) ══════════
static func _q(f: float, L: float) -> float:
	return roundf(f * L) / L   # egész számú rezgés a hurokban -> hibátlan ismétlődés


func _gen_music() -> void:
	var out := {}
	out["loop"] = to_wav(_music_loop(), MSR, true)
	out["flute"] = to_wav(_flute(), MSR)
	out["ghost"] = to_wav(_ghost(), MSR)
	out["bell"] = to_wav(_bell(), MSR)
	out["breath"] = to_wav(_breath(), MSR)
	out["heart"] = to_wav(_heart(), MSR)
	call_deferred("_music_done", out)


func _music_done(out: Dictionary) -> void:
	print("Zene elkészült: %.1f mp" % (Time.get_ticks_msec() / 1000.0))
	_mus = out
	_loop_player.stream = _mus["loop"]
	_loop_player.volume_db = -60.0
	_loop_player.play()
	var tw := create_tween()
	tw.tween_property(_loop_player, "volume_db", linear_to_db(MASTER), 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	music_started = true
	_t = 0.0
	_next = {"breath": 0.8, "mel": 5.0, "ghost": 8.5, "drip": 1.5, "heart": 2.5}


## zúgó basszus + vonós pad + sötét kórus, 24 mp-es, hibátlanul ismétlődő hurok
func _music_loop() -> PackedFloat32Array:
	var L := 24.0
	var n := int(L * MSR)
	var b := PackedFloat32Array()
	b.resize(n)
	var oscs: Array = []   # [frek, amp, forma(0 szinusz, 1 háromszög), lfo_frek, lfo_mély]
	# 1. mély zúgás (lebegő párok)
	var drones := [[55.0, 55.28, 1, 0.20], [82.41, 82.70, 2, 0.09], [36.71, 36.60, 1, 0.12]]
	for i in drones.size():
		var d: Array = drones[i]
		var lf := _q(0.035 + i * 0.013, L)
		lf = maxf(lf, 1.0 / L)
		oscs.append([_q(d[0], L), d[3], d[2], lf, 0.08])
		oscs.append([_q(d[1], L), d[3], d[2], lf, 0.08])
	# 3. vonós pad: Am (A3-C4-E4-G4-H4)
	var pad := [220.0, 261.63, 329.63, 392.0, 493.88]
	for i in pad.size():
		var f: float = pad[i]
		oscs.append([_q(f * (1 + i * 0.00035), L), 0.038, 2, 1.0 / L, 0.24])
		oscs.append([_q(f * 1.0028, L), 0.038, 1, 1.0 / L, 0.24])
	var nf := oscs.size()
	var ph := PackedFloat32Array()
	var inc := PackedFloat32Array()
	var h3 := PackedFloat32Array()
	var gain := PackedFloat32Array()
	var oa := PackedFloat32Array()
	var olf := PackedFloat32Array()
	var old := PackedFloat32Array()
	for o in oscs:
		ph.append(0.0)
		inc.append(float(o[0]) / MSR)
		h3.append(0.0 if o[2] == 1 else (1.0 / 9.0) * (1.0 if float(o[0]) * 3.0 < 900.0 else 0.3))
		gain.append(0.0)
		oa.append(o[1])
		olf.append(o[3])
		old.append(o[4])
	# 4. kórus: AM/FM moduláció, a sávszűrő hatása hangonként előre kiszámolva
	var choir := [220.0, 220 * 1.189, 220 * 1.498, 220 * 1.782]
	var cph := PackedFloat32Array()
	cph.resize(4)
	var cfr := PackedFloat32Array()
	var cmr := PackedFloat32Array()
	var camp := PackedFloat32Array()
	for i in 4:
		var f: float = _q(choir[i], L)
		cfr.append(f)
		cmr.append(_q(3.2 + i * 0.7, L))
		var bpg := 1.0 / sqrt(1.0 + 1.96 * pow(f / 520.0 - 520.0 / f, 2))
		camp.append((0.022 - i * 0.004) * 0.9 * bpg)
	for s in n:
		var t := float(s) / MSR
		if s % 64 == 0:
			for k in nf:
				gain[k] = oa[k] * (1.0 + old[k] * sin(TAU * olf[k] * t))
		var v := 0.0
		for k in nf:
			var p := ph[k] + inc[k]
			if p >= 1.0:
				p -= 1.0
			ph[k] = p
			var x := TAU * p
			v += (sin(x) - sin(3.0 * x) * h3[k]) * gain[k]
		for k in 4:
			var cp2 := cph[k] + (cfr[k] + cfr[k] * 0.012 * sin(TAU * cmr[k] * t)) / MSR
			if cp2 >= 1.0:
				cp2 -= 1.0
			cph[k] = cp2
			v += sin(TAU * cp2) * camp[k]
		b[s] = v * MUSIC_GAIN * 1.4
	return b


## furulyahang 220 Hz-en (a többi hangmagasság lejátszási sebességgel), visszhanggal
func _flute() -> PackedFloat32Array:
	var f := 220.0
	var dur := 0.7
	var n := int((dur + 0.25 + 0.9) * MSR)
	var dry := PackedFloat32Array()
	dry.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	var vib := 5.6
	for s in n:
		var t := float(s) / MSR
		var g := 0.0
		if t < 0.08: g = lr(t, 0, 0.08, 0.0, 0.062)
		elif t < dur * 0.5: g = 0.062
		else: g = xr(t, dur * 0.5, dur + 0.22, 0.062, 0.001)
		if t > dur + 0.22: g = 0.0
		ph = fmod(ph + (f + sin(TAU * vib * t) * f * 0.013) / MSR, 1.0)
		ph2 = fmod(ph2 + 2.0 * f / MSR, 1.0)
		var tri := 4.0 * absf(ph2 - 0.5) - 1.0
		dry[s] = (sin(TAU * ph) + tri * 0.18) * g
	return _echo(dry, [[0.28, 0.22], [0.84, 0.022]])


func _ghost() -> PackedFloat32Array:
	var f := 440.0
	var dur := 1.6
	var n := int((dur + 0.7 + 1.4) * MSR)
	var dry := PackedFloat32Array()
	dry.resize(n)
	var ph := 0.0
	for s in n:
		var t := float(s) / MSR
		var g := lr(t, 0, 0.18, 0.0, 0.032) if t < 0.18 else xr(t, 0.18, dur + 0.6, 0.032, 0.001)
		if t > dur + 0.6: g = 0.0
		ph = fmod(ph + (f + sin(TAU * 3.8 * t) * f * 0.008) / MSR, 1.0)
		dry[s] = sin(TAU * ph) * g
	return _echo(dry, [[0.45, 0.30], [1.35, 0.042]])


static func _echo(dry: PackedFloat32Array, taps: Array) -> PackedFloat32Array:
	var out := dry.duplicate()
	for tp in taps:
		var dl := int(tp[0] * MSR)
		var g: float = tp[1]
		for s in range(dl, out.size()):
			out[s] += dry[s - dl] * g
	for s in out.size():
		out[s] *= MUSIC_GAIN * 2.2
	return out


## csepegő harang (inharmonikus részhangok, hosszú lecsengés)
func _bell() -> PackedFloat32Array:
	var f := 220.0
	var n := int(4.7 * MSR)
	var b := PackedFloat32Array()
	b.resize(n)
	var ratios := [1.0, 2.756, 5.404]
	var vols := [0.052, 0.022, 0.009]
	for s in n:
		var t := float(s) / MSR
		var v := 0.0
		for i in 3:
			var decay := 4.5 - i * 1.2
			if t > decay:
				continue
			var g := lr(t, 0, 0.01, 0.0, vols[i]) if t < 0.01 else xr(t, 0.01, decay, vols[i], 0.001)
			v += sin(TAU * f * ratios[i] * t) * g
		b[s] = v * MUSIC_GAIN * 2.5
	return b


## "sóhaj": sávszűrt zaj hullám
func _breath() -> PackedFloat32Array:
	var dur := 8.5
	var n := int(dur * MSR)
	var b := PackedFloat32Array()
	b.resize(n)
	var bp := Biquad.new("bandpass", 220, 8.0, MSR)
	for s in n:
		var t := float(s) / MSR
		var g := lr(t, 0, dur * 0.35, 0.0, 0.037) if t < dur * 0.35 else lr(t, dur * 0.35, dur, 0.037, 0.0)
		b[s] = bp.process(randf() * 2 - 1) * g * MUSIC_GAIN * 6.0
	return b


## szívverés (lub-dub), közvetlenül a fő hangerőre
func _heart() -> PackedFloat32Array:
	var n := int(0.7 * MSR)
	var b := PackedFloat32Array()
	b.resize(n)
	for beat in 2:
		var off := int((0.0 if beat == 0 else 0.36) * MSR)
		var ln := int(0.22 * MSR)
		var lp := Biquad.new("lowpass", 280, 1.0, MSR)
		var peak := 0.46 if beat == 0 else 0.24
		for i in ln:
			var t := float(i) / MSR
			if i % 8 == 0:
				lp.set_freq(xr(t, 0, 0.22, 280, 50))
			var src := (randf() * 2 - 1) * exp(-i / (ln * 0.2))
			if off + i < n:
				b[off + i] += lp.process(src) * xr(t, 0, 0.28, peak, 0.001) * 2.0
	return b


func _mplay(key: String, pitch: float, vol := 1.0) -> void:
	if muted or not _mus.has(key):
		return
	var p := _mplayers[_mpi]
	_mpi = (_mpi + 1) % _mplayers.size()
	p.stream = _mus[key]
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(MASTER * vol)
	p.play()


func _process(delta: float) -> void:
	if not music_started or _mus.is_empty() or _next.is_empty():
		return
	_t += delta
	if _t >= _next["breath"]:
		var dur := 6.0 + randf() * 5.0
		_mplay("breath", float(Data.pick(BREATH_NOTES)) * 2.0 / 220.0, 0.75 + randf() * 0.5)
		_next["breath"] = _t + dur * 0.6 + randf() * 4.0
	if _t >= _next["mel"]:
		var phrase: Array = PHRASE_B if _phrase_gen % 3 == 2 else PHRASE_A
		var tr: float = [1.0, 0.9439, 1.0595][_phrase_gen % 3]
		var f: float = MEL_SCALE[phrase[_mel_idx % phrase.size()]] * tr
		_mel_idx += 1
		if _mel_idx % phrase.size() == 0:
			_phrase_gen += 1
		_mplay("flute", f / 220.0)
		var rest := (randf() * 1.2 + 0.4) if _mel_idx % 5 == 0 else 0.0
		_next["mel"] = _t + 0.5 + rest
	if _t >= _next["ghost"]:
		var f: float = GHOST_SCALE[GHOST_PHRASE[_ghost_idx % GHOST_PHRASE.size()]]
		_ghost_idx += 1
		_mplay("ghost", f / 440.0)
		var rest := (randf() * 2.0 + 0.5) if _ghost_idx % 3 == 0 else 0.0
		_next["ghost"] = _t + 1.1 + rest
	if _t >= _next["drip"]:
		_mplay("bell", float(Data.pick(DRIP_BASES)) / 220.0)
		_next["drip"] = _t + 4.0 + randf() * 10.0
	if _t >= _next["heart"]:
		_mplay("heart", 1.0)
		_next["heart"] = _t + 1.8 + randf() * 0.9
