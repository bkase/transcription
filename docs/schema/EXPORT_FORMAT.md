# Export Format

This document describes the export formats available for session data.

## JSON Export

Sessions can be exported as JSON with the following structure:

```json
{
  "version": "1.0",
  "exportedAt": "2026-01-25T00:00:00Z",
  "session": {
    "id": "session-uuid",
    "startedAt": "2026-01-25T00:00:00Z",
    "endedAt": "2026-01-25T00:30:00Z",
    "title": "Meeting Title",
    "durationMs": 1800000,
    "speakerCount": 2,
    "speakers": [
      {
        "machineSpeakerId": "speaker-0",
        "displayOrder": 1,
        "person": {
          "id": "person-uuid",
          "name": "Alice"
        }
      }
    ],
    "transcript": [
      {
        "id": "segment-uuid",
        "startMs": 0,
        "endMs": 5000,
        "text": "Hello, how are you?",
        "speakerId": "speaker-0",
        "confidence": 0.95
      }
    ]
  }
}
```

## Markdown Export

Sessions can be exported as readable Markdown:

```markdown
# Meeting Title

**Date:** January 25, 2026
**Duration:** 30 minutes
**Speakers:** Alice, Bob

---

## Transcript

**[00:00] Alice:** Hello, how are you?

**[00:05] Bob:** I'm doing well, thanks!
```

## VTT (Web Video Text Tracks) Export

For video subtitle compatibility:

```vtt
WEBVTT

00:00:00.000 --> 00:00:05.000
<v Alice>Hello, how are you?

00:00:05.000 --> 00:00:10.000
<v Bob>I'm doing well, thanks!
```

## Database Tables Used

Export functionality reads from the following tables:
- `sessions`: id, startedAt, endedAt, title, previewText, durationMs, audioPath, processingState, speakerCount, updatedAt
- `people`: id, name, colorToken, createdAt, updatedAt
- `speaker_tracks`: id, sessionId, machineSpeakerId, displayOrder, personId
- `transcript_segments`: id, sessionId, startMs, endMs, machineSpeakerId, text, confidence, isFinal, createdAt, updatedAt
- `speaker_segments`: id, sessionId, startMs, endMs, machineSpeakerId, score, isOverlap
