# Kard és Mágia

Roguelike kaland a katakombákban: **lovag, mágus vagy íjász**, öt mélység, öt főellenség
(Goblin Király, Nekromanta, Kő Titán, Árnyak Ura, Sárkány), kincsesládák és három élet.
Szintlépéskor **képességet választasz**, a mélységekben **kincstár, szentély, kereskedő és
csapdaterem** vár, rejtett csapdák és titkos ajtók lapulnak a falakban, a `Tab` pedig
**automata térképet** nyit. A kaland bármikor **menthető és folytatható**.

A játék **Godot 4.7** (GDScript) natív változata; a korábbi böngészős/Electron kiadás
forrása referenciaként a `reference/index.html` fájlban maradt (az exportba nem kerül bele).

## Irányítás

| Billentyű | Mit csinál |
|---|---|
| WASD / nyilak | mozgás és támadás (lenyomva tartva folyamatos járás) |
| Ctrl (vagy `.` / `>`) | lépcső — lejjebb a következő mélységbe |
| I | táska (A–Z: tárgy használata / felvétele, görgő vagy ↑↓: görgetés) |
| **Tab** | automata térkép ki/be |
| **K** | kutatás: titkos ajtók és rejtett csapdák a szomszédos mezőkön |
| **1 / 2 / 3** | választás a szintlépés-lapok és a kereskedő kínálata közül |
| Esc | játék közben: szünet-menü (**Mentés és kilépés**) · menüben: vissza |
| M vagy a 🔊 gomb | hang ki/be |
| F11 | teljes képernyő |

A mozgáshoz az `S` billentyű kell (WASD), ezért a **kutatás billentyűje `K`**, a térképé pedig
`Tab` (az `M` a hang).

A billentyűk az *Irányítás* menüben átköthetők; a beállítás a `user://beallitasok.cfg`
fájlba mentődik.

## Mentés és folytatás

A kaland bármikor folytatható: a mentés a `user://mentes.json` fájlba kerül, és a **teljes
állapotot** tartalmazza (pálya, csempék, bejárt mezők, fényerő, díszek, fáklyák, ládák,
csapdák, titkos ajtók, szentélyek, kereskedők, szörnyek, a hős értékei, felszerelése a
pajzshellyel együtt, táskája, képességei, életei, mérgezése, aranya, mélység, nehézség, körszám).

