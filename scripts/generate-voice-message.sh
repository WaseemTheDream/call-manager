#!/bin/bash
# Generate a voice message using ElevenLabs TTS
# Usage: ./generate-voice-message.sh <text> [format] [output_file]
#
# Formats: mp3 (default, for Slack), ogg (OGG Opus for WhatsApp)
#
# Environment variables (required):
#   ELEVENLABS_API_KEY    - ElevenLabs API key
#   ELEVENLABS_VOICE_ID   - Voice ID for TTS
#
# Optional:
#   TTS_MODEL             - Model ID (default: eleven_turbo_v2_5)
#   TTS_STABILITY         - Voice stability 0-1 (default: 0.5)
#   TTS_SIMILARITY        - Similarity boost 0-1 (default: 0.75)
#   TTS_SPEED             - Speech speed (default: 1.0)

set -euo pipefail

TEXT="${1:?Usage: generate-voice-message.sh <text> [format] [output_file]}"
FORMAT="${2:-mp3}"
OUTPUT="${3:-voice-message}"

MODEL="${TTS_MODEL:-eleven_turbo_v2_5}"
STABILITY="${TTS_STABILITY:-0.5}"
SIMILARITY="${TTS_SIMILARITY:-0.75}"
SPEED="${TTS_SPEED:-1.0}"

# Strip extension from output if provided
OUTPUT="${OUTPUT%.*}"

echo "Generating voice message (${FORMAT})..."

# Generate MP3 via ElevenLabs TTS
curl -s "https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}" \
  -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg text "$TEXT" \
    --arg model "$MODEL" \
    --argjson stability "$STABILITY" \
    --argjson similarity "$SIMILARITY" \
    --argjson speed "$SPEED" \
    '{
      text: $text,
      model_id: $model,
      voice_settings: {
        stability: $stability,
        similarity_boost: $similarity,
        speed: $speed
      }
    }')" \
  --output "${OUTPUT}.mp3"

if [ ! -s "${OUTPUT}.mp3" ]; then
  echo "Error: TTS generation failed (empty file)" >&2
  exit 1
fi

echo "Generated: ${OUTPUT}.mp3 ($(wc -c < "${OUTPUT}.mp3") bytes)"

# Convert to OGG Opus if requested (WhatsApp native format)
if [ "$FORMAT" = "ogg" ]; then
  ffmpeg -y -i "${OUTPUT}.mp3" \
    -c:a libopus -b:a 64k -ar 48000 -ac 1 \
    "${OUTPUT}.ogg" 2>/dev/null

  if [ -s "${OUTPUT}.ogg" ]; then
    echo "Converted: ${OUTPUT}.ogg ($(wc -c < "${OUTPUT}.ogg") bytes)"
    rm -f "${OUTPUT}.mp3"
    echo "Output: ${OUTPUT}.ogg"
  else
    echo "Error: OGG conversion failed, keeping MP3" >&2
    echo "Output: ${OUTPUT}.mp3"
  fi
else
  echo "Output: ${OUTPUT}.mp3"
fi
