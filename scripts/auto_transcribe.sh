#!/usr/bin/env bash
# auto_transcribe.sh — Periodic pipeline for new Medo e Delírio episodes.
#
# Checks the podcast RSS feed for episodes without a local SRT, downloads,
# transcribes with whisper.cpp, applies name fixes, copies to the local mirror,
# regenerates the manifest, uploads via SFTP, and verifies.
#
# Usage:
#   ./auto_transcribe.sh              # normal run
#   ./auto_transcribe.sh --dry-run    # detect new episodes without processing
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Time-window guard: exit silently outside 6 PM – 8 AM
# ---------------------------------------------------------------------------
hour=$(date +%H)
if [ "$hour" -ge 8 ] && [ "$hour" -lt 18 ]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

FEED_URL="https://www.spreaker.com/show/4711842/episodes/feed"
WHISPER_CLI="/Users/rafaelschmitt/Projects/whisper.cpp/build/bin/whisper-cli"
WHISPER_MODEL="/Users/rafaelschmitt/Projects/whisper.cpp/models/ggml-large-v3-turbo.bin"
MIRROR_DIR="/Users/rafaelschmitt/MedoDelirioTranscripts"
WORK_DIR="${MIRROR_DIR}/work"
LOG_DIR="${MIRROR_DIR}/logs"
MANIFEST_URL="https://api.medodelirioios.com/transcripts/v1/manifest.json"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# Pedro Daltro name-fix pairs (wrong=correct)
NAME_FIX_PAIRS=(
    "D'Altro=Daltro"
    "Doutro=Daltro"
)

# Load server credentials
ENV_FILE="${SCRIPT_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    if [[ "$DRY_RUN" == false ]]; then
        echo "ERROR: $ENV_FILE not found. Copy .env.example and fill in your values."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

notify_error() {
    local msg="$1"
    log "ERROR: $msg"
    osascript -e "display notification \"$msg\" with title \"Auto Transcribe\" subtitle \"Error\"" 2>/dev/null || true
}

notify_success() {
    local msg="$1"
    log "$msg"
    osascript -e "display notification \"$msg\" with title \"Auto Transcribe\" subtitle \"Done\"" 2>/dev/null || true
}

cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

