# Kard és Mágia

Roguelike kaland a katakombákban: lovag, mágus vagy íjász, öt mélység, szörnyek és kincsesládák.

- A játék: `index.html` (vászonra rajzolt grafika, saját hangok).
- Asztali ablak: `main.js` (Electron) – a játék saját ablakban fut, böngésző nélkül.
- Kiadás: egy `v…` címke feltöltésekor a GitHub elkészíti a Windows- és a Mac-csomagot
  (`.github/workflows/kiadas.yml`). A **ParthLauncher** innen tölti le és frissíti.

A pályák mindig bejárhatók: a generálás után a játék ellenőrzi, hogy a kezdőpontról minden
mező, a lépcső és minden láda elérhető-e, és ha nem, utat vág vagy áthelyezi a ládát.
