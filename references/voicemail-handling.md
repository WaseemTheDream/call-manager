# Voicemail Handling

VAPI's default behavior on voicemail is broken. Without explicit handling, the AI will say "Goodbye" and hang up when it hears the voicemail greeting.

## The Problem

1. Call connects to voicemail
2. Voicemail greeting plays ("Hi, you've reached...")
3. AI treats the greeting as a human response
4. AI fires `endCallPhrases` (e.g., "Goodbye") thinking the conversation ended
5. Call disconnects before the beep — no message left

## The Fix: Three-Part Solution

### 1. Put Full Payload in `firstMessage`

If your call exists to deliver a message (quote, reminder, notification), put the ENTIRE content in `firstMessage`:

```json
{
  "firstMessage": "Hi! This is Ren with your daily inspiration. Here is today's quote: [FULL QUOTE]. Have a wonderful day!"
}
```

`firstMessage` fires immediately on connect regardless of whether a human or voicemail picks up. This is your safety net.

### 2. Voicemail-Aware System Prompt

Add explicit voicemail instructions:

```
VOICEMAIL HANDLING: If you hear a voicemail greeting (e.g., "At the tone, please 
record your message", "Leave a message after the beep", or any automated greeting 
followed by a beep/silence), do NOT say "Goodbye" or end the call. Instead:
1. Wait for the beep/tone
2. Deliver the full message clearly and completely
3. Say "Have a great day!" and then end the call

The voicemail greeting is NOT the person talking to you. Do not respond 
conversationally to it. Do not end the call when you hear it.
```

### 3. Increase Silence Timeout

```json
{
  "silenceTimeoutSeconds": 15
}
```

Voicemail systems have pauses between the greeting and the beep. Default timeout (5s) kills the call too early.

## Complete Voicemail-Safe Config

```json
{
  "phoneNumberId": "<PHONE_ID>",
  "customer": { "number": "<E.164>" },
  "assistant": {
    "model": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-20250514",
      "messages": [{
        "role": "system",
        "content": "You are delivering a message. VOICEMAIL: If you hear a voicemail greeting, wait for the beep, deliver the full message, say goodbye, stop speaking. Do NOT end the call when you hear the greeting — that's the machine, not the person."
      }]
    },
    "voice": {
      "provider": "11labs",
      "voiceId": "<VOICE_ID>",
      "model": "<TTS_MODEL>"
    },
    "backgroundDenoisingEnabled": true,
    "backgroundSpeechDenoisingPlan": {
      "smartDenoisingPlan": { "enabled": true }
    },
    "backgroundSound": "off",
    "silenceTimeoutSeconds": 15,
    "firstMessage": "<FULL MESSAGE HERE>"
  }
}
```

## Call Screener + Voicemail Combo

Some contacts use call screeners AND have voicemail. Handle both:

```
CALL SCREENER: If you hear a screening prompt, clearly state your identity 
and purpose, then wait to be connected.

VOICEMAIL: If you hear a voicemail greeting or automated system, do NOT say 
goodbye. Wait for the beep, deliver the full message, then stop speaking.
```
