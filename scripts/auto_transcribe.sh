#!/usr/bin/env bash
# auto_transcribe.sh — Periodic pipeline for new Medo e Delírio episodes.
#
# Checks the podcast RSS feed for episodes without a local SRT, downloads,
# transcribes with whisper.cpp, applies name fixes, copies to the local mirror,
# regenerates the manifest, uploads via SFTP, and verifies.
#
# Usage:
#   ./auto_transcribe.sh                        # normal run (respects 6 PM – 8 AM window)
#   ./auto_transcribe.sh --dry-run              # detect new episodes without processing
#   ./auto_transcribe.sh --force                # run immediately, ignoring the time window
#   ./auto_transcribe.sh --list-recent [N]      # list IDs of the N most recent episodes (default 10)
#   ./auto_transcribe.sh --retranscribe <id>    # re-download, re-transcribe, and re-upload a specific episode
#   ./auto_transcribe.sh --no-chapters          # transcripts only, skip chapter generation
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
DRY_RUN=false
FORCE_RUN=false
LIST_RECENT=false
LIST_RECENT_N=10
RETRANSCRIBE_ID=""
SKIP_CHAPTERS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)       DRY_RUN=true; shift ;;
        --force)         FORCE_RUN=true; shift ;;
        --no-chapters)   SKIP_CHAPTERS=true; shift ;;
        --list-recent)
            LIST_RECENT=true
            if [[ $# -gt 1 && "$2" =~ ^[0-9]+$ ]]; then
                LIST_RECENT_N="$2"; shift
            fi
            shift ;;
        --retranscribe)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "ERROR: --retranscribe requires an episode ID argument"
                exit 1
            fi
            RETRANSCRIBE_ID="$2"; shift 2 ;;
        *) shift ;;
    esac
done

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

# Chapters — generated after transcripts are published, and entirely optional.
# Every failure here is non-fatal: the transcript run has already succeeded by
# the time chapters run, and the app treats a missing chapter entry as
# "this episode has no chapters yet".
CHAPTERS_DIR="/Users/rafaelschmitt/MedoDelirioChapters"
CHAPTERS_FILE="${CHAPTERS_DIR}/chapters.json"
CHAPTERS_VERSION_URL="https://api.medodelirioios.com/chapters/v1/version.json"
# Must be a Python with the `anthropic` and `pydantic` packages installed.
# launchd does not inherit your shell, so a venv path is the safe choice.
CHAPTERS_PYTHON="${CHAPTERS_PYTHON:-python3}"
# Exit code chapters_from_srt.py uses for an exhausted credit balance.
CHAPTERS_EXIT_NO_CREDIT=2

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
    if [[ "$DRY_RUN" == false && -z "$RETRANSCRIBE_ID" && "$LIST_RECENT" == false ]]; then
        echo "ERROR: $ENV_FILE not found. Copy .env.example and fill in your values."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Time-window guard: exit silently outside 6 PM – 8 AM (skip with --force)
# TEMPORARILY DISABLED (dedicated machine during vacation) — re-enable by
# uncommenting the block below.
# ---------------------------------------------------------------------------
# if [[ "$FORCE_RUN" != true && -z "$RETRANSCRIBE_ID" && "$LIST_RECENT" == false ]]; then
#     hour=$(date +%H)
#     if [ "$hour" -ge 8 ] && [ "$hour" -lt 18 ]; then
#         exit 0
#     fi
# fi

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
# Inline Python: list recent episodes from feed
# ---------------------------------------------------------------------------
list_recent_episodes() {
    local n="$1"
    python3 << PYEOF
import xml.etree.ElementTree as ET
import urllib.request
import sys
import os
from urllib.parse import urlparse, parse_qs

FEED_URL = os.environ.get("FEED_URL", "")
MIRROR_DIR = os.environ.get("MIRROR_DIR", "")
N = int("$n")


def parse_episode_id(guid: str) -> str | None:
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


req = urllib.request.Request(FEED_URL, headers={"User-Agent": "AutoTranscribe/1.0"})
with urllib.request.urlopen(req, timeout=30) as resp:
    data = resp.read()

root = ET.fromstring(data)

existing = set()
if os.path.isdir(MIRROR_DIR):
    for f in os.listdir(MIRROR_DIR):
        if f.endswith(".srt"):
            existing.add(os.path.splitext(f)[0])

count = 0
for item in root.findall(".//item"):
    if count >= N:
        break
    guid_el = item.find("guid")
    if guid_el is None or not guid_el.text:
        continue
    ep_id = parse_episode_id(guid_el.text.strip())
    if not ep_id:
        continue
    title_el = item.find("title")
    title = title_el.text.strip() if title_el is not None and title_el.text else "unknown"
    has_srt = "yes" if ep_id in existing else "no "
    print(f"{ep_id}  srt={has_srt}  {title}")
    count += 1
PYEOF
}

