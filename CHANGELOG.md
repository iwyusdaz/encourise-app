# Changelog

All notable changes to the Encourise project are documented here.

---

## [2.0.0] — 2026-04-12

### DeepTutor Feature Integration

Major release adding 9 adaptive learning features inspired by the [DeepTutor](https://github.com/HKUDS/DeepTutor) research project.

### Added

**Mobile App**

- **Tutoring Capability Architecture** — `TutoringCapability` class with three presets: Socratic, Quiz, Guided
- **Mode Picker** — Bottom sheet on topic list lets students choose Belajar / Tes Diri / Jalur Belajar
- **Quiz Screen** (`quiz_screen.dart`) — Self-test with MCQ questions, progress tracking, session save with `mode = 'quiz'`
- **Guided Learning Screen** (`guided_learning_screen.dart`) — 3-step structured learning, stepper UI, fully resumable, session save with `mode = 'guided'`
- **Notes Screen** (`notes_screen.dart`) — View all bookmarked Budi messages, grouped by topic, with delete
- **Save-Note Buttons** — Bookmark icon on AI messages in TutoringScreen, FreeChatScreen, QuizScreen, GuidedLearningScreen
- **Persistent Learner Memory** — Post-session Gemma-generated summaries stored in `learner_memory` table, injected into future prompts
- **Session Continuity** — `conversation_json` column on sessions table preserves chat history
- **Key Concepts** (`key_concepts.dart`) — Curriculum-aligned concept descriptions for enriched system prompts
- **Teaching Style Selector** — Settings screen with 3 styles: Penyemangat, Sokratik, Terstruktur
- **Enhanced Home Screen** — Feature cards row, resume guided session card, learner memory chip
- **Smart Reminders** — Context-aware local notifications with deep-link payload on tap
- **Notification Deep-Link** — Global `navigatorKey` routes notification taps to TutoringScreen or QuizScreen
- **Enriched System Prompt** — `buildSystemPrompt()` now injects key concepts, teaching style, and learner memory

**Database**

- SQLite schema v2: new tables `learner_memory`, `notes`, `guided_sessions`
- New columns: `sessions.mode`, `sessions.conversation_json`, `students.teaching_style`
- Supabase: created `learner_memory_cloud` and `notes_cloud` tables
- Supabase: added `mode` column to `sessions_cloud`

**Web Dashboard**

- Learner memory card on student profile (Budi's AI-generated summary)
- Mode badges on session history table (Sokratik / Kuis / Jalur)
- Notes tab showing synced student notes
- Jalur Belajar stat card on class overview

**Sync**

- `SyncService` extended to push `learner_memory` and `notes` to Supabase
- Smart reminder scheduling with JSON payload for deep-link

### Changed

- `TutoringScreen` now accepts a `TutoringCapability` parameter (default: socratic)
- `SessionSummaryScreen` converted to `StatefulWidget` for memory generation
- `prompt_builder.dart` signature extended with `keyConcepts`, `teachingStyle`, `learnerMemory` params
- Dashboard stat grid expanded from 3 to 4 columns
- `pubspec.yaml` version bumped to 2.0.0+2

### Fixed

- `session_summary_screen.dart`: missing `widget.` prefix on `subject` reference
- `sync_service.dart`: replaced deprecated `schedule()` with `show()` for notifications
- `sync_service.dart`: fixed syntax error in `_syncNotes` map closure
- Removed unused imports and color constants in quiz, guided, and notes screens

### Deployment

- APK: `releases/encourise-v2.0.0-release.apk` (101.2 MB)
- Web: [https://encourise.vercel.app](https://encourise.vercel.app)

---

## [1.5.0] — 2026-04

- Offline sync improvements
- Bug fixes and performance tuning

## [1.4.1] — 2026-04

- Hotfix for session save

## [1.4.0] — 2026-04

- Teacher web dashboard (Next.js + shadcn/ui)
- Weak topic heatmap page
- Student profile page with session history

## [1.3.0] — 2026-03

- Full K-12 curriculum data (Grades 1-12, 4 subjects)
- Topic progress tracking and mastery system

## [1.2.0] — 2026-03

- Supabase integration and WiFi sync
- Sync queue with retry logic

## [1.1.1] — 2026-03

- Bug fixes

## [1.1.0] — 2026-03

- Onboarding flow
- Settings screen
- Model download and import options

## [1.0.0] — 2026-03

- Initial release: MVP
- Gemma 4 E2B on-device via LiteRT-LM
- Socratic tutoring with Budi
- Difficulty adapter (level up, hints, weak topic flags)
- Basic progress tracking (streak, XP, accuracy)
- Works fully offline
