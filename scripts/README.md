# Scripts — content pipelines

This folder holds the automation that produces the **transcripts** and **chapters**
the app downloads. Neither is generated on user devices: both are built here, on a
Mac, and uploaded to the server as static files.

If you are picking this project up from someone else, read *The two pipelines* and
*If something breaks* first. Everything else is reference.

---

## The two pipelines

```
                    ┌──────────────────────────────────────────────┐
  podcast RSS ────► │ auto_transcribe.sh     (runs every 20 min)   │
                    │                                              │
                    │   download → whisper.cpp → .srt              │
                    │   generate_manifest.py → manifest.json       │
                    │   SFTP → transcripts/v1/                     │
                    │                                              │
                    │   then, per new episode:                     │
                    │   chapters_from_srt.py ──────► Claude API    │
                    │   generate_chapters_version.py → version.json│
                    │   SFTP → chapters/v1/                        │
                    └──────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────┐
                    │ batch_generate_chapters.py    (run by hand)  │
                    │   backfilling older episodes, 50% cheaper    │
                    └──────────────────────────────────────────────┘
```

**New episodes are fully automatic, transcripts and chapters both.** A launchd job
runs `auto_transcribe.sh` every 20 minutes; it transcribes, publishes, then
generates and publishes chapters for whatever it just transcribed.

**Backfilling older episodes is manual.** That's what `batch_generate_chapters.py`
is for — same result at half the price, but asynchronous, so it isn't suitable for
the automated run.

**Chapters are strictly optional.** Everything chapter-related in
`auto_transcribe.sh` is best-effort: it runs only after transcripts are uploaded
and verified, and every failure is caught. Missing API key, no credit, a bad
response, a failed upload — the transcript run still succeeds and the app simply
shows those episodes as having no chapters yet. If you want them off entirely,
leave `ANTHROPIC_API_KEY` empty in `.env`.

Both publish to the same server via SFTP, using the credentials in `scripts/.env`.

---

## What has to be where

The automation depends on files outside this repository. Paths are configured at
the top of `auto_transcribe.sh` (and in `.env`); these are the defaults.

### On the Mac that runs the job

```
~/MedoDelirioTranscripts/            transcript mirror — STATE, not cache
    <episodeId>.srt                  one per transcribed episode
    manifest.json                    generated
    logs/                            per-run logs + launchd output
    work/                            scratch (audio, intermediate SRT)

~/MedoDelirioChapters/               chapter ledger — STATE, not cache
    chapters.json                    every episode's chapters, one file
    version.json                     generated
    .venv/bin/python                 needs `anthropic` and `pydantic`

~/Projects/whisper.cpp/
    build/bin/whisper-cli            transcription binary
    models/ggml-large-v3-turbo.bin   model

~/Projects/MedoDelirioBrasilia/scripts/
    .env                             credentials (never committed)

~/Library/LaunchAgents/
    com.rafaelschmitt.autotranscribe.plist    the 20-minute schedule
```

### On the server

```
transcripts/v1/     <episodeId>.srt … + manifest.json
chapters/v1/        chapters.json + version.json
```

### The two directories that are state, not cache

**`~/MedoDelirioTranscripts/` decides which episodes are already transcribed.** The
script compares the RSS feed against the `.srt` files there. Delete it and the next
run tries to re-transcribe the entire back catalogue — hours of CPU.

**`~/MedoDelirioChapters/chapters.json` decides which episodes already have
chapters, and it is the *only* copy.** A missing file is read as "no episodes done
yet", so the next run would generate chapters for one new episode, write a
one-episode `chapters.json`, and **upload it over the full file on the server** —
silently wiping chapters for every other episode. If you ever move, rename, or
restore this file, verify it before the next run:

```bash
python3 -c "import json;print(len(json.load(open('$HOME/MedoDelirioChapters/chapters.json'))['episodes']),'episodes')"
```

Neither directory is backed up by anything. The transcripts are reproducible (at
the cost of CPU time); the chapters are reproducible only by re-spending API
credits. Worth including both in whatever backs up the machine.

### Checking the setup

Run this after moving machines, restoring from backup, or picking the project up
from someone else:

