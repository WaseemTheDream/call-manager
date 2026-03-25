# Example: Send a Voice Message via WhatsApp

Generate a voice note using ElevenLabs TTS and send it to a WhatsApp chat.

## Quick Version

```bash
# Generate the voice message
./scripts/generate-voice-message.sh \
  "Hey! Just wanted to let you know the meeting got moved to 3 PM." \
  voice-note

# Send via OpenClaw
openclaw message send \
  --channel whatsapp \
  --target "<CHAT_ID>" \
  --media voice-note.ogg
```

## Manual Steps

### 1. Generate MP3 via ElevenLabs

```bash
curl -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/$ELEVENLABS_VOICE_ID" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Your message here",
    "model_id": "eleven_turbo_v2_5",
    "voice_settings": {
      "stability": 0.5,
      "similarity_boost": 0.75,
      "speed": 1.0
    }
  }' --output message.mp3
```

### 2. Convert to OGG Opus (WhatsApp Native Format)

```bash
ffmpeg -y -i message.mp3 -c:a libopus -b:a 64k -ar 48000 -ac 1 message.ogg
```

**Why OGG Opus?** WhatsApp's native voice note format. MP3 works for short clips but fails on mobile for longer messages.

### 3. Send

```bash
openclaw message send \
  --channel whatsapp \
  --target "<CHAT_ID>" \
  --media message.ogg
```

## Notes

- Voice messages must be saved to the OpenClaw workspace directory (not `/tmp/`)
- OGG Opus is required for reliable WhatsApp playback on all devices
- Keep voice messages under 60 seconds for best engagement
