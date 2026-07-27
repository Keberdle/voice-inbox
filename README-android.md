# Voice Inbox → Logseq (Android)

Hlasové poznámky do dnešního deníku v Logseq — bez otevírání Logsequ.

Nahraješ hlasovku, ťukneš na ikonu, a poznámka se objeví jako blok na konci
deníkové stránky odpovídajícího dne:

```
- **14:32** Zavolat zítra Milanovi kvůli faktuře. #inbox
```

## Jak to funguje

```
[nahrávací appka]  →  složka s nahrávkami  →  [Termux skript]
                                                 │
                                    ElevenLabs Scribe v2 (přepis)
                                                 │
                                    Claude Haiku (volitelné vyčištění)
                                                 │
                              journals/RRRR_MM_DD.md  (append blok)
```

Skript `voice-inbox.sh` při každém spuštění:

1. najde všechny audio soubory ve sledované složce (`REC_DIR`),
2. každý přepíše přes ElevenLabs Scribe v2 (`language_code` dle konfigurace),
3. volitelně nechá text vyčistit Claudem (interpunkce, výplňová slova),
4. zapíše blok do deníku **podle data a času nahrávky** (mtime souboru) —
   hlasovka z večera zpracovaná ráno skončí ve včerejším deníku,
5. zpracovaný soubor přesune do podsložky `zpracovano/`.

Neúspěšné nahrávky (výpadek sítě, vyčerpaný kredit) zůstávají na místě
a zpracují se při dalším spuštění.

### Proč skript nenahrává sám?

Původní verze nahrávala přímo v Termuxu (`termux-microphone-record`).
Narazila na záměrné chování Androidu 12+: **aplikaci na pozadí systém
nezabije nahrávání, ale podstrkává jí ticho.** Nahrávání proto musí dělat
appka na popředí (jakýkoli hlasový záznamník) a Termux jen tiše zpracovává
soubory — to na pozadí fungovat smí.

## Požadavky

- Android telefon (vyvíjeno a laděno na Pixel 8 Pro)
- **Termux** + **Termux:API** (viz poznámky k instalaci níže)
- Logseq s grafem ve **sdíleném úložišti** (např. synchronizace přes
  Syncthing do `/storage/emulated/0/...`) — do složky v privátním úložišti
  jiné appky se skript nedostane
- ElevenLabs účet + API klíč (přepis se účtuje podle minut audia)
- Volitelně: Anthropic API klíč (účtuje se podle textových tokenů;
  skript používá nejlevnější model Haiku)
- Libovolný hlasový záznamník ukládající do sdíleného úložiště
  (doporučeno: Fossify Voice Recorder — open source; vestavěný Pixel
  Recorder použít **nelze**, ukládá do privátního úložiště)

## Instalace

### 1. Termux

Doporučené pořadí pokusů:

1. **F-Droid buildy** (Termux, Termux:API, Termux:Widget — všechny tři
   ze stejného zdroje). Varování „aplikace je pro starší Android" je jen
   varování, instalaci obvykle nebrání.
2. Když F-Droid build instalaci odmítne (stává se): **Google Play** verze.
   Ta má widget **vestavěný v hlavní appce** (Termux:Widget na Play
   neexistuje jako samostatná appka). Ověřeno v praxi: Play Termux
   + F-Droid Termux:API spolu fungují — pokud ti taková kombinace běží,
   neměň ji.

Poté povol Termux:API mikrofon není potřeba (skript nenahrává), ale
**oběma appkám nastav Baterie → Bez omezení**, ať Android nezabíjí
zpracování na pozadí.

### 2. Základ v Termuxu

```bash
pkg update && pkg install -y termux-api jq curl
termux-setup-storage        # potvrď dialog — zpřístupní /sdcard
```

### 3. Skript

Stáhni `voice-inbox-termux.sh` z repozitáře do telefonu (např. do Download)
a nainstaluj pod jménem `voice-inbox.sh` (na to jméno se váže ikona na ploše):

```bash
mkdir -p ~/.shortcuts/tasks
cp /sdcard/Download/voice-inbox-termux.sh ~/.shortcuts/tasks/voice-inbox.sh
chmod +x ~/.shortcuts/tasks/voice-inbox.sh
```

Složka `~/.shortcuts/tasks/` znamená **tichý běh na pozadí** — ťuknutí na
zkratku neotevře okno Termuxu, jen proběhne skript a ukáže toast.
(Skripty přímo v `~/.shortcuts/` se spouští s otevřeným terminálem.)

### 4. Konfigurace — klíče žijí MIMO skript

Aktualizace skriptu nikdy nepřepíše klíče, protože ty jsou v samostatném
souboru `~/.config/voice-inbox.conf`:

```bash
mkdir -p ~/.config
cat > ~/.config/voice-inbox.conf << 'EOF'
ELEVENLABS_API_KEY="SEM-VLOZ-ELEVENLABS-KLIC"
ANTHROPIC_API_KEY=""
LOGSEQ_JOURNALS="/storage/emulated/0/CESTA/K/GRAFU/journals"
REC_DIR="/storage/emulated/0/Recordings"
EOF
chmod 600 ~/.config/voice-inbox.conf
nano ~/.config/voice-inbox.conf
```

Přehled proměnných (v conf stačí uvádět jen ty, které se liší od
výchozích hodnot ve skriptu):