```bash
set -a; . ~/Projects/MedoDelirioBrasilia/scripts/.env; set +a
for p in ~/MedoDelirioTranscripts ~/MedoDelirioChapters/chapters.json \
         ~/Projects/whisper.cpp/build/bin/whisper-cli "$CHAPTERS_PYTHON"; do
    [ -e "$p" ] && echo "ok      $p" || echo "MISSING $p"
done
"$CHAPTERS_PYTHON" -c "import anthropic, pydantic" && echo "ok      python packages"
launchctl list | grep -q autotranscribe && echo "ok      launchd job loaded" || echo "MISSING launchd job"
```

---

## Transcripts

### `auto_transcribe.sh`

The whole transcript pipeline. Checks the podcast RSS feed for episodes that have
no local `.srt`, then for each one: downloads the MP3, transcribes it with
whisper.cpp, applies name corrections, copies the result to the local mirror,
regenerates `manifest.json`, uploads everything by SFTP, and verifies the manifest
is live.

```bash
./auto_transcribe.sh                     # normal run (respects the time window)
./auto_transcribe.sh --dry-run           # detect new episodes, process nothing
./auto_transcribe.sh --force             # run now, ignoring the time window
./auto_transcribe.sh --no-chapters       # transcripts only, skip chapter generation
./auto_transcribe.sh --list-recent 10    # print the 10 most recent episode IDs
./auto_transcribe.sh --retranscribe 73006056   # redo one episode end to end
```

After the transcript upload is verified, it generates chapters for each episode it
just transcribed (via `chapters_from_srt.py`), regenerates `version.json`, and
uploads both to `chapters/v1/`. That step is skipped silently when
`ANTHROPIC_API_KEY` or `CHAPTERS_REMOTE_DIR` is missing from `.env`, or when
`CHAPTERS_PYTHON` doesn't have the required packages — so chapters can be switched
off just by clearing a value.

