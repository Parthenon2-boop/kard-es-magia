# Kard és Mágia

Roguelike kaland a katakombákban: **lovag, mágus vagy íjász**, öt mélység, öt főellenség
(Goblin Király, Nekromanta, Kő Titán, Árnyak Ura, Sárkány), kincsesládák és három élet.
Szintlépéskor **képességet választasz**, a mélységekben **kincstár, szentély, kereskedő és
csapdaterem** vár, rejtett csapdák és titkos ajtók lapulnak a falakban, a `Tab` pedig
**automata térképet** nyit. A kaland bármikor **menthető és folytatható**.

## Gorgona (történet, képességek, Műtőterem)

A játék a *Flesh & Cog* történetét meséli el (`flesh_cog_teljes_narrat_v_s_vil_g_p_t_si_tmutat.md`):
Vane, az Elfeledett Sebész ereszkedik le a lebegő henger-város, Gorgona tetejéről a Belső Magig.

- **Négy zóna** saját színvilággal és zenével: Csatorna-Kazánok → Bronz Klinika → Tüdő-Kert → Mag-Kamra
  (`scripts/story.gd`). A lejáratot a zóna ura őrzi: **Rozsdaféreg, Karel Doktor, Szimbióta Anya,
  Az Első Kárpit** — mind kétfázisú, párbeszéddel, és **előre jelzett csapásokkal** (a pirosan
  villogó mező egy kör múlva robban).
- **Aktív képességek:** `Szóköz` félreugrás (nem telik vele kör), `Q` a test képessége
  (Forgószél / Gőzrobbanás / Nyílzápor), `E` gyors gyógyital. A lehűlés a HUD-on látszik.
- **Bevezető és befejezés** festett, mozgó képsorokkal (`art/*.jpg`) és saját zenével; a főellenségnél
  a zene dobogóra vált (`scripts/audio.gd`: `set_mood`).
- **Feljegyzések és Napló:** zónánként két megtalálható lap (főmenü → Napló, `J`).
- **Műtőterem** (főmenü → Műtőterem, `H`; halál után ide kerülsz): a szörnyekből gyűlő
  **Bio-Hulladékért** a Megnyúzott Próféta, **Rézötvözetért** Nora, a Csontkovács varr állandó
  fejlesztést az új testre (`scripts/meta.gd`, mentve: `user://gorgona.json`).
- Új szörnyek (Gőzpatkány, Automata-ápoló, Lebegő szike, Tüdőspóra), **Fertőzött** elitek, új tárgyak
  (Láncfogazású Szike, Gőzsugár-Karbély) és beültetések (Savas Epehólyag, Réz-Idegfonat, Túlhevített tartály).

### 4.1: animációk, ereklyék, események, a Sebész, napi kihívás

- **Animációk:** a szörnyek ütéskor nekilendülnek, halálkor összeroskadnak; a lövés visszarúg; a
  főellenség belépőjénél és halálánál a kamera ráúszik, fázisváltáskor a figura megnő és a kép
  felvillan. **Élő pálya:** gőzszelepek, fogaskerekek, csöpögő csövek, lüktető erek a falakon
  (`Sprites2.prop`). A főmenü háttere a lassan úszó Gorgona; a képsorok előtt rajzolt előtér-réteg
  mozog gyorsabban, mint a festmény (mélységhatás).
- **Ereklyék** (`scripts/relics.gd`): tíz darab, a főellenségek és a mini-bossok talapzatán két lap
  közül választva. Egymást erősítik (Gyújtókamra + Savmirigy + Robbanó epe; Tesla-tekercs + Rézbőr...).
  Új szörny-állapotok: égés, marás (−2 védelem rétegenként), vérzés.
- **Zóna-veszélyek és események:** padlórácsok szabályos ütemben törnek ki (előtte egy körrel
  jeleznek); zónánként egy **mini-boss** (Patkánykirály, Főnővér, Anyaspóra, Olvadt Őr) és egy
  **döntési esemény** két válasszal (ötödik különleges terem).
- **A Sebész:** negyedik hős, a Bronz Klinika elérésével oldódik fel. Vágásai vérzést okoznak, a
  legyőzöttekből szerveket operál ki, a `Q` (Beültetés) ezekből gyógyít és erősít.
- **Napi kihívás** (`scripts/daily.gd`, főmenü, `N`): aznap mindenkinek ugyanaz a pálya, a Műtőterem
  fejlesztései nélkül; a pontszám belépve a ranglistára kerül
  (`Birodalom_Godot/server/supabase/schema_kem_napi.sql`). **Jelvények:** nyolc teljesítmény a Műtőteremben.

Képernyőkép-jelenetek ehhez: `harc`, `relic`, `event`, `daily`; élő próbák: `tests/felho_elo.gd`,
`tests/napi_elo.gd`.

Képernyőkép-jelenetek ehhez: `intro`, `ending` (`--depth=N` a képsor sorszáma), `hub`, `journal`,
`boss`, `boss2`, `dialog`, `note`.

A játék **Godot 4.7** (GDScript) natív változata; a korábbi böngészős/Electron kiadás
forrása referenciaként a `reference/index.html` fájlban maradt (az exportba nem kerül bele).

## Nyelvek (magyar / angol / német)

