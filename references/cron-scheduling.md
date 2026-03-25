# Setting Up Recurring Calls with OpenClaw Cron

Guide for scheduling recurring voice calls and voice message deliveries using OpenClaw's cron system.

## Basic Cron Syntax

```bash
openclaw cron add \
  --name "<job-name>" \
  --schedule "<cron-expression>" \
  --timezone "<IANA-timezone>" \
  --announce \
  --prompt "<task-description>"
```

### Schedule Examples

| Schedule | Cron Expression | Description |
|---|---|---|
| Every day at 9 AM | `0 9 * * *` | Daily at 9:00 AM |
| Weekdays at 8 AM | `0 8 * * 1-5` | Monday-Friday at 8:00 AM |
| Every Monday at 10 AM | `0 10 * * 1` | Weekly on Monday |
| Twice daily (9 AM, 6 PM) | `0 9,18 * * *` | 9:00 AM and 6:00 PM |
| Every 30 minutes | `*/30 * * * *` | Every half hour |

## Delivery Modes

### `--announce` (Daily Reports)
Use for cron jobs that run once per day and always produce meaningful output:
```bash
--announce  # Results sent to target channel
```

### `--no-deliver` (Monitors)
Use for high-frequency monitoring jobs that should only send messages on actionable events:
```bash
--no-deliver  # Only sends messages via `openclaw message send` within the prompt
```

## Timezone Handling (CRITICAL)

**NEVER do mental UTC math.** Always verify with actual date commands:

```bash
# Wrong way (mental math)
# "8 AM EST = 13 UTC" — this is often wrong due to DST

# Right way (command verification)
TZ=America/New_York date -d "08:00 today" -u "+%H:%M UTC"
# Output: 13:00 UTC (standard time) or 12:00 UTC (daylight time)
```

Then use that UTC time in your cron schedule.

### Common Timezone Mistakes

- **DST transitions**: EST vs EDT, PST vs PDT
- **Server timezone**: Assuming server runs in local timezone
- **Seasonal drift**: Cron set in winter breaks in summer

### Verification Steps

1. Set the cron with `--timezone`
2. Run a test: `openclaw cron trigger <job-name>`
3. Check the output includes correct local time
4. Verify it matches your expectation

## Daily Quote Call Example

```bash
openclaw cron add \
  --name "daily-steve-jobs-quote" \
  --schedule "0 9 * * *" \
  --timezone "America/Los_Angeles" \
  --announce \
  --prompt "
Read assets/quotes/steve-jobs.md. Find an unused quote from the Unused Queue section.

Make a VAPI call to deliver it:
1. Use scripts/make-vapi-call.sh 
2. Phone: +1XXXXXXXXXX
3. Purpose: Daily Steve Jobs inspiration
4. Include the full quote in firstMessage for voicemail safety

After successful delivery:
1. Move the quote from Unused to Used section
2. Add today's date and recipient name
3. Save the updated file

If call fails, report the error but don't mark quote as used.
"
```

## Voice Message Delivery Example

```bash
openclaw cron add \
  --name "daily-voice-message" \
  --schedule "0 18 * * 1-5" \
  --timezone "America/New_York" \
  --announce \
  --prompt "
Generate a voice message for end-of-workday motivation:

1. Create inspiring 30-second message about tomorrow's opportunities
2. Use scripts/generate-voice-message.sh to create OGG file
3. Send via WhatsApp: openclaw message send --channel whatsapp --target <CHAT_ID> --media voice.ogg

Keep the message positive and forward-looking.
"
```

## Quote Tracking System

Maintain a quotes file with Used/Unused sections:

```markdown
# Steve Jobs Quotes

## Used Quotes
- 2026-03-25: "Your time is limited, so don't waste it living someone else's life." (Alex)
- 2026-03-24: "Innovation distinguishes between a leader and a follower." (Jordan)

## Unused Quotes  
- "Stay hungry, stay foolish."
- "The people who are crazy enough to think they can change the world are the ones who do."
- "Design is not just what it looks like. Design is how it works."
```

### Cron Prompt for Quote Management

```
Read the quotes file. Pick the first quote from Unused Quotes section.

Make the call with full voicemail safety:
- Put entire quote in firstMessage
- Include voicemail handling in system prompt
- Use 15+ second silence timeout

On success:
- Move quote from Unused to Used
- Add date and recipient: "- YYYY-MM-DD: "[quote]" (Recipient)"
- Write updated file

On failure:
- Report error
- Do NOT move the quote (leave for retry tomorrow)
```

## Monitoring and Debugging

### Check Job Status
```bash
openclaw cron list
openclaw cron logs <job-name>
```

### Common Issues

| Problem | Symptom | Fix |
|---|---|---|
| Wrong timezone | Runs at wrong time | Use `TZ=<zone> date` to verify |
| Quote repeats | Same quote multiple days | Check file write permissions |
| Call failures | No transcript/delivery | Add voicemail handling, check VAPI status |
| High frequency spam | Too many messages | Use `--no-deliver` for monitors |

### Testing New Jobs

1. **Create with near-future time**: Test 2-3 minutes ahead
2. **Monitor the first run**: Check logs and output
3. **Verify side effects**: Files updated, quotes moved, etc.
4. **Adjust and reschedule**: Fix issues, then set real schedule

## Advanced Patterns

### Conditional Delivery

```bash
--prompt "
Check if today is a holiday (read calendar or holiday API).
If holiday, skip the call and reply NO_REPLY.
Otherwise, proceed with daily quote delivery.
"
```

### Multi-Recipient Rotation

```bash
--prompt "
Read recipients list. Today is $(date +%w) (day of week).
Pick recipient based on rotation:
- 0 (Sunday): Skip
- 1 (Monday): Alex (+1XXXXXXXXXX)  
- 2 (Tuesday): Jordan (+1YYYYYYYYYY)
- etc.

Make call to selected recipient only.
"
```

### Retry Logic

```bash
--prompt "
Attempt the call. If it fails:
1. Wait 30 seconds
2. Try again
3. If second failure, log error and skip (don't waste the quote)

Only mark quote as used on successful delivery.
"
```

## Best Practices

1. **Test thoroughly**: Run manually before scheduling
2. **Start simple**: Basic daily call, then add complexity
3. **Monitor initially**: Watch first few runs closely  
4. **Handle failures gracefully**: Don't waste content on failed calls
5. **Use appropriate delivery modes**: `--announce` for daily, `--no-deliver` for monitors
6. **Timezone verification**: Always double-check with `TZ` commands
7. **Keep prompts focused**: One clear task per cron job
8. **Version your content**: Track what's been used/unused
9. **Plan for holidays**: Skip or adjust delivery on special days
10. **Clean up old jobs**: Remove or disable unused cron entries