**Nothing in the chapter step can fail the run.** It happens after transcripts are
already published, and each outcome is handled: out of API credit stops the loop
and notifies once; a single episode failing logs and moves on; a `chapters.json`
that fails validation is *not* uploaded (a bad file would break chapters for every
user at once, since there's only one). The final log line reports what happened,
e.g. `Chapters: 2 generated and uploaded` or `Chapters: none (out of credit)`.

**It only runs between 6 PM and 8 AM.** Outside that window a normal run exits
silently. Transcription pegs the CPU for a long time, so it's kept to hours when
the machine isn't in use. `--force` overrides this — that's the flag you want when
testing.

**Things it depends on**, all of which must exist at the paths hardcoded near the
top of the script:

| What | Default path |
|---|---|
| whisper.cpp binary | `~/Projects/whisper.cpp/build/bin/whisper-cli` |
| whisper model | `~/Projects/whisper.cpp/models/ggml-large-v3-turbo.bin` |
| Local transcript mirror | `~/MedoDelirioTranscripts` |
| Logs | `~/MedoDelirioTranscripts/logs/` |
| SFTP credentials | `scripts/.env` |

The mirror is the source of truth for "which episodes are already done" — the
script compares the feed against the `.srt` files there. It is not disposable
cache; **don't delete it**, or the next run will try to re-transcribe the entire
back catalogue.

Failures raise a macOS notification via `osascript` and are written to the per-run
log in `logs/`. `caffeinate` keeps the Mac awake during transcription.

### `com.rafaelschmitt.autotranscribe.plist`

The launchd job that runs the above every 1200 seconds (20 minutes). Install it by
copying to `~/Library/LaunchAgents/` and loading it:

```bash
cp com.rafaelschmitt.autotranscribe.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.rafaelschmitt.autotranscribe.plist
```

Check it is registered, and stop it if needed:

```bash
launchctl list | grep autotranscribe
launchctl unload ~/Library/LaunchAgents/com.rafaelschmitt.autotranscribe.plist
```

Its own stdout/stderr go to `logs/launchd.log` and `logs/launchd_err.log` — check
those if the job seems not to be firing at all.

### `generate_manifest.py`

Writes `manifest.json` listing every transcript with a SHA-256 hash and byte size.
The app fetches this, compares hashes against what it has, and downloads only the
files that changed.

```bash
python3 generate_manifest.py ~/MedoDelirioTranscripts
```

Called automatically by `auto_transcribe.sh`. You only run it by hand if you added
or edited `.srt` files manually.

---

## Chapters

Chapters are AI-generated topic divisions with timestamps, produced from the
transcripts by the Claude API. Unlike transcripts they ship as **one bundled file**
for the whole catalogue rather than one file per episode, because they're tiny —
about 64 bytes per chapter.

### `batch_generate_chapters.py`

Generates chapters for many episodes at once through the Claude Message Batches
API, which costs 50% of the standard token price. Batches are asynchronous —
usually under an hour, up to 24 — so the script is split into two phases.

```bash
export ANTHROPIC_API_KEY='...'
pip install anthropic          # the only dependency

# 1. Preview: what would run, and what it would cost. No API call, no spend.
python3 batch_generate_chapters.py submit --since 2026-01-01 \
    --srt-dir ~/MedoDelirioTranscripts --dry-run

# 2. Submit. Writes batch-state.json and exits — the work continues server-side.
python3 batch_generate_chapters.py submit --since 2026-01-01 \
    --srt-dir ~/MedoDelirioTranscripts

# 3. Collect. Polls until the batch ends, then merges into chapters.json.
python3 batch_generate_chapters.py fetch --srt-dir ~/MedoDelirioTranscripts
```

**Always `--dry-run` first.** It prints the episode list and a cost estimate
without spending anything.

Selection flags, which combine as an intersection:

| Flag | Meaning |
|---|---|
| `--since YYYY-MM-DD` | Only episodes published on or after this date |
| `--last N` | Only the N most recent episodes |
| `--force` | Regenerate episodes already present (never touches `source: "manual"`) |
| `--model` | Defaults to `claude-opus-5` |
| `--chapters` | Path to `chapters.json` (default: `./chapters.json`) |
| `--srt-dir` | Where to read/cache `.srt` files (default: `./srt-cache`) |

**Episodes already in `chapters.json` are skipped.** That file is the ledger —
there is no separate database. Re-running after a failure only processes what is
missing, so a partially-completed run is safe to resume.

**Paths are relative to your current directory, not the script's.** A missing
`chapters.json` is treated as "nothing done yet", so running from the wrong folder
silently regenerates everything and spends real money. Pass `--chapters` with an
absolute path if you're unsure.

**Running out of credits is handled.** The API returns HTTP 400 for an exhausted
balance; `submit` exits with a top-up message and writes no state file, and `fetch`
saves every result it did collect before reporting the failure. Top up and re-run —
already-written episodes are skipped.

Rough costs on Opus 5 at the batch rate: **~$7 for all of 2026** (62 episodes),
~$6 for the last 50, ~$3 for the last 25.

### `chapters_from_srt.py`

Generates chapters for **one** episode, synchronously. Same prompt and same
cue-resolution logic as the batch script, but it calls the API directly and
returns in a minute or so instead of going through a batch.

```bash
export ANTHROPIC_API_KEY='...'
pip install anthropic pydantic

python3 chapters_from_srt.py 70769288.srt 70769288 chapters.json --dry-run
python3 chapters_from_srt.py 70769288.srt 70769288 chapters.json
```

Arguments are positional: the SRT file, the episode ID, and the `chapters.json`
to merge into. `--dry-run` parses the transcript and reports its size without
calling the API or spending anything, and `--model` overrides the default
`claude-opus-5`.

Use it for a single episode, for re-doing one that came out badly, or for testing
a prompt change before committing to a batch. It costs about **twice** the batch
rate — roughly 25¢ per episode on Opus 5 — so anything beyond a handful of
episodes belongs in `batch_generate_chapters.py`.

It needs `pydantic` as well as `anthropic` (it uses typed structured output,
where the batch script builds a raw JSON schema).

Like the batch script, it refuses to overwrite an episode marked
`source: "manual"`.

### `generate_chapters_version.py`

Writes `version.json` next to `chapters.json`. This is the small file the app polls
on every launch — if its hash matches what the client already has, the client skips
downloading the much larger `chapters.json`.

```bash
python3 generate_chapters_version.py /path/to/chapters/v1
python3 generate_chapters_version.py /path/to/chapters/v1 --coverage-start 2024-06-01
```

It **validates `chapters.json` before writing** — non-integer timestamps, empty
titles, or an episode with no chapters all cause a non-zero exit. If it fails,
upload nothing: a malformed file breaks chapters for every user at once, since
there's only one file.

`--coverage-start` (default `2026-01-01`) is the date shown in the app under
Settings → Episódios, telling users how far back chapters currently reach. Widen it
as older episodes get backfilled.

### Publishing chapters

**For new episodes this is automatic** — `auto_transcribe.sh` regenerates
`version.json` and uploads both files to `chapters/v1/` as its final step.

You only publish by hand after a **backfill**, since `batch_generate_chapters.py`
writes `chapters.json` but doesn't upload it:

```bash
python3 generate_chapters_version.py ~/MedoDelirioChapters
# then SFTP chapters.json first, version.json second
```

**Upload `chapters.json` first, then `version.json`.** The app verifies the
SHA-256 of what it downloads against the hash in `version.json`. If the version
file lands first advertising a hash the data file doesn't have yet, every client
that syncs in that gap fails verification. The other order is harmless — clients
just don't notice the new chapters until `version.json` catches up.

Confirm what's live, and that it matches your local file:

```bash
curl -s https://api.medodelirioios.com/chapters/v1/version.json
shasum -a 256 ~/MedoDelirioChapters/chapters.json
```

The two hashes should be identical. If they differ, the files were uploaded out of
order or an upload failed — re-upload both, in order.

---

## Reaction suggestions

Unlike transcripts and chapters, this is a **one-off tool you run by hand**, not
part of any automated pipeline — there's no server-side state and nothing is
ever published without you looking at it first.

### `generate_reactions.py`

Suggests new Reactions (themed micro-playlists of sounds, e.g. "Vergonha
Alheia") from the app's sound catalog, using the Claude API.

```bash
export ANTHROPIC_API_KEY='...'
pip install anthropic pydantic

python3 generate_reactions.py reactions_export.json suggestions.json --dry-run
python3 generate_reactions.py reactions_export.json suggestions.json --count 15
```

`reactions_export.json` comes from the app: **Settings → Dev Options →
Reactions → Exportar Dados para Sugestão de Reactions**, then share/save the
file here. It contains the full sound catalog (id, title, author), the titles
of existing Reactions (so the model doesn't repeat them), and a handful of
real Reactions with their sound lists as few-shot examples of tone and sizing.

`suggestions.json` is written for human review — nothing is uploaded or
published by this script. Suggestions referencing unknown sound ids, left with
fewer than 3 sounds after cleanup, or duplicating an existing title are
dropped automatically and reported on stderr.

**Idea not yet implemented: topical Reactions.** Some real Reactions key off
current political events rather than a timeless theme. `chapters.json` (see
Chapters above) already summarizes what each recent episode covered, cheaply
— far fewer tokens than feeding raw transcripts. A future version could pass
the last N episodes' chapter titles alongside the sound catalog so the model
can suggest Reactions tied to what the show has actually been covering
lately, instead of only evergreen groupings.

### `reactions_review.html`

A static, no-build viewer for `suggestions.json` — open it in a browser (it
auto-loads `suggestions.json` from the same folder if served over http(s), or
use the file picker if opening it directly as a local file). Accept or discard
each suggestion; decisions persist in the browser across reloads. "Exportar
aceitas" downloads `reactions_approved.json` with only the kept Reactions, in
the same shape, ready to hand to the content manager app.

---

## Transcript maintenance utilities

Occasional cleanup tools, not part of any automated flow.

### `check_srt_repeats.py`

Scans transcripts for the repetition loops that speech-to-text models fall into —
the same line repeated over and over, or a short A-B-A-B cycle. Worth running after
a batch of new transcripts.

```bash
python3 check_srt_repeats.py ~/MedoDelirioTranscripts
```

Exits 0 if clean, 1 if it finds anything. A flagged episode is usually best fixed
with `auto_transcribe.sh --retranscribe <id>`.

### `fix_srt_names.py`

Replaces misspelled proper nouns across `.srt` files — whisper reliably mangles
certain Brazilian political names.

```bash
python3 fix_srt_names.py ~/MedoDelirioTranscripts --fix "Bolsonáro=Bolsonaro"
```

`auto_transcribe.sh` calls this automatically on new transcripts; run it by hand
when you want to correct existing ones.

### `batch_rename.py` and `batch_rename_query.py`

One-off filename cleanups from earlier migrations. `batch_rename.py` strips
everything after the first `-` in a filename; `batch_rename_query.py` strips a
`?p=` fragment. Both default to a dry run and need `--apply` to actually rename.

Kept for reference. You will probably never need them.

---

## Configuration

`scripts/.env` holds the SFTP credentials for uploads. It is **not** in version
control. Copy the template and fill it in:

```bash
cp .env.example .env
```

| Variable | Used for |
|---|---|
| `SFTP_HOST`, `SFTP_USER`, `SFTP_PORT`, `SFTP_KEY` | Server connection |
| `SFTP_REMOTE_DIR` | Remote `transcripts/v1/` |
| `CHAPTERS_REMOTE_DIR` | Remote `chapters/v1/` |
| `ANTHROPIC_API_KEY` | Chapter generation — leave empty to disable it |
| `CHAPTERS_PYTHON` | Python with `anthropic` and `pydantic` installed |

`CHAPTERS_PYTHON` matters because **launchd does not inherit your shell**. A
`python3` that works in Terminal may not be the one the job runs, and a global
`pip install` may not be visible to it. Point it at a venv:

```bash
python3 -m venv ~/MedoDelirioChapters/.venv
~/MedoDelirioChapters/.venv/bin/python -m pip install anthropic pydantic
```

then set `CHAPTERS_PYTHON="/Users/<you>/MedoDelirioChapters/.venv/bin/python"`.

When running the chapter scripts by hand, `ANTHROPIC_API_KEY` can just be exported
in your shell instead. Keys are managed at https://platform.claude.com.

---

## If something breaks

**New episodes have no transcripts.** Check the launchd job is loaded
(`launchctl list | grep autotranscribe`), then read the newest file in
`~/MedoDelirioTranscripts/logs/`. Run `./auto_transcribe.sh --force --dry-run` to
see whether it detects the episode at all. Remember it does nothing between 8 AM
and 6 PM without `--force`.

**A transcript is garbled or loops.** `python3 check_srt_repeats.py` to confirm,
then `./auto_transcribe.sh --retranscribe <episode-id>`.

**New episodes get transcripts but no chapters.** The chapter step logs why it
skipped. Grep the newest run log:

```bash
grep -i chapters ~/MedoDelirioTranscripts/logs/run_*.log | tail -20
```

Common causes, all shown verbatim in that line: `ANTHROPIC_API_KEY not set in
.env`, `CHAPTERS_REMOTE_DIR not set in .env`, `<python> lacks anthropic/pydantic`
(see `CHAPTERS_PYTHON` under Configuration), or `none (out of credit)` — top up at
https://platform.claude.com.

**Older episodes have no chapters.** Expected — only episodes transcribed *after*
this automation was added get them automatically. Backfill with
`batch_generate_chapters.py`.

**The app shows no chapters at all.** Check `version.json` is reachable
(`curl` above) and that its `hash` matches the actual file
(`shasum -a 256 chapters.json`). A mismatch means the two files were uploaded out
of order; re-upload `chapters.json`, then `version.json`.

**Everything is on fire and you want to stop the automation.**

```bash
launchctl unload ~/Library/LaunchAgents/com.rafaelschmitt.autotranscribe.plist
```

The app keeps working — it just stops getting new transcripts. Previously published
transcripts and chapters stay served, since they're static files on the server.

---

## Editing the chapter scripts

`chapters_from_srt.py` and `batch_generate_chapters.py` each contain their own copy
of three things: the SRT parser, the prompt builder, and the instructions sent to
the model. **If you change one, change the other**, or the two will drift.

The coupling is not cosmetic. Both parse the SRT and **renumber its cues from 1**,
ignoring the file's own indices, then send the transcript as numbered lines. The
model replies with a *cue number*, which is mapped back to a timestamp afterwards.
So the numbering is the contract between the prompt and the result — if the two
scripts ever numbered cues differently, identical model output would resolve to
**different timestamps**, silently and with no error.

Worth factoring the shared parts into a common module at some point. Until then,
treat the duplication as load-bearing rather than untidy.
