# Encourise Mobile UI/UX Redesign Brief

## Product Read

Encourise is an offline-first K-12 AI tutor for Indonesian students. The current Flutter app already has the right learning surface: onboarding, home, topic list, Socratic tutoring, quiz, guided learning, notes, summary, and settings. The biggest UI opportunity is to make those flows feel calmer, more trustworthy, and easier to scan on budget Android devices.

## Current UI Notes

- The existing design system is dark and purple-heavy. It feels polished, but more like a generic edtech/game template than an offline tutor for rural students.
- Home currently competes for attention: recent cards, categories, Ask Budi, guided resume, memory, stats, and subject grid all appear in one long stack.
- Chat, quiz, and guided learning share useful structure, but mode identity is subtle. A student should always know whether they are learning, testing, or following a guided path.
- Offline readiness is a core product promise, but it is not visually prominent enough.
- Budi is present as an avatar in chat, but the app could use him more as a calm guide and status anchor.

## Redesign Direction

Name: **Kelas Tenang**

Principles:

- Make offline confidence visible: show a small "Offline siap" status on home and session headers.
- Prioritize one next action: resume session, ask Budi, or choose a subject should dominate the first viewport.
- Use a daylight interface: warm white surfaces, deep ink text, jade/teal primary, sunflower XP accents, coral review states, and a restrained indigo AI accent.
- Keep gamification supportive, not noisy: streak, XP, and level should reassure the student without turning the app into a casino.
- Make modes unmistakable:
  - Belajar: conversational and gentle.
  - Tes Diri: focused question card with answer options.
  - Jalur Belajar: stepper and checklist.
- Keep touch targets large, labels short, and text legible at 360px mobile width.

## Screen Priorities

1. Home
   - Header: "Halo Andi" plus "Offline siap".
   - Primary card: resume guided session or "Mulai belajar".
   - Today row: daily goal, streak, XP.
   - Budi quick ask.
   - Subject grid with compact progress.

2. Topic And Mode Selection
   - Subject header with grade and mastered count.
   - Topic list with progress status.
   - Mode picker bottom sheet with three clear choices: Belajar, Tes Diri, Jalur Belajar.

3. Tutoring Session
   - Header: subject, topic, offline status, level.
   - Chat bubbles optimized for reading.
   - Budi messages include "Simpan" as a small icon action, not a large pill.
   - Input bar should feel stable and low-friction.

4. Guided Learning
   - Three-step progress is the main visual anchor.
   - Current step card above chat.
   - "Langkah Berikutnya" is visually stronger than free-form chat actions.

## GPT Image 2 Mockup Prompt

Use case: ui-mockup

Asset type: mobile app redesign concept board for Flutter implementation

Primary request: Create a polished UI/UX redesign concept for the Encourise mobile app, an offline-first AI tutor for Indonesian K-12 students. Show four Android phone screens side by side: Home, Topic mode picker, Tutoring chat, and Guided learning.

Product context: Encourise runs on budget Android phones, works fully offline after setup, and helps Indonesian students learn with an AI tutor named Budi. The audience is K-12 students in Indonesia and Southeast Asia, including low-connectivity communities.

Visual direction: "Kelas Tenang" daylight educational interface. Warm off-white app background, deep ink text, jade/teal primary actions, sunflower yellow XP highlights, coral review/error accents, and a restrained indigo accent for Budi/AI. Calm, friendly, trustworthy, not clinical, not game-noisy, not dark purple.

Screen 1 Home:
- Greeting "Halo Andi"
- Small status pill "Offline siap"
- Primary resume card: "Lanjut Jalur Belajar" and topic "Pecahan"
- Today row with goal, streak, XP
- Quick ask Budi card
- Subject grid: Matematika, Bahasa Indonesia, IPA, IPS with progress bars

Screen 2 Topic mode picker:
- Header "Matematika Kelas 5"
- Topic list with "Pecahan", "Desimal", "Bangun Ruang"
- Bottom sheet titled "Pilih cara belajar"
- Three mode choices: "Belajar", "Tes Diri", "Jalur Belajar"

Screen 3 Tutoring chat:
- Header "Belajar • Pecahan"
- Offline status and level chip
- Budi avatar, readable chat bubbles, student reply bubble
- Hint card and stable input bar

Screen 4 Guided learning:
- Header "Jalur Belajar • Pecahan"
- Three-step progress indicator
- Current step card "Langkah 2: Contoh dan Latihan"
- Chat area and prominent "Langkah Berikutnya" button

Layout constraints: 360x800 Android proportions, large touch targets, clear hierarchy, accessible contrast, production-ready Flutter UI, Material-style components, 8 to 16px radii, no nested cards, no decorative blobs, no marketing hero, no purple-dominant dark theme. Use realistic short Indonesian UI labels, but prioritize clean visual structure over excessive text.
