# voice-inbox

Hlasový inbox: klávesovou zkratkou (nebo ťuknutím na widget) nadiktuješ myšlenku
a ta se přepsaná objeví na konci dnešního **Logseq deníku** — nebo se rovnou
**vepíše do pole, kde bliká kurzor**. Přepis dělá ElevenLabs Scribe v2,
volitelně text učeše Claude (interpunkce, výplňová slova).

Dvě varianty jednoho nástroje:

| Skript | Platforma | Spouštění |
|---|---|---|
| `voice-inbox-linux.sh` | Linux (testováno na Mint/Cinnamon, X11) | klávesová zkratka / terminál |
| `voice-inbox-termux.sh` | Android (Termux + Termux:API + Termux:Widget) | widget na ploše |

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

1. Nainstaluj **Termux**, **Termux:API** a **Termux:Widget** — vše ze stejného
   zdroje (F-Droid, nebo GitHub releases; nemíchat!).
2. V Termuxu:

   ```bash
   pkg install termux-api jq curl
   termux-setup-storage
   mkdir -p ~/.shortcuts ~/.config
   cp voice-inbox-termux.sh ~/.shortcuts/voice-inbox.sh
   chmod +x ~/.shortcuts/voice-inbox.sh
   cp voice-inbox.conf.example ~/.config/voice-inbox.conf
   nano ~/.config/voice-inbox.conf   # klíč + cesta k journals na /sdcard
   ```

3. Na plochu přidej widget „Termux:Widget“ → `voice-inbox.sh`.

Termuxová verze zatím neumí diktovací příkazy (hashtagy/seznamy/nadpisy) —
je to jednodušší starší varianta téhož.

## API klíče

- **ElevenLabs** (povinný): elevenlabs.io → profil → API keys. Scribe se
  účtuje po minutách audia; free tier na osobní diktování dlouho stačí.
- **Anthropic** (volitelný): console.anthropic.com → API Keys + kredit
  v Billing. Bez něj se zapisuje surový přepis, s ním Claude opraví
  interpunkci a vyhodí výplňová slova (Haiku ~ zlomky centu za zápis).

V repozitáři žádné klíče nejsou a nepatří sem — drž je v konfigu s právy 600.

## Řešení potíží

- **Přepis selhal** — nahrávka zůstává v `~/.voice-inbox/rec.wav`; zkontroluj
  klíč a kredit, pak ji přepiš dodatečně: `voice-inbox ~/.voice-inbox/rec.wav`.
  Detail chyby: spusť `curl` ze skriptu ručně bez `-sf` s `-v`.
- **Tichá/prázdná nahrávka** — zkontroluj vstupní zařízení v nastavení zvuku;
  případně ve skriptu dej `arecord -D pulse …`.
- **`voice-type` nic nenapíše** — chybí `xdotool`, nebo běžíš na Waylandu
  (pak je text aspoň ve schránce).
