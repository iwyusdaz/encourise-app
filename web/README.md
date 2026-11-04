# Encourise Web Dashboard

Teacher dashboard for Encourise — view student progress, learner memory, session history, and notes.

**Live:** [https://encourise.vercel.app](https://encourise.vercel.app)

## Tech Stack

- **Next.js 16** (App Router, TypeScript)
- **shadcn/ui** + **Tailwind CSS** with Encourise color palette
- **Supabase** (PostgreSQL, Auth)
- **Vercel** (deployment)

## Pages

| Route | Description |
|-------|-------------|
| `/login` | Teacher login (Supabase Auth) |
| `/dashboard` | Class overview — student table, stat cards (Total Siswa, Aktif, Akurasi, Jalur Belajar) |
| `/dashboard/heatmap` | Weak topic heatmap — per-student, per-topic mastery grid |
| `/dashboard/student/[id]` | Student profile — learner memory, session history with mode badges, notes tab, weak topics |

## Supabase Tables Read

| Table | Data |
|-------|------|
| `students_cloud` | Student profiles synced from mobile devices |
| `sessions_cloud` | Session records with mode (tutoring/quiz/guided) |
| `topic_progress_cloud` | Per-topic mastery status |
| `learner_memory_cloud` | AI-generated learner summaries from Budi |
| `notes_cloud` | Student-bookmarked Budi messages |

## Development

```bash
npm install
npm run dev        # http://localhost:3000
```

## Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL=<your-supabase-url>
NEXT_PUBLIC_SUPABASE_ANON_KEY=<your-anon-key>
```

## Deploy

```bash
vercel --prod
```
