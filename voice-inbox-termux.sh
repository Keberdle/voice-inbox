#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# voice-inbox-termux.sh — zpracování hlasovek do Logseq deníku
#
# KLÍČE A NASTAVENÍ ŽIJÍ MIMO TENTO SOUBOR:
#   ~/.config/voice-inbox.conf
# Tenhle skript můžeš kdykoli přepsat novou verzí — konfigurace
# zůstává. V conf souboru stačí přepsat jen to, co se liší od
# výchozích hodnot níže (minimálně ELEVENLABS_API_KEY).
#
# Logika (v3): najde nové nahrávky v REC_DIR, přepíše je
# (ElevenLabs Scribe v2, volitelně Claude), zapíše do deníku
# podle data nahrávky, zpracované přesune do podsložky.
# ============================================================
set -uo pipefail

### VÝCHOZÍ HODNOTY — nepřepisuj tady, ale v conf souboru ###
ELEVENLABS_API_KEY=""
ANTHROPIC_API_KEY=""
CLAUDE_MODEL="claude-haiku-4-5-20251001"
LANG_CODE="cs"
LOGSEQ_JOURNALS="/storage/emulated/0/syncthing/LogSeq/journals"
INBOX_TAG="#inbox"
REC_DIR="/storage/emulated/0/Recordings/VoiceInbox"
### ------------------------------------------------------- ###

CONF="$HOME/.config/voice-inbox.conf"
[ -f "$CONF" ] && . "$CONF"

if [ -z "$ELEVENLABS_API_KEY" ]; then
    termux-notification -t "Voice inbox: chybí API klíč" \
        -c "Vyplň ELEVENLABS_API_KEY v $CONF"
    exit 1
fi

ARCHIVE_DIR="$REC_DIR/zpracovano"
mkdir -p "$REC_DIR" "$ARCHIVE_DIR"

append_block() {  # $1=journal soubor, $2=čas HH:MM, $3=text
    local J="$1"
    if [ -s "$J" ] && [ "$(tail -c1 "$J")" != "" ]; then echo >> "$J"; fi
    printf -- '- **%s** %s %s\n' "$2" "$3" "$INBOX_TAG" >> "$J"
}

OK=0; FAIL=0

while IFS= read -r -d '' F; do
    TEXT=$(curl -sf -X POST "https://api.elevenlabs.io/v1/speech-to-text" \
        -H "xi-api-key: $ELEVENLABS_API_KEY" \
        -F "file=@$F" \
        -F "model_id=scribe_v2" \
        -F "language_code=$LANG_CODE" \
        | jq -r '.text // empty')

    if [ -z "$TEXT" ]; then
        FAIL=$((FAIL+1))
        continue            # soubor zůstává ve složce na další pokus
    fi

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

    ONE_LINE=$(printf '%s' "$TEXT" | tr '\n' ' ' | sed 's/  */ /g')

    JOURNAL="$LOGSEQ_JOURNALS/$(date -r "$F" +%Y_%m_%d).md"
    STAMP=$(date -r "$F" +%H:%M)

    if append_block "$JOURNAL" "$STAMP" "$ONE_LINE"; then
        mv -- "$F" "$ARCHIVE_DIR/"
        OK=$((OK+1))
    else
        echo "- $(date -r "$F" '+%Y-%m-%d %H:%M') $ONE_LINE" >> "$HOME/.voice-inbox-nezapsano.md"
        FAIL=$((FAIL+1))
    fi
done < <(find "$REC_DIR" -maxdepth 1 -type f \
        \( -iname '*.m4a' -o -iname '*.mp3' -o -iname '*.wav' \
           -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.aac' \
           -o -iname '*.flac' \) -printf '%T@\t%p\0' \
        | sort -zn | cut -z -f2-)

if [ $((OK+FAIL)) -eq 0 ]; then
    termux-toast -g bottom "Žádné nové nahrávky"
elif [ "$FAIL" -eq 0 ]; then
    termux-toast -g bottom "✅ Zapsáno do deníku: $OK"
else
    termux-notification -t "Voice inbox: $OK zapsáno, $FAIL selhalo" \
        -c "Neúspěšné nahrávky zůstaly v $REC_DIR — spusť znovu, nebo zkontroluj klíč/kredit."
fi
