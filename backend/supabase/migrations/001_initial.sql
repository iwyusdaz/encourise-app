-- =========================================================================
-- Encourise Cloud Schema — Supabase (PostgreSQL)
-- Section 7.4.2 of the PRD
--
-- These tables store data synced from student devices when WiFi is
-- available. They power the teacher dashboard and admin portal.
-- =========================================================================

-- 1. Schools
CREATE TABLE IF NOT EXISTS schools (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    district    TEXT,
    admin_id    UUID,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Teachers
CREATE TABLE IF NOT EXISTS teachers (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    school_id   UUID REFERENCES schools(id) ON DELETE SET NULL,
    class_name  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Students (cloud mirror)
CREATE TABLE IF NOT EXISTS students_cloud (
    device_uuid TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    grade       INTEGER NOT NULL,
    teacher_id  UUID REFERENCES teachers(id) ON DELETE SET NULL,
    last_sync   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Sessions (cloud mirror)
CREATE TABLE IF NOT EXISTS sessions_cloud (
    id          TEXT PRIMARY KEY,
    device_uuid TEXT NOT NULL REFERENCES students_cloud(device_uuid) ON DELETE CASCADE,
    topic_id    TEXT NOT NULL,
    started_at  TIMESTAMPTZ NOT NULL,
    correct     INTEGER NOT NULL DEFAULT 0,
    accuracy    REAL NOT NULL DEFAULT 0.0,
    xp          INTEGER NOT NULL DEFAULT 0
);

-- 5. Topic progress (cloud mirror)
CREATE TABLE IF NOT EXISTS topic_progress_cloud (
    device_uuid  TEXT NOT NULL REFERENCES students_cloud(device_uuid) ON DELETE CASCADE,
    topic_id     TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'not_started',
    accuracy     REAL NOT NULL DEFAULT 0.0,
    level        INTEGER NOT NULL DEFAULT 1,
    last_updated TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (device_uuid, topic_id)
);

-- 6. Announcements
CREATE TABLE IF NOT EXISTS announcements (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id   UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    message      TEXT NOT NULL,
    target_class TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================================
-- Indexes for dashboard queries
-- =========================================================================
CREATE INDEX IF NOT EXISTS idx_sessions_device    ON sessions_cloud(device_uuid);
CREATE INDEX IF NOT EXISTS idx_sessions_topic     ON sessions_cloud(topic_id);
CREATE INDEX IF NOT EXISTS idx_progress_device    ON topic_progress_cloud(device_uuid);
CREATE INDEX IF NOT EXISTS idx_teachers_school    ON teachers(school_id);
CREATE INDEX IF NOT EXISTS idx_announcements_teacher ON announcements(teacher_id);

-- =========================================================================
-- Row-Level Security (RLS)
-- Enable RLS on all tables; policies will be added per role later.
-- =========================================================================
ALTER TABLE schools              ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers             ENABLE ROW LEVEL SECURITY;
ALTER TABLE students_cloud       ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions_cloud       ENABLE ROW LEVEL SECURITY;
ALTER TABLE topic_progress_cloud ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements        ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read/write their own data (basic policy)
CREATE POLICY "Allow anon insert for sync" ON students_cloud
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon insert sessions" ON sessions_cloud
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon insert progress" ON topic_progress_cloud
    FOR INSERT WITH CHECK (true);

-- Allow upserts from the mobile app
CREATE POLICY "Allow anon update students" ON students_cloud
    FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon update sessions" ON sessions_cloud
    FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Allow anon update progress" ON topic_progress_cloud
    FOR UPDATE USING (true) WITH CHECK (true);

-- Allow reads for dashboard
CREATE POLICY "Allow anon select students" ON students_cloud
    FOR SELECT USING (true);
CREATE POLICY "Allow anon select sessions" ON sessions_cloud
    FOR SELECT USING (true);
CREATE POLICY "Allow anon select progress" ON topic_progress_cloud
    FOR SELECT USING (true);
CREATE POLICY "Allow anon select schools" ON schools
    FOR SELECT USING (true);
CREATE POLICY "Allow anon select teachers" ON teachers
    FOR SELECT USING (true);
CREATE POLICY "Allow anon select announcements" ON announcements
    FOR SELECT USING (true);
