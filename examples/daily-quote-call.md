# Daily Quote Call Example

Setting up a recurring daily inspirational call system with quote tracking.

## Overview

This example shows how to:
1. Schedule a daily call delivering Steve Jobs quotes
2. Track which quotes have been used to avoid repeats
3. Handle voicemail scenarios safely
4. Manage failures without wasting quotes

## Step 1: Prepare the Quotes File

Ensure your quotes file has the proper structure:

```markdown
# Steve Jobs Quotes Collection

## Used Quotes
- 2026-03-25: "Innovation distinguishes between a leader and a follower." (Alex)
- 2026-03-24: "Your time is limited, so don't waste it living someone else's life." (Jordan)

## Unused Quotes
- "Stay hungry, stay foolish."
- "The people who are crazy enough to think they can change the world are the ones who do."
- "Design is not just what it looks like and feels like. Design is how it works."
```

## Step 2: Create the Cron Job

```bash
openclaw cron add \
  --name "daily-inspirational-call" \
  --schedule "0 9 * * *" \
  --timezone "America/Los_Angeles" \
  --announce \
  --prompt "
Make a daily inspirational call with Steve Jobs quote:

1. Read assets/quotes/steve-jobs.md
2. Find the first quote in the 'Unused Quotes' section
3. Make a VAPI call using scripts/make-vapi-call.sh:
   - Phone: +1XXXXXXXXXX
   - Purpose: 'Daily Steve Jobs inspiration'
   - Put the full quote in firstMessage for voicemail safety

System prompt must include:
- Voicemail handling instructions
- Quote delivery as the primary purpose
- Warm, inspirational tone

After successful call:
1. Move the quote from 'Unused Quotes' to 'Used Quotes' section
2. Add today's date and recipient name
3. Save the updated quotes file

If call fails (check transcript for errors):
- Log the failure reason
- Do NOT mark quote as used
- It will retry with the same quote tomorrow
"
```

## Step 3: Test the Setup

Before relying on the cron job, test manually:

```bash
# Test quote extraction
head -20 assets/quotes/steve-jobs.md

# Test VAPI call script
VAPI_API_KEY="your_key" \
VAPI_PHONE_NUMBER_ID="your_id" \
ELEVENLABS_VOICE_ID="your_voice" \
./scripts/make-vapi-call.sh "+1XXXXXXXXXX" "Test quote delivery" "This is a test quote: 'Innovation distinguishes between a leader and a follower.' Have a great day!"
```

## Step 4: Monitor Initial Runs

Check the first few automated runs:

```bash
# View recent cron job results
openclaw cron logs daily-inspirational-call

# Verify quotes file is being updated
cat assets/quotes/steve-jobs.md | grep "Used Quotes" -A 10

# Check for any call failures
grep -i "error\|fail" $(openclaw cron logs daily-inspirational-call --file)
```

## Advanced: Multi-Recipient Rotation

For multiple recipients on different days:

```bash
openclaw cron add \
  --name "rotating-quote-calls" \
  --schedule "0 9 * * 1-5" \
  --timezone "America/New_York" \
  --announce \
  --prompt "
Daily rotating inspirational calls:

Recipients rotation (based on day of week):
- Monday (1): Alex (+1XXXXXXXXXX)
- Tuesday (2): Jordan (+1YYYYYYYYYY)  
- Wednesday (3): Taylor (+1ZZZZZZZZZZ)
- Thursday (4): Alex (+1XXXXXXXXXX)
- Friday (5): Jordan (+1YYYYYYYYYY)

Today is $(date +%u) (day of week).
Select appropriate recipient and phone number.

Make the call with quote from assets/quotes/steve-jobs.md:
1. Get first unused quote
2. Call selected recipient
3. Move quote to used section with recipient name

Skip weekends (day 6,7).
"
```

## Troubleshooting

### Quote Not Moving to Used Section

**Problem**: Same quote delivered multiple days
**Check**: File write permissions, cron job output for errors
**Fix**: Ensure the cron job can write to the quotes file

### Call Always Goes to Voicemail

**Problem**: Recipient never answers, quotes getting used up
**Solution**: Adjust call timing, or implement voicemail-aware logic:

```bash
--prompt "
After making the call, check the transcript:
- If transcript shows conversation (human answered), mark quote as used normally
- If transcript shows only voicemail greeting + AI message, mark as 'delivered to voicemail'
- Consider shorter retry window (maybe try again 2 hours later)
"
```

### Timezone Issues

**Problem**: Calls happening at wrong time
**Debug**: 
```bash
TZ=America/Los_Angeles date -d "09:00 today" -u "+%H:%M UTC"
```
**Fix**: Update cron schedule with correct UTC time

### Running Out of Quotes

**Problem**: Used section grows, unused section shrinks
**Solution**: Implement quote recycling after 30+ days:

```bash
--prompt "
Before selecting a quote:
1. Check if Unused Quotes section is empty
2. If empty, move quotes older than 30 days from Used back to Unused
3. Then proceed with normal quote selection

This allows quote recycling after a month gap.
"
```

## Best Practices

1. **Test voicemail scenarios**: Call your own voicemail to verify message delivery
2. **Monitor failure patterns**: If calls consistently fail at certain times, adjust schedule  
3. **Graceful degradation**: Handle API failures without losing quotes
4. **Content variety**: Rotate between different quote collections periodically
5. **Recipient feedback**: Ask recipients about preferred timing and frequency
6. **Holiday awareness**: Skip or adjust delivery on major holidays
