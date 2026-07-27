#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# voice-inbox.sh — hlasový inbox do dnešního Logseq deníku
#
# Použití: 1. ťuknutí na widget = start nahrávání
#          2. ťuknutí = stop -> přepis (ElevenLabs Scribe v2)
#                     -> volitelná úprava textu (Claude)
#                     -> append na konec dnešního journal .md
#
# Instalace:
#   1. Termux + Termux:API + Termux:Widget (vše ze STEJNÉHO
#      zdroje — F-Droid, nebo GitHub releases; nemíchat!)
#   2. V Termuxu:
#        pkg install termux-api jq curl
#        termux-setup-storage        # povolí přístup na /sdcard
#        mkdir -p ~/.shortcuts
#        cp voice-inbox.sh ~/.shortcuts/ && chmod +x ~/.shortcuts/voice-inbox.sh
#   3. Na plochu přidat widget "Termux:Widget" -> voice-inbox.sh
#   4. Vyplnit konfiguraci níže.
#
# API reference:
#   ElevenLabs STT: https://elevenlabs.io/docs/overview/capabilities/speech-to-text
#   Anthropic API:  https://docs.claude.com/en/api/overview
# ============================================================
set -uo pipefail

### ------------------ KONFIGURACE ------------------------ ###
# Žádné klíče ve skriptu — nastavení patří do ~/.config/voice-inbox.conf
# (viz README; vytvoř: mkdir -p ~/.config && nano ~/.config/voice-inbox.conf)
CONF="${VOICE_INBOX_CONF:-$HOME/.config/voice-inbox.conf}"
if [ -f "$CONF" ]; then
    # shellcheck source=/dev/null
    . "$CONF"
fi
ELEVENLABS_API_KEY="${ELEVENLABS_API_KEY:-}"   # elevenlabs.io -> profil -> API keys
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"     # volitelné; prázdné = přepis bez LLM úpravy
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-haiku-4-5-20251001}"
LANG_CODE="${LANG_CODE:-cs}"         # jazyk diktátu (Scribe umí i autodetekci — pak řádek s language_code smaž)
# Cesta ke složce journals tvého grafu:
LOGSEQ_JOURNALS="${LOGSEQ_JOURNALS:-/storage/emulated/0/Logseq/muj-graf/journals}"
INBOX_TAG="${INBOX_TAG-"#inbox"}"    # tag přidaný k bloku ("" = bez tagu)
### ------------------------------------------------------- ###

if [ -z "$ELEVENLABS_API_KEY" ]; then
    termux-toast -g bottom "Chybí ELEVENLABS_API_KEY v ~/.config/voice-inbox.conf"
    exit 1
fi

WORKDIR="$HOME/.voice-inbox"
REC="$WORKDIR/rec.m4a"
mkdir -p "$WORKDIR"

# --- TOGGLE: běží už nahrávání? -----------------------------
if termux-microphone-record -i 2>/dev/null | jq -e '.isRecording == true' >/dev/null; then
    termux-microphone-record -q >/dev/null
    termux-toast -g bottom "Přepisuji…"
else
    rm -f "$REC"
    termux-microphone-record -f "$REC" -l 600 >/dev/null   # limit 10 min
    termux-toast -g bottom "🎙️ Nahrávám… (ťukni znovu pro stop)"
    exit 0
fi

# --- PŘEPIS: ElevenLabs Scribe v2 ---------------------------
TEXT=$(curl -sf -X POST "https://api.elevenlabs.io/v1/speech-to-text" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -F "file=@$REC" \
    -F "model_id=scribe_v2" \
    -F "language_code=$LANG_CODE" \
    | jq -r '.text // empty')

if [ -z "$TEXT" ]; then
    termux-notification -t "Voice inbox: přepis selhal" \
        -c "Nahrávka ponechána v $REC — zkus ručně / zkontroluj API klíč a kredit."
    exit 1
fi

# --- VOLITELNÁ ÚPRAVA PŘES CLAUDE ---------------------------
if [ -n "$ANTHROPIC_API_KEY" ]; then
    CLEANED=$(jq -n --arg t "$TEXT" --arg m "$CLAUDE_MODEL" '{
        model: $m,
        max_tokens: 2000,
        messages: [{role: "user", content: ("Oprav interpunkci a převeď tento mluvený projev do čistého psaného textu v češtině. Odstraň výplňová slova a přeřeky, zachovej význam i všechny informace, nic nepřidávej ani nekomentuj. Vrať pouze upravený text.\n\n" + $t)}]
    }' | curl -sf "https://api.anthropic.com/v1/messages" \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d @- \
        | jq -r '.content[0].text // empty')
    [ -n "$CLEANED" ] && TEXT="$CLEANED"
fi

# --- ZÁPIS DO DNEŠNÍHO DENÍKU -------------------------------
# Výchozí formát názvu journal souboru v Logseq je YYYY_MM_DD.md.
# Pokud máš vlastní :journal/file-name-format, uprav řádek níže.
JOURNAL="$LOGSEQ_JOURNALS/$(date +%Y_%m_%d).md"

# Víceřádkový přepis srazíme do jednoho bloku (Logseq: 1 bullet = 1 blok)
ONE_LINE=$(printf '%s' "$TEXT" | tr '\n' ' ' | sed 's/  */ /g')

printf -- '- **%s** %s %s\n' "$(date +%H:%M)" "$ONE_LINE" "$INBOX_TAG" >> "$JOURNAL"

rm -f "$REC"
termux-toast -g bottom "✅ Uloženo do deníku"
