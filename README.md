# Call Manager — AI Voice Call & Message Skill for OpenClaw

An OpenClaw skill for making AI-powered outbound phone calls, generating voice messages, and managing recurring voice delivery systems using VAPI, ElevenLabs, and Twilio.

## Features

- **Outbound AI Phone Calls** — Place real phone calls with a conversational AI agent via VAPI + Twilio
- **Voicemail-Aware Design** — Intelligent handling of voicemail systems, call screeners, and DTMF limitations
- **Recurring Quote Calls** — Schedule daily inspirational calls with quote tracking to avoid repeats
- **ElevenLabs Voice Cloning** — Create custom voice clones with sentence-by-sentence stitching for natural pacing
- **Voice Message Generation** — Generate TTS voice messages for WhatsApp (OGG Opus) and Slack (MP3)
- **Cron Scheduling** — Set up recurring calls and voice deliveries with OpenClaw's cron system

## Prerequisites

- [OpenClaw](https://openclaw.ai) installed and configured
- [VAPI](https://vapi.ai) account with API key
- [Twilio](https://twilio.com) phone number imported into VAPI
- [ElevenLabs](https://elevenlabs.io) account with API key
- `ffmpeg` installed (for audio conversion and stitching)
- `curl` and `jq` for API calls

## Installation

### Via OpenClaw

```bash
openclaw skill install call-manager
```

### Manual

```bash
git clone https://github.com/WaseemTheDream/call-manager.git
cp -r call-manager ~/.openclaw/workspace/skills/
```

## Configuration

Set these environment variables (or store in your OpenClaw credentials):

| Variable | Description |
|---|---|
| `VAPI_API_KEY` | Your VAPI API key |
| `VAPI_PHONE_NUMBER_ID` | Twilio number ID imported into VAPI |
| `ELEVENLABS_API_KEY` | Your ElevenLabs API key |
| `ELEVENLABS_VOICE_ID` | Default voice ID for TTS |
| `ELEVENLABS_CLONE_VOICE_ID` | Cloned voice ID (if using voice cloning) |

## Usage

### Make an Outbound Call

```bash
./scripts/make-vapi-call.sh "+1XXXXXXXXXX" "Schedule a dentist appointment for next Tuesday"
```

### Generate a Voice Message

```bash
# MP3 (for Slack)
./scripts/generate-voice-message.sh "Hey, just wanted to check in!" mp3

# OGG Opus (for WhatsApp)
./scripts/generate-voice-message.sh "Hey, just wanted to check in!" ogg
```

### Sentence-by-Sentence Stitching

```bash
./scripts/stitch-sentences.sh "First sentence. Second sentence. Third sentence." output.mp3
```

### Schedule a Daily Quote Call

```bash
openclaw cron add \
  --name "daily-quote-call" \
  --schedule "0 9 * * *" \
  --timezone "America/Los_Angeles" \
  --announce \
  --prompt "Read assets/quotes/steve-jobs.md. Pick an unused quote, make a VAPI call to deliver it, mark it as used."
```

See [examples/](examples/) for more detailed walkthroughs.

## Documentation

- [SKILL.md](SKILL.md) — Full OpenClaw skill procedures
- [references/lessons-learned.md](references/lessons-learned.md) — Battle-tested lessons from 100+ real calls
- [references/voice-cloning-guide.md](references/voice-cloning-guide.md) — Creating and tuning ElevenLabs voice clones
- [references/voicemail-handling.md](references/voicemail-handling.md) — Voicemail-aware call design
- [references/call-privacy.md](references/call-privacy.md) — Call transcript privacy model
- [references/cron-scheduling.md](references/cron-scheduling.md) — Setting up recurring calls

## Credits

Built by:
- **[Waseem Ahmad](https://waseemahmad.com)** — Creator & architect
- **[Chul Kwon](mailto:chulk90@gmail.com)** — Voice tuning & quality iteration
- **[Ren](https://waseemahmad.com/ren)** — AI development & implementation

Powered by [OpenClaw](https://openclaw.ai), [VAPI](https://vapi.ai), [ElevenLabs](https://elevenlabs.io), and [Twilio](https://twilio.com).

## License

[MIT](LICENSE)
