# Kard és Mágia

Roguelike kaland a katakombákban: **lovag, mágus vagy íjász**, öt mélység, öt főellenség
(Goblin Király, Nekromanta, Kő Titán, Árnyak Ura, Sárkány), kincsesládák és három élet.

A játék **Godot 4.7** (GDScript) natív változata; a korábbi böngészős/Electron kiadás
forrása referenciaként a `reference/index.html` fájlban maradt (az exportba nem kerül bele).

## Irányítás

| Billentyű | Mit csinál |
|---|---|
| WASD / nyilak | mozgás és támadás (lenyomva tartva folyamatos járás) |
| Ctrl (vagy `.` / `>`) | lépcső — lejjebb a következő mélységbe |
| I | táska (A–Z: tárgy használata / felvétele, görgő vagy ↑↓: görgetés) |
| Esc | menü / vissza |
| M vagy a 🔊 gomb | hang ki/be |
| F11 | teljes képernyő |

A billentyűk az *Irányítás* menüben átköthetők; a beállítás a `user://beallitasok.cfg`
fájlba mentődik.

## Kasztok

- **Lovag** (46 HP, ⚔ 9, 🛡 5): közelharcban ×1,35 sebzés, 20% eséllyel pajzzsal felfogja az
  ütés felét, szintenként +13 HP.
- **Íjász** (32 HP, ⚔ 6, 🛡 2): Faíjjal indul, lőtáv = íj + 1, íjjal 30% esély ×2,2-es
  kritikusra, közelről ×0,7, szintenként +10 HP.
- **Mágus** (26 HP, ✦ 11, 🛡 1): kék varázsgömb 5 mezőre (szomszédra is); varázssebzés =
  varázserő + (−1…3) − védelem/3 − varázsellenállás. Varázserő = alap + a fegyver sebzésének
  fele; szintenként +3.

## Tárgyak

- Fegyver, páncél és **pajzs** külön helyen; a védelem = alap + páncél + pajzs.
- Bájitalok és tekercsek ereje ritkaság szerint nő (×1 / 1,3 / 1,7 / 2,2).
- *Életerő töltő*: nagyobb max. életerő **és** teljes gyógyulás.
- Nagyon ritka / legendás fegyver: 10% / 20% **életlopás**; nagyon ritka / legendás páncél és
  pajzs: +1 / +2 HP **regeneráció** körönként (összeadódik).
- Tűzgömb tekercs: a mágusnál + varázserő; Erő tekercs a mágusnál 2× varázserő;
  Véd tekercs a lovagnál +2.

## Felépítés

| Fájl | Tartalom |
|---|---|
| `main.tscn`, `scripts/main.gd` | állapotgép, bemenet, rajzrétegek, képernyőkép-mód |
| `scripts/data.gd` | táblák: paletta, ritkaságok, nehézségek, tárgyak, szörnyek, kasztok |
| `scripts/dungeon.gd` | pályagenerálás, látómező, „sose lehessen bezáródni” biztosíték |
| `scripts/game.gd`, `world.gd`, `player.gd`, `mon.gd`, `item.gd` | játékszabályok |
| `scripts/cv.gd` | a canvas 2D rajzoló utánzata (útvonalak, ívek, görbék, színátmenetek, élsimítás) |
| `scripts/sprites.gd`, `menu_art.gd` | a rajzolt figurák, tárgyak, díszek és a menü borítóképe |
| `scripts/render.gd`, `screens.gd` | pálya + fények + HUD, illetve a menük és ablakok |
| `scripts/audio.gd` | szintetizált hangeffektek és háttérzene (hangfájlok nélkül) |
| `tests/run_tests.gd` | fej nélküli tesztek |

A pályák mindig bejárhatók: generálás után a játék ellenőrzi, hogy a kezdőpontról minden
mező, a lépcső és minden láda elérhető-e; ha nem, folyosót vág, a láda pedig sosem zárhat el
utat (áthelyezi, végső esetben eltünteti).

## Tesztek és képernyőképek

```
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
godot --path . -- --shot=_shots/menu.png --scene=menu
```

A `--scene` lehet: `menu`, `diff`, `char`, `help`, `play`, `orb`, `walk`, `inv`, `chest`,
`over`; a `--cls=Lovag|Mágus|Íjász` a hőst választja ki.

## Kiadás

Egy `v…` címke feltöltésekor (`git tag v2.0 && git push origin v2.0`) a GitHub Actions
(`.github/workflows/kiadas.yml`) Godot 4.7.2-vel lefuttatja a teszteket, elkészíti a
`kard_es_magia-windows.zip` (KardEsMagia.exe, beágyazott .pck) és a
`kard_es_magia-macos.zip` (univerzális .app, ad-hoc aláírással) csomagot, és GitHub-kiadásként
közzéteszi őket. A **ParthLauncher** innen tölti le és frissíti a játékot.