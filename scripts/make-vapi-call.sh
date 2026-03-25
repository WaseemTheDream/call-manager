#!/bin/bash
# Make an outbound VAPI phone call
# Usage: ./make-vapi-call.sh <phone_number> <purpose> [first_message]
#
# Environment variables (required):
#   VAPI_API_KEY           - VAPI platform API key
#   VAPI_PHONE_NUMBER_ID   - Twilio number ID imported into VAPI
#   ELEVENLABS_VOICE_ID    - ElevenLabs voice ID
#
# Optional environment variables:
#   VAPI_VOICE_MODEL       - TTS model (default: eleven_turbo_v2_5)
#   VAPI_LLM_MODEL         - LLM model (default: claude-sonnet-4-20250514)
#   CALL_TIMEZONE          - Timezone (default: America/Los_Angeles)
#   ASSISTANT_NAME         - AI assistant name (default: Assistant)

set -euo pipefail

PHONE_NUMBER="${1:?Usage: make-vapi-call.sh <phone_number> <purpose> [first_message]}"
PURPOSE="${2:?Usage: make-vapi-call.sh <phone_number> <purpose> [first_message]}"
FIRST_MESSAGE="${3:-Hi! This is ${ASSISTANT_NAME:-Assistant} calling about ${PURPOSE}.}"

VOICE_MODEL="${VAPI_VOICE_MODEL:-eleven_turbo_v2_5}"
LLM_MODEL="${VAPI_LLM_MODEL:-claude-sonnet-4-20250514}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build system prompt
SYSTEM_PROMPT=$("$SCRIPT_DIR/build-call-context.sh" "the recipient" "$PURPOSE")

# Sanitize text for JSON (smart quotes, em dashes, etc.)
sanitize() {
  echo "$1" \
    | sed 's/\xe2\x80\x9c/"/g; s/\xe2\x80\x9d/"/g' \
    | sed "s/\xe2\x80\x98/'/g; s/\xe2\x80\x99/'/g" \
    | sed 's/\xe2\x80\x94/-/g; s/\xe2\x80\x93/-/g' \
    | sed 's/\xe2\x80\xa6/.../g' \
    | tr -cd '[:print:]\n'
}

SYSTEM_PROMPT=$(sanitize "$SYSTEM_PROMPT")
FIRST_MESSAGE=$(sanitize "$FIRST_MESSAGE")

# Build JSON payload
PAYLOAD=$(jq -n \
  --arg phoneId "$VAPI_PHONE_NUMBER_ID" \
  --arg number "$PHONE_NUMBER" \
  --arg model "$LLM_MODEL" \
  --arg sysPrompt "$SYSTEM_PROMPT" \
  --arg voiceId "$ELEVENLABS_VOICE_ID" \
  --arg voiceModel "$VOICE_MODEL" \
  --arg firstMsg "$FIRST_MESSAGE" \
  '{
    phoneNumberId: $phoneId,
    customer: { number: $number },
    assistant: {
      model: {
        provider: "anthropic",
        model: $model,
        messages: [{ role: "system", content: $sysPrompt }]
      },
      voice: {
        provider: "11labs",
        voiceId: $voiceId,
        model: $voiceModel
      },
      backgroundDenoisingEnabled: true,
      backgroundSpeechDenoisingPlan: {
        smartDenoisingPlan: { enabled: true }
      },
      backgroundSound: "off",
      silenceTimeoutSeconds: 15,
      firstMessage: $firstMsg
    }
  }')

echo "Placing call to $PHONE_NUMBER..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.vapi.ai/call/phone" \
  -H "Authorization: Bearer $VAPI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  CALL_ID=$(echo "$BODY" | jq -r '.id')
  echo "Call initiated successfully!"
  echo "Call ID: $CALL_ID"
  echo "Status: $(echo "$BODY" | jq -r '.status')"
  echo ""
  echo "To check status: curl -s -H 'Authorization: Bearer \$VAPI_API_KEY' https://api.vapi.ai/call/$CALL_ID | jq '.status,.endedReason,.transcript'"
else
  echo "Error ($HTTP_CODE): $BODY" >&2
  exit 1
fi
