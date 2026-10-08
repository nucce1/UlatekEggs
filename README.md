# UlatekEggs
<img src="docs/logo.png" width="180" align="right" alt="Ula'tek slingrad runt ett grönt ägg">

WoW-addon av **Tjocksmock**, guilden **For Science**. Visar i fas 2 på Ula'tek (Mythic) en liten kartbit över din sida av arenan med äggen som röda prickar och **ditt ägg som grön prick**. Två fönster på 30 s: övre hörnet (3:28 efter pull) och nedre hörnet (3:54). Kartan visas bara för den som har ett ägg i det aktuella hörnet.

## Installera med WowUp

1. Öppna WowUp → **Get Addons** → **Install from URL**.
2. Klistra in `https://github.com/nucce1/UlatekEggs` och tryck **Import**.
3. WowUp hämtar senaste releasen och uppdaterar automatiskt när en ny kommer.

Manuellt: ladda ner zip-filen från senaste [releasen](https://github.com/nucce1/UlatekEggs/releases/latest) och packa upp i `World of Warcraft\_retail_\Interface\AddOns\`.

## Så fungerar det

- Vem som tar vilket ägg står i raidnoten (Northern Sky-reminder, annars MRT) i ett block:

  ```
  ulaStart
  tid 3:28 3:54
  Veraizh V1 Tjocksmock V2/V9 Cyrkdragon V3/V10 ... Bizer V ... Óneheal H9
  ulaEnd
  ```

  `H`/`V` = höger/vänster sida, första numret = ägget i övre hörnet, `/9` = ägget i nedre hörnet. Bara sida (`Bizer V`) = ingen karta. Raden `tid` är valfri; utan den gäller 3:28 och 3:54.
- `/ute` öppnar panelen: ditt ägg i klartext, förhandsvisning som kan dras dit du vill ha kartan, provkörning och rosterkontroll.
- `/ute test` låtsaspullar så du ser ditt ägg utan boss. `/ute check` visar vilka i raiden som saknar rad i noten.

## För utvecklare

- Testrigg: `python test\run_lua.py` (kräver OBS Studios `lua51.dll`), lint: `luacheck --config .luacheckrc UlatekEggs.lua`.
- Release: `tools\Release.ps1` kör lint och tester, bygger zip, kopierar till AddOns, taggar och skapar GitHub-releasen (kräver `gh`).
