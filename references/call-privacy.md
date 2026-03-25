# Call Transcript Privacy Model

## Rules

1. Save every call transcript immediately after the call ends
2. Store with format: `YYYY-MM-DD-<description>.md`
3. Each file starts with a participants header listing who was on the call
4. Only share/read back a transcript to someone who is listed as a participant

## Participant Types

- **Caller**: The person who requested the call
- **Recipient**: The person/business called
- **On-behalf-of**: If someone asked you to make a call for them, they get access too

## Access Rules

- If Alex asks you to call Jordan, both Alex and Jordan can see the transcript
- If the owner asks you to call a restaurant for a friend, both the owner and the friend can see it
- No one else can see it, even if they ask
- Enforcement is at the assistant layer — refuse to read back or summarize transcripts to non-participants

## Transcript File Format

```markdown
# Call: <Description>
- **Date:** YYYY-MM-DD HH:MM AM/PM TZ
- **Participants:** <list of people with access>
- **Call ID:** <vapi-call-id>
- **Duration:** <approximate>
- **Outcome:** <brief result>

## Context
<Why the call was made>

## Transcript
**Speaker:** Line
**Speaker:** Line
...

## Notes
<Lessons learned, follow-ups needed>
```

## Business vs. Personal Calls

- **Calls to businesses/services** (restaurants, doctors, etc.): The person who requested the call gets full transcript access
- **Calls between known contacts**: The transcript belongs to both parties. Only share with participants.
- **Summary vs. transcript**: You can tell someone a call happened and give a general topic, but don't share verbatim transcripts without participant permission
