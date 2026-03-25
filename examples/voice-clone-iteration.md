# Example: Iterating on a Voice Clone

Real-world workflow for creating and refining a voice clone with user feedback.

## The Process

Voice cloning is iterative. Expect 5-10 rounds to get it right.

### Round 1: Initial Clone

```bash
# Download reference audio
yt-dlp -x --audio-format mp3 -o "source.mp3" "YOUTUBE_URL"

# Trim to 60 seconds of clean speech
ffmpeg -i source.mp3 -ss 00:01:30 -t 00:01:00 -c copy clip1.mp3

# Create the clone
curl -X POST "https://api.elevenlabs.io/v1/voices/add" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -F "name=Custom Voice v1" \
  -F "files=@clip1.mp3" \
  -F "description=Initial clone attempt"
```

### Round 2: Feedback → More Training Data

Typical feedback: "Sounds close but the accent is wrong" or "Too fast at the end."

**Add more diverse training clips:**
```bash
# Download from different sources (interviews, speeches, etc.)
yt-dlp -x --audio-format mp3 -o "source2.mp3" "ANOTHER_URL"
ffmpeg -i source2.mp3 -ss 00:02:00 -t 00:00:45 -c copy clip2.mp3

# Delete old clone and recreate with more data
curl -X DELETE "https://api.elevenlabs.io/v1/voices/$OLD_VOICE_ID" \
  -H "xi-api-key: $ELEVENLABS_API_KEY"

curl -X POST "https://api.elevenlabs.io/v1/voices/add" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -F "name=Custom Voice v2" \
  -F "files=@clip1.mp3" \
  -F "files=@clip2.mp3" \
  -F "files=@clip3.mp3"
```

### Round 3: Model Selection

Switch to `eleven_multilingual_v2` for better clone fidelity:
```json
{
  "model_id": "eleven_multilingual_v2",
  "voice_settings": {
    "stability": 0.55,
    "similarity_boost": 0.9,
    "style": 0.4,
    "speed": 0.85
  }
}
```

### Round 4-5: Pacing Fixes

If the voice rushes toward the end of long text, switch to sentence stitching:

```bash
./scripts/stitch-sentences.sh \
  "$ELEVENLABS_API_KEY" \
  "$VOICE_ID" \
  "First sentence. Second sentence. Third sentence." \
  output.mp3
```

### Round 6+: Denoising

Clone voices often carry background hiss from training audio:

```bash
ffmpeg -y -i output.mp3 \
  -af "highpass=f=80,lowpass=f=12000,afftdn=nf=-25:nr=15:nt=w" \
  -c:a libmp3lame -b:a 128k output-clean.mp3
```

## What We Learned

| Approach | Result |
|----------|--------|
| Single long TTS generation | Pacing degrades, rushes at end |
| SSML `<break>` tags | Sounds robotic, like hitting pause |
| Sentence stitching + silence gaps | Natural, best results |
| turbo_v2_5 model | Fast but less faithful to source |
| multilingual_v2 model | Slower but more accurate clone |

## The Winning Formula

1. **5+ diverse training clips** from different contexts
2. **`eleven_multilingual_v2`** model for best fidelity
3. **Sentence-by-sentence generation** stitched with 0.5-0.7s silence
4. **FFT denoising** to clean up hiss
5. **Iterate with real human feedback** — at least 5 rounds
