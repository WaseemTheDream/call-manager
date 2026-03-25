---
name: call-manager
description: AI voice call management using VAPI + Twilio + ElevenLabs. Make outbound phone calls, generate voice messages for WhatsApp/Slack, clone voices, schedule recurring calls, and handle voicemail/call screeners. Use when placing phone calls, making reservations, delivering scheduled messages by phone, generating voice notes, cloning voices, or any task requiring AI voice interaction.
---

# Call Manager

AI voice call and message management using VAPI, Twilio, and ElevenLabs.

## Config

Required environment variables (load from TOOLS.md or credentials store):

| Variable | Purpose |
|---|---|
| `VAPI_API_KEY` | VAPI platform authentication |
| `VAPI_PHONE_NUMBER_ID` | Twilio number imported into VAPI |
| `ELEVENLABS_API_KEY` | ElevenLabs TTS and voice cloning |
| `ELEVENLABS_VOICE_ID` | Default voice for TTS generation |

Optional:
- `ELEVENLABS_CLONE_VOICE_ID` — Cloned voice ID (for custom voice calls)
- `VAPI_VOICE_MODEL` — TTS model (default: `eleven_turbo_v2_5`)
- `VAPI_LLM_MODEL` — LLM for call conversations (default: `claude-sonnet-4-20250514`)

---

## Procedure: Make an Outbound Call

POST to `https://api.vapi.ai/call/phone`:

```json
{
  "phoneNumberId": "<VAPI_PHONE_NUMBER_ID>",
  "customer": { "number": "<E.164 phone number>" },
  "assistant": {
    "model": {
      "provider": "anthropic",
      "model": "<VAPI_LLM_MODEL>",
      "messages": [{ "role": "system", "content": "<system prompt>" }]
    },
    "voice": {
      "provider": "11labs",
      "voiceId": "<ELEVENLABS_VOICE_ID>",
      "model": "<VAPI_VOICE_MODEL>"
    },
    "backgroundDenoisingEnabled": true,
    "backgroundSpeechDenoisingPlan": {
      "smartDenoisingPlan": { "enabled": true }
    },
    "backgroundSound": "off",
    "silenceTimeoutSeconds": 15,
    "firstMessage": "<opening line>"
  }
}
```

### Audio Settings (ALWAYS set these)

- `backgroundDenoisingEnabled: true` — filters ambient noise (fans, traffic, keyboards)
- `backgroundSpeechDenoisingPlan.smartDenoisingPlan.enabled: true` — Krisp-powered filtering for background voices, TVs, echoes
- `backgroundSound: "off"` — VAPI adds fake office ambiance by default; always disable
- Note: The property is NOT `backgroundSpeechDenoisingEnabled` — it's a nested plan object

### System Prompt Guidelines

Include in every system prompt:

1. **Identity**: Who the AI is and why it's calling
2. **Objective**: What needs to be accomplished
3. **Call screener handling**: "If prompted by a call screener, clearly state your name and purpose, then wait to be connected"
4. **Voicemail handling**: See Voicemail section below
5. **Conversation style**: Brief, natural, polite — 2-3 sentences max per turn
6. **Call ending**: "After saying goodbye, end the call promptly. Do not wait for the other party to hang up."
7. **Reality anchor**: "You are making a real phone call. Never claim this is a simulation or roleplay."

### firstMessage Design

The `firstMessage` fires immediately on connect. Design it based on call type:

- **Message delivery** (quotes, reminders): Put the ENTIRE payload in `firstMessage` — this is your safety net for voicemail
- **Screened calls**: Use it to identify yourself — "This is [name] calling for [recipient] regarding [purpose]"
- **Interactive calls** (orders, reservations): Keep it short — "Hi, I'd like to place a pickup order please"

### JSON Sanitization

Always sanitize text before embedding in VAPI JSON payloads. Smart quotes, em dashes, and non-ASCII punctuation cause `400 Bad Request` errors:

```bash
echo "$TEXT" \
  | sed 's/\xe2\x80\x9c/"/g; s/\xe2\x80\x9d/"/g' \
  | sed "s/\xe2\x80\x98/'/g; s/\xe2\x80\x99/'/g" \
  | sed 's/\xe2\x80\x94/-/g; s/\xe2\x80\x93/-/g' \
  | tr -cd '[:print:]'
```

---

## Procedure: Voicemail Handling

VAPI's default behavior on voicemail is to treat the greeting as a human response, then fire `endCallPhrases` (e.g., "Goodbye") — hanging up before leaving any message.

### Fix: Voicemail-Aware Design

1. **Full payload in `firstMessage`**: For message-delivery calls, include the complete message so it's spoken immediately on connect
2. **System prompt voicemail instructions**:
   ```
   VOICEMAIL HANDLING: If you hear a voicemail greeting (e.g., "At the tone, please record
   your message" or any automated greeting followed by a beep/silence), do NOT say "Goodbye"
   or end the call. Instead:
   1. Wait for the beep/tone
   2. Deliver the full message clearly and completely
   3. Say "Have a great day!" then stop speaking
   ```