# ---------------------------------------------------------------------------
# Inline Python: parse feed and find new episodes
# ---------------------------------------------------------------------------
find_new_episodes() {
    python3 << 'PYEOF'
import xml.etree.ElementTree as ET
import urllib.request
import sys
import os
from urllib.parse import urlparse, parse_qs

FEED_URL = os.environ.get("FEED_URL", "")
MIRROR_DIR = os.environ.get("MIRROR_DIR", "")


def parse_episode_id(guid: str) -> str | None:
    """Replicate EpisodesService.parseEpisodeId from Swift."""
    if not guid:
        return None
    try:
        parsed = urlparse(guid)
        if parsed.scheme:
            last = parsed.path.rstrip("/").rsplit("/", 1)[-1] if parsed.path else ""
            if last and last != "/":
                return last
            qs = parse_qs(parsed.query)
            p_vals = qs.get("p", [])
            if p_vals and p_vals[0]:
                return p_vals[0]
            return guid
    except Exception:
        pass
    return guid


def main():
    req = urllib.request.Request(FEED_URL, headers={"User-Agent": "AutoTranscribe/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()

    root = ET.fromstring(data)
    ns = {"itunes": "http://www.itunes.com/dtds/podcast-1.0.dtd"}

    existing = set()
    if os.path.isdir(MIRROR_DIR):
        for f in os.listdir(MIRROR_DIR):
            if f.endswith(".srt"):
                existing.add(os.path.splitext(f)[0])

    new_episodes = []
    for item in root.findall(".//item"):
        guid_el = item.find("guid")
        if guid_el is None or not guid_el.text:
            continue
        ep_id = parse_episode_id(guid_el.text.strip())
        if not ep_id or ep_id in existing:
            continue

        title_el = item.find("title")
        title = title_el.text.strip() if title_el is not None and title_el.text else "unknown"

        enclosure = item.find("enclosure")
        audio_url = enclosure.get("url", "") if enclosure is not None else ""
        if not audio_url:
            continue

        # tab-separated: id, audio_url, title
        print(f"{ep_id}\t{audio_url}\t{title}")

    return 0


sys.exit(main())
PYEOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
trap cleanup EXIT

mkdir -p "$MIRROR_DIR" "$LOG_DIR"
LOG_FILE="${LOG_DIR}/run_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

log "=== Auto Transcribe started ==="
log "Dry run: $DRY_RUN"

# Step 1: Find new episodes
log "Checking feed for new episodes..."
export FEED_URL MIRROR_DIR

EPISODES_RAW=$(find_new_episodes) || {
    notify_error "Failed to fetch or parse podcast feed"
    exit 1
}

if [[ -z "$EPISODES_RAW" ]]; then
    log "No new episodes found. Nothing to do."
    exit 0
fi

EPISODE_COUNT=$(echo "$EPISODES_RAW" | wc -l | tr -d ' ')
log "Found $EPISODE_COUNT new episode(s)"
echo "$EPISODES_RAW"

if [[ "$DRY_RUN" == true ]]; then
    log "Dry run complete. Exiting."
    exit 0
fi

# Prepare work directories
mkdir -p "${WORK_DIR}/audio" "${WORK_DIR}/srt" "${WORK_DIR}/fixed"

PROCESSED=0
FAILED=0
NEW_SRT_FILES=()

while IFS=$'\t' read -r EP_ID AUDIO_URL TITLE; do
    log "--- Processing episode: $EP_ID ($TITLE) ---"

    # Step 2: Download MP3
    SAFE_TITLE=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/\./-/g' | tr -cs 'a-z0-9 -' ' ' | tr ' ' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | awk '{n=split($0,a,"-"); s=""; for(i=1;i<=n && i<=10;i++) s=s (i>1?"-":"") a[i]; print s}')
    MP3_FILE="${WORK_DIR}/audio/${EP_ID}-${SAFE_TITLE}.mp3"

    log "Downloading audio..."
    if ! curl -fSL --retry 3 --retry-delay 5 -o "$MP3_FILE" "$AUDIO_URL"; then
        notify_error "Failed to download episode $EP_ID"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Step 3: Transcribe with whisper.cpp (prevent idle sleep)
    SRT_OUTPUT="${WORK_DIR}/srt/${EP_ID}"
    log "Transcribing with whisper.cpp..."
    if ! caffeinate -i "$WHISPER_CLI" \
        -m "$WHISPER_MODEL" \
        -l pt \
        -f "$MP3_FILE" \
        -osrt -otxt \
        -of "$SRT_OUTPUT" 2>&1; then
        notify_error "Whisper failed for episode $EP_ID"
        FAILED=$((FAILED + 1))
        rm -f "$MP3_FILE"
        continue
    fi

    rm -f "$MP3_FILE"

    if [[ ! -f "${SRT_OUTPUT}.srt" ]]; then
        notify_error "Whisper produced no SRT for episode $EP_ID"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Step 4: Apply Pedro Daltro name fix
    FIX_ARGS=()
    for pair in "${NAME_FIX_PAIRS[@]}"; do
        FIX_ARGS+=(--fix "$pair")
    done

    log "Applying name fixes..."
    python3 "${PROJECT_DIR}/scripts/fix_srt_names.py" \
        "${WORK_DIR}/srt" \
        -o "${WORK_DIR}/fixed" \
        "${FIX_ARGS[@]}" 2>&1 || {
        log "Warning: name fix script had issues, using original SRT"
        cp "${SRT_OUTPUT}.srt" "${WORK_DIR}/fixed/${EP_ID}.srt"
    }

    # Step 5: Rename to {episodeId}.srt and copy to mirror
    FIXED_SRT="${WORK_DIR}/fixed/${EP_ID}.srt"
    if [[ ! -f "$FIXED_SRT" ]]; then
        log "Warning: fixed SRT not found at expected path, copying original"
        cp "${SRT_OUTPUT}.srt" "$FIXED_SRT"
    fi

    cp "$FIXED_SRT" "${MIRROR_DIR}/${EP_ID}.srt"
    NEW_SRT_FILES+=("${EP_ID}.srt")
    PROCESSED=$((PROCESSED + 1))
    log "Episode $EP_ID transcribed and copied to mirror."

done <<< "$EPISODES_RAW"

if [[ $PROCESSED -eq 0 ]]; then
    log "No episodes were successfully processed."
    if [[ $FAILED -gt 0 ]]; then
        notify_error "$FAILED episode(s) failed to process"
    fi
    exit 1
fi

# Step 6: Regenerate manifest
log "Regenerating manifest.json..."
python3 "${PROJECT_DIR}/scripts/generate_manifest.py" "$MIRROR_DIR" || {
    notify_error "Failed to generate manifest"
    exit 1
}

# Step 7: Upload via SFTP
log "Uploading ${#NEW_SRT_FILES[@]} SRT file(s) + manifest.json via SFTP..."

SFTP_BATCH=$(mktemp)
echo "cd ${SFTP_REMOTE_DIR}" >> "$SFTP_BATCH"
for srt_file in "${NEW_SRT_FILES[@]}"; do
    echo "put ${MIRROR_DIR}/${srt_file}" >> "$SFTP_BATCH"
done
echo "put ${MIRROR_DIR}/manifest.json" >> "$SFTP_BATCH"
echo "bye" >> "$SFTP_BATCH"

if ! sftp -b "$SFTP_BATCH" -i "${SFTP_KEY}" -P "${SFTP_PORT}" "${SFTP_USER}@${SFTP_HOST}"; then
    rm -f "$SFTP_BATCH"
    notify_error "SFTP upload failed"
    exit 1
fi
rm -f "$SFTP_BATCH"

# Step 8: Verify manifest is live
log "Verifying manifest on server..."
sleep 3
if curl -sf "$MANIFEST_URL" | python3 -c "import json,sys; m=json.load(sys.stdin); print(f'Manifest OK: {len(m[\"files\"])} file(s), version {m[\"version\"]}')" 2>/dev/null; then
    log "Verification passed."
else
    log "Warning: could not verify manifest. Check manually."
fi

# Step 9: Summary
log "=== Auto Transcribe complete ==="
log "Processed: $PROCESSED | Failed: $FAILED | New files: ${NEW_SRT_FILES[*]}"
notify_success "Transcribed $PROCESSED new episode(s)"