- **magától ment** minden szintváltáskor és amikor a főmenübe lépsz vissza;
- az Esc-menü **„Mentés és kilépés"** pontja kézzel is ment;
- a főmenüben a **„Folytatás"** gomb csak akkor jelenik meg, ha van érvényes mentés;
- a fájl verziószámot tartalmaz: régi vagy sérült mentésnél a játék nem ajánlja fel a folytatást;
- az elesett vagy a Sárkányt legyőző hős mentése törlődik (a „Feladás" is törli).

## Szintlépéskor választható képesség

Minden szintlépésnél három lap közül választhatsz (1 / 2 / 3 vagy kattintás). A képességek
halmozódnak, és a táska képernyőn végig láthatók.

| Kinek | Képesség | Hatás | Max |
|---|---|---|---|
| közös | Vas szervezet | +10 max. életerő (rögtön gyógyít is) | 5× |
| közös | Szívósság | +2 védelem | 4× |
| közös | Vérszívás | +5% életlopás | 3× |
| közös | Gyors gyógyulás | +1 életerő körönként | 3× |
| közös | Kincsvadász | +50% arany a szörnyekből | 2× |
| Lovag | Pajzsmester | +5% pajzsblokk-esély | 4× |
| Lovag | Vértezet | +3 védelem | 3× |
| Lovag | Pajzsdöfés | 25% esély egy környi kábításra | 2× |
| Íjász | Sasszem | +8% kritikus esély | 3× |
| Íjász | Hosszú íj | +1 lőtáv | 2× |
| Íjász | Gyors léptek | minden 5. lépés ingyen (nem telik kör) | 1× |
| Mágus | Mágikus fókusz | +2 varázserő | 4× |
| Mágus | Messzi gömb | a gömb 1 mezővel tovább repül | 2× |
| Mágus | Átütő gömb | 20% esély, hogy a gömb átüt a célponton | 2× |

## Kinézet bolt (kozmetika)

A főmenü **„✦ Kinézet bolt"** gombjával és játék közben az Esc-menüből érhető el. A hős
**négy helyről** áll össze — **fej, test, láb, fegyver** —, és a darabok szabadon keverhetők.
A kiválasztott összeállítás **kasztonként** a `user://beallitasok.cfg` fájlba mentődik, és
**mindenhol** látszik: a főmenüben, a hősválasztónál, játék közben, a táska képernyőn és a
bolt előnézetében.

- **A kozmetika soha nem befolyásol játékértéket** — csak a rajzot változtatja meg.
- Bal oldalt a hős előnézete, jobb oldalt a négy hely változatai; a már meglévő darab egy
  kattintással felvehető, a többin az ára és a **„Megvásárlás (X érme)"** gomb látszik.
- Billentyűzettel is megy: `↑↓` hely, `←→` darab, `Enter` felvesz/megvásárol, `Tab` másik hős,
  `E` érmevásárlás, `Esc` vissza. Az `1`–`4` gomb a sor adott darabját választja.
- Fent az **érme-egyenleg** és az **„◉ Érmét veszek"** gomb: a három Gumroad-csomagot
  (100 érme 0,99 $, 220 érme 1,99 $, 600 érme 4,99 $) a böngészőben nyitja meg.

| Kaszt | Fej (15 érme) | Test (20) | Láb (10) | Fegyver (20) |
|---|---|---|---|---|
| Lovag | Arany sisak · Szarvas sisak · Harci csuklya | Arany páncél · Sötét páncél · Koponyás vért | Vas lábvért · Bőr lábvért | Lángkard · Jégkard · Csatabárd |
| Mágus | Csillagos kalap · Sötét kalap · Mágus korona | Kék · Bíbor · Arany köntös | Kék csizma · Arany csizma | Kristálybot · Koponyás bot · Élőfa bot |
| Íjász | Zöld csuklya · Szürke csuklya · Tollas kalap | Bőrvért · Zöld köpeny · Vadász mellvért | Bőrcsizma · Magas szárú csizma | Tiszafa íj · Csontíj · Számszeríj |

**Fiók.** A bejelentkezést a **ParthLauncher** intézi: a Godot felhasználói mappájába írt
`fiok.json` fájlból (`{url, anon, email, access_token, refresh_token, mentve}`) olvassuk ki
az adatokat indításkor és a bolt megnyitásakor. Ha a fájl hiányzik, a bolt a
**„Jelentkezz be a ParthLauncherben"** üzenetet mutatja, és minden más változatlanul működik.
A lejárt hozzáférési kulcsot a játék magától frissíti (`/auth/v1/token?grant_type=refresh_token`),
és visszaírja a `fiok.json`-ba. Az érme-egyenleg (`my_coins`), a birtokolt darabok
(`cosmetics`) és a vásárlás (`buy-cosmetic`) lekérdezése **aszinkron** (`HTTPRequest`), így
internet nélkül sem akad meg és nem omlik össze a játék — csak egy barátságos üzenet jelenik meg.
A kulcsok és az árak a kiszolgálón rögzítettek (`<kaszt>_<hely>_<név>`; fegyver/test 20, fej 15,
láb 10 érme); a teszt soronként összeveti őket a játékban lévő táblával.

## Különleges termek, csapdák, titkos ajtók

Minden mélységen négy terem kap külön szerepet:

- **Kincstár** — két láda értékesebb zsákmánnyal, és egy erős **őr** (másfélszeres életerő,
  háromszoros arany).
- **Szentély** — egyszer használható áldás: teljes gyógyulás, +1 élet, +2 védelem vagy
  +3 varázserő. Elég rálépni.
- **Kereskedő** — a szörnyekből hulló **aranyért** vásárolsz (bájital, egy véletlen tárgy vagy
  teljes gyógyítás, 10–60 arany). Az arany *nem* a boltban vett érme, hanem a játékon belüli pénz.
- **Csapdaterem** — sok rejtett csapda és egy garantált láda.

**Csapdák** (rejtettek, rálépve sülnek el, vagy szomszédos mezőről lehet észrevenni —
az íjász sokkal gyakrabban): *tüske* (a max. életerő 8–15%-a), *méreg* (sebzés + mérgezés),
*riasztó* (10 mezőn belül felébreszti a szörnyeket). Csapda csak szobák belsejébe kerül,
sosem a kezdőmezőre vagy a lépcsőre, így sosem áll az egyetlen út közepén.

**Titkos ajtók** falnak látszanak: van, amelyik rövidítést nyit, van, amelyik egy ládás
kamrát. Kutatással (`K`) mindig kinyithatók, vagy maguktól is felfedeződnek, ha mellettük
állsz. A bejárhatóság-ellenőrzés átjárhatónak veszi őket — így a mögöttük lévő rész sem
„szakad le" a pályáról.

## Automata térkép (Tab)

A bal felső sarokban kis térkép mutatja a bejárt mezőket, a lépcsőt, a különleges termeket
(saját színükkel) és a hőst. A térkép egy 80×60-as textúra, amely **csak az újonnan felfedezett
mezőkkel** frissül, a rajzréteg pedig csak akkor rajzolódik újra, ha tényleg változott a
felderített terület — így a kirajzolása egyetlen textúra-hívás.

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
- **Arany**: minden legyőzött szörny ejt néhányat (a főellenség 45–80-at, a kincstár őre
  háromszor annyit), és csak a **kereskedőnél** költhető el. Az aranyad a HUD-on és a táskában
  is látszik.

## Felépítés

| Fájl | Tartalom |
|---|---|
| `main.tscn`, `scripts/main.gd` | állapotgép, bemenet, rajzrétegek, automata térkép, képernyőkép-mód |
| `scripts/data.gd` | táblák: paletta, ritkaságok, nehézségek, tárgyak, szörnyek, kasztok, termek, csapdák |
| `scripts/dungeon.gd` | pályagenerálás, látómező, „sose lehessen bezáródni” biztosíték, termek, csapdák, titkos ajtók |
| `scripts/game.gd`, `world.gd`, `player.gd`, `mon.gd`, `item.gd` | játékszabályok |
| `scripts/perks.gd` | a szintlépéskor választható képességek táblája és hatásai |
| `scripts/save.gd` | mentés és betöltés (`user://mentes.json`, verziószámmal) |
| `scripts/cv.gd` | a canvas 2D rajzoló utánzata (útvonalak, ívek, görbék, színátmenetek, élsimítás) |
| `scripts/sprites.gd`, `menu_art.gd` | a rajzolt figurák, tárgyak, díszek és a menü borítóképe |
| `scripts/skins.gd` | a kinézet-alkatrészek (fej/test/láb/fegyver) katalógusa, mentése és rajza |
| `scripts/fiok.gd` | fiók (`fiok.json`), érme-egyenleg, birtokolt darabok, vásárlás (aszinkron HTTP) |
| `scripts/render.gd`, `screens.gd` | pálya + fények + HUD, illetve a menük és ablakok |
| `scripts/audio.gd` | szintetizált hangeffektek és háttérzene (hangfájlok nélkül) |
| `tests/run_tests.gd` | fej nélküli tesztek (pályák, harc, tárgyak, termek/csapdák, képességek, mentés, kozmetika) |

A pályák mindig bejárhatók: generálás után a játék ellenőrzi, hogy a kezdőpontról minden
mező, a lépcső és minden láda elérhető-e; ha nem, folyosót vág, a láda pedig sosem zárhat el
utat (áthelyezi, végső esetben eltünteti). A különleges termek csak a szoba *tartalmát*
változtatják meg, a csapdák és a szentély/kereskedő járható mezőn állnak, a titkos ajtó pedig
kutatással mindig kinyitható — így egyik új elem sem sértheti ezt a biztosítékot. A teszt
mind a 300 pályán ellenőrzi ezt.

## Tesztek és képernyőképek

```
godot --headless --path . --import
godot --headless --path . -s res://tests/parse_check.gd
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . -s res://tests/bench.gd
godot --path . -- --shot=_shots/menu.png --scene=menu
godot --path . -- --shot=_shots/terkep.png --scene=map --size=1024x768
```

A `--scene` lehet: `menu`, `diff`, `char`, `help`, `play`, `orb`, `walk`, `inv`, `chest`,
`over`, valamint **`perk`** (képességválasztó), **`shop`** (a játékon belüli **kereskedő**),
**`bolt`** (a **kinézet bolt** alaphelyzetben), **`bolt_preview`** (kinézet bolt felvett
összeállítással — `shop_preview` néven is), **`trap`** (csapdák és titkos ajtó), **`map`**
(automata térkép), **`pause`** (szünet-menü) és **`load`** (főmenü mentéssel). A `--cls=Lovag|Mágus|Íjász` a hőst választja ki, a `--size=SZÉLESSÉGxMAGASSÁG`
pedig az elrendezést (alapból 1280×800) — ezzel ellenőrizhető, hogy semmi nem lóg ki
kisebb képernyőn sem.

## Kiadás

Egy `v…` címke feltöltésekor (`git tag v2.0 && git push origin v2.0`) a GitHub Actions
(`.github/workflows/kiadas.yml`) Godot 4.7.2-vel lefuttatja a teszteket, elkészíti a
`kard_es_magia-windows.zip` (KardEsMagia.exe, beágyazott .pck) és a
`kard_es_magia-macos.zip` (univerzális .app, ad-hoc aláírással) csomagot, és GitHub-kiadásként
közzéteszi őket. A **ParthLauncher** innen tölti le és frissíti a játékot.