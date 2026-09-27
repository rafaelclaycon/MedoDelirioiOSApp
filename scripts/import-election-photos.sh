#!/bin/zsh
# Copies official TSE candidate photos into the widget's asset catalog as
# ElectionCandidate<ballot number>, which ElectionCandidateBadge picks up.
#
# Usage: scripts/import-election-photos.sh <folder>
# Every file in <folder> must be named after the ballot number, e.g. 13.jpg.

set -euo pipefail

source_dir=${1:?"usage: $0 <folder with 13.jpg, 22.jpg, ...>"}
catalog="$(dirname "$0")/../MedoDelirioWidget/Assets.xcassets"

for photo in "$source_dir"/*; do
    number=${${photo:t}%.*}
    if [[ ! $number =~ '^[0-9]+$' ]]; then
        echo "Skipping ${photo:t}: name it after the ballot number, e.g. 13.jpg"
        continue
    fi

    imageset="$catalog/ElectionCandidate$number.imageset"
    mkdir -p "$imageset"
    # Re-encoded as JPEG whatever the source format, at most 180 px tall:
    # Live Activities refuse large images.
    sips -s format jpeg -Z 180 "$photo" --out "$imageset/photo.jpg" >/dev/null
    cat > "$imageset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "photo.jpg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
    echo "ElectionCandidate$number <- ${photo:t}"
done
