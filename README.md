# voice-inbox

Hlasový inbox: klávesovou zkratkou (nebo ťuknutím na widget) nadiktuješ myšlenku
a ta se přepsaná objeví na konci dnešního **Logseq deníku** — nebo se rovnou
**vepíše do pole, kde bliká kurzor**. Přepis dělá ElevenLabs Scribe v2,
volitelně text učeše Claude (interpunkce, výplňová slova).

Dvě varianty jednoho nástroje:

| Skript | Platforma | Jak pracuje |
|---|---|---|
| `voice-inbox-linux.sh` | Linux (testováno na Mint/Cinnamon, X11) | klávesová zkratka: toggle nahrávání → zápis do deníku, nebo vepsání ke kurzoru |
| `voice-inbox-termux.sh` | Android (Termux + Termux:API) | ikona na ploše: zpracuje nové hlasovky ze sledované složky → zápis do deníku podle data nahrávky |

Android nemůže nahrávat na pozadí (systém od Androidu 12 podstrkává ticho),
proto tam nahrává libovolný záznamník do složky a skript ji dávkově
zpracovává — detailní návod v **[README-android.md](README-android.md)**.

## Jak to funguje

1. spuštění = **start nahrávání** (notifikace 🎙️)
2. spuštění = **stop** → přepis → úpravy → zápis

Linuxová verze má dva režimy výstupu (jeden skript, dva symlinky — o režimu
rozhoduje spuštění, které nahrávání *stopne*):

- **`voice-inbox`** — append do dnešního deníku jako blok
  `- **HH:MM** text… #inbox`
- **`voice-type`** — text se naklepe do pole s kurzorem (xdotool),
  funguje v libovolné aplikaci

Bonus: `voice-inbox soubor.mp3` přeskočí nahrávání a přepíše hotový soubor.

## Diktovací příkazy

| Řekneš | Dostaneš |
|---|---|
| „… hashtag spánek“ | `#spanek` — kanonizace podle mapy tagů (aliasy, diakritika, víceslovné tagy) |
| „seznam na nákup **dvojtečka** jablko, mrkev, banán“ | nadřazený blok + odsazené položky seznamu |
| „**nadpis první úrovně** Plány na víkend“ | `# Plány na víkend` (i druhé/třetí úrovně) |

Markdownové formátování (seznamy, nadpisy) se dělá jen při zápisu do deníku;
`voice-type` převádí pouze hashtagy a „dvojtečka“ → `:`.

Mapa tagů je jednoduchý TOML (`kanonicky = ["alias", …]`, viz
[tagy.example.toml](tagy.example.toml)). Neznámý tag projde jako
`#slovo-bez-diakritiky`, nic se neztratí.

## Instalace (Linux)

```bash
sudo apt install curl jq alsa-utils libnotify-bin xdotool xclip   # python3 už máš
git clone https://github.com/Keberdle/voice-inbox.git
cd voice-inbox
mkdir -p ~/bin
ln -s "$PWD/voice-inbox-linux.sh" ~/bin/voice-inbox
ln -s "$PWD/voice-inbox-linux.sh" ~/bin/voice-type
chmod +x voice-inbox-linux.sh
```

Konfigurace (klíče a cesty **nejsou ve skriptu**):

```bash
cp voice-inbox.conf.example ~/.config/voice-inbox.conf
chmod 600 ~/.config/voice-inbox.conf
nano ~/.config/voice-inbox.conf   # doplň ELEVENLABS_API_KEY a LOGSEQ_JOURNALS
```

Proměnné prostředí mají přednost před konfigem (hodí se na testování);
klíče jde místo konfigu exportovat, případně mít v `~/.secrets/ai.env`.

První test bez mikrofonu: `voice-inbox nejaka-nahravka.mp3` — vypíše přepis
a přidá blok do dnešního deníku. Pak klávesové zkratky (Cinnamon: Nastavení →
Klávesnice → Zkratky → Vlastní): `~/bin/voice-inbox` na `Super+V`,
`~/bin/voice-type` na `Super+B`.

Požadavky: X11 (pro `voice-type`/xdotool), Python ≥ 3.11 (tomllib).
Na Waylandu `voice-type` spadne do režimu „zkopíruj do schránky + vlož Ctrl+V“.

## Instalace (Android / Termux)

Kompletní návod včetně známých zádrhelů (výběr zdroje Termuxu, SAF dialogy,
zapečené cesty v ikonách, baterie) je v **[README-android.md](README-android.md)**.

Ve zkratce: záznamník ukládá hlasovky do sledované složky (`REC_DIR`),
ťuknutí na ikonu Termux zkratky je přepíše a zapíše do deníků **podle data
a času nahrávky** (hlasovka z večera zpracovaná ráno skončí ve včerejším
deníku), zpracované soubory přesune do podsložky `zpracovano/`. Neúspěšné
nahrávky zůstávají na místě na další pokus.

Termuxová verze zatím neumí diktovací příkazy (hashtagy/seznamy/nadpisy).

Tip: na obecné diktování do libovolného pole na Androidu (obdoba
`voice-type`) se hodí **Whisperian** — vlastní klávesnice, nebo integrace
do Gboardu podržením mezerníku; detail v [README-android.md](README-android.md).

## API klíče

- **ElevenLabs** (povinný): elevenlabs.io → profil → API keys. Scribe se
  účtuje po minutách audia; free tier na osobní diktování dlouho stačí.
- **Anthropic** (volitelný): console.anthropic.com → API Keys + kredit
  v Billing. Bez něj se zapisuje surový přepis, s ním Claude opraví
  interpunkci a vyhodí výplňová slova (Haiku ~ zlomky centu za zápis).

V repozitáři žádné klíče nejsou a nepatří sem — drž je v konfigu s právy 600.

### Ochrana před prompt injection z diktátu

Diktát typu „napiš mi shrnutí knihy…“ nebo „přelož to…“ dřív Claude občas
**vykonal** místo aby ho vyčistil — do deníku pak přišlo shrnutí knihy,
ne poznámka. Skript to řeší ve dvou vrstvách:

1. **Oddělení dat od pokynů** — pravidla korektury jsou v `system` promptu,
   přepis jde do zprávy zabalený v `<prepis>` a je explicitně označen jako
   pasivní text: otázky, prosby a příkazy v něm se neprovádějí, jen opíšou.
2. **Validace odpovědi** (`text_is_faithful`) — vyčištěný text musí mít
   40–150 % slov originálu a sdílet s ním slovník. Když Claude přece jen
   „splní úkol“ (odpověď je delší, kratší nebo o něčem jiném), úprava se
   zahodí a zapíše se surový přepis. Nic se neztratí, jen chybí korektura.

Skript navíc Claudovi nedává žádné nástroje — může jen vracet text, nikdy
nic spouštět, posílat ani mazat.

## Řešení potíží

- **Přepis selhal** — nahrávka zůstává v `~/.voice-inbox/rec.wav`; zkontroluj
  klíč a kredit, pak ji přepiš dodatečně: `voice-inbox ~/.voice-inbox/rec.wav`.
  Detail chyby: spusť `curl` ze skriptu ručně bez `-sf` s `-v`.
- **Tichá/prázdná nahrávka** — zkontroluj vstupní zařízení v nastavení zvuku;
  případně ve skriptu dej `arecord -D pulse …`.
- **`voice-type` nic nenapíše** — chybí `xdotool`, nebo běžíš na Waylandu
  (pak je text aspoň ve schránce).
