# Voice Cloning Guide

Create custom voice clones using ElevenLabs for natural, personalized AI calls and voice messages.

## Prerequisites

- ElevenLabs account (Starter plan or higher for voice cloning)
- `yt-dlp` and `ffmpeg` installed
- At least 1 minute of clean reference audio (3-5 minutes ideal)

## Step 1: Gather Reference Audio

Download source audio from speeches, interviews, or recordings:

```bash
# Download from YouTube
yt-dlp -x --audio-format mp3 -o "reference-audio.mp3" "YOUTUBE_URL"

# Trim to a clean segment (e.g., 30s-90s of clear speech)
ffmpeg -i reference-audio.mp3 -ss 00:00:30 -t 00:01:00 -c copy reference-clip.mp3
```

**Quality tips:**
- Choose segments with minimal background noise
- Avoid music, applause, or multiple speakers
- Diverse emotional range improves the clone (calm + emphatic)
- Multiple clips from different recordings > one long clip

## Step 2: Create the Voice Clone

```bash
curl -X POST "https://api.elevenlabs.io/v1/voices/add" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -F "name=My Custom Voice" \
  -F "files=@reference-clip-1.mp3" \
  -F "files=@reference-clip-2.mp3" \
  -F "files=@reference-clip-3.mp3" \
  -F "description=Custom voice clone for AI calls"
```

Response includes the new `voice_id` — save this.

## Step 3: Test and Iterate

Generate a test clip and get feedback:

```bash
curl -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Test sentence that matches your use case.",
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
      "stability": 0.55,
      "similarity_boost": 0.9,
      "style": 0.4,
      "speed": 0.85
    }
  }' --output test.mp3
```

### Iteration cycle:
1. Generate test → get feedback → adjust
2. If the voice sounds rushed → lower `speed` (0.78-0.85)
3. If it sounds robotic → increase `style` (0.3-0.5)
4. If it drifts from the source → increase `similarity_boost` (0.85-0.95)
5. If it sounds unstable → increase `stability` (0.5-0.7)
6. If quality plateaus → add more training clips from different sources

## Step 4: The Sentence-Stitching Breakthrough

For long-form content (quotes, monologues), generating the entire text as one TTS call often produces:
- Rushed pacing toward the end
- Inconsistent tone across sentences
- Unnatural pauses or no pauses at all

**The fix:** Generate each sentence separately and stitch with natural silence gaps.

See `scripts/stitch-sentences.sh` for the automated workflow.

### Voice Settings That Work Well for Clones

| Setting | Value | Notes |
|---------|-------|-------|
| model_id | eleven_multilingual_v2 | Best for cloned voices |
| stability | 0.55 | Balance between consistent and expressive |
| similarity_boost | 0.9 | High — stay close to the source |
| style | 0.4 | Moderate expressiveness |
| speed | 0.85 | Slightly slower for gravitas |

### What Didn't Work

- **SSML `<break>` tags**: Sounded robotic — like hitting pause on a tape recorder, not natural pausing
- **Single-shot long generation**: Pacing degrades with length, especially rushing toward the end
- **Very high stability (>0.8)**: Makes the voice flat and monotone
- **turbo_v2_5 for clones**: Works but `multilingual_v2` produces more faithful reproductions

## Denoising

Voice clones often have background hiss from training audio bleeding through. Clean it up:

```bash
ffmpeg -y -i input.mp3 \
  -af "highpass=f=80,lowpass=f=12000,afftdn=nf=-25:nr=15:nt=w" \
  -c:a libmp3lame -b:a 128k output.mp3
```

This applies:
- High-pass filter at 80Hz (removes rumble)
- Low-pass filter at 12kHz (removes hiss)
- FFT-based denoiser (removes white noise while preserving voice)
