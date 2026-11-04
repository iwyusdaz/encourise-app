"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

interface StudentData {
  device_uuid: string;
  name: string;
  grade: number;
  last_sync: string;
}

interface Session {
  id: string;
  topic_id: string;
  started_at: string;
  correct: number;
  accuracy: number;
  xp: number;
  mode?: string;
}

interface LearnerMemory {
  summary_text: string;
  profile_json: string;
  updated_at: string;
}

interface Note {
  id: string;
  topic_id: string;
  content_text: string;
  created_at: string;
}

interface TopicProgress {
  topic_id: string;
  status: string;
  accuracy: number;
  level: number;
  last_updated: string;
}

export default function StudentProfilePage() {
  const params = useParams();
  const studentId = params.id as string;

  const [student, setStudent] = useState<StudentData | null>(null);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [progress, setProgress] = useState<TopicProgress[]>([]);
  const [memory, setMemory] = useState<LearnerMemory | null>(null);
  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (studentId) fetchData();
  }, [studentId]);

  async function fetchData() {
    const [
      { data: studentData },
      { data: sessionsData },
      { data: progressData },
      { data: memoryData },
      { data: notesData },
    ] = await Promise.all([
      supabase
        .from("students_cloud")
        .select("*")
        .eq("device_uuid", studentId)
        .single(),
      supabase
        .from("sessions_cloud")
        .select("*")
        .eq("device_uuid", studentId)
        .order("started_at", { ascending: false }),
      supabase
        .from("topic_progress_cloud")
        .select("*")
        .eq("device_uuid", studentId),
      supabase
        .from("learner_memory_cloud")
        .select("*")
        .eq("device_uuid", studentId)
        .single(),
      supabase
        .from("notes_cloud")
        .select("*")
        .eq("device_uuid", studentId)
        .order("created_at", { ascending: false }),
    ]);

    if (studentData) setStudent(studentData);
    if (sessionsData) setSessions(sessionsData);
    if (progressData) setProgress(progressData);
    if (memoryData) setMemory(memoryData);
    if (notesData) setNotes(notesData);
    setLoading(false);
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-muted-foreground">Memuat data siswa…</p>
      </div>
    );
  }

  if (!student) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-muted-foreground">Siswa tidak ditemukan.</p>
      </div>
    );
  }

  const totalSessions = sessions.length;
  const avgAccuracy =
    totalSessions > 0
      ? sessions.reduce((s, sess) => s + sess.accuracy, 0) / totalSessions
      : 0;
  const totalXp = sessions.reduce((s, sess) => s + sess.xp, 0);
  const flaggedTopics = progress.filter((p) => p.status === "flagged");

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/dashboard" className="text-muted-foreground hover:text-primary text-sm">
            ← Kembali
          </Link>
          <div>
            <h1 className="text-xl font-bold text-foreground">{student.name}</h1>
            <p className="text-sm text-muted-foreground">
              Kelas {student.grade} · Terakhir sync:{" "}
              {new Date(student.last_sync).toLocaleDateString("id-ID")}
            </p>
          </div>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-6 py-8">
        {/* Learner memory card */}
        {memory && memory.summary_text && (
          <Card className="mb-6 border-primary/20 bg-primary/5">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2">
                <span>🧠</span> Catatan Budi tentang Siswa Ini
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-foreground leading-relaxed">
                {memory.summary_text}
              </p>
              <p className="text-xs text-muted-foreground mt-2">
                Terakhir diperbarui: {new Date(memory.updated_at).toLocaleDateString("id-ID")}
              </p>
            </CardContent>
          </Card>
        )}

        {/* Stat cards */}
        <div className="grid grid-cols-1 sm:grid-cols-4 gap-4 mb-8">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Total Sesi
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold">{totalSessions}</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Rata-rata Akurasi
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold">{(avgAccuracy * 100).toFixed(0)}%</p>
              <Progress value={avgAccuracy * 100} className="mt-2 h-2" />
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Total XP
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold text-primary">{totalXp}</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Topik Lemah
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold text-destructive">{flaggedTopics.length}</p>
            </CardContent>
          </Card>
        </div>

        {/* Tabs */}
        <Tabs defaultValue="overview">
          <TabsList>
            <TabsTrigger value="overview">Ringkasan</TabsTrigger>
            <TabsTrigger value="sessions">Riwayat Sesi</TabsTrigger>
            <TabsTrigger value="notes">Catatan ({notes.length})</TabsTrigger>
            <TabsTrigger value="weak">Topik Lemah</TabsTrigger>
          </TabsList>

          {/* Overview tab */}
          <TabsContent value="overview" className="mt-6">
            <Card>
              <CardHeader>
                <CardTitle>Progress per Topik</CardTitle>
              </CardHeader>
              <CardContent>
                {progress.length === 0 ? (
                  <p className="text-muted-foreground text-center py-4">Belum ada data.</p>
                ) : (
                  <div className="space-y-4">
                    {progress.map((p) => (
                      <div key={p.topic_id} className="flex items-center gap-4">
                        <span className="w-40 text-sm font-medium truncate">
                          {p.topic_id.replace(/_/g, " ")}
                        </span>
                        <Progress value={p.accuracy * 100} className="flex-1 h-3" />
                        <span className="text-sm text-muted-foreground w-12 text-right">
                          {(p.accuracy * 100).toFixed(0)}%
                        </span>
                        <Badge
                          className={
                            p.status === "mastered"
                              ? "bg-accent text-accent-foreground"
                              : p.status === "flagged"
                              ? "bg-destructive text-foreground"
                              : "bg-secondary text-secondary-foreground"
                          }
                        >
                          L{p.level}
                        </Badge>
                      </div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* Sessions tab */}
          <TabsContent value="sessions" className="mt-6">
            <Card>
              <CardHeader>
                <CardTitle>Riwayat Sesi</CardTitle>
              </CardHeader>
              <CardContent>
                {sessions.length === 0 ? (
                  <p className="text-muted-foreground text-center py-4">Belum ada sesi.</p>
                ) : (
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Tanggal</TableHead>
                        <TableHead>Topik</TableHead>
                        <TableHead>Mode</TableHead>
                        <TableHead>Benar</TableHead>
                        <TableHead>Akurasi</TableHead>
                        <TableHead>XP</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {sessions.map((sess) => (
                        <TableRow key={sess.id}>
                          <TableCell className="text-muted-foreground">
                            {new Date(sess.started_at).toLocaleDateString("id-ID")}
                          </TableCell>
                          <TableCell className="font-medium">
                            {sess.topic_id.replace(/_/g, " ")}
                          </TableCell>
                          <TableCell>
                            <Badge
                              className={
                                sess.mode === "quiz"
                                  ? "bg-amber-100 text-amber-700"
                                  : sess.mode === "guided"
                                  ? "bg-green-100 text-green-700"
                                  : "bg-blue-100 text-blue-700"
                              }
                            >
                              {sess.mode === "quiz"
                                ? "Kuis"
                                : sess.mode === "guided"
                                ? "Jalur"
                                : "Sokratik"}
                            </Badge>
                          </TableCell>
                          <TableCell>{sess.correct}</TableCell>
                          <TableCell>{(sess.accuracy * 100).toFixed(0)}%</TableCell>
                          <TableCell className="text-primary font-medium">
                            +{sess.xp}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* Notes tab */}
          <TabsContent value="notes" className="mt-6">
            <Card>
              <CardHeader>
                <CardTitle>Catatan Siswa</CardTitle>
              </CardHeader>
              <CardContent>
                {notes.length === 0 ? (
                  <p className="text-muted-foreground text-center py-4">
                    Belum ada catatan yang disimpan.
                  </p>
                ) : (
                  <div className="space-y-3">
                    {notes.map((note) => (
                      <div
                        key={note.id}
                        className="rounded-lg border border-border bg-card px-4 py-3"
                      >
                        <div className="flex items-center justify-between mb-1">
                          <Badge className="bg-secondary text-secondary-foreground">
                            {note.topic_id}
                          </Badge>
                          <span className="text-xs text-muted-foreground">
                            {new Date(note.created_at).toLocaleDateString("id-ID")}
                          </span>
                        </div>
                        <p className="text-sm text-foreground leading-relaxed mt-2">
                          {note.content_text}
                        </p>
                      </div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* Weak topics tab */}
          <TabsContent value="weak" className="mt-6">
            <Card>
              <CardHeader>
                <CardTitle>Topik yang Perlu Perhatian</CardTitle>
              </CardHeader>
              <CardContent>
                {flaggedTopics.length === 0 ? (
                  <p className="text-muted-foreground text-center py-4">
                    Tidak ada topik lemah. Bagus! 🎉
                  </p>
                ) : (
                  <div className="space-y-3">
                    {flaggedTopics.map((p) => (
                      <div
                        key={p.topic_id}
                        className="flex items-center justify-between rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3"
                      >
                        <div>
                          <p className="font-medium text-foreground">
                            {p.topic_id.replace(/_/g, " ")}
                          </p>
                          <p className="text-sm text-muted-foreground">
                            Akurasi: {(p.accuracy * 100).toFixed(0)}% · Level {p.level}
                          </p>
                        </div>
                        <Badge className="bg-destructive text-foreground">Perlu Review</Badge>
                      </div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </main>
    </div>
  );
}