# ---------------------------------------------------------------------------
# Inline Python: fetch audio URL for a specific episode ID
# ---------------------------------------------------------------------------
fetch_audio_url_for_id() {
    local target_id="$1"
    python3 << PYEOF
import xml.etree.ElementTree as ET
import urllib.request
import sys
import os
from urllib.parse import urlparse, parse_qs

FEED_URL = os.environ.get("FEED_URL", "")
TARGET = "$target_id"


def parse_episode_id(guid: str) -> str | None:
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


req = urllib.request.Request(FEED_URL, headers={"User-Agent": "AutoTranscribe/1.0"})
with urllib.request.urlopen(req, timeout=30) as resp:
    data = resp.read()

root = ET.fromstring(data)

for item in root.findall(".//item"):
    guid_el = item.find("guid")
    if guid_el is None or not guid_el.text:
        continue
    ep_id = parse_episode_id(guid_el.text.strip())
    if ep_id != TARGET:
        continue
    title_el = item.find("title")
    title = title_el.text.strip() if title_el is not None and title_el.text else "unknown"
    enclosure = item.find("enclosure")
    audio_url = enclosure.get("url", "") if enclosure is not None else ""
    if audio_url:
        print(f"{audio_url}\t{title}")
    sys.exit(0)

print(f"ERROR: episode '{TARGET}' not found in feed", file=sys.stderr)
sys.exit(1)
PYEOF
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
# --list-recent: print recent episode IDs and exit
# ---------------------------------------------------------------------------
if [[ "$LIST_RECENT" == true ]]; then
    export FEED_URL MIRROR_DIR
    list_recent_episodes "$LIST_RECENT_N"
    exit 0
fi

# ---------------------------------------------------------------------------
# --retranscribe: re-process a single episode by ID
# ---------------------------------------------------------------------------
if [[ -n "$RETRANSCRIBE_ID" ]]; then
    mkdir -p "$MIRROR_DIR" "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/retranscribe_${RETRANSCRIBE_ID}_$(date '+%Y%m%d_%H%M%S').log"
    exec > >(tee -a "$LOG_FILE") 2>&1

    log "=== Retranscribe started for episode: $RETRANSCRIBE_ID ==="

    export FEED_URL MIRROR_DIR
    LOOKUP=$(fetch_audio_url_for_id "$RETRANSCRIBE_ID") || {
        notify_error "Episode $RETRANSCRIBE_ID not found in feed"
        exit 1
    }
    AUDIO_URL=$(echo "$LOOKUP" | cut -f1)
    TITLE=$(echo "$LOOKUP" | cut -f2-)

    log "Found: $TITLE"
    log "Audio: $AUDIO_URL"

    trap cleanup EXIT
    mkdir -p "${WORK_DIR}/audio" "${WORK_DIR}/srt" "${WORK_DIR}/fixed"

    SAFE_TITLE=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/\./-/g' | tr -cs 'a-z0-9 -' ' ' | tr ' ' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | awk '{n=split($0,a,"-"); s=""; for(i=1;i<=n && i<=10;i++) s=s (i>1?"-":"") a[i]; print s}')
    MP3_FILE="${WORK_DIR}/audio/${RETRANSCRIBE_ID}-${SAFE_TITLE}.mp3"

    log "Downloading audio..."
    if ! curl -fSL --retry 3 --retry-delay 5 -o "$MP3_FILE" "$AUDIO_URL"; then
        notify_error "Failed to download episode $RETRANSCRIBE_ID"
        exit 1
    fi

    SRT_OUTPUT="${WORK_DIR}/srt/${RETRANSCRIBE_ID}"
    log "Transcribing with whisper.cpp..."
    if ! caffeinate -i "$WHISPER_CLI" \
        -m "$WHISPER_MODEL" \
        -l pt \
        -f "$MP3_FILE" \
        -osrt -otxt \
        -of "$SRT_OUTPUT" 2>&1; then
        notify_error "Whisper failed for episode $RETRANSCRIBE_ID"
        exit 1
    fi

    rm -f "$MP3_FILE"

    if [[ ! -f "${SRT_OUTPUT}.srt" ]]; then
        notify_error "Whisper produced no SRT for episode $RETRANSCRIBE_ID"
        exit 1
    fi

    FIX_ARGS=()
    for pair in "${NAME_FIX_PAIRS[@]}"; do
        FIX_ARGS+=(--fix "$pair")
    done

    log "Applying name fixes..."
    python3 "${PROJECT_DIR}/scripts/transcripts/fix_srt_names.py" \
        "${WORK_DIR}/srt" \
        -o "${WORK_DIR}/fixed" \
        "${FIX_ARGS[@]}" 2>&1 || {
        log "Warning: name fix script had issues, using original SRT"
        cp "${SRT_OUTPUT}.srt" "${WORK_DIR}/fixed/${RETRANSCRIBE_ID}.srt"
    }

    FIXED_SRT="${WORK_DIR}/fixed/${RETRANSCRIBE_ID}.srt"
    if [[ ! -f "$FIXED_SRT" ]]; then
        log "Warning: fixed SRT not found at expected path, copying original"
        cp "${SRT_OUTPUT}.srt" "$FIXED_SRT"
    fi

    cp "$FIXED_SRT" "${MIRROR_DIR}/${RETRANSCRIBE_ID}.srt"
    log "SRT written to mirror."

    log "Regenerating manifest.json..."
    python3 "${PROJECT_DIR}/scripts/transcripts/generate_manifest.py" "$MIRROR_DIR" || {
        notify_error "Failed to generate manifest"
        exit 1
    }

    log "Uploading SRT + manifest.json via SFTP..."
    SFTP_BATCH=$(mktemp)
    echo "cd ${SFTP_REMOTE_DIR}" >> "$SFTP_BATCH"
    echo "put ${MIRROR_DIR}/${RETRANSCRIBE_ID}.srt" >> "$SFTP_BATCH"
    echo "put ${MIRROR_DIR}/manifest.json" >> "$SFTP_BATCH"
    echo "bye" >> "$SFTP_BATCH"

    if ! sftp -b "$SFTP_BATCH" -i "${SFTP_KEY}" -P "${SFTP_PORT}" "${SFTP_USER}@${SFTP_HOST}"; then
        rm -f "$SFTP_BATCH"
        notify_error "SFTP upload failed"
        exit 1
    fi
    rm -f "$SFTP_BATCH"

    log "Verifying manifest on server..."
    sleep 3
    if curl -sf "$MANIFEST_URL" | python3 -c "import json,sys; m=json.load(sys.stdin); print(f'Manifest OK: {len(m[\"files\"])} file(s), version {m[\"version\"]}')" 2>/dev/null; then
        log "Verification passed."
    else
        log "Warning: could not verify manifest. Check manually."
    fi

    log "=== Retranscribe complete: $RETRANSCRIBE_ID ==="
    notify_success "Retranscribed episode $RETRANSCRIBE_ID"
    exit 0
fi

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
NEW_EPISODE_IDS=()

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
    python3 "${PROJECT_DIR}/scripts/transcripts/fix_srt_names.py" \
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
    NEW_EPISODE_IDS+=("${EP_ID}")
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
python3 "${PROJECT_DIR}/scripts/transcripts/generate_manifest.py" "$MIRROR_DIR" || {
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

# ---------------------------------------------------------------------------
# Step 9: Generate chapters for the new episodes
#
# Best-effort by design. Transcripts are already uploaded and verified above, so
# nothing below is allowed to fail the run — every command is guarded, and the
# worst case is that these episodes simply have no chapters until someone
# generates them by hand.
# ---------------------------------------------------------------------------
CHAPTERS_MADE=0
CHAPTERS_NOTE=""

chapters_step() {
    if [[ "$SKIP_CHAPTERS" == true ]]; then
        CHAPTERS_NOTE="skipped (--no-chapters)"
        return 0
    fi

    local script="${SCRIPT_DIR}/chapters/chapters_from_srt.py"
    if [[ ! -f "$script" ]]; then
        CHAPTERS_NOTE="skipped (chapters_from_srt.py not found)"
        return 0
    fi
    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        CHAPTERS_NOTE="skipped (ANTHROPIC_API_KEY not set in .env)"
        return 0
    fi
    if [[ -z "${CHAPTERS_REMOTE_DIR:-}" ]]; then
        CHAPTERS_NOTE="skipped (CHAPTERS_REMOTE_DIR not set in .env)"
        return 0
    fi
    # launchd runs with a bare PATH, so a Python without the SDK is the most
    # likely misconfiguration here. Check once rather than per episode.
    if ! "$CHAPTERS_PYTHON" -c "import anthropic, pydantic" >/dev/null 2>&1; then
        CHAPTERS_NOTE="skipped (${CHAPTERS_PYTHON} lacks anthropic/pydantic)"
        return 0
    fi

    mkdir -p "$CHAPTERS_DIR"

    local ep_id srt_path rc out_of_credit=false
    for ep_id in "${NEW_EPISODE_IDS[@]}"; do
        srt_path="${MIRROR_DIR}/${ep_id}.srt"
        if [[ ! -f "$srt_path" ]]; then
            log "Chapters: no SRT for $ep_id, skipping"
            continue
        fi

        log "Chapters: generating for $ep_id..."
        rc=0
        "$CHAPTERS_PYTHON" "$script" "$srt_path" "$ep_id" "$CHAPTERS_FILE" >>"$LOG_FILE" 2>&1 || rc=$?

        if [[ $rc -eq 0 ]]; then
            CHAPTERS_MADE=$((CHAPTERS_MADE + 1))
        elif [[ $rc -eq $CHAPTERS_EXIT_NO_CREDIT ]]; then
            # Every later episode would fail the same way — stop asking.
            log "Chapters: out of API credit, stopping"
            notify_error "Out of Claude API credit — chapters not generated"
            out_of_credit=true
            break
        else
            log "Chapters: failed for $ep_id (exit $rc), continuing"
        fi
    done

    if [[ $CHAPTERS_MADE -eq 0 ]]; then
        if [[ "$out_of_credit" == true ]]; then
            CHAPTERS_NOTE="none (out of credit)"
        else
            CHAPTERS_NOTE="none generated"
        fi
        return 0
    fi

    log "Chapters: regenerating version.json..."
    if ! "$CHAPTERS_PYTHON" "${SCRIPT_DIR}/chapters/generate_chapters_version.py" "$CHAPTERS_DIR" >>"$LOG_FILE" 2>&1; then
        # Validation failed — publishing now would break chapters for everyone,
        # since there is only one file for the whole catalogue.
        log "Chapters: version.json generation failed, not uploading"
        notify_error "chapters.json failed validation — not uploaded"
        CHAPTERS_NOTE="${CHAPTERS_MADE} generated, upload skipped (validation failed)"
        return 0
    fi

    # chapters.json must land before version.json: the app verifies the file's
    # hash against the version file, so the reverse order leaves every client
    # that syncs in the gap failing verification.
    log "Chapters: uploading..."
    local batch
    batch=$(mktemp)
    {
        echo "cd ${CHAPTERS_REMOTE_DIR}"
        echo "put ${CHAPTERS_FILE}"
        echo "put ${CHAPTERS_DIR}/version.json"
        echo "bye"
    } >"$batch"

    if ! sftp -b "$batch" -i "${SFTP_KEY}" -P "${SFTP_PORT}" "${SFTP_USER}@${SFTP_HOST}" >>"$LOG_FILE" 2>&1; then
        rm -f "$batch"
        log "Chapters: SFTP upload failed"
        notify_error "Chapters upload failed"
        CHAPTERS_NOTE="${CHAPTERS_MADE} generated, upload failed"
        return 0
    fi
    rm -f "$batch"

    sleep 3
    if curl -sf "$CHAPTERS_VERSION_URL" \
        | "$CHAPTERS_PYTHON" -c "import json,sys; v=json.load(sys.stdin); print(f'Chapters OK: {v[\"episodeCount\"]} episode(s), {v[\"chapterCount\"]} chapter(s)')" 2>/dev/null
    then
        log "Chapters: verification passed."
    else
        log "Chapters: warning — could not verify version.json. Check manually."
    fi

    CHAPTERS_NOTE="${CHAPTERS_MADE} generated and uploaded"
    return 0
}

chapters_step || {
    log "Chapters: unexpected error, continuing (transcripts already published)"
    CHAPTERS_NOTE="error"
}

# Step 10: Summary
log "=== Auto Transcribe complete ==="
log "Processed: $PROCESSED | Failed: $FAILED | New files: ${NEW_SRT_FILES[*]}"
log "Chapters: ${CHAPTERS_NOTE}"
if [[ $CHAPTERS_MADE -gt 0 ]]; then
    notify_success "Transcribed $PROCESSED episode(s), $CHAPTERS_MADE with chapters"
else
    notify_success "Transcribed $PROCESSED new episode(s)"
fi
