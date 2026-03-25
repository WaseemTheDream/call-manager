# Lessons Learned from Real Calls

Battle-tested insights from 100+ real AI voice calls.

## Call Screener Handling

**Problem:** Call went to a screener, AI didn't know what to do, call failed.
**Fix:** `firstMessage` must clearly state identity and purpose: "This is [Name] calling for [Recipient] with [purpose]." System prompt must include explicit screener handling instructions.

## Silence Timeout on Voicemail

**Problem:** AI said a short greeting and stopped, waiting for a reply. Hit silence timeout before delivering the actual message.
**Fix:** For one-way messages (quotes, reminders), put the ENTIRE payload in `firstMessage` or instruct the system prompt to continue without waiting. The AI's default is conversational — it waits for turns. Override this explicitly.

## Two Denoising Flags Required

**Problem:** Background voices audible on call despite `backgroundDenoisingEnabled: true`.
**Root cause:** That flag only handles ambient noise (fans, keyboards). Human voices require a separate flag.
**Fix:** Always set BOTH:
- `backgroundDenoisingEnabled: true` (ambient noise)
- `backgroundSpeechDenoisingPlan: { smartDenoisingPlan: { enabled: true } }` (human voices, TVs, echoes)
Note: The property is NOT `backgroundSpeechDenoisingEnabled` — that doesn't exist. It's a nested plan object.

## Duplicate Content in Recurring Calls

**Problem:** Daily scheduled call repeated the same content as yesterday.
**Fix:** Maintain a tracking file with Used and Unused queues. Cron task must reference this file and pick from the unused list.

## DTMF Limitation

**Problem:** Tried to navigate a phone tree — VAPI can't press menu buttons, only speaks.
**Fix:** No fix available. Avoid calling businesses with IVR phone trees. VAPI speaks but cannot send DTMF tones.

## Background Sound Must Be Off

**Problem:** VAPI adds fake office ambiance by default to make the AI sound more "human."
**Fix:** Always set `"backgroundSound": "off"`. Users want clean audio, not simulated office chatter.

## AI Should Hang Up After Goodbye

**Problem:** After saying goodbye, the AI stays on the line waiting for the user to hang up. Awkward silence.
**Fix:** Include in system prompt: "After saying goodbye, end the call promptly — do not wait for the user to hang up." Also set `silenceTimeoutSeconds` to 5.

## Check Platform Status FIRST

**Problem:** Calls failing silently — phone rings, user answers, AI never speaks, no transcript. Spent 30+ minutes debugging config when the real issue was VAPI platform degradation.
**Fix:** ALWAYS check https://status.vapi.ai BEFORE debugging config. Also check account credit balance. Status check = 10 seconds. Config debugging = 30 minutes. Do the quick thing first.

## Identity Must Be in System Prompt

**Problem:** When asked "who created you?" the AI defaults to claiming its base model creator.
**Fix:** EVERY system prompt must include identity/creator info: "You are [Name], created by [Creator]." Without this, the base model's training data takes over.

## Voice Tone Mismatch

**Problem:** A motivational/intense voice tone that works for quote delivery was described as "creepy" for normal conversation.
**Fix:** Use context-aware voice/prompt profiles. Motivational calls get energetic prompts. General calls get calm, conversational prompts. Consider separate assistant profiles per call type.

## Voice Breaking Character

**Problem:** When challenged ("why did you call me?"), the AI said "I'm not actually calling you... you were running through a role play scenario."
**Fix:** System prompt must explicitly state: "You are making a real phone call. Never claim this is a simulation or roleplay. You called them. Own it."

## Timezone Math

**Problem:** Recurring timezone errors when scheduling crons.
**Fix:** NEVER compute UTC offsets mentally. Always run:
```bash
TZ=America/New_York date -d "08:00" -u "+%H:%M UTC"
```

## Bot Verbalizes Actions Instead of Doing Them

**Problem:** System prompt says "end the call" but bot says "Hangs up" as spoken text, then sits in silence.
**Fix:** The bot can't programmatically hang up — it relies on silence timeout. Remove instructions like "hang up." Use: "After your message, simply stop speaking" and set `silenceTimeoutSeconds` low (5s).

## Name Mispronunciation

**Problem:** TTS mispronounces names despite correct spelling.
**Fix:** Use phonetic spelling in the prompt: "Keer-in" instead of "Kieran", "Wah-seem" instead of "Waseem", etc.

## Wait for Verbal Confirmation

**Problem:** AI jumps right into content delivery when the call connects, before the person even says hello.
**Fix:** Update system prompt: "Wait for the recipient to verbally confirm they're ready (by saying hello, yes, or similar) before delivering the content."

## JSON Serialization — Special Unicode Characters

**Problem:** Embedding text with smart quotes, em dashes, or non-ASCII punctuation causes `400 Bad Request: Unterminated string in JSON`.
**Fix:** Always sanitize text before embedding in VAPI JSON payloads:

```python
def sanitize_for_json(text):
    replacements = {
        '\u201c': '"', '\u201d': '"',   # smart double quotes
        '\u2018': "'", '\u2019': "'",   # smart single quotes
        '\u2014': '-', '\u2013': '-',   # em/en dash
        '\u2026': '...', '\u00a0': ' ', # ellipsis, nbsp
    }
    for char, replacement in replacements.items():
        text = text.replace(char, replacement)
    return text
```
