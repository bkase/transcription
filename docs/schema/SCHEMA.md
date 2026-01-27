# Database Schema

This document is auto-generated from migrations in `Persistence.swift`.

## Overview
The database contains 5 tables:

- [`sessions`](#sessions)
- [`people`](#people)
- [`speaker_tracks`](#speaker_tracks)
- [`transcript_segments`](#transcript_segments)
- [`speaker_segments`](#speaker_segments)

Full-text search tables:

- [`transcript_fts`](#transcript_fts) (FTS5)

---

## Migration: `v1_initial_schema`

### sessions

| Column | Type | Constraints | Default | References |
|--------|------|-------------|---------|------------|
| `id` | TEXT | PRIMARY KEY | - | - |
| `startedAt` | DATETIME | NOT NULL | - | - |
| `endedAt` | DATETIME | - | - | - |
| `title` | TEXT | - | - | - |
| `previewText` | TEXT | - | - | - |
| `durationMs` | INTEGER | - | - | - |
| `audioPath` | TEXT | - | - | - |
| `processingState` | TEXT | NOT NULL | "recording" | - |
| `speakerCount` | INTEGER | NOT NULL | 0 | - |
| `updatedAt` | DATETIME | NOT NULL | - | - |

### people

| Column | Type | Constraints | Default | References |
|--------|------|-------------|---------|------------|
| `id` | TEXT | PRIMARY KEY | - | - |
| `name` | TEXT | NOT NULL | - | - |
| `colorToken` | TEXT | NOT NULL | - | - |
| `createdAt` | DATETIME | NOT NULL | - | - |
| `updatedAt` | DATETIME | NOT NULL | - | - |

### speaker_tracks

| Column | Type | Constraints | Default | References |
|--------|------|-------------|---------|------------|
| `id` | TEXT | PRIMARY KEY | - | - |
| `sessionId` | TEXT | NOT NULL | - | `sessions` (ON DELETE CASCADE) |
| `machineSpeakerId` | TEXT | NOT NULL | - | - |
| `displayOrder` | INTEGER | NOT NULL | - | - |
| `personId` | TEXT | - | - | `people` (ON DELETE SET NULL) |

### transcript_segments

| Column | Type | Constraints | Default | References |
|--------|------|-------------|---------|------------|
| `id` | TEXT | PRIMARY KEY | - | - |
| `sessionId` | TEXT | NOT NULL | - | `sessions` (ON DELETE CASCADE) |
| `startMs` | INTEGER | NOT NULL | - | - |
| `endMs` | INTEGER | NOT NULL | - | - |
| `machineSpeakerId` | TEXT | - | - | - |
| `text` | TEXT | NOT NULL | - | - |
| `confidence` | REAL | - | - | - |
| `isFinal` | BOOLEAN | NOT NULL | false | - |
| `createdAt` | DATETIME | NOT NULL | - | - |
| `updatedAt` | DATETIME | NOT NULL | - | - |

### speaker_segments

| Column | Type | Constraints | Default | References |
|--------|------|-------------|---------|------------|
| `id` | TEXT | PRIMARY KEY | - | - |
| `sessionId` | TEXT | NOT NULL | - | `sessions` (ON DELETE CASCADE) |
| `startMs` | INTEGER | NOT NULL | - | - |
| `endMs` | INTEGER | NOT NULL | - | - |
| `machineSpeakerId` | TEXT | NOT NULL | - | - |
| `score` | REAL | - | - | - |
| `isOverlap` | BOOLEAN | NOT NULL | false | - |

### Indexes

| Index Name | Table | Columns |
|------------|-------|--------|
| `idx_sessions_startedAt` | `sessions` | `startedAt` |
| `idx_sessions_processingState` | `sessions` | `processingState` |
| `idx_speaker_tracks_sessionId` | `speaker_tracks` | `sessionId` |
| `idx_transcript_segments_sessionId` | `transcript_segments` | `sessionId` |
| `idx_transcript_segments_startMs` | `transcript_segments` | `sessionId`, `startMs` |
| `idx_speaker_segments_sessionId` | `speaker_segments` | `sessionId` |

## Migration: `v2_processing_error`

## Migration: `v3_fts5_search`

### transcript_fts (FTS5 Virtual Table)

Full-text search table for transcript search.

| Column | Indexed |
|--------|--------|
| `text` | Yes |
| `sessionId` | No (UNINDEXED) |
| `segmentId` | No (UNINDEXED) |

### Triggers

| Trigger | Event | Table | Description |
|---------|-------|-------|-------------|
| `transcript_fts_ai` | AFTER INSERT | `transcript_segments` | Inserts new record into FTS index |
| `transcript_fts_ad` | AFTER DELETE | `transcript_segments` | Removes record from FTS index |
| `transcript_fts_au` | AFTER UPDATE | `transcript_segments` | Updates record in FTS index |

---

## Entity Relationships

```
sessions 1--* speaker_tracks     (sessionId -> sessions.id, CASCADE)
sessions 1--* transcript_segments (sessionId -> sessions.id, CASCADE)
sessions 1--* speaker_segments   (sessionId -> sessions.id, CASCADE)
people   1--* speaker_tracks     (personId -> people.id, SET NULL)
```

- A **session** contains multiple **speaker tracks**, **transcript segments**, and **speaker segments**
- Deleting a session cascades to delete all related tracks and segments
- **People** can be assigned to **speaker tracks**; deleting a person sets the reference to NULL
