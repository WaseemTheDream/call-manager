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

## Voice Profiles

Voice profiles map use cases to specific voice IDs, settings, models, and generation techniques.
**Always check profiles before generating voice content.** Use the default voice only when no
profile matches the request.

### Profile: Default (Ren)

The agent's own voice. Use for general TTS, voice messages, briefings, and any content
that isn't associated with a specific character or persona.

| Setting | Value |
|---|---|
| Voice ID | `ELEVENLABS_VOICE_ID` (from config) |
| Model | `eleven_turbo_v2_5` |
| Stability | 0.5 |
| Similarity boost | 0.75 |
| Speed | 1.0 |
| Technique | Standard (single-shot generation) |

### Profile: Cloned Voice (Character Persona)

Use for any content delivered in a **cloned voice** (e.g., Steve Jobs quotes, celebrity
impressions, custom voice characters). Cloned voices require special handling — they sound
unnatural when generated as a single long passage.

| Setting | Value |
|---|---|
| Voice ID | `ELEVENLABS_CLONE_VOICE_ID` (from config) |
| Model | `eleven_multilingual_v2` |
| Stability | 0.55 |
| Similarity boost | 0.9 |
| Style | 0.4 |
| Speed | 0.85 |
| **Technique** | **Sentence-by-sentence stitching (MANDATORY)** |

**⚠️ CRITICAL: Cloned voices MUST use sentence-by-sentence stitching.**
Single-shot generation with cloned voices produces rushed pacing, inconsistent tone,
and unnatural pauses. This was extensively tested and validated — sentence stitching
is the only technique that produces natural-sounding output with cloned voices.

### How to select a profile

1. **Is this a cloned voice / character persona?** → Use **Cloned Voice** profile + sentence stitching
2. **Is this the agent's own voice?** → Use **Default** profile + standard generation
3. **Not sure?** → If `ELEVENLABS_CLONE_VOICE_ID` is referenced in the request, it's a clone

### Adding new voice profiles

Store voice profiles in TOOLS.md or the agent's credentials store. Each profile needs:
- Voice ID
- Model (`eleven_turbo_v2_5` for premade, `eleven_multilingual_v2` for clones)
- Voice settings (stability, similarity_boost, style, speed)
- Generation technique (standard or sentence-stitching)

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

**First: check Voice Profiles above** to determine the correct voice, model, settings, and technique.

### Standard TTS (single generation)

Use for **premade/default voices only**. Do NOT use for cloned voices.

```bash
curl -s "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
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

**⚠️ MANDATORY for all cloned voices.** Do not skip this for cloned voice content.

This technique generates each sentence separately via ElevenLabs TTS, adds silence gaps
between them, and concatenates into a single file. It produces dramatically more natural
pacing than single-shot generation with cloned voices.

### Why this matters

Single-shot TTS with cloned voices produces:
- Rushed pacing toward the end of longer passages
- Inconsistent tone across sentences
- Unnatural pauses or no pauses at all
- Loss of the clone's character over longer text

Sentence stitching fixes all of these by giving each sentence its own generation context.

### Steps

1. Split text into sentences (on `.` `!` `?`)
2. Generate each sentence via ElevenLabs TTS API with **cloned voice settings**:
   - model: `eleven_multilingual_v2`
   - stability: 0.55, similarity_boost: 0.9, style: 0.4, speed: 0.85
3. Generate silence gap: `ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1.2 -q:a 9 -acodec libmp3lame silence.mp3`
4. Build file list alternating sentences and silence gaps (no silence after last sentence)
5. Concatenate: `ffmpeg -f concat -safe 0 -i filelist.txt -c copy output.mp3`
6. Apply denoising: `ffmpeg -i output.mp3 -af "highpass=f=80,lowpass=f=12000,afftdn=nf=-25:nr=15:nt=w" final.mp3`

### Automated script

Use `scripts/stitch-sentences.sh`:

```bash
ELEVENLABS_API_KEY="<key>" \
ELEVENLABS_VOICE_ID="<clone_voice_id>" \
./scripts/stitch-sentences.sh "Your text here. Multiple sentences work best." output.mp3
```

Voice settings can be overridden via environment variables:
- `TTS_MODEL` (default: `eleven_multilingual_v2`)
- `TTS_STABILITY` (default: 0.55)
- `TTS_SIMILARITY` (default: 0.9)
- `TTS_STYLE` (default: 0.4)
- `TTS_SPEED` (default: 0.85)

### Rate limiting

The script adds a 0.3s delay between API calls. For longer passages (10+ sentences),
monitor ElevenLabs rate limits. The Starter plan allows ~100 requests/minute.

---

## Procedure: Voice Cloning

1. **Collect reference audio**: Download clips via `yt-dlp`, trim with `ffmpeg -ss <start> -to <end>`
2. **Upload to ElevenLabs**: `POST /v1/voices/add` with audio files and voice name
3. **Test and iterate**: Generate sample text, get feedback, add more training clips
4. **Fine-tune settings**: Adjust stability, similarity_boost, style, and speed

See `references/voice-cloning-guide.md` for the full workflow.

### Clone iteration lessons

From real-world iteration on a Steve Jobs voice clone:

1. **v1**: Single clip clone — recognizable but thin
2. **v2**: Added more training clips + switched to `eleven_multilingual_v2` — much better
3. **v3-v4**: Pacing issues (rushing at end) — fixed with punctuation, but model-level fix was limited
4. **v5-v6**: Expanded to 5 source clips from different contexts — broader range but introduced drift
5. **v7**: Tried SSML `<break>` tags for pauses — sounded terrible (robotic, like hitting pause on tape)
6. **v8**: **Sentence-by-sentence stitching** with v2 settings — this was the breakthrough

**Key insight**: More training clips ≠ better. A focused 2-3 clip clone with good settings often
outperforms a 5-clip clone. The generation technique (sentence stitching) matters more than
clone complexity for long-form content.

**Final winning combination**: Sentence stitching technique + cloned voice settings
(stability 0.55, similarity_boost 0.9, style 0.4, speed 0.85, model `eleven_multilingual_v2`).

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
| Cloned voice sounds rushed/unnatural | Using single-shot generation | Switch to sentence-by-sentence stitching (see procedure above) |
| Wrong voice used for character content | No voice profile check | Always check Voice Profiles section before generating |

### Known Limitations

- **DTMF not supported**: VAPI cannot press phone menu buttons — IVR/phone trees are a dead end
- **Call screeners**: Must be handled via system prompt (state identity, wait)
- **International calls**: Require Twilio geo-permissions per country
- **Non-English voices**: English voices drift back to English quickly; use native-language voices
- **Bot verbalizes actions**: "Hangs up" is spoken aloud instead of executed; use silence timeout instead
- **Cloned voices degrade on long text**: Always use sentence stitching for passages longer than 1-2 sentences