| Proměnná | Význam | Výchozí |
|---|---|---|
| `ELEVENLABS_API_KEY` | klíč pro přepis (povinný) | — |
| `ANTHROPIC_API_KEY` | klíč pro LLM vyčištění (prázdné = vypnuto) | `""` |
| `CLAUDE_MODEL` | model pro vyčištění | `claude-haiku-4-5-20251001` |
| `LANG_CODE` | jazyk diktátu | `cs` |
| `LOGSEQ_JOURNALS` | složka `journals/` grafu | dle skriptu |
| `REC_DIR` | sledovaná složka s nahrávkami | `.../Recordings/VoiceInbox` |
| `INBOX_TAG` | tag přidaný k bloku | `#inbox` |

Kde je složka journals, zjistíš např.:
`find /sdcard/ -maxdepth 5 -type d -name journals 2>/dev/null`
(pozor na koncové lomítko — `/sdcard` je symlink a `find` ho bez něj
nenásleduje).

### 5. Nahrávací appka

Nastav jí ukládání do složky, kterou máš v `REC_DIR`. **Všechno, co v té
složce přistane, se přepíše do deníku a přesune** — používej ji proto
výhradně pro inbox.

Známý zádrhel: některé appky se při výběru vlastní podsložky přes
systémový dialog zacyklí („vybrána nesprávná složka"), zvlášť když složku
předem vytvořil Termux. Nejjednodušší obejití: nech appce její výchozí
složku a tu nastav do `REC_DIR` v conf souboru.

### 6. Ikona na plochu

Dlouhý stisk plochy → Widgety (nebo Zkratky) → **Termux** → obecná
položka **„Shortcut"** → vyber `voice-inbox.sh`.

Pozor: launcher si do zkratky **zapeče cestu ke skriptu z doby
vytvoření**. Po přesunu/přejmenování skriptu se stará ikona rozbije
(`error: unable to open file ...`) — je potřeba ji odebrat a vytvořit
znovu přes položku „Shortcut", ne z historie zkratek.

## Použití

1. Nahraj hlasovku záznamníkem (klidně víc hlasovek za den).
2. Ťukni na ikonu voice-inbox → toast `✅ Zapsáno do deníku: N`.
3. Bloky najdeš v denících podle dne nahrání, s časem a tagem `#inbox`.

Pokud Logseq právě běží a nový blok nevidí: Re-index grafu
(⋯ → Re-index), případně graf zavřít a otevřít.

## Aktualizace skriptu

```bash
cp /sdcard/Download/voice-inbox-termux.sh ~/.shortcuts/tasks/voice-inbox.sh
chmod +x ~/.shortcuts/tasks/voice-inbox.sh
```

Konfigurace i klíče zůstávají netknuté.

## Řešení problémů

| Příznak | Příčina a řešení |
|---|---|
| `unable to open file .../voice-inbox.sh` | Ikona na ploše míří na starou cestu → odebrat a vytvořit znovu (viz krok 6) |
| Toast „přepis selhal" | Špatný klíč / vyčerpaný kredit ElevenLabs; nahrávka zůstává v `REC_DIR`, po opravě spusť znovu |
| Notifikace „chybí API klíč" | Vyplň `ELEVENLABS_API_KEY` v `~/.config/voice-inbox.conf` |
| Blok se slepil s předchozím (`--`) | Řeší skript sám (doplní chybějící newline na konci journalu) — pokud vidíš, máš starou verzi skriptu |
| Zápis selhal | Text se zálohuje do `~/.voice-inbox-nezapsano.md`, nic se neztrácí; zkontroluj `LOGSEQ_JOURNALS` |
| Nahrávky vlastní cestou nejde vybrat v appce | Zacyklený SAF dialog → použij výchozí složku appky + `REC_DIR` v conf |
| Deník má jiný formát názvů než `RRRR_MM_DD.md` | Uprav `date -r "$F" +%Y_%m_%d` ve skriptu dle své konvence |

Ladění: `bash -x ~/.shortcuts/tasks/voice-inbox.sh` — a před sdílením
výstupu zamaskuj klíče:
`... 2>&1 | sed -E 's/(xi_|xi-|sk-ant-)[A-Za-z0-9_-]+/[KLIC]/g'`

## Bezpečnost

- Klíče jsou jen v `~/.config/voice-inbox.conf` (domovská složka Termuxu,
  `chmod 600`) — mimo dosah ostatních aplikací i synchronizace.
  Klíče nikdy nepatří do repozitáře ani na /sdcard.
- Skript posílá data pouze na `api.elevenlabs.io` a `api.anthropic.com`.
- Obsah hlasovek prochází přes cloudové API — nediktuj, co nemá opustit
  telefon.

## Struktura repozitáře

```
.
├── README.md                  # přehled + linuxová verze
├── README-android.md          # tento soubor
├── voice-inbox-linux.sh       # Linux: toggle nahrávání + režim „ke kurzoru"
├── voice-inbox-termux.sh      # Android: zpracování složky nahrávek
├── voice-inbox.conf.example   # šablona konfigurace (bez klíčů)
└── tagy.example.toml          # ukázková mapa tagů (linuxová verze)
```

## Licence / stav

Osobní nástroj vzniklý iterativním laděním na reálném zařízení.
Pull requesty s podporou dalších STT providerů vítány.
