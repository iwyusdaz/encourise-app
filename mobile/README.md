# Encourise Mobile

Offline-first K-12 AI tutoring app powered by Gemma 4, built with Flutter.

**Current version:** 2.0.0

## Overview

Encourise runs Google's Gemma 4 E2B model entirely on-device via LiteRT-LM (Google AI Edge). The AI tutor **Budi** teaches students using adaptive Socratic methods, quizzes, and guided learning paths — all without internet.

## Features

- **Socratic Tutoring** — Budi guides students through questions, adapting difficulty in real time
- **Quiz Mode** — Self-test with multiple-choice questions and automatic scoring
- **Guided Learning** — 3-step structured learning journeys, fully resumable
- **Notes** — Bookmark Budi's messages as study notes, grouped by topic
- **Persistent Learner Memory** — Budi remembers student strengths/weaknesses across sessions
- **Smart Reminders** — Context-aware notifications based on activity patterns
- **Teaching Style** — Choose between Penyemangat (encouraging), Sokratik, or Terstruktur
- **Offline Sync** — Session data syncs to Supabase when WiFi is available
- **Free Chat** — Open-ended conversation with Budi on any topic

## Project Structure

```
lib/
├── main.dart                    # App entry, notification init, deep-link handler
├── models/
│   └── session_state.dart       # Session state snapshot for prompt injection
├── screens/
│   ├── home_screen.dart         # Dashboard with progress, feature cards, memory chip
│   ├── tutoring_screen.dart     # Socratic tutoring session UI
│   ├── quiz_screen.dart         # Self-test quiz mode
│   ├── guided_learning_screen.dart  # Multi-step guided learning
│   ├── free_chat_screen.dart    # Open conversation with Budi
│   ├── notes_screen.dart        # Saved notes viewer
│   ├── topic_list_screen.dart   # Topic browser with mode picker
│   ├── session_summary_screen.dart  # Post-session summary + memory generation
│   ├── settings_screen.dart     # Profile, teaching style, data reset
│   └── onboarding_screen.dart   # First-time setup
├── services/
│   ├── gemma_runtime.dart       # LiteRT-LM MethodChannel bridge
│   ├── session_manager.dart     # Multi-turn conversation manager
│   ├── difficulty_adapter.dart  # Real-time difficulty adjustment
│   ├── database_service.dart    # SQLite (v2 schema, 7 tables)
│   ├── sync_service.dart        # WiFi sync + smart reminders
│   ├── tutor_capability.dart    # Mode architecture (socratic/quiz/guided)
│   └── model_loader.dart        # Model download / import
└── utils/
    ├── prompt_builder.dart      # System prompt with key concepts + memory
    ├── curriculum_data.dart     # Grade/subject/topic data
    └── key_concepts.dart        # Topic-level concept descriptions
```

## Local Database (SQLite v2)

| Table | Purpose |
|-------|---------|
| `students` | Student profile (name, grade, teaching_style) |
| `topic_progress` | Per-topic mastery tracking |
| `sessions` | Session records with mode and conversation_json |
| `sync_queue` | Offline sync queue for Supabase |
| `learner_memory` | AI-generated learner summaries |
| `notes` | Bookmarked Budi messages |
| `guided_sessions` | Resumable guided learning state |

## Build

```bash
# Debug
flutter run

# Release APK
flutter build apk --release
```

Requires: Flutter 3.x, Android SDK 36, Gemma 4 E2B model (~2.4 GB) on device.

## Releases

APK releases are stored in `../releases/` with naming convention `encourise-vX.Y.Z-release.apk`.