A játék teljes egészében játszható **magyarul, angolul és németül**. A főmenü bal felső sarkában
(és az *Irányítás* képernyőn) a **HU / EN / DE** gombbal, a főmenüben az `L` billentyűvel is
válthatsz — azonnal, újraindítás nélkül (a már kiírt üzenetnapló is átvált). A választás a
`user://beallitasok.cfg` fájlba mentődik; első indításkor a rendszer nyelve dönt (ha nem
magyar/angol/német, akkor angol).

- Minden látható szöveg a `lang/hu.json`, `lang/en.json`, `lang/de.json` fájlban van
  (kulcs → szöveg, `{0}`, `{1}` helyőrzőkkel); a kód csak kulcsot használ: `Lang.T("menu.quit")`.
- Az üzenetnaplóba és a mentésbe **nem kerül lefordított szöveg**, csak hivatkozás
  (`Lang.ref(kulcs, ...)`), a tárgyak pedig belső azonosítóval mentődnek (pl. `moonlight_blade`).
  A régi mentések magyar tárgynevei betöltéskor azonosítóvá alakulnak.
- Új szövegnél elég a három JSON-ba felvenni a kulcsot; a teszt (8. rész) jelzi, ha valamelyik
  nyelvből hiányzik, ha fölösleges, vagy ha a helyőrzők nem egyeznek.

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

**Több mentés.** Minden mentés külön fájl a `user://mentesek/` mappában, és a teljes állapotot tartalmazza
(pálya, szörnyek, a hős, a főellenség fázisa, veszélyzónák, feljegyzések...).

- minden kalandnak van egy **automata mentése**: szintváltáskor és a főmenübe lépéskor frissül;
- az Esc-menü **„Mentés új helyre”** pontja (vagy a mentéslistán az `N`) **kézi mentést** készít — akárhányat.
  A kézi mentést a játék soha nem írja felül: ha abból folytatod, az automata mentés új helyre kerül;
- **Mentések** képernyő (főmenü → Mentések, `B`; játék közben Esc → Mentések / betöltés): bármelyik mentés
  bármikor visszatölthető vagy törölhető (a törlés második kattintásra történik);
- a főmenü **„Folytatás”** gombja a legfrissebb mentést tölti;
- az elesett vagy a Magot újraindító hősnek csak az automata mentése törlődik, a kézi mentései megmaradnak;
- a fájl verziószámot tartalmaz: régi vagy sérült mentés nem jelenik meg a listán. A korábbi, egyetlen
  `mentes.json` magától átköltözik a mappába.

**Felhő-mentés.** Ha a játék a ParthLauncherből, belépve indul, a `mentesek` mappa (a kalandok és a
Műtőterem állása, `_gorgona.json`) a **fiókhoz** kötődik: másik gépen belépve a mentések maguktól megjelennek
a listán (☁ jel). A közös modul a `scripts/felho_mentes.gd` (ugyanez van a többi játékban is); a kiszolgáló
oldala: `Birodalom_Godot/server/supabase/schema_felho_mentes.sql`. Belépés vagy hálózat nélkül minden
helyben működik, és később feltöltődik. Ha ugyanaz a mentés két gépen is változott, az újabb nyer.
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
| `scripts/lang.gd`, `lang/*.json` | nyelvek: fordítás (`Lang.T`), későbbi fordítású hivatkozás (`Lang.ref`), nyelvváltás |
| `scripts/cv.gd` | a canvas 2D rajzoló utánzata (útvonalak, ívek, görbék, színátmenetek, élsimítás) |
| `scripts/sprites.gd`, `menu_art.gd` | a rajzolt figurák, tárgyak, díszek és a menü borítóképe |
| `scripts/skins.gd` | a kinézet-alkatrészek (fej/test/láb/fegyver) katalógusa, mentése és rajza |
| `scripts/fiok.gd` | fiók (`fiok.json`), érme-egyenleg, birtokolt darabok, vásárlás (aszinkron HTTP) |
| `scripts/render.gd`, `screens.gd` | pálya + fények + HUD, illetve a menük és ablakok |
| `scripts/audio.gd` | szintetizált hangeffektek és háttérzene (hangfájlok nélkül) |
| `tests/run_tests.gd` | fej nélküli tesztek (pályák, harc, tárgyak, termek/csapdák, képességek, mentés, kozmetika, nyelvek) |

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
**`win`** (győzelem), **`bolt`** (a **kinézet bolt** alaphelyzetben), **`bolt_preview`** (kinézet bolt felvett
összeállítással — `shop_preview` néven is), **`trap`** (csapdák és titkos ajtó), **`map`**
(automata térkép), **`pause`** (szünet-menü) és **`load`** (főmenü mentéssel). A `--cls=Lovag|Mágus|Íjász` a hőst, a `--lang=hu|en|de` a nyelvet választja ki, a `--size=SZÉLESSÉGxMAGASSÁG`
pedig az elrendezést (alapból 1280×800) — ezzel ellenőrizhető, hogy semmi nem lóg ki
kisebb képernyőn sem.

## Kiadás

Egy `v…` címke feltöltésekor (`git tag v2.0 && git push origin v2.0`) a GitHub Actions
(`.github/workflows/kiadas.yml`) Godot 4.7.2-vel lefuttatja a teszteket, elkészíti a
`kard_es_magia-windows.zip` (KardEsMagia.exe, beágyazott .pck) és a
`kard_es_magia-macos.zip` (univerzális .app, ad-hoc aláírással) csomagot, és GitHub-kiadásként
közzéteszi őket. A **ParthLauncher** innen tölti le és frissíti a játékot.