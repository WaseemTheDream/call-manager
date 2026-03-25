#!/bin/bash
# Sentence-by-sentence TTS with silence gaps for natural pacing
# Usage: ./stitch-sentences.sh <text> <output_file> [silence_duration]
#
# This technique generates each sentence separately via ElevenLabs TTS,
# adds silence gaps between them, and concatenates into a single file.
# Produces much more natural pacing than generating the entire text at once.
#
# Environment variables (required):
#   ELEVENLABS_API_KEY       - ElevenLabs API key
#   ELEVENLABS_VOICE_ID      - Voice ID (works best with cloned voices)
#
# Optional:
#   TTS_MODEL               - Model ID (default: eleven_multilingual_v2)
#   TTS_STABILITY           - Voice stability (default: 0.55)
#   TTS_SIMILARITY          - Similarity boost (default: 0.9)
#   TTS_STYLE               - Style exaggeration (default: 0.4)
#   TTS_SPEED               - Speech speed (default: 0.85)

set -euo pipefail

TEXT="${1:?Usage: stitch-sentences.sh <text> <output_file> [silence_duration]}"
OUTPUT="${2:?Usage: stitch-sentences.sh <text> <output_file> [silence_duration]}"
SILENCE_DURATION="${3:-0.6}"

MODEL="${TTS_MODEL:-eleven_multilingual_v2}"
STABILITY="${TTS_STABILITY:-0.55}"
SIMILARITY="${TTS_SIMILARITY:-0.9}"
STYLE="${TTS_STYLE:-0.4}"
SPEED="${TTS_SPEED:-0.85}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Split text into sentences (handles ., !, ?)
IFS=$'\n' read -r -d '' -a SENTENCES < <(
  echo "$TEXT" | sed 's/\([.!?]\) /\1\n/g' | sed '/^$/d'
) || true

if [ ${#SENTENCES[@]} -eq 0 ]; then
  echo "Error: No sentences found in input text" >&2
  exit 1
fi

echo "Processing ${#SENTENCES[@]} sentences..."

# Generate silence clip
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono \
  -t "$SILENCE_DURATION" -q:a 9 -acodec libmp3lame \
  "$TMPDIR/silence.mp3" 2>/dev/null

# Generate each sentence
FILELIST="$TMPDIR/filelist.txt"
> "$FILELIST"

for i in "${!SENTENCES[@]}"; do
  SENTENCE="${SENTENCES[$i]}"
  SENTENCE=$(echo "$SENTENCE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$SENTENCE" ]; then
    continue
  fi

  OUTFILE="$TMPDIR/sentence_${i}.mp3"
  echo "  [$((i+1))/${#SENTENCES[@]}] $SENTENCE"

  curl -s "https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}" \
    -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg text "$SENTENCE" \
      --arg model "$MODEL" \
      --argjson stability "$STABILITY" \
      --argjson similarity "$SIMILARITY" \
      --argjson style "$STYLE" \
      --argjson speed "$SPEED" \
      '{
        text: $text,
        model_id: $model,
        voice_settings: {
          stability: $stability,
          similarity_boost: $similarity,
          style: $style,
          speed: $speed
        }
      }')" \
    --output "$OUTFILE"

  if [ -s "$OUTFILE" ]; then
    echo "file '$OUTFILE'" >> "$FILELIST"
    # Add silence between sentences (not after the last one)
    if [ $i -lt $((${#SENTENCES[@]} - 1)) ]; then
      echo "file '$TMPDIR/silence.mp3'" >> "$FILELIST"
    fi
  else
    echo "  Warning: Failed to generate sentence $((i+1))" >&2
  fi

  # Rate limiting — small delay between API calls
  sleep 0.3
done

# Concatenate all segments
echo "Stitching sentences..."
ffmpeg -f concat -safe 0 -i "$FILELIST" -c copy "$TMPDIR/stitched.mp3" 2>/dev/null

# Apply denoising
echo "Applying denoising filter..."
ffmpeg -i "$TMPDIR/stitched.mp3" \
  -af "highpass=f=80,lowpass=f=12000,afftdn=nf=-25:nr=15:nt=w" \
  "$OUTPUT" 2>/dev/null

if [ -s "$OUTPUT" ]; then
  echo "Done! Output: $OUTPUT ($(wc -c < "$OUTPUT") bytes)"
else
  echo "Error: Final output is empty" >&2
  exit 1
fi