3. **Increase `silenceTimeoutSeconds`**: Set to at least 15 seconds — voicemail systems pause between greeting and beep
4. **Avoid "hang up" instructions**: The AI verbalizes "hangs up" instead of ending the call. Use "stop speaking" and rely on silence timeout

---

## Procedure: Retrieve Call Transcript

```
GET https://api.vapi.ai/call/<call-id>
Authorization: Bearer <VAPI_API_KEY>
```

Key response fields:
- `status`: queued, in-progress, ended
- `endedReason`: customer-ended-call, silence-timed-out, customer-did-not-answer
- `transcript`: Full conversation text
- `messages`: Array with timestamps and per-utterance detail

Save transcripts following the privacy model in `references/call-privacy.md`.

---

## Procedure: End a Call

```
DELETE https://api.vapi.ai/call/<call-id>
Authorization: Bearer <VAPI_API_KEY>
```

---

## Procedure: Generate Voice Message (ElevenLabs TTS)

### Standard TTS (single generation)

```bash
curl -s "https://api.elevenlabs.io/v1/text-to-speech/$ELEVENLABS_VOICE_ID" \
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
  }' \
  --output message.mp3
```

### Convert for WhatsApp (OGG Opus)

```bash
ffmpeg -y -i message.mp3 -c:a libopus -b:a 64k -ar 48000 -ac 1 message.ogg
```

### Upload to Slack (3-step API)

1. Get upload URL: `POST files.getUploadURLExternal` with `filename` and `length`
2. Upload file: `POST <upload_url>` with the MP3 file
3. Complete: `POST files.completeUploadExternal` with `files`, `channel_id`, `initial_comment`

---

## Procedure: Sentence-by-Sentence Stitching

For natural pacing with cloned voices, generate each sentence separately and stitch with silence gaps:

1. Split text into sentences
2. Generate each sentence via ElevenLabs TTS API
3. Generate silence: `ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 0.6 -q:a 9 -acodec libmp3lame silence.mp3`
4. Concatenate with `ffmpeg -f concat -safe 0 -i filelist.txt -c copy output.mp3`
5. Apply denoising: `ffmpeg -i output.mp3 -af "highpass=f=80,lowpass=f=12000,afftdn=nf=-25:nr=15:nt=w" final.mp3`

Recommended voice settings for cloned voices:
- stability: 0.55
- similarity_boost: 0.9
- style: 0.4
- speed: 0.85
- model: `eleven_multilingual_v2`

---

## Procedure: Voice Cloning

1. **Collect reference audio**: Download clips via `yt-dlp`, trim with `ffmpeg -ss <start> -to <end>`
2. **Upload to ElevenLabs**: `POST /v1/voices/add` with audio files and voice name
3. **Test and iterate**: Generate sample text, get feedback, add more training clips
4. **Fine-tune settings**: Adjust stability, similarity_boost, style, and speed

See `references/voice-cloning-guide.md` for the full workflow.

---

## Procedure: Schedule Recurring Calls

```bash
openclaw cron add \
  --name "<job-name>" \
  --schedule "<cron expression>" \
  --timezone "<IANA timezone>" \
  --announce \
  --prompt "<task description>"
```

**Critical**: Always use `TZ=<zone> date` for timezone verification — never do mental UTC math.

For quote tracking, maintain a quotes file with Used/Unused sections. The cron prompt should reference this file and move quotes between sections after delivery.

See `references/cron-scheduling.md` for detailed setup.

---

## Troubleshooting

### Before debugging ANYTHING: Check VAPI status

```
GET https://status.vapi.ai
```

If degraded → stop debugging, wait. Status check takes 10 seconds; config debugging takes 30 minutes.

### Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| Phone rings, silence, hangup (no transcript, cost=0) | VAPI platform degradation or low credits | Check status.vapi.ai, then check balance |
| `call.start.error-get-transport` | Number/routing issue | Verify Twilio number config |
| `silence-timed-out` with partial transcript | AI stopped speaking, waited for reply | Fix `firstMessage` — include full payload |
| `call.start.error-get-assistant` | Invalid or deleted assistant ID | Verify with `GET /assistant/{id}` |
| `400 Bad Request: Unterminated string` | Smart quotes/em dashes in JSON | Sanitize text (see JSON Sanitization above) |
| International call fails silently | Missing Twilio geo-permissions | Enable geo-permissions for target country |
| TTS mispronounces a name | TTS phonetic interpretation | Use phonetic spelling: "Keer-in" instead of "Kieran" or similar phonetic workarounds |

### Known Limitations

- **DTMF not supported**: VAPI cannot press phone menu buttons — IVR/phone trees are a dead end
- **Call screeners**: Must be handled via system prompt (state identity, wait)
- **International calls**: Require Twilio geo-permissions per country
- **Non-English voices**: English voices drift back to English quickly; use native-language voices
- **Bot verbalizes actions**: "Hangs up" is spoken aloud instead of executed; use silence timeout instead
